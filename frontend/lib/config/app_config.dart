import 'package:shared_preferences/shared_preferences.dart';
import 'environment.dart';
import 'package:flutter/foundation.dart';

class AppConfig {
  // Environment configuration
  static const String _environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'staging',
  );

  // Preference keys
  static const String _keyUseMockData = 'use_mock_data';
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyLanguage = 'app_language';
  static const String _keyForceProduction = 'force_production_mode';
  static const String _keyEnableAWS = 'enable_aws_integration';

  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    // Default to AWS integration enabled for production mode
    _prefs!.setBool(_keyEnableAWS, _prefs!.getBool(_keyEnableAWS) ?? true);
    // Mock data disabled by default when AWS is enabled
    _prefs!.setBool(_keyUseMockData, _prefs!.getBool(_keyUseMockData) ?? false);
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception(
        'AppConfig not initialized. Call AppConfig.initialize() first.',
      );
    }
    return _prefs!;
  }

  static String get environment => _environment;
  static bool get isDevelopment => _environment == 'development';
  static bool get isProduction => _environment == 'production';
  static bool get isDebugMode => kDebugMode || isDevelopment;

  // Compatibility: allow callers to set a force production mode flag
  static bool get forceProductionMode =>
      prefs.getBool(_keyForceProduction) ?? false;
  static Future<void> setForceProductionMode(bool value) async =>
      prefs.setBool(_keyForceProduction, value);

  // AWS Integration toggle
  static bool get enableAWSIntegration => prefs.getBool(_keyEnableAWS) ?? true;
  static Future<void> setAWSIntegration(bool enabled) async {
    await prefs.setBool(_keyEnableAWS, enabled);
    // When AWS is enabled, disable mock data and vice versa
    await setUseMockData(!enabled);
  }

  // AWS Configuration
  static Map<String, String> get awsConfig => enableAWSIntegration
      ? {
          'mode': 'AWS Cognito',
          'region': Environment.awsRegion,
          'userPoolId': Environment.cognitoUserPoolId,
          'clientId': Environment.cognitoAppClientId,
          'websocketUrl': Environment.webSocketUrl,
        }
      : {
          'mode': 'offline',
          'region': '',
          'userPoolId': '',
          'clientId': '',
          'websocketUrl': '',
        };

  // Mock data flag - opposite of AWS integration
  static bool get enableMockData => prefs.getBool(_keyUseMockData) ?? false;
  static bool get useMockData => enableMockData; // compatibility alias
  static Future<void> setUseMockData(bool enabled) async {
    await prefs.setBool(_keyUseMockData, enabled);
    // When mock data is enabled, disable AWS and vice versa
    await prefs.setBool(_keyEnableAWS, !enabled);
  }

  // Backend URL
  static String get backendBaseUrl =>
      enableAWSIntegration ? Environment.apiBaseUrl : 'http://localhost:0';

  static void printConfig() {
    debugPrint('=== App Configuration ===');
    debugPrint('Environment: $_environment');
    debugPrint('AWS Integration: $enableAWSIntegration');
    debugPrint('Mock Data: $enableMockData');
    debugPrint('Backend URL: $backendBaseUrl');
    debugPrint('User Pool: ${Environment.cognitoUserPoolId}');
    debugPrint('========================');
  }

  // Language
  static String get language => prefs.getString(_keyLanguage) ?? 'ar';
  static Future<void> setLanguage(String language) async =>
      prefs.setString(_keyLanguage, language);

  // Onboarding
  static bool get onboardingCompleted =>
      prefs.getBool(_keyOnboardingCompleted) ?? false;
  static Future<void> setOnboardingCompleted(bool completed) async =>
      prefs.setBool(_keyOnboardingCompleted, completed);

  // Debug info
  static Map<String, dynamic> getDebugInfo() {
    return {
      'environment': environment,
      'mock_data': enableMockData,
      'onboarding_completed': onboardingCompleted,
      'language': language,
    };
  }
}
