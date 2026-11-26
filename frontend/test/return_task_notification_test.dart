import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/services/push_notifications_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('completed return opens notifications after cold start without reviving an offer or opening wallet', () async {
    SharedPreferences.setMockInitialValues({});
    const message = RemoteMessage(data: {
      'type': 'driver_return_task_updated',
      'eventId': 'RETURN_TASK_NOTICE:synthetic',
      'orderId': 'order1',
      'action': 'open_notifications',
    });
    expect(PushNotificationsService.isWalletEvent(message.data), isFalse);
    await PushNotificationsService.stashPendingTabFromTap(message);
    expect(await PushNotificationsService.consumePendingTabFromTap(), 4);
    expect(await PushNotificationsService.consumeStashedWaveOfferFromTap(), isNull);
    expect(await PushNotificationsService.consumePendingTabFromTap(), isNull);
  });
}
