import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/widgets/offer_display_receipt.dart';

void main() {
  testWidgets('only visible active response controls acknowledge, once',
      (tester) async {
    var count = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OfferDisplayReceipt(
                expiresAt: DateTime.now().add(const Duration(minutes: 1)),
                acknowledge: () async {
                  count++;
                  return true;
                },
                child: const SizedBox(height: 48, width: 200)))));
    await tester.pump();
    expect(count, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(count, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'off-screen controls are not acknowledged until scrolled into view',
      (tester) async {
    var count = 0;
    final scroll = ScrollController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                controller: scroll,
                child: Column(children: [
                  const SizedBox(height: 2000),
                  OfferDisplayReceipt(
                      expiresAt: DateTime.now().add(const Duration(minutes: 1)),
                      acknowledge: () async {
                        count++;
                        return true;
                      },
                      child: const SizedBox(height: 48, width: 200))
                ])))));
    await tester.pump();
    expect(count, 0);
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump(const Duration(seconds: 3));
    expect(count, 1);
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });
  testWidgets('expired offer never acquires a receipt', (tester) async {
    var count = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OfferDisplayReceipt(
                expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
                acknowledge: () async {
                  count++;
                  return true;
                },
                child: const SizedBox(height: 48, width: 200)))));
    await tester.pump(const Duration(seconds: 3));
    expect(count, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
