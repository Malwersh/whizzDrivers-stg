import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wizz_driver/models/monthly_wallet_statement.dart';
import 'package:wizz_driver/models/wallet_transaction.dart';
import 'package:wizz_driver/models/wallet_balance.dart';
import 'package:wizz_driver/features/wallet/screens/monthly_statement_screen.dart';
import 'package:wizz_driver/services/monthly_wallet_service.dart';
import 'package:wizz_driver/services/wallet_funding_service.dart';
import 'package:wizz_driver/features/wallet/widgets/minimum_balance_indicator.dart';

String jwt(String sub) =>
    'x.${base64Url.encode(utf8.encode(jsonEncode({'sub': sub})))}.x';
Map<String, dynamic> row(String id, String category, int amount,
        {String? bucket}) =>
    {
      'sk': 'ts#2026-10-20T12:00:00.000Z#$id',
      'walletId': 'WALLET#DRIVER#d',
      'category': category,
      'type': amount < 0 ? 'DEBIT' : 'CREDIT',
      'amount': amount,
      'createdAt': '2026-10-20T12:00:00.000Z',
      'metadata': {'balanceType': bucket, 'financialSchemaVersion': 4}
    };
Map<String, dynamic> page(List<Map<String, dynamic>> rows, {String? next}) => {
      'month': '2026-10',
      'timeZone': 'Asia/Baghdad',
      'asOf': '2026-10-25T00:00:00Z',
      'transactions': rows,
      'nextToken': next
    };

class FakeMonthlyService extends MonthlyWalletService {
  @override
  Future<MonthlyWalletStatement> load(String month,
          {void Function(int)? onProgress}) async =>
      MonthlyWalletStatement(
          month: month,
          asOf: DateTime.utc(2026, 10, 25),
          transactions: [WalletTransaction.fromJson(row('a', 'TOPUP', 25000))]);
}

void main() {
  testWidgets(
      'monthly screen offers month choice, complete totals and PDF menu without overflow on small RTL screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (c, w) =>
            Directionality(textDirection: TextDirection.rtl, child: w!),
        home: MonthlyStatementScreen(service: FakeMonthlyService())));
    await tester.pumpAndSettle();
    expect(find.text('الكشف الشهري'), findsOneWidget);
    expect(find.text('الإضافات الفعلية'), findsOneWidget);
    expect(find.text('حفظ الكشف CSV'), findsNothing);
    await tester.tap(find.byTooltip('خيارات الكشف'));
    await tester.pumpAndSettle();
    expect(find.text('تحميل الكشف'), findsOneWidget);
    expect(find.text('ملف PDF'), findsOneWidget);
    Navigator.of(tester.element(find.text('تحميل الكشف'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(find.text('عرض الكشف'));
    expect(label.style!.color, Colors.white);
    expect(find.text('اختر شهر الكشف'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
      'monthly totals exclude both hold/release sides, include full cash capture and real compensation',
      () {
    final rows = [
      row('t', 'TOPUP', 25000),
      row('ha', 'HOLD_CREATED', -12000, bucket: 'AVAILABLE'),
      row('hl', 'HOLD_CREATED', 12000, bucket: 'LOCKED'),
      row('ra', 'FULL_CASH_RELEASED', 12000, bucket: 'AVAILABLE'),
      row('rl', 'FULL_CASH_RELEASED', -12000, bucket: 'LOCKED'),
      row('c', 'FULL_CASH_COMPLETED', -6250, bucket: 'LOCKED'),
      row('a', 'CASH_ADJUDICATION_SETTLED', 750, bucket: 'AVAILABLE')
    ];
    final s = MonthlyWalletStatement(
        month: '2026-10',
        asOf: DateTime.utc(2026, 10, 25),
        transactions: rows.map(WalletTransaction.fromJson).toList());
    expect(s.credits, 25750);
    expect(s.debits, 6250);
    expect(s.net, 19500);
    expect(s.holds, 12000);
    expect(s.releases, 12000);
    expect(s.visible.length, 5);
    expect(s.visible.any((t) => t.displayTitle.contains('رسوم توصيل')), false);
    expect(s.csv().take(3), [239, 187, 191]);
    expect(
        MonthlyWalletStatement.csvCell('=HYPERLINK("bad")').startsWith('"\''),
        true);
    expect(MonthlyWalletStatement.csvCell(-5), '-5');
    expect(utf8.decode(s.csv()), contains('+03:00'));
  });
  test('month uses Baghdad boundaries rather than device time', () {
    expect(
        MonthlyWalletStatement.monthOf(DateTime.parse('2026-09-30T21:00:00Z')),
        '2026-10');
    expect(
        MonthlyWalletStatement.monthOf(DateTime.parse('2026-09-30T20:59:59Z')),
        '2026-09');
  });
  test('loads all pages and rejects foreign wallet or duplicate ledger rows',
      () async {
    var calls = 0;
    final service = MonthlyWalletService(
        transport: WalletFundingService(
            token: () async => jwt('d'),
            client: MockClient((r) async {
              expect(r.url.queryParameters['month'], '2026-10');
              calls++;
              return http.Response(
                  jsonEncode(calls == 1
                      ? page([row('a', 'TOPUP', 25000)], next: 'second')
                      : page([row('b', 'TRANSFER', 1000)])),
                  200);
            })));
    final s = await service.load('2026-10');
    expect(calls, 2);
    expect(s.credits, 26000);
    for (final bad in [
      row('x', 'TOPUP', 1)..['walletId'] = 'WALLET#DRIVER#other',
      row('same', 'TOPUP', 1)
    ]) {
      calls = 0;
      final svc = MonthlyWalletService(
          transport: WalletFundingService(
              token: () async => jwt('d'),
              client: MockClient((r) async {
                calls++;
                return http.Response(
                    jsonEncode(page([bad], next: calls == 1 ? 'again' : null)),
                    200);
              })));
      await expectLater(svc.load('2026-10'), throwsFormatException);
    }
  });
  test('account switch while loading fails closed', () async {
    var current = 'd';
    final svc = MonthlyWalletService(
        transport: WalletFundingService(
            token: () async => jwt(current),
            client: MockClient((r) async {
              current = 'other';
              return http.Response(jsonEncode(page([])), 200);
            })));
    await expectLater(
        svc.load('2026-10'), throwsA(isA<FundingSessionChanged>()));
  });
  testWidgets(
      'collateral split tracks real balances and explanation expands and collapses',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MinimumBalanceIndicator(
                balance: WalletBalance(
                    walletId: 'w',
                    availableBalance: 1000,
                    lockedBalance: 12500,
                    minRequiredBalance: 25000,
                    status: 'ACTIVE',
                    currency: 'IQD')))));
    expect(find.text('ضمان الطلبات'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('25,000'), findsNothing);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        closeTo(1000 / 13500, 0.00001));
    expect(find.textContaining('عند القبول').hitTestable(), findsNothing);
    await tester.tap(find.text('كيف يعمل الضمان؟'));
    await tester.pumpAndSettle();
    expect(find.textContaining('عند القبول').hitTestable(), findsOneWidget);
    await tester.tap(find.text('كيف يعمل الضمان؟'));
    await tester.pumpAndSettle();
    expect(find.textContaining('عند القبول').hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
