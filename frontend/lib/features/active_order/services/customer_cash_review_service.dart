import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/environment.dart';
import '../../../providers/driver_auth_provider.dart';

class CustomerCashReviewService {
  final http.Client client;
  final Future<String?> Function() token;
  CustomerCashReviewService(
      {http.Client? client, Future<String?> Function()? token})
      : client = client ?? http.Client(),
        token = token ?? DriverAuthHelper.getCurrentAccessToken;
  Future<Map<String, dynamic>> call(
      String orderId, Map<String, dynamic> body) async {
    final credential = await token();
    if (credential == null || credential.isEmpty) {
      throw Exception('UNAUTHORIZED');
    }
    final response = await client
        .post(
            Uri.parse(
                '${Environment.apiBaseUrl}/driver/orders/${Uri.encodeComponent(orderId)}/cash-review'),
            headers: {
              'Authorization': 'Bearer $credential',
              'Content-Type': 'application/json'
            },
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    if (await token() != credential) throw Exception('UNAUTHORIZED');
    final value = jsonDecode(response.body);
    if (response.statusCode != 200 ||
        value is! Map<String, dynamic> ||
        value['success'] != true ||
        value['orderId'] != orderId) {
      throw Exception(value is Map ? value['code'] : 'CASH_REVIEW_UNAVAILABLE');
    }
    return value;
  }
}
