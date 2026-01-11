import 'dart:async';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';

/// Authentication Helper for Live Chat WebSocket
/// Ensures proper JWT token authentication before WebSocket connection
class LiveChatAuthHelper {
  static const Duration _tokenRefreshThreshold = Duration(minutes: 5);

  static String? _cachedToken;
  static DateTime? _tokenExpiryTime;

  /// Get a valid JWT token for WebSocket authentication
  static Future<String?> getValidAuthToken() async {
    try {
      debugPrint('🔐 LiveChatAuthHelper: Getting valid auth token...');

      // Check if we have a cached token that's still valid
      if (_isCachedTokenValid()) {
        debugPrint('✅ Using cached JWT token');
        return _cachedToken;
      }

      // Fetch fresh token from Amplify
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;

      if (!session.isSignedIn) {
        debugPrint('❌ User not authenticated - cannot get JWT token');
        // For testing purposes, return a mock token if in debug mode
        if (kDebugMode) {
          debugPrint('🧪 DEBUG MODE: Using mock JWT token for testing');
          return _getMockJwtToken();
        }
        return null;
      }

      final tokens = session.userPoolTokensResult.value;
      final accessToken = tokens.accessToken.raw;

      // Cache the token with expiry time
      _cachedToken = accessToken;
      _tokenExpiryTime = DateTime.now().add(_tokenRefreshThreshold);

      debugPrint('✅ Fresh JWT token obtained (${accessToken.length} chars)');
      return accessToken;
    } catch (e) {
      debugPrint('❌ Error getting auth token: $e');
      // For testing purposes, return a mock token if in debug mode
      if (kDebugMode) {
        debugPrint('🧪 DEBUG MODE: Using mock JWT token due to error');
        return _getMockJwtToken();
      }
      return null;
    }
  }

  /// Check if the cached token is still valid
  static bool _isCachedTokenValid() {
    if (_cachedToken == null || _tokenExpiryTime == null) {
      return false;
    }

    final now = DateTime.now();
    final isValid = now.isBefore(_tokenExpiryTime!);

    if (!isValid) {
      debugPrint('🔄 Cached token expired, refreshing...');
    }

    return isValid;
  }

  /// Clear cached authentication data
  static void clearAuthCache() {
    _cachedToken = null;
    _tokenExpiryTime = null;
    debugPrint('🧹 Auth cache cleared');
  }

  /// Check if user is authenticated and token is available
  static Future<bool> isAuthenticated() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final isSignedIn = session.isSignedIn;

      if (isSignedIn) {
        debugPrint('✅ User is authenticated with Amplify Cognito');
        return true;
      } else {
        debugPrint('❌ User is not signed in to Amplify');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error checking authentication: $e');
      // For testing purposes, return true if in debug mode
      if (kDebugMode && !kReleaseMode) {
        debugPrint('🧪 DEBUG MODE: Simulating authenticated user');
        return true;
      }
      return false;
    }
  }

  /// Get authentication diagnostics
  static Future<Map<String, dynamic>> getAuthDiagnostics() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;

      Map<String, dynamic> diagnostics = {
        'isSignedIn': session.isSignedIn,
        'hasCachedToken': _cachedToken != null,
        'tokenExpiryTime': _tokenExpiryTime?.toIso8601String(),
        'tokenLength': _cachedToken?.length ?? 0,
        'timeUntilExpiry': _tokenExpiryTime
            ?.difference(DateTime.now())
            .inMinutes,
        'debugMode': kDebugMode,
        'authMethod': 'amplify_cognito',
      };

      if (session.isSignedIn) {
        try {
          final tokens = session.userPoolTokensResult.value;
          final accessToken = tokens.accessToken.raw;

          diagnostics.addAll({
            'tokenFromAmplify': true,
            'amplifyTokenLength': accessToken.length,
            'userSub': session.userSubResult.value,
            'identityId': session.identityIdResult.value,
          });
        } catch (e) {
          diagnostics['amplifyTokenError'] = e.toString();
        }
      }

      return diagnostics;
    } catch (e) {
      return {
        'error': e.toString(),
        'isSignedIn': false,
        'hasCachedToken': false,
        'debugMode': kDebugMode,
      };
    }
  }

  /// Get a mock JWT token for testing purposes
  static String _getMockJwtToken() {
    // Create a mock JWT token that matches the expected format
    // This is for testing only and should not be used in production
    const header = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9';
    const payload =
        'eyJzdWIiOiJ0ZXN0LWRyaXZlci0wMDEiLCJlbWFpbCI6InRlc3RAZXhhbXBsZS5jb20iLCJjb2duaXRvOnVzZXJuYW1lIjoidGVzdC1kcml2ZXItMDAxIiwidG9rZW5fdXNlIjoiYWNjZXNzIiwic2NvcGUiOiJhd3MuY29nbml0by5zaWduaW4udXNlci5hZG1pbiIsImF1dGhfdGltZSI6MTY5NjEyMzQ1MCwiZXhwIjoxNjk2MTIzNDUwLCJpYXQiOjE2OTYxMjM0NTAsImp0aSI6InRlc3Qtand0LTEiLCJjbGllbnRfaWQiOiI3czNydmNuUDM0ZnIySnA1NGpta3NieWQwcyIsInVzZXJuYW1lIjoidGVzdC1kcml2ZXItMDAxIn0';
    const signature = 'mock_signature_for_testing_only';

    return '$header.$payload.$signature';
  }
}
