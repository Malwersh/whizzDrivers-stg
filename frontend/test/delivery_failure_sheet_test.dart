import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/features/active_order/models/active_order_model.dart';
import 'package:wizz_driver/features/active_order/services/financial_order_actions.dart';
import 'package:wizz_driver/features/active_order/screens/return_order_screen.dart';

ActiveOrder order(String status) => ActiveOrder.fromJson({
      'orderId': 'order1',
      'orderNumber': 'ORD123',
      'status': status,
      'items': [],
      'financialAssignment': {
        'offerId': 'offer1',
        'attempt': 1,
        'returnStatus': status == 'returning' ? 'RETURNING' : null
      }
    });

class Actions extends FinancialOrderActions {
  int calls = 0;
  VoidCallback? submitted;
  @override
  Future<Map<String, dynamic>> send(
      String id, String action, Map<String, dynamic> assignment,
      {String? reason,
      Map<String, dynamic>? position,
      String? issueId,
      String? note}) async {
    calls++;
    submitted?.call();
    return {'success': true};
  }
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('bottom sheet closes without action at $width', (t) async {
      t.view.physicalSize = Size(width, 850);
      t.view.devicePixelRatio = 1;
      t.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPadding);
      final actions = Actions();
      await t.pumpWidget(ProviderScope(
          child: MaterialApp(
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () => showDeliveryFailureSheet(
                              context, order('arrived_at_customer'),
                              load: (_) async => order('arrived_at_customer'),
                              actions: actions),
                          child: const Text('فتح')))))));
      await t.tap(find.text('فتح'));
      await t.pumpAndSettle();
      expect(
          t.widget<ReturnOrderScreen>(find.byType(ReturnOrderScreen)).asSheet,
          isTrue);
      expect(find.text('الطلب ORD123'), findsOneWidget);
      expect(find.text('العودة إلى الطلب'), findsOneWidget);
      expect(t.getTopLeft(find.byType(ReturnOrderScreen)).dy, greaterThan(0));
      await t.tap(find.text('العودة إلى الطلب'));
      await t.pumpAndSettle();
      expect(find.byType(ReturnOrderScreen), findsNothing);
      expect(find.text('فتح'), findsOneWidget);
      expect(actions.calls, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
      'explicit request keeps approved return workflow after sheet closes',
      (t) async {
    var status = 'arrived_at_customer';
    final actions = Actions()..submitted = () => status = 'returning';
    await t.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () =>
                            showDeliveryFailureSheet(context, order(status),
                                load: (_) async => order(status),
                                actions: actions,
                                locate: () async => {
                                      'latitude': 31.9,
                                      'longitude': 44.4,
                                      'accuracyMeters': 10,
                                      'capturedAt': '2026-10-23T04:00:00Z'
                                    }),
                        child: const Text('فتح')))))));
    await t.tap(find.text('فتح'));
    await t.pumpAndSettle();
    await t.tap(find.byType(CheckboxListTile));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byType(FilledButton));
    await t.tap(find.byType(FilledButton));
    await t.pumpAndSettle();
    expect(actions.calls, 1);
    expect(t.widget<ReturnOrderScreen>(find.byType(ReturnOrderScreen)).asSheet,
        isFalse);
    expect(find.text('وصلت إلى الفرع ومعي الأصناف'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
