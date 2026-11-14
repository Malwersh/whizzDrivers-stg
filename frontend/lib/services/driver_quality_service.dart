import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import '../providers/driver_auth_provider.dart';

class DriverQualityException implements Exception {
  final String code;
  const DriverQualityException(this.code);
}

class DriverQualityService {
  final http.Client client;
  final Future<String?> Function() token;
  final String endpoint;
  DriverQualityService(
      {http.Client? client,
      Future<String?> Function()? token,
      String? endpoint})
      : client = client ?? http.Client(),
        token = token ?? DriverAuthHelper.getCurrentAccessToken,
        endpoint = endpoint ?? Environment.apiBaseUrl;
  String? _subject(String? token) {
    try {
      final claims = jsonDecode(utf8
          .decode(base64Url.decode(base64Url.normalize(token!.split('.')[1]))));
      return claims['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _request(
      String path, Map<String, dynamic>? body) async {
    final access = await token(), owner = _subject(access);
    if (owner == null) throw const DriverQualityException('UNAUTHORIZED');
    try {
      final headers = {
        'Authorization': 'Bearer $access',
        'Content-Type': 'application/json'
      };
      final url = Uri.parse('$endpoint$path');
      final response = await (body == null
              ? client.get(url, headers: headers)
              : client.post(url, headers: headers, body: jsonEncode(body)))
          .timeout(const Duration(seconds: 30));
      if (_subject(await token()) != owner) {
        throw const DriverQualityException('UNAUTHORIZED');
      }
      final data = jsonDecode(response.body);
      if (response.statusCode != 200 ||
          data is! Map<String, dynamic> ||
          data['success'] != true) {
        throw DriverQualityException(data is Map && data['code'] is String
            ? data['code']
            : 'QUALITY_UNAVAILABLE');
      }
      return data;
    } on DriverQualityException {
      rethrow;
    } catch (_) {
      throw const DriverQualityException('QUALITY_UNAVAILABLE');
    }
  }

  Future<Map<String, dynamic>> load() =>
      _request('/driver/quality-incidents', null);
  Future<Map<String, dynamic>> appeal(Map<String, dynamic> body) =>
      _request('/driver/quality-incidents/appeal', body);
  void dispose() => client.close();
}
