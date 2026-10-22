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

test('delivery funding allocation V2 remains readable after acceptance',()=>{
 const order=fixture();order.financialAcceptance.schemaVersion=2;order.financialAcceptance.allocation.ruleVersion='ORDER_ALLOCATION_V2_DELIVERY_FUNDING';
 assert.equal(view(order).total,14500);assert.equal(view(order).holdRequiredAmount,10500);
 order.financialAcceptance.allocation.ruleVersion='UNKNOWN';assert.throws(()=>view(order));
});
test('full cash pricing is explicit and rejects inconsistent retained cash',()=>{
 const old=process.env.FINANCIAL_SETTLEMENT_MODEL;
 try{
  const o=fixture(),t=o.financialAcceptance;t.schemaVersion=3;t.settlementModel='FULL_CASH_AT_DELIVERY_V1';t.allocation.ruleVersion='ORDER_ALLOCATION_V3_FULL_CASH';
  assert.throws(()=>view(o));process.env.FINANCIAL_SETTLEMENT_MODEL='FULL_CASH_AT_DELIVERY_V1';
  t.allocation.driverCashRetained=m(5000);t.allocation.driverWalletHold=m(9500);t.allocation.driverWalletCreditTotal=m(0);
  assert.equal(view(o).driverCashRetained,5000);assert.equal(view(o).holdRequiredAmount,9500);
  t.allocation.driverWalletHold=m(10500);assert.throws(()=>view(o));
 }finally{if(old===undefined)delete process.env.FINANCIAL_SETTLEMENT_MODEL;else process.env.FINANCIAL_SETTLEMENT_MODEL=old;}
});
