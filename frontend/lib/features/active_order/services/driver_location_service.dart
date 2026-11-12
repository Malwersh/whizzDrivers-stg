import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import '../../../services/driver_search_api_service.dart';
import '../../../services/driver_location_mode.dart';

/// Real GPS publishing belongs to the active trip, not to a screen's timer.
class DriverLocationService {
  static final DriverLocationService _instance = DriverLocationService._();
  factory DriverLocationService() => _instance;
  DriverLocationService._();
  // Explicit dependency injection for offline lifecycle/GPS tests only.
  DriverLocationService.testing(
      {required this.testPermission,
      required this.testPositions,
      required this.testCurrent,
      required this.testSend,
      required this.testFixedMode});
  Future<LocationPermission> Function()? testPermission;
  Stream<Position> Function(LocationSettings)? testPositions;
  Future<Position> Function(LocationSettings)? testCurrent;
  Future<bool> Function(String, Position)? testSend;
  Future<bool> Function()? testFixedMode;
  DateTime Function()? testNow;
  bool _fixedMode = false;
  Future<Position> _current(LocationSettings settings) async {
    if (testCurrent != null) return testCurrent!(settings);
    if (_fixedMode) {
      final p = await DriverSearchApiService.getCurrentPosition();
      if (p == null) throw StateError('Test position unavailable');
      return p;
    }
    return Geolocator.getCurrentPosition(locationSettings: settings);
  }

  StreamSubscription<Position>? _positions;
  Timer? _heartbeat;
  String? _orderId;
  bool _sending = false;
  DateTime? _sentAt;
  int _generation = 0;
  static const phases = {
    'picked_up',
    'heading_to_customer',
    'arrived_at_customer',
    'on_the_way',
    'out_for_delivery'
  };
  void synchronize(String? id, String? status) {
    if (id == null || !phases.contains(status)) {
      unawaited(stopTracking());
      return;
    }
    if (_orderId != id) unawaited(startTracking(id));
  }

  Future<void> startTracking(String id) async {
    final generation = ++_generation;
    _heartbeat?.cancel();
    final previous = _positions;
    _positions = null;
    _orderId = id;
    _sentAt = null;
    await previous?.cancel();
    _fixedMode = await (testFixedMode?.call() ??
        DriverLocationMode.usesFixedTestPosition());
    final permission = _fixedMode
        ? LocationPermission.always
        : await (testPermission?.call() ?? Geolocator.checkPermission());
    if (_generation != generation ||
        _orderId != id ||
        permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;
    final LocationSettings settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
            intervalDuration: const Duration(seconds: 5),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'توصيل الطلب جارٍ',
                notificationText: 'مشاركة موقع الرحلة لتتبع التوصيل',
                enableWakeLock: true))
        : AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5,
            activityType: ActivityType.automotiveNavigation,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true);
    // A trial profile must never publish the physical device's real GPS.
    if (!_fixedMode) {
      _positions = (testPositions?.call(settings) ??
              Geolocator.getPositionStream(locationSettings: settings))
          .listen((p) => unawaited(_publish(id, p)), onError: (Object _) {});
    }
    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (_orderId != id || _sending) return;
      try {
        final p = await _current(settings).timeout(const Duration(seconds: 10));
        await _publish(id, p);
      } catch (_) {}
    });
    try {
      final p = await _current(settings).timeout(const Duration(seconds: 12));
      await _publish(id, p);
    } catch (_) {}
  }

  Future<void> _publish(String id, Position p) async {
    final now = testNow?.call() ?? DateTime.now();
    if (_orderId != id ||
        _sending ||
        p.accuracy > 100 ||
        now.difference(p.timestamp).inSeconds > 30 ||
        _sentAt != null && now.difference(_sentAt!).inSeconds < 5) return;
    _sending = true;
    try {
      final ok = testSend != null
          ? await testSend!(id, p)
          : await DriverSearchApiService.refreshSearchPosition(
              latitude: p.latitude,
              longitude: p.longitude,
              tracking: {
                  'orderId': id,
                  'accuracy': p.accuracy,
                  'heading':
                      p.heading >= 0 && p.heading < 360 ? p.heading : 0.0,
                  'observedAt': p.timestamp.toUtc().toIso8601String()
                });
      if (ok) _sentAt = now;
    } finally {
      _sending = false;
    }
  }

  Future<void> stopTracking() async {
    _generation++;
    _heartbeat?.cancel();
    _heartbeat = null;
    _orderId = null;
    _sentAt = null;
    final stream = _positions;
    _positions = null;
    await stream?.cancel();
  }
}
