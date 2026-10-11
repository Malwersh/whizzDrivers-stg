import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/services/trips_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildHeadersForProtectedRequest includes Authorization when token exists', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});

    final headers = await TripsService.buildHeadersForProtectedRequest();

    expect(headers.containsKey('Content-Type'), isTrue);
    expect(headers['Content-Type'], 'application/json');
    expect(headers.containsKey('Authorization'), isTrue);
    expect(headers['Authorization'], 'Bearer test-token');
  });
}
