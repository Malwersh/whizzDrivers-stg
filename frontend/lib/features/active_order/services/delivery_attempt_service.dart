import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/environment.dart';
import '../../../providers/driver_auth_provider.dart';

class DeliveryAttemptService {
  final http.Client client;
  final Future<String?> Function() token;
  DeliveryAttemptService(
      {http.Client? client, Future<String?> Function()? token})
      : client = client ?? http.Client(),
        token = token ?? DriverAuthHelper.getCurrentAccessToken;

  Future<Map<String, dynamic>> send(
      String orderId, Map<String, dynamic> assignment,
      {String action = 'read',
      Map<String, dynamic>? position,
      String? eventId}) async {
    final credential = await token();
    if (credential == null || credential.isEmpty)
      throw Exception('أعد تسجيل الدخول');
    final selector = {
      'offerId': assignment['offerId'],
      'attempt': assignment['attempt']
    };
    final endpoint =
        '${Environment.apiBaseUrl}/driver/orders/${Uri.encodeComponent(orderId)}/delivery-attempt';
    final headers = {
      'Authorization': 'Bearer $credential',
      'Content-Type': 'application/json'
    };
    final response = await (action == 'read'
            ? client.get(
                Uri.parse(endpoint).replace(
                    queryParameters: selector.map((k, v) => MapEntry(k, '$v'))),
                headers: headers)
            : client.post(
                Uri.parse(action == 'contact' ? '$endpoint/contact' : endpoint),
                headers: headers,
                body: jsonEncode({
                  ...selector,
                  if (action == 'start') 'position': position,
                  if (action == 'contact') ...{
                    'eventId': eventId,
                    'channel': 'CALL_INITIATED'
                  }
                })))
        .timeout(const Duration(seconds: 20));
    if (await token() != credential)
      throw Exception('تغيرت الجلسة؛ أعد فتح الطلب');
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 ||
        data is! Map<String, dynamic> ||
        data['success'] != true ||
        data['orderId'] != orderId) {
      final code = data is Map ? data['code'] : null;
      throw Exception(switch (code) {
        'ARRIVAL_OUTSIDE_RADIUS' =>
          'اقترب من عنوان الزبون؛ يجب أن تكون ضمن نطاق الوصول المعتمد.',
        'ARRIVAL_LOCATION_REQUIRED' =>
          'دقة الموقع غير كافية؛ انتظر إشارة أدق وأعد المحاولة.',
        'ARRIVAL_LOCATION_STALE' => 'الموقع قديم؛ حدّث موقعك وأعد المحاولة.',
        'CONTACT_ATTEMPT_TOO_SOON' =>
          'انتظر موعد محاولة التواصل التالية وحدّث الحالة.',
        _ => 'تعذر تأكيد العملية؛ حدّث الحالة قبل إعادة المحاولة.'
      });
    }
    return data;
  }
}
