'use strict';
const {financialOrderPricing}=require('./financial-order-view');
const {pickupView}=require('./driver-trip-route');
const terminal=['delivered','completed','cancelled','canceled','returned'];
const finite=v=>typeof v==='number'&&Number.isFinite(v);
const address=v=>typeof v==='string'?v: v?.fullAddress||v?.addressLine1||v?.address||v?.formattedAddress||'';
function tripView(o,normalizeOrderPricingToIqd,toNumber){
 const financial=['financialSnapshot','commercialPricing','financialAcceptance','financialOutcome','codFinancialEvidence'].some(k=>o[k]!=null);
 const done=['delivered','completed'].includes(o.status);
 let earning=null,base=null,tip=null,earningsState='UNAVAILABLE',cashRetained=null,walletCredit=null;
 if(financial && done && o.financialOutcome && o.walletFinancialStatus==='SETTLED'){
  try {const p=financialOrderPricing(o);if(p){earning=p.driverEarnings;base=p.driverEarning;tip=p.tip;earningsState='CONFIRMED';if(!o.cashAdjudication){cashRetained=p.driverCashRetained;walletCredit=p.laterWalletCredit;}}}catch{/* Do not substitute customer tariff for unavailable financial evidence. */}
 } else if(!financial && done && finite(o.driverEarnings) && o.driverEarnings>=0){earning=o.driverEarnings;earningsState='RECORDED';}
 const pricing=normalizeOrderPricingToIqd(o);
 const rawTotal=toNumber(o.total??o.totalAmount,0),pt=toNumber(o.pricing?.total,0);
 const scale=(o.currency==='IQD'&&o.createdBy==='wizzuser_app')||(rawTotal>0&&pt/rawTotal>=900&&pt/rawTotal<=1100)?1000:1;
 const customerFee=o.pricing?.deliveryFee!=null?toNumber(o.pricing.deliveryFee,0)/scale:pricing.deliveryFee;
 const pickup=pickupView(o),accepted=o.financialAcceptance?.acceptedAt||o.assignedAt||o.acceptedAt||null;
 const ended=o.deliveredAt||o.completedAt||o.returnedAt||o.cancelledAt||o.canceledAt||null;
 const duration=Date.parse(ended)-Date.parse(accepted);
 return {tripId:o.orderId||o.PK.replace('ORDER#',''),orderId:o.orderId||o.PK.replace('ORDER#',''),orderNumber:o.orderNumber||'',tripNumber:o.tripNumber||o.trip_number||null,
  status:done?'completed':o.status==='returned'?'returned':'cancelled',driverEarnings:earning,driverBaseEarnings:base,driverTip:tip,earningsState,
  // Compatibility fields are customer tariff only, never used as driver earnings by the new UI.
  deliveryFee:customerFee,finalDeliveryFee:earning,tip:tip??0,waveBonus:0,
  cashCollectedAmount:o.cashCollected===true&&finite(o.cashCollectedAmount)?o.cashCollectedAmount:null,
  driverCashRetained:cashRetained,driverWalletCredit:walletCredit,
  settledCollateral:done&&o.holdStatus==='SETTLED'&&finite(o.holdAmount)?o.holdAmount:null,
  paymentMethod:o.paymentMethod||null,holdStatus:o.holdStatus||null,
  pickupLocation:o.pickupLocation||o.restaurantLocation||{lat:o.restaurantLat??o.pickupLatitude??null,lng:o.restaurantLng??o.pickupLongitude??null},
  deliveryLocation:o.deliveryLocation||{lat:o.deliveryAddress?.lat??o.customerLat??o.deliveryLatitude??null,lng:o.deliveryAddress?.lng??o.customerLng??o.deliveryLongitude??null},
  pickupAddress:pickup.restaurantAddress||address(o.pickupAddress),deliveryAddress:address(o.deliveryAddress)||address(o.customerAddress),restaurantName:pickup.restaurantName||'',customerName:o.customerName||o.deliveryName||'',
  createdAt:o.createdAt,completedAt:ended,acceptedAt:accepted,pickupTime:o.pickedUpAt||o.pickupAt||null,deliveryTime:o.deliveredAt||null,
  estimatedDistanceMeters:finite(o.financialAcceptance?.calculation?.totalDistanceMeters)?o.financialAcceptance.calculation.totalDistanceMeters:null,
  durationSeconds:Number.isFinite(duration)&&duration>=0?Math.round(duration/1000):null,
  itemCount:Array.isArray(o.items)?o.items.length:null,quantity:Array.isArray(o.items)?o.items.reduce((sum,v)=>sum+(Number.isInteger(v.quantity)&&v.quantity>=0?v.quantity:0),0):null,
  deliveryProofCount:Array.isArray(o.deliveryProofs)?o.deliveryProofs.length:0,hasReturnCase:!!o.returnCaseId,
 };
}
function historyFilter(query,driverId){
 const states={completed:['delivered','completed'],cancelled:['cancelled','canceled'],returned:['returned']};
 if(query.status && !states[query.status])throw Error('INVALID_STATUS');
 const values={':driverId':driverId,':meta':'META'},names={'#status':'status'};
 const status=(states[query.status]||terminal).map((s,i)=>{values[':s'+i]=s;return ':s'+i;});
 let filter='driverId = :driverId AND SK = :meta AND #status IN ('+status.join(',')+')';
 if(query.from || query.to){
  const from=Date.parse(query.from),to=Date.parse(query.to);if(!Number.isFinite(from)||!Number.isFinite(to)||from>to)throw Error('INVALID_RANGE');
  values[':from']=new Date(from).toISOString();values[':to']=new Date(to).toISOString();values[':null']=null;
  const times=['deliveredAt','completedAt','returnedAt','cancelledAt','canceledAt','createdAt'];
  const absent=k=>`(attribute_not_exists(${k}) OR ${k} = :null)`;
  filter+=' AND ('+times.map((t,i)=>'('+[...times.slice(0,i).map(absent),`${t} BETWEEN :from AND :to`].join(' AND ')+')').join(' OR ')+')';
 }
 return {FilterExpression:filter,ExpressionAttributeNames:names,ExpressionAttributeValues:values};
}
module.exports={tripView,historyFilter,terminal};
