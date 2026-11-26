import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/services/wallet_funding_service.dart';
import 'package:wizz_driver/services/zaincash_funding_service.dart';
import 'package:wizz_driver/features/wallet/screens/zaincash_payment_screen.dart';

String token(String sub) => 'header.${base64Url.encode(utf8.encode(jsonEncode({
          'sub': sub
        })))}.signature';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  ZaincashFundingService service(http.Client client,
          {String Function()? subject}) =>
      ZaincashFundingService(
          transport: WalletFundingService(
              client: client,
              token: () async => token(subject?.call() ?? 'driver')));
  test(
      'restart and timeout retain exact immutable attempt; success clears account-scoped draft',
      () async {
    Map<String, dynamic>? first;
    int calls = 0;
    final client = MockClient((r) async {
      calls++;
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      first ??= b;
      expect(b, first);
      if (calls == 1) throw Exception('lost');
      return http.Response(jsonEncode({...b, 'state': 'SUCCESS'}), 200);
    });
    final s = service(client);
    await s.initialize();
    await expectLater(s.pay(25000), throwsException);
    expect(s.pending, first);
    final reopened = service(client);
    await reopened.initialize();
    expect(reopened.pending, first);
    await reopened.pay(50000);
    expect(reopened.pending, isNull);
  });
  test('another account cannot see draft or receive an old in-flight response',
      () async {
    String sub = 'driver';
    final s = service(MockClient((r) async {
      sub = 'other';
      return http.Response(r.body, 200);
    }), subject: () => sub);
    await s.initialize();
    await expectLater(s.pay(25000), throwsA(isA<FundingSessionChanged>()));
    final other = service(MockClient((_) async => http.Response('{}', 200)),
        subject: () => sub);
    await other.initialize();
    expect(other.pending, isNull);
  });
  test(
      'unknown retry plus later disabled error keeps draft; first definite rejection clears it',
      () async {
    int count = 0;
    final s = service(MockClient((r) async {
      if (count++ == 0) throw Exception('timeout');
      return http.Response(
          jsonEncode({
            'error': {'code': 'METHOD_DISABLED', 'message': 'disabled'}
          }),
          409);
    }));
    await s.initialize();
    await expectLater(s.pay(25000), throwsException);
    await expectLater(s.pay(25000), throwsA(isA<FundingRejected>()));
    expect(s.pending, isNotNull);
    SharedPreferences.setMockInitialValues({});
    final fresh = service(MockClient((r) async => http.Response(
        jsonEncode({
          'error': {'code': 'METHOD_DISABLED', 'message': 'disabled'}
        }),
        409)));
    await fresh.initialize();
    await expectLater(fresh.pay(25000), throwsA(isA<FundingRejected>()));
    expect(fresh.pending, isNull);
  });
  test('mismatched response never clears a saved attempt', () async {
    final s = service(MockClient((r) async => http.Response(
        jsonEncode({'requestId': 'wrong', 'amount': 25000, 'state': 'SUCCESS'}),
        200)));
    await s.initialize();
    await expectLater(s.pay(25000), throwsException);
    expect(s.pending, isNotNull);
  });
  testWidgets(
      '320px UAT screen clearly separates test balance and history without overflow',
      (tester) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = service(MockClient((r) async => http.Response(
        jsonEncode(r.url.path.endsWith('/config')
            ? {
                'enabled': true,
                'mode': 'UAT',
                'minimum': 25000,
                'maximum': 500000
              }
            : {
                'payments': [
                  {
                    'requestId': '11111111-1111-4111-8111-111111111111',
                    'amount': 25000,
                    'mode': 'UAT',
                    'state': 'SUCCESS',
                    'createdAt': '2026-10-24'
                  }
                ]
              }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'})));
    await tester
        .pumpWidget(MaterialApp(home: ZaincashPaymentScreen(service: s)));
    await tester.pumpAndSettle();
    expect(find.textContaining('بيئة اختبار'), findsOneWidget);
    expect(find.textContaining('الرصيد الفعلي لم يتغير'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
