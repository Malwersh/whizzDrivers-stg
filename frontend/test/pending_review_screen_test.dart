import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../lib/features/authentication/screens/pending_review_screen.dart';
import '../lib/models/profile_status.dart';
import '../lib/services/profile_completion_service.dart';
import '../lib/providers/riverpod/services_provider.dart';

class ReviewService extends ProfileCompletionService {
  bool approved = false;
  bool failed = false;
  int calls = 0;
  @override
  Future<ProfileStatus> checkProfileCompleteness() async {
    calls++;
    return ProfileStatus(
        exists: true,
        status: approved
            ? ProfileStatusEnum.active
            : ProfileStatusEnum.pendingReview,
        isComplete: true,
        missingFields: [],
        needsRedirect: false,
        error: failed ? 'network' : null);
  }
}

Future<void> mount(WidgetTester tester, ReviewService service) async {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(initialLocation: '/pending-review', routes: [
    GoRoute(
        path: '/pending-review',
        builder: (context, state) => const PendingReviewScreen()),
    GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Text('approved home'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(overrides: [
    profileCompletionServiceProvider.overrideWithValue(service),
  ], child: MaterialApp.router(routerConfig: router)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'already approved driver leaves review screen after authoritative check',
      (tester) async {
    final service = ReviewService()..approved = true;
    await mount(tester, service);
    expect(find.text('approved home'), findsOneWidget);
    expect(service.calls, 1);
  });
  testWidgets('manual recheck observes approval without polling',
      (tester) async {
    final service = ReviewService();
    await mount(tester, service);
    expect(find.text('تحت المراجعة'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(service.calls, 1);
    service.approved = true;
    await tester.tap(find.text('التحقق من حالة الطلب'));
    await tester.pumpAndSettle();
    expect(find.text('approved home'), findsOneWidget);
    expect(service.calls, 2);
  });
  testWidgets('failed status check keeps driver in review and allows retry',
      (tester) async {
    final service = ReviewService()..failed = true;
    await mount(tester, service);
    expect(find.text('تعذر التحقق من الحالة. أعد المحاولة.'), findsOneWidget);
    expect(find.text('approved home'), findsNothing);
    service
      ..failed = false
      ..approved = true;
    await tester.tap(find.text('التحقق من حالة الطلب'));
    await tester.pumpAndSettle();
    expect(find.text('approved home'), findsOneWidget);
  });
}
