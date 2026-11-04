import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/features/active_order/models/active_order_model.dart';
import 'package:wizz_driver/features/active_order/services/active_order_service.dart';
import 'package:wizz_driver/features/active_order/screens/at_restaurant_screen.dart';
import 'package:wizz_driver/providers/riverpod/active_order_provider.dart';

ActiveOrder fixture() => ActiveOrder.fromJson({
      'orderId': 'order1',
      'orderNumber': 'ORD1792721062420',
      'status': 'arrived_at_store',
      'restaurantName': 'مطعم فتوش',
      'restaurantAddress': 'المناذرة السوق الكبير قرب الفاكه',
      'customerName': 'Mohammed Ali',
      'customerAddress': 'عنوان الزبون',
      'paymentMethod': 'COD',
      'total': 8500,
      'items': [
        {
          'itemId': 'item1',
          'name': 'كباب يلعب النفس',
          'quantity': 2,
          'price': 0,
          'notes': 'ملاحظات الصنف',
          'modifiers': ['إضافة واحدة']
        }
      ]
    });

class Service extends ActiveOrderService {
  ActiveOrder order = fixture();
  int pickups = 0, headings = 0;
  bool failRead = false, failHeading = false, losePickupReply = false;
  @override
  Future<ActiveOrder> getOrderById(String id) async {
    if (failRead) throw Exception('offline');
    return order;
  }

  @override
  Future<ActiveOrder> pickupOrder(String id) async {
    pickups++;
    order = order.copyWith(status: 'picked_up', pickedUpAt: DateTime.now());
    if (losePickupReply) throw Exception('lost reply');
    return order;
  }

  @override
  Future<ActiveOrder> startHeadingToCustomer(String id) async {
    headings++;
    if (failHeading) {
      failHeading = false;
      throw Exception('offline');
    }
    order = order.copyWith(status: 'heading_to_customer');
    return order;
  }
}

Future<void> show(WidgetTester tester, Service service,
    {double width = 390, void Function(ActiveOrder)? next}) async {
  tester.view.physicalSize = Size(width, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
      overrides: [activeOrderServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(
                  size: Size(width, 850),
                  textScaler: const TextScaler.linear(1.3)),
              child: AtRestaurantScreen(
                  order: service.order, onContinue: next ?? (_) {})))));
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester) async {
  await tester.drag(
      find.byKey(const Key('arrival-thumb')), const Offset(-900, 0));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 390.0])
    testWidgets('pickup layout quantities notes and pinned slider at $width',
        (tester) async {
      final service = Service();
      await show(tester, service, width: width);
      expect(find.text('اسحب لتأكيد الاستلام'), findsOneWidget);
      expect(find.text('مطعم فتوش'), findsOneWidget);
      expect(find.text('0 د'), findsNothing);
      expect(service.pickups, 0);
      await tester.scrollUntilVisible(find.text('ملاحظات الصنف'), 120,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('×2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  testWidgets('pickup confirmation advances only after human gesture',
      (tester) async {
    final service = Service();
    var next = 0;
    await show(tester, service, next: (order) {
      expect(order.status, 'heading_to_customer');
      next++;
    });
    expect(service.pickups, 0);
    await confirm(tester);
    expect(service.pickups, 1);
    expect(service.headings, 1);
    expect(next, 1);
  });
  testWidgets(
      'heading retry never repeats successful pickup and hides pre-pickup actions',
      (tester) async {
    final service = Service()..failHeading = true;
    var next = 0;
    await show(tester, service, next: (_) => next++);
    await confirm(tester);
    expect(service.pickups, 1);
    expect(next, 0);
    expect(find.text('اسحب لمتابعة التوصيل'), findsOneWidget);
    await tester.tap(find.text('مساعدة'));
    await tester.pumpAndSettle();
    expect(find.text('الاعتذار عن التوصيل'), findsNothing);
    expect(find.text('الإبلاغ عن مشكلة في الاستلام'), findsNothing);
    await tester.tap(find.byTooltip('إغلاق'));
    await tester.pumpAndSettle();
    await confirm(tester);
    expect(service.pickups, 1);
    expect(service.headings, 2);
    expect(next, 1);
  });
  testWidgets(
      'lost pickup response recovers stored stage instead of resubmitting',
      (tester) async {
    final service = Service()..losePickupReply = true;
    var next = 0;
    await show(tester, service, next: (_) => next++);
    await confirm(tester);
    expect(service.pickups, 1);
    expect(service.headings, 1);
    expect(next, 1);
  });
  testWidgets('failed fresh read blocks pickup until refresh', (tester) async {
    final service = Service()..failRead = true;
    await show(tester, service);
    await confirm(tester);
    expect(service.pickups, 0);
    expect(service.headings, 0);
  });
}
