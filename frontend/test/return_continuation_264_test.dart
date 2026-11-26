import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/active_order/screens/return_continuation_screen.dart';
Map<String,dynamic> fixture({bool driver=true}) => {'success':true,'orderId':'order1','caseId':'case1','caseKey':'RETURN#1','version':3,'taskCompleted':false,'claimPolicy':{'appealSeconds':259200},'appeals':[],'balance':{'driverRemainingTotal':1,'companyRemainingTotal':0},'plan':{'planId':'plan1','reason':'خطة اختبار موثقة','lines':[{'lineId':'line_1','name':'وجبة الاختبار','quantity':1,'treatment':'RETURN_TO_MERCHANT'}]},'execution':{'lines':driver?{}:{'line_1':{'handover':{'recordId':'driver-record'}}}}};
void main(){
 testWidgets('driver explicitly attests the exact authorized line; the client cannot send an actor, quantity or money', (tester)async{
 final posts=<Map<String,dynamic>>[];final value=fixture();
 await tester.pumpWidget(MaterialApp(home:ReturnContinuationScreen(orderId:'order1',caseKey:'CURRENT',driver:true,call:(body)async{if(body['action']!='READ_RETURN_CONTINUATION'){posts.add(body);value['execution']={'lines':{'line_1':{'handover':{'recordId':'saved'}}}};}return value;})));
 await tester.pumpAndSettle();expect(posts,isEmpty);
 final note=find.widgetWithText(TextField,'تعليل الإجراء أو الاعتراض ومرجع الإثبات');await tester.ensureVisible(note);await tester.enterText(note,'مرجع إقرار التسليم الفعلي');
 final hand=find.text('أسجل تسليمي الكمية فعليًا');await tester.ensureVisible(hand);await tester.tap(hand);await tester.pumpAndSettle();
 final save=find.widgetWithText(FilledButton,'حفظ الإقرار');expect(tester.widget<FilledButton>(save).onPressed,isNull);expect(posts,isEmpty);
 await tester.tap(find.byType(CheckboxListTile));await tester.pumpAndSettle();await tester.tap(save);await tester.pumpAndSettle();expect(posts.length,1);expect(posts.single['lineId'],'line_1');expect(posts.single['planId'],'plan1');expect(posts.single['expectedVersion'],3);expect(posts.single['confirmPhysicalExecution'],true);expect(posts.single.containsKey('actorId'),false);expect(posts.single.containsKey('quantity'),false);expect(posts.single.containsKey('amount'),false);expect(find.text('سُجل إقرارك؛ بانتظار تأكيد الطرف المختص.'),findsOneWidget);
 });
 testWidgets('merchant supplemental receipt requires an explicit condition and keeps its handover reference', (tester)async{
 final posts=<Map<String,dynamic>>[], value=fixture(driver:false);
 await tester.pumpWidget(MaterialApp(home:ReturnContinuationScreen(orderId:'order1',caseKey:'RETURN#1',driver:false,call:(body)async{if(body['action']!='READ_RETURN_CONTINUATION'){posts.add(body);value['execution']={'lines':{'line_1':{'terminal':{'outcome':'RECEIVED_BY_MERCHANT'}}}};}return value;})));
 await tester.pumpAndSettle();final receive=find.widgetWithText(FilledButton,'أؤكد استلامي الكمية المرتبطة بالخطة');expect(tester.widget<FilledButton>(receive).onPressed,isNull);
 final field=find.byType(DropdownButtonFormField<String>).first;await tester.ensureVisible(field);await tester.tap(field);await tester.pumpAndSettle();await tester.tap(find.text('تالفة').last);await tester.pumpAndSettle();
 final note=find.widgetWithText(TextField,'تعليل الإجراء أو الاعتراض ومرجع الإثبات');await tester.ensureVisible(note);await tester.enterText(note,'إقرار استلام إضافي بحالة تالفة');await tester.ensureVisible(receive);await tester.tap(receive);await tester.pumpAndSettle();await tester.tap(find.byType(CheckboxListTile));await tester.pumpAndSettle();await tester.tap(find.text('حفظ الإقرار'));await tester.pumpAndSettle();
 expect(posts.single['action'],'RECEIVE_RETURN_REMAINDER');expect(posts.single['condition'],'DAMAGED');expect(posts.single['handoverId'],'driver-record');expect(posts.single.containsKey('allItemsReceived'),false);
 });
}
