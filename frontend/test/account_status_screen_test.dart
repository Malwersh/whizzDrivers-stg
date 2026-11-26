import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wizz_driver/features/authentication/screens/account_status_screen.dart';
import 'package:wizz_driver/providers/riverpod/services_provider.dart';
import 'package:wizz_driver/services/profile_completion_service.dart';

void main() {
  testWidgets(
      'refresh after administrative approval resumes the signed-in flow',
      (tester) async {
    var response = http.Response('{"data":{"status":"SUSPENDED"}}', 200);
    final service = ProfileCompletionService(
      tokenResolver: () async => 'fixture',
      client: MockClient((_) async => response),
    );
    final router = GoRouter(
      initialLocation: '/account-status',
      routes: [
        GoRoute(
          path: '/account-status',
          builder: (_, __) => const AccountStatusScreen(),
        ),
        GoRoute(
          path: '/splash',
          builder: (_, __) => const Text('استئناف الجلسة'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileCompletionServiceProvider.overrideWithValue(service)
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('حساب معلّق'), findsOneWidget);

    final refresh = find.text('تحديث حالة الحساب');
    response = http.Response('{}', 503);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(find.text('تعذّر تحديث حالة الحساب. أعد المحاولة.'), findsOneWidget);
    expect(find.text('تم رفض طلب الانضمام'), findsNothing);

    response = http.Response(
      '{"data":{"status":"APPROVED","isVerified":true}}',
      200,
    );
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(find.text('استئناف الجلسة'), findsOneWidget);
    expect(find.text('حساب معلّق'), findsNothing);
  });
}
