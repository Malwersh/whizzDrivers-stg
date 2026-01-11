/// SMS Service Configuration
/// This file contains configuration for various SMS providers
class SMSServiceConfig {
  // Firebase Phone Auth Configuration
  static const String firebaseProjectId = 'hadhirfb25';
  static const String firebaseWebApiKey = String.fromEnvironment('FIREBASE_API_KEY', 
      defaultValue: 'YOUR_FIREBASE_API_KEY_HERE');
  static const String firebaseAppId =
      '1:155226741183:web:c1b5e98ee28ce96d69a90a'; // ✅ Web App ID configured

  // Twilio Configuration
  static const String twilioAccountSid =
      'AC_REPLACE_WITH_YOUR_TWILIO_ACCOUNT_SID';
  static const String twilioAuthToken = 'YOUR_TWILIO_AUTH_TOKEN';
  static const String twilioPhoneNumber =
      '+1234567890'; // Your Twilio phone number

  // Google Cloud Function Configuration
  static const String cloudFunctionUrl =
      'https://us-central1-hadhir-sms.cloudfunctions.net/sendSMS';
  static const String cloudFunctionApiKey = 'YOUR_CLOUD_FUNCTION_API_KEY';

  // SMS Service Priority (Firebase only - production ready)
  static const Map<String, int> providerPriority = {
    'firebase': 1, // Primary and only SMS provider
    'google_cloud_function': 2, // Optional backup if implemented
    'twilio': 3, // Optional backup if implemented
  };

  // Configuration validation
  static bool get isFirebaseConfigured {
    return firebaseWebApiKey !=
            'AIzaSyC_REPLACE_WITH_YOUR_FIREBASE_WEB_API_KEY' &&
        firebaseProjectId != 'hadhir-firebase-project';
  }

  static bool get isTwilioConfigured {
    return twilioAccountSid != 'AC_REPLACE_WITH_YOUR_TWILIO_ACCOUNT_SID' &&
        twilioAuthToken != 'YOUR_TWILIO_AUTH_TOKEN';
  }

  static bool get isCloudFunctionConfigured {
    return cloudFunctionUrl !=
            'https://us-central1-hadhir-sms.cloudfunctions.net/sendSMS' &&
        cloudFunctionApiKey != 'YOUR_CLOUD_FUNCTION_API_KEY';
  }

  // Get available providers (Firebase only for production)
  static List<String> get availableProviders {
    final providers = <String>[];

    // Firebase is the primary and required SMS provider
    if (isFirebaseConfigured) providers.add('firebase');

    // Optional additional providers (if configured)
    if (isCloudFunctionConfigured) providers.add('google_cloud_function');
    if (isTwilioConfigured) providers.add('twilio');

    return providers;
  }

  // Service status report
  static Map<String, dynamic> getServiceStatus() {
    return {
      'firebase_configured': isFirebaseConfigured,
      'twilio_configured': isTwilioConfigured,
      'cloud_function_configured': isCloudFunctionConfigured,
      'available_providers': availableProviders,
      'recommended_provider': availableProviders.isNotEmpty
          ? availableProviders.first
          : 'firebase',
      'total_providers': availableProviders.length,
    };
  }
}
