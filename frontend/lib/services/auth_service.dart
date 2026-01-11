import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

import '../config/app_config.dart';
import 'cognito_token_service.dart';

class AuthService {
  // Dynamic base URL based on configuration
  static String get baseUrl => AppConfig.backendBaseUrl;

  // Dynamic development mode based on configuration
  static bool get _isDevelopmentMode => AppConfig.enableMockData;

  static String? _authToken;

  static String? get authToken => _authToken;

  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  /// Initialize the service by loading stored token and checking Amplify session
  static Future<void> initialize() async {
    debugPrint('🔐 Initializing AuthService...');
    
    // Load stored token from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    
    // Check Amplify session and update if available
    await checkAuthentication();
    
    debugPrint('🔐 AuthService initialized. isAuthenticated: $isAuthenticated');
  }

  /// Check if user is authenticated by verifying Amplify session (FIXED)
  static Future<bool> checkAuthentication() async {
    try {
      // 1. Check Amplify session first (PRIORITY)
      final session = await Amplify.Auth.fetchAuthSession();
      if (session.isSignedIn) {
        debugPrint('✅ User authenticated via Amplify');
        
        // Update _authToken from Amplify
        if (session is CognitoAuthSession) {
          try {
            final result = session.userPoolTokensResult;
            final tokens = result.value;
            _authToken = tokens.accessToken.raw;
            await _saveToken(_authToken!);
            debugPrint('✅ Token updated from Amplify session');
                    } catch (e) {
            debugPrint('⚠️ Could not extract token: $e');
          }
        }
        return true;
      }
      
      // 2. If Amplify session not found, check stored token
      if (_authToken != null) {
        debugPrint('⚠️ Using stored token (not from Amplify)');
        return true;
      }
      
      debugPrint('❌ No authentication found');
      return false;
    } catch (e) {
      debugPrint('❌ Error checking authentication: $e');
      // If error, fall back to stored token check
      return _authToken != null;
    }
  }

