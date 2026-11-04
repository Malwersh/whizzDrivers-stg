import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/services/driver_search_api_service.dart';

void main() {
  test(
      'confirmed stop clears cached search and notifies home without restarting',
      () async {
    SharedPreferences.setMockInitialValues(
        {'isSearchingForOffers': true, 'searchEndTime': 'later'});
    final before = DriverSearchApiService.confirmedStopEvents.value;
    final r = await DriverSearchApiService.stopSearching(
        client: MockClient((request) async {
          expect(request.url.path.endsWith('/driver/stop-searching'), true);
          expect(request.headers['Authorization'], 'Bearer fixture');
          return http.Response('{"success":true}', 200);
        }),
        tokenProvider: () async => 'fixture');
    expect(r['success'], true);
    expect(DriverSearchApiService.confirmedStopEvents.value, before + 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('isSearchingForOffers'), false);
    expect(prefs.containsKey('searchEndTime'), false);
  });
  test('active-order rejection cannot clear cache or announce an offline state',
      () async {
    SharedPreferences.setMockInitialValues({'isSearchingForOffers': true});
    final before = DriverSearchApiService.confirmedStopEvents.value;
    final r = await DriverSearchApiService.stopSearching(
        client: MockClient((_) async =>
            http.Response('{"success":false,"message":"يوجد طلب جارٍ"}', 409)),
        tokenProvider: () async => 'fixture');
    expect(r['success'], false);
    expect(DriverSearchApiService.confirmedStopEvents.value, before);
    expect(
        (await SharedPreferences.getInstance()).getBool('isSearchingForOffers'),
        true);
  });
}
