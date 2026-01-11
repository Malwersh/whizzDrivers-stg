import '../config/sms_config.dart';

/// Service to handle WIZZAPP SMS verification for Iraqi phone numbers
class WizzappSMSService {
  static const String _awsRegion = SMSConfig.region;
  static const String _senderId = SMSConfig.senderId;

  /// Sends SMS verification code using WIZZAPP sender ID
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

      // Format the verification message
      final message = SMSConfig.formatVerificationMessage(verificationCode);

      // Prepare the SMS payload
      final payload = {
        'Action': 'Publish',
        'PhoneNumber': normalizedPhone,
        'Message': message,
        'MessageAttributes.1.Name': 'AWS.SNS.SMS.SenderID',
        'MessageAttributes.1.Value.StringValue': _senderId,
        'MessageAttributes.1.Value.DataType': 'String',
        'MessageAttributes.2.Name': 'AWS.SNS.SMS.SMSType',
        'MessageAttributes.2.Value.StringValue': 'Transactional',
        'MessageAttributes.2.Value.DataType': 'String',
        'Version': '2010-03-31',
      };

      print('🔧 SMS Debug: Attempting to send SMS via WIZZAPP');
      print('📱 Phone: $normalizedPhone');
      print('📤 Sender ID: $_senderId');
      print('💬 Message: $message');

      // Note: In a real implementation, you would use AWS SDK with proper credentials
      // For now, we'll simulate the SMS sending process

      // Simulate successful SMS send for development
      await Future.delayed(const Duration(milliseconds: 500));

      return {
        'success': true,
        'messageId': 'sim-${DateTime.now().millisecondsSinceEpoch}',
        'phone': normalizedPhone,
        'senderId': _senderId,
        'message': 'تم إرسال رمز التحقق عبر الرسائل النصية',
      };
    } catch (e) {
      print('❌ SMS Error: $e');
      return {
        'success': false,
        'error': 'فشل في إرسال الرسالة النصية',
        'errorCode': 'SMS_SEND_FAILED',
        'details': e.toString(),
      };
    }
  }

  /// Validates SMS verification code format
  static bool isValidVerificationCode(String code) {
    // Verification codes are typically 6 digits
    return RegExp(r'^\d{6}$').hasMatch(code);
  }

  /// Gets SMS sending status for Iraqi numbers
  static Map<String, dynamic> getSMSCapabilityStatus() {
    return {
      'smsEnabled': SMSConfig.smsVerificationEnabled,
      'senderId': _senderId,
      'country': SMSConfig.country,
      'region': _awsRegion,
      'iraqiNumbersSupported': true,
      'senderIdArn': SMSConfig.senderIdArn,
    };
  }

  /// Determines if SMS should be used for a given phone number
  static bool shouldUseSMS(String phoneNumber) {
    return SMSConfig.isIraqiPhoneNumber(phoneNumber) &&
        SMSConfig.smsVerificationEnabled;
  }

  /// Gets user-friendly message about SMS verification status
  static String getSMSStatusMessage(String phoneNumber) {
    if (shouldUseSMS(phoneNumber)) {
      return 'سيتم إرسال رمز التحقق عبر الرسائل النصية من WIZZAPP';
    } else if (SMSConfig.isIraqiPhoneNumber(phoneNumber)) {
      return 'الرسائل النصية غير متاحة حالياً، سيتم استخدام البريد الإلكتروني';
    } else {
      return 'يجب استخدام رقم هاتف عراقي للتحقق عبر الرسائل النصية';
    }
  }
}
