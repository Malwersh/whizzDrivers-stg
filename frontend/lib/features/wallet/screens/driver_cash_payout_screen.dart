import 'package:flutter/material.dart';
import '../../../services/driver_cash_payout_service.dart';
import '../../../design_system/app_colors.dart';

class DriverCashPayoutScreen extends StatefulWidget {
  const DriverCashPayoutScreen({super.key, this.service});
  final DriverCashPayoutService? service;
  @override
  State<DriverCashPayoutScreen> createState() => _DriverCashPayoutScreenState();
}

class _DriverCashPayoutScreenState extends State<DriverCashPayoutScreen> {
  late final DriverCashPayoutService api;
  final amount = TextEditingController();
  Map<String, dynamic>? data;
  List<Map<String, dynamic>> rows = [];
  bool busy = false;
  String? error, cursor;
  @override
  void initState() {
    super.initState();
    api = widget.service ?? DriverCashPayoutService();
    _load();
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await api.retryPending();
      final out = await api.call(
          {'action': 'READ', if (more && cursor != null) 'cursor': cursor});
      if (!mounted) return;
      setState(() {
        data = out;
        cursor = out['nextCursor'] as String?;
        final next = (out['items'] as List? ?? [])
            .map((v) => Map<String, dynamic>.from(v))
            .toList();
        rows = {
          for (final r in (more ? [...rows, ...next] : next)) r['payoutId']: r
        }.values.toList();
        rows.sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
        error = null;
      });
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String money(num n) => '${n.toStringAsFixed(0)} د.ع';
  int? parseAmount(String text) {
    const a = '٠١٢٣٤٥٦٧٨٩', p = '۰۱۲۳۴۵۶۷۸۹';
    final s = text
        .trim()
        .split('')
        .map((c) => a.contains(c)
            ? '${a.indexOf(c)}'
            : p.contains(c)
                ? '${p.indexOf(c)}'
                : c)
        .join();
    return RegExp(r'^\d+$').hasMatch(s) ? int.tryParse(s) : null;
  }

  Future<void> _act(Map<String, dynamic> v, String prompt) async {
    final yes = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        builder: (c) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(prompt,
                      style: const TextStyle(
                          fontSize: 16, color: AppColors.secondary)),
                  const SizedBox(height: 20),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('تأكيد')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('تراجع',
                          style: TextStyle(color: AppColors.secondary)))
                ])));
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      await api.call(v, mutation: true);
      amount.clear();
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final eligibility = data?['eligibility'] as Map?,
        eligible = eligibility?['eligibleIqd'] as num?,
        perRequest = data?['limits']?['maximumPerRequestIqd'] as num?;
    final blockedReason = DriverCashPayoutService.blockedReason(eligibility);
    return Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(title: const Text('صرف رصيد المحفظة'), actions: [
          IconButton(
              onPressed: busy ? null : () => _load(),
              icon: const Icon(Icons.refresh, color: AppColors.secondary))
        ]),
        body: RefreshIndicator(
            onRefresh: () => _load(),
            child: ListView(
                key: const ValueKey('driver-payout-list'),
                padding: const EdgeInsets.all(16),
                children: [
                  if (busy)
                    const LinearProgressIndicator(color: AppColors.secondary),
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(error!,
                            style:
                                const TextStyle(color: AppColors.secondary))),
                  if (data?['enabled'] == false)
                    const Text('صرف الرصيد غير متاح حاليًا.'),
                  if (data?['enabled'] == true)
                    _card(Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('الرصيد المؤهل للطلب',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(
                              eligible == null
                                  ? 'يحتاج مراجعة'
                                  : money(eligible),
                              style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondary)),
                          const SizedBox(height: 8),
                          if (perRequest != null)
                            Text(
                                'الحد الأعلى لطلب الصرف: ${money(perRequest)}'),
                          const Text(
                              'يشمل التعويضات والشحن المثبت غير المستخدم. أجرة التوصيل التي احتفظت بها نقدًا لا تُصرف مرة أخرى.',
                              style: TextStyle(fontSize: 13, height: 1.6)),
                          if (blockedReason != null) ...[
                            const SizedBox(height: 12),
                            Container(
                                key: const ValueKey('payout-blocked-reason'),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF0F3F9),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(children: [
                                        Icon(Icons.info_outline,
                                            size: 20,
                                            color: AppColors.secondary),
                                        SizedBox(width: 8),
                                        Text('لماذا لا يمكن طلب الصرف؟',
                                            style: TextStyle(
                                                color: AppColors.secondary,
                                                fontWeight: FontWeight.w600))
                                      ]),
                                      const SizedBox(height: 8),
                                      Text(blockedReason,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.6,
                                              color: AppColors.secondary))
                                    ]))
                          ],
                          const SizedBox(height: 12),
                          TextField(
                              controller: amount,
                              keyboardType: TextInputType.number,
                              enabled: !busy &&
                                  blockedReason == null &&
                                  eligible != null &&
                                  eligible > 0,
                              decoration: const InputDecoration(
                                  labelText: 'المبلغ بالدينار',
                                  floatingLabelStyle: const TextStyle(
                                      color: AppColors.secondary),
                                  labelStyle:
                                      const TextStyle(color: Color(0xFF53627B)),
                                  focusedBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color: AppColors.secondary)),
                                  border: OutlineInputBorder())),
                          const SizedBox(height: 12),
                          FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(44)),
                              onPressed: busy ||
                                      eligible == null ||
                                      eligible <= 0 ||
                                      eligibility?['activePayoutId'] != null
                                  ? null
                                  : () {
                                      final n = parseAmount(amount.text);
                                      if (n == null ||
                                          n <= 0 ||
                                          n > eligible ||
                                          (perRequest != null &&
                                              n > perRequest)) {
                                        setState(() => error = perRequest !=
                                                    null &&
                                                n != null &&
                                                n > perRequest
                                            ? 'الحد الأعلى لطلب الصرف ${money(perRequest)}.'
                                            : 'أدخل مبلغًا صحيحًا لا يتجاوز الرصيد المؤهل.');
                                        return;
                                      }
                                      _act({
                                        'action': 'REQUEST',
                                        'amountIqd': n
                                      }, 'سيُحجز ${money(n)} من محفظتك لحين مراجعة الإدارة وتسليمك النقد من الصندوق.');
                                    },
                              child: Text(eligibility?['activePayoutId'] != null
                                  ? 'لديك طلب صرف قيد المتابعة'
                                  : 'طلب صرف نقدي'))
                        ])),
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('طلبات الصرف',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16))),
                  if (rows.isEmpty && data != null)
                    const Text('لا توجد طلبات صرف.'),
                  for (final r in rows)
                    _card(Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                              money((r['amount']?['minorAmount'] as num? ?? 0) /
                                  1000),
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondary)),
                          Text(DriverCashPayoutService.states[r['status']] ??
                              'قيد المراجعة'),
                          if (r['cashbox'] != null)
                            Text('الصندوق: ${r['cashbox']['name']}'),
                          if (r['cashVoucherNumber'] != null)
                            Text('سند الصرف: ${r['cashVoucherNumber']}',
                                style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          if (['UNDER_REVIEW', 'APPROVED']
                              .contains(r['status']))
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () => _act({
                                          'action': 'CANCEL',
                                          'payoutId': r['payoutId'],
                                          'version': r['version'],
                                          'reason': 'تراجع السائق عن طلب الصرف'
                                        },
                                            'إلغاء طلب الصرف وإعادة المبلغ إلى الرصيد المتاح؟'),
                                child: const Text('إلغاء الطلب',
                                    style:
                                        TextStyle(color: AppColors.secondary))),
                          if (r['status'] == 'AWAITING_RECEIPT')
                            FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.secondary,
                                    foregroundColor: Colors.white),
                                onPressed: busy
                                    ? null
                                    : () => _act({
                                          'action': 'ACK_RECEIPT',
                                          'payoutId': r['payoutId'],
                                          'version': r['version'],
                                          'receivedAmountIqd': (r['amount']
                                                  ['minorAmount'] as num) ~/
                                              1000,
                                          'confirmed': true
                                        }, 'هل استلمت ${money((r['amount']['minorAmount'] as num) / 1000)} نقدًا بالكامل؟ أكد بعد عدّ المبلغ فقط.'),
                                child: const Text('استلمت المبلغ بالكامل')),
                          if ([
                            'PROCESSING',
                            'AWAITING_RECEIPT',
                            'RECEIPT_CONFIRMED'
                          ].contains(r['status']))
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () => _act({
                                          'action': 'REPORT_PROBLEM',
                                          'payoutId': r['payoutId'],
                                          'version': r['version'],
                                          'reason':
                                              'السائق يطلب مراجعة تسليم مبلغ الصرف'
                                        },
                                            'إبلاغ الإدارة بمشكلة في استلام مبلغ الصرف؟'),
                                child: const Text('مشكلة في الاستلام',
                                    style:
                                        TextStyle(color: AppColors.secondary))),
                          if (r['status'] == 'RECONCILIATION_REQUIRED')
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () => _act({
                                          'action': 'ACK_NOT_RECEIVED',
                                          'payoutId': r['payoutId'],
                                          'version': r['version'],
                                          'confirmed': true
                                        }, 'هل تؤكد أنك لم تستلم مبلغ الصرف؟'),
                                child: const Text('أؤكد أنني لم أستلم المبلغ',
                                    style:
                                        TextStyle(color: AppColors.secondary))),
                        ])),
                  if (cursor != null)
                    TextButton(
                        onPressed: busy ? null : () => _load(more: true),
                        child: const Text('تحميل المزيد',
                            style: TextStyle(color: AppColors.secondary))),
                ])));
  }

  Widget _card(Widget child) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4EAF2))),
      child: child);
}
