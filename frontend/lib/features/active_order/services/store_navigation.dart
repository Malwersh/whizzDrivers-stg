import '../../../config/environment.dart';
import '../../../services/driver_location_mode.dart';

/// A test origin provides a driving preview. It cannot change the GPS of Maps.
class StoreNavigation {
  static Uri directions(
      {required double latitude,
      required double longitude,
      required bool testOrigin}) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) throw ArgumentError('Invalid destination');
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
      'travelmode': 'driving',
      if (testOrigin)
        'origin': '${Environment.testLatitude},${Environment.testLongitude}',
      if (!testOrigin) 'dir_action': 'navigate',
    });
  }

  static Future<Uri> forStore(double latitude, double longitude) async =>
      directions(
          latitude: latitude,
          longitude: longitude,
          testOrigin: await DriverLocationMode.usesFixedTestPosition());
}
