import '../widgets/active_trip_summary.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class CustomerCashReviewScreen extends StatefulWidget {
  final bool driver;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) call;
  const CustomerCashReviewScreen({
    super.key,
    required this.call,
    this.driver = false,
  });
  @override
  State<CustomerCashReviewScreen> createState() =>
      _CustomerCashReviewScreenState();
}

class _CustomerCashReviewScreenState extends State<CustomerCashReviewScreen> {
  Map<String, dynamic>? data;
  bool busy = false, confirmedPayment = false;
  String? message;
  final paid = TextEditingController(), reason = TextEditingController();
  final keys = <String, String>{};
  static const statuses = {
    'APPROVED': 'معتمد — لم يُنفذ الرد',
    'EXECUTED': 'سُجل التسليم — بانتظار إقرار الزبون',
    'ACKNOWLEDGED': 'أكد الزبون الاستلام — بانتظار المطابقة',
    'RECONCILED': 'اكتمل الرد والمطابقة',
    'CANCELLED': 'أُلغي قبل التنفيذ',
  };
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    paid.dispose();
    reason.dispose();
    super.dispose();
  }

  String money(dynamic n) => '$n د.ع';
  String friendly(Object e) {
    final s = e.toString();
    if (s.contains('UNAUTHORIZED')) return 'أعد تسجيل الدخول لعرض حسابك.';
    if (s.contains('SOURCE_PROOF_CHANGED')) {
      return 'تغيرت حالة تسوية المبلغ؛ يلزم مراجعة مصدر الرد قبل التنفيذ.';
    }
    if (s.contains('CONFLICT') || s.contains('STATE')) {
      return 'تغيرت الحالة. حدّث الشاشة وراجعها قبل إعادة المحاولة.';
    }
    if (s.contains('FORBIDDEN')) return 'لا يملك هذا الحساب صلاحية الإجراء.';
    return 'تعذر تأكيد العملية. حدّث الحالة قبل إعادة المحاولة، ولا تكرر تسليم المال.';
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final d = await widget.call({'action': 'READ_CUSTOMER_CASH_CASE'});
      if (mounted) setState(() => data = d);
    } catch (e) {
      if (mounted) setState(() => message = friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> act(
    String action,
    Map<String, dynamic> extra,
    String note,
  ) async {
    if (busy || data == null) return;
    final body = <String, dynamic>{
      'action': action,
      'expectedVersion': data!['version'],
      'reason': note,
      ...extra,
    };
    body['idempotencyKey'] = keys.putIfAbsent(
      jsonEncode(body),
      () => const Uuid().v4(),
    );
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final d = await widget.call(body);
      if (mounted) {
        setState(() {
          data = d;
          message = action == 'REPORT_CASH_PAYMENT'
              ? 'تم إرسال إفادة الدفع بنجاح. بانتظار مراجعة الإدارة.'
              : 'حُفظ الإجراء. راجع الحالة أدناه.';
          confirmedPayment = false;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(message!),
            duration: const Duration(seconds: 6),
          ));
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) setState(() => message = friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refundDialog(Map<String, dynamic> r) async {
    bool confirmed = false;
    var reference = '';
    final execute = widget.driver;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(
            execute ? 'إثبات تسليم مبلغ الرد' : 'تأكيد استلام مبلغ الرد',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('المبلغ: ${money(r['amountIqd'])}'),
                Text('سند الرد: ${r['voucherNumber']}'),
                if (execute)
                  TextField(
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'مرجع التسليم أو تفاصيله',
                    ),
                    onChanged: (v) => update(() => reference = v),
                  ),
                CheckboxListTile(
                  value: confirmed,
                  onChanged: (v) => update(() => confirmed = v == true),
                  title: Text(
                    execute
                        ? 'سلّمت المبلغ كاملًا فعليًا للزبون.'
                        : 'استلمت المبلغ كاملًا فعليًا.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('رجوع'),
            ),
            FilledButton(
              onPressed: confirmed && (!execute || reference.trim().length >= 5)
                  ? () => Navigator.pop(
                        ctx,
                        execute
                            ? reference.trim()
                            : 'استلام كامل مبلغ الرد من مصدره المسجل',
                      )
                  : null,
              child: const Text('حفظ الإقرار'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    await act(
      execute ? 'EXECUTE_CUSTOMER_REFUND' : 'ACKNOWLEDGE_CUSTOMER_REFUND',
      {
        'refundId': r['refundId'],
        if (execute)
          'confirmPhysicalExecution': true
        else
          'confirmFullReceipt': true,
        if (execute) 'reference': result,
      },
      result,
    );
  }

  @override
  Widget build(BuildContext context) {
    final refunds = (data?['refunds'] as List? ?? [])
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    final reports = (data?['reports'] as List? ?? [])
        .whereType<Map>()
        .where((r) => r['actorKind'] == (widget.driver ? 'DRIVER' : 'CUSTOMER'))
        .toList();
    final latestReport = reports.isEmpty ? null : reports.last;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: TripStyle.background,
          colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: TripStyle.blue,
              secondary: TripStyle.yellow,
              onPrimary: Colors.white),
          appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: TripStyle.ink,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                  color: TripStyle.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              alignLabelWithHint: true,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFDDE5EF))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFDDE5EF)))),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  backgroundColor: TripStyle.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)))),
        ),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('مراجعة النقد ورد المبلغ'),
            actions: [
              IconButton(
                onPressed: busy ? null : load,
                tooltip: 'تحديث الحالة',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'أدخل المبلغ الذي استلمته فعليًا من الزبون، وأضف تفاصيل الفرق لمراجعته.',
              ),
              if (busy) const LinearProgressIndicator(),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(message!),
                ),
              if (data != null) ...[
                if (latestReport != null)
                  Card(
                    key: const ValueKey('latest-payment-report'),
                    child: ListTile(
                      leading: const Icon(Icons.task_alt),
                      title: Text(
                          'آخر إفادة مرسلة: ${money(latestReport['reportedPaidIqd'])}'),
                      subtitle: Text(data!['status'] == 'CLOSED'
                          ? 'أُغلقت مراجعة التحصيل.'
                          : 'إفادتك محفوظة. المطابقة واعتماد المعالجة لدى الإدارة.'),
                    ),
                  ),
                _panel(Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('المبلغ المطلوب للطلب',
                          style: TextStyle(color: TripStyle.muted)),
                      const SizedBox(height: 8),
                      Text(money(data!['expectedIqd']),
                          style: const TextStyle(
                              color: TripStyle.ink,
                              fontSize: 28,
                              fontWeight: FontWeight.bold))
                    ])),
                if (data!['collectionVerification'] is Map)
                  Text(
                    'المبلغ المطابق: ${money(data!['collectionVerification']['collectedIqd'])}',
                  ),
                const SizedBox(height: 16),
                _panel(Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('المبلغ المستلم فعليًا',
                          style: TextStyle(
                              color: TripStyle.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: paid,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'إجمالي ما دفعه الزبون فعليًا بالدينار',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: reason,
                        enabled: !busy,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'تفاصيل الدفع أو الفرق',
                        ),
                      ),
                      CheckboxListTile(
                        value: confirmedPayment,
                        onChanged: busy
                            ? null
                            : (v) =>
                                setState(() => confirmedPayment = v == true),
                        title: Text(
                          widget.driver
                              ? 'أؤكد أنني استلمت المبلغ المدون فعليًا من الزبون.'
                              : 'أؤكد أنني دفعت المبلغ المدون فعليًا.',
                        ),
                      ),
                      FilledButton(
                        onPressed: busy || !confirmedPayment
                            ? null
                            : () {
                                final n = int.tryParse(paid.text.trim());
                                if (n == null ||
                                    n < 0 ||
                                    reason.text.trim().length < 5) {
                                  setState(
                                    () => message =
                                        'أدخل مبلغًا صحيحًا وتفاصيل لا تقل عن خمسة أحرف.',
                                  );
                                  return;
                                }
                                act(
                                    'REPORT_CASH_PAYMENT',
                                    {
                                      'reportedPaidIqd': n,
                                      'confirmActualPayment': true,
                                    },
                                    reason.text.trim());
                              },
                        child: const Text('إرسال إفادة الدفع للمراجعة'),
                      ),
                    ])),
                const SizedBox(height: 24),
                const Text(
                  'طلبات رد المبلغ',
                  style: TextStyle(
                      color: TripStyle.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                if (refunds.isEmpty)
                  _panel(const Row(children: [
                    Icon(Icons.receipt_long_outlined, color: TripStyle.blue),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text('لا يوجد رد مبلغ معتمد لهذا الطلب.',
                            style: TextStyle(color: TripStyle.muted)))
                  ])),
                for (final r in refunds)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            money(r['amountIqd']),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(statuses[r['status']] ?? 'تحتاج مراجعة'),
                          SelectableText('السند: ${r['voucherNumber']}'),
                          if (widget.driver &&
                                  r['status'] == 'APPROVED' &&
                                  r['source']?['kind'] == 'DRIVER_UNSETTLED' ||
                              !widget.driver && r['status'] == 'EXECUTED')
                            OutlinedButton(
                              onPressed: busy ? null : () => refundDialog(r),
                              child: Text(
                                widget.driver
                                    ? 'إثبات تسليم الرد للزبون'
                                    : 'تأكيد استلام الرد كاملًا',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel(Widget child) => Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE3E9F1)),
          borderRadius: BorderRadius.circular(20)),
      child: child);
}
