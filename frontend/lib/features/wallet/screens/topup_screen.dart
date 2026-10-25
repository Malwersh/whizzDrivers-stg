import 'zaincash_payment_screen.dart';
import 'sandbox_payment_screen.dart';
import 'dart:async';
import '../../../services/push_notifications_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/wallet_funding_service.dart';

class TopupScreen extends StatefulWidget {
  const TopupScreen({super.key, this.service});
  final WalletFundingService? service;
  @override
  State<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends State<TopupScreen> with WidgetsBindingObserver {
  StreamSubscription<dynamic>? _pushEvents;
  bool _loading = false;
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  late final _funding = widget.service ?? WalletFundingService();
  bool _sessionChanged = false;
  Map<String, dynamic>? _config;
  Map<String, dynamic>? _sandbox;
  List<Map<String, dynamic>> _requests = [];
  String? _error, _receipt;
  bool _busy = false;
  Future<Map<String, dynamic>> _call(String path,
          {Map<String, dynamic>? body}) =>
      _funding.call(path, body: body);
  void _failure(Object e) {
    if (!mounted) return;
    setState(() {
      _error = e.toString();
      if (e is FundingSessionChanged) {
        _sessionChanged = true;
        _config = null;
        _sandbox = null;
        _requests = [];
        _receipt = null;
        _amount.clear();
        _reference.clear();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _pushEvents = PushNotificationsService.walletEvents.listen((_) {
      if (mounted && !_busy) _load(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_busy) {
      _load(silent: true);
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (_loading || _sessionChanged) return;
    _loading = true;
    if (!silent) setState(() => _busy = true);
    try {
      await _funding.initialize();
      final wasPending = _funding.hasPending;
      final config = await _call('/wallet/funding/config');
      final requests = await _funding.history();
      Map<String, dynamic>? sandbox;
      try {
        sandbox = await _call('/wallet/funding/sandbox/config');
      } on FundingSessionChanged {
        rethrow;
      } catch (_) {/* Optional test features stay hidden when unavailable. */}
      if (mounted) {
        setState(() {
          _config = config;
          _sandbox = sandbox;
          _requests = requests;
          if (wasPending && !_funding.hasPending) {
            _amount.clear();
            _reference.clear();
            _receipt = null;
          }
          _error = null;
        });
      }
    } catch (e) {
      _failure(e);
    } finally {
      _loading = false;
      if (mounted && !silent) setState(() => _busy = false);
    }
  }

  Future<void> _moreRequests() async {
    if (_busy || _sessionChanged) return;
    setState(() => _busy = true);
    try {
      final rows = await _funding.history(more: true);
      if (mounted)
        setState(() {
          _requests.addAll(rows);
        });
    } catch (e) {
      _failure(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    final image = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 1800);
    if (image == null || !mounted || _sessionChanged || _funding.hasPending)
      return;
    setState(() => _busy = true);
    try {
      final bytes = await image.readAsBytes();
      if (bytes.length > 4 * 1024 * 1024)
        throw Exception('اختر صورة لا تتجاوز ٤ ميجابايت');
      final png = bytes.length > 7 && bytes[0] == 137 && bytes[1] == 80;
      final jpg = bytes.length > 3 && bytes[0] == 255 && bytes[1] == 216;
      if (!png && !jpg) throw Exception('اختر صورة JPG أو PNG');
      final contentType = png ? 'image/png' : 'image/jpeg';
      final signed = await _call('/wallet/funding/receipt',
          body: {'contentType': contentType, 'size': bytes.length});
      await _funding.upload(signed['uploadUrl'], bytes, contentType);
      if (mounted) {
        setState(() {
          _receipt = signed['key'];
          _error = null;
        });
      }
    } catch (e) {
      _failure(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || _sessionChanged) return;
    if (_funding.hasPending) {
      await _sendPending();
      return;
    }
    final normalized = _amount.text.replaceAllMapped(
        RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x660}');
    final amount = int.tryParse(normalized);
    if (amount == null ||
        amount < 25000 ||
        _receipt == null ||
        _reference.text.trim().isEmpty ||
        _config == null ||
        _config?['manual']?['enabled'] != true) {
      setState(() =>
          _error = 'الحد الأدنى 25,000 د.ع. أدخل مرجع التحويل وارفع الوصل');
      return;
    }
    await _sendPending(payload: {
      'amount': amount,
      'method': 'MANUAL_VERIFICATION',
      'evidenceRef': _receipt,
      'transferReference': _reference.text.trim().replaceAllMapped(
          RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x660}'),
      'configVersion': _config!['version'],
    });
  }

  Future<void> _sendPending({Map<String, dynamic>? payload}) async {
    if (_busy || _sessionChanged) return;
    setState(() => _busy = true);
    try {
      await _funding.submit(payload: payload);
      if (!mounted) return;
      _amount.clear();
      _reference.clear();
      _receipt = null;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'تم تأكيد تسجيل الطلب. يضاف الرصيد بعد المراجعة والموافقة.')));
      await _load(silent: true);
    } catch (e) {
      _failure(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _pushEvents?.cancel();
    if (widget.service == null) _funding.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manual = (_config?['manual'] ?? {}) as Map;
    final enabled = manual['enabled'] == true;
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('شحن المحفظة')),
          body: RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                const Text('اختر طريقة الشحن',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const ListTile(
                    leading: Icon(Icons.phone_android),
                    title: Text('تحويل زين كاش ورفع الوصل'),
                    subtitle: Text('يُضاف الرصيد بعد مراجعة المدير')),
                if (!enabled && !_funding.hasPending && !_sessionChanged)
                  const Text(
                      'التحويل غير متاح حالياً. لم تُفعّل بيانات المستلم بعد.'),
                if (_funding.hasPending && !_sessionChanged) ...[
                  Card(
                      color: const Color(0xFFF1F5FA),
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                    'محاولة شحن محفوظة — نحتاج تأكيد نتيجتها',
                                    style: TextStyle(
                                        color: Color(0xFF082C63),
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    'المبلغ: ${_funding.pending!["amount"]} د.ع\nمرجع التحويل: ${_funding.pending!["transferReference"]}'),
                                const Text(
                                    'لا تحوّل مبلغًا جديدًا ولا ترفع وصلًا آخر لهذه المحاولة. حدّث القائمة أو أعد إرسال الطلب نفسه. إذا بقيت النتيجة غير مؤكدة فتواصل مع الدعم.'),
                                OutlinedButton(
                                    onPressed: _busy ? null : _load,
                                    child: const Text('تحديث طلبات الشحن')),
                                FilledButton(
                                    onPressed: _busy ? null : _sendPending,
                                    child:
                                        const Text('إعادة إرسال الطلب نفسه')),
                              ]))),
                ],
                if (enabled && !_funding.hasPending && !_sessionChanged) ...[
                  Text('المستلم: ${manual['name']}'),
                  ListTile(
                      title: Text('${manual['phone']}',
                          textDirection: TextDirection.ltr),
                      trailing: IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () => Clipboard.setData(
                              ClipboardData(text: '${manual['phone']}')))),
                  const Text(
                      'حوّل مبلغاً لا يقل عن 25,000 دينار إلى الرقم الموضح، ثم ارفع الوصل وأرسل الطلب. صورة الوصل لا تضيف الرصيد قبل المراجعة.'),
                  TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                        labelText: 'المبلغ بالدينار العراقي'),
                  ),
                  TextField(
                    controller: _reference,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                        labelText: 'رقم عملية التحويل في زين كاش'),
                  ),
                  OutlinedButton.icon(
                      onPressed: _busy ? null : _pick,
                      icon: const Icon(Icons.receipt),
                      label: Text(_receipt == null
                          ? 'رفع صورة الوصل'
                          : 'تم رفع الوصل — تغيير الصورة')),
                  FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: const Text('إرسال طلب الشحن')),
                ],
                if (_sandbox?['eligible'] == true &&
                    _sandbox?['qi'] == true) ...[
                  const Divider(),
                  const Text('اختبار البطاقة البنكية — رصيد منفصل'),
                  for (final provider in ['qi'])
                    if (_sandbox?[provider] == true)
                      ListTile(
                        leading: const Icon(Icons.science_outlined),
                        title: Text(provider == 'qi'
                            ? 'اختبار البطاقة البنكية'
                            : 'اختبار زين كاش المباشر'),
                        subtitle:
                            const Text('تجريبي — لا يضاف إلى الرصيد الأساسي'),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    SandboxPaymentScreen(provider: provider))),
                      ),
                ],
                const Divider(),
                ListTile(
                    enabled: !_sessionChanged && !_funding.hasPending && !_busy,
                    leading: const Icon(Icons.payment),
                    title: const Text('الدفع المباشر بزين كاش'),
                    subtitle: const Text('الدفع الآمن ومتابعة عمليات البوابة'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ZaincashPaymentScreen()));
                      if (mounted) _load();
                    }),
                const ListTile(
                    enabled: false,
                    leading: Icon(Icons.credit_card),
                    title: Text('البطاقة البنكية'),
                    subtitle:
                        Text('غير متاحة حالياً — بانتظار اعتماد البوابة')),
                const Divider(),
                const Text('أحدث طلبات الشحن',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (_requests.isEmpty && _error == null && !_busy)
                  const Text('لا توجد طلبات شحن ضمن النتائج المتاحة'),
                if (_funding.historyCursor != null)
                  OutlinedButton(
                      onPressed: _busy ? null : _moreRequests,
                      child: const Text('تحميل طلبات شحن أقدم')),
                ..._requests.map((r) => ListTile(
                    title: Text('${r['amount']} د.ع'),
                    subtitle: Text('${{
                          'PENDING': 'بانتظار المراجعة',
                          'APPROVED': 'تم شحن المحفظة',
                          'REJECTED': 'مرفوض'
                        }[r['status']] ?? r['status']}\n${r['rejectionReason'] ?? ''}\n${r['topupId']}'))),
              ])),
        ));
  }
}
