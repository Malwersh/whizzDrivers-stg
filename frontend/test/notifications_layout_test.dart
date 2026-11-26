import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/features/notifications/notifications_screen.dart';

void main() {
  test('notification grouping follows Baghdad day across UTC midnight', () {
    final now = DateTime.parse('2026-10-28T22:00:00Z');
    expect(
        notificationDayLabel({'createdAt': '2026-10-28T21:01:00Z'}, now: now),
        'اليوم');
    expect(
        notificationDayLabel({'createdAt': '2026-10-28T20:59:00Z'}, now: now),
        'أمس');
    expect(notificationDayLabel({'createdAt': 'invalid'}, now: now),
        'إشعارات سابقة');
  });
  testWidgets(
      'long Arabic notification remains readable and tappable on a narrow large-text screen',
      (t) async {
    t.view.physicalSize = const Size(320, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    var tapped = false;
    await t.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 700), textScaler: TextScaler.linear(2)),
            child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                    body: ListView(children: [
                  WalletNotificationCard(item: {
                    'type': 'wallet_cash_payout',
                    'title': 'تم اعتماد طلب صرف رصيد المحفظة',
                    'body':
                        'راجع حالة طلب الصرف وتفاصيل التسليم النقدي من المحفظة. لا تؤكد الاستلام حتى تستلم المبلغ وتعدّه.',
                    'createdAt': '2026-10-28T12:05:00Z'
                  }, onTap: () => tapped = true)
                ]))))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.text('تم اعتماد طلب صرف رصيد المحفظة'));
    expect(tapped, isTrue);
    expect(find.textContaining('2026-10-28T'), findsNothing);
  });
}
