import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config/environment.dart';
import 'driver_auth_helper.dart';

class DriverCashPayoutService {
  DriverCashPayoutService({this.transport, this.userReader, this.tokenReader});
  final http.Client? transport;
  final Future<String?> Function()? userReader, tokenReader;
  Future<String?> _user() =>
      userReader?.call() ?? DriverAuthHelper.getCurrentUserId();
  Future<String?> _token() =>
      tokenReader?.call() ?? DriverAuthHelper.getCurrentAccessToken();
  static const states = {
    'UNDER_REVIEW': 'بانتظار المراجعة',
    'APPROVED': 'معتمد · بانتظار التسليم',
    'PROCESSING': 'جارٍ تجهيز التسليم',
    'AWAITING_RECEIPT': 'بانتظار تأكيد استلامك',
    'RECEIPT_CONFIRMED': 'استلمت · بانتظار المطابقة',
    'PAID': 'مكتمل',
    'CANCELLED': 'ملغى',
    'RECONCILIATION_REQUIRED': 'قيد المراجعة',
    'NON_RECEIPT_CONFIRMED': 'لم تستلم · بانتظار الحسم',
    'FAILED_NOT_PAID': 'أُعيد الرصيد إلى المحفظة'
  };
  static String? blockedReason(Map? eligibility) {
    if (eligibility == null) return null;
    if (eligibility['activePayoutId'] != null) {
      return 'لديك طلب صرف قيد المتابعة. أكمله أو ألغِه قبل تقديم طلب جديد.';
    }
    if (eligibility['status'] != 'VERIFIED' ||
        eligibility['eligibleIqd'] is! num) {
      switch (eligibility['code']) {
        case 'DRIVER_PAYOUT_RECONCILIATION_REQUIRED':
          return 'يوجد فرق بين سجل حركات المحفظة ورصيدها. الصرف متوقف لحين مراجعة الإدارة ومطابقة الرصيد. تواصل مع الدعم لمتابعة المراجعة؛ لا تحتاج إلى شحن المحفظة لمعالجة هذا الفرق.';
        case 'DRIVER_PAYOUT_HISTORY_UNVERIFIED':
        case 'DRIVER_PAYOUT_HISTORY_TOO_LARGE':
        case 'DRIVER_PAYOUT_SOURCE_INVALID':
          return 'لم يكتمل التحقق من سجل المحفظة أو مصادر الرصيد. يلزم أن تراجع الإدارة الحركات قبل إتاحة الصرف. تواصل مع الدعم لمتابعة المراجعة.';
        case 'DRIVER_PAYOUT_WALLET_UNAVAILABLE':
          return 'المحفظة غير مؤهلة للصرف حاليًا. تواصل مع الدعم لمراجعة حالة المحفظة.';
        case 'DRIVER_PAYOUT_WALLET_CHANGED':
          return 'تغيّر رصيد المحفظة أثناء التحقق. اضغط تحديث لإعادة فحص الرصيد المؤهل.';
        default:
          return 'تعذر التحقق من الرصيد المؤهل الآن. اضغط تحديث لإعادة المحاولة، وإذا استمرت المشكلة تواصل مع الدعم.';
      }
    }
    if ((eligibility['eligibleIqd'] as num) <= 0) {
      return 'لا يوجد رصيد مؤهل للصرف حاليًا من التعويضات المعتمدة أو الشحن المثبت غير المستخدم. المبالغ المحجوزة للطلبات وأجرة التوصيل التي احتفظت بها نقدًا غير متاحة للصرف.';
    }
    return null;
  }

  static String friendly(String? code) {
    if (code == 'DRIVER_PAYOUT_ACTIVE_REQUEST')
      return 'لديك طلب صرف قيد المتابعة. أكمله أو ألغِه قبل طلب جديد.';
    if (code == 'DRIVER_PAYOUT_NOT_ELIGIBLE')
      return 'المبلغ يتجاوز الرصيد المؤهل. حدّث البيانات وراجع المبلغ.';
    if (code == 'DRIVER_PAYOUT_STATE_CHANGED' ||
        code == 'DRIVER_PAYOUT_WALLET_CHANGED')
      return 'تغيّرت البيانات. حدّث الحالة قبل إعادة المحاولة.';
    if (code == 'UNAUTHORIZED') return 'سجّل الدخول مجددًا.';
    if (code == 'DRIVER_PAYOUT_DISABLED') return 'صرف الرصيد غير متاح حاليًا.';
    return 'تعذر تأكيد العملية. حدّث الحالة ثم أعد المحاولة؛ لن يتكرر الطلب نفسه.';
  }

  Future<Map<String, dynamic>> call(Map<String, dynamic> input,
      {bool mutation = false}) async {
    final user = await _user(), token = await _token();
    if (user == null || token == null) throw Exception('سجّل الدخول مجددًا.');
    if (user != await _user())
      throw Exception('تغيّر الحساب. أعد فتح المحفظة.');
    final body = Map<String, dynamic>.from(input)..['driverId'] = user;
    final prefs = await SharedPreferences.getInstance();
    final storeKey = 'driver_cash_payout_pending_v1_$user';
    if (mutation) {
      final signature = jsonEncode(input), old = prefs.getString(storeKey);
      if (old != null) {
        final saved = jsonDecode(old) as Map;
        if (saved['signature'] != signature)
          throw Exception(
              'توجد عملية لم تتأكد نتيجتها. أعد المحاولة بالإجراء نفسه أولًا.');
        body['requestId'] = saved['requestId'];
      } else {
        body['requestId'] = const Uuid().v4();
        await prefs.setString(
            storeKey,
            jsonEncode(
                {'signature': signature, 'requestId': body['requestId']}));
      }
    }
    try {
      final response = await (transport?.post ?? http.post)(
              Uri.parse('${Environment.apiBaseUrl}/driver/cash-payouts'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json'
              },
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 35));
      if (user != await _user())
        throw Exception('تغيّر الحساب. أعد فتح المحفظة.');
      final out = jsonDecode(response.body);
      if (response.statusCode != 200 || out is! Map || out['success'] != true) {
        // A definitive rejection can be retried against a newly fetched version.
        if (mutation &&
            [400, 401, 403, 409].contains(response.statusCode) &&
            out is Map &&
            out['code'] != null) await prefs.remove(storeKey);
        throw Exception(friendly(out is Map ? out['code']?.toString() : null));
      }
      if (mutation) await prefs.remove(storeKey);
      return Map<String, dynamic>.from(out);
    } on FormatException {
      throw Exception('تعذر قراءة النتيجة. حدّث الحالة قبل إعادة المحاولة.');
    } on TimeoutException {
      throw Exception(
          'لم تتأكد نتيجة الاتصال. اضغط تحديث للتحقق دون تكرار الطلب.');
    }
  }

  Future<Map<String, dynamic>>? _pendingRetry;
  Future<void> retryPending() async {
    final user = await _user();
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance(),
        raw = prefs.getString('driver_cash_payout_pending_v1_$user');
    if (raw == null) return;
    final saved = jsonDecode(raw) as Map;
    if (_pendingRetry != null) {
      await _pendingRetry;
      return;
    }
    _pendingRetry = call(
        Map<String, dynamic>.from(jsonDecode(saved['signature'] as String)),
        mutation: true);
    try {
      await _pendingRetry;
    } finally {
      _pendingRetry = null;
    }
  }
}
