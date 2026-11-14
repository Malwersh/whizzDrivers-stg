import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/services/push_notifications_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('approval and rejection taps route to wallet after cold start',
      () async {
    for (final type in [
      'wallet_topup_approved',
      'wallet_topup_rejected',
      'wallet_sandbox_payment_succeeded',
      'wallet_transfer_completed'
    ]) {
      await PushNotificationsService.stashPendingTabFromTap(
          RemoteMessage(data: {'type': type}));
      expect(await PushNotificationsService.consumePendingTabFromTap(), 2);
      expect(await PushNotificationsService.consumePendingTabFromTap(), null);
    }
  });
  test(
      'wave offers preserve their home route and general notifications keep their tab',
      () async {
    await PushNotificationsService.stashPendingTabFromTap(const RemoteMessage(
        data: {
          'type': 'new_wave_offer',
          'offerId': 'offer',
          'orderId': 'order'
        }));
    expect(await PushNotificationsService.consumePendingTabFromTap(), 0);
    await PushNotificationsService.stashPendingTabFromTap(
        const RemoteMessage(data: {'type': 'general'}));
    expect(await PushNotificationsService.consumePendingTabFromTap(), 4);
  });
}
