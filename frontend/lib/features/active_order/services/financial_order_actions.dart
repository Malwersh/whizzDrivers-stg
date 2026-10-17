import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/environment.dart';
import '../../../providers/driver_auth_provider.dart';

class FinancialOrderActions {
  final http.Client client;
  final Future<String?> Function() token;
  FinancialOrderActions(
      {http.Client? client, Future<String?> Function()? token})
      : client = client ?? http.Client(),
        token = token ?? DriverAuthHelper.getCurrentAccessToken;

  Future<Map<String, dynamic>> send(
      String orderId, String action, Map<String, dynamic> assignment,
      {String? reason}) async {
    if (!['request-return', 'arrive-return', 'financial-unassign']
            .contains(action) ||
        assignment['offerId'] is! String ||
        assignment['attempt'] is! int) {
      throw Exception('بيانات محاولة الإسناد غير متاحة؛ حدّث الطلب');
    }
    final credential = await token();
    if (credential == null || credential.isEmpty)
      throw Exception('أعد تسجيل الدخول');
    final body = <String, dynamic>{
      'offerId': assignment['offerId'],
      'attempt': assignment['attempt']
    };
    if (action == 'request-return') {
      body.addAll({'reason': reason, 'cashCollected': false});
    } else if (action == 'arrive-return') {
      body['returnId'] = assignment['returnId'];
    } else {
      body['cashCollected'] = false;
      body['reason'] = reason;
    }
    final response = await client
        .post(
          Uri.parse(
              '${Environment.apiBaseUrl}/driver/orders/${Uri.encodeComponent(orderId)}/$action'),
          headers: {
            'Authorization': 'Bearer $credential',
            'Content-Type': 'application/json'
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (await token() != credential)
      throw Exception('تغيرت الجلسة؛ أعد فتح الطلب');
    if (response.statusCode != 200)
      throw Exception('تعذر تأكيد العملية؛ حدّث الطلب قبل إعادة المحاولة');
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic> ||
        data['success'] != true ||
        data['orderId'] != orderId) {
      throw Exception('لم يؤكد الخادم العملية');
    }
    return data;
  }
}
