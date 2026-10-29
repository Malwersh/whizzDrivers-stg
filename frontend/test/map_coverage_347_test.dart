import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/services/map_data_failure.dart';
import 'package:wizz_driver/features/home/widgets/outside_coverage_sheet.dart';

void main() {
  test('only authoritative region miss is outside coverage', () {
    expect(
        MapDataFailure.fromResponse(
            404, {'error': 'Region not found for coordinates'})?.kind,
        MapDataFailureKind.outsideCoverage);
    for (final status in [404, 429, 500, 502]) {
      expect(
          MapDataFailure.fromResponse(status, {'message': 'not found'})?.kind,
          MapDataFailureKind.server);
    }
    expect(MapDataFailure.fromResponse(401, {})?.kind,
        MapDataFailureKind.authentication);
    expect(MapDataFailure.fromResponse(403, {})?.kind,
        MapDataFailureKind.authentication);
    expect(MapDataFailure.fromResponse(200, {'success': true}), isNull);
  });
  testWidgets(
      'coverage sheet shows current place and coordinates without an internet error',
      (tester) async {
    const channel = MethodChannel('com.whizz.driver/location_label');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel, (_) async => 'شيكاغو، الولايات المتحدة');
    var refreshed = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OutsideCoverageSheet(
                latitude: 41.8781,
                longitude: -87.6298,
                onRefresh: () => refreshed = true))));
    await tester.pumpAndSettle();
    expect(find.text('أنت خارج مناطق الخدمة حاليًا'), findsOneWidget);
    expect(find.text('شيكاغو، الولايات المتحدة'), findsOneWidget);
    expect(find.textContaining('41.878'), findsNothing);
    expect(find.textContaining('-87.629'), findsNothing);
    expect(find.textContaining('الإنترنت'), findsNothing);
    await tester.tap(find.text('تحديث موقعي'));
    expect(refreshed, isTrue);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  testWidgets('place lookup failure never exposes coordinates', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.whizz.driver/location_label'),
        (_) async => throw PlatformException(code: 'offline'));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OutsideCoverageSheet(
                latitude: 41.8781, longitude: -87.6298, onRefresh: () {}))));
    await tester.pumpAndSettle();
    expect(find.textContaining('41.878'), findsNothing);
    expect(find.textContaining('-87.629'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
