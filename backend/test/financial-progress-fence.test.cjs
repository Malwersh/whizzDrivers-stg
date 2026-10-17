'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const policy=require('../legacy-order-policy');
const source=fs.readFileSync(process.env.DRIVER_HANDLER_FILE||'backend/lambda_driver_api_v2.js','utf8');
for(const name of ['startHeadingToStore','arriveAtStore','pickupOrder','startHeadingToCustomer','arriveAtCustomer'])test(name+' uses conditional financial progress and keeps both status fields aligned',async()=>{
 const start=source.indexOf('async function '+name+'('),end=source.indexOf('\nasync function ',start+20);let captured,fail=false;
 class UpdateCommand{constructor(input){this.input=input;}}
 const ctx={console:{log(){},error(){},warn(){}},require:n=>{assert.equal(n,'./legacy-order-policy');return policy;},UpdateCommand,ORDERS_TABLE:'orders',getDriverInfo:async()=>null,getOrderById:async()=>({statusCode:200}),dynamodb:{async send(c){captured=c.input;if(fail)throw Object.assign(Error('race'),{name:'ConditionalCheckFailedException'});return {};}}};
 vm.runInNewContext(source.slice(start,end)+'\nthis.run='+name,ctx);assert.equal((await ctx.run('d','o',{})).statusCode,200);
 assert.match(captured.UpdateExpression,/orderStatus = :status/);assert.match(captured.ConditionExpression,/driverId = :driverId AND/);assert.match(captured.ConditionExpression,/attribute_not_exists\(financialOutcome\)/);assert.equal(captured.ExpressionAttributeValues[':lfSchema'],1);
 fail=true;assert.equal((await ctx.run('d','o',{})).statusCode,409);
});
