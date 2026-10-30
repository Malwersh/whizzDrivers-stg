import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../lib/services/notification_sound_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('an unavailable custom online cue cannot block the selected offer sound',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final bytes = List<int>.filled(44, 0),
        hash = sha256.convert(List<int>.filled(44, 0)).toString();
    SharedPreferences.setMockInitialValues({
      'notification_sound_policy_v1': jsonEncode({
        'version': 3,
        'values': {
          'merchantNewOrder': 'merchant_original',
          'driverNewOffer': 'driver_offer',
          'driverGoOnline': 'custom_$hash'
        },
        'catalog': [
          {'id': 'custom_$hash', 'sha256': hash, 'audio': base64Encode(bytes)}
        ]
      })
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NotificationSoundFiles.bridge, (call) async {
      throw PlatformException(code: 'INSTALL_UNAVAILABLE');
    });
    try {
      await NotificationSoundPolicy.refresh();
      expect(
          NotificationSoundPolicy.file('driverNewOffer'), 'driver_offer.wav');
      expect(
          NotificationSoundPolicy.file('driverGoOnline'), 'online_chime.wav');
    } finally {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NotificationSoundFiles.bridge, null);
    }
  });
}
