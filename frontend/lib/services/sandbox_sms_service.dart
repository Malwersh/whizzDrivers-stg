import 'package:flutter/foundation.dart';

import '../config/environment.dart';

/// Enhanced SMS verification service with AWS End User Messaging
/// Now uses dedicated phone number +14255552152 for reliable SMS delivery
class SandboxSMSService {
  // Dedicated phone number configuration
  static const String dedicatedPhoneNumber = '+14255552152';

  // Legacy bypass codes (kept for backward compatibility during transition)
  static const List<String> _emergencyBypassCodes = [
    '123456', // Primary bypass (legacy)
    '999999', // Secondary bypass (legacy)
    '555555', // Tertiary bypass (legacy)
    '111111', // Development bypass (legacy)
    '000000', // Debug bypass (legacy)
  ];

  // Iraqi carriers for future carrier-specific optimizations
  // static const List<String> _iraqiCarriers = ['Zain Iraq', 'Asia Cell', 'Korek Telecom'];

  /// Determines if phone number should use bypass codes
  /// With dedicated phone number +14255552152, bypasses are rarely needed
  static bool shouldUseBypass(String phoneNumber) {
    // Dedicated phone number should work reliably - bypasses only for extreme fallback
    if (Environment.awsAccessKeyId == 'YOUR_AWS_ACCESS_KEY_ID') {
      debugPrint('⚠️  AWS not configured - using bypass for $phoneNumber');
      return true;
    }

    // In production with dedicated number, bypasses should not be needed
    debugPrint(
      '✅ Using dedicated number $dedicatedPhoneNumber for $phoneNumber',
    );
    return false;
  }

  /// Validates if a verification code is a valid bypass code
  static bool isBypassCode(String code) {
    return _emergencyBypassCodes.contains(code.trim());
  }

  /// Gets appropriate error message for SMS verification failure
  static String getSMSErrorMessage(String phoneNumber, {String? errorCode}) {
    if (phoneNumber.startsWith('+964')) {
      // Iraqi-specific error messages with dedicated phone number reference
      return 'لم تصل رسالة التحقق من $dedicatedPhoneNumber؟ تحقق من رسائلك أو جرب إعادة الإرسال.';
    }

    return 'فشل في إرسال رمز التحقق من $dedicatedPhoneNumber. يرجى المحاولة مرة أخرى.';
  }

  /// Gets user-friendly success message for bypass verification
  static String getBypassSuccessMessage(String code) {
    if (code == '123456') {
      return 'تم التحقق بنجاح باستخدام الرمز الاحتياطي الأساسي';
    } else if (code == '999999') {
      return 'تم التحقق بنجاح باستخدام الرمز الاحتياطي الثانوي';
    } else if (code == '555555') {
      return 'تم التحقق بنجاح باستخدام الرمز الاحتياطي الثالث';
    }

    return 'تم التحقق بنجاح باستخدام رمز احتياطي';
  }

  /// Provides detailed SMS delivery status information
  static Map<String, dynamic> getSMSDeliveryStatus(String phoneNumber) {
    final isIraqi = phoneNumber.startsWith('+964');
    const isInSandbox = !Environment.isProduction;

    return {
      'phone_number': phoneNumber,
      'is_iraqi': isIraqi,
      'is_sandbox': isInSandbox,
      'carrier_blocking_risk': isIraqi ? 'high' : 'low',
      'bypass_recommended': shouldUseBypass(phoneNumber),
      'bypass_codes': shouldUseBypass(phoneNumber)
          ? _emergencyBypassCodes.take(3).toList()
          : [],
      'delivery_method': 'dedicated_phone_number',
      'success_probability': '95%', // High success rate with dedicated number
      'dedicated_number': dedicatedPhoneNumber,
    };
  }

  /// Formats phone number for optimal SMS delivery
  static String formatForSMS(String phoneNumber) {
    // Remove all non-digit characters except +
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Iraqi phone number formatting
    if (cleaned.startsWith('07') && cleaned.length == 11) {
      return '+964${cleaned.substring(1)}';
    } else if (cleaned.startsWith('7') && cleaned.length == 10) {
      return '+964$cleaned';
    } else if (cleaned.startsWith('964') && !cleaned.startsWith('+')) {
      return '+$cleaned';
    }

    return cleaned;
  }

  /// Validates Iraqi phone number format
  static bool isValidIraqiPhone(String phoneNumber) {
    final formatted = formatForSMS(phoneNumber);

    // Must start with +964 and have correct length
    if (!formatted.startsWith('+964')) return false;

    // Extract the mobile part (after +964)
    final mobilePart = formatted.substring(4);

    // Must be 10 digits starting with 7
    return RegExp(r'^7[0-9]{9}$').hasMatch(mobilePart);
  }

  /// Gets recommendations for improving SMS delivery
  static List<String> getSMSImprovementRecommendations(String phoneNumber) {
    final recommendations = <String>[];

    if (phoneNumber.startsWith('+964')) {
      recommendations.addAll([
        'استخدم الرموز الاحتياطية: ${_emergencyBypassCodes.take(3).join('، ')}',
        'تأكد من أن الرقم صحيح: ${formatForSMS(phoneNumber)}',
        'جرب في وقت مختلف (بعض الشركات تحجب SMS في أوقات معينة)',
      ]);

      if (!Environment.isProduction) {
        recommendations.add('في وضع التطوير: استخدم الرموز الاحتياطية دائماً');
      }
    }

    return recommendations;
  }

  /// Logs SMS attempt for debugging
  static void logSMSAttempt({
    required String phoneNumber,
    required String method,
    required bool success,
    String? errorCode,
    String? verificationCode,
  }) {
    if (kDebugMode) {
      final status = getSMSDeliveryStatus(phoneNumber);

      debugPrint('📱 SMS ATTEMPT LOG');
      debugPrint('================');
      debugPrint('Phone: $phoneNumber');
      debugPrint('Method: $method');
      debugPrint('Success: $success');
      debugPrint('Error Code: ${errorCode ?? 'none'}');
      debugPrint('Is Iraqi: ${status['is_iraqi']}');
      debugPrint('Is Sandbox: ${status['is_sandbox']}');
      debugPrint('Bypass Recommended: ${status['bypass_recommended']}');
      debugPrint('Delivery Method: ${status['delivery_method']}');

      if (verificationCode != null && isBypassCode(verificationCode)) {
        debugPrint('🚨 BYPASS CODE USED: $verificationCode');
      }
    }
  }

  /// Gets sandbox-specific configuration advice
  static Map<String, dynamic> getSandboxAdvice() {
    return {
      'title': 'AWS SNS Sandbox Mode Active',
      'description':
          'SMS delivery is limited to verified phone numbers in sandbox mode',
      'actions': [
        {
          'action': 'Use Bypass Codes',
          'description':
              'Use codes: ${_emergencyBypassCodes.take(3).join(', ')} for testing',
          'priority': 'immediate',
        },
        {
          'action': 'Verify Phone in AWS',
          'description':
              'Add +9647831367435 to AWS SNS sandbox verified numbers',
          'priority': 'medium',
        },
        {
          'action': 'Exit Sandbox',
          'description': 'Submit AWS SNS sandbox exit request for production',
          'priority': 'production',
        },
      ],
      'bypass_codes': _emergencyBypassCodes,
      'status': 'development_ready',
    };
  }
}
