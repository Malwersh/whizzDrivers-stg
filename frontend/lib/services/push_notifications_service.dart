import 'financial_offer_reference.dart';
import 'driver_offer_audio.dart';
import 'notification_sound_policy.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/environment.dart';
import 'offer_closure_inbox.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Required on background isolate
  try {
    try {
      DartPluginRegistrant.ensureInitialized();
    } catch (_) {
      // ignore
    }
    await Firebase.initializeApp();
  } catch (_) {
    // ignore
  }

  // Best-effort: stash wave-offer info so the UI can render it when the user
  // later taps the notification (background/lock-screen cases).
  try {
    if (!PushNotificationsService.isWalletEvent(message.data)) {
      await PushNotificationsService.stashWaveOfferFromTap(message);
      await PushNotificationsService.stashPendingTabFromTap(message);
    }
  } catch (_) {
    // ignore
  }
}

class PushNotificationsService {
  static bool _initialized = false;
  static bool _soundListener=false;
  static final _profileEvents = StreamController<RemoteMessage>.broadcast();
  static Stream<RemoteMessage> get profileEvents => _profileEvents.stream;
  static bool isProfileEvent(Map<String, dynamic> data) =>
      data['type'] == 'driver_review_changed';
  static final _walletEvents = StreamController<RemoteMessage>.broadcast();
  static Stream<RemoteMessage> get walletEvents => _walletEvents.stream;
  static StreamSubscription<RemoteMessage>? _foregroundSub;
  static Timer? _tokenRetryTimer;
  static bool isWalletEvent(Map<String, dynamic> data) =>
      data['type'] == 'wallet_topup_approved' ||
      data['type'] == 'wallet_topup_rejected' ||
      data['type'] == 'wallet_sandbox_payment_succeeded' ||
      data['type'] == 'wallet_transfer_completed' ||
      data['type'] == 'wallet_cod_lifecycle';
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<dynamic>? _authHubSub;
  static FutureOr<void> Function(RemoteMessage message)? _onNotificationTap;

  static String? _lastKnownFcmToken;
  static bool _tokenRegistered = false;
  static String? _lastRegistrationIdToken;

  // Used to pass wave-offer tap info across cold starts.
  static const String _pendingWaveOfferKey = 'pendingWaveOfferFromPushTap';

  // Used to request navigation to a specific bottom tab after cold start.
  static const String _pendingTabIndexKey = 'pendingTabIndexFromPushTap';

  static Future<void> initialize(
      {FutureOr<void> Function(RemoteMessage message)?
          onNotificationTap}) async {
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
      sound: false,
    );

