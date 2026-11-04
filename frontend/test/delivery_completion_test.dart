import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/features/active_order/models/active_order_model.dart';
import 'package:wizz_driver/features/active_order/screens/delivery_completion_screen.dart';

ActiveOrder order(
        {String id = 'order1',
        String status = 'delivered',
        double? earning = 2750}) =>
    ActiveOrder.fromJson({
      'orderId': id,
      'status': status,
      'items': [],
      'totalAmount': 8500,
      if (earning != null) 'driverEarnings': earning
    });
void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
        'full screen success displays entitlement not customer cash at $width',
        (t) async {
      t.view.physicalSize = Size(width, 850);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var homes = 0;
      await t.pumpWidget(MaterialApp(
          home: DeliveryCompletionScreen(
              orderId: 'order1',
              orderNumber: 'ORD123',
              confirmedOrder: order(),
              loadOrder: (_) async => throw Exception(),
              onHome: () => homes++)));
      await t.pumpAndSettle();
      expect(find.text('تم إكمال الطلب'), findsOneWidget);
      expect(find.text('2,750 د.ع'), findsOneWidget);
      expect(find.textContaining('8,500'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      await t.tap(find.text('العودة للرئيسية'));
      expect(homes, 1);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
      'failed read never guesses earnings and retry requires correct delivered order',
      (t) async {
    var reads = 0;
    await t.pumpWidget(MaterialApp(
        home: DeliveryCompletionScreen(
            orderId: 'order1',
            orderNumber: 'ORD123',
            loadOrder: (_) async {
              reads++;
              return reads == 1 ? order(id: 'other') : order();
            },
            onHome: () {})));
    await t.pumpAndSettle();
    expect(find.text('2,750 د.ع'), findsNothing);
    expect(find.textContaining('تعذّر تحميل'), findsOneWidget);
    await t.tap(find.text('إعادة المحاولة'));
    await t.pumpAndSettle();
    expect(find.text('2,750 د.ع'), findsOneWidget);
    expect(reads, 2);
  });
  testWidgets('zero confirmed entitlement remains zero', (t) async {
    await t.pumpWidget(MaterialApp(
        home: DeliveryCompletionScreen(
            orderId: 'order1',
            orderNumber: 'ORD123',
            confirmedOrder: order(earning: 0),
            loadOrder: (_) async => throw Exception(),
            onHome: () {})));
    await t.pumpAndSettle();
    expect(find.text('0 د.ع'), findsOneWidget);
  });
}
