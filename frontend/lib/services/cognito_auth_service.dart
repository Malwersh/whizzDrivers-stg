import 'dart:async';
import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/logging/auth_logger.dart';
import '../services/driver_service.dart';

/// AWS Cognito authentication service for user registration and login
class CognitoAuthService {
  static String? _authToken;
  static String? get authToken => _authToken;
  AuthLogger? logger;

  // Cache for last known profile status (to be used by router guards)
  static String? _lastKnownProfileStatus;
  static String? get lastKnownProfileStatus => _lastKnownProfileStatus;
  
  /// Update the cached profile status (used by router guards)
  static Future<void> updateLastKnownProfileStatus(String? status) async {
    await _setLastKnownProfileStatus(status);
  }
  
  static Future<void> _setLastKnownProfileStatus(String? status) async {
    _lastKnownProfileStatus = status;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (status != null) {
        await prefs.setString('driver_profile_status', status);
      } else {
        await prefs.remove('driver_profile_status');
      }
    } catch (_) {}
  }

  Future<void> initialize() async {
    debugPrint('🔐 CognitoAuthService: Initializing...');
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('cognito_auth_token');
    // Load cached profile status if present
    _lastKnownProfileStatus = prefs.getString('driver_profile_status');

    debugPrint(
      '🔐 CognitoAuthService: Token loaded: ${_authToken != null ? 'YES' : 'NO'}',
    );
    debugPrint(
      '🔐 CognitoAuthService: Profile status: $_lastKnownProfileStatus',
    );

    // CRITICAL: Validate the session against Amplify, not just check if token exists
    try {
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      if (session.isSignedIn) {
        debugPrint('🔐 CognitoAuthService: Valid session found');
      } else {
        debugPrint('🔐 CognitoAuthService: No valid session, clearing cache');
        _authToken = null;
        _lastKnownProfileStatus = null;
        await prefs.remove('cognito_auth_token');
        await prefs.remove('driver_profile_status');
      }
    } catch (e) {
      // If we can't validate session, clear cached data to force re-authentication
      debugPrint('❌ CognitoAuthService: Session validation failed: $e');
      debugPrint('🧹 CognitoAuthService: Clearing cached auth data');
      _authToken = null;
      _lastKnownProfileStatus = null;
      await prefs.remove('cognito_auth_token');
      await prefs.remove('driver_profile_status');
    }

    debugPrint(
      '🔐 CognitoAuthService: Initialize complete. isAuthenticated=$isAuthenticated',
    );
  }

  Future<void> _saveToken(String token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cognito_auth_token', token);
  }

  Future<void> _clearToken() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cognito_auth_token');
  }

  bool get isAuthenticated => _authToken != null;

  /// Enhanced login methods with driver profile fetching and multi-strategy support
  Future<Map<String, dynamic>> loginWithEmailDetailed({
    required String email,
    required String password,
  }) async {
    logger?.logLoginAttempt(identity: email, channel: 'email');
    final result = await (() async {
      try {
        debugPrint('🔐 Attempting email login: $email');

        // Check if a user is already signed in, and sign them out first
        try {
          final currentSession = await Amplify.Auth.fetchAuthSession();
          if (currentSession.isSignedIn) {
            debugPrint('⚠️ User already signed in, signing out first...');
            await Amplify.Auth.signOut();
            await _clearToken();
            debugPrint('✅ Previous user signed out');
          }
        } catch (e) {
          debugPrint('⚠️ Error checking current session: $e');
        }

        // Strategy 1: Try direct email login (for compatibility)
        try {
          debugPrint('🔐 Strategy 1: Trying direct email login...');
          final result = await Amplify.Auth.signIn(
            username: email,
            password: password,
          );

          if (result.isSignedIn) {
            debugPrint('✅ Direct email login successful');
            final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
            if (session.isSignedIn) {
              final tokens = session.userPoolTokensResult.value;
              await _saveToken(tokens.accessToken.raw);

              // Fetch and save driver profile
              final profileData = await _fetchDriverProfileFromBackend();
              if (profileData != null) {
                await _saveDriverCredentials(
                  driverId: profileData['driverId'] ?? email,
                  accessToken: tokens.accessToken.raw,
                  profile: profileData,
                );
                await _setLastKnownProfileStatus(profileData['status'] as String?);
              }

              return {
                'success': true,
                'message': 'تم تسجيل الدخول بنجاح',
                'profile': profileData,
              };
            }
          }
        } on AuthException catch (e) {
          debugPrint('⚠️ Direct email login failed: ${e.message}');
          
          // Strategy 2: Try with generated phone from email hash
          try {
            final generatedPhone = _generatePhoneFromEmail(email);
            debugPrint('🔐 Strategy 2: Trying generated phone: $generatedPhone');

            final result = await Amplify.Auth.signIn(
              username: generatedPhone,
              password: password,
            );

            if (result.isSignedIn) {
              debugPrint('✅ Generated phone login successful');
              final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
              if (session.isSignedIn) {
                final tokens = session.userPoolTokensResult.value;
                await _saveToken(tokens.accessToken.raw);

                // Fetch and save driver profile
                final profileData = await _fetchDriverProfileFromBackend();
                if (profileData != null) {
                  await _saveDriverCredentials(
                    driverId: profileData['driverId'] ?? email,
                    accessToken: tokens.accessToken.raw,
                    profile: profileData,
                  );
                  await _setLastKnownProfileStatus(profileData['status'] as String?);
                }

                return {
                  'success': true,
                  'message': 'تم تسجيل الدخول بنجاح',
                  'profile': profileData,
                };
              }
            }
          } on AuthException catch (phoneError) {
            debugPrint('⚠️ Generated phone login failed: ${phoneError.message}');
            
            // Return the original email error, not the phone error
            return {
              'success': false,
              'message': _getArabicErrorMessage(e),
              'error': e.message,
              'error_code': e.underlyingException?.toString(),
            };
          }
        }

        return {
          'success': false,
          'message': 'مطلوب خطوة إضافية لإكمال تسجيل الدخول',
        };
      } catch (e) {
        debugPrint('❌ Email login error: $e');
        return {
          'success': false,
          'message': 'حدث خطأ غير متوقع',
          'error': e.toString(),
        };
      }
    })();

    logger?.logLoginResult(
      identity: email,
      channel: 'email',
      success: result['success'] == true,
      failureReason: result['success'] == true ? null : 'invalid_credentials',
    );
    return result;
  }

  /// Generate phone number from email hash (same algorithm as registration)
  String _generatePhoneFromEmail(String email) {
    final emailHash = email.hashCode.abs();
    final phoneNumber = '+964${emailHash.toString().padLeft(10, '0').substring(0, 10)}';
    return phoneNumber;
  }

  Future<Map<String, dynamic>> loginWithPhoneDetailed({
    required String phone,
    required String password,
  }) async {
    logger?.logLoginAttempt(identity: phone, channel: 'phone');

    try {
      final formattedPhone = _formatPhoneNumber(phone);
      final result = await Amplify.Auth.signIn(
        username: formattedPhone,
        password: password,
      );

      if (result.isSignedIn) {
        final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
        if (session.isSignedIn) {
          final tokens = session.userPoolTokensResult.value;
          await _saveToken(tokens.accessToken.raw);

          // Fetch and save driver profile
          final profileData = await _fetchDriverProfileFromBackend();
          if (profileData != null) {
            await _saveDriverCredentials(
              driverId: profileData['driverId'] ?? formattedPhone,
              accessToken: tokens.accessToken.raw,
              profile: profileData,
            );
            await _setLastKnownProfileStatus(profileData['status'] as String?);
          }

          logger?.logLoginResult(
            identity: phone,
            channel: 'phone',
            success: true,
          );

          return {
            'success': true,
            'message': 'تم تسجيل الدخول بنجاح',
            'profile': profileData,
          };
        }
      }

      logger?.logLoginResult(
        identity: phone,
        channel: 'phone',
        success: false,
        failureReason: 'auth_failed',
      );

      return {
        'success': false,
        'message': 'فشل في تسجيل الدخول',
      };
    } on AuthException catch (e) {
      logger?.logLoginResult(
        identity: phone,
        channel: 'phone',
        success: false,
        failureReason: e.runtimeType.toString(),
      );

      return {
        'success': false,
        'message': _getArabicErrorMessage(e),
        'error': e.message,
      };
    } catch (e) {
      logger?.logLoginResult(
        identity: phone,
        channel: 'phone',
        success: false,
        failureReason: 'exception',
      );

      return {
        'success': false,
        'message': 'حدث خطأ غير متوقع: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  /// Fetch driver profile from backend using DriverService
  Future<Map<String, dynamic>?> _fetchDriverProfileFromBackend() async {
    try {
      debugPrint('🔐 FETCH_PROFILE: Starting profile fetch from backend');

      // Use DriverService to get profile
      final profileResult = await DriverService.getDriverProfile();
      
      if (profileResult != null) {
        debugPrint('🔐 FETCH_PROFILE: Profile fetched successfully');
        debugPrint('🔐 FETCH_PROFILE: Profile status: ${profileResult.status}');

        // Convert DriverProfile to Map for compatibility
        return {
          'driverId': profileResult.id,
          'name': profileResult.name,
          'email': profileResult.email,
          'phone': profileResult.phone,
          'city': profileResult.city,
          'vehicleType': profileResult.vehicleType,
          'licenseNumber': profileResult.licenseNumber,
          'nationalId': profileResult.nationalId,
          'status': profileResult.status,
        };
      } else {
        debugPrint('🔐 FETCH_PROFILE: No profile found');
        return null;
      }
    } catch (e) {
      debugPrint('🔐 FETCH_PROFILE: Error fetching profile: $e');
      return null;
    }
  }

  /// Comprehensive sign out with cleanup
  Future<void> signOut() async {
    debugPrint('🔐 SIGNOUT: Starting comprehensive sign out');

    try {
      // Sign out from Amplify/Cognito
      await Amplify.Auth.signOut();
      debugPrint('🔐 SIGNOUT: Amplify sign out successful');
    } catch (e) {
      debugPrint('🔐 SIGNOUT: Amplify sign out error: $e');
    }

    // Clear all local storage
    await _clearAllAuthData();

    debugPrint('🔐 SIGNOUT: Complete');
  }

  /// Force clean all auth data (for debugging/testing)
  Future<void> forceCleanAuthData() async {
    debugPrint('🧹 FORCE_CLEAN: Starting comprehensive data cleanup');

    try {
      // Try to sign out from Amplify first
      await Amplify.Auth.signOut();
    } catch (e) {
      debugPrint('🧹 FORCE_CLEAN: Amplify sign out error (continuing): $e');
    }

    // Clear all local storage
    await _clearAllAuthData();

    debugPrint('🧹 FORCE_CLEAN: Complete');
  }

  Future<void> _clearAllAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear authentication tokens
      _authToken = null;
      await prefs.remove('cognito_auth_token');
      await prefs.remove('access_token');
      
      // Clear profile and session data
      _lastKnownProfileStatus = null;
      await prefs.remove('driver_profile_status');
      await prefs.remove('driver_id');
      await prefs.remove('driver_profile');
      await prefs.remove('isAuthenticated');
      
      // Clear pending registration data
      await prefs.remove('pending_driver_registration');
      
      debugPrint('🧹 AUTH_DATA: All local auth data cleared');
    } catch (e) {
      debugPrint('🧹 AUTH_DATA: Error clearing local data: $e');
    }
  }

  /// Save driver credentials to SharedPreferences
  Future<void> _saveDriverCredentials({
    required String driverId,
    required String accessToken,
    required Map<String, dynamic> profile,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('driver_id', driverId);
      await prefs.setString('access_token', accessToken);
      await prefs.setString('driver_profile', jsonEncode(profile));
      await prefs.setBool('isAuthenticated', true);
      
      debugPrint('🔐 CREDENTIALS: Driver credentials saved successfully');
    } catch (e) {
      debugPrint('🔐 CREDENTIALS: Error saving driver credentials: $e');
      rethrow;
    }
  }

  /// Helper methods
  String _formatPhoneNumber(String phone) {
    if (phone.isEmpty) return phone;

    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleanPhone.startsWith('+964')) {
      String withoutPlus = cleanPhone.substring(1);
      if (withoutPlus.length == 12 && withoutPlus.substring(3).startsWith('7')) {
        return cleanPhone;
      }
    }

    if (cleanPhone.startsWith('07') && cleanPhone.length == 11) {
      return '+964${cleanPhone.substring(1)}';
    }

    if (cleanPhone.startsWith('7') && cleanPhone.length == 10) {
      return '+964$cleanPhone';
    }

    return phone;
  }

  String _getArabicErrorMessage(AuthException e) {
    if (e is UsernameExistsException) {
      return 'يوجد حساب بهذا البريد الإلكتروني أو رقم الهاتف مسبقاً';
    }
    if (e is UserNotFoundException) {
      return 'المستخدم غير موجود';
    }
    if (e is CodeMismatchException) {
      return 'رمز التحقق غير صحيح';
    }
    if (e is InvalidPasswordException) {
      return 'كلمة المرور لا تستوفي المتطلبات';
    }

    final errorMessage = e.message.toLowerCase();
    final errorType = e.runtimeType.toString();

    if (errorMessage.contains('incorrect username or password') ||
        errorMessage.contains('notauthorized') ||
        errorType.contains('NotAuthorized')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }
    if (errorMessage.contains('attempt limit exceeded') ||
        errorMessage.contains('limitexceeded') ||
        errorType.contains('LimitExceeded')) {
      return 'تم تجاوز عدد المحاولات المسموح. يرجى المحاولة لاحقاً';
    }
    if (errorMessage.contains('invalid verification code provided') ||
        errorMessage.contains('codeexpired') ||
        errorMessage.contains('expiredcode') ||
        errorType.contains('CodeExpired') ||
        errorType.contains('ExpiredCode')) {
      return 'رمز التحقق منتهي الصلاحية';
    }

    final msg = e.message.toLowerCase();
    if (msg.contains('username') && msg.contains('exists')) {
      return 'يوجد حساب بهذا البريد الإلكتروني أو رقم الهاتف مسبقاً';
    }
    if (msg.contains('user') && msg.contains('not found')) {
      return 'المستخدم غير موجود';
    }
    if (msg.contains('code') && msg.contains('mismatch')) {
      return 'رمز التحقق غير صحيح';
    }
    if (msg.contains('password')) {
      return 'كلمة المرور غير صحيحة أو لا تستوفي المتطلبات';
    }
    if (msg.contains('not authorized')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }
    if (msg.contains('too many requests') || msg.contains('limit exceeded')) {
      return 'تم تجاوز عدد المحاولات المسموح. يرجى المحاولة لاحقاً';
    }
    if (msg.contains('network')) {
      return 'خطأ في الاتصال بالإنترنت';
    }

    return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى';
  }

  // Static validation methods for compatibility
  static bool isValidIraqiPhone(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    return cleanPhone.startsWith('07') && cleanPhone.length == 11;
  }

  static String normalizeIraqiPhone(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (cleanPhone.startsWith('+964')) {
      return cleanPhone;
    }
    
    if (cleanPhone.startsWith('07') && cleanPhone.length == 11) {
      return '+964${cleanPhone.substring(1)}';
    }
    
    if (cleanPhone.startsWith('7') && cleanPhone.length == 10) {
      return '+964$cleanPhone'; 
    }
    
    return phone;
  }
}
