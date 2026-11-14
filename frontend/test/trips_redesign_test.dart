import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/models/trip_model.dart';
import 'package:wizz_driver/features/trips/trips_screen.dart';
import 'package:wizz_driver/features/trips/trip_detail_screen.dart';

Trip trip(
        {String id = 'order1',
        String status = 'completed',
        String created = '2026-10-22T10:00:00Z'}) =>
    Trip.fromJson({
      'tripId': id,
      'orderId': id,
      'orderNumber': 'ORD123',
      'tripNumber': 'TRP123',
      'status': status,
      'restaurantName': 'مطعم فتوش',
      'pickupAddress': 'عنوان المتجر الكامل',
      'deliveryAddress': 'عنوان الزبون الكامل',
      'customerName': 'Mohammed Ali',
      'createdAt': created,
      'completedAt': '2026-10-22T12:00:00Z',
      'acceptedAt': '2026-10-22T11:00:00Z',
      'pickupTime': '2026-10-22T11:30:00Z',
      'deliveryTime': '2026-10-22T12:00:00Z',
      'driverEarnings': 2750,
      'driverBaseEarnings': 2750,
      'driverTip': 0,
      'earningsState': 'CONFIRMED',
      'cashCollectedAmount': 8500,
      'driverCashRetained': 2750,
      'settledCollateral': 5750,
      'driverWalletCredit': 0,
      'estimatedDistanceMeters': 6520,
      'durationSeconds': 3600,
      'quantity': 2,
      'deliveryProofCount': 0
    });
void main() {
  for (final width in [320.0, 390.0])
    testWidgets('compact history and actual entitlement details at $width',
        (t) async {
      t.view.physicalSize = Size(width, 850);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(
                  size: Size(width, 850),
                  textScaler: const TextScaler.linear(1.2)),
              child: TripsScreen(
                  loadPage: ({nextToken, status, from, to}) async => {
                        'success': true,
                        'trips': [trip()],
                        'hasMore': false
                      }))));
      await t.pumpAndSettle();
      expect(find.text('2,750 د.ع'), findsOneWidget);
      expect(find.text('مطعم فتوش'), findsOneWidget);
      expect(find.text('1,500 د.ع'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(MaterialApp(
          home: TripDetailScreen(
              trip: trip(),
              loadTrip: (_) async => trip(),
              mapBuilder: (_) => const SizedBox())));
      await t.pumpAndSettle();
      expect(find.text('2,750 د.ع'), findsWidgets);
      await t.scrollUntilVisible(find.text('التحصيل والتسوية'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('التحصيل والتسوية'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  testWidgets('empty cursor page remains loadable and retry preserves trips',
      (t) async {
    var count = 0;
    await t.pumpWidget(MaterialApp(
        home: TripsScreen(loadPage: ({nextToken, status, from, to}) async {
      count++;
      return switch (count) {
        1 => {
            'success': true,
            'trips': <Trip>[],
            'hasMore': true,
            'nextToken': 'one'
          },
        2 => {
            'success': true,
            'trips': [trip()],
            'hasMore': true,
            'nextToken': 'two'
          },
        3 => {'success': false},
        _ => {
            'success': true,
            'trips': [trip(), trip(id: 'order2')],
            'hasMore': false
          }
      };
    })));
    await t.pumpAndSettle();
    await t.tap(find.text('تحميل المزيد'));
    await t.pumpAndSettle();
    expect(find.text('2,750 د.ع'), findsOneWidget);
    await t.ensureVisible(find.text('تحميل المزيد'));
    await t.tap(find.text('تحميل المزيد'));
    await t.pumpAndSettle();
    expect(find.text('2,750 د.ع'), findsOneWidget);
    await t.ensureVisible(find.text('إعادة محاولة تحميل المزيد'));
    await t.tap(find.text('إعادة محاولة تحميل المزيد'));
    await t.pumpAndSettle();
    expect(find.text('2,750 د.ع'), findsNWidgets(2));
  });
  testWidgets('late page cannot overwrite a newly selected state filter',
      (t) async {
    final pending = Completer<Map<String, dynamic>>();
    await t.pumpWidget(MaterialApp(
        home: TripsScreen(loadPage: ({nextToken, status, from, to}) async {
      if (status == null) return pending.future;
      return {
        'success': true,
        'trips': [trip(id: 'new', status: 'cancelled')],
        'hasMore': false
      };
    })));
    await t.pump();
    await t.tap(find.widgetWithText(ChoiceChip, 'ملغاة'));
    await t.pumpAndSettle();
    pending.complete({
      'success': true,
      'trips': [trip(id: 'stale')],
      'hasMore': false
    });
    await t.pumpAndSettle();
    expect(find.text('مطعم فتوش'), findsOneWidget);
    expect(find.text('ملغاة'), findsNWidgets(2));
  });
  test(
      'unknown status and missing driver earnings never become completed/customer tariff',
      () {
    final value = Trip.fromJson({
      'status': 'invented',
      'createdAt': 'bad',
      'deliveryFee': 1500,
      'finalDeliveryFee': 1500
    });
    expect(value.status, TripStatus.unknown);
    expect(value.driverEarnings, isNull);
    expect(value.getFormattedDate(), 'تاريخ غير متاح');
  });
}
