import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/sms_config.dart';
import 'firebase_phone_auth_service.dart';
import 'google_sms_service.dart';
import 'wizzapp_sms_service.dart';

/// Unified SMS Service that intelligently chooses the best SMS provider
/// Priority: Google SMS > Firebase > AWS (Wizzapp)
class UnifiedSMSService {
  static const Map<String, int> _providerPriority = {
    'google': 1,
    'firebase': 2,
    'aws': 3,
  };

  static final Map<String, String> _verificationCodes = {};
  static final Map<String, DateTime> _codeTimestamps = {};
  static final Map<String, int> _failureCount = {};

  /// Send SMS verification code using the best available provider
  static Future<Map<String, dynamic>> sendVerificationSMS({
    required String phoneNumber,
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

      // Generate verification code
      final verificationCode = _generateVerificationCode();

      // Store the code for verification
      _verificationCodes[normalizedPhone] = verificationCode;
      _codeTimestamps[normalizedPhone] = DateTime.now();

      debugPrint('🚀 Unified SMS: Sending verification to $normalizedPhone');
      debugPrint('🔐 Generated code: $verificationCode');

      // Try providers in order of priority
      final providers = await _getAvailableProviders();
      Map<String, dynamic>? lastResult;

      for (final provider in providers) {
        debugPrint('📡 Trying provider: $provider');

        final result = await _sendWithProvider(
          provider: provider,
          phoneNumber: normalizedPhone,
          verificationCode: verificationCode,
        );

        if (result['success'] == true) {
          _resetFailureCount(provider);
          return {
            ...result,
            'provider_used': provider,
            'verification_id': _generateVerificationId(normalizedPhone),
            'code_expires_at': DateTime.now()
                .add(const Duration(minutes: 10))
                .toIso8601String(),
          };
        }

        lastResult = result;
        _incrementFailureCount(provider);
        debugPrint('❌ Provider $provider failed: ${result['error']}');
      }

      // All providers failed
      return lastResult ??
          {
            'success': false,
            'error': 'جميع خدمات الرسائل النصية غير متاحة حالياً',
            'errorCode': 'ALL_PROVIDERS_FAILED',
          };
    } catch (e) {
      debugPrint('❌ Unified SMS Exception: $e');
      return {
        'success': false,
        'error': 'حدث خطأ في إرسال الرسالة النصية',
        'errorCode': 'SMS_SERVICE_ERROR',
        'details': e.toString(),
      };
    }
  }

  /// Verify SMS code
  static Future<Map<String, dynamic>> verifyCode({
    required String phoneNumber,
    required String verificationCode,
    String? verificationId,
  }) async {
    try {
      final normalizedPhone = SMSConfig.normalizeIraqiPhone(phoneNumber);

      // Check if code exists and is not expired
      final storedCode = _verificationCodes[normalizedPhone];
      final codeTimestamp = _codeTimestamps[normalizedPhone];

      if (storedCode == null || codeTimestamp == null) {
        return {
          'success': false,
          'verified': false,
          'error': 'لم يتم العثور على رمز التحقق. يرجى طلب رمز جديد',
          'errorCode': 'CODE_NOT_FOUND',
        };
      }

      // Check if code expired (10 minutes)
      final now = DateTime.now();
      if (now.difference(codeTimestamp).inMinutes > 10) {
        _clearCode(normalizedPhone);
        return {
          'success': false,
          'verified': false,
          'error': 'انتهت صلاحية رمز التحقق. يرجى طلب رمز جديد',
          'errorCode': 'CODE_EXPIRED',
        };
      }

      // Verify the code
      if (storedCode == verificationCode) {
        _clearCode(normalizedPhone);
        return {
          'success': true,
          'verified': true,
          'phone': normalizedPhone,
          'message': 'تم التحقق من رقم الهاتف بنجاح',
          'provider': 'unified_sms_service',
        };
      } else {
        return {
          'success': false,
          'verified': false,
          'error': 'رمز التحقق غير صحيح',
          'errorCode': 'INVALID_CODE',
        };
      }
    } catch (e) {
      debugPrint('❌ Code verification error: $e');
      return {
        'success': false,
        'verified': false,
        'error': 'حدث خطأ في التحقق من الرمز',
        'errorCode': 'VERIFICATION_ERROR',
        'details': e.toString(),
      };
    }
  }

