import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import 'services_provider.dart';
import '../../services/driver_service.dart';
import '../../services/realtime_communication_service.dart';

part 'auth_provider.g.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final Map<String, dynamic>? currentDriver;
  final String? errorMessage;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.currentDriver,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    Map<String, dynamic>? currentDriver,
    String? errorMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      currentDriver: currentDriver ?? this.currentDriver,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  @override
  AuthState build() {
    return const AuthState();
  }

  /// Initialize authentication state
  Future<void> initialize() async {
    debugPrint('🔐 AuthProvider: Initializing authentication state');
    _setLoading(true);

    try {
      if (AppConfig.enableAWSIntegration) {
        // Note: Using services provider instead of direct instantiation
        final cognito = ref.read(cognitoAuthServiceProvider);
        debugPrint('🔐 CognitoAuthService created successfully');

        // Initialize and check authentication status
        await cognito.initialize();
        if (cognito.isAuthenticated) {
          debugPrint('🔐 AWS: User is authenticated, loading driver data');
          await _loadCurrentDriver(useAWS: true, cognitoService: cognito);
        } else {
          debugPrint('🔐 AWS: User is not authenticated');
          _setLoading(false);
        }
      } else {
        await AuthService.initialize();
        debugPrint('🔐 AuthService initialized successfully');

        if (AuthService.isAuthenticated) {
          debugPrint('🔐 User is authenticated, loading driver data');
          await _loadCurrentDriver(useAWS: false);
        } else {
          debugPrint('🔐 User is not authenticated');
          _setLoading(false);
        }
      }
    } catch (e) {
      debugPrint('❌ AuthProvider initialization error: $e');
      _setError('خطأ في تهيئة التطبيق: ${e.toString()}');
      _setLoading(false);
    }
  }

  /// Load current driver data and initialize real-time services
  Future<void> _loadCurrentDriver({
    bool useAWS = false,
    dynamic cognitoService,
  }) async {
    debugPrint('👤 Loading current driver data...');
    try {
      Map<String, dynamic> result;
      if (useAWS) {
        // Use DriverService which handles AWS integration properly
        final driverProfile = await DriverService.getDriverProfile();
        if (driverProfile != null) {
          result = {
            'success': true,
            'data': {
              'id': driverProfile.id,
              'name': driverProfile.name,
              'phone': driverProfile.phone,
              'email': driverProfile.email,
              'city': driverProfile.city,
              'status': driverProfile.status,
            }
          };
        } else {
          result = {'success': false, 'message': 'No profile found'};
        }
      } else {
        result = await AuthService.getCurrentDriver();
      }

      if (result['success']) {
        final driverData = result['data'];
        state = state.copyWith(
          currentDriver: driverData,
          isAuthenticated: true,
          errorMessage: null,
        );
        debugPrint('✅ Driver data loaded successfully');

        // Initialize real-time communication service after successful authentication
        final token = useAWS
            ? (cognitoService?.authToken ?? AuthService.authToken)
            : AuthService.authToken;
        await _initializeRealtimeServices(authToken: token);
      } else {
        state = state.copyWith(
          isAuthenticated: false,
          currentDriver: null,
          errorMessage: result['message'],
        );
        debugPrint('❌ Failed to load driver data: ${result['message']}');
      }
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        currentDriver: null,
        errorMessage: 'خطأ في جلب بيانات السائق: ${e.toString()}',
      );
      debugPrint('❌ Error loading driver data: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Initialize real-time communication services after authentication
  Future<void> _initializeRealtimeServices({String? authToken}) async {
    final driver = state.currentDriver;
    if (driver == null) return;

    try {
      debugPrint('🚀 Initializing real-time communication services...');

      final realtimeService = RealtimeCommunicationService();
      await realtimeService.initialize(
        driverId: driver['id'] ?? 'driver_123',
        driverName: driver['name'] ?? 'Unknown Driver',
        driverPhone: driver['phone'] ?? '+964 770 123 4567',
        authToken: authToken ?? AuthService.authToken ?? 'mock_token',
      );

      debugPrint('✅ Real-time communication services initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize real-time services: $e');
      // Don't fail authentication if real-time services fail to initialize
    }
  }

  /// Check if current driver profile is incomplete and needs setup
  bool get needsProfileCompletion {
    final driver = state.currentDriver;
    if (driver == null) return false;

    final status = driver['status'] as String?;
    final name = driver['name'] as String?;
    final city = driver['city'] as String?;
    final vehicleType = driver['vehicle_type'] as String?;

    // Profile is incomplete if:
    // 1. Status is PENDING_PROFILE
    // 2. Required fields are missing
    final isIncomplete =
        status == 'PENDING_PROFILE' ||
        name == null ||
        name.isEmpty ||
        city == null ||
        city.isEmpty ||
        vehicleType == null ||
        vehicleType.isEmpty;

    debugPrint(
      '🔍 Profile completion check: status=$status, incomplete=$isIncomplete',
    );
    return isIncomplete;
  }

  /// Login with phone and password
  Future<bool> login({required String phone, required String password}) async {
    debugPrint('🔐 AuthProvider: Login attempt for phone: $phone');
    _setLoading(true);
    _clearError();

    try {
      final result = await AuthService.login(phone: phone, password: password);

      if (result['success']) {
        debugPrint('✅ Login successful, loading driver data');
        await _loadCurrentDriver();
        return true;
      } else {
        _setError(result['message']);
        debugPrint('❌ Login failed: ${result['message']}');
        return false;
      }
    } catch (e) {
      _setError('خطأ في تسجيل الدخول: ${e.toString()}');
      debugPrint('❌ Login error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Register a new driver
  Future<bool> register({
    required String name,
    required String phone,
    required String password,
    required String city,
    required String vehicleType,
    required String licenseNumber,
    required String nationalId,
  }) async {
    _setLoading(true);
    _clearError();

  try {
    final result = await AuthService.register(
      name: name,
      phone: phone,
      password: password,
      city: city,
      vehicleType: vehicleType,
      licenseNumber: licenseNumber,
      nationalId: nationalId,
    );

    if (result['success']) {
      return true;
    } else {
      _setError(result['message']);
      return false;
    }
  } catch (e) {
    _setError('خطأ في إنشاء الحساب: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Verify phone number with OTP code
  Future<bool> verifyPhone({
    required String phone,
    required String code,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await AuthService.verifyPhone(phone: phone, code: code);

      if (result['success']) {
        // After successful verification, load current driver data
        await _loadCurrentDriver();
        return true;
      } else {
        _setError(result['message']);
        return false;
      }
    } catch (e) {
      _setError('خطأ في التحقق من رقم الهاتف: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Request password reset
  Future<bool> requestPasswordReset({required String phone}) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await AuthService.requestPasswordReset(phone: phone);

      if (result['success']) {
        return true;
      } else {
        _setError(result['message']);
        return false;
      }
    } catch (e) {
      _setError('خطأ في طلب إعادة تعيين كلمة المرور: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Reset password with verification code
  Future<bool> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await AuthService.resetPassword(
        phone: phone,
        code: code,
        newPassword: newPassword,
      );

      if (result['success']) {
        return true;
      } else {
        _setError(result['message']);
        return false;
      }
    } catch (e) {
      _setError('خطأ في إعادة تعيين كلمة المرور: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Logout the current user
  Future<void> logout() async {
    _setLoading(true);

    try {
      await AuthService.logout();
      state = const AuthState();
    } catch (e) {
      _setError('خطأ في تسجيل الخروج: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void _setError(String? error) {
    state = state.copyWith(errorMessage: error);
  }

  void _clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
