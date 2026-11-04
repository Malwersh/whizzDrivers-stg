import 'package:wizz_driver/features/active_order/services/delivery_proof_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/features/active_order/models/active_order_model.dart';
import 'package:wizz_driver/features/active_order/screens/at_customer_screen.dart';
import 'package:wizz_driver/features/active_order/widgets/trip_arrival_slider.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('delivery cash confirmation gates slider at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      var reads = 0;
      final order = ActiveOrder.fromJson({
        'orderId': 'order1',
        'orderNumber': 'ORD123',
        'status': 'arrived_at_customer',
        'customerName': 'Mohammed Ali',
        'customerAddress': 'العنوان الكامل للزبون في النجف',
        'customerPhone': '+9647800000000',
        'paymentMethod': 'COD',
        'total': 8500,
        'items': [
          {'name': 'كباب', 'quantity': 2, 'price': 3500}
        ]
      });
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
              home: AtCustomerScreen(
                  order: order,
                  proofService: DeliveryProofService(
                      token: () async => 'token',
                      client: MockClient((_) async => http.Response(
                          '{"success":true,"orderId":"order1","proofs":[]}',
                          200))),
                  loadOrder: (_) async {
                    reads++;
                    return order;
                  }))));
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(
          tester
              .widget<TripArrivalSlider>(find.byType(TripArrivalSlider))
              .enabled,
          isFalse);
      expect(find.text('العنوان الكامل للزبون في النجف'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('استلمت 8500 د.ع بالكامل'), 150,
          scrollable: find.byType(Scrollable).first);
      await Scrollable.ensureVisible(
          tester.element(find.text('استلمت 8500 د.ع بالكامل')),
          alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(find.text('استلمت 8500 د.ع بالكامل'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TripArrivalSlider>(find.byType(TripArrivalSlider))
              .enabled,
          isTrue);
      expect(find.text('مراجعة النقد ورد المبلغ'), findsOneWidget);
      expect(find.text('صورة التسليم'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
