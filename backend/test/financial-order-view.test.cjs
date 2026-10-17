const {test}=require('node:test'),assert=require('node:assert/strict');
const {financialOrderPricing:view}=require('../financial-order-view');
const m=n=>({currency:'IQD',scale:1000,moneySchemaVersion:1,minorAmount:n*1000});
const fixture=()=>({financialSnapshot:{},financialAcceptance:{schemaVersion:1,paymentMethod:'COD',customerDeliveryFee:m(3000),allocation:{ruleVersion:'ORDER_ALLOCATION_V1',paymentMethod:'COD',customerGoodsPayment:m(10000),customerTotal:m(14500),driverTipEntitlement:m(1000),driverTotalEntitlement:m(5000),driverEarningEntitlement:m(4000),driverWalletHold:m(10500),driverCashRetained:m(4000),driverWalletCreditTotal:m(1000),merchantCommission:m(1000)}}});
test('active financial order separates customer D from driver E, cash and H and never applies a magnitude heuristic',()=>{
 const result=view(fixture());assert.equal(result.total,14500);assert.equal(result.deliveryFee,3000);assert.equal(result.driverEarning,4000);assert.equal(result.driverEarnings,5000);assert.equal(result.holdRequiredAmount,10500);assert.equal(result.laterWalletCredit,1000);assert.equal(result.merchantCommission,undefined);
 assert.equal(view({}),null);
});
test('malformed explicit money and missing financial acceptance cannot fall back to legacy pricing',()=>{
 const order=fixture();order.financialAcceptance.allocation.customerTotal.scale=1;assert.throws(()=>view(order));assert.throws(()=>view({financialSnapshot:{},pricing:{total:14500}}));
});
