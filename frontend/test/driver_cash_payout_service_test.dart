import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/services/driver_cash_payout_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'uncertain response persists the operation; retry uses the same request id and bound driver',
      () async {
    final bodies = <Map<String, dynamic>>[];
    var fail = true;
    final client = MockClient((r) async {
      bodies.add(jsonDecode(r.body));
      if (fail) return http.Response('{}', 503);
      return http.Response(
          '{"success":true,"payout":{"status":"UNDER_REVIEW"}}', 200);
    });
    final api = DriverCashPayoutService(
        transport: client,
        userReader: () async => 'driver1',
        tokenReader: () async => 'test-token');
    await expectLater(
        api.call({'action': 'REQUEST', 'amountIqd': 5000}, mutation: true),
        throwsException);
    fail = false;
    await api.retryPending();
    expect(bodies.length, 2);
    expect(bodies[0]['requestId'], bodies[1]['requestId']);
    expect(bodies[1]['driverId'], 'driver1');
    expect(
        (await SharedPreferences.getInstance())
            .getString('driver_cash_payout_pending_v1_driver1'),
        isNull);
  });
  test('different mutation is blocked while prior result is uncertain',
      () async {
    var calls = 0;
    final api = DriverCashPayoutService(
        transport: MockClient((r) async {
          calls++;
          return http.Response('{}', 503);
        }),
        userReader: () async => 'driver1',
        tokenReader: () async => 'test-token');
    await expectLater(
        api.call({'action': 'REQUEST', 'amountIqd': 5000}, mutation: true),
        throwsException);
    await expectLater(
        api.call({'action': 'REQUEST', 'amountIqd': 6000}, mutation: true),
        throwsException);
    expect(calls, 1);
  });
  test('account change between reading user and token cannot send a mutation',
      () async {
    var reads = 0, calls = 0;
    final api = DriverCashPayoutService(
        transport: MockClient((r) async {
          calls++;
          return http.Response('{"success":true}', 200);
        }),
        userReader: () async => ++reads == 1 ? 'driver1' : 'driver2',
        tokenReader: () async => 'other-token');
    await expectLater(
        api.call({'action': 'REQUEST', 'amountIqd': 5000}, mutation: true),
        throwsException);
    expect(calls, 0);
  });
}
