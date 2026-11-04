import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/features/active_order/services/order_persistence_service.dart';
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
      {String? reason,Map<String,dynamic>? position,String? issueId,String? note}) {
    calls++;
    return pending.future;
  }
}

void main() {
  test('terminal cache cleanup preserves a different active order', () async {
    SharedPreferences.setMockInitialValues({'active_order':'new-order','order_state':'picked_up','order_data_new-order':'{}'});
    await OrderPersistenceService.clearActiveOrder(expectedOrderId:'old-return');
    expect((await SharedPreferences.getInstance()).getString('active_order'),'new-order');
    await OrderPersistenceService.clearActiveOrder(expectedOrderId:'new-order');
    expect((await SharedPreferences.getInstance()).getString('active_order'),isNull);
  });
  testWidgets('return polls until confirmed and offers terminal home action only after server confirmation', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var phase='return_arrived';
    var finished=0;
    await tester.pumpWidget(MaterialApp(home:ReturnOrderScreen(locate:()async=>{'latitude':31.91,'longitude':44.45,'accuracyMeters':5.0,'capturedAt':DateTime.now().toUtc().toIso8601String()},order:order(phase),load:(_) async=>order(phase),onFinished:(id) async {expect(id,'order1');finished++;})));
    await tester.pumpAndSettle();
    expect(find.text('العودة للرئيسية'),findsNothing);
    phase='returned';
    await tester.pump(const Duration(seconds:15));
    await tester.pumpAndSettle();
    expect(find.text('أكد الفرع الاستلام وانتهت العودة'),findsOneWidget);
    expect(finished,1);
    await tester.pumpWidget(const SizedBox());
  });
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
        home: ReturnOrderScreen(locate:()async=>{'latitude':31.91,'longitude':44.45,'accuracyMeters':5.0,'capturedAt':DateTime.now().toUtc().toIso8601String()},
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
  testWidgets('pending disposition offers no arrival or self-directed return action',(tester)async{
    final pending=ActiveOrder.fromJson({'orderId':'order1','status':'returning','paymentMethod':'COD','items':[],'financialAssignment':{'offerId':'offer1','attempt':1,'returnId':'ret1','returnStatus':'REQUESTED','exceptionPolicyVersion':'OECSR_STAGING_COD_V1'}});
    await tester.pumpWidget(MaterialApp(home:ReturnOrderScreen(locate:()async=>{'latitude':31.91,'longitude':44.45,'accuracyMeters':5.0,'capturedAt':DateTime.now().toUtc().toIso8601String()},order:pending,load:(_)async=>pending)));
    await tester.pumpAndSettle();expect(find.textContaining('أُرسل البلاغ للإدارة'),findsOneWidget);expect(find.text('وصلت إلى الفرع ومعي الأصناف'),findsNothing);expect(find.text('أعد الأصناف إلى الفرع'),findsNothing);await tester.pumpWidget(const SizedBox());
  });

  testWidgets('authorization and recovery refresh automatically within two seconds without manual refresh',(tester)async{
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var reads=0;
    final pending=ActiveOrder.fromJson({'orderId':'order1','status':'returning','paymentMethod':'COD','items':[],'financialAssignment':{'offerId':'offer1','attempt':1,'returnId':'ret1','returnStatus':'REQUESTED'}});
    await tester.pumpWidget(MaterialApp(home:ReturnOrderScreen(order:pending,load:(_)async{reads++;if(reads==1)throw Exception('offline');return order('returning');})));
    await tester.pumpAndSettle();expect(find.text('وصلت إلى الفرع ومعي الأصناف'),findsNothing);
    await tester.pump(const Duration(seconds:2));await tester.pumpAndSettle();expect(find.text('وصلت إلى الفرع ومعي الأصناف'),findsOneWidget);expect(reads,2);await tester.pumpWidget(const SizedBox());
  });
  testWidgets('elapsed obstacle wait never exposes a finish action',(tester)async{
    final arrived=ActiveOrder.fromJson({'orderId':'order1','status':'return_arrived','paymentMethod':'COD','items':[],'financialAssignment':{'offerId':'offer1','attempt':1,'returnId':'ret1','returnStatus':'ARRIVED_AT_BRANCH','serverNow':'2026-10-21T10:06:00Z','returnHandover':{'state':'AWAITING_SUPPORT','escalationAt':'2026-10-21T10:05:00Z','reason':'BRANCH_CLOSED'}}});
    await tester.pumpWidget(MaterialApp(home:ReturnOrderScreen(order:arrived,load:(_)async=>arrived)));
    await tester.pumpAndSettle();expect(find.text('سُجل البلاغ — بانتظار تعليمات الدعم'),findsOneWidget);expect(find.text('العودة للرئيسية'),findsNothing);expect(find.text('وصلت إلى الفرع ومعي الأصناف'),findsNothing);expect(find.textContaining('انتهت مهلة الانتظار'),findsOneWidget);await tester.pumpWidget(const SizedBox());
  });

}
