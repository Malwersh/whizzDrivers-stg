import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wizz_driver/features/active_order/widgets/trip_arrival_slider.dart';
import 'package:wizz_driver/features/active_order/widgets/store_issue_bottom_sheet.dart';
import 'package:wizz_driver/features/active_order/services/store_navigation.dart';
import 'package:wizz_driver/features/active_order/services/pickup_issue_service.dart';
void main(){
 testWidgets('RTL thumb points left, fills drag path and resets incomplete drag',(tester)async{
  var calls=0;await tester.pumpWidget(MaterialApp(home:Scaffold(body:Directionality(textDirection:TextDirection.rtl,child:SizedBox(width:320,child:TripArrivalSlider(onConfirm:()async{calls++;}))))));
  final thumb=find.byKey(const Key('arrival-thumb'));final start=tester.getCenter(thumb);expect(tester.widget<Icon>(find.byIcon(Icons.arrow_back_rounded)).textDirection,TextDirection.ltr);
  final g=await tester.startGesture(start);await g.moveBy(const Offset(-100,0));await tester.pump();expect(tester.getCenter(thumb).dx,lessThan(start.dx));expect(tester.getSize(find.byKey(const Key('arrival-progress'))).width,greaterThan(64));await g.up();await tester.pumpAndSettle();expect(calls,0);expect(tester.getCenter(thumb).dx,closeTo(start.dx,1));
 });
 testWidgets('completed slide submits once while waiting',(tester)async{
  var calls=0;final done=Completer<void>();await tester.pumpWidget(MaterialApp(home:Scaffold(body:SizedBox(width:320,child:TripArrivalSlider(onConfirm:(){calls++;return done.future;})))));
  await tester.drag(find.byKey(const Key('arrival-thumb')),const Offset(-300,0));await tester.pump();expect(calls,1);await tester.drag(find.byKey(const Key('arrival-thumb')),const Offset(-300,0));expect(calls,1);done.complete();await tester.pumpAndSettle();
 });
 test('trial Maps previews local drive; normal Maps navigates actual GPS',(){final trial=StoreNavigation.directions(latitude:31.92,longitude:44.45,testOrigin:true);expect(trial.queryParameters['origin'],isNotEmpty);expect(trial.queryParameters['travelmode'],'driving');expect(trial.queryParameters.containsKey('dir_action'),isFalse);final live=StoreNavigation.directions(latitude:31.92,longitude:44.45,testOrigin:false);expect(live.queryParameters.containsKey('origin'),isFalse);expect(live.queryParameters['dir_action'],'navigate');});
 test('lost report response retries the same ID and frozen assignment',()async{
  String? id;var calls=0;final service=PickupIssueService(token:()async=>'credential',client:MockClient((r)async{calls++;final body=jsonDecode(r.body);expect(body['offerId'],'offer1');expect(body['attempt'],2);if(id==null){id=body['reportId'];throw http.ClientException('offline');}expect(body['reportId'],id);return http.Response(jsonEncode({'success':true,'orderId':'order1','reportId':id}),200);}));
  Future<void> send()async{await service.submit('order1',issueType:'StoreClosed',assignment:{'offerId':'offer1','attempt':2});}
  await expectLater(send(),throwsException);await send();expect(calls,2);
 });
 testWidgets('Other requires details and report failure stays visible',(tester)async{
  tester.view.physicalSize=const Size(390,850);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  var calls=0;await tester.pumpWidget(MaterialApp(home:Scaffold(body:StoreIssueBottomSheet(orderId:'order1',onSubmit:(type,notes)async{calls++;throw Exception('offline');}))));
  await tester.scrollUntilVisible(find.text('مشكلة أخرى'),100,scrollable:find.byType(Scrollable).first);await tester.tap(find.text('مشكلة أخرى'));await tester.pump();await tester.tap(find.text('إرسال البلاغ'));await tester.pump();expect(calls,0);
  await tester.scrollUntilVisible(find.byType(TextField),100,scrollable:find.byType(Scrollable).first);await tester.enterText(find.byType(TextField),'تفاصيل');await tester.tap(find.text('إرسال البلاغ'));await tester.pumpAndSettle();expect(calls,1);await tester.scrollUntilVisible(find.textContaining('لم يتأكد حفظ البلاغ'),100,scrollable:find.byType(Scrollable).first);expect(find.textContaining('لم يتأكد حفظ البلاغ'),findsOneWidget);expect(tester.takeException(),isNull);
 });
}
