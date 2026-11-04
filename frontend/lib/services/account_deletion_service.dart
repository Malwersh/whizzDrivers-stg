import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'cognito_token_service.dart';

class AccountDeletionService {
  static const _base = String.fromEnvironment('ACCOUNT_DELETION_API_URL', defaultValue: 'https://77j15qyukg.execute-api.us-east-1.amazonaws.com/staging');
  static const _storage = FlutterSecureStorage(iOptions: IOSOptions(accountName: 'driver_account_deletion'), aOptions: AndroidOptions(sharedPreferencesName: 'driver_account_deletion'));
  static Future<bool> hasSavedReceipt() async => await _storage.read(key: 'receipt') != null;

  Future<String?> _owner() async {
    try { return (await Amplify.Auth.getCurrentUser()).userId; } catch (_) { return null; }
  }

  Future<Map<String, dynamic>> _receipt(String? owner) async {
    final saved = await _storage.read(key: 'receipt');
    if (saved == null) throw Exception('يرجى تسجيل الدخول إلى حسابك');
    final receipt = jsonDecode(saved) as Map<String, dynamic>;
    if (owner != null && owner != receipt['ownerId']) throw Exception('يرجى تسجيل الدخول إلى حسابك');
    try {
      return await _request('receipt', body: {'receiptToken': receipt['token']});
    } on _AuthenticationExpired {
      throw Exception('انتهت صلاحية إيصال المتابعة؛ تواصل مع الدعم بمرجع طلبك');
    }
  }

  Future<Map<String, dynamic>> call(String path, {Map<String, dynamic>? body}) async {
    final owner = await _owner();
    final token = await CognitoTokenService.getAccessToken();
    if (token == null || token.isEmpty) {
      if (path == 'status') return _receipt(owner);
      throw Exception('يرجى تسجيل الدخول إلى حسابك');
    }
    try {
      final result = await _request(path, token: token, body: body);
      if (owner != null && result['receiptToken'] is String) await _storage.write(key: 'receipt', value: jsonEncode({'ownerId': owner, 'token': result['receiptToken']}));
      return result;
    } on _AuthenticationExpired {
      if (path == 'status') return _receipt(owner);
      throw Exception('يرجى تسجيل الدخول إلى حسابك');
    }
  }

  Future<Map<String, dynamic>> _request(String path, {String? token, Map<String, dynamic>? body}) async {
    final headers = {'Content-Type': 'application/json', if(token != null) 'Authorization': 'Bearer $token'};
    final uri = Uri.parse('$_base/deletion/$path');
    final response = await (body == null ? http.get(uri, headers: headers) : http.post(uri, headers: headers, body: jsonEncode(body))).timeout(const Duration(seconds: 30));
    if(response.statusCode == 401) throw _AuthenticationExpired();
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if(response.statusCode >= 400) throw Exception(data['message'] ?? 'تعذر إكمال العملية؛ حدّث حالة الطلب قبل إعادة المحاولة');
    return data;
  }
}
class _AuthenticationExpired implements Exception {}
