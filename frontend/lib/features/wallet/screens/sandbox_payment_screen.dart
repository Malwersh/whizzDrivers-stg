import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../services/driver_auth_helper.dart';
import '../../../services/wallet_api_service.dart';

class SandboxPaymentScreen extends StatefulWidget {
  final String provider;
  const SandboxPaymentScreen({super.key, required this.provider});
  @override
  State<SandboxPaymentScreen> createState() => _SandboxPaymentScreenState();
}

class _SandboxPaymentScreenState extends State<SandboxPaymentScreen>
    with WidgetsBindingObserver {
  final _amount = TextEditingController(text: '25000');
  String _requestId = const Uuid().v4();
  Map<String, dynamic>? _overview;
  bool _busy = false;
  String? _error;
  Future<Map<String, dynamic>> _call(String suffix,
      {Map<String, dynamic>? body}) async {
    final token = await DriverAuthHelper.getCurrentAccessToken();
    if (token == null) throw Exception('يرجى تسجيل الدخول');
    final uri =
        Uri.parse('${WalletApiService.baseUrl}/wallet/funding/sandbox$suffix');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };
    final response = await (body == null
            ? http.get(uri, headers: headers)
            : http.post(uri, headers: headers, body: jsonEncode(body)))
        .timeout(const Duration(seconds: 35));
    final value = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 300) {
      throw Exception(value['message'] ?? 'تعذر إكمال الاختبار');
    }
    return Map<String, dynamic>.from(value['data'] ?? value);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final overview = await _call('');
      final pending = List<Map<String, dynamic>>.from(
          (overview['payments'] as List)
              .map((p) => Map<String, dynamic>.from(p)));
      for (final payment
          in pending.where((p) => p['state'] == 'PENDING').take(5)) {
        await _call('/check', body: {'requestId': payment['requestId']});
      }
      final updated = await _call('');
      if (mounted) {
        setState(() {
          _overview = updated;
          if ((updated['payments'] as List).any((p) =>
              p['requestId'] == _requestId &&
              [
                'SUCCESS',
                'FAILED',
                'CANCELED',
                'EXPIRED',
                'AUTHENTICATION_FAILED'
              ].contains(p['state']))) {
            _requestId = const Uuid().v4();
          }
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _pay() async {
    final normalized = _amount.text.replaceAllMapped(
        RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x660}');
    final amount = int.tryParse(normalized);
    if (amount == null || amount < 25000 || amount > 500000) {
      setState(() => _error = 'أدخل مبلغاً بين 25,000 و500,000 دينار');
      return;
    }
    setState(() => _busy = true);
    try {
      final payment = await _call('/payment', body: {
        'provider': widget.provider,
        'amount': amount,
        'requestId': _requestId
      });
      if (payment['checkoutUrl'] == null) {
        throw Exception(
            'العملية قيد التحقق. راجع سجل الاختبار قبل إنشاء محاولة جديدة');
      }
      final opened = await launchUrl(Uri.parse(payment['checkoutUrl']),
          mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('تعذر فتح صفحة الدفع');
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            title: Text(widget.provider == 'qi'
                ? 'اختبار الدفع بالبطاقة'
                : 'اختبار زين كاش')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'بيئة اختبار فقط. استخدم بيانات الاختبار؛ الرصيد هنا لا يسمح باستقبال الطلبات ولا يغيّر محفظتك الأساسية.'))),
          Text('رصيد الاختبار: ${_overview?['balance'] ?? 0} د.ع'),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          TextField(
              controller: _amount,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'مبلغ الاختبار بالدينار'),
              onChanged: (_) => _requestId = const Uuid().v4()),
          FilledButton(
              onPressed: _busy ? null : _pay,
              child: const Text('فتح الدفع التجريبي')),
          OutlinedButton(
              onPressed: _busy ? null : _refresh,
              child: const Text('التحقق من النتيجة')),
          const Divider(),
          ...((_overview?['payments'] ?? []) as List).map((p) => ListTile(
              title: Text('${p['amount']} د.ع — ${p['provider']}'),
              subtitle: Text('${p['state']}'),
              trailing: p['state'] == 'SUCCESS'
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null)),
        ]),
      ));
}
