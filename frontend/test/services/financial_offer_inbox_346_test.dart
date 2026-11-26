import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/services/financial_offer_inbox.dart';
import 'package:wizz_driver/services/push_notifications_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
Map<String,dynamic> ref(String id,{String owner='driver'})=>{'financialPushVersion':1,'orderId':'order-$id','offerId':id,'waveNumber':1,'dispatchDriverId':owner,'driverId':owner,'cycleId':'cycle','expiresAt':DateTime.now().toUtc().add(const Duration(minutes:1)).toIso8601String(),'offerDigest':List.filled(64,'a').join()};
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 setUp(()=>SharedPreferences.setMockInitialValues({}));
 test('foreground push immediately emits a persisted reference without a tap',()async{final event=FinancialOfferInbox.events.first;await PushNotificationsService.stashWaveOfferFromTap(RemoteMessage(data:{...ref('one'),'type':'financial_wave_offer_available'}));expect((await event)['offerId'],'one');expect((await FinancialOfferInbox.pending('driver')).single['offerId'],'one');});
 test('independent simultaneous offers survive and are owner-scoped',()async{await Future.wait([FinancialOfferInbox.record(ref('one')),FinancialOfferInbox.record(ref('two')),FinancialOfferInbox.record(ref('foreign',owner:'other'))]);expect((await FinancialOfferInbox.pending('driver')).map((r)=>r['offerId']).toSet(),{'one','two'});expect((await FinancialOfferInbox.pending('other')).single['offerId'],'foreign');});
 test('expiry is original and invalid metadata cannot produce a display event',()async{var count=0;final sub=FinancialOfferInbox.events.listen((_)=>count++);await expectLater(FinancialOfferInbox.record({...ref('expired'),'expiresAt':'2020-01-01T00:00:00Z'}),throwsFormatException);expect(count,0);expect(await FinancialOfferInbox.pending('driver'),isEmpty);await sub.cancel();});
 test('removing one offer never clears another offer or another account',()async{final first=ref('one'),second=ref('two');await FinancialOfferInbox.record(first);await FinancialOfferInbox.record(second);await FinancialOfferInbox.remove(first);expect((await FinancialOfferInbox.pending('driver')).single['offerId'],'two');await FinancialOfferInbox.clear();expect(await FinancialOfferInbox.pending('driver'),isEmpty);});
}
