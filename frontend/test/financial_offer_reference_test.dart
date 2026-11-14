import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wizz_driver/services/financial_offer_reference.dart';
import 'package:wizz_driver/services/push_notifications_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> reference() => {
  'financialPushVersion': '1', 'orderId': 'order', 'offerId': 'FINO:offer',
  'waveNumber': '2', 'dispatchDriverId': 'driver', 'driverId': 'driver',
  'cycleId': 'cycle', 'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 2)).toIso8601String(),
  'offerDigest': List.filled(64, 'a').join(),
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reference survives consumption for network retry and clears only the matching offer', () async {
    SharedPreferences.setMockInitialValues({});
    final ref = reference();
    await PushNotificationsService.stashWaveOfferFromTap(RemoteMessage(data: {...ref, 'type': 'financial_wave_offer_available'}));
    final first = await PushNotificationsService.consumeStashedWaveOfferFromTap();
    expect(first?['offerId'], ref['offerId']);
    expect((await PushNotificationsService.consumeStashedWaveOfferFromTap())?['offerId'], ref['offerId']);
    await PushNotificationsService.clearStashedFinancialOffer({...ref, 'offerId': 'other'});
    expect(await PushNotificationsService.consumeStashedWaveOfferFromTap(), isNotNull);
    await PushNotificationsService.clearStashedFinancialOffer(ref);
    expect(await PushNotificationsService.consumeStashedWaveOfferFromTap(), isNull);
  });
  test('hydrates financial details from authenticated server response, not push prices', () async {
    final ref = reference();
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/driver/financial-wave-offer'));
      expect(request.headers['Authorization'], 'Bearer credential');
      final body = jsonDecode(request.body);
      expect(body['waveNumber'], 2); expect(body.containsKey('price'), false);
      return http.Response(jsonEncode({'success': true, 'message': {'type': 'financial_wave_offer', 'eventId': ref['offerId'], 'offer': {
        'offerId': ref['offerId'], 'orderId': 'order', 'waveNumber': 2,
        'expiresAt': ref['expiresAt'], 'offerDigest': ref['offerDigest'],
        'display': {'items': [{'name': 'item', 'quantity': 2}]},
      }}}), 200);
    });
    final offer = await FinancialOfferReference.hydrate({...ref, 'price': 0}, 'driver', client: client, token: () async => 'credential');
    expect(offer['display']['items'][0]['quantity'], 2);
  });
  test('foreign account and expired reference do not issue a network request', () async {
    var calls = 0;
    final client = MockClient((_) async { calls++; return http.Response('{}', 200); });
    await expectLater(FinancialOfferReference.hydrate(reference(), 'other', client: client, token: () async => 'credential'), throwsFormatException);
    expect(() => FinancialOfferReference.read({...reference(), 'expiresAt': '2020-01-01T00:00:00.000Z'}), throwsFormatException);
    expect(calls, 0);
  });
  test('session switch while fetching and changed response identity are rejected', () async {
    var credential = 'first';
    final client = MockClient((_) async { credential = 'second'; return http.Response('{}', 200); });
    await expectLater(FinancialOfferReference.hydrate(reference(), 'driver', client: client, token: () async => credential), throwsStateError);
    final ref = reference();
    final changed = MockClient((_) async => http.Response(jsonEncode({'success': true, 'message': {'type': 'financial_wave_offer', 'eventId': 'other', 'offer': {}}}), 200));
    await expectLater(FinancialOfferReference.hydrate(ref, 'driver', client: changed, token: () async => 'credential'), throwsFormatException);
  });
}