  /// Save token to local storage
  static Future<void> _saveToken(String token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  /// Clear token from local storage
  static Future<void> _clearToken() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  /// Check if user is authenticated (synchronous getter - uses cached value)
  static bool get isAuthenticated => _authToken != null;

  /// Login driver
  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    // Use mock service in development mode
    if (_isDevelopmentMode) {
      debugPrint('AuthService: Development login for $phone');
      await Future.delayed(const Duration(milliseconds: 1000));

      if (phone.isNotEmpty && password.isNotEmpty) {
        final token = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
        await _saveToken(token);

        final loginData = {
          'success': true,
          'message': 'تم تسجيل الدخول بنجاح',
          'driver_id': 'driver_123',
          'token': token,
        };
        
        // Save complete login data to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('login_data', jsonEncode(loginData));
        debugPrint('🔐 Saved login data to SharedPreferences (mock mode)');

        return loginData;
      }

      return {
        'success': false,
        'message': 'رقم الهاتف أو كلمة المرور غير صحيحة',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: _headers,
        body: jsonEncode({'phone': phone, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          (data['success'] == true || data['login_success'] == true)) {
        // Handle both 'success' and 'login_success' field names
        final token = data['token'] ?? data['access_token'];
        if (token != null) {
          await _saveToken(token);
          
          // Configure AWS services with Cognito token if available
          try {
            if (AppConfig.enableAWSIntegration) {
              debugPrint('🔧 Configuring AWS services with Cognito tokens...');
              await CognitoTokenService.configureAWSServices();
            }
          } catch (e) {
            debugPrint('⚠️ Failed to configure AWS services: $e');
          }
        }
        
        final loginData = <String, dynamic>{
          'success': true,
          'message': data['message'] ?? 'تم تسجيل الدخول بنجاح',
          'token': token,
          'login_success': data['login_success'],
          'driver_id': data['driver_id'],
        };
        
        // Add any additional fields from the response
        data.forEach((key, value) {
          if (!loginData.containsKey(key)) {
            loginData[key] = value;
          }
        });

        // Save complete login data to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('login_data', jsonEncode(loginData));
        debugPrint(
          '🔐 Saved login data to SharedPreferences: driver_id=${data['driver_id']}',
        );

        return loginData;
      } else {
        // Handle different error response formats
        String errorMessage = 'فشل في تسجيل الدخول';

        if (data['detail'] != null) {
          // Handle detailed error response
          final detail = data['detail'];
          errorMessage =
              detail['arabic_message'] ?? detail['message'] ?? errorMessage;
        } else if (data['message'] != null) {
          // Handle simple error response
          errorMessage = data['message'];
        }

        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: ${e.toString()}'};
    }
  }

  /// Register new driver
  static Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String password,
    required String city,
    required String vehicleType,
    required String licenseNumber,
    required String nationalId,
  }) async {
    // Print current configuration for debugging
    AppConfig.printConfig();

    // Use mock service only if explicitly enabled
    if (_isDevelopmentMode) {
      debugPrint('🧪 AuthService: Using mock registration for $phone');
      debugPrint(
        '💡 To enable AWS Cognito, set AppConfig.setForceProductionMode(true)',
      );
      await Future.delayed(const Duration(milliseconds: 1500));

      // Simulate phone number already exists scenario sometimes
      if (phone == '07701234567') {
        return {'success': false, 'message': 'رقم الهاتف مستخدم بالفعل'};
      }

      final token = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
      await _saveToken(token);

      return {
        'success': true,
        'message': 'تم التسجيل بنجاح (Mock Mode)',
        'driver_id': 'driver_123',
        'token': token,
      };
    }

    // AWS Cognito integration via backend
    debugPrint('🚀 AuthService: Using AWS Cognito registration for $phone');
    debugPrint('📡 Backend URL: $baseUrl');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'fullName': name, // Add fullName for backend compatibility
          'phone': phone,
          'password': password,
          'city': city,
          'vehicle_type': vehicleType,
          'license_number': licenseNumber,
          'national_id': nationalId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        // Don't save token for registration - token comes after login
        // Registration just creates the user, phone verification is needed first
        return data;
      } else {
        // Handle different error response formats
        String errorMessage = 'فشل في التسجيل';
        Map<String, dynamic> additionalData = {};

        if (data['detail'] != null) {
          // Handle detailed error response (like validation errors)
          final detail = data['detail'];
          errorMessage =
              detail['arabic_message'] ?? detail['message'] ?? errorMessage;

          // Check for specific error types that need special handling
          final errorType = detail['error'];

          if (errorType == 'PHONE_VERIFICATION_REQUIRED') {
            // User exists but needs phone verification
            additionalData = {
              'error_type': 'phone_verification_required',
              'phone': detail['phone'],
              'next_step': 'phone_verification',
              'show_verification_screen': true,
              'verification_endpoint': detail['verification_endpoint'],
              'confirm_endpoint': detail['confirm_endpoint'],
            };
          } else if (errorType == 'PHONE_ALREADY_REGISTERED') {
            // Phone is fully registered and confirmed
            additionalData = {
              'error_type': 'phone_already_registered',
              'next_step': 'login',
              'show_login_option': true,
              'login_endpoint': detail['login_endpoint'],
            };
          }

          // If there are validation errors, append them
          if (detail['validation_errors'] != null &&
              detail['validation_errors'] is List) {
            final validationErrors = (detail['validation_errors'] as List)
                .map((error) => error.toString())
                .toList();
            if (validationErrors.isNotEmpty) {
              errorMessage += '\n\n${validationErrors.join('\n')}';
            }
          }
        } else if (data['message'] != null) {
          // Handle simple error response
          errorMessage = data['message'];
        }

        return {'success': false, 'message': errorMessage, ...additionalData};
      }
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: ${e.toString()}'};
    }
  }

  /// Send verification code to phone
  static Future<Map<String, dynamic>> sendVerificationCode(String phone) async {
    // Use real Cognito SMS service instead of mock
    debugPrint(
      'AuthService: Redirecting to Cognito SMS verification for $phone',
    );
    debugPrint('📱 Use the SMS test screen for real verification');
    await Future.delayed(const Duration(milliseconds: 800));

    return {
      'success': false,
      'message': 'استخدم صفحة تسجيل SMS للتحقق الحقيقي',
      'redirect_to_sms_test': true,
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/phone/send-verification'),
        headers: _headers,
        body: jsonEncode({'phone': phone}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return data;
      } else {
        // Handle different error response formats
        String errorMessage = 'فشل في إرسال رمز التحقق';

        if (data['detail'] != null) {
          // Handle detailed error response
          final detail = data['detail'];
          errorMessage =
              detail['arabic_message'] ?? detail['message'] ?? errorMessage;
        } else if (data['message'] != null) {
          // Handle simple error response
          errorMessage = data['message'];
        }

        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: ${e.toString()}'};
    }
  }

  /// Verify phone number with code
  static Future<Map<String, dynamic>> verifyPhone({
    required String phone,
    required String code,
  }) async {
    // Use mock service in development mode
    if (_isDevelopmentMode) {
      debugPrint('AuthService: Verifying phone $phone with code $code');
      await Future.delayed(const Duration(milliseconds: 1000));

      // Accept "12345" as the development verification code
      if (code == '12345') {
        return {'success': true, 'message': 'تم التحقق من الهاتف بنجاح'};
      } else {
        return {
          'success': false,
          'message': 'رمز التحقق غير صحيح (استخدم 12345 في وضع التطوير)',
        };
      }
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/phone/verify'),
        headers: _headers,
        body: jsonEncode({'phone': phone, 'verification_code': code}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return data;
      } else {
        // Handle different error response formats
        String errorMessage = 'رمز التحقق غير صحيح';

        if (data['detail'] != null) {
          // Handle detailed error response
          final detail = data['detail'];
          errorMessage =
              detail['arabic_message'] ?? detail['message'] ?? errorMessage;
        } else if (data['message'] != null) {
          // Handle simple error response
          errorMessage = data['message'];
        }

        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: ${e.toString()}'};
    }
  }

  /// Reset password
  static Future<Map<String, dynamic>> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    // Use mock service in development mode
    if (_isDevelopmentMode) {
      debugPrint('AuthService: Resetting password for $phone');
      await Future.delayed(const Duration(milliseconds: 1200));

      if (code.length == 5 && newPassword.length >= 6) {
        return {'success': true, 'message': 'تم تغيير كلمة المرور بنجاح'};
      } else {
        return {
          'success': false,
          'message': 'رمز التحقق غير صحيح أو كلمة المرور قصيرة جداً',
        };
      }
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/password/reset'),
        headers: _headers,
        body: jsonEncode({
          'phone': phone,
          'verification_code': code,
          'new_password': newPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return data;
      } else {
        // Handle different error response formats
        String errorMessage = 'فشل في تغيير كلمة المرور';

        if (data['detail'] != null) {
          // Handle detailed error response
          final detail = data['detail'];
          errorMessage =
              detail['arabic_message'] ?? detail['message'] ?? errorMessage;
        } else if (data['message'] != null) {
          // Handle simple error response
          errorMessage = data['message'];
        }

        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: ${e.toString()}'};
    }
  }

  /// Request password reset
  static Future<Map<String, dynamic>> requestPasswordReset({
    required String phone,
  }) async {
    // Use mock service in development mode
    if (_isDevelopmentMode) {
      debugPrint('AuthService: Requesting password reset for $phone');
      await Future.delayed(const Duration(milliseconds: 800));

      return {
        'success': true,
        'message': 'تم إرسال رمز التحقق لإعادة تعيين كلمة المرور',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/password/request-reset'),
        headers: _headers,
        body: jsonEncode({'phone': phone}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return data;
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'فشل في طلب إعادة تعيين كلمة المرور',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'خطأ في الاتصال: ${e.toString()}'};
    }
  }

  /// Logout user
  static Future<void> logout() async {
    await _clearToken();
    
    // Clear login data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('login_data');
    debugPrint('🔐 Cleared login data from SharedPreferences');
    
    // Clear Cognito token cache
    try {
      CognitoTokenService.clearCache();
    } catch (e) {
      debugPrint('⚠️ Failed to clear Cognito token cache: $e');
    }
  }

  /// Get current driver profile
  static Future<Map<String, dynamic>> getCurrentDriver() async {
    if (!isAuthenticated) {
      return {'success': false, 'message': 'غير مخول'};
    }

    // Legacy profile endpoint deprecated. Use AWS Cognito + DynamoDB path instead.
    return {
      'success': false,
      'message':
          'تم إيقاف واجهة الملف الشخصي القديمة. الرجاء تفعيل تكامل AWS لاستخدام الملف الشخصي.',
    };
  }

  /// Test backend connection
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl.replaceAll('/api/v1', '')), // Use root endpoint
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'status': 'connected',
          'backend_url': baseUrl,
          'response': data,
          'status_code': response.statusCode,
        };
      } else {
        return {
          'success': false,
          'status': 'error',
          'backend_url': baseUrl,
          'error': 'HTTP ${response.statusCode}',
          'response': response.body,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'status': 'connection_failed',
        'backend_url': baseUrl,
        'error': e.toString(),
      };
    }
  }

  /// Check if backend is in development mode
  static bool get isDevelopmentMode => _isDevelopmentMode;
}
