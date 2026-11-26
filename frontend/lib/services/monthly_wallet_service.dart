import '../models/monthly_wallet_statement.dart';
import '../models/wallet_transaction.dart';
import 'wallet_funding_service.dart';

class MonthlyWalletService {
  MonthlyWalletService({WalletFundingService? transport})
      : _transport = transport ?? WalletFundingService();
  final WalletFundingService _transport;
  Future<MonthlyWalletStatement> load(String month,
      {void Function(int)? onProgress}) async {
    final account = await _transport.account();
    final rows = <String, WalletTransaction>{};
    final cursors = <String>{};
    String? cursor, asOf;
    for (var page = 0; page < 500; page++) {
      final query = {'month': month, if (cursor != null) 'nextToken': cursor};
      final data = await _transport
          .call('/wallet/me/transactions?${Uri(queryParameters: query).query}');
      if (data['month'] != month ||
          data['timeZone'] != 'Asia/Baghdad' ||
          data['asOf'] is! String ||
          (asOf != null && asOf != data['asOf']))
        throw const FormatException('تعذر مطابقة صفحات الكشف. أعد المحاولة.');
      asOf = data['asOf'] as String;
      final date = DateTime.tryParse(asOf);
      if (date == null) throw const FormatException('توقيت الكشف غير صالح');
      for (final raw in data['transactions'] as List) {
        final value = Map<String, dynamic>.from(raw as Map);
        if (value['walletId'] != 'WALLET#DRIVER#$account' ||
            value['sk'] is! String ||
            value['amount'] is! num ||
            DateTime.tryParse('${value['createdAt'] ?? value['timestamp']}') ==
                null) throw const FormatException('تعذر التحقق من حركات الكشف');
        final t = WalletTransaction.fromJson(value);
        if (MonthlyWalletStatement.monthOf(t.createdAt) != month)
          throw const FormatException('حركة خارج الشهر المحدد');
        if (rows.containsKey(t.entryId))
          throw const FormatException(
              'تكررت حركة بين صفحات الكشف. أعد المحاولة.');
        rows[t.entryId] = t;
      }
      onProgress?.call(rows.length);
      cursor = data['nextToken'] as String?;
      if (cursor == null || cursor.isEmpty) {
        await _transport.account();
        return MonthlyWalletStatement(
            month: month,
            asOf: date,
            transactions: List.unmodifiable(rows.values));
      }
      if (!cursors.add(cursor))
        throw const FormatException('تعذر متابعة صفحات الكشف');
    }
    throw const FormatException(
        'عدد الحركات كبير. يرجى التواصل مع الدعم للحصول على كشف كامل.');
  }
}
