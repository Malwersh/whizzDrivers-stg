const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync(require.resolve('../lambda_driver_api_v2.js'),'utf8');
const functionText=name=>source.slice(source.indexOf(`async function ${name}(`),source.indexOf('\n}\n',source.indexOf(`async function ${name}(`))+2);
function reader(order){const context={console:{log(){},error(){}},GetCommand:class{constructor(input){this.input=input}},ORDERS_TABLE:'orders',DRIVER_LIVE_STATE_TABLE:'live',dynamodb:{send:async command=>({Item:command.input.TableName==='live'?{currentOrderId:order.orderId}:order})},require:path=>path==='./financial-order-view'?require('../financial-order-view'):{}};vm.createContext(context);vm.runInContext(functionText('getOrderById')+'\n'+functionText('getActiveOrder')+'\nglobalThis.read=getActiveOrder;',context);return context.read;}
test('assigned delivery-funded order is restored with accepted amounts',async()=>{
 const m=n=>({currency:'IQD',scale:1000,moneySchemaVersion:1,minorAmount:n*1000});
 const o={orderId:'order',driverId:'driver',status:'assigned',financialSnapshot:{},financialAcceptance:{schemaVersion:2,paymentMethod:'COD',customerDeliveryFee:m(1500),allocation:{ruleVersion:'ORDER_ALLOCATION_V2_DELIVERY_FUNDING',paymentMethod:'COD',customerGoodsPayment:m(7000),customerTotal:m(9500),driverTipEntitlement:m(500),driverTotalEntitlement:m(3250),driverEarningEntitlement:m(2750),driverWalletHold:m(7500),driverCashRetained:m(2000),driverWalletCreditTotal:m(1250)}}};
 const r=await reader(o)('driver',{});assert.equal(r.statusCode,200);const body=JSON.parse(r.body);assert.equal(body.hasActiveOrder,true);assert.equal(body.order.total,9500);
});
test('failed financial read is an error instead of an empty active order',async()=>{const r=await reader({orderId:'order',driverId:'driver',financialSnapshot:{}})('driver',{});assert.equal(r.statusCode,500);assert.equal(JSON.parse(r.body).hasActiveOrder,undefined);});