  /// Resend verification code
  static Future<Map<String, dynamic>> resendVerificationCode({
    required String phoneNumber,
  }) async {
    // Clear existing code first
    final normalizedPhone = SMSConfig.normalizeIraqiPhone(phoneNumber);
    _clearCode(normalizedPhone);

    // Send new code
    return sendVerificationSMS(phoneNumber: phoneNumber);
  }

  /// Send SMS with specific provider
  static Future<Map<String, dynamic>> _sendWithProvider({
    required String provider,
    required String phoneNumber,
    required String verificationCode,
  }) async {
    switch (provider) {
      case 'google':
        return await GoogleSMSService.sendVerificationSMS(
          phoneNumber: phoneNumber,
          verificationCode: verificationCode,
        );

      case 'firebase':
        return await FirebasePhoneAuthService.sendVerificationSMS(
          phoneNumber: phoneNumber,
        );

      case 'aws':
        return await WizzappSMSService.sendVerificationSMS(
          phoneNumber: phoneNumber,
          verificationCode: verificationCode,
        );

      default:
        return {
          'success': false,
          'error': 'مقدم خدمة غير معروف',
          'errorCode': 'UNKNOWN_PROVIDER',
        };
    }
  }

  /// Get available providers sorted by priority and reliability
  static Future<List<String>> _getAvailableProviders() async {
    final List<MapEntry<String, int>> providers = [];

    // Check Google SMS Service
    final googleStatus = GoogleSMSService.getServiceStatus();
    if (googleStatus['cloudFunctionConfigured'] == true ||
        googleStatus['twilioConfigured'] == true) {
      final priority =
          _providerPriority['google']! + _getFailurePenalty('google');
      providers.add(MapEntry('google', priority));
    }

    // Check Firebase Phone Auth
    if (FirebasePhoneAuthService.isConfigured()) {
      final priority =
          _providerPriority['firebase']! + _getFailurePenalty('firebase');
      providers.add(MapEntry('firebase', priority));
    }

    // AWS is always available (fallback)
    final priority = _providerPriority['aws']! + _getFailurePenalty('aws');
    providers.add(MapEntry('aws', priority));

    // Sort by priority (lower number = higher priority)
    providers.sort((a, b) => a.value.compareTo(b.value));

    return providers.map((e) => e.key).toList();
  }

  /// Generate secure verification code
  static String _generateVerificationCode() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Generate verification ID for tracking
  static String _generateVerificationId(String phone) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = phone.hashCode.abs();
    return 'verify_${hash}_$timestamp';
  }

  /// Clear verification code for phone number
  static void _clearCode(String phoneNumber) {
    _verificationCodes.remove(phoneNumber);
    _codeTimestamps.remove(phoneNumber);
  }

  /// Track provider failures for smart routing
  static void _incrementFailureCount(String provider) {
    _failureCount[provider] = (_failureCount[provider] ?? 0) + 1;
  }

  /// Reset failure count on success
  static void _resetFailureCount(String provider) {
    _failureCount[provider] = 0;
  }

  /// Get failure penalty for provider prioritization
  static int _getFailurePenalty(String provider) {
    final failures = _failureCount[provider] ?? 0;
    return failures * 2; // Each failure adds 2 to priority (lower priority)
  }

  /// Get service status
  static Map<String, dynamic> getServiceStatus() {
    return {
      'unified_sms_service': true,
      'available_providers': _getAvailableProviders(),
      'failure_counts': Map.from(_failureCount),
      'active_verifications': _verificationCodes.length,
      'supported_countries': ['Iraq'],
      'features': [
        'multi_provider_fallback',
        'intelligent_routing',
        'failure_tracking',
        'automatic_retry',
        'cost_optimization',
      ],
    };
  }

  /// Test all available SMS providers
  static Future<Map<String, dynamic>> testAllProviders() async {
    final results = <String, dynamic>{};

    // Test Google SMS Service
    final googleTest = await GoogleSMSService.testService();
    results['google'] = googleTest;

    // Test Firebase (configuration check)
    results['firebase'] = {
      'configured': FirebasePhoneAuthService.isConfigured(),
      'status': FirebasePhoneAuthService.getServiceStatus(),
    };

    // Test AWS (always available but may have delivery issues)
    results['aws'] = WizzappSMSService.getSMSCapabilityStatus();

    return {
      'success': true,
      'provider_tests': results,
      'recommended_provider': (await _getAvailableProviders()).first,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Clear all verification codes (for testing/cleanup)
  static void clearAllCodes() {
    _verificationCodes.clear();
    _codeTimestamps.clear();
    _failureCount.clear();
  }
}
