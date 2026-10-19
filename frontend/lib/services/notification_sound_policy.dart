import 'package:flutter/foundation.dart';
import 'notification_sound_files.dart';
export 'notification_sound_files.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';
import 'cognito_token_service.dart';

/// Verified uploaded sounds and original assets, cached for offline playback.
class NotificationSoundPolicy {
  static const files = {
    'merchant_original': 'first_nitification_sound.wav',
    'driver_original': 'driver_original.wav',
    'merchant_bell': 'merchant_bell.wav',
    'driver_offer': 'driver_offer.wav',
    'online_chime': 'online_chime.wav',
    'soft_chime': 'soft_chime.wav'
  };
  static Map<String, dynamic> _values = {
    'merchantNewOrder': 'merchant_original',
    'driverNewOffer': 'driver_original',
    'driverGoOnline': 'online_chime',
    'merchantReminderSeconds': 45,
    'merchantAcceptanceSeconds': 300
  };
  static DateTime? _loaded;
  static bool _busy = false;
  static String? file(String key) {
    final id = _values[key];
    if (NotificationSoundFiles.installed.containsKey(id)) return '$id.wav';
    return id == 'silent'
        ? null
        : files[id] ??
            files[key == 'merchantNewOrder'
                ? 'merchant_original'
                : key == 'driverNewOffer'
                    ? 'driver_original'
                    : 'online_chime'];
  }

  static List<String> get ready =>
      [...files.keys, ...NotificationSoundFiles.installed.keys];
  static int get reminderSeconds =>
      (_values['merchantReminderSeconds'] as num?)?.toInt() ?? 45;
  static int get acceptanceSeconds =>
      (_values['merchantAcceptanceSeconds'] as num?)?.toInt() ?? 300;
  static bool _channelsReady = false;
  static Future<void> prepareChannels() async {
    if (_channelsReady ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) return;
    final plugin = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    for (final id in [...files.keys, 'silent']) {
      final file = files[id];
      await plugin?.createNotificationChannel(AndroidNotificationChannel(
          'driver_offers_' + (file?.replaceAll('.wav', '') ?? 'silent'),
          'إشعارات الطلبات • $id',
          importance: Importance.high,
          playSound: file != null,
          sound: file == null
              ? null
              : RawResourceAndroidNotificationSound(
                  file.replaceAll('.wav', ''))));
    }
    await plugin?.createNotificationChannel(const AndroidNotificationChannel(
        'driver_offers_default', 'إشعارات الطلبات',
        importance: Importance.high, playSound: true));
    _channelsReady = true;
  }

  static Future<void> refresh() async {
    if (_busy ||
        _loaded != null && DateTime.now().difference(_loaded!).inMinutes < 5)
      return;
    _busy = true;
    try {
      await prepareChannels();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('notification_sound_policy_v1');
      if (saved != null) {
        final cached = jsonDecode(saved);
        if (cached is Map && cached['values'] is Map) {
          await NotificationSoundFiles.adopt(
              List<dynamic>.from(cached['catalog'] ?? []), 'driver_offers');
          _values = {
            ..._values,
            ...Map<String, dynamic>.from(cached['values'])
          };
        }
      }
      final token = await CognitoTokenService.getAccessToken();
      if (token == null) return;
      final headers = {'Authorization': 'Bearer $token'};
      final base = Environment.centralPushApiBaseUrl;
      final r = await http
          .get(Uri.parse('$base/push/sounds'), headers: headers)
          .timeout(const Duration(seconds: 4));
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final policy =
            body['notificationPolicy'] ?? body['data']?['notificationPolicy'];
        await NotificationSoundFiles.adopt(
            List<dynamic>.from(policy['catalog'] ?? []), 'driver_offers');
        final v = Map<String, dynamic>.from(policy['values']);
        for (final k in [
          'merchantNewOrder',
          'driverNewOffer',
          'driverGoOnline'
        ]) {
          if (v[k] != 'silent' &&
              !files.containsKey(v[k]) &&
              !NotificationSoundFiles.installed.containsKey(v[k])) return;
        }
        _values = {..._values, ...v};
        await prefs.setString(
            'notification_sound_policy_v1', jsonEncode(policy));
        _loaded = DateTime.now();
      }
    } catch (_) {
      /* Keep last known policy and default on first launch. */
    } finally {
      _busy = false;
    }
  }
}
