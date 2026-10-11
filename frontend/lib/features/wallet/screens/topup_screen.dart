import 'sandbox_payment_screen.dart';
import 'dart:async';
import '../../../services/push_notifications_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../../services/wallet_api_service.dart';
import '../../../services/driver_auth_helper.dart';

class TopupScreen extends StatefulWidget {
  const TopupScreen({super.key});
  @override
  State<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends State<TopupScreen> with WidgetsBindingObserver {
  StreamSubscription<dynamic>? _pushEvents;
  bool _loading = false;
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _api = WalletApiService();
  Map<String, dynamic>? _config;
  Map<String, dynamic>? _sandbox;
  List<Map<String, dynamic>> _requests = [];
  String? _error, _receipt;
  String _requestKey = const Uuid().v4();
  bool _busy = false;
  Future<Map<String, dynamic>> _call(String path,
      {Map<String, dynamic>? body}) async {
    final token = await DriverAuthHelper.getCurrentAccessToken();
    if (token == null) throw Exception('يرجى تسجيل الدخول');
    final uri = Uri.parse('${WalletApiService.baseUrl}$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };
    final response = body == null
        ? await http.get(uri, headers: headers)
        : await http.post(uri, headers: headers, body: jsonEncode(body));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'تعذر إكمال العملية');
    }
    return (data['data'] ?? data) as Map<String, dynamic>;
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
    if (_loading) return;
    _loading = true;
    if (!silent) setState(() => _busy = true);
    try {
      final config = await _call('/wallet/funding/config');
      final requests = await _api.getTopupRequests();
      Map<String, dynamic>? sandbox;
      try {
        sandbox = await _call('/wallet/funding/sandbox/config');
      } catch (_) {/* Optional test features stay hidden when unavailable. */}
      if (mounted) {
        setState(() {
          _config = config;
          _sandbox = sandbox;
          _requests = requests;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      _loading = false;
      if (mounted && !silent) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    final image = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 1800);
    if (image == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await image.readAsBytes();
      final png = bytes.length > 7 && bytes[0] == 137 && bytes[1] == 80;
      final jpg = bytes.length > 3 && bytes[0] == 255 && bytes[1] == 216;
      if (!png && !jpg) throw Exception('اختر صورة JPG أو PNG');
      final contentType = png ? 'image/png' : 'image/jpeg';
      final signed = await _call('/wallet/funding/receipt',
          body: {'contentType': contentType, 'size': bytes.length});
      final result = await http.put(Uri.parse(signed['uploadUrl']),
          headers: {
            'Content-Type': contentType,
            'x-amz-server-side-encryption': 'AES256',
            'If-None-Match': '*'
          },
          body: bytes);
      if (result.statusCode >= 300) throw Exception('تعذر رفع الوصل');
      if (mounted) {
        setState(() {
          _receipt = signed['key'];
          _requestKey = const Uuid().v4();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final normalized = _amount.text.replaceAllMapped(
        RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x660}');
    final amount = int.tryParse(normalized);
    if (amount == null ||
        amount < 25000 ||
        _receipt == null ||
        _reference.text.trim().isEmpty) {
      setState(() =>
          _error = 'الحد الأدنى 25,000 د.ع. أدخل مرجع التحويل وارفع الوصل');
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.requestTopup(
          amount: amount,
          method: 'MANUAL_VERIFICATION',
          evidenceRef: _receipt,
          idempotencyKey: _requestKey,
          transferReference: _reference.text.trim().replaceAllMapped(
              RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x660}'),
          configVersion: _config!['version']);
      if (!mounted) return;
      _amount.clear();
      _reference.clear();
      _receipt = null;
      _requestKey = const Uuid().v4();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('أُرسل الطلب للمراجعة. يضاف الرصيد بعد موافقة المدير')));
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _pushEvents?.cancel();
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
                if (!enabled)
                  const Text(
                      'التحويل غير متاح حالياً. لم تُفعّل بيانات المستلم بعد.'),
                if (enabled) ...[
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
                      onChanged: (_) => _requestKey = const Uuid().v4()),
                  TextField(
                      controller: _reference,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                          labelText: 'رقم عملية التحويل في زين كاش'),
                      onChanged: (_) => _requestKey = const Uuid().v4()),
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
                if (_sandbox?['eligible'] == true) ...[
                  const Divider(),
                  const Text('اختبار بوابات الدفع — رصيد منفصل'),
                  for (final provider in ['zaincash', 'qi'])
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
                const ListTile(
                    enabled: false,
                    leading: Icon(Icons.payment),
                    title: Text('الدفع المباشر بزين كاش'),
                    subtitle:
                        Text('غير متاح حالياً — بانتظار تفعيل بوابة الدفع')),
                const ListTile(
                    enabled: false,
                    leading: Icon(Icons.credit_card),
                    title: Text('البطاقة البنكية'),
                    subtitle:
                        Text('غير متاحة حالياً — بانتظار اعتماد البوابة')),
                const Divider(),
                const Text('طلبات الشحن',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (_requests.isEmpty) const Text('لا توجد طلبات شحن'),
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
