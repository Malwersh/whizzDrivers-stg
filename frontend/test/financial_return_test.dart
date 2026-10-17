import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wizz_driver/features/active_order/models/active_order_model.dart';
import 'package:wizz_driver/features/active_order/screens/return_order_screen.dart';
import 'package:wizz_driver/features/active_order/services/financial_order_actions.dart';

ActiveOrder order(String status) => ActiveOrder.fromJson({
      'orderId': 'order1',
      'status': status,
      'paymentMethod': 'COD',
      'financialAssignment': {
        'offerId': 'offer1',
        'attempt': 1,
        'returnId': 'ret1',
        'returnStatus':
            status == 'returning' ? 'RETURNING' : 'ARRIVED_AT_BRANCH'
      },
      'items': []
    });

class Actions extends FinancialOrderActions {
  final pending = Completer<Map<String, dynamic>>();
  int calls = 0;
  @override
  Future<Map<String, dynamic>> send(
      String id, String action, Map<String, dynamic> assignment,
      {String? reason}) {
    calls++;
    return pending.future;
  }
}

void main() {
  test(
      'return transport sends explicit assignment and rejects a response from a replaced login',
      () async {
    String? token = 'first';
    Map<String, dynamic>? seen;
    final service = FinancialOrderActions(
        token: () async => token,
        client: MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer first');
          expect(r.body, contains('"cashCollected":false'));
          seen = {};
          token = 'second';
          return http.Response('{"success":true,"orderId":"order1"}', 200);
        }));
    await expectLater(
        service.send(
            'order1', 'request-return', {'offerId': 'offer1', 'attempt': 1},
            reason: 'CUSTOMER_REFUSED'),
        throwsException);
    expect(seen, isNotNull);
  });
  test(
      'active order preserves financial assignment through copy/cache and recognizes COD',
      () {
    final a = order('returning');
    expect(a.isCashPayment, isTrue);
    expect(a.copyWith(status: 'return_arrived').financialAssignment?['attempt'],
        1);
    expect(ActiveOrder.fromJson(a.toJson()).isReturning, isTrue);
  });
  testWidgets(
      'return waits for no-cash confirmation and server acknowledgement before showing returning',
      (tester) async {
    final actions = Actions();
    String phase = 'picked_up';
    await tester.pumpWidget(MaterialApp(
        home: ReturnOrderScreen(
            order: order('picked_up'),
            actions: actions,
            load: (id) async => order(phase))));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(actions.calls, 0);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(actions.calls, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    phase = 'returning';
    actions.pending.complete({'success': true, 'orderId': 'order1'});
    await tester.pumpAndSettle();
    expect(find.text('أعد الأصناف إلى الفرع'), findsOneWidget);
    expect(find.text('وصلت إلى الفرع ومعي الأصناف'), findsOneWidget);
  });
}
