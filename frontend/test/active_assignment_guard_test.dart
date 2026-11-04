import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/features/active_order/models/active_order_model.dart';
import 'package:wizz_driver/features/active_order/services/active_order_service.dart';
import 'package:wizz_driver/features/active_order/widgets/active_assignment_guard.dart';
import 'package:wizz_driver/providers/riverpod/active_order_provider.dart';

ActiveOrder trip(String id, [String status = 'arrived_at_store']) =>
    ActiveOrder.fromJson({'orderId': id, 'status': status, 'items': []});

class Service extends ActiveOrderService {
  Future<ActiveOrder?> Function() read = () async => trip('old');
  @override
  Future<ActiveOrder?> getActiveOrder() => read();
}

void main() {
  Future<ProviderContainer> mount(WidgetTester tester, Service service) async {
    SharedPreferences.setMockInitialValues({
      'active_order': 'old',
      'order_state': 'arrived_at_store',
      'order_data_old': '{}',
      'isSearchingForOffers': true
    });
    final container = ProviderContainer(
        overrides: [activeOrderServiceProvider.overrideWithValue(service)]);
    container.read(activeOrderProvider.notifier).setOrder(trip('old'));
    final router = GoRouter(initialLocation: '/trip', routes: [
      GoRoute(
          path: '/', builder: (_, __) => const Scaffold(body: Text('HOME'))),
      GoRoute(
          path: '/active-order',
          builder: (_, __) => const Scaffold(body: Text('NEW TRIP'))),
      GoRoute(
          path: '/trip',
          builder: (_, __) => ActiveAssignmentGuard(
              order: trip('old'), child: const Scaffold(body: Text('PICKUP')))),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      container.dispose();
    });
    return container;
  }

  for (final outcome in ['cancelled', 'unassigned']) {
    testWidgets('$outcome closes pickup and clears only old cache',
        (tester) async {
      final service = Service();
      final container = await mount(tester, service);
      expect(find.text('PICKUP'), findsOneWidget);
      service.read =
          () async => outcome == 'cancelled' ? trip('old', 'cancelled') : null;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(container.read(activeOrderProvider).order, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_order'), isNull);
      expect(prefs.getBool('isSearchingForOffers'), true);
    });
  }
  testWidgets('cancelled detail refresh also exits stale pickup screen',
      (tester) async {
    final service = Service();
    final container = await mount(tester, service);
    container
        .read(activeOrderProvider.notifier)
        .setOrder(trip('old', 'cancelled'));
    service.read = () async => null;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });
  testWidgets('offline preserves pickup and persisted assignment',
      (tester) async {
    final service = Service()..read = () async => throw Exception('offline');
    final container = await mount(tester, service);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('PICKUP'), findsOneWidget);
    expect(container.read(activeOrderProvider).order?.orderId, 'old');
    expect((await SharedPreferences.getInstance()).getString('active_order'),
        'old');
  });
  testWidgets('resume reconciles without waiting for timer', (tester) async {
    final service = Service();
    await mount(tester, service);
    service.read = () async => null;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });
  testWidgets('new live trip routes to it instead of marking free',
      (tester) async {
    final service = Service();
    final container = await mount(tester, service);
    service.read = () async => trip('new');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('NEW TRIP'), findsOneWidget);
    expect(container.read(activeOrderProvider).order?.orderId, 'new');
  });
  testWidgets('late old read cannot clear newer local assignment',
      (tester) async {
    final service = Service();
    final container = await mount(tester, service);
    final delayed = Completer<ActiveOrder?>();
    service.read = () => delayed.future;
    await tester.pump(const Duration(seconds: 5));
    container.read(activeOrderProvider.notifier).setOrder(trip('new'));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_order', 'new');
    delayed.complete(null);
    await tester.pumpAndSettle();
    expect(container.read(activeOrderProvider).order?.orderId, 'new');
    expect(prefs.getString('active_order'), 'new');
    expect(find.text('HOME'), findsNothing);
  });
}
