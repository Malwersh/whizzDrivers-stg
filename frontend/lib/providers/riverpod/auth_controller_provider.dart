import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

import '../../services/cognito_auth_service_enhanced.dart';

// Simple provider for auth controller without code generation
final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController();
});

class AuthController {
  /// Sign in with phone number and handle unconfirmed users
  Future<void> signInWithPhone({
    required String phoneNumber,
    String? password,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(AuthException e) onError,
    required Function() onVerificationCompleted,
    bool isRegistration = false,
  }) async {
    try {
      final cognitoService = CognitoAuthServiceEnhanced();

      // For registration, we use the registration flow
      if (isRegistration) {
        debugPrint(
          '🔄 AuthController: Registration flow - generating verification code',
        );

        // In registration flow, we don't try to sign in, we just trigger SMS
        // The actual registration happens after phone verification
        // For now, simulate code sent
        onCodeSent('mock-verification-id', null);
        return;
      }

      // For login flow, try to sign in first
      debugPrint('🔄 AuthController: Login flow - attempting sign in');

      if (password == null || password.isEmpty) {
        throw const InvalidParameterException('Password is required for login');
      }

      final result = await cognitoService.loginWithPhoneDetailed(
        phone: phoneNumber,
        password: password,
      );

      if (result['success'] == true) {
        debugPrint('✅ AuthController: Login successful');
        onVerificationCompleted();
        return;
      }

      // Check if the error is due to unconfirmed user
      final errorMessage = result['message'] ?? '';
      final errorCode = result['error_code'] ?? '';
      final error = result['error'] ?? '';

      debugPrint('🔍 AuthController: Login failed');
      debugPrint('   Error message: $errorMessage');
      debugPrint('   Error code: $errorCode');
      debugPrint('   Error: $error');

      // Check for unconfirmed user scenarios
      if (_isUnconfirmedUserError(errorMessage, errorCode, error)) {
        debugPrint(
          '🎯 AuthController: User is unconfirmed - redirecting to verification',
        );

        // Send verification code to the unconfirmed user
        await _resendVerificationCodeForUnconfirmedUser(phoneNumber);

        // Trigger the verification flow
        onCodeSent('unconfirmed-user-verification', null);
        return;
      }

      // Handle other login errors
      throw InvalidParameterException(errorMessage);
    } catch (e) {
      debugPrint('❌ AuthController: Sign in error: $e');

      if (e is AuthException) {
        // Check if this is an unconfirmed user error from Amplify
        if (_isAmplifyUnconfirmedUserError(e)) {
          debugPrint(
            '🎯 AuthController: Amplify unconfirmed user - redirecting to verification',
          );

          try {
            // Try to resend verification code
            await _resendVerificationCodeForUnconfirmedUser(phoneNumber);
            onCodeSent('unconfirmed-user-verification', null);
            return;
          } catch (resendError) {
            debugPrint(
              '⚠️ AuthController: Could not resend verification code: $resendError',
            );
          }
        }
        onError(e);
      } else {
        onError(InvalidParameterException(e.toString()));
      }
    }
  }

  /// Check if the error indicates an unconfirmed user from our backend
  bool _isUnconfirmedUserError(String message, String errorCode, String error) {
    final msg = message.toLowerCase();
    final code = errorCode.toLowerCase();
    final err = error.toLowerCase();

    return msg.contains('not confirmed') ||
        msg.contains('unconfirmed') ||
        msg.contains('غير مؤكد') ||
        code.contains('usernotconfirmed') ||
        err.contains('not confirmed');
  }

  /// Check if this is an Amplify unconfirmed user error
  bool _isAmplifyUnconfirmedUserError(AuthException e) {
    return e.message.toLowerCase().contains('user is not confirmed') ||
        e.message.toLowerCase().contains('usernotconfirmed');
  }

  /// Resend verification code for unconfirmed user
  Future<void> _resendVerificationCodeForUnconfirmedUser(String phoneNumber) async {
    try {
      final cognitoService = CognitoAuthServiceEnhanced();
      await cognitoService.resendConfirmationCode(username: phoneNumber);
      debugPrint('✅ AuthController: Verification code resent successfully');
    } catch (e) {
      debugPrint('❌ AuthController: Failed to resend verification code: $e');
      rethrow;
    }
  }

  /// Register with phone number - TEMPORARILY DISABLED
  /*
  Future<void> registerWithPhone({
    required String phoneNumber,
    required String password,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(AuthException e) onError,
    required Function() onRegistrationCompleted,
  }) async {
    try {
      debugPrint('🔄 AuthController: Starting phone registration');

      final cognitoService = CognitoAuthServiceEnhanced();
      
      // Temporarily disabled - need to add required parameters
      final result = <String, dynamic>{'success': false, 'message': 'Registration temporarily disabled'};
      
      /*
      final result = await cognitoService.registerWithPhone(
        phone: phoneNumber,
        password: password,
        city: 'Baghdad', // Required parameter
        name: 'Test User', // Required parameter
        // Need to add other required parameters
      );
      */

      if (result['success'] == true) {
        debugPrint('✅ AuthController: Registration initiated - code sent');
        onCodeSent('registration-verification', null);
      } else {
        final errorMessage = result['message'] ?? 'Registration failed';
        throw InvalidParameterException(errorMessage);
      }
    } catch (e) {
      debugPrint('❌ AuthController: Registration error: $e');
      if (e is AuthException) {
        onError(e);
      } else {
        onError(InvalidParameterException(e.toString()));
      }
    }
  }
  */

  /// Confirm phone verification code - TEMPORARILY DISABLED
  /*
  Future<bool> confirmPhoneVerification({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    try {
      debugPrint('🔄 AuthController: Confirming phone verification');
      
      final cognitoService = CognitoAuthServiceEnhanced();
      
      final result = await cognitoService.confirmRegistration(
        username: phoneNumber,
        confirmationCode: verificationCode,
      );

      if (result['success'] == true) {
        debugPrint('✅ AuthController: Phone verification confirmed');
        return true;
      } else {
        debugPrint('❌ AuthController: Phone verification failed: ${result['message']}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ AuthController: Confirmation error: $e');
      return false;
    }
  }
  */
}
