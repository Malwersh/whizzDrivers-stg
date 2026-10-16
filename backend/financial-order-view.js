'use strict';
// Read only the accepted public amounts; never guess a unit or expose the internal allocation.
function financialOrderPricing(order) {
 if(!Object.prototype.hasOwnProperty.call(order,'financialSnapshot'))return null;
 const terms=order.financialAcceptance,a=terms?.allocation;
 if(terms?.schemaVersion!==1||terms.paymentMethod!=='COD'||a?.ruleVersion!=='ORDER_ALLOCATION_V1'||a.paymentMethod!=='COD')throw Error('FINANCIAL_ORDER_VIEW_UNAVAILABLE');
 const amount=v=>{
  if(v?.currency!=='IQD'||v.scale!==1000||v.moneySchemaVersion!==1||!Number.isSafeInteger(v.minorAmount)||v.minorAmount<0)throw Error('FINANCIAL_ORDER_VIEW_UNAVAILABLE');
  return v.minorAmount/1000;
 };
 return {schemaVersion:2,goodsSubtotal:amount(a.customerGoodsPayment),deliveryFee:amount(terms.customerDeliveryFee),tip:amount(a.driverTipEntitlement),
  total:amount(a.customerTotal),driverEarnings:amount(a.driverTotalEntitlement),driverEarning:amount(a.driverEarningEntitlement),
  holdRequiredAmount:amount(a.driverWalletHold),driverCashRetained:amount(a.driverCashRetained),laterWalletCredit:amount(a.driverWalletCreditTotal)};
}
module.exports={financialOrderPricing};
