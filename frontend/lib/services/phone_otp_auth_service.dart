import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../utils/iraqi_phone.dart';
import 'cognito_auth_service_enhanced.dart';

/// Amplify owns token persistence and refresh; no parallel token store.
class PhoneAuthException implements Exception {
  final String message;
  const PhoneAuthException(this.message);
}

class PhoneOtpAuthService {
  bool _busy = false;
  bool _awaitingCode = false;
  String? _sessionId;
  String? _phone;
  String? get phone => _phone;
  static const _baseUrl = String.fromEnvironment('PHONE_AUTH_API_URL',
      defaultValue:
          'https://yyka17sq38.execute-api.us-east-1.amazonaws.com/staging');

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    if (_baseUrl.isEmpty) {
      throw StateError('Phone authentication is not configured');
    }
    final response = await http
        .post(Uri.parse('$_baseUrl/auth/phone/$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 35));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw PhoneAuthException(
          data['message'] as String? ?? 'تعذر إكمال العملية');
    }
    return data;
  }

  Future<void> requestCode(String input) async {
    if (_busy) throw StateError('طلب آخر قيد التنفيذ');
    _busy = true;
    _awaitingCode = false;
    try {
      final phone = IraqiPhone.normalize(input);
      final data = await _post('send', {'phone': phone});
      _sessionId = data['sessionId'] as String;
      _phone = phone;
      _awaitingCode = true;
    } finally {
      _busy = false;
    }
  }

  Future<bool> verifyCode(String code) async {
    if (_busy || !_awaitingCode) throw StateError('اطلب رمز التحقق أولاً');
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      throw const FormatException('أدخل رمز التحقق المكون من 6 أرقام');
    }
    _busy = true;
    try {
      final data = await _post(
          'verify', {'phone': _phone, 'sessionId': _sessionId, 'code': code});
      final start = await Amplify.Auth.signIn(
        username: data['username'] as String,
        options: const SignInOptions(
            pluginOptions: CognitoSignInPluginOptions(
          authFlowType: AuthenticationFlowType.customAuthWithoutSrp,
        )),
      );
      if (start.isSignedIn ||
          start.nextStep.signInStep !=
              AuthSignInStep.confirmSignInWithCustomChallenge) {
        throw StateError('تعذر بدء جلسة الدخول');
      }
      final result = await Amplify.Auth.confirmSignIn(
          confirmationValue: data['loginProof'] as String);
      if (result.isSignedIn) {
        _awaitingCode = false;
        final auth = CognitoAuthServiceEnhanced();
        await auth.initialize();
        final driver = await auth.getCurrentDriver();
        if (driver['success'] != true) {
          throw const PhoneAuthException('تعذر تحميل الحساب؛ أعد فتح التطبيق');
        }
        return true;
      }
      _awaitingCode = result.nextStep.signInStep ==
          AuthSignInStep.confirmSignInWithCustomChallenge;
      return false;
    } finally {
      _busy = false;
    }
  }
}
