import 'dart:async';
import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/environment.dart';
import '../services/logging/auth_logger.dart';
import 'aws_dynamodb_service.dart';

/// Enhanced AWS Cognito authentication service for user registration and login
class CognitoAuthServiceEnhanced {
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
      if (status == null) {
        await prefs.remove('driver_profile_status');
      } else {
        await prefs.setString('driver_profile_status', status);
      }
    } catch (_) {}
  }

  /// Save driver credentials to SharedPreferences for WebSocket and API services
  Future<void> _saveDriverCredentials({
    required String driverId,
    required String accessToken,
    required Map<String, dynamic> profile,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save login data structure for app session restoration
      final loginData = {
        'driver_id': driverId,
        'access_token': accessToken,
        'profile': profile,
        'login_timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await prefs.setString('login_data', jsonEncode(loginData));
      await prefs.setString('auth_token', accessToken);
      await prefs.setString('driver_id', driverId);
      
      debugPrint('✅ Driver credentials saved for WebSocket and API services');
    } catch (e) {
      debugPrint('❌ Error saving driver credentials: $e');
    }
  }

  /// Persist any cached extended registration fields to DynamoDB profile.
  /// Returns true if a pending cache existed and was successfully persisted.
  Future<bool> persistPendingRegistrationIfAny() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('pending_driver_registration');
      if (raw == null || raw.isEmpty) {
        return false;
      }
      final Map<String, dynamic> pending = jsonDecode(raw);

      // Ensure the DynamoDB HTTP client is configured with a valid token.
      String? token = _authToken;
      if (token == null || token.isEmpty) {
        try {
          final session =
              await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
          if (session.isSignedIn) {
            token = session.userPoolTokensResult.value.accessToken.raw;
          }
        } catch (_) {}
      }
      if (token != null && token.isNotEmpty) {
        AWSDynamoDBService.configure(
          baseUrl: Environment.apiBaseUrl,
          authToken: token,
        );
      }

      // Fetch existing profile first to respect current verification status
      String existingStatus = 'PENDING_PROFILE';
      try {
        final existing = await AWSDynamoDBService().getDriverProfile(
          'self',
          maxRetries: 1,
        );
        if (existing != null &&
            (existing['status'] ?? '').toString().isNotEmpty) {
          existingStatus = existing['status'];
        }
      } catch (e) {
        debugPrint(
          'persistPendingRegistrationIfAny: failed to read existing profile (will proceed): $e',
        );
      }
      // Update local cache with whatever we know so far
      await _setLastKnownProfileStatus(existingStatus);

      // Determine if we should auto-advance status to PENDING_REVIEW (all key docs present)
      final hasDocsInfo =
          (pending['licenseNumber'] ?? '').toString().isNotEmpty &&
          (pending['nationalId'] ?? '').toString().isNotEmpty &&
          (pending['docs'] ?? '').toString().isNotEmpty;

      final attr = <String, String>{
        'name': pending['name'] ?? '',
        'city': pending['city'] ?? '',
        'vehicleType': pending['vehicleType'] ?? '',
        'licenseNumber': pending['licenseNumber'] ?? '',
        'nationalId': pending['nationalId'] ?? '',
        'docs': pending['docs'] ?? '',
      };

      // Only attempt auto-transition if profile still at baseline
      if (hasDocsInfo && existingStatus == 'PENDING_PROFILE') {
        attr['status'] = 'PENDING_REVIEW';
        debugPrint(
          'persistPendingRegistrationIfAny: auto-transitioning status PENDING_PROFILE -> PENDING_REVIEW',
        );
      } else {
        debugPrint(
          'persistPendingRegistrationIfAny: not setting status (existingStatus=$existingStatus, hasDocsInfo=$hasDocsInfo)',
        );
      }

      // Check if documents are stored in the pending registration
      final hasPendingDocuments =
          pending.containsKey('drivingLicenseFile') ||
          pending.containsKey('vehicleRegistrationFile') ||
          pending.containsKey('nonCriminalRecordFile');

      bool ok = false;
      if (hasPendingDocuments) {
        // Use document-aware registration method
        debugPrint(
          'persistPendingRegistrationIfAny: found documents, using saveDriverRegistrationWithDocuments',
        );
        ok = await AWSDynamoDBService().saveDriverRegistrationWithDocuments(
          driverId: 'self',
          email: pending['email'] ?? '',
          phoneNumber: pending['phone'] ?? '',
          attributes: {
            'name': pending['name'] ?? '',
            'city': pending['city'] ?? '',
            'vehicleType': pending['vehicleType'] ?? '',
            'licenseNumber': pending['licenseNumber'] ?? '',
            'nationalId': pending['nationalId'] ?? '',
            if (attr['status'] != null) 'status': attr['status']!,
          },
          drivingLicenseFile: pending['drivingLicenseFile'],
          vehicleRegistrationFile: pending['vehicleRegistrationFile'],
          nonCriminalRecordFile: pending['nonCriminalRecordFile'],
        );
      } else {
        // Use regular registration method
        debugPrint(
          'persistPendingRegistrationIfAny: no documents, using saveDriverRegistration',
        );
        ok = await AWSDynamoDBService().saveDriverRegistration(
          driverId: 'self',
          email: pending['email'] ?? '',
          phoneNumber: pending['phone'] ?? '',
          attributes: attr,
        );
      }

      if (ok) {
        // If we explicitly set status, reflect it locally; else keep existing
        await _setLastKnownProfileStatus(attr['status'] ?? existingStatus);
        await prefs.remove('pending_driver_registration');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('persistPendingRegistrationIfAny error: $e');
      return false;
    }
  }

  Future<void> initialize() async {
    debugPrint('🔐 CognitoAuthServiceEnhanced: Initializing...');
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('cognito_auth_token');
    // Load cached profile status if present
    _lastKnownProfileStatus = prefs.getString('driver_profile_status');

    debugPrint(
      '🔐 CognitoAuthServiceEnhanced: Cached token exists: ${_authToken != null}',
    );
    debugPrint(
      '🔐 CognitoAuthServiceEnhanced: Cached profile status: $_lastKnownProfileStatus',
    );

    // CRITICAL: Validate the session against Amplify, not just check if token exists
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;

      if (session.isSignedIn) {
        debugPrint(
          '✅ CognitoAuthServiceEnhanced: Amplify session is valid and signed in',
        );
        // Get fresh token from valid session
        try {
          final tokens = session.userPoolTokensResult.value;
          final freshToken = tokens.accessToken.raw;

          // Update cached token with fresh one
          _authToken = freshToken;
          await prefs.setString('cognito_auth_token', freshToken);
          debugPrint('✅ CognitoAuthServiceEnhanced: Token refreshed on initialization');
        } catch (tokenError) {
          debugPrint(
            '⚠️ CognitoAuthServiceEnhanced: Could not get fresh tokens: $tokenError',
          );
          // Keep cached token but it might be expired
        }
      } else {
        // Session is not signed in - clear everything
        debugPrint(
          '❌ CognitoAuthServiceEnhanced: Amplify session is NOT signed in, clearing cache',
        );
        _authToken = null;
        _lastKnownProfileStatus = null;
        await prefs.remove('cognito_auth_token');
        await prefs.remove('driver_profile_status');
      }
    } catch (e) {
      // If we can't validate session, clear cached data to force re-authentication
      debugPrint('❌ CognitoAuthServiceEnhanced: Session validation failed: $e');
      debugPrint('🧹 CognitoAuthServiceEnhanced: Clearing cached auth data');
      _authToken = null;
      _lastKnownProfileStatus = null;
      await prefs.remove('cognito_auth_token');
      await prefs.remove('driver_profile_status');
    }

    debugPrint(
      '🔐 CognitoAuthServiceEnhanced: Initialize complete. isAuthenticated=$isAuthenticated',
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
    await prefs.remove('login_data');
    await prefs.remove('auth_token');
    await prefs.remove('driver_id');
  }

  bool get isAuthenticated => _authToken != null;

  /// Format phone number to E.164 format for Iraqi numbers
  String _formatPhoneNumber(String phone) {
    // Remove all non-digits
    String digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Handle Iraqi numbers
    if (digitsOnly.startsWith('07')) {
      // Convert 07XXXXXXXX to +9647XXXXXXXX
      return '+964${digitsOnly.substring(1)}';
    } else if (digitsOnly.startsWith('9647')) {
      // Already in format 9647XXXXXXXX, add +
      return '+$digitsOnly';
    } else if (digitsOnly.startsWith('7') && digitsOnly.length == 10) {
      // 7XXXXXXXX format, add +964
      return '+964$digitsOnly';
    }
    
    // Return as is if no pattern matches
    return phone;
  }

  /// Validate Iraqi phone number format
  bool isValidIraqiPhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check various Iraqi phone formats
    if (digitsOnly.startsWith('07') && digitsOnly.length == 11) {
      return true; // 07XXXXXXXXX
    }
    if (digitsOnly.startsWith('9647') && digitsOnly.length == 13) {
      return true; // 9647XXXXXXXXX
    }
    if (digitsOnly.startsWith('7') && digitsOnly.length == 10) {
      return true; // 7XXXXXXXXX
    }
    
    return false;
  }

  /// Get Arabic error message for Cognito exceptions
  String _getArabicErrorMessage(AuthException e) {
    switch (e.runtimeType.toString()) {
      case 'UserNotFoundException':
        return 'المستخدم غير موجود';
      case 'NotAuthorizedException':
        return 'اسم المستخدم أو كلمة المرور غير صحيحة';
      case 'UserNotConfirmedException':
        return 'يجب تأكيد الحساب أولاً';
      case 'CodeMismatchException':
        return 'رمز التحقق غير صحيح';
      case 'ExpiredCodeException':
        return 'رمز التحقق منتهي الصلاحية';
      case 'InvalidPasswordException':
        return 'كلمة المرور لا تلبي المتطلبات';
      case 'UsernameExistsException':
        return 'اسم المستخدم موجود بالفعل';
      case 'InvalidParameterException':
        return 'المعاملات غير صحيحة';
      case 'TooManyRequestsException':
        return 'تم تجاوز عدد المحاولات المسموح';
      default:
        return e.message;
    }
  }

  /// Generate phone number from email hash for fallback login strategy
  String _generatePhoneFromEmail(String email) {
    final emailHash = email.hashCode.abs();
    final phoneNumber = '+964${emailHash.toString().padLeft(10, '0').substring(0, 10)}';
    return phoneNumber;
  }

  /// Register with email
  Future<Map<String, dynamic>> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String city,
    required String vehicleType,
    required String licenseNumber,
    required String nationalId,
    Map<String, dynamic>? driverPhotoFile,
    Map<String, dynamic>? drivingLicenseFile,
    Map<String, dynamic>? vehicleRegistrationFile,
    Map<String, dynamic>? nonCriminalRecordFile,
  }) async {
    logger?.logSendCode(
      identity: email,
      channel: 'email',
      purpose: 'signup',
      attempt: 1,
    );
    
    debugPrint('🔧 CognitoAuthServiceEnhanced.registerWithEmail called');
    debugPrint('   Email: $email');
    debugPrint('   Phone: $phone');
    debugPrint('   Name: $fullName');

    try {
      debugPrint('🔧 Building user attributes...');
      // Use full name as single 'name' attribute to match backend Lambda
      final userAttributes = <AuthUserAttributeKey, String>{
        AuthUserAttributeKey.email: email,
        if (phone.isNotEmpty)
          AuthUserAttributeKey.phoneNumber: _formatPhoneNumber(phone),
        AuthUserAttributeKey.name: fullName,
        // NOTE: Custom driver profile fields removed from Cognito. They will be stored in DynamoDB.
      };

      debugPrint(
        '🔧 User attributes prepared (Cognito only): ${userAttributes.length} attributes',
      );
      debugPrint('🔧 Formatted phone: ${_formatPhoneNumber(phone)}');

      debugPrint('🔧 Calling Amplify.Auth.signUp...');
      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(userAttributes: userAttributes),
      );

      // Cache extended fields to persist post-confirmation
      try {
        final prefs = await SharedPreferences.getInstance();
        final pendingData = <String, dynamic>{
          'email': email,
          'phone': _formatPhoneNumber(phone),
          'name': fullName,
          'city': city,
          'vehicleType': vehicleType,
          'licenseNumber': licenseNumber,
          'nationalId': nationalId,
          'docs': '', // Documents will be handled separately
          'status': 'PENDING_PROFILE', // Initial status
        };

        // Include document files if provided
        if (drivingLicenseFile != null) {
          pendingData['drivingLicenseFile'] = drivingLicenseFile;
        }
        if (vehicleRegistrationFile != null) {
          pendingData['vehicleRegistrationFile'] = vehicleRegistrationFile;
        }
        if (nonCriminalRecordFile != null) {
          pendingData['nonCriminalRecordFile'] = nonCriminalRecordFile;
        }

        await prefs.setString(
          'pending_driver_registration',
          jsonEncode(pendingData),
        );
      } catch (_) {}

      debugPrint('🔧 Amplify.Auth.signUp completed');
      debugPrint('🔧 isSignUpComplete: ${result.isSignUpComplete}');
      debugPrint('🔧 userId: ${result.userId}');
      debugPrint('🔧 nextStep: ${result.nextStep.signUpStep.name}');

      if (result.isSignUpComplete) {
        debugPrint('🔧 Registration complete immediately');
        return {
          'success': true,
          'message': 'تم إنشاء الحساب بنجاح',
          'confirmation_required': false,
          'user_id': result.userId,
        };
      } else {
        debugPrint('🔧 Registration requires confirmation');
        return {
          'success': true,
          'message': 'تم إنشاء الحساب. يرجى التحقق من بريدك الإلكتروني',
          'confirmation_required': true,
          'user_id': result.userId,
          'next_step': result.nextStep.signUpStep.name,
        };
      }
    } on AuthException catch (e) {
      debugPrint('🔧 AuthException caught: ${e.message}');
      debugPrint('🔧 AuthException type: ${e.runtimeType}');
      debugPrint('🔧 Underlying exception: ${e.underlyingException}');
      return {
        'success': false,
        'message': _getArabicErrorMessage(e),
        'error': e.message,
        'error_code': e.underlyingException?.toString(),
      };
    } catch (e) {
      debugPrint('🔧 Generic exception caught: $e');
      debugPrint('🔧 Exception type: ${e.runtimeType}');
      return {
        'success': false,
        'message': 'حدث خطأ غير متوقع',
        'error': e.toString(),
      };
    }
  }

  /// Register with phone via Cognito (OTP required)
  Future<Map<String, dynamic>> registerWithPhone({
    required String phone,
    required String password,
    required String fullName,
    String? email, // Optional email parameter
    required String city,
    required String vehicleType,
    required String licenseNumber,
    required String nationalId,
    Map<String, dynamic>? driverPhotoFile,
    Map<String, dynamic>? drivingLicenseFile,
    Map<String, dynamic>? vehicleRegistrationFile,
    Map<String, dynamic>? nonCriminalRecordFile,
  }) async {
    debugPrint('🔧 CognitoAuthServiceEnhanced.registerWithPhone called');
    debugPrint('🔧 Input phone: $phone');

    // Basic validation
    if (!isValidIraqiPhone(phone)) {
      debugPrint('❌ Phone validation failed for: $phone');
      return {
        'success': false,
        'message': 'رقم الهاتف غير صحيح. يجب أن يبدأ بـ 07 ويكون 11 رقماً',
        'error': 'INVALID_PHONE_FORMAT',
      };
    }
    if (password.length < 8) {
      debugPrint('❌ Password too short: ${password.length}');
      return {
        'success': false,
        'message': 'كلمة المرور يجب أن تكون 8 أحرف على الأقل',
        'error': 'WEAK_PASSWORD',
      };
    }

    logger?.logSendCode(
      identity: phone,
      channel: 'phone',
      purpose: 'signup',
      attempt: 1,
    );

    try {
      final formattedPhone = _formatPhoneNumber(phone);

      // Use name attribute instead of given_name/family_name to match schema
      final userAttributes = <AuthUserAttributeKey, String>{
        AuthUserAttributeKey.phoneNumber: formattedPhone,
        AuthUserAttributeKey.name: fullName,
        if (email != null && email.isNotEmpty)
          AuthUserAttributeKey.email: email,
      };

      debugPrint('🔧 Calling Amplify.Auth.signUp with phone username');
      final result = await Amplify.Auth.signUp(
        username: formattedPhone,
        password: password,
        options: SignUpOptions(userAttributes: userAttributes),
      );

      // Cache extended fields to persist post-confirmation
      try {
        final prefs = await SharedPreferences.getInstance();
        final pendingData = <String, dynamic>{
          'email': email ?? '',
          'phone': formattedPhone,
          'name': fullName,
          'city': city,
          'vehicleType': vehicleType,
          'licenseNumber': licenseNumber,
          'nationalId': nationalId,
          'docs': '',
          'status': 'PENDING_PROFILE',
        };

        // Include document files if provided
        if (drivingLicenseFile != null) {
          pendingData['drivingLicenseFile'] = drivingLicenseFile;
        }
        if (vehicleRegistrationFile != null) {
          pendingData['vehicleRegistrationFile'] = vehicleRegistrationFile;
        }
        if (nonCriminalRecordFile != null) {
          pendingData['nonCriminalRecordFile'] = nonCriminalRecordFile;
        }

        await prefs.setString(
          'pending_driver_registration',
          jsonEncode(pendingData),
        );
      } catch (_) {}

      // Do NOT save any auth token here; user must verify first
      final requiresConfirmation = !result.isSignUpComplete;
      debugPrint('🔧 signUp complete? ${result.isSignUpComplete}');

      return {
        'success': true,
        'message': requiresConfirmation
            ? 'تم إنشاء الحساب. تم إرسال رمز التحقق إلى هاتفك'
            : 'تم إنشاء الحساب',
        'phone_verification_required': true,
        'user_id': result.userId,
        'next_step': result.nextStep.signUpStep.name,
      };
    } on AuthException catch (e) {
      debugPrint('🔧 AuthException in registerWithPhone: ${e.message}');
      return {
        'success': false,
        'message': _getArabicErrorMessage(e),
        'error': e.message,
        'error_code': e.runtimeType.toString(),
      };
    } catch (e) {
      debugPrint('🔧 Generic exception in registerWithPhone: $e');
      return {
        'success': false,
        'message': 'حدث خطأ غير متوقع',
        'error': e.toString(),
      };
    }
  }

  /// Login with email
  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    logger?.logLoginAttempt(identity: email, channel: 'email');
    final success = await (() async {
      try {
        final result = await Amplify.Auth.signIn(
          username: email,
          password: password,
        );

        if (result.isSignedIn) {
          // Get user session token
          final session =
              await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
          if (session.isSignedIn) {
            final tokens = session.userPoolTokensResult.value;
            await _saveToken(tokens.accessToken.raw);
            // Persist pending registration if exists
            await persistPendingRegistrationIfAny();
            return true;
          }
        }
        return false;
      } on AuthException catch (e) {
        safePrint('Login error: ${e.message}');
        return false;
      }
    })();
    logger?.logLoginResult(
      identity: email,
      channel: 'email',
      success: success,
      failureReason: success ? null : 'invalid_credentials',
    );
    return success;
  }

  /// Login with phone
  Future<bool> loginWithPhone({
    required String phone,
    required String password,
  }) async {
    logger?.logLoginAttempt(identity: phone, channel: 'phone');
    final success = await (() async {
      try {
        final formattedPhone = _formatPhoneNumber(phone);
        final result = await Amplify.Auth.signIn(
          username: formattedPhone,
          password: password,
        );

        if (result.isSignedIn) {
          // Get user session token
          final session =
              await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
          if (session.isSignedIn) {
            final tokens = session.userPoolTokensResult.value;
            await _saveToken(tokens.accessToken.raw);
            // Persist pending registration if exists
            await persistPendingRegistrationIfAny();
            return true;
          }
        }
        return false;
      } on AuthException catch (e) {
        safePrint('Login error: ${e.message}');
        return false;
      }
    })();
    logger?.logLoginResult(
      identity: phone,
      channel: 'phone',
      success: success,
      failureReason: success ? null : 'invalid_credentials',
    );
    return success;
  }

  /// Login with detailed response for better error handling with fallback strategy
  Future<Map<String, dynamic>> loginWithEmailDetailed({
    required String email,
    required String password,
  }) async {
    logger?.logLoginAttempt(identity: email, channel: 'email');
    
    try {
      // Strategy 0: Check if user is already signed in and handle it
      final existingSession = await Amplify.Auth.fetchAuthSession();
      if (existingSession.isSignedIn) {
        if (kDebugMode) {
          debugPrint('⚠️ User already signed in, forcing logout first...');
        }
        await forceCompleteLogout();
        // Wait a bit for logout to complete
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Strategy 1: Try direct email login
      try {
        if (kDebugMode) {
          debugPrint('🔐 Strategy 1: Trying direct email: $email');
        }
        
        final result = await Amplify.Auth.signIn(
          username: email,
          password: password,
        );

        if (result.isSignedIn) {
          if (kDebugMode) {
            debugPrint('✅ Direct email login successful');
          }
          final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
          if (session.isSignedIn) {
            final tokens = session.userPoolTokensResult.value;
            await _saveToken(tokens.accessToken.raw);
            
            // Persist pending registration if exists
            await persistPendingRegistrationIfAny();
            
            logger?.logLoginResult(
              identity: email,
              channel: 'email',
              success: true,
            );
            
            return {
              'success': true,
              'message': 'تم تسجيل الدخول بنجاح',
            };
          }
        }
      } on AuthException catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Direct email login failed: ${e.message}');
        }
        
        // Handle "user already signed in" error
        if (e.runtimeType.toString().contains('InvalidUserPool') || 
            e.message.toLowerCase().contains('already signed in')) {
          if (kDebugMode) {
            debugPrint('🔄 Handling already signed in error, forcing logout...');
          }
          await forceCompleteLogout();
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Retry after logout
          try {
            final retryResult = await Amplify.Auth.signIn(
              username: email,
              password: password,
            );
            
            if (retryResult.isSignedIn) {
              final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
              if (session.isSignedIn) {
                final tokens = session.userPoolTokensResult.value;
                await _saveToken(tokens.accessToken.raw);
                await persistPendingRegistrationIfAny();
                
                logger?.logLoginResult(
                  identity: email,
                  channel: 'email',
                  success: true,
                );
                
                return {
                  'success': true,
                  'message': 'تم تسجيل الدخول بنجاح',
                };
              }
            }
          } catch (retryError) {
            if (kDebugMode) {
              debugPrint('⚠️ Retry after logout failed: $retryError');
            }
          }
        }
        
        // Strategy 2: Try with generated phone from email hash
        try {
          final generatedPhone = _generatePhoneFromEmail(email);
          if (kDebugMode) {
            debugPrint('🔐 Strategy 2: Trying generated phone: $generatedPhone');
          }

          final result = await Amplify.Auth.signIn(
            username: generatedPhone,
            password: password,
          );

          if (result.isSignedIn) {
            if (kDebugMode) {
              debugPrint('✅ Generated phone login successful');
            }
            final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
            if (session.isSignedIn) {
              final tokens = session.userPoolTokensResult.value;
              await _saveToken(tokens.accessToken.raw);
              
              // Persist pending registration if exists
              await persistPendingRegistrationIfAny();
              
              logger?.logLoginResult(
                identity: email,
                channel: 'email',
                success: true,
              );
              
              return {
                'success': true,
                'message': 'تم تسجيل الدخول بنجاح',
              };
            }
          }
        } on AuthException catch (phoneError) {
          if (kDebugMode) {
            debugPrint('⚠️ Generated phone login failed: ${phoneError.message}');
          }
          
          // Return the original email error, not the phone error
          logger?.logLoginResult(
            identity: email,
            channel: 'email',
            success: false,
            failureReason: e.runtimeType.toString(),
          );
          
          return {
            'success': false,
            'message': _getArabicErrorMessage(e),
            'error': e.message,
            'reason': e.runtimeType.toString(),
          };
        }
      }
      
      // If both strategies failed without throwing exceptions
      logger?.logLoginResult(
        identity: email,
        channel: 'email',
        success: false,
        failureReason: 'auth_incomplete',
      );
      
      return {
        'success': false,
        'message': 'فشل في إكمال تسجيل الدخول',
      };
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Unexpected error in loginWithEmailDetailed: $e');
      }
      
      logger?.logLoginResult(
        identity: email,
        channel: 'email',
        success: false,
        failureReason: 'unexpected_error',
      );
      
      return {
        'success': false,
        'message': 'حدث خطأ غير متوقع في تسجيل الدخول',
        'error': e.toString(),
      };
    }
  }

  /// Login with phone with detailed response
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
        // Get user session token
        final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
        if (session.isSignedIn) {
          final tokens = session.userPoolTokensResult.value;
          await _saveToken(tokens.accessToken.raw);
          
          // Persist pending registration if exists
          await persistPendingRegistrationIfAny();
          
          logger?.logLoginResult(
            identity: phone,
            channel: 'phone',
            success: true,
          );
          
          return {
            'success': true,
            'message': 'تم تسجيل الدخول بنجاح',
          };
        }
      }
      
      logger?.logLoginResult(
        identity: phone,
        channel: 'phone',
        success: false,
        failureReason: 'auth_incomplete',
      );
      
      return {
        'success': false,
        'message': 'فشل في إكمال تسجيل الدخول',
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
        failureReason: 'generic_error',
      );
      
      return {
        'success': false,
        'message': 'حدث خطأ غير متوقع',
        'error': e.toString(),
      };
    }
  }

  /// Verify phone number
  Future<Map<String, dynamic>> verifyPhoneNumber({
    required String phone,
    required String verificationCode,
  }) async {
    final result = await (() async {
      try {
        final formattedPhone = _formatPhoneNumber(phone);
        final result = await Amplify.Auth.confirmSignUp(
          username: formattedPhone,
          confirmationCode: verificationCode,
        );

        // After confirmation, try to read profile and save extended fields if available
        if (result.isSignUpComplete) {
          try {
            // Warm-up read and persist pending registration
            await persistPendingRegistrationIfAny();
            await Future.delayed(const Duration(milliseconds: 300));
            await AWSDynamoDBService().getDriverProfile('self');
          } catch (_) {}
        }

        return {
          'success': result.isSignUpComplete,
          'verified': result.isSignUpComplete,
          'message': result.isSignUpComplete
              ? 'تم التحقق من رقم الهاتف بنجاح'
              : 'رمز التحقق غير صحيح',
        };
      } on AuthException catch (e) {
        return {
          'success': false,
          'verified': false,
          'message': _getArabicErrorMessage(e),
        };
      }
    })();
    logger?.logVerifyCode(
      identity: phone,
      channel: 'phone',
      purpose: 'signup',
      success: result['success'] == true,
      failureReason: result['success'] == true ? null : 'code_mismatch',
    );
    return result;
  }

  /// Confirm email verification
  Future<bool> confirmEmail({
    required String email,
    required String verificationCode,
  }) async {
    final success = await (() async {
      try {
        final result = await Amplify.Auth.confirmSignUp(
          username: email,
          confirmationCode: verificationCode,
        );
        return result.isSignUpComplete;
      } on AuthException catch (e) {
        safePrint('Error confirming email: ${e.message}');
        return false;
      }
    })();
    logger?.logVerifyCode(
      identity: email,
      channel: 'email',
      purpose: 'signup',
      success: success,
      failureReason: success ? null : 'code_mismatch',
    );
    return success;
  }

  /// Get current authenticated user profile
  Future<Map<String, dynamic>> getCurrentDriver() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        return {'success': false, 'message': 'غير مصرح بالوصول'};
      }

      final user = await Amplify.Auth.getCurrentUser();
      final userAttributes = await Amplify.Auth.fetchUserAttributes();

      final attributeMap = <String, String>{};
      for (final attr in userAttributes) {
        attributeMap[attr.userAttributeKey.key] = attr.value;
      }

      // Configure DynamoDB API client with Cognito token
      final cognitoSession = session as CognitoAuthSession;
      final tokens = cognitoSession.userPoolTokensResult.value;
      final accessToken = tokens.accessToken.raw;
      AWSDynamoDBService.configure(
        baseUrl: Environment.apiBaseUrl,
        authToken: accessToken,
      );

      // Retry fetching profile (handle eventual consistency right after confirmation)
      Map<String, dynamic>? dynamoProfile;
      for (var attempt = 1; attempt <= 3; attempt++) {
        dynamoProfile = await AWSDynamoDBService().getDriverProfile(
          'self',
          maxRetries: 1,
        );
        if (dynamoProfile != null) break;
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final merged = {
        'id': user.userId,
        'username': user.username,
        'name': attributeMap['name'] ?? (dynamoProfile?['name'] ?? ''),
        'email': attributeMap['email'] ?? (dynamoProfile?['email'] ?? ''),
        'phone':
            attributeMap['phone_number'] ?? (dynamoProfile?['phone'] ?? ''),
        'city': dynamoProfile?['city'] ?? '',
        'vehicle_type': dynamoProfile?['vehicleType'] ?? '',
        'license_number': dynamoProfile?['licenseNumber'] ?? '',
        'national_id': dynamoProfile?['nationalId'] ?? '',
        'email_verified': attributeMap['email_verified'] == 'true',
        'phone_verified': attributeMap['phone_number_verified'] == 'true',
        'status': dynamoProfile?['status'] ?? 'PENDING_PROFILE',
      };

      // ✅ Save driver credentials to SharedPreferences for app services
      await _saveDriverCredentials(
        driverId: dynamoProfile?['driverId'] ?? user.userId,
        accessToken: accessToken,
        profile: merged,
      );

      // Update local cache for router guard usage
      await _setLastKnownProfileStatus(merged['status'] as String?);

      return {'success': true, 'data': merged};
    } on AuthException catch (e) {
      return {'success': false, 'message': _getArabicErrorMessage(e)};
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await Amplify.Auth.signOut();
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
    await _clearToken();
    await _setLastKnownProfileStatus(null);
  }

  /// Force complete logout - clears everything including any stuck sessions
  Future<void> forceCompleteLogout() async {
    try {
      debugPrint('🚪 Force complete logout started...');
      
      // Step 1: Clear local tokens and data first
      await _clearToken();
      await _setLastKnownProfileStatus(null);
      
      // Step 2: Try multiple sign out approaches
      try {
        // Global sign out from all devices
        await Amplify.Auth.signOut(
          options: const SignOutOptions(globalSignOut: true)
        );
        debugPrint('✅ Global sign out successful');
      } catch (e) {
        debugPrint('⚠️ Global sign out failed: $e');
        
        // Fallback to regular sign out
        try {
          await Amplify.Auth.signOut();
          debugPrint('✅ Regular sign out successful');
        } catch (e2) {
          debugPrint('⚠️ Regular sign out failed: $e2');
        }
      }
      
      // Step 3: Clear SharedPreferences completely
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove('cognito_auth_token'),
        prefs.remove('driver_profile_status'),
        prefs.remove('login_data'),
        prefs.remove('auth_token'),
        prefs.remove('driver_id'),
        prefs.remove('pending_driver_registration'),
      ]);
      
      debugPrint('✅ Force complete logout finished');
    } catch (e) {
      debugPrint('❌ Error in force complete logout: $e');
      // Force clear local data even if remote logout fails
      await _clearToken();
      await _setLastKnownProfileStatus(null);
    }
  }

  /// Resend confirmation code with details
  Future<Map<String, dynamic>> resendConfirmationCodeWithDetails({
    required String username,
  }) async {
    try {
      final result = await Amplify.Auth.resendSignUpCode(username: username);

      String? deliveryMessage;
      if (result.codeDeliveryDetails.destination != null) {
        final destination = result.codeDeliveryDetails.destination!;
        if (result.codeDeliveryDetails.deliveryMedium == DeliveryMedium.email) {
          deliveryMessage = 'تم إرسال الرمز إلى $destination';
        } else if (result.codeDeliveryDetails.deliveryMedium == DeliveryMedium.sms) {
          deliveryMessage = 'تم إرسال الرمز إلى $destination';
        }
      }

      return {
        'success': true,
        'message': 'تم إعادة إرسال رمز التحقق',
        'delivery_message': deliveryMessage,
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _getArabicErrorMessage(e)};
    }
  }

  /// Resend confirmation code (simplified version)
  Future<Map<String, dynamic>> resendConfirmationCode({
    required String username,
  }) async {
    try {
      await Amplify.Auth.resendSignUpCode(username: username);
      return {'success': true, 'message': 'تم إعادة إرسال رمز التحقق'};
    } on AuthException catch (e) {
      return {'success': false, 'message': _getArabicErrorMessage(e)};
    }
  }

  /// Send email verification code specifically for email attributes
  Future<Map<String, dynamic>> sendEmailVerificationCode({
    required String email,
  }) async {
    try {
      debugPrint('🔧 Sending email verification code to: $email');
      
      final result = await Amplify.Auth.sendUserAttributeVerificationCode(
        userAttributeKey: AuthUserAttributeKey.email,
      );

      String? deliveryMessage;
      if (result.codeDeliveryDetails.destination != null) {
        final destination = result.codeDeliveryDetails.destination!;
        deliveryMessage = 'تم إرسال رمز التحقق إلى بريدك الإلكتروني: $destination';
      }

      return {
        'success': true,
        'message': 'تم إرسال رمز التحقق إلى بريدك الإلكتروني',
        'delivery_message': deliveryMessage,
        'delivery_medium': 'email',
      };
    } on AuthException catch (e) {
      debugPrint('🔧 Error sending email verification: ${e.message}');
      return {
        'success': false, 
        'message': _getArabicErrorMessage(e),
        'error': e.message,
      };
    }
  }

  /// Confirm email attribute verification (after user is already signed up)
  Future<bool> confirmEmailAttribute({
    required String verificationCode,
  }) async {
    try {
      await Amplify.Auth.confirmUserAttribute(
        userAttributeKey: AuthUserAttributeKey.email,
        confirmationCode: verificationCode,
      );
      return true;
    } on AuthException catch (e) {
      debugPrint('🔧 Error confirming email attribute: ${e.message}');
      return false;
    }
  }

  /// Reset password via phone
  Future<Map<String, dynamic>> resetPasswordPhone({
    required String phone,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phone);
      final result = await Amplify.Auth.resetPassword(username: formattedPhone);
      
      return {
        'success': true,
        'message': 'تم إرسال رمز إعادة التعيين',
        'next_step': result.nextStep.toString(),
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _getArabicErrorMessage(e)};
    }
  }

  /// Reset password via email
  static Future<bool> resetPasswordEmail({
    required String email,
  }) async {
    try {
      await Amplify.Auth.resetPassword(username: email);
      return true;
    } on AuthException catch (e) {
      debugPrint('Error resetting password: ${e.message}');
      return false;
    }
  }

  /// Confirm password reset with phone
  Future<Map<String, dynamic>> confirmResetPasswordPhone({
    required String phone,
    required String confirmationCode,
    required String newPassword,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phone);
      await Amplify.Auth.confirmResetPassword(
        username: formattedPhone,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );
      return {
        'success': true,
        'message': 'تم تغيير كلمة المرور بنجاح',
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'message': _getArabicErrorMessage(e),
      };
    }
  }

  /// Confirm password reset with email  
  static Future<Map<String, dynamic>> confirmResetPasswordEmail({
    required String email,
    required String confirmationCode,
    required String newPassword,
  }) async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );
      return {
        'success': true,
        'message': 'تم تغيير كلمة المرور بنجاح',
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'message': _getStaticArabicErrorMessage(e),
      };
    }
  }

  /// Static helper for Arabic error messages (for static methods)
  static String _getStaticArabicErrorMessage(AuthException e) {
    switch (e.runtimeType.toString()) {
      case 'UserNotConfirmedException':
        return 'الحساب غير مؤكد. يرجى التحقق من بريدك الإلكتروني أو رقم هاتفك';
      case 'UserNotFoundException': 
        return 'المستخدم غير موجود';
      case 'NotAuthorizedException':
        return 'بيانات الدخول غير صحيحة';  
      case 'InvalidPasswordException':
        return 'كلمة المرور لا تلبي المتطلبات المطلوبة';
      case 'UsernameExistsException':
        return 'هذا الحساب مسجل مسبقاً';
      case 'CodeMismatchException':
        return 'رمز التحقق غير صحيح';
      case 'ExpiredCodeException':
        return 'رمز التحقق منتهي الصلاحية';
      case 'LimitExceededException':
        return 'تم تجاوز الحد المسموح من المحاولات';
      case 'TooManyRequestsException':
        return 'تم تجاوز عدد الطلبات المسموح. يرجى المحاولة لاحقاً';
      default:
        return e.message;
    }
  }
}
