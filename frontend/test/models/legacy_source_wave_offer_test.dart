import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/models/wave_offer.dart';
import 'package:wizz_driver/services/push_notifications_service.dart';
Map<String,dynamic> offer() => {
 'legacySourceVersion':1,'moneyUnit':'IQD_WHOLE','currency':'IQD',
 'offerId':'offer1','orderId':'order1','jobId':'dispatch1','dispatchCycleId':'cycle1',
 'orderTotal':104500,'holdRequiredAmount':100000,'deliveryFee':3000,
 'tip':1500,'bonusAmount':0,'estimatedEarnings':4500,
 'sentAt':'2026-10-16T12:00:00.000Z','expiresAt':'2026-10-16T12:01:30.000Z',
};
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('explicit whole IQD keeps large amounts and tip exactly once through serialization',(){
  final o=WaveOffer.fromJson(offer());
  expect(o.orderTotal,104500);expect(o.requiredBalanceAmount,100000);
  expect(o.tip,1500);expect(o.estimatedEarnings,4500);
  final copy=WaveOffer.fromJson(o.toJson());
  expect(copy.orderTotal,104500);expect(copy.tip,1500);expect(copy.moneyUnit,'IQD_WHOLE');
 });
 test('explicit zero fee and zero reservation are preserved independently of checkout',(){
  final o=WaveOffer.fromJson({...offer(),'holdRequiredAmount':0,'orderTotal':1500,'deliveryFee':0,'estimatedEarnings':1500});
  expect(o.deliveryFee,0);expect(o.requiredBalanceAmount,0);
 });
 test('mixed units, unknown source, missing or inconsistent cash terms fail closed',(){
  for(final changes in [ {'moneyUnit':'IQD_MINOR'}, {'legacySourceVersion':2}, {'currency':'USD'},
   {'estimatedEarnings':6000}, {'tip':null}, {'bonusAmount':1}, {'holdRequiredAmount':-1},
   {'orderTotal':104500.5}, {'isEmergencyWave':true}, {'deliveryFee':'3,000'},
   {'legacySourceVersion':null}, {'moneyUnit':null}]){
    expect(()=>WaveOffer.fromJson({...offer(),...changes}),throwsFormatException);
  }
 });
 test('flat FCM numeric strings retain explicit amounts and all source markers in cached tap',()async{
  SharedPreferences.setMockInitialValues({});
  final data={for(final e in offer().entries)e.key:e.value.toString(),
   'type':'new_wave_offer','action':'wave_assignment','driverId':'driver1','waveNumber':'1'};
  await PushNotificationsService.stashWaveOfferFromTap(RemoteMessage(data:data));
  final cached=(await PushNotificationsService.consumeStashedWaveOfferFromTap())!;
  expect(cached['tip'],'1500');expect(cached['holdRequiredAmount'],'100000');
  expect(cached['legacySourceVersion'],'1');expect(cached['moneyUnit'],'IQD_WHOLE');
  expect(WaveOffer.fromJson({...offer(),
   for (final field in ['legacySourceVersion','moneyUnit','currency','orderTotal',
    'holdRequiredAmount','deliveryFee','tip','bonusAmount','estimatedEarnings']) field:cached[field],
  }).orderTotal,104500);
 });
}
