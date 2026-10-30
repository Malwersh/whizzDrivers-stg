import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'driver_auth_helper.dart';
import 'wallet_api_service.dart';

class FundingRejected implements Exception {
  FundingRejected(this.code, this.message);
  final String code, message;
  @override
  String toString() => message;
}

class FundingSessionChanged implements Exception {
  @override
  String toString() => 'تغير الحساب. أغلق صفحة الشحن وافتحها من الحساب الحالي.';
}

/// Pins the entire funding page to one authenticated subject. Tokens remain in
/// the auth SDK; only the immutable retry payload is kept in account-scoped storage.
class WalletFundingService {
  WalletFundingService(
      {http.Client? client,
      Future<String?> Function()? token,
      Future<SharedPreferences> Function()? preferences})
      : _client = client ?? http.Client(),
        _token = token ?? DriverAuthHelper.getCurrentAccessToken,
        _preferences = preferences ?? SharedPreferences.getInstance;
  final http.Client _client;
  final Future<String?> Function() _token;
  final Future<SharedPreferences> Function() _preferences;
  bool _sending = false;
  String? _subject;
  Map<String, dynamic>? _pending;
  bool get hasPending => _pending != null;
  Map<String, dynamic>? get pending =>
      _pending == null ? null : Map.unmodifiable(_pending!);
  String get _storageKey => 'wallet_funding_pending_v1_$_subject';

