import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/features/more/screens/driver_performance_screen.dart';

void main() {
  testWidgets('pending saved snapshot is labelled instead of appearing current', (tester) async {
    await tester.pumpWidget(MaterialApp(home: DriverPerformanceScreen(load: () async => {
      'rulesVersion': 'OBSERVED_DRIVER_PERFORMANCE_V4',
      'projection': {'status': 'UPDATING', 'version': 7},
      'acceptanceRate': null, 'acceptanceRateStatus': 'INSUFFICIENT_DATA',
      'completionRate': null, 'completionRateStatus': 'INSUFFICIENT_DATA',
    })));
    await tester.pumpAndSettle();
    expect(find.textContaining('يجري تحديث مؤشراتك'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'last100 rating shows valid sample and private-safe source details',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: DriverPerformanceScreen(
            load: () async => {
                  'rulesVersion': 'OBSERVED_DRIVER_PERFORMANCE_V4',
                  'updatedAt': '2026-10-25T12:00:00Z',
                  'customerRating': 4.6,
                  'customerRatingCount': 100,
                  'ratingWindow': {
                    'basis': 'LAST_100_VALID_CUSTOMER_RATINGS_V1',
                    'average': 4.6,
                    'count': 100,
                    'status': 'PROVISIONAL',
                    'underReview': 2,
                    'excluded': 3,
                    'unverified': 0,
                    'allTime': {'underReview': 2, 'excluded': 4}
                  },
                  'details': {
                    'rating': [
                      {
                        'status': 'INCLUDED',
                        'reason': 'ORIGINAL_VERIFIED_CUSTOMER_RATING',
                        'stars': 5,
                        'orderNumber': 'ORD1792497600000',
                        'orderId': 'internal-order',
                        'occurredAt': '2026-10-25T10:00:00Z'
                      }
                    ]
                  }
                })));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('تقييمات العملاء'));
    expect(find.text('آخر 100 تقييم صالح · 100 محتسب'), findsOneWidget);
    await tester.tap(find.text('تقييمات العملاء'));
    await tester.pumpAndSettle();
    expect(find.textContaining('تُملأ العينة بتقييمات أقدم'), findsOneWidget);
    expect(find.text('5 من 5'), findsOneWidget);
    expect(find.text('الطلب ORD1792497600000'), findsOneWidget);
    expect(find.textContaining('internal-order'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unavailable last100 never displays a stale all-time score',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: DriverPerformanceScreen(
            load: () async => {
                  'rulesVersion': 'OBSERVED_DRIVER_PERFORMANCE_V4',
                  'updatedAt': '2026-10-25T12:00:00Z',
                  'customerRating': 4.9,
                  'customerRatingCount': 200,
                  'ratingWindow': {
                    'basis': 'LAST_100_VALID_CUSTOMER_RATINGS_V1',
                    'average': null,
                    'count': 0,
                    'status': 'UNAVAILABLE'
                  }
                })));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('تقييمات العملاء'));
    expect(find.text('4.9'), findsNothing);
    expect(find.text('تعذر تحديث نافذة التقييمات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing metrics show retry and never a manufactured percentage',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: DriverPerformanceScreen(load: () async => null)));
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحديث المؤشرات'), findsOneWidget);
    expect(find.text('0.0٪'), findsNothing);
    expect(find.text('75.0٪'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('preliminary rate is marked and its explicit sample explained',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: DriverPerformanceScreen(
            load: () async => {
                  'updatedAt': '2026-10-24T12:00:00Z',
                  'acceptanceRate': .5,
                  'acceptanceRateStatus': 'PROVISIONAL',
                  'acceptance': {
                    'accepted': 1,
                    'declined': 1,
                    'sampleSize': 2,
                    'unconfirmedExcluded': 3,
                    'withdrawnExcluded': 1
                  },
                  'completionRate': null,
                  'completionRateStatus': 'INSUFFICIENT_DATA',
                  'completion': {
                    'completed': 0,
                    'returned': 0,
                    'driverFailures': 0,
                    'sampleSize': 0,
                    'inProgress': 1,
                    'reviewExcluded': 1,
                    'noFaultExcluded': 0
                  },
                  'customerRating': null,
                  'customerRatingCount': 0,
                })));
    await tester.pumpAndSettle();
    expect(find.text('50.0٪'), findsOneWidget);
    expect(find.text('مبدئي'), findsOneWidget);
    expect(find.text('بناءً على 2 عرضًا موثقًا'), findsOneWidget);
    expect(find.textContaining('قبلت 1 ورفضت 1'), findsNothing);
    await tester.tap(find.text('معدل القبول'));
    await tester.pumpAndSettle();
    expect(find.textContaining('قبلت 1 ورفضت 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'timing explains original plan and opens Arabic reasons without technical identifiers',
      (tester) async {
    final data = <String, dynamic>{
      'updatedAt': '2026-10-24T12:00:00Z',
      'onTimeRate': .5,
      'onTimeRateStatus': 'PROVISIONAL',
      'punctuality': {
        'onTime': 1,
        'lateObserved': 1,
        'sampleSize': 2,
        'reviewExcluded': 1,
        'unavailableExcluded': 3,
        'inProgress': 0,
        'graceSeconds': 300
      },
      'activity': {
        'accepted': 7,
        'coverageComplete': false,
        'legacyExcluded': 2
      },
      'details': {
        'punctuality': [
          {
            'status': 'REVIEW',
            'reason': 'PICKUP_DELAY_REQUIRES_REVIEW',
            'attempt': 2,
            'occurredAt': '2026-10-24T12:00:00Z',
            'orderId': 'internal-secret-uuid',
            'targets': {
              'pickupTargetAt': '2026-10-24T12:05:00Z',
              'customerTargetAt': '2026-10-24T12:20:00Z'
            }
          }
        ]
      }
    };
    await tester.pumpWidget(
        MaterialApp(home: DriverPerformanceScreen(load: () async => data)));
    await tester.pumpAndSettle();
    final button = find.text('الالتزام بالوقت');
    await tester.scrollUntilVisible(button, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('تأخر الاستلام؛ يلزم تحديد سبب الانتظار'), 150,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(find.text('تأخر الاستلام؛ يلزم تحديد سبب الانتظار'), findsOneWidget);
    expect(find.text('محاولة الإسناد: 2'), findsOneWidget);
    expect(find.textContaining('15:05 بتوقيت بغداد'), findsOneWidget);
    expect(find.textContaining('internal-secret-uuid'), findsNothing);
    await tester.tap(find.byTooltip('إغلاق التفاصيل'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'partial activity is a lower bound and never marketed as completed trips',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: DriverPerformanceScreen(
            load: () async => {
                  'updatedAt': '2026-10-24T12:00:00Z',
                  'activity': {
                    'accepted': 7,
                    'coverageComplete': false,
                    'legacyExcluded': 2
                  }
                })));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('نشاط آخر 30 يومًا'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('7'), findsOneWidget);
    expect(find.text('حد أدنى · قراءة جزئية'), findsOneWidget);
    await tester.tap(find.text('نشاط آخر 30 يومًا'));
    await tester.pumpAndSettle();
    expect(find.textContaining('وليس عدد الرحلات المكتملة أو ساعات العمل'),
        findsOneWidget);
    expect(find.text('100.0٪'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'explanations stay collapsed and compact rows handle narrow large-text screens',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!),
        home: DriverPerformanceScreen(
            load: () async => {
                  'updatedAt': '2026-10-24T12:00:00Z',
                  'acceptanceRate': 1.0,
                  'acceptanceRateStatus': 'PROVISIONAL',
                  'acceptance': {'sampleSize': 21},
                  'customerRating': 4.9,
                  'customerRatingCount': 100,
                })));
    await tester.pumpAndSettle();
    expect(find.text('100.0٪'), findsOneWidget);
    expect(
        find.textContaining('نسبة العروض التي قبلتها إلى آخر'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('كيف تُحسب مؤشراتك؟'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('كيف تُحسب مؤشراتك؟'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('نسبة العروض التي قبلتها إلى آخر'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
