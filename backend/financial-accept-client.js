'use strict';
const {LambdaClient,InvokeCommand}=require('@aws-sdk/client-lambda');
const TARGET='arn:aws:lambda:us-east-1:699561669180:function:staging-driver-financial-accept';
// Drivers API only invokes the financial writer. It never acquires wallet mutation permissions.
async function invokeFinancialOperation(body,accessToken,action,client=new LambdaClient({region:'us-east-1'})) {
 if(!['accept','decline','complete_cod','request_return','arrive_return','unassign_financial'].includes(action))throw Error('INVALID_FINANCIAL_ACTION');
 if(action==='unassign_financial'&&process.env.FINANCIAL_COD_ASSIGNMENTS_MODE!=='REQUIRED')throw Error('COD_ASSIGNMENTS_DISABLED');
 if(['request_return','arrive_return'].includes(action)&&process.env.FINANCIAL_COD_RETURNS_MODE!=='REQUIRED')throw Error('COD_RETURNS_DISABLED');
 if(action==='complete_cod'&&process.env.FINANCIAL_COD_COMPLETION_MODE!=='REQUIRED')throw Error('COD_COMPLETION_DISABLED');
 if(process.env.FINANCIAL_DISPATCH_MODE!=='REQUIRED'||process.env.FINANCIAL_ACCEPT_FUNCTION_ARN!==TARGET)throw Error('FINANCIAL_DISPATCH_DISABLED');
 const result=await client.send(new InvokeCommand({FunctionName:TARGET,InvocationType:'RequestResponse',
  Payload:Buffer.from(JSON.stringify({action,body,accessToken}))}));
 if(result.FunctionError)throw Error('FINANCIAL_ACCEPTANCE_UNAVAILABLE');
 let response;try{response=JSON.parse(Buffer.from(result.Payload).toString());}catch{throw Error('FINANCIAL_ACCEPTANCE_UNAVAILABLE');}
 if(response.statusCode!==200||!response.result||response.result.success!==true)throw Object.assign(Error(response.code||'FINANCIAL_ACCEPTANCE_UNAVAILABLE'),{code:response.code});
 return response.result;
}
function invokeFinancialAcceptance(body,accessToken,decline=false,client){return invokeFinancialOperation(body,accessToken,decline?'decline':'accept',client);}
function invokeFinancialCompletion(body,accessToken,client){return invokeFinancialOperation(body,accessToken,'complete_cod',client);}
function invokeFinancialReturn(body,accessToken,action,client){if(!['request_return','arrive_return'].includes(action))throw Error('INVALID_COD_RETURN');return invokeFinancialOperation(body,accessToken,action,client);}
function invokeFinancialUnassign(body,accessToken,client){return invokeFinancialOperation(body,accessToken,'unassign_financial',client);}
module.exports={invokeFinancialAcceptance,invokeFinancialCompletion,invokeFinancialReturn,invokeFinancialUnassign};
