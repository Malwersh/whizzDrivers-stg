const {test}=require('node:test'),assert=require('node:assert/strict');
const {invokeFinancialAcceptance:invoke}=require('../financial-accept-client');
const arn='arn:aws:lambda:us-east-1:699561669180:function:staging-driver-financial-accept';
test('financial client is disabled by default and cannot invoke a different target',async()=>{
 const old={...process.env};let calls=0;
 try{delete process.env.FINANCIAL_DISPATCH_MODE;await assert.rejects(invoke({},'test',false,{async send(){calls++;}}));
 process.env.FINANCIAL_DISPATCH_MODE='REQUIRED';process.env.FINANCIAL_ACCEPT_FUNCTION_ARN='other';await assert.rejects(invoke({},'test',false,{async send(){calls++;}}));assert.equal(calls,0);
 }finally{process.env=old;}
});
test('API forwards original credentials to the fixed financial writer without requesting a separate hold',async()=>{
 const old={...process.env};try{process.env.FINANCIAL_DISPATCH_MODE='REQUIRED';process.env.FINANCIAL_ACCEPT_FUNCTION_ARN=arn;
 const body={offerId:'FINO:1',orderId:'order_with_underscores',waveNumber:2};let calls=0;
 const result=await invoke(body,'test-access',false,{async send(c){calls++;assert.equal(c.input.FunctionName,arn);assert.equal(c.input.InvocationType,'RequestResponse');
  const payload=JSON.parse(Buffer.from(c.input.Payload));assert.deepEqual(payload,{action:'accept',body,accessToken:'test-access'});
  return {Payload:Buffer.from(JSON.stringify({statusCode:200,result:{success:true,holdId:'held-once',replayed:true}}))};}});
 assert.equal(calls,1);assert.equal(result.holdId,'held-once');assert.equal(result.accessToken,undefined);
 }finally{process.env=old;}
});
test('completion requires its own flag and invokes the same financial writer without legacy capture',async()=>{
 const {invokeFinancialCompletion}=require('../financial-accept-client'),old={...process.env};let calls=0;
 try{
  process.env.FINANCIAL_DISPATCH_MODE='REQUIRED';process.env.FINANCIAL_ACCEPT_FUNCTION_ARN=arn;delete process.env.FINANCIAL_COD_COMPLETION_MODE;
  const client={async send(c){calls++;assert.deepEqual(JSON.parse(Buffer.from(c.input.Payload)),{action:'complete_cod',body:{orderId:'order1',cashCollected:true},accessToken:'live-token'});return {Payload:Buffer.from(JSON.stringify({statusCode:200,result:{success:true,operationId:'cod1'}}))};}};
  await assert.rejects(invokeFinancialCompletion({orderId:'order1',cashCollected:true},'live-token',client));assert.equal(calls,0);
  process.env.FINANCIAL_COD_COMPLETION_MODE='REQUIRED';assert.equal((await invokeFinancialCompletion({orderId:'order1',cashCollected:true},'live-token',client)).operationId,'cod1');assert.equal(calls,1);
 }finally{process.env=old;}
});
test('driver return transport requires its flag and cannot invoke merchant confirmation',async()=>{
 const {invokeFinancialReturn}=require('../financial-accept-client'),old={...process.env};let calls=0;
 try{process.env.FINANCIAL_DISPATCH_MODE='REQUIRED';process.env.FINANCIAL_ACCEPT_FUNCTION_ARN=arn;delete process.env.FINANCIAL_COD_RETURNS_MODE;
 const client={async send(c){calls++;const p=JSON.parse(Buffer.from(c.input.Payload));assert.equal(p.action,'request_return');assert.equal(p.accessToken,'driver-token');return {Payload:Buffer.from(JSON.stringify({statusCode:200,result:{success:true,returnId:'ret1'}}))};}};
 const body={orderId:'order1',offerId:'offer1',attempt:1,reason:'CUSTOMER_REFUSED',cashCollected:false};
 await assert.rejects(invokeFinancialReturn(body,'driver-token','request_return',client));assert.equal(calls,0);
 process.env.FINANCIAL_COD_RETURNS_MODE='REQUIRED';assert.equal((await invokeFinancialReturn(body,'driver-token','request_return',client)).returnId,'ret1');
 await assert.rejects(async()=>invokeFinancialReturn(body,'driver-token','confirm_return',client));assert.equal(calls,1);
 }finally{process.env=old;}
});

test('financial unassignment has its own closed gate and forwards the frozen assignment to the fixed writer',async()=>{
 const {invokeFinancialUnassign}=require('../financial-accept-client'),old={...process.env};let calls=0;
 try{process.env.FINANCIAL_DISPATCH_MODE='REQUIRED';process.env.FINANCIAL_ACCEPT_FUNCTION_ARN=arn;delete process.env.FINANCIAL_COD_ASSIGNMENTS_MODE;
 const body={orderId:'order1',offerId:'offer1',attempt:2,cashCollected:false,reason:'VehicleIssue'};
 const client={async send(c){calls++;assert.equal(c.input.FunctionName,arn);assert.deepEqual(JSON.parse(Buffer.from(c.input.Payload)),{action:'unassign_financial',body,accessToken:'driver-original'});return {Payload:Buffer.from(JSON.stringify({statusCode:200,result:{success:true,replayed:true}}))};}};
 await assert.rejects(invokeFinancialUnassign(body,'driver-original',client),/COD_ASSIGNMENTS_DISABLED/);assert.equal(calls,0);
 process.env.FINANCIAL_COD_ASSIGNMENTS_MODE='REQUIRED';assert.equal((await invokeFinancialUnassign(body,'driver-original',client)).replayed,true);assert.equal(calls,1);
 }finally{process.env=old;}
});
