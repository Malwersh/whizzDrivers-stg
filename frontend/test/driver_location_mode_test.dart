import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/services/driver_location_mode.dart';

void main() {
  bool allows(
          {bool enabled = true,
          bool production = false,
          String environment = 'staging',
          String configured = 'trial',
          String? driver = 'trial'}) =>
      DriverLocationMode.allows(
          enabled: enabled,
          production: production,
          environment: environment,
          configuredDriverId: configured,
          driverId: driver);
  test('fixed position is restricted to explicit staging test identity', () {
    expect(allows(), isTrue);
    expect(allows(driver: 'another-driver'), isFalse);
    expect(allows(driver: null), isFalse);
    expect(allows(configured: ''), isFalse);
    expect(allows(enabled: false), isFalse);
    expect(allows(production: true), isFalse);
    expect(allows(environment: 'production'), isFalse);
  });
}
