import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'wallet_funding_service.dart';

/// Retains one immutable attempt per account, including timeouts before init returns.
class ZaincashFundingService {
  ZaincashFundingService(
      {WalletFundingService? transport,
      Future<SharedPreferences> Function()? preferences})
      : transport = transport ?? WalletFundingService(),
        _preferences = preferences ?? SharedPreferences.getInstance;
  final WalletFundingService transport;
  final Future<SharedPreferences> Function() _preferences;
  Map<String, dynamic>? pending;
  String? _subject;
  bool _sending = false;
  String get _key => 'zaincash_attempt_v1_$_subject';
  Future<void> _account() async {
    final sub = await transport.account();
    if (_subject != null && _subject != sub) throw FundingSessionChanged();
    _subject ??= sub;
  }

  Future<void> initialize() async {
    await _account();
    final prefs = await _preferences();
    await _account();
    final saved = prefs.getString(_key);
    if (saved == null) return;
    final data = jsonDecode(saved);
    if (data is! Map ||
        data['subject'] != _subject ||
        data['amount'] is! int ||
        !['LIVE', 'UAT'].contains(data['mode']) ||
        data['requestId'] is! String ||
        !RegExp(r'^[a-f0-9-]{36}$').hasMatch(data['requestId'])) {
      throw Exception(
          'تعذر استعادة مرجع الدفع. راجع سجل العمليات والدعم قبل الدفع مجددًا.');
    }
    pending = {
      'requestId': data['requestId'],
      'amount': data['amount'],
      'mode': data['mode']
    };
  }

  Future<Map<String, dynamic>> config() =>
      transport.call('/wallet/funding/zaincash/config');
  Future<Map<String, dynamic>> history({String? cursor}) => transport.call(
      '/wallet/funding/zaincash/payments${cursor == null ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}'}');
  Future<void> _resolved(Map<String, dynamic> p) async {
    if (pending == null ||
        p['requestId'] != pending!['requestId'] ||
        p['amount'] != pending!['amount'] || p['mode'] != pending!['mode'] ||
        !['SUCCESS', 'FAILED', 'EXPIRED', 'CANCELED', 'NOT_CREATED']
            .contains(p['state'])) return;
    final prefs = await _preferences();
    await _account();
    if (!await prefs.remove(_key))
      throw Exception('تعذر حفظ نتيجة الدفع. حدّث السجل.');
    pending = null;
  }

  Future<Map<String, dynamic>> check(String requestId) async {
    final p = await transport
        .call('/wallet/funding/zaincash/check', body: {'requestId': requestId});
    await _resolved(p);
    return p;
  }

  Future<Map<String, dynamic>> pay(int amount,
      {String expectedMode = 'UAT'}) async {
    if (_sending) throw Exception('جارٍ متابعة عملية الدفع');
    _sending = true;
    try {
      await _account();
      final newAttempt = pending == null;
      if (pending == null) {
        if (amount < 25000 || amount > 500000)
          throw Exception('راجع مبلغ الشحن');
        final data = {
          'requestId': const Uuid().v4(),
          'amount': amount,
          'mode': expectedMode
        };
        final prefs = await _preferences();
        await _account();
        if (!await prefs.setString(
            _key, jsonEncode({...data, 'subject': _subject}))) {
          throw Exception('تعذر حفظ مرجع الدفع. لم تُرسل العملية.');
        }
        pending = data;
      }
      late Map<String, dynamic> p;
      try {
        p = await transport.call('/wallet/funding/zaincash/payment',
            body: pending);
      } on FundingRejected catch (e) {
        if (newAttempt &&
            [
              'METHOD_DISABLED',
              'ACCOUNT_CLOSING',
              'ZAINCASH_INVALID',
              'ZAINCASH_ACTIVE_PAYMENT',
              'ZAINCASH_MODE_CHANGED'
            ].contains(e.code)) {
          final prefs = await _preferences();
          await _account();
          if (await prefs.remove(_key)) pending = null;
        }
        rethrow;
      }
      if (p['requestId'] != pending!['requestId'] ||
          p['amount'] != pending!['amount'] || p['mode'] != pending!['mode']) {
        throw Exception(
            'تعذر مطابقة عملية الدفع. راجع الدعم قبل الدفع مجددًا.');
      }
      await _resolved(p);
      return p;
    } finally {
      _sending = false;
    }
  }

  Future<void> confirmSavedOutcome(Map<String, dynamic> p) => _resolved(p);
  void dispose() => transport.dispose();
}
