import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wizz_driver/features/demand/demand_card.dart';
import 'package:wizz_driver/features/demand/demand_service.dart';

Map<String, dynamic> fixture() => {
      'success': true,
      'state': 'READY',
      'timezone': 'Asia/Baghdad',
      'area': {'id': 'z', 'name': 'ناحية الحيرة'},
      'sourceArea': {'id': 'z', 'name': 'ناحية الحيرة'},
      'isTestData': true,
      'generatedAt': '2026-10-23T10:00:00Z',
      'days': List.generate(
          7,
          (i) => {
                'date': '2026-10-${23 + i}',
                'confidence': 'MODERATE',
                'slots': List.generate(
                    24,
                    (h) => {
                          'hour': h,
                          'score': h * 4,
                          'level': h > 15 ? 'HIGH' : 'LOW'
                        })
              })
    };
void main() {
  test('request uses authenticated server scope and discards changed identity',
      () async {
    var token = 'first';
    final s = DemandService(
        headers: () async => {'Authorization': token},
        client: MockClient((request) async {
          expect(request.url.path.endsWith('/driver/demand-forecast'), true);
          expect(request.url.queryParameters, isEmpty);
          token = 'other';
          return http.Response(jsonEncode(fixture()), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    await expectLater(s.load(), throwsStateError);
    s.dispose();
  });
  for (final width in [320.0, 390.0]) {
    testWidgets('forecast card and daily sheet fit $width and can close',
        (t) async {
      t.view.physicalSize = Size(width, 850);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = DemandService(
          headers: () async => {'Authorization': 'test'},
          client: MockClient((_) async => http.Response(
              jsonEncode(fixture()), 200,
              headers: {'content-type': 'application/json; charset=utf-8'})));
      await t.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(
                  size: Size(width, 850),
                  textScaler: const TextScaler.linear(1.2)),
              child: Scaffold(
                  body:
                      SingleChildScrollView(child: DemandCard(service: s))))));
      await t.pumpAndSettle();
      expect(find.text('بيانات تجريبية'), findsOneWidget);
      await t.tap(find.text('أوقات الطلب المتوقعة'));
      await t.pumpAndSettle();
      expect(find.text('العودة إلى الرئيسية'), findsOneWidget);
      await Scrollable.ensureVisible(t.element(find.text('السبت 24/10')),
          alignment: .5);
      await t.pumpAndSettle();
      await t.tap(find.text('السبت 24/10'));
      expect(
          t
              .widget<ChoiceChip>(
                  find.widgetWithText(ChoiceChip, 'السبت 24/10'))
              .selected,
          isFalse);
      await t.pump();
      expect(
          t
              .widget<ChoiceChip>(
                  find.widgetWithText(ChoiceChip, 'السبت 24/10'))
              .selected,
          isTrue);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.byTooltip('إغلاق'));
      await t.pumpAndSettle();
      expect(find.text('العودة إلى الرئيسية'), findsNothing);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    });
  }
  testWidgets('insufficient data never draws invented bars', (t) async {
    final s = DemandService(
        headers: () async => {'Authorization': 'test'},
        client: MockClient((_) async => http.Response(
            jsonEncode({...fixture(), 'state': 'INSUFFICIENT', 'days': []}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
    await t
        .pumpWidget(MaterialApp(home: Scaffold(body: DemandCard(service: s))));
    await t.pumpAndSettle();
    expect(find.byType(DemandBars), findsNothing);
    expect(find.textContaining('نجمع بيانات'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
