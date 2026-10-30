import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/services/trips_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'filters/cursor preserve authorization without accepting a driver selector',
      () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.url.queryParameters['driverId'], isNull);
      expect(request.url.queryParameters['status'], 'returned');
      expect(request.url.queryParameters['nextToken'], 'cursor');
      expect(request.url.queryParameters['from'], '2026-10-01T00:00:00.000Z');
      return http.Response(
          jsonEncode({
            'success': true,
            'trips': [],
            'hasMore': true,
            'nextToken': 'next'
          }),
          200);
    });
    final result = await TripsService.fetchDriverTrips(
        driverId: 'untrusted',
        status: 'returned',
        nextToken: 'cursor',
        from: DateTime.utc(2026, 10, 1),
        to: DateTime.utc(2026, 10, 22),
        client: client);
    expect(result['hasMore'], isTrue);
    expect(result['nextToken'], 'next');
  });
  test('changed login cannot publish history response', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'old'});
    final client = MockClient((_) async {
      await (await SharedPreferences.getInstance())
          .setString('auth_token', 'new');
      return http.Response('{"success":true,"trips":[],"hasMore":false}', 200);
    });
    expect((await TripsService.fetchDriverTrips(client: client))['success'],
        isFalse);
  });
  test('detail rejects another order receipt', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'token'});
    final client = MockClient((_) async =>
        http.Response('{"success":true,"trip":{"orderId":"other"}}', 200));
    await expectLater(
        TripsService.fetchTrip('order1', client: client), throwsException);
  });
}
