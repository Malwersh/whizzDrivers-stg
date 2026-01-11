import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

/// خدمة تتبع موقع السائق وإرساله للسيرفر
class DriverLocationService {
  static final DriverLocationService _instance = DriverLocationService._internal();
  
  factory DriverLocationService() => _instance;
  
  DriverLocationService._internal();

  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;
  String? _currentOrderId;
  bool _isTracking = false;

  /// بدء تتبع الموقع لطلب معين
  Future<void> startTracking(String orderId) async {
    if (_isTracking && _currentOrderId == orderId) {
      debugPrint('⚠️ Already tracking for order: $orderId');
      return;
    }

    await stopTracking(); // إيقاف أي تتبع سابق

    _currentOrderId = orderId;
    _isTracking = true;

    debugPrint('🟢 Starting location tracking for order: $orderId');

    // التحقق من أذونات الموقع
    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      debugPrint('❌ Location permission denied');
      return;
    }

    // بدء تتبع الموقع كل 30 ثانية
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _sendCurrentLocation();
    });

    // إرسال الموقع الأول مباشرة
    _sendCurrentLocation();
  }

  /// إيقاف تتبع الموقع
  Future<void> stopTracking() async {
    if (_locationTimer != null) {
      _locationTimer!.cancel();
      _locationTimer = null;
    }

    if (_positionStream != null) {
      await _positionStream!.cancel();
      _positionStream = null;
    }

    _isTracking = false;
    _currentOrderId = null;

    debugPrint('🔴 Location tracking stopped');
  }

  /// إرسال الموقع الحالي للسيرفر
  Future<void> _sendCurrentLocation() async {
    if (!_isTracking || _currentOrderId == null) {
      return;
    }

    try {
      // الحصول على الموقع الحالي
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      debugPrint('📍 Sending location: ${position.latitude}, ${position.longitude}');

      // إرسال الموقع للسيرفر
      await _updateLocationOnServer(
        orderId: _currentOrderId!,
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );

      debugPrint('✅ Location sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending location: $e');
      
      // إعادة المحاولة بعد فشل الإرسال
      if (_isTracking) {
        debugPrint('🔄 Retrying in 10 seconds...');
        await Future.delayed(const Duration(seconds: 10));
        if (_isTracking) {
          _sendCurrentLocation();
        }
      }
    }
  }

  /// التحقق من أذونات الموقع
  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // التحقق من تفعيل خدمة الموقع
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('❌ Location services are disabled');
      return false;
    }

    // التحقق من الأذونات
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('❌ Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('❌ Location permissions are permanently denied');
      return false;
    }

    return true;
  }

  /// إرسال الموقع للسيرفر (API Call)
  Future<void> _updateLocationOnServer({
    required String orderId,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) async {
    // TODO: استبدل هذا بالـ API call الحقيقي
    // مثال:
    // final response = await http.post(
    //   Uri.parse('https://api.example.com/driver/location'),
    //   headers: {'Content-Type': 'application/json'},
    //   body: jsonEncode({
    //     'orderId': orderId,
    //     'latitude': latitude,
    //     'longitude': longitude,
    //     'timestamp': timestamp.toIso8601String(),
    //   }),
    // );
    //
    // if (response.statusCode != 200) {
    //   throw Exception('Failed to update location');
    // }

    // محاكاة API call
    await Future.delayed(const Duration(milliseconds: 500));
    
    debugPrint('''
    📤 Location update:
       Order ID: $orderId
       Lat: $latitude
       Lng: $longitude
       Time: ${timestamp.toIso8601String()}
    ''');
  }

  /// الحصول على الموقع الحالي (للاستخدام الفوري)
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('❌ Error getting current position: $e');
      return null;
    }
  }

  /// تتبع الموقع بشكل مستمر (للاستخدام في الخرائط)
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // تحديث كل 10 أمتار
      ),
    );
  }

  /// حساب المسافة بين نقطتين
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
  }

  /// التحقق من حالة التتبع
  bool get isTracking => _isTracking;
  String? get currentOrderId => _currentOrderId;
}
