const {test}=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');const vm=require('node:vm');
const {digest}=require('../phone-auth/challenge-policy');
function setup({verified=true,code='123456',expired=false,newAccount=false,abandoned=false,hasProfile=false,hasWallet=false}={}){
 const phone='+9647701234567',id='test-session',calls=[];
 const record={id,phone,username:phone,purpose:'registration-otp',expiresAt:Math.floor(Date.now()/1000)+(expired?-10:300),attempts:0,used:false,digest:digest('key',id,phone,code)};
 const names=['GetCommand','PutCommand','UpdateCommand','TransactWriteCommand','ListUsersCommand','AdminCreateUserCommand','AdminSetUserPasswordCommand','AdminUpdateUserAttributesCommand','GetSecretValueCommand','InvokeCommand'];const commands={};
 for(const name of names)commands[name]=class{constructor(input){this.input=input;this.kind=name;}};
 let created=false;
 const user={Username:'stable-existing-id',Enabled:true,UserStatus:abandoned?'UNCONFIRMED':'CONFIRMED',Attributes:[{Name:'sub',Value:'stable-sub'},{Name:'phone_number_verified',Value:verified?'true':'false'}]};
 const db={send:async c=>{calls.push(c);if(c.kind==='GetCommand'&&c.input.TableName==='drivers')return {Item:hasProfile?{driverId:'stable-sub'}:undefined};if(c.kind==='GetCommand'&&c.input.TableName==='wallets')return {Item:hasWallet?{walletId:'existing'}:undefined};if(c.kind==='GetCommand')return {Item:c.input.Key.id===id?record:{sessionId:id}};return {};}};
 const module={exports:{}};
 vm.runInNewContext(fs.readFileSync(require.resolve('../phone-auth/registration'),'utf8'),{exports:module.exports,Buffer,Date,AbortSignal,process:{env:{OTP_TABLE:'otp',USER_POOL_ID:'pool',DRIVER_TABLE:'drivers',WALLETS_TABLE:'wallets',WALLET_TRIGGER:'wallet'}},require:n=>{
 if(n==='@aws-sdk/client-dynamodb')return {DynamoDBClient:class{}};
 if(n==='@aws-sdk/lib-dynamodb')return {...commands,DynamoDBDocumentClient:{from:()=>db}};
 if(n==='@aws-sdk/client-secrets-manager')return {...commands,SecretsManagerClient:class{async send(){return {SecretString:JSON.stringify({apiKey:'test',hmacKey:'key'})};}}};
 if(n==='@aws-sdk/client-cognito-identity-provider')return {...commands,CognitoIdentityProviderClient:class{async send(c){calls.push(c);if(c.kind==='ListUsersCommand')return {Users:newAccount&&!created?[]:[user]};if(newAccount&&c.kind==='AdminCreateUserCommand'){created=true;return {User:user};}if((newAccount||abandoned)&&['AdminSetUserPasswordCommand','AdminUpdateUserAttributesCommand'].includes(c.kind))return {};throw Error('Unexpected account mutation');}}};
 if(n==='@aws-sdk/client-lambda')return {...commands,LambdaClient:class{async send(c){calls.push(c);return {};}}};
 return n.startsWith('./')?require('../phone-auth/'+n.slice(2)):require(n);
 }});
 return {calls,run:answer=>module.exports.handler({path:'/auth/phone/verify',body:JSON.stringify({phone,sessionId:id,code:answer})})};
}
test('valid OTP preserves existing identity and creates only a login proof',async()=>{
 const h=setup();const result=await h.run('123456');assert.equal(result.statusCode,200);
 const value=JSON.parse(result.body);assert.equal(value.username,'stable-existing-id');assert.match(value.loginProof,/^[a-f0-9]{64}$/);
 assert.equal(h.calls.some(c=>c.kind==='AdminCreateUserCommand'||c.kind==='AdminSetUserPasswordCommand'),false);
 const profile=h.calls.find(c=>c.kind==='PutCommand'&&c.input.TableName==='drivers');assert.equal(profile.input.Item.driverId,'stable-sub');assert.equal(profile.input.Item.isVerified,false);assert.equal(profile.input.ConditionExpression,'attribute_not_exists(driverId)');
});
test('wrong or expired OTP never provisions an account or wallet',async()=>{
 for(const options of [{},{expired:true}]){
 const h=setup(options);const result=await h.run('000000');assert.equal(result.statusCode,400);assert.equal(h.calls.some(c=>c.kind==='ListUsersCommand'||c.kind==='InvokeCommand'),false);
 }
});
test('legacy unverified phone cannot take over an existing identity',async()=>{
 const h=setup({verified:false});assert.equal((await h.run('123456')).statusCode,409);assert.equal(h.calls.some(c=>c.kind==='AdminSetUserPasswordCommand'||c.kind==='InvokeCommand'),false);
});

test('new identity is provisioned only after OTP consumption and stays unapproved',async()=>{
 const h=setup({newAccount:true});assert.equal((await h.run('123456')).statusCode,200);
 const consume=h.calls.findIndex(c=>c.kind==='TransactWriteCommand'&&c.input.TransactItems.some(x=>x.Update?.UpdateExpression.includes('used')));
 const create=h.calls.findIndex(c=>c.kind==='AdminCreateUserCommand');assert.ok(consume>=0&&create>consume);
 assert.equal(h.calls[create].input.MessageAction,'SUPPRESS');
 const profile=h.calls.find(c=>c.kind==='PutCommand'&&c.input.TableName==='drivers');assert.equal(profile.input.Item.status,'PENDING_PROFILE');
});

test('abandoned unconfirmed signup resumes only after valid OTP and preserves its subject',async()=>{
 const h=setup({verified:false,abandoned:true});const result=await h.run('123456');assert.equal(result.statusCode,200);
 assert.equal(JSON.parse(result.body).username,'stable-existing-id');
 assert.equal(h.calls.some(c=>c.kind==='AdminCreateUserCommand'),false);
 const profile=h.calls.find(c=>c.kind==='PutCommand'&&c.input.TableName==='drivers');assert.equal(profile.input.Item.driverId,'stable-sub');assert.equal(profile.input.Item.isVerified,false);
});
test('unconfirmed account with an existing profile or wallet cannot be reclaimed',async()=>{
 for(const options of [{hasProfile:true},{hasWallet:true}]) {
  const h=setup({verified:false,abandoned:true,...options});assert.equal((await h.run('123456')).statusCode,409);
  assert.equal(h.calls.some(c=>c.kind==='AdminSetUserPasswordCommand'),false);
 }
});
