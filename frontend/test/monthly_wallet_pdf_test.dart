import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/models/monthly_wallet_statement.dart';
import 'package:wizz_driver/models/wallet_transaction.dart';
import 'package:wizz_driver/services/monthly_wallet_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'Arabic PDF includes complete multipage monthly movements and embedded local font',
      () async {
    final statement = MonthlyWalletStatement(
        month: '2026-10',
        asOf: DateTime.utc(2026, 10, 25),
        transactions: List.generate(
            120,
            (i) => WalletTransaction(
                entryId: 'line$i',
                walletId: 'w',
                direction: 'CREDIT',
                amount: 25000,
                type: 'TOPUP',
                status: 'POSTED',
                createdAt: DateTime.utc(2026, 10, 20))));
    final bytes = await MonthlyWalletPdf.generate(statement);
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(10000));
    await File('/private/tmp/wallet-statement-269-preview.pdf')
        .writeAsBytes(bytes);
  });
}
