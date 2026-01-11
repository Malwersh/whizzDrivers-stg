import 'dart:async';
import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/environment.dart';

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Required on background isolate
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // ignore
  }
}

class PushNotificationsService {
  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<dynamic>? _authHubSub;
  static FutureOr<void> Function(RemoteMessage message)? _onNotificationTap;

  static String? _lastKnownFcmToken;

  // Used to pass wave-offer tap info across cold starts.
  static const String _pendingWaveOfferKey = 'pendingWaveOfferFromPushTap';

  // Used to request navigation to a specific bottom tab after cold start.
  static const String _pendingTabIndexKey = 'pendingTabIndexFromPushTap';

  static Future<void> initialize({FutureOr<void> Function(RemoteMessage message)? onNotificationTap}) async {
    if (kIsWeb) return;

    // Allow callers (like widgets) to set/update the tap handler even if we already initialized.
    if (onNotificationTap != null) {
      _onNotificationTap = onNotificationTap;
    }

    if (_initialized) return;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('PushNotificationsService: Firebase.initializeApp failed: $e');
      debugPrint(
        'PushNotificationsService: iOS Firebase config is likely missing/invalid. '
        'Ensure ios/Runner/GoogleService-Info.plist is a valid Firebase plist for bundleId com.wiz.wizdriverapp.',
      );
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      _lastKnownFcmToken = token;
      await _registerToken(token);
    }

    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) async {
      if (newToken.isEmpty) return;
      _lastKnownFcmToken = newToken;
      await _registerToken(newToken);
    });

    // Handle notification taps (background -> foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      final handler = _onNotificationTap;
      if (handler != null) {
        await handler(message);
      }
    });

    // Handle notification that opened the app from terminated state
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      final handler = _onNotificationTap;
      if (handler != null) {
        await handler(initialMessage);
      }
    }

    // If user signs in later, retry token registration.
    _authHubSub?.cancel();
    _authHubSub = Amplify.Hub.listen(HubChannel.Auth, (event) async {
      final name = event.eventName;
      if (name == 'SIGNED_IN' || name == 'SESSION_ESTABLISHED') {
        final tokenToRegister = _lastKnownFcmToken;
        if (tokenToRegister != null && tokenToRegister.isNotEmpty) {
          await _registerToken(tokenToRegister);
        }
      }
    });

    _initialized = true;
  }

  static Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    await _authHubSub?.cancel();
    _authHubSub = null;
    _initialized = false;
  }

  static Future<String?> _getIdToken() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session is CognitoAuthSession && session.isSignedIn) {
        final tokensResult = session.userPoolTokensResult;
        // In Amplify v2, accessing .value may throw if tokens are unavailable.
        final tokens = tokensResult.value;
        return tokens.idToken.raw;
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  static String _platform() {
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.iOS) return 'ios';
    return 'android';
  }

  static Future<String?> _deviceId() async {
    try {
      final info = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = await info.androidInfo;
        return android.id;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await info.iosInfo;
        return ios.identifierForVendor;
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  static Future<void> _registerToken(String token) async {
    final idToken = await _getIdToken();
    if (idToken == null || idToken.isEmpty) {
      debugPrint('Push token register skipped: no auth session');
      return;
    }

    final uri = Uri.parse('${Environment.centralPushApiBaseUrl}/push/tokens/register');

    final deviceId = await _deviceId();

    final payload = <String, dynamic>{
      'token': token,
      'platform': _platform(),
      'app': 'driver',
      'env': Environment.environment,
      if (deviceId != null && deviceId.isNotEmpty) 'deviceId': deviceId,
    };

    try {
      final resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        debugPrint('Push token register failed: ${resp.statusCode} ${resp.body}');
      } else {
        try {
          final decoded = jsonDecode(resp.body);
          debugPrint('Push token registered: ${jsonEncode(decoded)}');
        } catch (_) {
          debugPrint('Push token registered: ${resp.statusCode}');
        }
      }
    } on TimeoutException {
      debugPrint('Push token register timed out');
    } catch (e) {
      debugPrint('Push token register error: $e');
    }
  }

  /// Persist a wave-offer payload so the Home screen can render it after cold start.
  /// This is intentionally minimal (offerId/orderId/etc.) and is removed once consumed.
  static Future<void> stashWaveOfferFromTap(RemoteMessage message) async {
    try {
      final data = message.data;
      final type = (data['type'] ?? '').toString();
      if (type != 'new_wave_offer') return;

      final offerId = (data['offerId'] ?? '').toString();
      final orderId = (data['orderId'] ?? '').toString();
      if (offerId.isEmpty || orderId.isEmpty) return;

      final payload = <String, dynamic>{
        'offerId': offerId,
        'orderId': orderId,
        'waveNumber': (data['waveNumber'] ?? '').toString(),
        'restaurantName': (data['restaurantName'] ?? '').toString(),
        'expiresAt': (data['expiresAt'] ?? '').toString(),
        'isEmergencyWave': (data['isEmergencyWave'] ?? '').toString(),
        'tappedAt': DateTime.now().toIso8601String(),
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingWaveOfferKey, jsonEncode(payload));
    } catch (_) {
      // ignore
    }
  }

  /// Persist a pending bottom-tab index so Splash can route after auth/profile checks.
  /// This avoids calling GoRouter navigation APIs too early (common cold-start race).
  static Future<void> stashPendingTabFromTap(RemoteMessage message) async {
    try {
      final data = message.data;
      final type = (data['type'] ?? '').toString();

      // Wave offers should always open the search/home tab.
      // Non-wave notifications default to notifications tab.
      final targetTab = type == 'new_wave_offer' ? 0 : 4;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_pendingTabIndexKey, targetTab);
    } catch (_) {
      // ignore
    }
  }

  static Future<int?> consumePendingTabFromTap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_pendingTabIndexKey)) return null;
      final tab = prefs.getInt(_pendingTabIndexKey);
      await prefs.remove(_pendingTabIndexKey);
      if (tab == null) return null;
      return tab.clamp(0, 5);
    } catch (_) {
      // ignore
    }
    return null;
  }

  static Future<Map<String, dynamic>?> consumeStashedWaveOfferFromTap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingWaveOfferKey);
      if (raw == null || raw.isEmpty) return null;
      await prefs.remove(_pendingWaveOfferKey);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // ignore
    }
    return null;
  }
}
