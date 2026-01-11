// Profile Completion Service
// Checks and tracks driver profile completion status
// Version: 1.0
// Date: 2025-10-18

import 'package:flutter/foundation.dart';
import '../models/profile_status.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../config/environment.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service to manage and check profile completion status
class ProfileCompletionService {

  ProfileCompletionService();

  /// Check if the current user's profile is complete
  /// Returns ProfileStatus with completion details
  Future<ProfileStatus> checkProfileCompleteness() async {
    try {
      debugPrint('🔍 ProfileCompletionService: Checking profile completeness');

      // Get auth session
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      if (!session.isSignedIn) {
        debugPrint('⚠️ ProfileCompletionService: User not signed in');
        return ProfileStatus(
          exists: false,
          status: ProfileStatusEnum.pendingProfile,
          isComplete: false,
          missingFields: ['auth'],
          needsRedirect: true,
          redirectPath: '/driver-profile-setup',
        );
      }

      final tokens = session.userPoolTokensResult.value;
      final accessToken = tokens.accessToken.raw;

      // Make HTTP request to driver profile API
      final response = await http.get(
        Uri.parse('${Environment.apiBaseUrl}/driver/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('🌐 ProfileCompletionService: API Response status: ${response.statusCode}');
      debugPrint('🌐 ProfileCompletionService: API Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        debugPrint('🔍 DEBUG: Full response: $responseData');
        
        // Extract profile data from API response
        Map<String, dynamic> profile;
        if (responseData is Map && responseData.containsKey('data')) {
          profile = responseData['data'] as Map<String, dynamic>;
        } else {
          profile = responseData as Map<String, dynamic>;
        }
        
        debugPrint('🔍 DEBUG: profile keys: ${profile.keys}');
        debugPrint('🔍 DEBUG: profile status value: ${profile['status']}');
        debugPrint('ProfileCompletionService: Profile found: ${profile['status']}');

        // Extract status
        final statusString = profile['status'] as String? ?? 'PENDING_PROFILE';
        final statusEnum = _parseProfileStatus(statusString);

        // Check required fields
        final missingFields = _getMissingFields(profile);
        
        debugPrint('🔍 ProfileCompletionService: Status enum: $statusEnum');
        debugPrint('🔍 ProfileCompletionService: Missing fields: $missingFields');
        
        // Profile is complete if status is Active/PendingReview
        final isComplete = statusEnum == ProfileStatusEnum.active ||
            statusEnum == ProfileStatusEnum.pendingReview ||
            missingFields.isEmpty;
            statusEnum == ProfileStatusEnum.pendingReview ||
            missingFields.isEmpty;

        // Determine if redirect is needed
        final needsRedirect = 
            statusEnum == ProfileStatusEnum.pendingProfile ||
            statusEnum == ProfileStatusEnum.pendingDocs;
            
        debugPrint('✅ ProfileCompletionService: isComplete: $isComplete, needsRedirect: $needsRedirect');

        return ProfileStatus(
          exists: true,
          status: statusEnum,
          isComplete: isComplete,
          missingFields: missingFields,
          needsRedirect: needsRedirect,
          redirectPath: needsRedirect ? '/driver-profile-setup' : null,
          profileData: profile,
        );
      } else {
        debugPrint('❌ ProfileCompletionService: API error: ${response.statusCode} - ${response.body}');
        
        // For 404, assume no profile exists
        if (response.statusCode == 404) {
          return ProfileStatus(
            exists: false,
            status: ProfileStatusEnum.pendingProfile,
            isComplete: false,
            missingFields: ['all'],
            needsRedirect: true,
            redirectPath: '/driver-profile-setup',
          );
        }
        
        // For other errors, return error status
        return ProfileStatus(
          exists: false,
          status: ProfileStatusEnum.pendingProfile,
          isComplete: false,
          missingFields: ['api_error'],
          needsRedirect: true,
          redirectPath: '/driver-profile-setup',
          error: 'API Error: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('❌ ProfileCompletionService: Error checking profile: $e');

      // On error, assume profile needs to be completed to be safe
      return ProfileStatus(
        exists: false,
        status: ProfileStatusEnum.pendingProfile,
        isComplete: false,
        missingFields: ['unknown'],
        needsRedirect: true,
        redirectPath: '/driver-profile-setup',
        error: e.toString(),
      );
    }
  }

  /// Get list of missing required fields
  List<String> _getMissingFields(Map<String, dynamic> profile) {
    final missing = <String>[];

    // Check required basic fields
    if (_isNullOrEmpty(profile['name'])) missing.add('name');
    if (_isNullOrEmpty(profile['city'])) missing.add('city');
    if (_isNullOrEmpty(profile['vehicleType'])) missing.add('vehicleType');
    if (_isNullOrEmpty(profile['licenseNumber'])) missing.add('licenseNumber');
    if (_isNullOrEmpty(profile['nationalId'])) missing.add('nationalId');
    if (_isNullOrEmpty(profile['drivingLicenseUrl'])) {
      missing.add('drivingLicenseUrl');
    }

    // Check registration paper (required for car/motorcycle)
    final vehicleType = profile['vehicleType'] as String?;
    if ((vehicleType == 'car' || vehicleType == 'motorcycle') &&
        _isNullOrEmpty(profile['registrationPaperUrl'])) {
      missing.add('registrationPaperUrl');
    }

    return missing;
  }

  /// Check if value is null or empty string
  bool _isNullOrEmpty(dynamic value) {
    return value == null || (value is String && value.isEmpty);
  }

  /// Parse profile status string to enum
  ProfileStatusEnum _parseProfileStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING_PROFILE':
        return ProfileStatusEnum.pendingProfile;
      case 'PENDING_DOCS':
        return ProfileStatusEnum.pendingDocs;
      case 'PENDING_REVIEW':
        return ProfileStatusEnum.pendingReview;
      case 'ACTIVE':
        return ProfileStatusEnum.active;
      case 'SUSPENDED':
        return ProfileStatusEnum.suspended;
      case 'REJECTED':
        return ProfileStatusEnum.rejected;
      default:
        debugPrint('⚠️ Unknown status: $status, defaulting to PENDING_PROFILE');
        return ProfileStatusEnum.pendingProfile;
    }
  }

  /// Update profile status
  Future<bool> updateProfileStatus(ProfileStatusEnum status) async {
    try {
      debugPrint('🔄 ProfileCompletionService: Updating status to $status');

      // Get auth session
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      if (!session.isSignedIn) {
        debugPrint('⚠️ ProfileCompletionService: User not signed in');
        return false;
      }

      final tokens = session.userPoolTokensResult.value;
      final accessToken = tokens.accessToken.raw;
      final statusString = _profileStatusToString(status);

      // Make HTTP PUT request to update profile
      final response = await http.put(
        Uri.parse('${Environment.apiBaseUrl}/driver/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'status': statusString,
        }),
      );

      final success = response.statusCode == 200;

      if (success) {
        debugPrint('✅ ProfileCompletionService: Status updated to $statusString');
      } else {
        debugPrint('❌ ProfileCompletionService: Failed to update status: ${response.statusCode}');
      }

      return success;
    } catch (e) {
      debugPrint('❌ ProfileCompletionService: Error updating status: $e');
      return false;
    }
  }

  /// Convert enum to string
  String _profileStatusToString(ProfileStatusEnum status) {
    switch (status) {
      case ProfileStatusEnum.pendingProfile:
        return 'PENDING_PROFILE';
      case ProfileStatusEnum.pendingDocs:
        return 'PENDING_DOCS';
      case ProfileStatusEnum.pendingReview:
        return 'PENDING_REVIEW';
      case ProfileStatusEnum.active:
        return 'ACTIVE';
      case ProfileStatusEnum.suspended:
        return 'SUSPENDED';
      case ProfileStatusEnum.rejected:
        return 'REJECTED';
    }
  }

  /// Check if user can access main app
  Future<bool> canAccessMainApp() async {
    final status = await checkProfileCompleteness();

    // Only ACTIVE users can access main app
    final canAccess =
        status.isComplete && status.status == ProfileStatusEnum.active;

    debugPrint('🔐 ProfileCompletionService: Can access main app: $canAccess');

    return canAccess;
  }

  /// Get user's phone number from profile
  Future<String?> getPhoneNumber() async {
    try {
      // Get auth session
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      if (!session.isSignedIn) return null;

      final tokens = session.userPoolTokensResult.value;
      final accessToken = tokens.accessToken.raw;

      final response = await http.get(
        Uri.parse('${Environment.apiBaseUrl}/driver/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final profile = responseData['data'] ?? responseData;
        return profile['phoneNumber'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('❌ ProfileCompletionService: Error getting phone: $e');
      return null;
    }
  }

  /// Get user's email from profile
  Future<String?> getEmail() async {
    try {
      // Get auth session
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      if (!session.isSignedIn) return null;

      final tokens = session.userPoolTokensResult.value;
      final accessToken = tokens.accessToken.raw;

      final response = await http.get(
        Uri.parse('${Environment.apiBaseUrl}/driver/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final profile = responseData['data'] ?? responseData;
        return profile['email'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('❌ ProfileCompletionService: Error getting email: $e');
      return null;
    }
  }

  /// Get registration method (phone or email)
  Future<String?> getRegistrationMethod() async {
    try {
      // Get auth session
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      if (!session.isSignedIn) return 'phone';

      final tokens = session.userPoolTokensResult.value;
      final accessToken = tokens.accessToken.raw;

      final response = await http.get(
        Uri.parse('${Environment.apiBaseUrl}/driver/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final profile = responseData['data'] ?? responseData;
        return profile['registrationMethod'] as String? ?? 'phone';
      }
      return 'phone';
    } catch (e) {
      debugPrint('❌ ProfileCompletionService: Error getting registration method: $e');
      return 'phone'; // Default to phone
    }
  }
}
