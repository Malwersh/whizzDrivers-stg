const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const {digest}=require('../phone-auth/challenge-policy');
const reviewPhone='+9647800000000';
function setup({phone=reviewPhone,enabled=true,verified=true,status='CONFIRMED',users=1,configured=true}={}){
 const calls=[],sms=[];const commands={};
 for(const kind of ['GetCommand','PutCommand','UpdateCommand','TransactWriteCommand','ListUsersCommand','AdminCreateUserCommand','AdminSetUserPasswordCommand','AdminUpdateUserAttributesCommand','GetSecretValueCommand','InvokeCommand'])commands[kind]=class{constructor(input){this.kind=kind;this.input=input;}};
 const user={Enabled:enabled,UserStatus:status,Attributes:[{Name:'phone_number_verified',Value:String(verified)}]};
 const db={send:async c=>{calls.push(c);return {};}};const module={exports:{}};
 vm.runInNewContext(fs.readFileSync(require.resolve('../phone-auth/registration'),'utf8'),{exports:module.exports,Buffer,Date,AbortSignal,process:{env:{OTP_TABLE:'otp',USER_POOL_ID:'pool',...(configured?{REVIEW_TEST_PHONE:reviewPhone,REVIEW_TEST_CODE:'123456'}:{})}},fetch:async(u,o)=>{sms.push(JSON.parse(o.body));return {ok:true};},require:n=>{
  if(n==='@aws-sdk/client-dynamodb')return {DynamoDBClient:class{}};
  if(n==='@aws-sdk/lib-dynamodb')return {...commands,DynamoDBDocumentClient:{from:()=>db}};
  if(n==='@aws-sdk/client-secrets-manager')return {...commands,SecretsManagerClient:class{async send(){return {SecretString:JSON.stringify({apiKey:'test',hmacKey:'test-key'})};}}};
  if(n==='@aws-sdk/client-cognito-identity-provider')return {...commands,CognitoIdentityProviderClient:class{async send(c){calls.push(c);assert.equal(c.kind,'ListUsersCommand');return {Users:Array.from({length:users},()=>user)};}}};
  if(n==='@aws-sdk/client-lambda')return {...commands,LambdaClient:class{}};
  return n.startsWith('./')?require('../phone-auth/'+n.slice(2)):require(n);
 }});
 return {calls,sms,run:()=>module.exports.handler({path:'/auth/phone/send',body:JSON.stringify({phone}),requestContext:{identity:{sourceIp:'127.0.0.1'}}})};
}
test('existing verified review identity receives a hashed fixed challenge without SMS',async()=>{
 const h=setup();const r=await h.run();assert.equal(r.statusCode,200);assert.equal(h.sms.length,0);
 const tx=h.calls.find(c=>c.input.TransactItems?.some(x=>x.Put?.Item.purpose==='registration-otp'));
 const record=tx.input.TransactItems.find(x=>x.Put?.Item.purpose==='registration-otp').Put.Item;
 assert.equal(record.digest,digest('test-key',record.id,reviewPhone,'123456'));
 assert.equal(record.expiresAt>Math.floor(Date.now()/1000),true);
 assert.equal(h.calls[0].input.TransactItems.length,4);
 assert.equal(h.calls.some(c=>c.kind.startsWith('Admin')),false);
});
test('fixed code never admits missing, disabled, unverified, unconfirmed or ambiguous identities',async()=>{
 for(const opt of [{users:0},{enabled:false},{verified:false},{status:'UNCONFIRMED'},{users:2}]){
  const h=setup(opt);assert.equal((await h.run()).statusCode,409);assert.equal(h.sms.length,0);
  assert.equal(h.calls.some(c=>c.input.TransactItems?.some(x=>x.Put?.Item.purpose==='registration-otp')),false);
 }
});
test('ordinary numbers and deployments without review configuration keep normal SMS verification',async()=>{
 for(const opt of [{phone:'+9647701234567'},{configured:false}]){
  const h=setup(opt);assert.equal((await h.run()).statusCode,200);assert.equal(h.sms.length,1);
  assert.equal(h.calls.some(c=>c.kind==='ListUsersCommand'),false);
  assert.match(h.sms[0].verificationCode,/^\d{6}$/);
 }
});
