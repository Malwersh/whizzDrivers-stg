// Driver Authentication Provider
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

/// Provider for current driver ID
final currentDriverIdProvider = FutureProvider<String?>((ref) async {
  try {
    // Try to get driver ID from SharedPreferences first
    final prefs = await SharedPreferences.getInstance();
    
    // Check if we have stored driver ID
    String? driverId = prefs.getString('driver_id');
    if (driverId != null && driverId.isNotEmpty) {
      return driverId;
    }
    
    // Try to get from access token
    final accessToken = prefs.getString('access_token');
    if (accessToken != null && !JwtDecoder.isExpired(accessToken)) {
      try {
        final decoded = JwtDecoder.decode(accessToken);
        driverId = decoded['sub'] ?? decoded['cognito:username'] ?? decoded['username'];
        
        if (driverId != null) {
          // Store for future use
          await prefs.setString('driver_id', driverId);
          return driverId;
        }
      } catch (e) {
        // JWT decode failed
      }
    }
    
    // Try to get from user preferences or other sources
    // (Skip DynamoDB for now as getDriverData method doesn't exist)
    
    // If we have a decoded JWT, use that as driver ID
    if (driverId != null) {
      await prefs.setString('driver_id', driverId);
      return driverId;
    }
    
    return null;
  } catch (e) {
    return null;
  }
});

/// Provider for current driver authentication status
final driverAuthStatusProvider = FutureProvider<bool>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    
    if (accessToken == null) return false;
    
    // Check if token is expired
    if (JwtDecoder.isExpired(accessToken)) {
      return false;
    }
    
    return true;
  } catch (e) {
    return false;
  }
});

/// Provider for current access token
final driverAccessTokenProvider = FutureProvider<String?>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    
    if (accessToken != null && !JwtDecoder.isExpired(accessToken)) {
      return accessToken;
    }
    
    return null;
  } catch (e) {
    return null;
  }
});

/// Helper class for driver authentication operations
class DriverAuthHelper {
  /// Get current driver ID from any available source
  static Future<String?> getCurrentDriverId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check stored driver ID first
      String? driverId = prefs.getString('driver_id');
      if (driverId != null && driverId.isNotEmpty) {
        return driverId;
      }
      
      // Try from access token
      final accessToken = prefs.getString('access_token');
      if (accessToken != null && !JwtDecoder.isExpired(accessToken)) {
        try {
          final decoded = JwtDecoder.decode(accessToken);
          driverId = decoded['sub'] ?? decoded['cognito:username'] ?? decoded['username'];
          
          if (driverId != null) {
            await prefs.setString('driver_id', driverId);
            return driverId;
          }
        } catch (e) {
          // Ignore JWT decode error
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Get current access token from Amplify session
  static Future<String?> getCurrentAccessToken() async {
    try {
      // Get token from Amplify Auth Session
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final accessToken = session.userPoolTokensResult.value.accessToken.raw;
      
      if (accessToken.isNotEmpty) {
        // Optional: cache it in SharedPreferences for offline detection
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        return accessToken;
      }
      
      // Fallback: try SharedPreferences (for offline scenarios)
      final prefs = await SharedPreferences.getInstance();
      final cachedToken = prefs.getString('access_token');
      
      if (cachedToken != null && !JwtDecoder.isExpired(cachedToken)) {
        return cachedToken;
      }
      
      return null;
    } catch (e) {
      // If Amplify fails, try cached token
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedToken = prefs.getString('access_token');
        
        if (cachedToken != null && !JwtDecoder.isExpired(cachedToken)) {
          return cachedToken;
        }
      } catch (_) {
        // Ignore
      }
      
      return null;
    }
  }
  
  /// Check if driver is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await getCurrentAccessToken();
    return token != null;
  }
}
