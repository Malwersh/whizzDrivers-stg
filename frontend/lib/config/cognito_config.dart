// Cognito Configuration for WhizzDrivers User Pool
// Based on AWS Cognito settings: SMS verification enabled via WIZZAPP

class CognitoConfig {
  // User Pool Configuration (from your AWS settings)
  // ✅ CORRECTED: Using hadhir-phone-only-pool for drivers
  static const String userPoolId = 'us-east-1_Mnrmklxro';
  static const String region = 'us-east-1';
  static const String accountId = '031857856164';

  // Verification settings based on your Cognito configuration
  static const bool smsVerificationEnabled = true;
  static const bool emailVerificationEnabled = true;
  static const bool keepOriginalAttributeWhenUpdatePending = true;

  // SMS Configuration with WIZZAPP
  static const bool sendSmsForPhoneVerification = true;
  static const bool sendEmailForEmailVerification = true;
  static const String senderId = 'WIZZAPP';
  static const String senderIdArn =
      'arn:aws:sms-voice:us-east-1:031857856164:sender-id/WIZZAPP/IQ';

  // Fallback strategy: "Send SMS message if phone number is available, otherwise send email message"
  static const String verificationStrategy = 'sms_first_email_fallback';

  // Active attributes when update is pending
  static const List<String> activeAttributesWhenUpdatePending = [
    'phone_number',
    'email',
  ];

  // Verification flow configuration
  static const Map<String, dynamic> verificationConfig = {
    'primary_verification': 'phone_number', // SMS first
    'fallback_verification': 'email', // Email fallback
    'auto_verify_phone': true,
    'auto_verify_email': true,
    'require_confirmation': true,
    'keep_original_on_update': true,
  };

  // Iraqi phone number configuration
  static const String iraqiCountryCode = '+964';
  static const List<String> iraqiMobileCarriers = [
    'Zain Iraq',
    'Asia Cell',
    'Korek Telecom',
    'WizzApp', // Your SMS service
  ];

  // SMS delivery configuration
  static const Map<String, dynamic> smsConfig = {
    'max_retry_attempts': 3,
    'retry_delay_seconds': 30,
    'fallback_to_email_after_retries': true,
    'use_wizzapp_for_iraqi_numbers': true,
  };

  // Verification code configuration
  static const int verificationCodeLength = 6;
  static const int verificationCodeExpiryMinutes = 5;
  static const int maxVerificationAttempts = 3;

  // Helper methods
  static bool shouldUseSmsVerification(String phoneNumber) {
    return smsVerificationEnabled && phoneNumber.startsWith(iraqiCountryCode);
  }

  static bool shouldUseEmailVerification(String email) {
    return emailVerificationEnabled && email.isNotEmpty && email.contains('@');
  }

  static String getVerificationMethod(String? phoneNumber, String? email) {
    if (phoneNumber != null && shouldUseSmsVerification(phoneNumber)) {
      return 'sms';
    }
    if (email != null && shouldUseEmailVerification(email)) {
      return 'email';
    }
    return 'email'; // Default fallback
  }
}
