import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

/// Helper class to get driver authentication token
/// 
/// Provides easy access to JWT token for API calls
class DriverAuthHelper {
  /// Get current access token from Amplify
  /// Returns null if not authenticated
  static Future<String?> getCurrentAccessToken() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession() 
          as CognitoAuthSession;
      
      if (session.isSignedIn) {
        final accessToken = session.userPoolTokensResult.value.accessToken.raw;
        return accessToken;
      }
      
      return null;
    } catch (e) {
      print('Error getting access token: $e');
      return null;
    }
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session.isSignedIn;
    } catch (e) {
      print('Error checking authentication: $e');
      return false;
    }
  }

  /// Get current user ID (sub from Cognito)
  static Future<String?> getCurrentUserId() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      final subAttr = attributes.firstWhere(
        (attr) => attr.userAttributeKey == CognitoUserAttributeKey.sub,
      );
      return subAttr.value;
    } catch (e) {
      print('Error getting user ID: $e');
      return null;
    }
  }
}
