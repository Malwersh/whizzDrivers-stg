import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../../config/environment.dart';
import '../../../providers/driver_auth_provider.dart';

class PickupIssueService {
  PickupIssueService({http.Client? client, Future<String?> Function()? token})
      : client = client ?? http.Client(),
        token = token ?? DriverAuthHelper.getCurrentAccessToken;
  final http.Client client;
  final Future<String?> Function() token;
  final Map<String, String> _attempts = {};
  Future<Map<String, dynamic>> submit(String orderId,
      {required String issueType,
      String? notes,
      Map<String, dynamic>? assignment}) async {
    final credential = await token();
    if (credential == null || credential.isEmpty)
      throw Exception('أعد تسجيل الدخول');
    final details = notes?.trim();
    final key = jsonEncode([
      credential,
      orderId,
      issueType,
      details,
      assignment?['offerId'],
      assignment?['attempt']
    ]);
    if (_attempts.length > 50) _attempts.clear();
    final id = _attempts.putIfAbsent(key, () => const Uuid().v4());
    final response = await client
        .post(
            Uri.parse(
                '${Environment.apiBaseUrl}/driver/orders/${Uri.encodeComponent(orderId)}/issue'),
            headers: {
              'Authorization': 'Bearer $credential',
              'Content-Type': 'application/json'
            },
            body: jsonEncode({
              'issueType': issueType,
              'issueSource': 'Store',
              'notes': details?.isEmpty == true ? null : details,
              'reportId': id,
              if (assignment != null) ...{
                'offerId': assignment['offerId'],
                'attempt': assignment['attempt']
              }
            }))
        .timeout(const Duration(seconds: 15));
    if (await token() != credential)
      throw Exception('تغيرت الجلسة؛ أعد فتح الطلب');
    if (response.statusCode != 200)
      throw Exception('لم يتأكد حفظ البلاغ؛ حدّث الطلب وأعد المحاولة');
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic> ||
        data['success'] != true ||
        data['orderId'] != orderId ||
        data['reportId'] != id) throw Exception('لم يؤكد الخادم البلاغ');
    _attempts.remove(key);
    return data;
  }
}
