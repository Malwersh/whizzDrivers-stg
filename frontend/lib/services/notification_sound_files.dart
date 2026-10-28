import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationSoundFiles {
  static final Map<String, Map<String, String>> installed = {};
  static final changed = ValueNotifier<int>(0);
  static const bridge = MethodChannel('wizz/notification-sound-files');
  static Future<void> adopt(List<dynamic> catalog, String prefix) async {
    for (final item in catalog) {
      if (item is! Map || item['audio'] is! String || item['sha256'] is! String)
        continue;
      final hash = item['sha256'] as String, id = item['id'];
      if (id != 'custom_$hash' ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
          installed.containsKey(id)) continue;
      final bytes = base64Decode(item['audio']);
      if (bytes.length > 256000 || sha256.convert(bytes).toString() != hash)
        continue;
      Map<String, String>? data;
      try {
        data = await bridge.invokeMapMethod<String, String>(
            'install', {'file': '$id.wav', 'bytes': Uint8List.fromList(bytes)});
      } catch (_) {
        // One unavailable custom file must not block other sound choices.
        continue;
      }
      if (data == null) continue;
      if (defaultTargetPlatform == TargetPlatform.android) {
        await FlutterLocalNotificationsPlugin()
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(AndroidNotificationChannel(
                '${prefix}_$id', 'إشعارات الطلبات',
                importance: Importance.high,
                sound: UriAndroidNotificationSound(data['uri']!),
                playSound: true));
      }
      installed[id] = Map<String, String>.from(data);
      changed.value++;
    }
  }

  static Source source(String file) => file.startsWith('custom_') &&
          installed.containsKey(file.replaceAll('.wav', ''))
      ? DeviceFileSource(installed[file.replaceAll('.wav', '')]!['path']!)
      : AssetSource('sounds/$file');
}
