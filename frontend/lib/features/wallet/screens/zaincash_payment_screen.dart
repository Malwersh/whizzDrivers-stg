import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/wallet_funding_service.dart';
import '../../../services/zaincash_funding_service.dart';

class ZaincashPaymentScreen extends StatefulWidget {
  const ZaincashPaymentScreen({super.key, this.service});
  final ZaincashFundingService? service;
  @override
  State<ZaincashPaymentScreen> createState() => _ZaincashPaymentScreenState();
}

class _ZaincashPaymentScreenState extends State<ZaincashPaymentScreen>
    with WidgetsBindingObserver {
  late final _service = widget.service ?? ZaincashFundingService();
  final _amount = TextEditingController(text: '25000');
  Map<String, dynamic>? _config;
  final List<Map<String, dynamic>> _payments = [];
  String? _cursor, _error;
  bool _busy = false, _accountChanged = false;
  static const _navy = Color(0xFF082C63);
  static const _states = {
    'CREATING': 'جارٍ إنشاء عملية الدفع',
    'CREATION_UNCERTAIN': 'نتيجة إنشاء الدفع غير مؤكدة — تحتاج متابعة',
    'PENDING': 'بانتظار إكمال الدفع أو تأكيده',
    'SUCCESS': 'تم تأكيد الدفع',
    'FAILED': 'فشل الدفع',
    'EXPIRED': 'انتهت صلاحية الدفع',
    'CANCELED': 'أُلغي الدفع',
    'NOT_CREATED': 'أكدت المراجعة عدم إنشاء أو تحصيل الدفع',
    'REVIEW_REQUIRED': 'تحتاج مراجعة مالية',
    'REFUND_REVIEW_REQUIRED': 'استرجاع من البوابة قيد المراجعة المالية',
  };
  bool _terminal(Map<String, dynamic> p) => [
        'SUCCESS',
        'FAILED',
        'EXPIRED',
        'CANCELED',
        'NOT_CREATED',
        'NOT_CREATED'
      ].contains(p['state']);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _failure(Object e) {
    _error = e.toString();
    if (e is FundingSessionChanged) {
      _accountChanged = true;
      _config = null;
      _payments.clear();
      _amount.clear();
    }
  }

  Future<void> _refresh({bool more = false}) async {
    if (_busy || _accountChanged) return;
    setState(() => _busy = true);
    try {
      await _service.initialize();
      final c = await _service.config();
      var h = await _service.history(cursor: more ? _cursor : null);
      if (!more) {
        final active = List<Map<String, dynamic>>.from(h['payments'] ?? [])
            .where((p) => [
                  'PENDING',
                  'CREATING',
                  'CREATION_UNCERTAIN',
                  'REVIEW_REQUIRED'
                ].contains(p['state']))
            .take(3);
        for (final p in active) {
          await _service.check(p['requestId']);
        }
        if (active.isNotEmpty) h = await _service.history();
      }
      final rows = List<Map<String, dynamic>>.from(h['payments'] ?? []);
      if (_service.pending != null) {
        final match =
            rows.where((p) => p['requestId'] == _service.pending!['requestId']);
        if (match.isNotEmpty) await _service.confirmSavedOutcome(match.first);
      }
      if (!mounted) return;
      setState(() {
        _config = c;
        _cursor = h['cursor'];
        if (!more) _payments.clear();
        _payments.addAll(rows);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _failure(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    if (_busy || _accountChanged) return;
    final normalized = _amount.text.replaceAllMapped(
        RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x660}');
    final amount = int.tryParse(normalized);
    if (_service.pending == null &&
        (amount == null ||
            amount < (_config?['minimum'] ?? 25000) ||
            amount > (_config?['maximum'] ?? 500000))) {
      setState(() => _error = 'أدخل مبلغًا ضمن حدود الشحن المعروضة');
      return;
    }
    setState(() => _busy = true);
    try {
      final p = await _service.pay(amount ?? 25000,
          expectedMode: _config?['mode'] ?? 'UAT');
      if (!mounted) return;
      final raw = p['checkoutUrl'];
      if (raw is String && p['state'] == 'PENDING') {
        final url = Uri.parse(raw);
        if (url.scheme != 'https' ||
            !(url.host == 'zaincash.iq' || url.host.endsWith('.zaincash.iq')) ||
            url.userInfo.isNotEmpty ||
            url.hasPort) throw Exception('رابط الدفع غير صالح');
        if (!await launchUrl(url, mode: LaunchMode.externalApplication))
          throw Exception(
              'تعذر فتح صفحة الدفع. العملية محفوظة؛ يمكنك متابعتها.');
      }
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _failure(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refresh();
      }
    }
  }

  Future<void> _open(Map<String, dynamic> p) async {
    try {
      await _service.transport.account();
      final url = Uri.parse(p['checkoutUrl'] as String);
      if (url.scheme != 'https' ||
          !(url.host == 'zaincash.iq' || url.host.endsWith('.zaincash.iq')) ||
          url.userInfo.isNotEmpty ||
          url.hasPort) throw Exception('رابط الدفع غير صالح');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication))
        throw Exception('تعذر فتح صفحة الدفع');
    } catch (e) {
      if (mounted) setState(() => _failure(e));
    }
  }

  Future<void> _check(Map<String, dynamic> p) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.check(p['requestId']);
    } catch (e) {
      if (mounted) setState(() => _failure(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refresh();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amount.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        _service.pending != null || _payments.any((p) => !_terminal(p));
    final test = _config?['mode'] == 'UAT';
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            appBar: AppBar(title: const Text('شحن مباشر بزين كاش')),
            body: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_config?['pilot'] == true)
                    const Text(
                        'تجربة تشغيل فعلية لحسابك — يُخصم مبلغ حقيقي ويُضاف بعد تأكيد الدفع.',
                        style: TextStyle(
                            color: _navy, fontWeight: FontWeight.bold)),
                  if (test)
                    const Card(
                        child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                                'بيئة اختبار — لا يضاف أي مبلغ إلى رصيد المحفظة الفعلي.',
                                style: TextStyle(
                                    color: _navy,
                                    fontWeight: FontWeight.bold)))),
                  if (_config?['enabled'] != true && !_accountChanged)
                    const Text(
                        'استقبال دفعات جديدة غير مفعّل. يمكنك متابعة عملياتك السابقة.'),
                  if (pending && !_accountChanged) ...[
                    const Text(
                        'توجد محاولة دفع تحتاج متابعة. لا تدفع مبلغًا جديدًا قبل تأكيد نتيجتها.',
                        style: TextStyle(
                            color: _navy, fontWeight: FontWeight.bold)),
                    if (_service.pending != null)
                      OutlinedButton(
                          onPressed: _busy ? null : _pay,
                          child: const Text('استعادة محاولة الدفع نفسها')),
                  ],
                  if (!pending &&
                      _config?['enabled'] == true &&
                      !_accountChanged) ...[
                    Text(
                        'حدود الشحن: ${_config!['minimum']} إلى ${_config!['maximum']} د.ع'),
                    TextField(
                        controller: _amount,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'مبلغ الشحن بالدينار العراقي'),
                        enabled: !_busy),
                    FilledButton(
                        onPressed: _busy ? null : _pay,
                        child: Text(test
                            ? 'متابعة الدفع التجريبي'
                            : 'الدفع الآمن عبر زين كاش')),
                    const Text(
                        'لا تُدخل رمز التحقق أو بيانات زين كاش في تطبيقنا. أكمل الدفع في صفحة زين كاش الرسمية. يُضاف الرصيد بعد تأكيد البوابة.'),
                  ],
                  const SizedBox(height: 24),
                  Row(children: [
                    const Expanded(
                        child: Text('سجل الدفع المباشر',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _navy))),
                    IconButton(
                        onPressed: _busy ? null : _refresh,
                        icon: const Icon(Icons.refresh))
                  ]),
                  ..._payments.map((p) => Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                    '${p['amount']} د.ع${p['mode'] == 'UAT' ? ' — تجريبي' : ''}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _navy)),
                                Text(_states[p['state']] ??
                                    'حالة غير معروفة — راجع الدعم'),
                                if (p['state'] == 'SUCCESS')
                                  Text(p['mode'] == 'UAT'
                                      ? 'نجح الاختبار؛ الرصيد الفعلي لم يتغير.'
                                      : 'أضيف الرصيد إلى المحفظة.'),
                                if (p['reason'] != null) Text('${p['reason']}'),
                                SelectableText(
                                    'مرجع العملية: ${p['requestId']}'),
                                Text('${p['createdAt']}'),
                                if (p['state'] == 'PENDING' &&
                                    p['checkoutUrl'] is String)
                                  OutlinedButton(
                                      onPressed: _busy ? null : () => _open(p),
                                      child: const Text(
                                          'متابعة الدفع نفسه في زين كاش')),
                                if (!_terminal(p))
                                  OutlinedButton(
                                      onPressed: _busy ? null : () => _check(p),
                                      child:
                                          const Text('التحقق من نتيجة الدفع')),
                              ])))),
                  if (_cursor != null)
                    OutlinedButton(
                        onPressed: _busy ? null : () => _refresh(more: true),
                        child: const Text('تحميل عمليات أقدم')),
                ]))));
  }
}
