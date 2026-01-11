import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/environment.dart';

class LocationState {
  final Position? currentPosition;
  final bool isLocationServiceEnabled;
  final bool hasPermission;
  final bool isLoading;
  final String? errorMessage;

  const LocationState({
    this.currentPosition,
    this.isLocationServiceEnabled = false,
    this.hasPermission = false,
    this.isLoading = false,
    this.errorMessage,
  });

  LocationState copyWith({
    Position? currentPosition,
    bool? isLocationServiceEnabled,
    bool? hasPermission,
    bool? isLoading,
    String? errorMessage,
  }) {
    return LocationState(
      currentPosition: currentPosition ?? this.currentPosition,
      isLocationServiceEnabled:
          isLocationServiceEnabled ?? this.isLocationServiceEnabled,
      hasPermission: hasPermission ?? this.hasPermission,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  StreamSubscription<Position>? _positionStreamSubscription;

  LocationNotifier() : super(const LocationState()) {
    // Initialize automatically
    initialize();
  }

  @override
  void dispose() {
    _stopLocationUpdates();
    super.dispose();
  }

  Future<void> initialize() async {
    _setLoading(true);

    try {
      if (Environment.useTestLocation) {
        state = state.copyWith(
          isLocationServiceEnabled: true,
          hasPermission: true,
          currentPosition: Position(
            latitude: Environment.testLatitude,
            longitude: Environment.testLongitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ),
          errorMessage: null,
        );
        return;
      }
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      state = state.copyWith(isLocationServiceEnabled: serviceEnabled);

      if (!serviceEnabled) {
        _setError('خدمات الموقع غير مفعلة. يرجى تفعيلها للمتابعة.');
        _setLoading(false);
        return;
      }

      // Check location permission
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final hasPermission =
          permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;

      state = state.copyWith(hasPermission: hasPermission);

      if (!hasPermission) {
        _setError(
          'تم رفض إذن الوصول للموقع. بعض الميزات قد لا تعمل بشكل صحيح.',
        );
        _setLoading(false);
        return;
      }

      // Get the current position
      final position = await Geolocator.getCurrentPosition();
      state = state.copyWith(currentPosition: position, errorMessage: null);

      // Start listening to position updates
      startLocationUpdates();
    } catch (e) {
      _setError('خطأ في تهيئة خدمات الموقع: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  void startLocationUpdates() {
    // Cancel existing subscription if any
    _stopLocationUpdates();

    try {
      if (Environment.useTestLocation) {
        state = state.copyWith(
          currentPosition: Position(
            latitude: Environment.testLatitude,
            longitude: Environment.testLongitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ),
          errorMessage: null,
        );
        debugPrint(
          '📍 Test location active: ${Environment.testLatitude}, ${Environment.testLongitude}',
        );
        return;
      }
      // Get location updates
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update if moved 10 meters
      );

      _positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) {
              state = state.copyWith(
                currentPosition: position,
                errorMessage: null,
              );
              debugPrint(
                '📍 Location updated: ${position.latitude}, ${position.longitude}',
              );
            },
            onError: (dynamic error) {
              _setError('خطأ في تحديثات الموقع: ${error.toString()}');
              debugPrint('❌ Location stream error: $error');
            },
          );

      debugPrint('📍 Started location updates');
    } catch (e) {
      _setError('خطأ في بدء تحديثات الموقع: ${e.toString()}');
      debugPrint('❌ Error starting location updates: $e');
    }
  }

  void _stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    debugPrint('📍 Stopped location updates');
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) /
        1000; // Convert to km
  }

  void _setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void _setError(String? error) {
    state = state.copyWith(errorMessage: error);
  }
}

// Provider definition
final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier();
});
