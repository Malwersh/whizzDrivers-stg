import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/services/driver_cash_payout_service.dart';
import 'package:wizz_driver/features/wallet/screens/driver_cash_payout_screen.dart';

class FakePayoutApi extends DriverCashPayoutService {
  FakePayoutApi(
      {this.eligibility = const {'status': 'VERIFIED', 'eligibleIqd': 5000},
      this.maximum});
  final Map<String, dynamic> eligibility;
  final int? maximum;
  final mutations = <Map<String, dynamic>>[];
  @override
  Future<void> retryPending() async {}
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> input,
      {bool mutation = false}) async {
    if (mutation) mutations.add(input);
    return {
      'success': true,
      'enabled': true,
      if (maximum != null) 'limits': {'maximumPerRequestIqd': maximum},
      'eligibility': eligibility,
      'items': [
        {
          'payoutId': 'p1',
          'version': 4,
          'status': 'AWAITING_RECEIPT',
          'amount': {'minorAmount': 5000000},
          'cashVoucherNumber': 'CPV-TEST',
          'cashbox': {'name': 'صندوق الاختبار'}
        }
      ]
    };
  }
}

void main() {
  testWidgets(
      'server request cap is visible and blocks amount below eligibility but above request cap',
      (t) async {
    final api = FakePayoutApi(maximum: 2500);
    await t.pumpWidget(MaterialApp(home: DriverCashPayoutScreen(service: api)));
    await t.pumpAndSettle();
    expect(find.textContaining('الحد الأعلى لطلب الصرف: 2500'), findsOneWidget);
    await t.enterText(find.byType(TextField), '3000');
    await t.ensureVisible(find.text('طلب صرف نقدي'));
    await t.tap(find.text('طلب صرف نقدي'));
    await t.pumpAndSettle();
    expect(api.mutations, isEmpty);
    await t.drag(find.byType(ListView), const Offset(0, 600));
    await t.pumpAndSettle();
    expect(find.text('الحد الأعلى لطلب الصرف 2500 د.ع.'), findsOneWidget);
  });

  testWidgets('unverified wallet explains the reason and keeps amount disabled',
      (t) async {
    final api = FakePayoutApi(eligibility: {
      'status': 'REVIEW_REQUIRED',
      'eligibleIqd': null,
      'code': 'DRIVER_PAYOUT_RECONCILIATION_REQUIRED'
    });
    await t.pumpWidget(MaterialApp(home: DriverCashPayoutScreen(service: api)));
    await t.pumpAndSettle();
    expect(find.text('لماذا لا يمكن طلب الصرف؟'), findsOneWidget);
    expect(find.textContaining('يوجد فرق بين سجل حركات المحفظة ورصيدها'),
        findsOneWidget);
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(api.mutations, isEmpty);
  });
  test('every blocked eligibility state has an actionable reason', () {
    for (final code in [
      'DRIVER_PAYOUT_SOURCE_UNAVAILABLE',
      'DRIVER_PAYOUT_HISTORY_UNVERIFIED',
      'DRIVER_PAYOUT_HISTORY_TOO_LARGE',
      'DRIVER_PAYOUT_SOURCE_INVALID',
      'DRIVER_PAYOUT_WALLET_UNAVAILABLE',
      'DRIVER_PAYOUT_WALLET_CHANGED',
      'UNKNOWN'
    ]) {
      expect(
          DriverCashPayoutService.blockedReason(
              {'status': 'REVIEW_REQUIRED', 'code': code}),
          isNotEmpty);
    }
    expect(
        DriverCashPayoutService.blockedReason(
            {'status': 'VERIFIED', 'eligibleIqd': 0}),
        contains('لا يوجد رصيد مؤهل'));
    expect(
        DriverCashPayoutService.blockedReason({
          'status': 'VERIFIED',
          'eligibleIqd': 5000,
          'activePayoutId': 'p1'
        }),
        contains('طلب صرف قيد المتابعة'));
    expect(
        DriverCashPayoutService.blockedReason(
            {'status': 'VERIFIED', 'eligibleIqd': 5000}),
        isNull);
  });

  testWidgets(
      'driver cash receipt needs a separate explicit confirmation on small RTL display',
      (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final api = FakePayoutApi();
    await t.pumpWidget(MaterialApp(
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: DriverCashPayoutScreen(service: api))));
    await t.pumpAndSettle();
    await t.drag(find.byKey(const ValueKey('driver-payout-list')),
        const Offset(0, -420));
    await t.pumpAndSettle();
    await t.tap(find.text('استلمت المبلغ بالكامل'));
    await t.pumpAndSettle();
    expect(api.mutations, isEmpty);
    expect(find.textContaining('أكد بعد عدّ المبلغ فقط'), findsOneWidget);
    await t.tap(find.text('تأكيد').last);
    await t.pumpAndSettle();
    expect(api.mutations.single['action'], 'ACK_RECEIPT');
    expect(api.mutations.single['receivedAmountIqd'], 5000);
    expect(api.mutations.single['confirmed'], true);
    expect(t.takeException(), isNull);
  });
}
