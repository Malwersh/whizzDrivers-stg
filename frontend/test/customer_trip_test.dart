import 'package:wizz_driver/features/active_order/widgets/driver_trip_help.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/features/active_order/models/active_order_model.dart';
import 'package:wizz_driver/features/active_order/services/trip_route_service.dart';
import 'package:wizz_driver/features/active_order/screens/heading_to_customer_screen.dart';
import 'package:wizz_driver/features/active_order/widgets/trip_arrival_slider.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
        'customer route at $width: full destination, cash and safe help',
        (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final order = ActiveOrder.fromJson({
        'orderId': 'order1',
        'status': 'heading_to_customer',
        'financialAssignment': {'offerId': 'offer1', 'attempt': 1},
        'restaurantName': 'مطعم فتوش',
        'restaurantLat': 31.92,
        'restaurantLng': 44.45,
        'customerName': 'Mohammed Ali',
        'customerAddress': 'عنوان الزبون الكامل للاختبار',
        'customerLat': 31.9,
        'customerLng': 44.48,
        'customerPhone': '+9647800000000',
        'customerNearestLandmark': 'موقع محدد من الخريطة',
        'total': 8500,
        'paymentMethod': 'cash',
        'items': []
      });
      var geometry = 0;
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
              home: HeadingToCustomerScreen(
                  order: order,
                  loadOrder: (_) async => order,
                  loadRoute: (_) async => TripRoadRoute([
                        [44.45, 31.92],
                        [44.46, 31.91],
                        [44.48, 31.9]
                      ], 3067, 480),
                  mapBuilder: (_, lines) {
                    geometry = lines.length;
                    return const SizedBox();
                  }))));
      await tester.pumpAndSettle();
      expect(geometry, 2);
      expect(find.byType(TripArrivalSlider), findsOneWidget);
      expect(find.textContaining('علامة قريبة:'), findsNothing);
      await tester.scrollUntilVisible(find.text('8500 د.ع'), 150,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('8500 د.ع'), findsOneWidget);
      expect(find.text('عنوان الزبون الكامل للاختبار'), findsOneWidget);
      await tester.tap(find.text('مساعدة'));
      await tester.pumpAndSettle();
      expect(find.text('الاعتذار عن التوصيل'), findsNothing);
      expect(find.text('الإبلاغ عن مشكلة في الاستلام'), findsNothing);
      expect(find.text('الاتصال بالزبون'), findsWidgets);
      expect(find.text('تعذّر إكمال التوصيل'), findsOneWidget);
      final whiteSurface = find.descendant(
          of: find.byType(DriverTripHelp),
          matching: find.byWidgetPredicate((w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == Colors.white));
      expect(whiteSurface, findsOneWidget);
      expect(tester.getBottomLeft(whiteSurface).dy, 850);
      expect(tester.getBottomLeft(find.text('العودة إلى الطلب')).dy,
          lessThan(816));
      final helpSurface = find.ancestor(
          of: find.text('تعذّر إكمال التوصيل'),
          matching: find.byType(SingleChildScrollView));
      expect(helpSurface, findsOneWidget);
      expect(
          find.descendant(
              of: helpSurface, matching: find.text('العودة إلى الطلب')),
          findsOneWidget);
      await tester.tap(find.text('العودة إلى الطلب'));
      await tester.pumpAndSettle();
      expect(find.text('مساعدة في هذه الرحلة'), findsNothing);
      expect(find.byType(TripArrivalSlider), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
