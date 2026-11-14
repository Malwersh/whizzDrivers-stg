import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/session_validation_policy.dart';
void main() {
  test('network loss does not delete persisted credentials', () {
    for (final error in ['SocketException','TimeoutException','NetworkException','UnknownException']) {
      expect(definitiveSessionRejection(error), isFalse);
    }
  });
  test('authoritative removed or expired identity clears persisted credentials', () {
    for (final error in ['UserNotFoundException','NotAuthorizedServiceException','SignedOutException','SessionExpiredException']) {
      expect(definitiveSessionRejection(error), isTrue);
    }
  });
}
