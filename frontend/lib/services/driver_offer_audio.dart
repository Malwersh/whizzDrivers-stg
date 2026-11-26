import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'notification_sound_policy.dart';

/// Coalesce WS/FCM arrivals; a failed playback can be retried by the next arrival.
class OfferAudioDeduplicator {
  final Map<String, DateTime> _played = {};
  final Map<String, Future<void>> _inFlight = {};
  Future<void> play(String id, Future<bool> Function() cue) {
    final now = DateTime.now();
    _played.removeWhere((_, at) => now.difference(at).inMinutes >= 10);
    if (_played.containsKey(id)) return Future.value();
    return _inFlight.putIfAbsent(id, () async {
      try {
        if (await cue()) {
          _played[id] = DateTime.now();
          while (_played.length > 200) {
            _played.remove(_played.keys.first);
          }
        }
      } finally {
        _inFlight.remove(id);
      }
    });
  }
}

/// One foreground cue per offer. The OS owns background notification audio.
class DriverOfferAudio {
  static final _player = AudioPlayer();
  static final _dedup = OfferAudioDeduplicator();
  static Future<void> _tail = Future.value();
  static bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  static Map<String, dynamic> lastResult = const {};
  static Future<void> play(String offerId) async {
    if (offerId.isEmpty || !_foreground) return;
    await _dedup.play(offerId, () => _cue());
  }

  static Future<Map<String, dynamic>> preview() async {
    await _cue(refreshPolicy: true);
    return Map<String, dynamic>.from(lastResult);
  }

  static Future<bool> _cue({bool refreshPolicy = false}) async {
    try {
      await NotificationSoundPolicy.refresh(force: refreshPolicy).timeout(
          refreshPolicy
              ? const Duration(seconds: 6)
              : const Duration(milliseconds: 600));
    } catch (_) {/* Cached original is available offline. */}
    final file = NotificationSoundPolicy.file('driverNewOffer');
    if (file == null) {
      lastResult = {'playing': false, 'silent': true};
      await _recordDiagnostic();
      return true;
    }
    var played = false;
    final task = _tail.then((_) async {
      if (!_foreground) {
        lastResult = {'playing': false, 'reason': 'APP_NOT_ACTIVE'};
        return;
      }
      try {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          final result = await NotificationSoundFiles.bridge
              .invokeMapMethod<String, dynamic>('playOfferCue', {'file': file});
          lastResult = result == null
              ? {'playing': false}
              : Map<String, dynamic>.from(result);
          played = lastResult['playing'] == true;
          return;
        }
        await _player.setAudioContext(AudioContext(
            android: const AudioContextAndroid(
                contentType: AndroidContentType.sonification,
                usageType: AndroidUsageType.notification,
                audioFocus: AndroidAudioFocus.gainTransientMayDuck)));
        await _player.stop();
        await _player.setVolume(1);
        try {
          await _player.play(NotificationSoundFiles.source(file));
        } catch (_) {
          await _player.play(AssetSource('sounds/driver_original.wav'));
        }
        played = true;
        lastResult = {'playing': true};
      } catch (error) {
        lastResult = {
          'playing': false,
          'reason': 'PLAYBACK_FAILED',
          'errorType': error.runtimeType.toString(),
          if (error is PlatformException) 'nativeCode': error.code
        };
        debugPrint('Driver offer cue failed: ${error.runtimeType}');
      }
    });
    _tail = task.catchError((Object _) {});
    await task;
    lastResult = {...lastResult, 'selectedFile': file};
    await _recordDiagnostic();
    return played;
  }

  static Future<void> _recordDiagnostic() async {
    if (kIsWeb) return;
    try {
      await File('${Directory.systemTemp.path}/driver-offer-audio-dart.json')
          .writeAsString(
              jsonEncode({
                ...lastResult,
                'recordedAt': DateTime.now().toUtc().toIso8601String()
              }),
              flush: true);
    } catch (_) {/* Diagnostic storage cannot block the offer. */}
  }
}
