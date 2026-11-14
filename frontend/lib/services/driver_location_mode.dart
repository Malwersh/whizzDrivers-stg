import '../config/environment.dart';
import '../providers/driver_auth_provider.dart';

/// Client test override is explicit, staging-only and identity-specific.
/// Server authorization/location checks remain authoritative.
class DriverLocationMode {
  static bool allows(
          {required bool enabled,
          required bool production,
          required String environment,
          required String configuredDriverId,
          required String? driverId}) =>
      enabled &&
      !production &&
      environment == 'staging' &&
      configuredDriverId.isNotEmpty &&
      driverId == configuredDriverId;
  static Future<bool> usesFixedTestPosition() async {
    if (!Environment.useTestLocation ||
        Environment.isProduction ||
        Environment.environment != 'staging' ||
        Environment.testLocationDriverId.isEmpty) return false;
    return allows(
        enabled: Environment.useTestLocation,
        production: Environment.isProduction,
        environment: Environment.environment,
        configuredDriverId: Environment.testLocationDriverId,
        driverId: await DriverAuthHelper.getCurrentDriverId());
  }
}
