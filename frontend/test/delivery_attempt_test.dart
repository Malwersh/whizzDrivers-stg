import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wizz_driver/features/active_order/models/active_order_model.dart';
import 'package:wizz_driver/features/active_order/screens/delivery_attempt_screen.dart';
import 'package:wizz_driver/features/active_order/services/delivery_attempt_service.dart';

final order = ActiveOrder.fromJson({
  'orderId': 'order1',
  'status': 'arrived_at_customer',
  'customerPhone': '+9647800000000',
  'financialAssignment': {
    'offerId': 'offer1',
    'attempt': 1,
    'exceptionPolicyVersion': 'OECSR_STAGING_COD_V1'
  },
  'items': []
});
Map<String, dynamic> view({bool eligible = false, int count = 0}) => {
      'success': true,
      'orderId': 'order1',
      'attemptId': 'ATT:1',
      'state': 'WAITING',
      'serverNow': '2026-10-20T12:00:00Z',
      'deadlineAt': eligible ? '2026-10-20T11:59:59Z' : '2026-10-20T12:10:00Z',
      'nextContactAt': '2026-10-20T12:00:00Z',
      'requiredContactAttempts': 3,
      'contactCount': count,
      'noResponseEligible': eligible
    };
void main() {
  test('transport binds credential and selectors and refuses replaced login',
      () async {
    var token = 'first';
    final api = DeliveryAttemptService(
        token: () async => token,
        client: MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer first');
          expect(r.url.queryParameters, {'offerId': 'offer1', 'attempt': '1'});
          token = 'second';
          return http.Response(jsonEncode(view()), 200);
        }));
    await expectLater(
        api.send('order1', order.financialAssignment!), throwsException);
  });
  testWidgets(
      'server deadline drives countdown; no-response return remains blocked before eligibility',
      (t) async {
    var elapsed = Duration.zero;
    final api = DeliveryAttemptService(
        token: () async => 'token',
        client:
            MockClient((r) async => http.Response(jsonEncode(view()), 200)));
    await t.pumpWidget(MaterialApp(
        home: DeliveryAttemptScreen(
            order: order, service: api, elapsed: () => elapsed)));
    await t.pumpAndSettle();
    expect(find.text('الانتظار المتبقي: 10:00'), findsOneWidget);
    final button = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'متابعة إرجاع الطلب لعدم الرد'));
    expect(button.onPressed, isNull);
    elapsed = const Duration(seconds: 2);
    await t.pump(const Duration(seconds: 2));
    expect(find.text('الانتظار المتبقي: 9:58'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'failed dialer records nothing; lost acknowledgement retries the same event without redial',
      (t) async {
    var calls = 0, posts = 0;
    String? id;
    final api = DeliveryAttemptService(
        token: () async => 'token',
        client: MockClient((r) async {
          if (r.method == 'GET') return http.Response(jsonEncode(view()), 200);
          posts++;
          final body = jsonDecode(r.body);
          expect(body['channel'], 'CALL_INITIATED');
          if (id == null) {
            id = body['eventId'];
            return http.Response('{"code":"TEMPORARY"}', 409);
          }
          expect(body['eventId'], id);
          return http.Response(jsonEncode(view(count: 1)), 200);
        }));
    await t.pumpWidget(MaterialApp(
        home: DeliveryAttemptScreen(
            order: order,
            service: api,
            call: (_) async {
              calls++;
              return calls > 1;
            })));
    await t.pumpAndSettle();
    await t.tap(find.text('الاتصال بالزبون وتسجيل المحاولة'));
    await t.pumpAndSettle();
    expect(posts, 0);
    await t.tap(find.text('الاتصال بالزبون وتسجيل المحاولة'));
    await t.pumpAndSettle();
    expect(posts, 1);
    await t.tap(find.text('إعادة تأكيد تسجيل المحاولة'));
    await t.pumpAndSettle();
    expect(posts, 2);
    expect(calls, 2);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('GPS starts once with actual position and response from server',
      (t) async {
    var started = false;
    final point = {
      'latitude': 31.0,
      'longitude': 44.0,
      'accuracyMeters': 20,
      'capturedAt': '2026-10-20T12:00:00Z'
    };
    final api = DeliveryAttemptService(
        token: () async => 'token',
        client: MockClient((r) async {
          if (r.method == 'POST') {
            expect(jsonDecode(r.body)['position'], point);
            started = true;
            return http.Response(jsonEncode(view()), 200);
          }
          return http.Response(
              '{"success":true,"orderId":"order1","exists":false}', 200);
        }));
    await t.pumpWidget(MaterialApp(
        home: DeliveryAttemptScreen(
            order: order, service: api, locate: () async => point)));
    await t.pumpAndSettle();
    await t.tap(find.text('تأكيد الوصول وبدء الانتظار'));
    await t.pumpAndSettle();
    expect(started, true);
    expect(find.text('الانتظار المتبقي: 10:00'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
