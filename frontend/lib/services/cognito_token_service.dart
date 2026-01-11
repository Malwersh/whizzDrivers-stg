import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';

import '../config/environment.dart';
import 'aws_dynamodb_service.dart';

/// Service to extract Cognito JWT tokens and configure AWS services
class CognitoTokenService {
  static String? _cachedAccessToken;
  static DateTime? _tokenCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  /// Get the current Cognito access token
  static Future<String?> getAccessToken() async {
    try {
      // Check cache first (valid for 5 minutes)
      if (_cachedAccessToken != null &&
          _tokenCacheTime != null &&
          DateTime.now().difference(_tokenCacheTime!) < _cacheValidDuration) {
        debugPrint('🔑 Using cached Cognito access token');
        return _cachedAccessToken;
      }

      // Fetch fresh token from Amplify
      final session = await Amplify.Auth.fetchAuthSession();

      if (!session.isSignedIn) {
        debugPrint('❌ User is not signed in to Cognito');
        return null;
      }

      if (session is CognitoAuthSession) {
        final tokens = session.userPoolTokensResult.value;
        final accessToken = tokens.accessToken.raw;

        // Cache the token
        _cachedAccessToken = accessToken;
        _tokenCacheTime = DateTime.now();

        debugPrint('✅ Retrieved fresh Cognito access token');
        return accessToken;
      } else {
        debugPrint('❌ Auth session is not a Cognito session');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Failed to get Cognito access token: $e');
      return null;
    }
  }

  /// Get the current Cognito ID token (required for WebSocket authentication)
  static Future<String?> getIdToken() async {
    try {
      // Fetch fresh token from Amplify
      final session = await Amplify.Auth.fetchAuthSession();

      if (!session.isSignedIn) {
        debugPrint('❌ User is not signed in to Cognito');
        return null;
      }

      if (session is CognitoAuthSession) {
        final tokens = session.userPoolTokensResult.value;
        final idToken = tokens.idToken.raw;

        debugPrint('✅ Retrieved fresh Cognito ID token');
        return idToken;
      } else {
        debugPrint('❌ Auth session is not a Cognito session');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Failed to get Cognito ID token: $e');
      return null;
    }
  }

  /// Configure AWS DynamoDB service with current auth token
  static Future<bool> configureAWSServices() async {
    try {
      final accessToken = await getAccessToken();

      if (accessToken == null) {
        debugPrint('❌ Cannot configure AWS services - no access token');
        debugPrint(
          '💡 User may not be signed in yet. Call this after authentication.',
        );
        return false;
      }

      // Configure AWSDynamoDBService with the JWT token
      AWSDynamoDBService.configure(
        baseUrl: Environment.apiBaseUrl,
        authToken: accessToken,
      );

      debugPrint('✅ AWS services configured with Cognito access token');
      debugPrint(
        '✅ Token: ${accessToken.substring(0, 20)}...${accessToken.substring(accessToken.length - 10)}',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Failed to configure AWS services: $e');
      return false;
    }
  }

  /// Configure AWS services and retry if initial attempt fails
  /// Useful for right after login when session might not be fully established
  static Future<bool> configureAWSServicesWithRetry({
    int maxAttempts = 3,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      debugPrint(
        '🔄 Attempting to configure AWS services (attempt $attempt/$maxAttempts)',
      );

      final success = await configureAWSServices();
      if (success) {
        return true;
      }

      if (attempt < maxAttempts) {
        // Wait a bit before retrying to allow session to be established
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }

    debugPrint(
      '❌ Failed to configure AWS services after $maxAttempts attempts',
    );
    return false;
  }

  /// Clear cached token (call on logout or to force refresh)
  static void clearCache() {
    _cachedAccessToken = null;
    _tokenCacheTime = null;
    debugPrint('🗑️ Cleared Cognito token cache');
  }

  /// Force clear cache and reconfigure AWS services with fresh token
  static Future<bool> forceFreshConfiguration() async {
    debugPrint('🔄 Forcing fresh AWS configuration...');

    // Clear token cache
    clearCache();

    // Wait a moment for cache to clear
    await Future.delayed(const Duration(milliseconds: 100));

    // Get fresh token and configure AWS services
    final success = await configureAWSServicesWithRetry(maxAttempts: 3);

    if (success) {
      debugPrint('✅ Fresh AWS configuration successful');
    } else {
      debugPrint('❌ Fresh AWS configuration failed');
    }

    return success;
  }

  /// Check if user is authenticated with valid token
  static Future<bool> isAuthenticated() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session.isSignedIn;
    } catch (e) {
      debugPrint('❌ Error checking authentication status: $e');
      return false;
    }
  }
}
