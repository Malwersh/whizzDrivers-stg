import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/models/trip_model.dart';
import 'package:wizz_driver/features/earnings/earnings_service.dart';
import 'package:wizz_driver/features/earnings/earnings_summary.dart';
import 'package:wizz_driver/features/earnings/earnings_screen.dart';

Trip trip(
        {String id = 'order1',
        String state = 'CONFIRMED',
        double earning = 3250,
        int day = 22}) =>
    Trip.fromJson({
      'tripId': id,
      'orderId': id,
      'orderNumber': 'ORD123',
      'restaurantName': 'مطعم فتوش',
      'status': 'completed',
      'createdAt': '2026-10-22T11:00:00',
      'completedAt': '2026-10-${day.toString().padLeft(2, '0')}T12:00:00',
      'driverEarnings': earning,
      'driverBaseEarnings': earning - 500,
      'driverTip': 500,
      'earningsState': state,
      'deliveryFee': 1500,
      'cashCollectedAmount': 8500
    });
void main() {
  test(
      'confirmed total includes tips once, excludes recorded and deduplicates orders',
      () {
    final s =
        EarningsSummary([trip(), trip(), trip(id: 'old', state: 'RECORDED')]);
    expect(s.total, 3250);
    expect(s.base, 2750);
    expect(s.tips, 500);
    expect(s.unconfirmedCount, 1);
    expect(s.hasBreakdown, isTrue);
  });
  test(
      'complete paginated period crosses empty pages and scopes completed records',
      () async {
    var count = 0;
    final s = EarningsService(
        token: () async => 'test-token',
        loadPage: ({nextToken, status, from, to}) async {
          expect(status, 'completed');
          count++;
          return count == 1
              ? {
                  'success': true,
                  'trips': <Trip>[],
                  'hasMore': true,
                  'nextToken': 'next'
                }
              : {
                  'success': true,
                  'trips': [trip(), trip()],
                  'hasMore': false
                };
        });
    final summary =
        await s.load(DateTime(2026, 10, 19), DateTime(2026, 10, 25, 23, 59));
    expect(summary.total, 3250);
    expect(count, 2);
  });
  test('page failure and repeated cursor never return partial earnings',
      () async {
    for (final repeat in [false, true]) {
      var count = 0;
      final s = EarningsService(
          token: () async => 'test-token',
          loadPage: ({nextToken, status, from, to}) async {
            count++;
            return count == 1 || repeat
                ? {
                    'success': true,
                    'trips': [trip()],
                    'hasMore': true,
                    'nextToken': 'same'
                  }
                : {'success': false};
          });
      await expectLater(
          s.load(DateTime(2026, 10, 19), DateTime(2026, 10, 25, 23, 59)),
          throwsStateError);
      expect(count, 2);
    }
  });
  test('identity change discards the whole period', () async {
    var identity = 'first';
    var requests = 0;
    final service = EarningsService(
        token: () async => identity,
        loadPage: ({nextToken, status, from, to}) async {
          requests++;
          identity = 'second';
          return {
            'success': true,
            'trips': [trip()],
            'hasMore': true,
            'nextToken': 'next'
          };
        });
    await expectLater(
        service.load(DateTime(2026, 10, 19), DateTime(2026, 10, 25)),
        throwsStateError);
    expect(requests, 1);
  });
  test('changed selection stops further requests', () async {
    var count = 0;
    await expectLater(
        EarningsService(
                token: () async => 'test-token',
                loadPage: ({nextToken, status, from, to}) async {
                  count++;
                  return {'success': true, 'trips': <Trip>[], 'hasMore': false};
                })
            .load(DateTime(2026, 10, 19), DateTime(2026, 10, 25),
                isCurrent: () => false),
        throwsStateError);
    expect(count, 0);
  });
  for (final width in [320.0, 390.0])
    testWidgets('single screen earnings and help fit $width', (t) async {
      t.view.physicalSize = Size(width, 850);
      t.view.devicePixelRatio = 1;
      t.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPadding);
      final s = EarningsService(
          token: () async => 'test-token',
          loadPage: ({nextToken, status, from, to}) async => {
                'success': true,
                'trips': [trip(), trip(id: 'old', state: 'RECORDED')],
                'hasMore': false
              });
      await t.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(
                  size: Size(width, 850),
                  padding: const EdgeInsets.only(bottom: 34),
                  textScaler: const TextScaler.linear(1.2)),
              child: EarningsScreen(now: DateTime(2026, 10, 22), service: s))));
      await t.pumpAndSettle();
      expect(find.text('3,250 د.ع'), findsWidgets);
      expect(find.text('8,500 د.ع'), findsNothing);
      expect(find.text('أجور التوصيل'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.byTooltip('عن الأرباح'));
      await t.pumpAndSettle();
      expect(find.text('كيف تُعرض أرباحك؟'), findsOneWidget);
      await t.ensureVisible(find.text('العودة إلى الأرباح'));
      await t.tap(find.text('العودة إلى الأرباح'));
      await t.pumpAndSettle();
      expect(find.text('كيف تُعرض أرباحك؟'), findsNothing);
      expect(t.takeException(), isNull);
    });
  testWidgets(
      'chart day selection updates summary inline without more requests',
      (t) async {
    var calls = 0;
    final s = EarningsService(
        token: () async => 'test-token',
        loadPage: ({nextToken, status, from, to}) async {
          calls++;
          return {
            'success': true,
            'trips': [trip(), trip(id: 'second', day: 21)],
            'hasMore': false
          };
        });
    await t.pumpWidget(MaterialApp(
        home: EarningsScreen(now: DateTime(2026, 10, 22), service: s)));
    await t.pumpAndSettle();
    expect(find.text('6,500 د.ع'), findsOneWidget);
    await Scrollable.ensureVisible(t.element(find.text('خ')), alignment: .5);
    await t.pumpAndSettle();
    await t.tap(find.text('خ'));
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView), const Offset(0, 600));
    await t.pumpAndSettle();
    expect(find.text('6,500 د.ع'), findsNothing);
    expect(find.text('استحقاقات 22/10/2026'), findsOneWidget);
    expect(calls, 1);
  });
  testWidgets('inactive earnings tab does not fetch until selected', (t) async {
    var calls = 0;
    final s = EarningsService(
        token: () async => 'test-token',
        loadPage: ({nextToken, status, from, to}) async {
          calls++;
          return {'success': true, 'trips': <Trip>[], 'hasMore': false};
        });
    await t.pumpWidget(MaterialApp(
        home: EarningsScreen(
            isActive: false, now: DateTime(2026, 10, 22), service: s)));
    await t.pumpAndSettle();
    expect(calls, 0);
    await t.pumpWidget(MaterialApp(
        home: EarningsScreen(
            isActive: true, now: DateTime(2026, 10, 22), service: s)));
    await t.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('0 د.ع'), findsOneWidget);
    expect(find.text('لا توجد رحلات مكتملة في هذه الفترة'), findsOneWidget);
  });
}
