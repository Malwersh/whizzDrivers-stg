import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/services/wallet_funding_service.dart';
import 'package:wizz_driver/features/wallet/screens/topup_screen.dart';
import 'wallet_funding_service_test.dart' show token, payload;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'pending funding shows immutable recovery and hides editable transfer form at320px',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = WalletFundingService(
        token: () async => token('driverA'),
        client: MockClient((req) async {
          if (req.method == 'POST') throw TimeoutException('unknown');
          return http.Response(
              jsonEncode(req.url.path.endsWith('/funding/config')
                  ? {
                      'version': 1,
                      'manual': {'enabled': true, 'phone': '07800000000'}
                    }
                  : {'requests': []}),
              200);
        }));
    await api.initialize();
    await expectLater(api.submit(payload: payload('driverA')),
        throwsA(isA<TimeoutException>()));
    await tester.pumpWidget(MaterialApp(home: TopupScreen(service: api)));
    await tester.pumpAndSettle();
    expect(find.text('إعادة إرسال الطلب نفسه'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('إرسال طلب الشحن'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'switching account while loading clears previous recipient and form',
      (tester) async {
    var current = token('driverA');
    final api = WalletFundingService(
        token: () async => current,
        client: MockClient((req) async {
          current = token('driverB');
          return http.Response(
              jsonEncode({
                'version': 1,
                'manual': {'enabled': true, 'phone': 'private-recipient'}
              }),
              200);
        }));
    await tester.pumpWidget(MaterialApp(home: TopupScreen(service: api)));
    await tester.pumpAndSettle();
    expect(find.textContaining('تغير الحساب'), findsOneWidget);
    expect(find.textContaining('private-recipient'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
