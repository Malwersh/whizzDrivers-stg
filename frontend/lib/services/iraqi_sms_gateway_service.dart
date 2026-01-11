import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/sms_config.dart';

/// Iraqi SMS Gateway Service
/// Alternative SMS delivery for Iraqi numbers using local gateways
class IraqiSMSGatewayService {
  // Iraqi SMS Gateway Configuration (Example - replace with actual provider)
  static const String _gatewayBaseUrl =
      'https://api.iraqisms.com/v1'; // Example URL
  static const String _apiKey =
      'your_iraqi_sms_api_key'; // Replace with actual key
  static const String _senderId = 'HADHIR'; // Your registered sender ID

  /// Sends SMS verification code using Iraqi SMS gateway
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

      debugPrint(
        '🇮🇶 Iraqi SMS Gateway: Sending verification to $normalizedPhone',
      );

      // Format the verification message in Arabic
      final message =
          '''
رمز التحقق الخاص بك من تطبيق هاضر:
$verificationCode

لا تشارك هذا الرمز مع أحد.
صالح لمدة 5 دقائق.

- فريق هاضر
''';

      // Iraqi SMS Gateway API endpoint
      const url = '$_gatewayBaseUrl/send-sms';

      final payload = {
        'phone': normalizedPhone,
        'message': message,
        'sender_id': _senderId,
        'api_key': _apiKey,
        'message_type': 'transactional',
        'language': 'arabic',
      };

      debugPrint('🇮🇶 Sending to Iraqi SMS Gateway: $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('🇮🇶 Iraqi SMS Response: ${response.statusCode}');
      debugPrint('🇮🇶 Iraqi SMS Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          return {
            'success': true,
            'messageId': responseData['message_id'],
            'phone': normalizedPhone,
            'message': 'تم إرسال رمز التحقق عبر الشبكة المحلية العراقية',
            'provider': 'iraqi_gateway',
            'delivery_status': responseData['status'] ?? 'sent',
          };
        } else {
          return {
            'success': false,
            'error': responseData['error'] ?? 'فشل في إرسال الرسالة',
            'errorCode': 'IRAQI_GATEWAY_ERROR',
            'details': responseData['message'],
          };
        }
      } else {
        return {
          'success': false,
          'error': 'فشل الاتصال بالشبكة المحلية العراقية',
          'errorCode': 'GATEWAY_CONNECTION_ERROR',
          'httpStatus': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('❌ Iraqi SMS Gateway Exception: $e');
      return {
        'success': false,
        'error': 'خطأ في الاتصال بخدمة الرسائل النصية',
        'errorCode': 'NETWORK_ERROR',
        'details': e.toString(),
      };
    }
  }

  /// Verifies SMS code (if gateway supports verification)
  static Future<Map<String, dynamic>> verifyCode({
    required String messageId,
    required String verificationCode,
  }) async {
    try {
      debugPrint(
        '🇮🇶 Iraqi SMS Gateway: Verifying code for message: $messageId',
      );

      const url = '$_gatewayBaseUrl/verify-code';

      final payload = {
        'message_id': messageId,
        'code': verificationCode,
        'api_key': _apiKey,
      };

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        return {
          'success': responseData['success'] ?? false,
          'verified': responseData['verified'] ?? false,
          'message': responseData['verified'] == true
              ? 'تم التحقق بنجاح'
              : 'رمز التحقق غير صحيح',
          'provider': 'iraqi_gateway',
        };
      } else {
        return {
          'success': false,
          'verified': false,
          'error': 'فشل في التحقق من الرمز',
          'errorCode': 'VERIFICATION_FAILED',
        };
      }
    } catch (e) {
      debugPrint('❌ Iraqi SMS Verification Exception: $e');
      return {
        'success': false,
        'verified': false,
        'error': 'خطأ في التحقق من الرمز',
        'errorCode': 'NETWORK_ERROR',
        'details': e.toString(),
      };
    }
  }

  /// Gets SMS delivery status
  static Future<Map<String, dynamic>> getDeliveryStatus({
    required String messageId,
  }) async {
    try {
      final url = '$_gatewayBaseUrl/delivery-status/$messageId';

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        return {
          'success': true,
          'messageId': messageId,
          'status': responseData['status'], // 'sent', 'delivered', 'failed'
          'deliveredAt': responseData['delivered_at'],
          'carrier': responseData['carrier'],
          'message': _getStatusMessage(responseData['status']),
        };
      } else {
        return {
          'success': false,
          'error': 'فشل في الحصول على حالة التسليم',
          'errorCode': 'STATUS_CHECK_FAILED',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'خطأ في فحص حالة التسليم',
        'errorCode': 'NETWORK_ERROR',
        'details': e.toString(),
      };
    }
  }

  /// Gets service status and capabilities
  static Map<String, dynamic> getServiceStatus() {
    return {
      'provider': 'iraqi_gateway',
      'enabled': true,
      'supportedCountries': ['Iraq'],
      'supportedCarriers': [
        'Zain Iraq',
        'Asia Cell',
        'Korek Telecom',
        'Omnnea',
      ],
      'features': [
        'local_delivery',
        'carrier_direct',
        'delivery_reports',
        'arabic_support',
        'high_delivery_rate',
      ],
      'senderId': _senderId,
      'gatewayUrl': _gatewayBaseUrl,
    };
  }

  /// Validates if the service is properly configured
  static bool isConfigured() {
    return _apiKey.isNotEmpty &&
        _apiKey != 'your_iraqi_sms_api_key' &&
        _gatewayBaseUrl.isNotEmpty;
  }

  /// Gets Iraqi SMS gateway providers (for documentation)
  static List<Map<String, String>> getIraqiGatewayProviders() {
    return [
      {
        'name': 'IraqiSMS',
        'website': 'https://iraqisms.com',
        'description': 'Local Iraqi SMS gateway with high delivery rates',
      },
      {
        'name': 'Zain Business SMS',
        'website': 'https://business.iq.zain.com',
        'description': 'Direct integration with Zain Iraq network',
      },
      {
        'name': 'AsiaCell Business',
        'website': 'https://business.asiacell.com',
        'description': 'AsiaCell direct SMS gateway',
      },
      {
        'name': 'Korek Business',
        'website': 'https://business.korek.com',
        'description': 'Korek Telecom business SMS services',
      },
      {
        'name': 'IraqTel SMS',
        'website': 'https://iraqtel.com',
        'description': 'Iraqi telecommunications SMS service',
      },
    ];
  }

  static String _getStatusMessage(String? status) {
    switch (status) {
      case 'sent':
        return 'تم إرسال الرسالة';
      case 'delivered':
        return 'تم تسليم الرسالة بنجاح';
      case 'failed':
        return 'فشل في تسليم الرسالة';
      case 'pending':
        return 'الرسالة قيد المعالجة';
      default:
        return 'حالة غير معروفة';
    }
  }
}
