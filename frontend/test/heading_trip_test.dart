import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wizz_driver/features/active_order/models/active_order_model.dart';
import 'package:wizz_driver/features/active_order/services/trip_route_service.dart';
import 'package:wizz_driver/features/active_order/screens/heading_to_restaurant_screen.dart';
import 'package:wizz_driver/features/active_order/widgets/driver_trip_help.dart';

ActiveOrder get order => ActiveOrder.fromJson({
      'orderId': 'order1',
      'status': 'heading_to_store',
      'restaurantName': 'مطعم فتوش',
      'restaurantLat': 31.92,
      'restaurantLng': 44.45,
      'customerName': 'Mohammed Ali',
      'customerLat': 31.9,
      'customerLng': 44.48,
      'customerPhone': '+9647800000000',
      'items': []
    });
void main() {
  testWidgets('road geometry, current name and help-only unassignment',
      (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Set<Polyline> lines = {};
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: HeadingToRestaurantScreen(
                order: order,
                loadOrder: (_) async => order,
                loadRoute: (_) async => TripRoadRoute([
                      [44.45, 31.92],
                      [44.46, 31.91],
                      [44.48, 31.9]
                    ], 3067, 480),
                mapBuilder: (_, p) {
                  lines = p;
                  return const SizedBox();
                }))));
    await tester.pumpAndSettle();
    expect(lines.length, 2);
    expect(lines.first.points.length, 3);
    expect(find.text('مطعم فتوش'), findsOneWidget);
    expect(find.text('فك الارتباط من الطلب'), findsNothing);
    expect(find.text('الاعتذار عن التوصيل'), findsNothing);
    await tester.tap(find.text('مساعدة'));
    await tester.pumpAndSettle();
    expect(find.byType(DriverTripHelp), findsOneWidget);
    expect(find.text('الاعتذار عن التوصيل'), findsOneWidget);
    expect(find.text('الإبلاغ عن مشكلة في الاستلام'), findsOneWidget);
    expect(find.text('الاتصال بالمتجر'), findsNothing);
    expect(find.text('الاتصال بالزبون'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('route failure exposes retry and no fabricated road',
      (tester) async {
    Set<Polyline> lines = {};
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: HeadingToRestaurantScreen(
                order: order,
                loadOrder: (_) async => order,
                loadRoute: (_) async => throw Exception('offline'),
                mapBuilder: (_, p) {
                  lines = p;
                  return const SizedBox();
                }))));
    await tester.pumpAndSettle();
    expect(lines, isEmpty);
    await tester.scrollUntilVisible(find.text('إعادة المحاولة'), 100,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('تعذر تحميل مسار الطريق'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('route transport rejects replaced login and wrong order', () async {
    String? token = 'first';
    final service = TripRouteService(
        token: () async => token,
        client: MockClient((r) async {
          token = 'second';
          return http.Response(
              jsonEncode({'success': true, 'orderId': 'order1', 'route': {}}),
              200);
        }));
    await expectLater(service.load('order1'), throwsException);
  });
  test('invalid geometry never draws invented straight line', () {
    expect(
        () => TripRoadRoute.fromJson({
              'purpose': 'DISPLAY_ONLY',
              'coordinates': [
                [44, 31]
              ],
              'distanceMeters': 1,
              'durationSeconds': 1
            }),
        throwsFormatException);
  });
}
