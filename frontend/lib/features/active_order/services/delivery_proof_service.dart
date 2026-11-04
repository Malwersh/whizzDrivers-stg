import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../../config/environment.dart';
import '../../../providers/driver_auth_provider.dart';

class DeliveryProofService {
  DeliveryProofService({http.Client? client, Future<String?> Function()? token})
      : client = client ?? http.Client(),
        token = token ?? DriverAuthHelper.getCurrentAccessToken;
  final http.Client client;
  final Future<String?> Function() token;
  Future<Map<String, dynamic>> _request(String orderId,
      {String? id, Map<String, dynamic>? body}) async {
    final credential = await token();
    if (credential == null || credential.isEmpty)
      throw Exception('أعد تسجيل الدخول');
    final uri = Uri.parse(
        '${Environment.apiBaseUrl}/driver/orders/${Uri.encodeComponent(orderId)}/delivery-proof${id == null ? '' : '/${Uri.encodeComponent(id)}'}');
    final headers = {
      'Authorization': 'Bearer $credential',
      'Content-Type': 'application/json'
    };
    final response = await (body == null
            ? client.get(uri, headers: headers)
            : client.post(uri, headers: headers, body: jsonEncode(body)))
        .timeout(const Duration(seconds: 35));
    if (await token() != credential) throw Exception('تغيرت جلسة الدخول');
    if (response.statusCode != 200)
      throw Exception('لم يتأكد حفظ الصورة؛ حاول مجددًا');
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic> ||
        data['success'] != true ||
        data['orderId'] != orderId) throw Exception('استجابة الصورة غير مؤكدة');
    return data;
  }

  Future<List<Map<String, dynamic>>> list(String orderId) async {
    final data = await _request(orderId);
    return (data['proofs'] as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
  }

  Future<Map<String, dynamic>> upload(String orderId, String id,
      Uint8List bytes, Map<String, dynamic>? assignment) async {
    final data = await _request(orderId, body: {
      'proofId': id,
      'fileData': base64Encode(bytes),
      if (assignment != null) ...{
        'offerId': assignment['offerId'],
        'attempt': assignment['attempt']
      }
    });
    if (data['proof']?['id'] != id ||
        data['proof']?['sha256'] != sha256.convert(bytes).toString())
      throw Exception('لم يتأكد ربط الصورة بالطلب');
    return Map<String, dynamic>.from(data['proof']);
  }

  Future<Uint8List> view(String orderId, String id) async {
    final data = await _request(orderId, id: id);
    if (data['proof']?['id'] != id) throw Exception('الصورة لا تطابق الإثبات');
    final bytes = base64Decode(data['fileData'] as String);
    if (bytes.length > 1500000 ||
        sha256.convert(bytes).toString() != data['proof']?['sha256'])
      throw Exception('تعذر التحقق من الصورة');
    return bytes;
  }
}