    // Token acquisition can fail while APNs is registering. Listeners must still be installed.
    await refreshTokenRegistration();
    _tokenRetryTimer?.cancel();
    _tokenRetryTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_tokenRegistered) {
        await refreshTokenRegistration();
      }
    });

    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) async {
      if (newToken.isEmpty) return;
      _lastKnownFcmToken = newToken;
      _tokenRegistered = false;
      await _registerToken(newToken);
    });

    _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen((message) async {
      if (OfferClosureInbox.isClosure(message.data)) {
        try { await OfferClosureInbox.record(message.data); } catch (_) { /* Resume rechecks persisted events. */ }
        return;
      }
      if(message.data['type']=='new_wave_offer'||message.data['type']=='financial_wave_offer_available'){
        if(message.data['type']=='financial_wave_offer_available')await stashWaveOfferFromTap(message);
        try{
          final user=await Amplify.Auth.getCurrentUser();
          final expires=DateTime.tryParse(message.data['expiresAt']?.toString()??'');
          if(message.data['driverId']==user.userId&&expires!=null&&expires.isAfter(DateTime.now())){
            unawaited(DriverOfferAudio.play(message.data['offerId']?.toString()??''));
          }
        }catch(_){/* A signed-out device must not announce an offer. */}
      }
      if (isWalletEvent(message.data)) _walletEvents.add(message);
      if (isProfileEvent(message.data)) _profileEvents.add(message);
    });

    // Handle notification taps (background -> foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      if (OfferClosureInbox.isClosure(message.data)) await stashWaveOfferFromTap(message);
      if (isProfileEvent(message.data)) _profileEvents.add(message);
      debugPrint(
          '📲 Push tap (onMessageOpenedApp) data keys: ${message.data.keys.toList()}');
      debugPrint('📲 Push tap (onMessageOpenedApp) data: ${message.data}');
      final handler = _onNotificationTap;
      if (handler != null) {
        await handler(message);
      }
    });

    // Handle notification that opened the app from terminated state
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      if (OfferClosureInbox.isClosure(initialMessage.data)) await stashWaveOfferFromTap(initialMessage);
      debugPrint(
          '📲 Push tap (getInitialMessage) data keys: ${initialMessage.data.keys.toList()}');
      debugPrint(
          '📲 Push tap (getInitialMessage) data: ${initialMessage.data}');
      final handler = _onNotificationTap;
      if (handler != null) {
        await handler(initialMessage);
      }
    }

    // If user signs in later, retry token registration.
    _authHubSub?.cancel();
    _authHubSub = Amplify.Hub.listen(HubChannel.Auth, (event) async {
      final name = event.eventName;
      if (name == 'SIGNED_OUT') await _unregisterSignedOutDevice();
      if (name == 'SIGNED_IN' || name == 'SESSION_ESTABLISHED') {
        final tokenToRegister = _lastKnownFcmToken;
        if (tokenToRegister != null && tokenToRegister.isNotEmpty) {
          await _registerToken(tokenToRegister);
        }
      }
    });

    _initialized = true;
  }

  static Future<void> refreshTokenRegistration() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final messaging = FirebaseMessaging.instance;
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          await messaging.getAPNSToken() == null) {
        return;
      }
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _lastKnownFcmToken = token;
        await _registerToken(token);
      }
    } catch (_) {
      debugPrint('Push token is not available yet; registration will retry.');
    }
  }

  static Future<void> dispose() async {
    _tokenRetryTimer?.cancel();
    _tokenRetryTimer = null;
    await _foregroundSub?.cancel();
    _foregroundSub = null;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    await _authHubSub?.cancel();
    _authHubSub = null;
    _initialized = false;
    _tokenRegistered = false;
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

  static Future<void> _unregisterSignedOutDevice() async {
    try {
      await OfferClosureInbox.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingWaveOfferKey);
      await prefs.remove(_pendingTabIndexKey);
    } catch (_) { /* Token unregister must still run if local cleanup fails. */ }
    final token = _lastKnownFcmToken;
    final idToken = _lastRegistrationIdToken;
    _tokenRegistered = false;
    _lastRegistrationIdToken = null;
    _lastKnownFcmToken = null;
    if (token != null && idToken != null) {
      try {
        await http
            .post(
                Uri.parse(
                    '${Environment.centralPushApiBaseUrl}/push/tokens/unregister'),
                headers: {
                  'Authorization': 'Bearer $idToken',
                  'Content-Type': 'application/json'
                },
                body: jsonEncode({'token': token}))
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        debugPrint('Device unregistration will rely on token invalidation.');
      }
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      debugPrint('Push token deletion unavailable.');
    }
  }

  static Future<void> _registerToken(String token) async {
    _tokenRegistered = false;
    final idToken = await _getIdToken();
    if (idToken == null || idToken.isEmpty) {
      debugPrint('Push token register skipped: no auth session');
      return;
    }

    if(!_soundListener){_soundListener=true;NotificationSoundFiles.changed.addListener(() {final token=_lastKnownFcmToken;if(token!=null)unawaited(_registerToken(token));});}
    await NotificationSoundPolicy.refresh();
    _lastRegistrationIdToken = idToken;
    final uri =
        Uri.parse('${Environment.centralPushApiBaseUrl}/push/tokens/register');

    final deviceId = await _deviceId();

    final payload = <String, dynamic>{
      'token': token,
      'platform': _platform(),
          'soundReady': NotificationSoundPolicy.ready,
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
        debugPrint(
            'Push token register failed: ${resp.statusCode} ${resp.body}');
      } else {
        _tokenRegistered = true;
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
  /// This is removed once consumed.
  static Future<void> stashWaveOfferFromTap(RemoteMessage message) async {
    try {
      final data = message.data;
      if (OfferClosureInbox.isClosure(data)) {
        await OfferClosureInbox.record(data);
        return;
      }
      final type = (data['type'] ?? '').toString().trim();
      if (type == 'financial_wave_offer_available') {
        final reference = FinancialOfferReference.read(data);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_pendingWaveOfferKey, jsonEncode({...reference, 'type': type}));
        return;
      }


      String pick(List<String> keys) {
        for (final k in keys) {
          final v = data[k];
          if (v == null) continue;
          final s = v.toString().trim();
          if (s.isNotEmpty) return s;
        }
        return '';
      }

      final offerId = pick(['offerId', 'offer_id']);
      final orderId = pick(['orderId', 'order_id']);

      // iOS sometimes delivers the notification tap payload without our `type` key.
      // Accept the stash as long as identifiers exist.
      if (offerId.isEmpty || orderId.isEmpty) return;

      if (type.isNotEmpty && !const ['new_wave_offer', 'wave_offer', 'priority_order_offer'].contains(type)) return;
      final effectiveType = type.isEmpty ? 'new_wave_offer' : type;

      final payload = <String, dynamic>{
        'type': effectiveType,
        'cycleId': pick(['cycleId', 'dispatchCycleId']),
        'action': pick(['action']),
        'driverId': pick(['driverId', 'driver_id', 'subjectId', 'subject_id']),
        'offerId': offerId,
        'orderId': orderId,
        'waveNumber': pick(['waveNumber', 'wave_number']),
        'restaurantName': pick(['restaurantName', 'restaurant_name']),
        'restaurantImageUrl': pick([
          'restaurantImageUrl',
          'restaurant_image_url',
          'restaurantImage',
          'restaurant_image'
        ]),
        'customerName': pick(['customerName', 'customer_name']),
        'customerAddress': pick(['customerAddress', 'customer_address']),
        'deliveryFee': pick(['deliveryFee', 'delivery_fee']),
        'bonusAmount': pick(['bonusAmount', 'bonus_amount']),
        'tip': pick(['tip']),
        'holdRequiredAmount': pick(['holdRequiredAmount']),
        'moneyUnit': pick(['moneyUnit']),
        'legacySourceVersion': pick(['legacySourceVersion']),
        'orderTotal':
            pick(['orderTotal', 'order_total', 'orderValue', 'order_value']),
        'estimatedEarnings': pick(['estimatedEarnings', 'estimated_earnings']),
        'distance': pick(['distance', 'distanceKm', 'distance_km']),
        'estimatedMinutes': pick(['estimatedMinutes', 'estimated_minutes']),
        'itemsCount': pick(['itemsCount', 'items_count']),
        'currency': pick(['currency']),
        'expiresAt': pick(['expiresAt', 'expires_at']),
        'isEmergencyWave': pick(['isEmergencyWave', 'is_emergency_wave']),
        'tappedAt': DateTime.now().toIso8601String(),
      };

      for (final field in ['tip', 'holdRequiredAmount', 'moneyUnit', 'legacySourceVersion']) {
        if (payload[field] == null || payload[field] == '') payload.remove(field);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingWaveOfferKey, jsonEncode(payload));
      debugPrint(
          '💾 Stashed wave offer to SharedPreferences: offerId=${payload['offerId']}, orderId=${payload['orderId']}');
    } catch (e) {
      debugPrint('🚨 Error stashing wave offer: $e');
    }
  }

  /// Persist a pending bottom-tab index so Splash can route after auth/profile checks.
  /// This avoids calling GoRouter navigation APIs too early (common cold-start race).
  static Future<void> stashPendingTabFromTap(RemoteMessage message) async {
    try {
      final data = message.data;
      final type = (data['type'] ?? '').toString().trim();
      final action = (data['action'] ?? '').toString().trim();

      final offerId = (data['offerId'] ?? data['offer_id'] ?? '').toString();
      final orderId = (data['orderId'] ?? data['order_id'] ?? '').toString();
      final hasOfferIdentifiers = offerId.isNotEmpty && orderId.isNotEmpty;

      // Wave offers should always open the search/home tab.
      // Non-wave notifications default to notifications tab.
      final targetTab = isWalletEvent(data)
          ? 2
          : (type == 'new_wave_offer' ||
                  action == 'wave_assignment' ||
                  hasOfferIdentifiers)
              ? 0
              : 4;

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

  static Future<void> clearStashedFinancialOffer(Map<String, dynamic> reference) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingWaveOfferKey);
    if (raw == null) return;
    final saved = jsonDecode(raw);
    if (saved is Map && saved['type'] == 'financial_wave_offer_available' && saved['offerId'] == reference['offerId'] && saved['driverId'] == reference['driverId']) {
      await prefs.remove(_pendingWaveOfferKey);
    }
  }

  static Future<Map<String, dynamic>?> consumeStashedWaveOfferFromTap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingWaveOfferKey);
      if (raw == null || raw.isEmpty) {
        debugPrint(
            '🔍 [Consume] No pending wave offer key in SharedPreferences');
        return null;
      }
      debugPrint(
          '📤 [Consume] Found stashed offer reference');
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['type'] == 'financial_wave_offer_available') {
        try { FinancialOfferReference.read(decoded); return decoded; } catch (_) { await prefs.remove(_pendingWaveOfferKey); return null; }
      }
      await prefs.remove(_pendingWaveOfferKey);
      if (decoded is Map<String, dynamic>) {
        if (OfferClosureInbox.isClosure(decoded)) {
          await OfferClosureInbox.record(decoded);
          return null;
        }
        debugPrint('✅ [Consume] Successfully decoded stashed wave offer');
        return decoded;
      }
    } catch (e) {
      debugPrint('🚨 [Consume] Error consuming stashed wave offer: $e');
    }
    return null;
  }
}
