import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../services/driver_websocket_service.dart';
import '../../services/aws_dynamodb_service.dart';
import '../../services/new_auth_service.dart';
import '../../services/cognito_auth_service_enhanced.dart';
import '../../services/cognito_auth_service.dart';
import '../../services/profile_completion_service.dart';
import '../../services/auth_service.dart';
import '../../services/cognito_token_service.dart';
import '../../config/environment.dart';
import '../../features/active_order/services/active_order_service.dart';
import '../../models/driver_status.dart';
import '../../config/app_config.dart';
import '../../services/logging/auth_logger.dart';
// import '../../services/wallet_service_new.dart'; // TODO: إضافة المحفظة الجديدة

/// Wrapper class for AuthService static methods (for session persistence)
class AuthServiceWrapper {
  Future<void> initialize() => AuthService.initialize();
  Future<bool> checkAuthentication() => AuthService.checkAuthentication();
  bool get isAuthenticated => AuthService.isAuthenticated;
  
  /// Logout - delegates to CognitoAuthService for proper Amplify sign out
  Future<void> logout() async {
    try {
      debugPrint('🚪 AuthServiceWrapper: Starting logout process...');

      // Best-effort: mark driver offline / stop searching on the backend BEFORE clearing auth.
      // This prevents later waves from re-offering when the driver has logged out.
      try {
        final token = await CognitoTokenService.getAccessToken();
        if (token != null && token.isNotEmpty) {
          final url = Uri.parse('${Environment.apiBaseUrl}/driver/stop-searching');
          await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'reason': 'logout'}),
          );
        }
      } catch (e) {
        debugPrint('⚠️ stop-searching on logout failed (ignored): $e');
      }
      
      // Step 1: Clear AuthService token FIRST (prevent router from seeing authenticated state)
      await AuthService.logout();
      debugPrint('✅ AuthService token cleared');
      
      // Step 2: Use CognitoAuthService for comprehensive Amplify logout
      final cognitoService = CognitoAuthService();
      await cognitoService.signOut();
      debugPrint('✅ CognitoAuthService logout completed');
      
      debugPrint('✅ Complete logout successful');
    } catch (e) {
      debugPrint('⚠️ Error during logout: $e');
      // Fallback: clear local token even if Cognito signout fails
      try {
        await AuthService.logout(); // Clear token anyway
        await Amplify.Auth.signOut();
        debugPrint('✅ Fallback logout completed');
      } catch (amplifyError) {
        debugPrint('⚠️ Fallback logout also failed: $amplifyError');
        // Last resort: force clear token
        await AuthService.logout();
      }
    }
  }
}

/// Provides a singleton instance of [DriverWebSocketService].
final driverWebSocketServiceProvider = Provider<DriverWebSocketService>((ref) {
  final service = DriverWebSocketService();
  service.attachLogger(ref.read(authLoggerProvider));
  return service;
});

/// Provides a singleton instance of [AWSDynamoDBService].
final awsDynamoDBServiceProvider = Provider<AWSDynamoDBService>((ref) {
  return AWSDynamoDBService();
});

/// Provides an instance of [NewAuthService], injecting its dependencies.
final newAuthServiceProvider = Provider<NewAuthService>((ref) {
  final wsService = ref.watch(driverWebSocketServiceProvider);
  final logger = ref.watch(authLoggerProvider);
  return NewAuthService(webSocketService: wsService, logger: logger);
});

/// Provides an instance of [CognitoAuthServiceEnhanced] for AWS Cognito authentication
final cognitoAuthServiceProvider = Provider<CognitoAuthServiceEnhanced>((ref) {
  final service = CognitoAuthServiceEnhanced();
  service.logger = ref.watch(authLoggerProvider);
  return service;
});

/// Provides AuthService static wrapper for session persistence
final authServiceProvider = Provider<AuthServiceWrapper>((ref) {
  return AuthServiceWrapper();
});

/// Provides the appropriate Cognito auth service based on configuration
final cognitoAuthServiceProviderActive = Provider<dynamic>((ref) {
  if (AppConfig.enableAWSIntegration) {
    return ref.watch(cognitoAuthServiceProvider);
  } else {
    return ref.watch(newAuthServiceProvider);
  }
});

/// Provides driver status state management
final driverStatusProvider = StateProvider<DriverStatus>((ref) {
  return DriverStatus.offline;
});

/// Provides a singleton instance of [AuthLogger]
final authLoggerProvider = Provider<AuthLogger>((ref) {
  return AuthLogger();
});

/// Provides a singleton instance of [ProfileCompletionService]
final profileCompletionServiceProvider = Provider<ProfileCompletionService>((ref) {
  // Using real HTTP API service instead of DynamoDB
  return ProfileCompletionService();
});

// TODO: إضافة walletServiceProvider بعد بناء المحفظة الجديدة

/// Provides a singleton instance of [ActiveOrderService]
final activeOrderServiceProvider = Provider<ActiveOrderService>((ref) {
  return ActiveOrderService();
});

// NOTE: unifiedWebSocketServiceProvider was removed here to avoid duplication.
// See `driver_connection_provider.dart` for the active implementation & disposal logic.
