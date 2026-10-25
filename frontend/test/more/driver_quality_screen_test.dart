import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wizz_driver/services/driver_quality_service.dart';
import 'package:wizz_driver/features/more/screens/driver_quality_screen.dart';

String token(String sub) => 'header.${base64Url.encode(utf8.encode(jsonEncode({
          'sub': sub
        })))}.signature';
Map<String, dynamic> data({bool complete = true, bool incident = false}) => {
      'success': true,
      'schemaVersion': 1,
      'coverageComplete': complete,
      'items': incident
          ? [
              {
                'incidentId': '12345678-1234-4123-8123-123456789abc',
                'orderId': 'order1',
                'orderNumber': 'ORD123',
                'category': 'ROAD_SAFETY',
                'state': 'RESOLVED',
                'decision': 'SUBSTANTIATED',
                'decisionReason': 'راجع الفريق مصادر البلاغ',
                'canAppeal': true,
                'version': 3
              }
            ]
          : []
    };
http.Response response(Map<String, dynamic> value, {int status = 200}) =>
    http.Response(jsonEncode(value), status,
        headers: {'content-type': 'application/json; charset=utf-8'});
void main() {
  test(
      'account change prevents previous identity response from being displayed',
      () async {
    var owner = 'first';
    final api = DriverQualityService(
        endpoint: 'https://test.invalid',
        token: () async => token(owner),
        client: MockClient((_) async {
          owner = 'second';
          return response(data());
        }));
    await expectLater(api.load(), throwsA(isA<DriverQualityException>()));
    api.dispose();
  });
  testWidgets(
      'partial empty history is not presented as a clean complete history',
      (tester) async {
    final api = DriverQualityService(
        endpoint: 'https://test.invalid',
        token: () async => token('driver1'),
        client: MockClient((_) async => response(data(complete: false))));
    await tester
        .pumpWidget(MaterialApp(home: DriverQualityScreen(service: api)));
    await tester.pumpAndSettle();
    expect(
        find.text('لا توجد ملاحظات في الجزء الذي تم تحميله.'), findsOneWidget);
    expect(find.textContaining('هذه النتائج تغطي جزءًا'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
  testWidgets(
      'own decision and appeal retry preserve operation identity on a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final posts = <Map<String, dynamic>>[];
    final api = DriverQualityService(
        endpoint: 'https://test.invalid',
        token: () async => token('driver1'),
        client: MockClient((r) async {
          if (r.method == 'GET') return response(data(incident: true));
          posts.add(jsonDecode(r.body));
          return response(
              {'success': false, 'code': 'QUALITY_APPEAL_UNAVAILABLE'},
              status: 503);
        }));
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!),
        home: DriverQualityScreen(service: api)));
    await tester.pumpAndSettle();
    expect(find.text('واقعة مثبتة بعد المراجعة'), findsOneWidget);
    await tester.ensureVisible(find.text('اعتراض على القرار'));
    await tester.tap(find.text('اعتراض على القرار'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'أعترض وأطلب مراجعة إفادتي');
    await tester.ensureVisible(find.text('إرسال الاعتراض'));
    await tester.tap(find.text('إرسال الاعتراض'));
    await tester.pumpAndSettle();
    expect(posts.length, 1);
    await tester.tap(find.text('إرسال الاعتراض'));
    await tester.pumpAndSettle();
    expect(posts.length, 2);
    expect(posts[0]['idempotencyKey'], posts[1]['idempotencyKey']);
    expect(posts[0]['driverId'], isNull);
    expect(find.text('تم تسجيل اعتراضك للمراجعة.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
  testWidgets('load failure shows retry without an empty clean state',
      (tester) async {
    final api = DriverQualityService(
        endpoint: 'https://test.invalid',
        token: () async => token('driver1'),
        client:
            MockClient((_) async => response({'success': false}, status: 503)));
    await tester
        .pumpWidget(MaterialApp(home: DriverQualityScreen(service: api)));
    await tester.pumpAndSettle();
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.textContaining('لا توجد ملاحظات'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
}
