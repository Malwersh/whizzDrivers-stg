import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'notification_sound_policy.dart';

/// One foreground cue per offer across WebSocket and FCM. APNs owns background audio.
class DriverOfferAudio {
  static final _player = AudioPlayer();
  static final Map<String, DateTime> _seen = {};
  static Future<void> play(String offerId) async {
    if (offerId.isEmpty ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
      return;
    final now = DateTime.now();
    _seen.removeWhere((_, at) => now.difference(at).inMinutes >= 10);
    if (_seen.containsKey(offerId)) return;
    _seen[offerId] = now;
    while (_seen.length > 200) {
      _seen.remove(_seen.keys.first);
    }
    unawaited(NotificationSoundPolicy.refresh());
    final file = NotificationSoundPolicy.file('driverNewOffer');
    if (file == null) return;
    try {
      await _player.stop();
      await _player.play(NotificationSoundFiles.source(file));
    } catch (_) {/* Keep the visible offer usable. */}
  }
}
