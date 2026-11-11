import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wizz_driver/features/active_order/services/driver_location_service.dart';

Position point(DateTime time, double latitude, {double accuracy = 8}) =>
    Position(
        latitude: latitude,
        longitude: 44.476014,
        timestamp: time,
        accuracy: accuracy,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 90,
        headingAccuracy: 0,
        speed: 5,
        speedAccuracy: 0);
void main() {
  test('simulated GPS movement heartbeat and trip termination', () {
    fakeAsync((clock) {
      var now = DateTime.now();
      final positions = StreamController<Position>(sync: true);
      final sent = <Position>[];
      var current = point(now, 31.913292);
      LocationSettings? settings;
      final service = DriverLocationService.testing(
          testPermission: () async => LocationPermission.always,
          testFixedMode: () async => false,
          testPositions: (s) {
            settings = s;
            return positions.stream;
          },
          testCurrent: (_) async => current,
          testSend: (_, p) async {
            sent.add(p);
            return true;
          })
        ..testNow = () => now;
      service.startTracking('trial-order');
      clock.flushMicrotasks();
      expect(sent.length, 1);
      positions.add(point(now, 31.914));
      clock.flushMicrotasks();
      expect(sent.length, 1);
      now = now.add(const Duration(seconds: 6));
      current = point(now, 31.915);
      positions.add(current);
      clock.flushMicrotasks();
      expect(sent.last.latitude, 31.915);
      now = now.add(const Duration(seconds: 16));
      current = point(now, 31.916);
      clock.elapse(const Duration(seconds: 15));
      clock.flushMicrotasks();
      expect(sent.last.latitude, 31.916);
      final apple = settings as AppleSettings;
      expect(apple.allowBackgroundLocationUpdates, isTrue);
      expect(apple.pauseLocationUpdatesAutomatically, isFalse);
      service.synchronize('trial-order', 'delivered');
      clock.flushMicrotasks();
      final count = sent.length;
      positions.add(point(now, 31.92));
      clock.elapse(const Duration(seconds: 20));
      expect(sent.length, count);
      service.stopTracking();
      positions.close();
      clock.flushMicrotasks();
    });
  });
  testWidgets(
      'staging fixed trial avoids real GPS stream and permission lookup',
      (tester) async {
    var streamCalls = 0, permissionCalls = 0;
    final sent = <Position>[];
    final service = DriverLocationService.testing(
        testPermission: () async {
          permissionCalls++;
          return LocationPermission.denied;
        },
        testFixedMode: () async => true,
        testPositions: (_) {
          streamCalls++;
          return const Stream.empty();
        },
        testCurrent: (_) async => point(DateTime.now(), 31.913292),
        testSend: (_, p) async {
          sent.add(p);
          return true;
        });
    await service.startTracking('trial-order');
    expect(sent.single.latitude, 31.913292);
    expect(streamCalls, 0);
    expect(permissionCalls, 0);
    await service.stopTracking();
  });
  testWidgets('trip stopped while permission pending never starts GPS',
      (tester) async {
    final permission = Completer<LocationPermission>();
    var streams = 0;
    final service = DriverLocationService.testing(
        testPermission: () => permission.future,
        testFixedMode: () async => false,
        testPositions: (_) {
          streams++;
          return const Stream.empty();
        },
        testCurrent: (_) async => point(DateTime.now(), 31.9),
        testSend: (_, __) async => true);
    final starting = service.startTracking('trial-order');
    await tester.pump();
    await service.stopTracking();
    permission.complete(LocationPermission.always);
    await starting;
    expect(streams, 0);
  });
}
