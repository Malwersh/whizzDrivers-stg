import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/profile_status.dart';

void main() {
  for (final status in ['APPROVED', 'VERIFIED', 'ACTIVE', 'approved']) {
    test('$status routes a complete profile into the app', () {
      final profile = ProfileStatus.fromJson({
        'profileExists': true,
        'status': status,
        'isComplete': true,
      });
      expect(profile.status, ProfileStatusEnum.active);
      expect(profile.canAccessMainApp, isTrue);
      expect(profile.needsRedirect, isFalse);
    });
  }
  for (final status in ['PENDING_REVIEW', 'SUSPENDED', 'REJECTED']) {
    test('$status does not grant access to the app', () {
      final profile = ProfileStatus.fromJson({
        'profileExists': true,
        'status': status,
        'isComplete': true,
      });
      expect(profile.canAccessMainApp, isFalse);
    });
  }
}
