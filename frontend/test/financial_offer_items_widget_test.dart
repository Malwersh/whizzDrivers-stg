import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/models/wave_offer.dart';
import 'package:wizz_driver/features/home/widgets/order_details_bottom_sheet.dart';
void main() {
  testWidgets('item sheet shows the ordered quantity and normalized unit price', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: OrderItemsBottomSheet(
      currency: 'IQD', items: [OrderItem(itemId: 'i1', name: 'كباب', quantity: 2, price: 3500, notes: 'بدون بصل')],
    ))));
    expect(find.text('كباب'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('سعر القطعة: 3500 IQD'), findsOneWidget);
    expect(find.text('بدون بصل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
