import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wizz_driver/config/environment.dart';
import 'package:wizz_driver/screens/auth/phone_otp_login_screen.dart';

void main() {
  testWidgets('brand and phone and code steps fit a compact phone',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(320, 580));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final paths = <String>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.25)),
                child: child!,
              ),
              home: const PhoneOtpLoginScreen(),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('شركة الانطلاق الخاطف'), findsOneWidget);
        expect(find.text('مرحبًا بك'), findsOneWidget);
        expect(find.text('ربط أو استعادة حساب سابق'), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);

        const phone = ValueKey('driver-login-phone');
        const code = ValueKey('driver-login-code');
        await tester.enterText(find.byKey(phone), '07700000009');
        await tester.ensureVisible(find.text('إرسال رمز التحقق'));
        await tester.tap(find.text('إرسال رمز التحقق'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(paths, ['/${Environment.environment}/auth/phone/send']);
        expect(find.byKey(phone), findsNothing);
        expect(find.byKey(code), findsOneWidget);
        expect(find.text('التحقق من رقم الهاتف'), findsOneWidget);
        expect(find.text('+9647700000009'), findsOneWidget);
        expect(find.textContaining('إعادة الإرسال بعد'), findsOneWidget);

        await tester.enterText(find.byKey(code), '123');
        await tester.ensureVisible(find.text('تحقق وادخل'));
        await tester.tap(find.text('تحقق وادخل'));
        await tester.pump();
        expect(
            find.text('أدخل رمز التحقق المكوّن من ٦ أرقام.'), findsOneWidget);
        expect(paths, hasLength(1));
        await tester.ensureVisible(find.text('تغيير الرقم'));
        await tester.tap(find.text('تغيير الرقم'));
        await tester.pump();
        expect(find.byKey(phone), findsOneWidget);
        expect(find.byKey(code), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
      },
      () => MockClient((request) async {
        paths.add(request.url.path);
        expect(jsonDecode(request.body), {'phone': '+9647700000009'});
        return http.Response(
          '{"sessionId":"fixture","expiresIn":300,"resendAfter":60}',
          200,
        );
      }),
    );
  });
}
