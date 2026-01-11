import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;
  String _locationStatus = 'Unknown';
  String? _errorMessage;
  bool _hasLocationPermission = false;

  // Iraqi cities coordinates
  static const Map<String, LatLng> iraqiCities = {
    'Baghdad': LatLng(33.3152, 44.3661),
    'Basra': LatLng(30.5084, 47.7804),
    'Erbil': LatLng(36.1911, 44.0092),
    'Mosul': LatLng(36.3489, 43.1189),
    'Najaf': LatLng(32.0000, 44.3333),
    'Karbala': LatLng(32.6160, 44.0241),
  };

  LatLng? get currentLocation => _currentLocation;
  bool get isTracking => _isTracking;
  String get locationStatus => _locationStatus;
  String? get errorMessage => _errorMessage;
  bool get hasLocationPermission => _hasLocationPermission;

  /// Get current location or return fallback Baghdad coordinates
  LatLng getLocationOrDefault() {
    return _currentLocation ?? iraqiCities['Baghdad']!;
  }

  /// Initialize location services and check permissions
  Future<bool> initialize() async {
    try {
      // Clear error without notifying listeners (avoid setState during build)
      _errorMessage = null;

      // Set fallback location (Baghdad) initially
      _currentLocation ??= iraqiCities['Baghdad'];

      // Check location permission with detailed status
      final permission = await Permission.location.status;

      if (permission.isDenied) {
        _setStatus('طلب إذن الموقع...');
        final result = await Permission.location.request();

        if (result.isDenied) {
          _setError('تم رفض إذن الموقع. يرجى تفعيله من إعدادات التطبيق');
          return false;
        } else if (result.isPermanentlyDenied) {
          _setError('تم رفض إذن الموقع نهائياً. يرجى تفعيله من إعدادات الجهاز');
          return false;
        }
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setError('خدمات الموقع غير مفعلة. يرجى تفعيلها من إعدادات الجهاز');
        return false;
      }

      _hasLocationPermission = true;
      _setStatus('جاهز');
      return true;
    } catch (e) {
      _setError('خطأ في تهيئة خدمات الموقع: ${e.toString()}');
      return false;
    }
  }

  /// Request location permission with user-friendly messages
  Future<bool> requestLocationPermission() async {
    try {
      final permission = await Permission.location.status;

      if (permission.isGranted) {
        _hasLocationPermission = true;
        return true;
      }

      if (permission.isPermanentlyDenied) {
        // Guide user to app settings
        _setError('يرجى تفعيل إذن الموقع من إعدادات التطبيق');
        await openAppSettings();
        return false;
      }

      final result = await Permission.location.request();
      _hasLocationPermission = result.isGranted;

      if (!_hasLocationPermission) {
        _setError('إذن الموقع مطلوب لتلقي الطلبات وتتبع التوصيل');
      }

      return _hasLocationPermission;
    } catch (e) {
      _setError('خطأ في طلب إذن الموقع: ${e.toString()}');
      return false;
    }
  }

  /// Start real-time location tracking
  Future<void> startTracking() async {
    if (_isTracking) return;

    try {
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );

      _positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) {
              _currentLocation = LatLng(position.latitude, position.longitude);
              _locationStatus = 'Tracking';
              notifyListeners();
            },
            onError: (error) {
              _locationStatus = 'Tracking error: $error';
              notifyListeners();
            },
          );

      _isTracking = true;
      notifyListeners();
    } catch (e) {
      _locationStatus = 'Failed to start tracking: $e';
      notifyListeners();
    }
  }

  /// Stop location tracking
  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isTracking = false;
    _locationStatus = 'Stopped';
    notifyListeners();
  }

  /// Get current one-time location
  Future<LatLng?> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentLocation = LatLng(position.latitude, position.longitude);
      notifyListeners();
      return _currentLocation;
    } catch (e) {
      _locationStatus = 'Failed to get location: $e';
      notifyListeners();
      return null;
    }
  }

  /// Get distance between two points in meters
  double getDistanceBetween(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Find nearest Iraqi city
  String getNearestIraqiCity(LatLng location) {
    String nearestCity = 'Baghdad';
    double shortestDistance = double.infinity;

    for (final entry in iraqiCities.entries) {
      final distance = getDistanceBetween(location, entry.value);
      if (distance < shortestDistance) {
        shortestDistance = distance;
        nearestCity = entry.key;
      }
    }

    return nearestCity;
  }

  /// Check if location is within Iraqi city bounds (approximate)
  bool isWithinIraqiBounds(LatLng location) {
    // Iraq approximate bounds
    const double minLat = 29.0;
    const double maxLat = 37.4;
    const double minLng = 38.8;
    const double maxLng = 48.8;

    return location.latitude >= minLat &&
        location.latitude <= maxLat &&
        location.longitude >= minLng &&
        location.longitude <= maxLng;
  }

  void _setStatus(String status) {
    _locationStatus = status;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _locationStatus = 'خطأ';
    notifyListeners();
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