  String _subjectOf(String? token) {
    if (token == null) throw FundingSessionChanged();
    try {
      final data = jsonDecode(utf8
          .decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))));
      final sub = data['sub'];
      if (sub is! String || !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(sub))
        throw const FormatException();
      return sub;
    } catch (_) {
      throw FundingSessionChanged();
    }
  }

  Future<String> _access() async {
    final token = await _token();
    final sub = _subjectOf(token);
    if (_subject != null && sub != _subject) throw FundingSessionChanged();
    _subject ??= sub;
    return token!;
  }

  Future<String> account() async {
    await _access();
    return _subject!;
  }

  Future<void> initialize() async {
    await _access();
    final prefs = await _preferences();
    await _access();
    final saved = prefs.getString(_storageKey);
    if (saved == null) return;
    final data = jsonDecode(saved) as Map<String, dynamic>;
    if (data['subject'] != _subject || data['payload'] is! Map) {
      throw const FormatException('تعذر استعادة محاولة الشحن. تواصل مع الدعم.');
    }
    _pending = Map<String, dynamic>.from(data['payload']);
  }

  Future<Map<String, dynamic>> call(String path,
      {Map<String, dynamic>? body}) async {
    final token = await _access();
    final uri = Uri.parse('${WalletApiService.baseUrl}$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      if (body?['idempotencyKey'] != null)
        'X-Idempotency-Key': '${body!['idempotencyKey']}'
    };
    final response = await (body == null
            ? _client.get(uri, headers: headers)
            : _client.post(uri, headers: headers, body: jsonEncode(body)))
        .timeout(const Duration(seconds: 25));
    await _access();
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = data['error'] is Map ? data['error'] as Map : data;
      throw FundingRejected('${error['code'] ?? response.statusCode}',
          '${error['message'] ?? 'تعذر تأكيد النتيجة. حدّث طلبات الشحن قبل إعادة المحاولة.'}');
    }
    return Map<String, dynamic>.from(data['data'] ?? data);
  }

  String? historyCursor;
  Future<List<Map<String, dynamic>>> history({bool more = false}) async {
    final data = await call(
        '/wallet/topup/my-requests${more && historyCursor != null ? '?cursor=${Uri.encodeQueryComponent(historyCursor!)}' : ''}');
    historyCursor = data['cursor'];
    final rows = List<Map<String, dynamic>>.from(data['requests'] ?? []);
    if (!_sending &&
        _pending != null &&
        rows.any((r) =>
            r['driverId'] == _subject &&
            r['amount'] == _pending!['amount'] &&
            r['evidenceRef'] == _pending!['evidenceRef'] &&
            r['transferReference'] == _pending!['transferReference'] &&
            ['PENDING', 'APPROVED', 'REJECTED'].contains(r['status']))) {
      await _clearPending();
    }
    return rows;
  }

  Future<void> _clearPending() async {
    await _access();
    final prefs = await _preferences();
    await _access();
    if (!await prefs.remove(_storageKey))
      throw Exception('تعذر حفظ حالة الطلب. أعد تحديث القائمة.');
    _pending = null;
  }

  Future<Map<String, dynamic>> submit({Map<String, dynamic>? payload}) async {
    if (_sending) throw Exception('جارٍ التحقق من محاولة الشحن');
    _sending = true;
    try {
      return await _submit(payload: payload);
    } finally {
      _sending = false;
    }
  }

  Future<Map<String, dynamic>> _submit({Map<String, dynamic>? payload}) async {
    await _access();
    final isNewAttempt = _pending == null;
    if (_pending == null) {
      if (payload == null) throw Exception('لا توجد محاولة شحن لاستئنافها');
      if (payload['amount'] is! int ||
          payload['amount'] < 1 ||
          payload['amount'] > 9007199254740991 ||
          payload['method'] != 'MANUAL_VERIFICATION' ||
          payload['configVersion'] is! int ||
          payload['evidenceRef'] is! String ||
          !RegExp(r'^receipts/' + _subject! + r'/[a-f0-9-]+\.(jpg|png)$')
              .hasMatch(payload['evidenceRef']) ||
          payload['transferReference'] is! String ||
          !RegExp(r'^[a-zA-Z0-9-]{4,80}$')
              .hasMatch(payload['transferReference'])) {
        throw Exception('راجع المبلغ ومرجع التحويل والوصل قبل الإرسال');
      }
      final record = {...payload, 'idempotencyKey': const Uuid().v4()};
      final prefs = await _preferences();
      await _access();
      if (!await prefs.setString(
          _storageKey, jsonEncode({'subject': _subject, 'payload': record}))) {
        throw Exception('تعذر حفظ محاولة الشحن. لم تُرسل؛ حاول مجددًا.');
      }
      _pending = record;
    }
    late Map<String, dynamic> result;
    try {
      result = await call('/wallet/topup/request', body: _pending);
    } on FundingRejected catch (e) {
      // These responses precede creation. After a previous unknown response we
      // keep its immutable draft until an actual saved request is matched.
      if (isNewAttempt &&
          {
            'CONFIG_CHANGED',
            'METHOD_DISABLED',
            'INVALID_REQUEST',
            'INVALID_FUNDING_REQUEST',
            'FUNDING_AMOUNT_LIMIT',
            'ACCOUNT_CLOSING'
          }.contains(e.code)) {
        await _clearPending();
      }
      rethrow;
    }
    final row = result['topupRequest'];
    if (result['success'] != true ||
        row is! Map ||
        row['driverId'] != _subject ||
        row['amount'] != _pending!['amount'] ||
        row['evidenceRef'] != _pending!['evidenceRef'] ||
        row['transferReference'] != _pending!['transferReference'] ||
        !['PENDING', 'APPROVED', 'REJECTED'].contains(row['status'])) {
      throw Exception(
          'تعذر مطابقة الطلب المحفوظ. حدّث طلبات الشحن؛ لا ترسل تحويلًا آخر.');
    }
    await _clearPending();
    return result;
  }

  Future<void> upload(String url, List<int> bytes, String type) async {
    await _access();
    final response = await _client
        .put(Uri.parse(url),
            headers: {
              'Content-Type': type,
              'x-amz-server-side-encryption': 'AES256',
              'If-None-Match': '*'
            },
            body: bytes)
        .timeout(const Duration(seconds: 25));
    await _access();
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw Exception('تعذر رفع الوصل');
  }

  void dispose() => _client.close();
}
