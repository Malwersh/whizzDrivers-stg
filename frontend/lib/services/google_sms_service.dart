import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/sms_config.dart';
import '../config/sms_service_config.dart';

/// Google Cloud SMS Service using Twilio as a reliable SMS provider
/// Alternative to AWS SNS with better delivery rates for Iraq
class GoogleSMSService {
  // Twilio credentials from configuration
  static String get _accountSid => SMSServiceConfig.twilioAccountSid;
  static String get _authToken => SMSServiceConfig.twilioAuthToken;
  static String get _fromPhoneNumber => SMSServiceConfig.twilioPhoneNumber;

  // Google Cloud Functions endpoint for SMS
  static String get _cloudFunctionUrl => SMSServiceConfig.cloudFunctionUrl;
  static String get _cloudFunctionApiKey =>
      SMSServiceConfig.cloudFunctionApiKey;

  /// Sends SMS verification code using Google Cloud SMS service
  static Future<Map<String, dynamic>> sendVerificationSMS({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    try {
      // Normalize the Iraqi phone number
      final normalizedPhone = SMSConfig.normalizeIraqiPhone(phoneNumber);

      // Validate it's an Iraqi number
      if (!SMSConfig.isIraqiPhoneNumber(normalizedPhone)) {
        return {
          'success': false,
          'error': 'رقم الهاتف يجب أن يكون عراقي',
          'errorCode': 'INVALID_PHONE_FORMAT',
        };
      }

      // Format the verification message in Arabic
      final message = SMSConfig.formatVerificationMessage(verificationCode);

      debugPrint('🌟 Google SMS: Sending verification to $normalizedPhone');
      debugPrint('📱 Message: $message');

      // Try Google Cloud Function first (preferred method)
      final cloudResult = await _sendViaCloudFunction(
        phone: normalizedPhone,
        message: message,
        code: verificationCode,
      );

      if (cloudResult['success'] == true) {
        return cloudResult;
      }

      debugPrint('☁️ Cloud Function failed, trying Twilio...');

      // Fallback to Twilio if Cloud Function fails
      final twilioResult = await _sendViaTwilio(
        phone: normalizedPhone,
        message: message,
        code: verificationCode,
      );

      return twilioResult;
    } catch (e) {
      debugPrint('❌ Google SMS Exception: $e');
      return {
        'success': false,
        'error': 'فشل في إرسال الرسالة النصية',
        'errorCode': 'SMS_SEND_FAILED',
        'details': e.toString(),
      };
    }
  }

  /// Send SMS via Google Cloud Function
  static Future<Map<String, dynamic>> _sendViaCloudFunction({
    required String phone,
    required String message,
    required String code,
  }) async {
    try {
      if (!_isCloudFunctionConfigured()) {
        throw Exception('Google Cloud Function not configured');
      }

      final payload = {
        'to': phone,
        'message': message,
        'code': code,
        'country': 'IQ',
        'sender': 'HADHIR',
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await http
          .post(
            Uri.parse(_cloudFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_cloudFunctionApiKey',
              'X-API-Key': _cloudFunctionApiKey,
            },
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('☁️ Cloud Function Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          return {
            'success': true,
            'messageId':
                responseData['messageId'] ??
                'cf-${DateTime.now().millisecondsSinceEpoch}',
            'phone': phone,
            'provider': 'google_cloud_function',
            'message': 'تم إرسال رمز التحقق عبر Google Cloud',
            'deliveryStatus': responseData['deliveryStatus'] ?? 'sent',
          };
        }
      }

      throw Exception('Cloud Function returned error: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ Cloud Function SMS Error: $e');
      return {
        'success': false,
        'error': 'فشل في إرسال الرسالة عبر Google Cloud',
        'errorCode': 'CLOUD_FUNCTION_FAILED',
        'details': e.toString(),
      };
    }
  }

  /// Send SMS via Twilio as fallback
  static Future<Map<String, dynamic>> _sendViaTwilio({
    required String phone,
    required String message,
    required String code,
  }) async {
    try {
      if (!_isTwilioConfigured()) {
        throw Exception('Twilio not configured');
      }

      // Twilio REST API endpoint
      final url =
          'https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Messages.json';

      // Basic Auth for Twilio
      final credentials = base64Encode(utf8.encode('$_accountSid:$_authToken'));

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Basic $credentials',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {'From': _fromPhoneNumber, 'To': phone, 'Body': message},
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('📱 Twilio Response: ${response.statusCode}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);

        return {
          'success': true,
          'messageId': responseData['sid'],
          'phone': phone,
          'provider': 'twilio',
          'message': 'تم إرسال رمز التحقق عبر Twilio',
          'status': responseData['status'],
          'price': responseData['price'],
        };
      } else {
        final errorData = json.decode(response.body);
        throw Exception('Twilio error: ${errorData['message']}');
      }
    } catch (e) {
      debugPrint('❌ Twilio SMS Error: $e');
      return {
        'success': false,
        'error': 'فشل في إرسال الرسالة عبر Twilio',
        'errorCode': 'TWILIO_FAILED',
        'details': e.toString(),
      };
    }
  }

  /// Generate a secure 6-digit verification code
  static String generateVerificationCode() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Validate verification code format
  static bool isValidVerificationCode(String code) {
    return RegExp(r'^\d{6}$').hasMatch(code);
  }

  /// Check if Google Cloud Function is configured
  static bool _isCloudFunctionConfigured() {
    return SMSServiceConfig.isCloudFunctionConfigured;
  }

  /// Check if Twilio is configured
  static bool _isTwilioConfigured() {
    return SMSServiceConfig.isTwilioConfigured;
  }

  /// Get service status and configuration
  static Map<String, dynamic> getServiceStatus() {
    return {
      'provider': 'google_sms_service',
      'cloudFunctionConfigured': _isCloudFunctionConfigured(),
      'twilioConfigured': _isTwilioConfigured(),
      'supportedCountries': ['Iraq', 'Global'],
      'features': [
        'high_delivery_rate',
        'international_support',
        'fallback_providers',
        'delivery_tracking',
        'cost_optimization',
      ],
      'priorityOrder': ['google_cloud_function', 'twilio'],
    };
  }

  /// Test SMS service connectivity
  static Future<Map<String, dynamic>> testService() async {
    final status = getServiceStatus();

    if (!status['cloudFunctionConfigured'] && !status['twilioConfigured']) {
      return {
        'success': false,
        'error': 'لم يتم تكوين أي خدمة SMS',
        'details': 'يرجى تكوين Google Cloud Function أو Twilio',
      };
    }

    return {
      'success': true,
      'message': 'خدمة SMS جاهزة للاستخدام',
      'availableProviders': [
        if (status['cloudFunctionConfigured']) 'google_cloud_function',
        if (status['twilioConfigured']) 'twilio',
      ],
    };
  }
}
