import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/models/wave_offer.dart';
Map<String,dynamic> money(int minor)=>{'moneySchemaVersion':1,'currency':'IQD','scale':1000,'minorAmount':minor};
Map<String,dynamic> offer()=>{
 'schemaVersion':1,'kind':'DRIVER_OFFER_PROPOSAL','offerId':'FINO:abc','offerDigest':'a'*64,'orderId':'order_with_underscores',
 'branchId':'branch1','waveNumber':2,'paymentMethod':'COD','pickupLocation':{'latitude':31.9,'longitude':44.4},'deliveryZoneId':'zone1',
 'createdAt':'2026-10-16T12:00:00.000Z','expiresAt':'2026-10-16T12:01:00.000Z','totalDistanceMeters':4000,'totalDurationSeconds':600,
 'customerCashToCollect':money(14500125),'driverEarning':money(3000125),'driverTip':money(1000000),'driverTotalEntitlement':money(4000125),
 'driverWalletHold':money(10500000),'driverCashRetained':money(4000125),'laterWalletEarningCredit':money(0),'laterWalletTipCredit':money(0),
};
void main(){
 test('financial Money bypasses legacy magnitude normalization and preserves the contract',(){
  final raw=offer(),model=WaveOffer.fromJson(raw);expect(model.orderTotal,14500.125);expect(model.deliveryFee,3000.125);
  expect(model.estimatedEarnings,4000.125);expect(model.holdRequiredAmount,10500);expect(model.waveNumber,2);expect(model.orderId,'order_with_underscores');
  expect(model.toJson(),raw);expect(model.financialTerms, isNotNull);
 });
 test('invalid scale, schema, prepaid and inconsistent entitlement are rejected',(){
  for(final mutation in <void Function(Map<String,dynamic>)>[
   (v)=>v['driverWalletHold']['scale']=1,(v)=>v['driverEarning']['minorAmount']=-1,
   (v)=>v['schemaVersion']=2,(v)=>v['paymentMethod']='PREPAID',(v)=>v['driverTotalEntitlement']=money(1),
  ]){final value=offer();mutation(value);expect(()=>WaveOffer.fromJson(value),throwsFormatException);}
 });
}
