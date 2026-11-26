import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/features/active_order/models/active_order_model.dart';
import 'package:wizz_driver/features/active_order/screens/at_customer_screen.dart';
import 'package:wizz_driver/features/active_order/services/active_order_service.dart';
import 'package:wizz_driver/providers/riverpod/active_order_provider.dart';

ActiveOrder order(String status, {String id = 'cash-order'}) =>
    ActiveOrder.fromJson({
      'orderId': id,
      'status': status,
      'items': [],
      'totalAmount': 9250,
      'driverEarnings': 2750,
      'paymentMethod': 'cash'
    });

class ReviewService extends ActiveOrderService {
  String status = 'arrived_at_customer';
  bool fail = false;
  final ids = <String>[];
  @override
  Future<ActiveOrder> getOrderById(String id) async {
    ids.add(id);
    if (fail) throw Exception('unavailable');
    return order(status);
  }
}

void main() {
  for (final scenario in [
    'already delivered',
    'poll completion',
    'read failure',
    'new assignment'
  ]) {
    testWidgets('delivery reconciles $scenario without resubmission',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'active_order': 'cash-order',
        'order_state': 'arrived_at_customer',
        'order_data_cash-order': '{}',
        'isSearchingForOffers': true
      });
      final service = ReviewService();
      if (scenario == 'already delivered') service.status = 'delivered';
      if (scenario == 'read failure') service.fail = true;
      final container = ProviderContainer(
          overrides: [activeOrderServiceProvider.overrideWithValue(service)]);
      final router = GoRouter(initialLocation: '/delivery', routes: [
        GoRoute(
            path: '/', builder: (_, __) => const Scaffold(body: Text('HOME'))),
        GoRoute(
            path: '/delivery',
            builder: (_, __) =>
                AtCustomerScreen(order: order('arrived_at_customer')))
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      if (scenario != 'already delivered') {
        expect(find.text('HOME'), findsNothing);
        if (scenario == 'new assignment') {
          container
              .read(activeOrderProvider.notifier)
              .setOrder(order('accepted', id: 'new-order'));
          await (await SharedPreferences.getInstance())
              .setString('active_order', 'new-order');
        }
        if (scenario != 'read failure') service.status = 'delivered';
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      }
      expect(service.ids.every((id) => id == 'cash-order'), true);
      final prefs = await SharedPreferences.getInstance();
      if (scenario == 'read failure') {
        expect(find.text('HOME'), findsNothing);
        expect(prefs.getString('active_order'), 'cash-order');
        service.fail = false;
        await tester.tap(find.byTooltip('تحديث حالة الطلب'));
        await tester.pumpAndSettle();
        expect(find.text('HOME'), findsNothing);
      } else {
        if (scenario != 'new assignment') {
          expect(find.text('تم إكمال الطلب'), findsOneWidget);
          expect(find.text('2,750 د.ع'), findsOneWidget);
          await tester.tap(find.text('العودة للرئيسية'));
          await tester.pumpAndSettle();
        }
        expect(find.text('HOME'), findsOneWidget);
        expect(prefs.getString('active_order'),
            scenario == 'new assignment' ? 'new-order' : null);
        expect(container.read(activeOrderProvider).order?.orderId,
            scenario == 'new assignment' ? 'new-order' : null);
      }
      expect(prefs.getBool('isSearchingForOffers'), true);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      container.dispose();
    });
  }
}
