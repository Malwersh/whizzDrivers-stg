const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const {digest}=require('../phone-auth/challenge-policy');
function harness(record) {
 const writes=[]; let used=false;
 const commands={}; for(const name of ['GetCommand','PutCommand','UpdateCommand','TransactWriteCommand','GetSecretValueCommand','AdminUpdateUserAttributesCommand']) commands[name]=class {constructor(input){this.input=input;this.kind=name;}};
 const db={send:async cmd=>{
  if(cmd.kind==='GetCommand') return {Item:{...record,used}};
  writes.push(cmd);
  if(cmd.kind==='UpdateCommand') {if(used){const e=new Error();e.name='ConditionalCheckFailedException';throw e;} if(cmd.input.UpdateExpression.includes('used')) used=true;}
  return {};
 }};
 const cognito={send:async cmd=>{writes.push(cmd);return {};}};
 const module={exports:{}};
 const context={exports:module.exports,process:{env:{OTP_TABLE:'table',OTP_SECRET_ARN:'secret'}},fetch:async()=>({ok:true}),AbortSignal,Date,Buffer,require:name=>{
  if(name==='@aws-sdk/client-dynamodb') return {DynamoDBClient:class{}};
  if(name==='@aws-sdk/lib-dynamodb') return {...commands,DynamoDBDocumentClient:{from:()=>db}};
  if(name==='@aws-sdk/client-secrets-manager') return {...commands,SecretsManagerClient:class{async send(){return {SecretString:JSON.stringify({apiKey:'test',hmacKey:'key'})};}}};
  if(name==='@aws-sdk/client-cognito-identity-provider') return {...commands,CognitoIdentityProviderClient:class{send(cmd){return cognito.send(cmd);}}};
  if(name.startsWith('./')) return require('../phone-auth/'+name.slice(2));
  return require(name);
 }};
 vm.runInNewContext(fs.readFileSync(require.resolve('../phone-auth/triggers'),'utf8'),context);
 return {handler:module.exports.handler,writes};
}
function event(answer){return {userName:'driver',userPoolId:'pool',triggerSource:'VerifyAuthChallengeResponse_Authentication',request:{privateChallengeParameters:{id:'session'},challengeAnswer:answer},response:{}};}
test('atomic consumption allows only one successful verification and verifies phone',async()=>{
 const record={id:'session',username:'driver',expiresAt:Math.floor(Date.now()/1000)+300,attempts:0,digest:digest('key','session','driver','123456')};
 const h=harness(record); const results=await Promise.all([h.handler(event('123456')),h.handler(event('123456'))]);
 assert.equal(results.filter(e=>e.response.answerCorrect).length,1);
 assert.equal(h.writes.filter(c=>c.kind==='AdminUpdateUserAttributesCommand').length,1);
});
test('wrong answer increments attempts without marking phone verified',async()=>{
 const h=harness({id:'session',username:'driver',expiresAt:Math.floor(Date.now()/1000)+300,attempts:0,digest:digest('key','session','driver','123456')});
 assert.equal((await h.handler(event('000000'))).response.answerCorrect,false);
 assert.equal(h.writes.filter(c=>c.kind==='AdminUpdateUserAttributesCommand').length,0);
 assert.equal(h.writes[0].input.UpdateExpression,'ADD attempts :one');
});
test('unverified existing phone cannot start a custom login',async()=>{
 const h=harness({});
 await assert.rejects(h.handler({userName:'driver',triggerSource:'CreateAuthChallenge_Authentication',request:{userAttributes:{phone_number:'+9647701234567',phone_number_verified:'false'},session:[]},response:{}}),/enrollment required/);
 assert.equal(h.writes.length,0);
});
