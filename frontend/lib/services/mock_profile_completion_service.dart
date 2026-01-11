// Mock Profile Service للاختبار
// يحاكي وجود ملف شخصي مكتمل للسائق المسجل دخوله

import 'package:flutter/foundation.dart';
import '../models/profile_status.dart';
import 'profile_completion_service.dart';

class MockProfileCompletionService extends ProfileCompletionService {
  MockProfileCompletionService() : super();
  /// Mock service that always returns complete profile
  /// Used for testing when driver profile API is not accessible
  @override
  Future<ProfileStatus> checkProfileCompleteness() async {
    try {
      debugPrint('🎭 MockProfileCompletionService: Returning complete profile');
      
      // Simulate a complete active driver profile
      return ProfileStatus(
        exists: true,
        status: ProfileStatusEnum.active,
        isComplete: true,
        missingFields: [],
        needsRedirect: false,
        redirectPath: null,
        profileData: {
          'status': 'ACTIVE',
          'name': 'سائق تجريبي',
          'city': 'بغداد',
          'vehicleType': 'دراجة نارية',
          'licenseNumber': '123456',
          'nationalId': '123456789',
        },
      );
    } catch (e) {
      debugPrint('❌ MockProfileCompletionService: Error: $e');
      
      // Even on error, return complete profile for testing
      return ProfileStatus(
        exists: true,
        status: ProfileStatusEnum.active,
        isComplete: true,
        missingFields: [],
        needsRedirect: false,
        redirectPath: null,
      );
    }
  }
  
  /// Mock method for profile update
  Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    debugPrint('🎭 MockProfileCompletionService: Mock profile update');
    return true;
  }
}