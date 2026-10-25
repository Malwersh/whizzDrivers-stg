import 'dart:convert';
import 'dart:typed_data';
import 'wallet_transaction.dart';

class MonthlyWalletStatement {
  MonthlyWalletStatement(
      {required this.month, required this.asOf, required this.transactions});
  final String month;
  final DateTime asOf;
  final List<WalletTransaction> transactions;
  List<WalletTransaction> get visible =>
      WalletTransaction.driverVisible(transactions);
  static bool isInternal(WalletTransaction t) =>
      t.isHoldCreated || t.isHoldReleased;
  int get credits => transactions
      .where((t) => !isInternal(t) && t.isCredit && !t.isReversed)
      .fold(0, (n, t) => n + t.amount);
  int get debits => transactions
      .where((t) => !isInternal(t) && t.isDebit && !t.isReversed)
      .fold(0, (n, t) => n + t.amount);
  int get net => credits - debits;
  int get holds => visible
      .where((t) => t.isHoldCreated && !t.isReversed)
      .fold(0, (n, t) => n + t.amount);
  int get releases => visible
      .where((t) => t.isHoldReleased && !t.isReversed)
      .fold(0, (n, t) => n + t.amount);
  static DateTime baghdad(DateTime date) =>
      date.toUtc().add(const Duration(hours: 3));
  static String monthOf(DateTime date) {
    final b = baghdad(date);
    return '${b.year}-${b.month.toString().padLeft(2, '0')}';
  }

  static String csvCell(Object value) {
    if (value is num) return value.toString();
    var s = value.toString();
    if (RegExp(r'^\s*[=+@\-]').hasMatch(s)) s = "'$s";
    return '"${s.replaceAll('"', '""')}"';
  }

  Uint8List csv() {
    final rows = <List<Object>>[
      ['كشف محفظة السائق', month],
      ['التوقيت', 'بغداد'],
      ['حتى', baghdad(asOf).toIso8601String().replaceFirst('Z', '+03:00')],
      ['الإضافات الفعلية', credits],
      ['الخصومات الفعلية', debits],
      ['صافي تغير المحفظة', net],
      [
        'ملاحظة',
        'الحجز وفك الحجز حركة داخلية. الكشف لا يشمل أجور التوصيل التي يحتفظ بها السائق نقدًا خارج المحفظة.'
      ],
      [
        'التاريخ بتوقيت بغداد',
        'الحركة',
        'النوع',
        'المبلغ د.ع',
        'أثرها على المحفظة د.ع',
        'الحالة'
      ],
      for (final t in visible)
        [
          baghdad(t.createdAt).toIso8601String().replaceFirst('Z', '+03:00'),
          t.displayTitle,
          isInternal(t)
              ? 'حركة حجز داخلية'
              : t.isCredit
                  ? 'إضافة'
                  : 'خصم',
          t.amount,
          isInternal(t) || t.isReversed
              ? 0
              : t.isCredit
                  ? t.amount
                  : -t.amount,
          t.isReversed ? 'ملغاة' : 'مسجلة'
        ],
    ];
    return Uint8List.fromList(utf8.encode(
        '\uFEFF${rows.map((r) => r.map(csvCell).join(',')).join('\r\n')}'));
  }
}
