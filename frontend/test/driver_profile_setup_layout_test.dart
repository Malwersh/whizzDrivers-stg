import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wizz_driver/features/authentication/screens/driver_profile_setup_screen.dart';

void main() {
  testWidgets(
      'compact RTL form keeps validation reachable from the submit button',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 590));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final requests = <String>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          ProviderScope(
              child: MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.3)),
              child: child!,
            ),
            home: DriverProfileSetupScreen(
              phoneNumber: '',
              profileToken: () async => 'test-profile-token',
            ),
          )),
        );
        await tester.pumpAndSettle();
        expect(find.text('إكمال ملف السائق'), findsOneWidget);

        final send = find.widgetWithText(FilledButton, 'إرسال الطلب للمراجعة');
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pumpAndSettle();

        final missingName = find.text('أدخل الاسم الكامل');
        expect(missingName, findsOneWidget);
        expect(tester.getTopLeft(missingName).dy, inInclusiveRange(0, 590));
        expect(requests.where((method) => method == 'PUT'), isEmpty);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        requests.add(request.method);
        if (request.url.path.endsWith('/driver/registration-options')) {
          expect(request.headers['Authorization'], 'Bearer test-profile-token');
          return http.Response(
            jsonEncode({
              'governorates': [
                {'regionId': 'najaf', 'name': 'النجف'},
              ],
              'regions': [],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        expect(request.url.path, endsWith('/legal'));
        return http.Response('{}', 503);
      }),
    );
  });
}
