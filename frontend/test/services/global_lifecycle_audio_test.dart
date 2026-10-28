import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/services/global_app_state_manager.dart';
import 'package:wizz_driver/services/driver_offer_audio.dart';
import 'package:wizz_driver/services/notification_sound_files.dart';

Future<void> lifecycle(String state) async {
  final done = Completer<void>();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
          'flutter/lifecycle',
          const StringCodec().encodeMessage('AppLifecycleState.$state'),
          (_) => done.complete());
  await done.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'global manager preserves framework lifecycle and foreground offer audio',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    var plays = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NotificationSoundFiles.bridge, (call) async {
      if (call.method == 'playOfferCue') plays++;
      return {'playing': true, 'volume': .7};
    });
    final manager = GlobalAppStateManager();
    try {
      manager.initialize();
      manager.initialize();
      await lifecycle('paused');
      expect(WidgetsBinding.instance.lifecycleState, AppLifecycleState.paused);
      await lifecycle('resumed');
      expect(WidgetsBinding.instance.lifecycleState, AppLifecycleState.resumed);
      expect((await DriverOfferAudio.preview())['playing'], true);
      expect(plays, 1);
      await lifecycle('paused');
      expect((await DriverOfferAudio.preview())['playing'], false);
      expect(plays, 1,
          reason: 'Background cues remain owned by notification audio');
      await lifecycle('resumed');
      manager.dispose();
      await lifecycle('inactive');
      expect(WidgetsBinding.instance.lifecycleState, AppLifecycleState.inactive,
          reason: 'Disposal must not clear the framework handler');
      await lifecycle('resumed');
    } finally {
      manager.dispose();
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NotificationSoundFiles.bridge, null);
    }
  });
}
