import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../lib/services/driver_offer_audio.dart';
import '../../lib/services/notification_sound_files.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('iPhone preview uses native playback and returns real session volume',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NotificationSoundFiles.bridge, (call) async {
      calls.add(call);
      return {
        'playing': true,
        'volume': 0.7,
        'route': ['Speaker']
      };
    });
    try {
      final result = await DriverOfferAudio.preview();
      expect(result['playing'], true);
      expect(result['volume'], .7);
      expect(calls.single.method, 'playOfferCue');
      expect(calls.single.arguments, {'file': 'driver_original.wav'});
    } finally {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NotificationSoundFiles.bridge, null);
    }
  });
}
