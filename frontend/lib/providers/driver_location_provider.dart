// Driver Location Provider - Enhanced for Spark-style interface
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../config/environment.dart';

/// Model for driver location
class DriverLocation {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const DriverLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  DriverLocation copyWith({
    double? latitude,
    double? longitude,
    DateTime? timestamp,
  }) {
    return DriverLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Driver location notifier
class DriverLocationNotifier extends StateNotifier<DriverLocation?> {
  DriverLocationNotifier() : super(null);

  /// Update driver location
  void updateLocation(double latitude, double longitude) {
    state = DriverLocation(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
    );
  }

  /// Get current position and update location
  Future<void> getCurrentLocation() async {
    try {
      if (Environment.useTestLocation) {
        updateLocation(Environment.testLatitude, Environment.testLongitude);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      updateLocation(position.latitude, position.longitude);
    } catch (e) {
      // Handle error silently
    }
  }

  /// Clear location
  void clearLocation() {
    state = null;
  }
}

/// Provider for driver location
final driverLocationProvider = StateNotifierProvider<DriverLocationNotifier, DriverLocation?>((ref) {
  return DriverLocationNotifier();
});
