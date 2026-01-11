// Profile Completion Service Provider
// Riverpod provider for profile completion checking
// Version: 1.0
// Date: 2025-10-18

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/profile_completion_service.dart';
import '../../models/profile_status.dart';

/// Provider for ProfileCompletionService
final profileCompletionServiceProvider = Provider<ProfileCompletionService>((
  ref,
) {
  return ProfileCompletionService();
});

/// Provider to check profile completion status
/// This is a FutureProvider that will be watched by the UI
final profileStatusProvider = FutureProvider<ProfileStatus>((ref) async {
  final service = ref.watch(profileCompletionServiceProvider);
  return await service.checkProfileCompleteness();
});

/// Provider to check if user can access main app
final canAccessMainAppProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(profileCompletionServiceProvider);
  return await service.canAccessMainApp();
});
