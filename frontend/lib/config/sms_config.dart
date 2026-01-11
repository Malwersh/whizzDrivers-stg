/// SMS Configuration for Hadhir with Dedicated Phone Number
///
/// This configuration handles SMS verification settings for Iraqi phone numbers
/// using AWS End User Messaging with dedicated phone number +14255552152.
class SMSConfig {
  // Dedicated phone number configuration - UPDATED TO WORKING NUMBER
  static const String dedicatedPhoneNumber = '+14255552152';
  static const String senderId =
      'WHIZZDRIVER'; // Updated to match AWS Sender ID for Iraq
  static const String senderIdArn =
      'arn:aws:sms-voice:us-east-1:031857856164:sender-id/WHIZZDRIVER/IQ';
  static const String country = 'IQ';
  static const String region = 'us-east-1';

  // Working phone pool configuration (with phone number + sender ID)
  static const String phonePoolId = 'pool-a2a21dfe3b5d4506961fca46cb4a8bdf';
  static const String phonePoolArn =
      'arn:aws:sms-voice:us-east-1:031857856164:pool/pool-a2a21dfe3b5d4506961fca46cb4a8bdf';
  static const String phoneNumberId = 'phone-c8315deb34c643b7925b0b2d0669c729';
  static const String phoneArn =
      'arn:aws:sms-voice:us-east-1:031857856164:phone-number/phone-c8315deb34c643b7925b0b2d0669c729';
  


  // SMS verification settings 
  static const bool smsVerificationEnabled = true;
  static const bool emailVerificationEnabled = true;
  static const bool smsPreferredForIraqiNumbers = true;
  static const bool useEndUserMessaging = true; // New: Use dedicated number
  static const bool usePhoneNumberDirectly =
      true; // Bypass pool issue - use phone number directly

  // Iraqi phone number validation - Fixed pattern for Iraqi mobile prefixes
  // Supports: 077X, 078X, 079X with 8 digits, 75X with 8 digits (corrected)
  static const String iraqiPhonePattern =
      r'^(\+964|964|0)?(77[0-9]{8}|78[0-9]{8}|79[0-9]{8}|75[0-9]{8})$';

  // Verification message templates
  static const String verificationMessageTemplate =
      'رمز التحقق الخاص بك من هاضر: {code}\nمن WHIZZDRIVER (+14255552152)\nلا تشارك هذا الرمز مع أحد.';
  static const String appName = 'هاضر درايفر';

  /// Validates if a phone number is Iraqi format
  static bool isIraqiPhoneNumber(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    
    // Debug logging
    print('🔍 SMSConfig.isIraqiPhoneNumber: "$phone" -> "$cleanPhone"');
    print('🔍 Pattern: $iraqiPhonePattern');

    final isValid = RegExp(iraqiPhonePattern).hasMatch(cleanPhone);
    print('🔍 Is valid: $isValid');

    return isValid;
  }

  /// Normalizes Iraqi phone number to international format
  static String normalizeIraqiPhone(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    
    // Debug logging
    print('🔍 SMSConfig.normalizeIraqiPhone: "$phone" -> "$cleanPhone"');

    String normalized;
    if (cleanPhone.startsWith('+964')) {
      normalized = cleanPhone;
    } else if (cleanPhone.startsWith('964')) {
      normalized = '+$cleanPhone';
    } else if (cleanPhone.startsWith('07')) {
      normalized = '+964${cleanPhone.substring(1)}';
    } else if (cleanPhone.startsWith('7')) {
      normalized = '+964$cleanPhone';
    } else {
      normalized = cleanPhone;
    }
    
    print('🔍 Normalized result: "$normalized"');
    return normalized;
  }

  /// Gets the preferred verification method for a given phone number
  static String getPreferredVerificationMethod(String phone) {
    if (isIraqiPhoneNumber(phone) && smsVerificationEnabled) {
      return 'sms';
    }
    return 'email';
  }

  /// Formats verification message with code
  static String formatVerificationMessage(String code) {
    return verificationMessageTemplate.replaceAll('{code}', code);
  }
}
