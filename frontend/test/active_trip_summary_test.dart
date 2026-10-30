import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wizz_driver/features/active_order/models/active_order_model.dart';
import 'package:wizz_driver/features/active_order/widgets/active_trip_summary.dart';
import 'package:wizz_driver/features/active_order/widgets/unassign_order_bottom_sheet.dart';
import 'package:wizz_driver/features/active_order/services/financial_order_actions.dart';
ActiveOrder order(String status) => ActiveOrder.fromJson({'orderId':'order1','status':status,'paymentMethod':'COD','total':8500,'restaurantName':'مطعم فتوش','customerName':'Mohammed Ali','items':[]});
void main() {
 for (final width in [320.0,390.0]) {
  testWidgets('trip action fits narrow screen $width', (tester) async {
   tester.view.physicalSize=Size(width,800);tester.view.devicePixelRatio=1;
   addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
   var calls=0;
   await tester.pumpWidget(MaterialApp(home:MediaQuery(data:MediaQueryData(size:Size(width,800),textScaler:const TextScaler.linear(1.3)),child:Scaffold(body:ActiveTripSummary(order:order('assigned').copyWith(restaurantAddress:'النجف شارع طويل قرب السوق في منطقة الاختبار'),action:ElevatedButton(onPressed:()=>calls++,child:const Text('انطلق إلى المطعم')),onUnassign:(){})))));
   await tester.pumpAndSettle();expect(find.text('جاهز للانطلاق'),findsWidgets);
   await tester.tap(find.text('انطلق إلى المطعم'));expect(calls,1);expect(tester.takeException(),isNull);
  });
 }
 test('unassign allowed only before pickup',(){
  for(final s in ['assigned','accepted','heading_to_store','arrived_at_store']){expect(TripStyle.canUnassign(order(s)),isTrue);}
  for(final s in ['picked_up','heading_to_customer','arrived_at_customer','delivered','returning']){expect(TripStyle.canUnassign(order(s)),isFalse);}
  expect(TripStyle.canUnassign(order('accepted').copyWith(pickedUpAt:DateTime.now())),isFalse);
 });
 test('financial unassign pins assignment and rejects wrong receipt',()async{
  final service=FinancialOrderActions(token:()async=>'token',client:MockClient((r)async{
   expect(r.url.path,endsWith('/driver/orders/order1/financial-unassign'));
   expect(jsonDecode(r.body),{'offerId':'offer1','attempt':2,'cashCollected':false,'reason':'Emergency'});
   return http.Response('{"success":true,"orderId":"another-order"}',200);
  }));
  await expectLater(service.send('order1','financial-unassign',{'offerId':'offer1','attempt':2},reason:'Emergency'),throwsException);
 });
 testWidgets('unassign failure remains visible', (tester)async{
  tester.view.physicalSize=const Size(390,1200);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final pending=Completer<void>();var calls=0;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:UnassignOrderBottomSheet(orderId:'order1',onUnassign:(_){calls++;return pending.future;}))));
  await tester.tap(find.text('حالة طارئة'));await tester.pump();
  await tester.ensureVisible(find.text('تأكيد الاعتذار'));await tester.tap(find.text('تأكيد الاعتذار'));await tester.tap(find.text('تأكيد الاعتذار'));await tester.pump();expect(calls,1);
  pending.completeError(Exception('تعذر الاتصال'));await tester.pumpAndSettle();
  expect(find.text('الاعتذار عن التوصيل'),findsOneWidget);expect(find.textContaining('تعذر الاتصال'),findsOneWidget);expect(tester.takeException(),isNull);
 });
}
