import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/services/push_notifications_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('COD wallet notice opens wallet after cold start and does not become a new driver offer', () async {
    SharedPreferences.setMockInitialValues({});
    const message = RemoteMessage(data: {
      'type': 'wallet_cod_lifecycle',
      'eventId': 'COD_EVENT:synthetic',
      'action': 'open_wallet',
    });
    await PushNotificationsService.stashPendingTabFromTap(message);
    expect(await PushNotificationsService.consumePendingTabFromTap(), 2);
    expect(await PushNotificationsService.consumeStashedWaveOfferFromTap(), isNull);
    expect(await PushNotificationsService.consumePendingTabFromTap(), isNull);
  });
}
