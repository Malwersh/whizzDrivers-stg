import '../../services/map_data_failure.dart';
import 'widgets/outside_coverage_sheet.dart';
import '../../services/financial_offer_inbox.dart';
import 'widgets/store_marker_halo.dart';
import 'widgets/store_photo_marker.dart';
import 'widgets/map_tools.dart';
import 'widgets/map_demand_sheet.dart';
import '../../services/map_activity_service.dart';
import '../../providers/riverpod/tab_provider.dart';
import '../more/screens/live_chat_screen.dart';
import 'widgets/go_online_button.dart';
import '../../services/offer_performance_prefetch.dart';
import 'widgets/decline_acceptance_impact.dart';
import '../../widgets/location_permission_notice.dart';
import '../demand/demand_card.dart';
import '../../services/driver_location_mode.dart';
import '../../services/financial_offer_reference.dart';
import '../../services/driver_offer_audio.dart';
import '../../services/notification_sound_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'widgets/order_offer_card.dart';
import 'widgets/order_details_bottom_sheet.dart';
import '../../services/websocket_service.dart';
import '../../services/cognito_token_service.dart';
import '../../models/map_data.dart';
import '../../services/map_data_service.dart';
import '../../services/business_status_cache.dart';
import '../../models/wave_offer.dart' show WaveOffer;
import '../../models/wave_offer.dart' as wave_model;
import '../../widgets/wave_offer_dialog.dart';
import '../../services/push_notifications_service.dart';
import '../../services/offer_closure_inbox.dart';
import '../../services/driver_search_api_service.dart';
import '../../config/environment.dart';
import '../active_order/services/order_persistence_service.dart';
import '../active_order/helpers/order_restore_helper.dart';
import '../wallet/providers/wallet_provider.dart';

// ألوان التطبيق
class AppColors {
  static const Color primary = Color(0xFFFDC500); // اللون الأساسي - أصفر ذهبي
  static const Color secondary = Color(0xFF00296B); // اللون الثانوي - أزرق داكن
  static const Color accent = Color(0xFF00c1e8); // لون مساعد - أزرق فاتح
}

// نموذج بيانات الطلب
class OrderItem {
  final String itemId;
  final String name;
  final int quantity;
  final double unitPrice;
  final String? imageUrl;
  final String? notes;

  OrderItem({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.imageUrl,
    this.notes,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      itemId: json['itemId'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      imageUrl: json['imageUrl'],
      notes: json['notes'],
    );
  }
}

class OrderOffer {
  final String id;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final String storeName;
  final String storeAddress;
  final String? storeImageUrl; // صورة المطعم
  final double estimatedEarnings;
  final double deliveryFee;
  final double extraEarnings;
  final double tips;
  final String deliveryType; // 'pickup', 'shopping'
  final int itemsCount;
  final List<OrderItem> items; // قائمة العناصر
  final double distanceInMiles;
  final int estimatedMinutes;
  final DateTime createdAt;
  final bool isUrgent;
  final String? specialInstructions;

  OrderOffer({
    required this.id,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.storeName,
    required this.storeAddress,
    this.storeImageUrl,
    required this.estimatedEarnings,
    required this.deliveryFee,
    required this.extraEarnings,
    required this.tips,
    required this.deliveryType,
    required this.itemsCount,
    required this.items,
    required this.distanceInMiles,
    required this.estimatedMinutes,
    required this.createdAt,
    this.isUrgent = false,
    this.specialInstructions,
  });
}

class SparkHomeSimpleArabic extends ConsumerStatefulWidget {
  const SparkHomeSimpleArabic({super.key});

  @override
  ConsumerState<SparkHomeSimpleArabic> createState() =>
      _SparkHomeSimpleArabicState();
}

class _SparkHomeSimpleArabicState extends ConsumerState<SparkHomeSimpleArabic>
    with WidgetsBindingObserver {
  final _performancePreview = OfferPerformancePrefetch(
      load: DriverSearchApiService.getDriverPerformance);
  String? _preparingRejectOfferId;
  bool _isSearchingForOffers = false;
  bool _isStartingOnline = false;
  double _onlineSheetOpacity = 1;
  DateTime? _searchEndTime;
  DateTime? _selectedEndTime;
  Position? _currentPosition;
  List<DateTime>? _timeOptions; // قائمة الأوقات المنشأة مرة واحدة
  bool _isCheckingWalletBalance = false; // حالة التحميل لفحص رصيد المحفظة
  Timer? _searchTimer; // Timer للتحقق من انتهاء وقت البحث
  final List<OrderOffer> _availableOffers =
      []; // قائمة الطلبات المتاحة (Legacy - Deprecated)
  final Set<String> _rejectedOfferIds = {}; // الطلبات المرفوضة
  Timer?
      _storesStatusRefreshTimer; // 🔄 Timer لتحديث حالة المطاعم تلقائياً (Polling مثل wizzuser)
  late AudioPlayer _audioPlayer; // مشغل الصوت للإشعارات
  String? _errorMessage; // رسالة الخطأ عند فشل البدء

  // 🌊 Wave System - New
  WaveOffer?
      _currentWaveOffer; // العرض الحالي من Wave System (DEPRECATED - use _currentWaveOffers)
  final List<WaveOffer> _currentWaveOffers = []; // قائمة عروض الموجات الحالية
  String?
      _currentRejectConfirmationOfferId; // معرّف العرض الذي يتم تأكيد رفضه حالياً
  StreamSubscription? _waveOfferSubscription;
  StreamSubscription? _financialPushSubscription;
  final Set<String> _pushHydrating={};
  final Map<String,DateTime> _pushRetryAfter={};
  bool _drainingFinancialPush=false;

  Future<void> _drainFinancialPush() async {
    if(!mounted||_drainingFinancialPush)return;
    _drainingFinancialPush=true;
    try{
      final owner=await _bindOfferOwner();if(owner==null||!mounted)return;
      for(final reference in await FinancialOfferInbox.pending(owner)){
        if(!mounted)break;
        await _receiveFinancialPush(reference);
      }
    } finally { _drainingFinancialPush=false; }
  }

  Future<void> _receiveFinancialPush(Map<String,dynamic> data)async{
    final id=data['offerId']?.toString()??'';
    if(id.isEmpty||_pushHydrating.contains(id)||(_pushRetryAfter[id]?.isAfter(DateTime.now())??false))return;
    _pushHydrating.add(id);
    final epoch=_offerAuthEpoch;
    try{
      final owner=await _bindOfferOwner();
      if(owner==null||data['driverId']!=owner||!mounted||epoch!=_offerAuthEpoch)return;
      if(_currentWaveOffers.any((o)=>o.offerId==id)){await PushNotificationsService.clearStashedFinancialOffer(data);return;}
      final hydrated=await FinancialOfferReference.hydrate(data,owner);
      if(!mounted||epoch!=_offerAuthEpoch||await _bindOfferOwner()!=owner)return;
      final offer=WaveOffer.fromJson(hydrated);
      if(!await _offerStillVisible(offer)){await PushNotificationsService.clearStashedFinancialOffer(data);return;}
      if(!mounted||epoch!=_offerAuthEpoch)return;
      await _handleWaveOffer(offer,fromSocket:false);
      if(mounted&&epoch==_offerAuthEpoch&&_currentWaveOffers.any((o)=>o.offerId==id)){
        await PushNotificationsService.clearStashedFinancialOffer(data);
        _pushRetryAfter.remove(id);
      }
    } catch (_) {
      // Keep the reference for a bounded retry until its original expiry.
      _pushRetryAfter[id]=DateTime.now().add(const Duration(seconds:3));
    } finally { _pushHydrating.remove(id); }
  }
  StreamSubscription? _offerExpiredSubscription;
  StreamSubscription? _offerTakenSubscription;
  StreamSubscription<dynamic>? _offerAuthSubscription;
  final _offerClosureScope = OfferClosureScope();
  int _offerAuthEpoch = 0;
  bool _closureRefreshInFlight = false;
  Timer? _offerExpiryCleanupTimer; // 🆕 دوري لتنظيف العروض المنتهية الصلاحية

  // WebSocket Service for Wave System
  final WebSocketService _webSocketService = WebSocketService();

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // Google Maps
  String _storeSearchQuery = '';
  bool _heatEnabled = false,
      _activityLoading = false,
      _activityIsTestData = false;
  String? _activityError;
  DateTime? _activityExpiresAt;
  Map<String, int> _readyPickups = {};
  Timer? _mapActivityTimer;
  Timer? _pickupHaloExpiryTimer;
  int _markerBuildVersion = 0;
  final _storePhotoMarkers = StorePhotoMarkers();
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final ValueNotifier<double> _locationWavePhase = ValueNotifier(0);
  Timer? _locationWaveTimer;
  Timer? _searchPositionTimer;
  bool _searchPositionBusy = false;
  double _locationWaveZoom = 14;
  LatLng? _displayDriverLocation;
  BitmapDescriptor? _driverLocationIcon;
  final List<BitmapDescriptor> _driverBreathingIcons = [];
  StreamSubscription<Position>? _displayLocationSubscription;

  LatLng get _driverMapPoint => _displayDriverLocation ?? const LatLng(0, 0);

  void _setDisplayDriverLocation(Position position) {
    if (!mounted) return;
    setState(() {
      _displayDriverLocation = LatLng(position.latitude, position.longitude);
      final icon = _driverLocationIcon;
      if (icon != null) {
        _markers.removeWhere(
            (m) => m.markerId == const MarkerId('driver_location'));
        _markers.add(Marker(
            markerId: const MarkerId('driver_location'),
            position: _driverMapPoint,
            icon: icon,
            anchor: const Offset(.5, .5),
            zIndex: 1000));
      }
    });
  }

  Future<void> _ensureDriverMapMarker() async {
    if (_driverBreathingIcons.isEmpty) {
      for (var i = 0; i < 16; i++) {
        final breath = (1 - math.cos(2 * math.pi * i / 16)) / 2;
        _driverBreathingIcons
            .add(await _createDriverLocationMarker(breath: breath));
        if (!mounted) return;
      }
    }
    final icon = _driverLocationIcon ?? _driverBreathingIcons.first;
    if (!mounted) return;
    setState(() {
      _driverLocationIcon = icon;
      _markers
          .removeWhere((m) => m.markerId == const MarkerId('driver_location'));
      _markers.add(Marker(
          markerId: const MarkerId('driver_location'),
          position: _driverMapPoint,
          icon: icon,
          anchor: const Offset(.5, .5),
          zIndex: 1000));
    });
  }

  void _startLocationWaves() {
    _locationWaveTimer?.cancel();
    _locationWaveTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
        return;
      _locationWavePhase.value = (_locationWavePhase.value + .05) % 1;
    });
  }

  Set<Circle> _locationWaves(double phase) {
    final metersPerPixel = 156543.03392 *
        math.cos(_driverMapPoint.latitude * math.pi / 180) /
        math.pow(2, _locationWaveZoom);
    final breath = (1 - math.cos(2 * math.pi * phase)) / 2;
    final wave = Curves.easeOut.transform(phase);
    final fade = math.sin(math.pi * phase);
    return {
      Circle(
          circleId: const CircleId('driver_location_halo'),
          center: _driverMapPoint,
          radius: (12 + breath * 2) * metersPerPixel,
          strokeWidth: 0,
          strokeColor: Colors.transparent,
          fillColor: AppColors.secondary.withValues(alpha: .1 + breath * .04),
          zIndex: 1,
          consumeTapEvents: false),
      Circle(
          circleId: const CircleId('driver_location_wave'),
          center: _driverMapPoint,
          radius: (12 + wave * 24) * metersPerPixel,
          strokeWidth: 1,
          strokeColor: AppColors.secondary.withValues(alpha: .28 * fade),
          fillColor: AppColors.secondary.withValues(alpha: .025 * fade),
          zIndex: 2,
          consumeTapEvents: false),
    };
  }

  MapDataResponse? _mapData;
  bool _isLoadingMapData = false;
  bool _outsideCoverageNoticeShown = false;
  bool _coverageSheetOpen = false;
  bool _outsideCoverageConfirmed = false;
  bool _checkingCoverageForStart = false;

  // 📊 Driver Performance Metrics

  // ✅ Active Order Check
  bool _hasCheckedActiveOrder = false;

  double get _dispatchLat =>
      (_currentPosition ?? (throw StateError('موقع السائق غير متاح'))).latitude;
  double get _dispatchLng =>
      (_currentPosition ?? (throw StateError('موقع السائق غير متاح')))
          .longitude;
  Future<void> _requireDispatchPosition() async {
    final position = await DriverSearchApiService.getCurrentPosition();
    if (position == null) throw StateError('تعذر تحديد موقع السائق؛ فعّل GPS');
    if (!mounted) return;
    setState(() => _currentPosition = position);
    _setDisplayDriverLocation(position);
  }

  // Stream listener for notification taps
  StreamSubscription<RemoteMessage>? _notificationTapSubscription;

  @override
  void initState() {
    super.initState();
    DriverSearchApiService.confirmedStopEvents
        .addListener(_onConfirmedSearchStop);
    _offerAuthSubscription = Amplify.Hub.listen(HubChannel.Auth, (event) {
      if (event.eventName == 'SIGNED_OUT' || event.eventName == 'SIGNED_IN') {
        _offerAuthEpoch++;
        _performancePreview.clear();
        _pushRetryAfter.clear();
        _offerClosureScope.bind(null);
        if (mounted)
          setState(() {
            _currentWaveOffers.clear();
            _currentWaveOffer = null;
          });
      }
    });
    _financialPushSubscription=FinancialOfferInbox.events.listen((data){
      unawaited(_receiveFinancialPush(data));
    });
    _startLocationWaves();
    _searchPositionTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _refreshSearchPosition());
    try {
      print('🚀 Initializing SparkHomeSimpleArabic...');

      // Add app lifecycle observer for background/foreground handling
      WidgetsBinding.instance.addObserver(this);

      // One tap listener; closure persistence belongs to PushNotificationsService.
      _setupNotificationTapListener();

      // تهيئة مشغل الصوت أولاً مع حماية
      _initAudioPlayer();

      // تأخير التهيئة لتجنب الانغلاق
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _delayedInitialization();
        // ✅ فحص الطلب النشط بعد بناء الشاشة
        _checkForActiveOrder();
      });

      print('✅ SparkHomeSimpleArabic basic initialization complete');
    } catch (e, stackTrace) {
      print('🚨 CRITICAL: Error in initState: $e');
      print('Stack trace: $stackTrace');

      // Fallback initialization
      _fallbackInitialization();
    }
  }

  void _setupNotificationTapListener() {
    print('🔔 [Home] Setting up notification tap listener...');
    _notificationTapSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 [Home] Notification tapped! Message: ${message.data}');
      print('🔔 [Home] Consuming stash immediately...');

      // Consume immediately
      _consumeWaveOfferFromPushTap();

      // Retry after delays to handle race conditions
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          print('🔔 [Home] Retry #1 consuming stash (500ms)');
          _consumeWaveOfferFromPushTap();
        }
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          print('🔔 [Home] Retry #2 consuming stash (1.5s)');
          _consumeWaveOfferFromPushTap();
        }
      });
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (mounted) {
          print('🔔 [Home] Retry #3 consuming stash (3s)');
          _consumeWaveOfferFromPushTap();
        }
      });
    });
    print('✅ [Home] Notification tap listener setup complete');
  }

  Future<void> _checkForActiveOrder() async {
    if (_hasCheckedActiveOrder) return;
    _hasCheckedActiveOrder = true;

    try {
      debugPrint('🏠 SparkHome: Checking for active order...');
      await OrderRestoreHelper.checkAndRestoreActiveOrder(context, ref);
      debugPrint('✅ SparkHome: Active order check completed');
    } catch (e) {
      debugPrint('❌ SparkHome: Active order check error: $e');
    }
  }

  // 🆕 Track if app was actually closed or just tab switch
  DateTime? _lastPausedTime;
  static const Duration _minimumBackgroundDuration = Duration(seconds: 3);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _startLocationWaves();
      _displayLocationSubscription?.resume();
    } else {
      _locationWaveTimer?.cancel();
      _displayLocationSubscription?.pause();
    }

    print('📱 App lifecycle changed: $state');

    // Keep local handling for specific home screen needs
    print('🔔 didChangeAppLifecycleState called: $state');
    switch (state) {
      case AppLifecycleState.resumed:
        print('📱 App resumed - home screen specific handling');
        _refreshLocationIfStale();
        _refreshSearchPosition();

        // ✅ Consume any push-tap stash on resume (background tap case).
        print('🔄 Calling _consumeWaveOfferFromPushTap() on resumed');
        _refreshOfferClosures();
        _consumeWaveOfferFromPushTap();
        Future.delayed(const Duration(milliseconds: 500), () {
          print(
              '🔄 Retry #1 calling _consumeWaveOfferFromPushTap() after 500ms');
          _consumeWaveOfferFromPushTap();
        });
        Future.delayed(const Duration(milliseconds: 1500), () {
          print(
              '🔄 Retry #2 calling _consumeWaveOfferFromPushTap() after 1.5s');
          _consumeWaveOfferFromPushTap();
        });

        // 🆕 Only handle resume if app was actually in background for a while
        // This prevents reconnection on simple tab switches within the app
        if (_lastPausedTime != null) {
          final backgroundDuration =
              DateTime.now().difference(_lastPausedTime!);
          print(
              '⏱️ App was in background for: ${backgroundDuration.inSeconds} seconds');

          if (backgroundDuration >= _minimumBackgroundDuration) {
            print('✅ Real app resume detected - handling WebSocket');
            _handleAppResumed();

            // ✅ Check for active order when app resumes from background
            _hasCheckedActiveOrder = false; // Reset flag
            _checkForActiveOrder();
          } else {
            print(
                'ℹ️ Quick tab switch detected - ignoring (${backgroundDuration.inSeconds}s < ${_minimumBackgroundDuration.inSeconds}s)');
          }
          _lastPausedTime = null;
        } else {
          print('ℹ️ No pause time tracked - likely initial load');
        }
        break;

      case AppLifecycleState.paused:
        print('📱 App paused - home screen cleanup');
        _lastPausedTime = DateTime.now();
        print('⏱️ Paused at: $_lastPausedTime');
        break;

      default:
        print('📱 App lifecycle: $state');
    }
  }

  Future<void> _refreshSearchPosition() async {
    if (!mounted || !_isSearchingForOffers || _searchPositionBusy) return;
    _searchPositionBusy = true;
    try {
      await _requireDispatchPosition();
      await DriverSearchApiService.refreshSearchPosition(
          latitude: _dispatchLat, longitude: _dispatchLng);
    } catch (_) {
      // Retry on the next foreground tick after a transient session/network failure.
    } finally {
      _searchPositionBusy = false;
    }
  }

  void _refreshLocationIfStale() {
    if (_currentPosition == null) {
      print('🌍 Refreshing location on app resume');
      _initializeLocation();
    }
  }

  /// 🆕 معالجة استئناف التطبيق بعد إغلاق فعلي (ليس tab switch)
  Future<void> _handleAppResumed() async {
    try {
      print(
          '🔄 App ACTUALLY resumed after real background - checking driver search state...');

      // ✅ أولاً: فحص وجود طلب نشط
      await _checkForActiveOrder();

      // التحقق إذا كان السائق يبحث عن طلبات
      if (_isSearchingForOffers) {
        print('🔍 Driver was searching when app went to background');
        print('🔌 Checking WebSocket connection health...');

        // التحقق من حالة WebSocket
        if (_webSocketService.isConnected) {
          print(
              '✅ WebSocket still connected - refreshing connection proactively');
          // تحديث الاتصال احترازياً (قد يكون stale بعد background)
          await _webSocketService.refreshConnection();
          print(
              '✅ WebSocket refreshed - connection is healthy and ready for offers');
        } else {
          print('❌ WebSocket disconnected during background - reconnecting...');
          // إعادة الاتصال الكاملة
          await _reconnectWebSocket();

          if (_webSocketService.isConnected) {
            print('✅ Reconnected successfully and ready for offers');
          } else {
            print('⚠️ Reconnection failed - driver needs to restart search');
          }
        }

        print('✅ App resumed handling complete - ready to receive offers');
      } else {
        print('ℹ️ Driver not searching - no WebSocket action needed');
      }
    } catch (e) {
      print('❌ Error in _handleAppResumed: $e');
    }
  }

  /// ✅ فحص وجود طلب نشط وعرض BottomSheet (Replaced by OrderRestoreHelper)

  /// 🆕 إعادة الاتصال بـ WebSocket
  Future<void> _reconnectWebSocket() async {
    try {
      // ✅ FIX: تحقق من الاتصال أولاً لمنع الاتصالات المكررة
      if (_webSocketService.isConnected) {
        print('✅ WebSocket already connected, skipping reconnection');
        return;
      }

      print('🔌 Reconnecting WebSocket...');

      final driverId = await _bindOfferOwner();
      if (driverId == null) throw const DriverSearchStartException('أعد تسجيل الدخول.', code: 'AUTH_REQUIRED');
      final authToken = await CognitoTokenService.getIdToken();
      if (authToken == null)
        throw const DriverSearchStartException(
            'تعذر تجديد جلسة الدخول. أعد تسجيل الدخول.',
            code: 'AUTH_REQUIRED');

      // إعادة تهيئة WebSocket
      await _webSocketService.initialize(
        driverId: driverId,
        authToken: authToken,
      );

      if (_webSocketService.isConnected) {
        print('✅ WebSocket reconnected successfully');
      } else {
        print('⚠️ WebSocket reconnection may have issues');
      }
    } catch (e) {
      print('❌ Error reconnecting WebSocket: $e');
    }
  }

  /// تهيئة مشغل الصوت مع حماية كاملة
  void _initAudioPlayer() {
    try {
      _audioPlayer = AudioPlayer();
      print('🔊 Audio player initialized');
    } catch (audioError) {
      print('🚨 Audio player initialization failed: $audioError');
      // Try again with delay
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          _audioPlayer = AudioPlayer();
          print('🔊 Audio player initialized on retry');
        } catch (retryError) {
          print('🚨 Audio player retry failed: $retryError');
        }
      });
    }
  }

  /// تهيئة متأخرة لتجنب الانغلاق
  void _delayedInitialization() async {
    try {
      if (!mounted) return;

      print('🔄 Starting delayed initialization...');

      // إعداد WebSocket callbacks أولاً مع تأخير
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      _setupWebSocketCallbacks();

      // ثم الموقع مع تأخير أكبر
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      _initializeLocation();

      // أخيراً استعادة حالة البحث
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      _restoreSearchState();

      print(
          '🔄 [Init] About to consume wave offer from push tap (immediate attempt)');
      // ✅ If the app was opened from a push tap (lock screen / terminated),
      // consume the stashed wave offer and show it in the list.
      await _refreshOfferClosures();
      await _consumeWaveOfferFromPushTap();

      // 🆕 Multiple retry attempts to handle race condition:
      // The onMessageOpenedApp handler may still be saving the stash when
      // _delayedInitialization runs on cold start.
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          print('🔄 [Init] Retry #1 consuming wave offer (800ms)');
          _consumeWaveOfferFromPushTap();
        }
      });
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          print('🔄 [Init] Retry #2 consuming wave offer (2s)');
          _consumeWaveOfferFromPushTap();
        }
      });
      Future.delayed(const Duration(milliseconds: 3500), () {
        if (mounted) {
          print('🔄 [Init] Retry #3 consuming wave offer (3.5s)');
          _consumeWaveOfferFromPushTap();
        }
      });

      // 🆕 Start periodic cleanup of expired offers
      _startOfferExpiryCleanup();

      print('✅ Delayed initialization complete');
    } catch (e, stackTrace) {
      print('🚨 Error in delayed initialization: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _consumeWaveOfferFromPushTap() async {
    print('🔍 [Consume] _consumeWaveOfferFromPushTap() called');
    await _refreshOfferClosures();
    await _drainFinancialPush();
    try {
      final data =
          await PushNotificationsService.consumeStashedWaveOfferFromTap();
      if (data == null) {
        print('ℹ️ [Consume] No stashed wave offer found in SharedPreferences');
        return;
      }

      print('📲 [Consume] Wave offer found! Consuming: ${data.toString()}');

      final offerId = (data['offerId'] ?? '').toString().trim();
      final orderId = (data['orderId'] ?? '').toString().trim();
      if (offerId.isEmpty ||
          orderId.isEmpty ||
          OfferClosureInbox.isClosure(data)) return;
      final owner = await _bindOfferOwner();
      if (owner == null || data['driverId'] != owner) return;

      DateTime? expiresAt;
      final expiresAtRaw = (data['expiresAt'] ?? '').toString().trim();
      if (expiresAtRaw.isNotEmpty) {
        expiresAt = DateTime.tryParse(expiresAtRaw);
      }
      if (expiresAt == null || !expiresAt.isAfter(DateTime.now())) return;

      final existing = _currentWaveOffers.any((o) => o.offerId == offerId);
      if (existing) {
        await _handleWaveOffer(
            _currentWaveOffers.firstWhere((o) => o.offerId == offerId),
            fromSocket: false);
        return;
      }

      if (data['type'] == 'financial_wave_offer_available') {
        await _receiveFinancialPush(data);
        return;
      }

      final waveNumber =
          int.tryParse((data['waveNumber'] ?? '').toString()) ?? 1;
      final restaurantName = (data['restaurantName'] ?? '').toString().trim();
      final restaurantImageUrl =
          (data['restaurantImageUrl'] ?? '').toString().trim();
      final customerName = (data['customerName'] ?? '').toString().trim();
      final customerAddress = (data['customerAddress'] ?? '').toString().trim();

      double _parseDouble(dynamic raw, {double fallback = 0.0}) {
        if (raw == null) return fallback;
        final s0 = raw.toString().trim();
        if (s0.isEmpty) return fallback;
        final s = s0.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.\-]'), '');
        return double.tryParse(s) ?? fallback;
      }

      int _parseInt(dynamic raw, {int fallback = 0}) {
        if (raw == null) return fallback;
        final s0 = raw.toString().trim();
        if (s0.isEmpty) return fallback;
        final s = s0.replaceAll(RegExp(r'[^0-9\-]'), '');
        return int.tryParse(s) ?? fallback;
      }

      dynamic _pickFirstNonEmpty(List<dynamic> candidates) {
        for (final c in candidates) {
          if (c == null) continue;
          if (c is String && c.trim().isEmpty) continue;
          return c;
        }
        return null;
      }

      // Parse financial details
      final deliveryFee = _parseDouble(data['deliveryFee'], fallback: 0.0);
      final bonusAmount = _parseDouble(data['bonusAmount'], fallback: 0.0);
      final orderTotal = _parseDouble(
        _pickFirstNonEmpty([data['orderTotal'], data['orderValue']]),
        fallback: 0.0,
      );
      final holdRequiredAmount =
          _parseDouble(data['holdRequiredAmount'], fallback: 0.0);
      final estimatedEarnings = _parseDouble(data['estimatedEarnings'],
          fallback: (deliveryFee + bonusAmount));

      // Parse distance & time
      final distance = _parseDouble(
        _pickFirstNonEmpty([data['distance'], data['distanceKm']]),
        fallback: 0.0,
      );
      final estimatedMinutes = _parseInt(data['estimatedMinutes'], fallback: 0);
      final itemsCount = _parseInt(data['itemsCount'], fallback: 0);
      final currency =
          (data['currency'] ?? 'IQD').toString().replaceAll('"', '').trim();

      final isEmergencyWave =
          (data['isEmergencyWave'] ?? '').toString().toLowerCase() == 'true';

      // Create a full WaveOffer with all details from push notification
      var placeholder = WaveOffer(
        offerId: offerId,
        orderId: orderId,
        jobId: 'JOB_$orderId',
        dispatchCycleId: (data['cycleId'] ?? '').toString().isEmpty
            ? null
            : data['cycleId'].toString(),
        waveNumber: waveNumber,
        isEmergencyWave: isEmergencyWave,
        rank: 1,
        score: 0,
        restaurantId: orderId,
        restaurantName: restaurantName.isEmpty ? 'طلب جديد' : restaurantName,
        restaurantAddress: '',
        restaurantLat: 0,
        restaurantLng: 0,
        restaurantImageUrl:
            restaurantImageUrl.isNotEmpty ? restaurantImageUrl : null,
        customerId: '',
        customerName: customerName,
        customerAddress: customerAddress,
        customerLat: 0,
        customerLng: 0,
        orderTotal: orderTotal,
        deliveryFee: deliveryFee,
        bonusAmount: bonusAmount,
        tip: 0,
        estimatedEarnings: estimatedEarnings,
        holdRequiredAmount: holdRequiredAmount > 0 ? holdRequiredAmount : null,
        currency: currency,
        distance: distance,
        estimatedMinutes: estimatedMinutes,
        itemsCount: itemsCount,
        items: const <wave_model.OrderItem>[],
        sentAt: DateTime.now(),
        expiresAt: expiresAt,
      );

      if (data['legacySourceVersion'] != null || data['moneyUnit'] != null) {
        // Validate the original push values; a missing field must not become zero.
        placeholder = WaveOffer.fromJson({
          ...placeholder.toJson(),
          for (final field in [
            'legacySourceVersion',
            'moneyUnit',
            'currency',
            'orderTotal',
            'deliveryFee',
            'bonusAmount',
            'tip',
            'estimatedEarnings',
            'holdRequiredAmount'
          ])
            field: data[field],
        });
      }
      if (!await _offerStillVisible(placeholder) || !mounted) return;
      await _handleWaveOffer(placeholder, fromSocket: false);
      print('✅ Added push-tap offer with full details: $offerId');
      print(
          '📊 Details: deliveryFee=$deliveryFee IQD, distance=${distance.toStringAsFixed(1)}km, customer=$customerName');
    } catch (e) {
      print('❌ Error consuming push-tap wave offer: $e');
    }
  }

  /// تهيئة احتياطية في حالة الفشل
  void _fallbackInitialization() {
    try {
      // تهيئة أساسية فقط
      _audioPlayer = AudioPlayer();
      print('🛡️ Fallback initialization completed');
    } catch (e) {
      print('🚨 Even fallback failed: $e');
    }
  }

  /// 🆕 Start periodic cleanup of expired offers (every 2 seconds)
  /// This ensures offers always disappear by expiresAt, even if card timer doesn't run
  void _startOfferExpiryCleanup() {
    _offerExpiryCleanupTimer?.cancel();

    _offerExpiryCleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      unawaited(_drainFinancialPush());
      _pushRetryAfter.removeWhere((_,at)=>DateTime.now().difference(at).inMinutes>2);

      if (_currentWaveOffers.isNotEmpty) {
        unawaited(_refreshOfferClosures());
        final owner = _offerClosureScope.owner;
        if (owner != null) unawaited(_performancePreview.prefetch(owner));
      }
      final nowUtc = DateTime.now().toUtc();
      int removedCount = 0;

      setState(() {
        _currentWaveOffers.removeWhere((offer) {
          // Compare in UTC to avoid timezone-related false expiries.
          final isExpired = nowUtc.isAfter(offer.expiresAt.toUtc());
          if (isExpired) {
            print('🗑️ Auto-removing expired offer: ${offer.offerId}');
            removedCount++;
          }
          return isExpired;
        });
      });

      if (removedCount > 0) {
        print(
            '✅ Cleaned up $removedCount expired offers. Remaining: ${_currentWaveOffers.length}');
      }
    });

    print('⏰ Offer expiry cleanup timer started (every 2 seconds)');
  }

  /// إعداد WebSocket callbacks لاستقبال عروض Wave
  void _setupWebSocketCallbacks() {
    try {
      print('🔌 Setting up WebSocket callbacks...');

      // 🌊 Wave System Listeners (NEW - PRIORITY)
      _waveOfferSubscription = _webSocketService.waveOfferStream.listen(
        (waveOffer) {
          if (!mounted) return;
          print(
              '🌊 Wave offer received: ${waveOffer.offerId} (Wave ${waveOffer.waveNumber}, Rank ${waveOffer.rank})');
          _handleWaveOffer(waveOffer);
        },
        onError: (error) {
          print('❌ Wave offer stream error: $error');
        },
      );

      _offerExpiredSubscription = _webSocketService.offerExpiredStream.listen(
        (offerId) {
          if (mounted) {
            print('⏰ Wave offer expired: $offerId');
            _handleWaveOfferExpired(offerId);
          }
        },
        onError: (error) {
          print('❌ Offer expired stream error: $error');
        },
      );

      _offerTakenSubscription =
          OfferClosureInbox.events.listen((closure) async {
        final epoch = _offerAuthEpoch;
        final owner = await _bindOfferOwner();
        if (!mounted || epoch != _offerAuthEpoch || owner != closure.driverId)
          return;
        _handleWaveOfferTaken(closure.offerId,
            orderId: closure.orderId, cycleId: closure.cycleId);
      }, onError: (_) {
        _refreshOfferClosures();
      });

      print('✅ WebSocket callbacks configured successfully (Wave System only)');
    } catch (e) {
      print('🚨 Error setting up WebSocket callbacks: $e');
    }
  }

  // استعادة حالة البحث من SharedPreferences
  void _restoreSearchState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSearching = prefs.getBool('isSearchingForOffers') ?? false;
      final searchEndTimeStr = prefs.getString('searchEndTime');

      if (isSearching && searchEndTimeStr != null) {
        final searchEndTime = DateTime.parse(searchEndTimeStr);

        // التحقق من أن الوقت لم ينته بعد
        if (DateTime.now().isBefore(searchEndTime)) {
          setState(() {
            _isSearchingForOffers = true;
            _searchEndTime = searchEndTime;
          });

          print('✅ تم استعادة حالة البحث: ${_formatTime(searchEndTime)}');
          _startSearchTimer(); // بدء Timer للتحقق من انتهاء الوقت

          // ✅ FIX: إعادة الاتصال الذكية - فقط إذا كان الاتصال مقطوع
          print(
              '🔍 Checking WebSocket connection status after state restore...');
          if (!_webSocketService.isConnected) {
            print('🔌 WebSocket disconnected - reconnecting...');
            print('📱 Reason: App was closed/crashed or network was lost');
            await _startRealWebSocketConnection();
            print('✅ Reconnection attempt complete');
          } else {
            print('✅ WebSocket already connected - no reconnection needed');
            print('💓 Sending keepalive to verify connection health...');
            await _webSocketService.refreshConnection();
            print('✅ Connection verified - ready to receive offers');
          }
          // Reconcile an existing unexpired online session after a completed/returned order.
          // The endpoint rechecks approval and preserves any newly assigned order.
          await _requireDispatchPosition();
          await DriverSearchApiService.startSearching(
              latitude: _dispatchLat, longitude: _dispatchLng);
        } else {
          // الوقت انتهى، إيقاف البحث
          _clearSearchState();
          print('⏰ انتهى وقت البحث، تم الإيقاف التلقائي');
        }
      }
    } catch (e) {
      print('❌ خطأ في استعادة حالة البحث: $e');
    }
  }

  // حفظ حالة البحث في SharedPreferences
  void _saveSearchState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isSearchingForOffers', _isSearchingForOffers);

      final endTime = _searchEndTime;
      if (endTime != null) {
        await prefs.setString('searchEndTime', endTime.toIso8601String());
      }

      print('💾 تم حفظ حالة البحث');
    } catch (e) {
      print('❌ خطأ في حفظ حالة البحث: $e');
    }
  }

  void _onConfirmedSearchStop() {
    if (mounted) _clearSearchState();
  }

  // مسح حالة البحث من SharedPreferences
  void _clearSearchState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isSearchingForOffers');
      await prefs.remove('searchEndTime');

      if (!mounted) return;
      setState(() {
        _isSearchingForOffers = false;
        _searchEndTime = null;
      });

      _searchTimer?.cancel();
      print('🗑️ تم مسح حالة البحث');
    } catch (e) {
      print('❌ خطأ في مسح حالة البحث: $e');
    }
  }

  // بدء Timer للتحقق من انتهاء وقت البحث
  void _startSearchTimer() {
    _searchTimer?.cancel(); // إلغاء أي timer سابق

    if (_searchEndTime != null) {
      _searchTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        final endTime = _searchEndTime;
        if (endTime == null) {
          // إذا تم مسح _searchEndTime، إلغاء Timer
          timer.cancel();
          return;
        }

        if (DateTime.now().isAfter(endTime)) {
          print('⏰ انتهى وقت البحث، إيقاف تلقائي');
          _stopSearching();
          timer.cancel();
        }
      });
    }
  }

  // تشغيل صوت الإشعار عند وصول طلب جديد مع حماية كاملة من الانغلاق

  /// تهيئة خدمة الموقع مع حماية كاملة من الانغلاق
  void _initializeLocation() async {
    try {
      await _requireDispatchPosition();
      if (!mounted || await DriverLocationMode.usesFixedTestPosition()) return;
      _displayLocationSubscription ??= Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen((position) {
        if (!mounted) return;
        setState(() => _currentPosition = position);
        _setDisplayDriverLocation(position);
      }, onError: (Object _) {});
    } catch (_) {
      if (mounted)
        setState(() {
          _currentPosition = null;
          _displayDriverLocation = null;
        });
    }
  }

  void _markOutsideCoverage() {
    _stopStoresStatusAutoRefresh();
    if (!mounted) return;
    setState(() {
      _outsideCoverageConfirmed = true;
      _mapData = null; _readyPickups.clear(); ++_markerBuildVersion;
      _markers.removeWhere((m) => m.markerId != const MarkerId('driver_location'));
    });
  }

  Future<void> _showOutsideCoverage({bool force = false}) async {
    if (!mounted || _coverageSheetOpen || (!force && _outsideCoverageNoticeShown)) return;
    _outsideCoverageNoticeShown = true;
    _coverageSheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (sheetContext) => OutsideCoverageSheet(latitude: _dispatchLat, longitude: _dispatchLng,
          onRefresh: () {
            Navigator.of(sheetContext).pop();
            _outsideCoverageNoticeShown = false;
            unawaited(_loadMapData());
          }),
      );
    } finally { _coverageSheetOpen = false; }
  }

  Future<bool> _showCoverageFailure(Object error) async {
    final outside = error is MapDataFailure && error.kind == MapDataFailureKind.outsideCoverage ||
      error is DriverSearchStartException && error.code == 'OUTSIDE_SERVICE_AREA';
    if (!outside || !mounted) return false;
    _markOutsideCoverage();
    await _showOutsideCoverage(force: true);
    return true;
  }

  void _startSearchingForOffers() async {
    if (!mounted || _checkingCoverageForStart || _isStartingOnline) return;
    setState(() => _checkingCoverageForStart = true);
    try {
      await DriverSearchApiService.checkSearchEligibility();
      if (!mounted) return;
      // Recheck a fresh GPS point before opening the time picker. A dismissed
      // notice is not permission to search, and old coverage must not trap a
      // driver who has since returned to a served area.
      await _requireDispatchPosition();
      if (!mounted) return;
      final data = await MapDataService.fetchMapData(lat: _dispatchLat, lng: _dispatchLng);
      if (!mounted) return;
      setState(() {
        _mapData = data;
        _outsideCoverageConfirmed = false;
        _outsideCoverageNoticeShown = false;
      });
      _updateMapMarkers();
      _startStoresStatusAutoRefresh();
      _showSparkNowTimeSelection();
    } catch (error) {
      if (await _showCoverageFailure(error)) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is DriverSearchStartException ? error.message
            : error is MapDataFailure ? error.toString()
              : 'تعذر التحقق من الموقع أو حالة الحساب. أعد المحاولة.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _checkingCoverageForStart = false);
    }
  }

  void _showSparkNowTimeSelection() {
    // إنشاء قائمة الأوقات مرة واحدة
    final now = DateTime.now();
    _timeOptions = <DateTime>[];
    for (int i = 1; i <= 24; i++) {
      final timeSlot = now.add(Duration(minutes: 30 * i));
      _timeOptions!.add(timeSlot);
    }

    // إعادة تعيين الاختيار عند فتح البوتوم شيت
    _selectedEndTime = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => _buildSparkNowModal(setModalState),
      ),
    );
  }

  void _confirmSparkNow(DateTime endTime) async {
    if (_isStartingOnline) return;
    final wasSearching = _isSearchingForOffers;
    _isStartingOnline = true;
    try {
      if (!mounted) {
        print('⚠️ Widget not mounted, cancelling search start');
        return;
      }

      Navigator.pop(context);

      // 🔒 SECURITY: Check wallet balance before starting search
      print('💰 فحص رصيد المحفظة قبل بدء البحث...');

      // Set loading state
      if (mounted) {
        setState(() {
          _isCheckingWalletBalance = true;
        });
      }

      try {
        // Wait for wallet data to load
        final wallet = await ref.read(walletBalanceProvider.future);

        // Clear loading state
        if (mounted) {
          setState(() {
            _isCheckingWalletBalance = false;
          });
        }

        // Availability is not a fixed balance target. The backend checks the
        // immutable offer's actual collateral atomically when accepting it.
        if (!wallet.isActive) {
          if (mounted) {
            await showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                      title: const Text('المحفظة غير نشطة'),
                      content: const Text(
                          'لا يمكن بدء استقبال الطلبات بهذه الحالة. راجع حالة المحفظة أو تواصل مع الدعم.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('حسنًا'))
                      ],
                    ));
          }
          return;
        }
      } catch (walletError) {
        // Error loading wallet data
        print('❌ خطأ في تحميل بيانات المحفظة: $walletError');

        // Clear loading state
        if (mounted) {
          setState(() {
            _isCheckingWalletBalance = false;
          });
        }

        // Show error dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.orange, size: 28),
                  SizedBox(width: 12),
                  Text('خطأ في الاتصال'),
                ],
              ),
              content: const Text(
                'حدث خطأ أثناء التحقق من رصيد محفظتك. يرجى التحقق من الاتصال بالإنترنت والمحاولة مرة أخرى.',
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('حسناً'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Prepare the selected sound before exposing the searching state.
      bool soundReady = false;
      if (!wasSearching) {
        try {
          await NotificationSoundPolicy.refresh();
          final file = NotificationSoundPolicy.file('driverGoOnline');
          if (file != null && mounted) {
            await _audioPlayer.setSource(NotificationSoundFiles.source(file));
            soundReady = true;
          }
        } catch (_) {
          // Audio is optional; a failed download must not block going online.
        }
      }
      await _startRealWebSocketConnection(failOnError: true);
      if (!mounted) return;
      if (!wasSearching) {
        setState(() => _onlineSheetOpacity = 0);
        await Future<void>.delayed(const Duration(milliseconds: 180));
        if (!mounted) return;
      }
      setState(() {
        _isSearchingForOffers = true;
        _searchEndTime = endTime;
        _onlineSheetOpacity = 1;
      });
      if (!wasSearching &&
          soundReady &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused) {
        unawaited(_audioPlayer.resume().catchError((Object _) {}));
      }
      _saveSearchState();
      unawaited(_refreshSearchPosition());
      _startSearchTimer();
    } catch (error) {
      if (mounted) setState(() => _onlineSheetOpacity = 1);
      if (await _showCoverageFailure(error)) return;
      if (mounted) {
        setState(() => _onlineSheetOpacity = 1);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is DriverSearchStartException
              ? error.message
              : 'تعذر بدء استقبال الطلبات. أعد المحاولة.'),
        ));
      }
    } finally {
      _isStartingOnline = false;
      if (mounted) setState(() => _isCheckingWalletBalance = false);
    }
  }

  void _stopSearching() async {
    print('🛑🛑🛑 إيقاف البحث بواسطة السائق - البداية');

    // 🎯 STEP 1: استدعاء REST API لتحديث WizzDriverLiveState
    try {
      print('📡 استدعاء REST API /driver/stop-searching...');

      // 🔄 IMPORTANT: احصل على Token حديث من Amplify بدلاً من SharedPreferences
      String? authToken;
      try {
        final session = await Amplify.Auth.fetchAuthSession();
        final cognitoSession = session as CognitoAuthSession;
        authToken = cognitoSession.userPoolTokensResult.value.accessToken.raw;
        print('✅ تم الحصول على Access Token من Amplify');
      } catch (tokenError) {
        print(
            '⚠️ فشل الحصول على Token من Amplify، محاولة من SharedPreferences');
        final prefs = await SharedPreferences.getInstance();
        authToken =
            prefs.getString('auth_token') ?? prefs.getString('id_token');
      }

      print('🔑 Auth Token موجود: ${authToken != null}');
      print('🔑 Auth Token length: ${authToken?.length ?? 0}');

      if (authToken != null) {
        final stopUrl = '${Environment.apiBaseUrl}/driver/stop-searching';
        print('🌐 URL: $stopUrl');

        final response = await http.post(
          Uri.parse(stopUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          // إضافة timeout لتجنب التعليق
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('⏱️ API Request timeout بعد 10 ثواني');
            throw TimeoutException('Request timeout');
          },
        );

        print('📥 Response Status Code: ${response.statusCode}');
        print('📥 Response Body: ${response.body}');

        if (response.statusCode == 200) {
          print('✅✅✅ REST API: تم إيقاف حالة البحث بنجاح');
          final data = jsonDecode(response.body);
          print('📊 Response Data: $data');
        } else if (response.statusCode == 401) {
          print('🔐 Token منتهي الصلاحية - محاولة تحديث Token');
          // محاولة تحديث Token وإعادة المحاولة
          try {
            await Amplify.Auth.fetchAuthSession();
            print('✅ تم تحديث Session - إعادة المحاولة');
            // إعادة استدعاء الدالة
            return _stopSearching();
          } catch (e) {
            print('❌ فشل تحديث Session: $e');
          }
        } else {
          print('⚠️⚠️⚠️ REST API: فشل إيقاف البحث - ${response.statusCode}');
          print('⚠️ Response Body: ${response.body}');
        }
      } else {
        print('❌❌❌ لا يوجد Auth Token - لن يتم استدعاء API');
      }
    } catch (apiError) {
      print('❌❌❌ خطأ في استدعاء stop-searching API: $apiError');
      print('❌ Stack trace: ${StackTrace.current}');
    }

    // 🔥 STEP 2: إرسال رسالة stop_searching إلى Enhanced Handler قبل قطع الاتصال
    if (_webSocketService.isConnected) {
      print('📤 WebSocket متصل - إرسال رسالة stop_searching');
      final stopSearchingMessage = WebSocketMessage(
        type: MessageType.driverOffline,
        data: {
          'action': 'stop_searching',
          'type': 'driver_offline',
          'driverId': _webSocketService.driverId,
          'userId': _webSocketService.driverId,
          'userType': 'driver',
          'disconnectAfterStop':
              false, // لا نريد قطع الاتصال كلياً، فقط إيقاف البحث
          'timestamp': DateTime.now().toIso8601String()
        },
      );
      _webSocketService.sendMessage(stopSearchingMessage);
      print('📤 تم إرسال رسالة stop_searching للنظام المركزي');

      // انتظار قصير للتأكد من إرسال الرسالة
      await Future.delayed(const Duration(milliseconds: 500));

      // 🆕 Refresh connection after stopping search to prevent stale connection
      print('🔄 Refreshing WebSocket connection after stopping search...');
      await _webSocketService.refreshConnection();
      print('✅ Connection refreshed and ready for next search');
    } else {
      print('⚠️ WebSocket غير متصل - لن يتم إرسال رسالة stop_searching');
    }

    print('🧹 مسح الحالة من SharedPreferences...');
    _clearSearchState(); // مسح الحالة من SharedPreferences
    print('✅✅✅ إيقاف البحث - الانتهاء');
  }

  /// بدء البحث عن الطلبات مع WebSocket الموجود أو تهيئة جديد
  Future<void> _startRealWebSocketConnection({bool failOnError = false}) async {
    try {
      if (!mounted) {
        print('⚠️ Widget not mounted, skipping WebSocket setup');
        return;
      }

      print('🔌 بدء نظام البحث عن الطلبات...');

      // ✅ FIX: التحقق من صحة الاتصال الموجود
      if (_webSocketService.isConnected) {
        print('✅ WebSocket already connected');

        // فقط إرسال heartbeat للتأكد من أن الاتصال سليم
        print('💓 Sending keepalive heartbeat...');
        await _webSocketService.refreshConnection();

        print('✅ Connection verified, calling start-searching API...');
        await _callStartSearchingAPI();
        return;
      }

      // ✅ إذا لم يكن متصل، محاولة إعادة الاتصال (حالة: انقطاع إنترنت، إغلاق مفاجئ)
      print('🔄 WebSocket disconnected - attempting reconnection...');
      print('📱 Reason: App crash, network loss, or connection timeout');

      final driverId = await _bindOfferOwner();
      if (driverId == null) throw const DriverSearchStartException('أعد تسجيل الدخول.', code: 'AUTH_REQUIRED');
      final authToken = await CognitoTokenService.getIdToken();
      if (authToken == null) throw const DriverSearchStartException('أعد تسجيل الدخول.', code: 'AUTH_REQUIRED');

      print('🚗 معرف السائق: $driverId');

      // محاولة إعادة تهيئة WebSocket
      try {
        print('🔌 Re-initializing WebSocket connection...');
        await _webSocketService.initialize(
          driverId: driverId,
          authToken: authToken,
        );

        if (_webSocketService.isConnected) {
          print('✅ WebSocket connection re-established successfully');
          print('📡 Calling start-searching API to sync state...');
          await _callStartSearchingAPI();
        } else {
          throw Exception('WebSocket connection failed after initialization');
        }
      } catch (wsError) {
        print('❌ WebSocket re-initialization failed: $wsError');
        print('⚠️ Wave System requires WebSocket connection');
        print('💡 User should check internet connection and retry');
        if (failOnError) rethrow;
      }
    } catch (e, stackTrace) {
      print('🚨 CRITICAL: خطأ في نظام البحث: $e');
      print('Stack trace: $stackTrace');
      if (failOnError) rethrow;
    }
  }

  /// استدعاء REST API /driver/start-searching لكتابة البيانات الكاملة
  Future<void> _callStartSearchingAPI() async {
    await _requireDispatchPosition();
    final result = await DriverSearchApiService.startSearching(
        latitude: _dispatchLat, longitude: _dispatchLng);
    if (result['success'] != true)
      throw DriverSearchStartException(
          result['message']?.toString() ?? 'تعذر بدء استقبال الطلبات.',
          code: result['code']?.toString());
  }

  // بدء محاكاة وصول طلبات جديدة
  // Legacy simulation system removed - Wave System only

  // قبول الطلب (DEPRECATED - Use Wave System)
  void _acceptOffer(OrderOffer offer) {
    print('⚠️ _acceptOffer called for legacy offer flow - ignoring');
    print('✅ Use Wave System offer acceptance instead');
  }

  // رفض الطلب (DEPRECATED - Use Wave System)
  void _rejectOffer(OrderOffer offer) {
    print('⚠️ _rejectOffer called for legacy offer flow - ignoring');

    setState(() {
      _rejectedOfferIds.add(offer.id);
      _availableOffers.removeWhere((o) => o.id == offer.id);
    });
  }

  /// معالجة انتهاء صلاحية الطلب
  void _handleOfferExpired(String offerId) {
    setState(() {
      _availableOffers.removeWhere((offer) => offer.id == offerId);
    });
    print('⏰ انتهت صلاحية الطلب: $offerId');
  }

  /// معالجة قبول طلب من سائق آخر
  void _handleOfferAcceptedByOther(String offerId) {
    setState(() {
      _availableOffers.removeWhere((offer) => offer.id == offerId);
    });
    print('🤝 تم قبول الطلب من سائق آخر: $offerId');
  }

  // بناء بطاقة الطلب (Legacy - Deprecated - لم يعد مستخدماً)
  Widget _buildOfferCard(OrderOffer offer) {
    // ملاحظة: هذه الدالة محتفظ بها للتوافق فقط
    // النظام الحالي يستخدم WaveOffer و _buildWaveOfferCard
    return Container(); // placeholder
  }

  // 🌊 بناء بطاقة Wave Offer (NEW)
  Widget _buildWaveOfferCard(WaveOffer offer) {
    return Padding(
      key: ValueKey<String>('wave-offer-card-${offer.offerId}'),
      padding: const EdgeInsets.only(bottom: 16),
      child: OrderOfferCard(
        key: ValueKey<String>('wave-offer-${offer.offerId}'),
        offer: offer,
        onAccept: () => _acceptWaveOffer(offer),
        onReject: () =>
            _showRejectConfirmationSheet(offer), // ✅ عرض Bottom Sheet للتأكيد
        onTimeout: () => _handleTimeout(offer), // ✅ معالج منفصل لانتهاء الوقت
        onTap: () => _showWaveOrderDetails(offer),
        onDisplayed: offer.financialTerms == null
            ? null
            : () => DriverSearchApiService.acknowledgeDisplayedOffer(
                offer.orderId, offer.offerId),
      ),
    );
  }

  /// تحويل OrderOffer إلى WaveOffer (للتوافق مع الشاشات القديمة)
  WaveOffer _convertOrderOfferToWaveOffer(OrderOffer order) {
    return WaveOffer(
      offerId: order.id,
      orderId: order.id,
      jobId: 'JOB_${order.id}',
      waveNumber: 1,
      rank: 1,
      score: 0,
      restaurantId: 'REST_${order.storeName.hashCode}',
      restaurantName: order.storeName,
      restaurantAddress: order.storeAddress,
      restaurantLat: 0,
      restaurantLng: 0,
      restaurantImageUrl: order.storeImageUrl,
      customerId: 'CUST_${order.customerName.hashCode}',
      customerName: order.customerName,
      customerAddress: order.customerAddress,
      customerLat: 0,
      customerLng: 0,
      customerPhone: order.customerPhone,
      orderTotal: order.estimatedEarnings,
      deliveryFee: order.deliveryFee,
      estimatedEarnings: order.estimatedEarnings,
      currency: 'IQD', // القيمة الافتراضية للعروض القديمة
      distance: order.distanceInMiles / 0.621371, // miles to km
      estimatedMinutes: order.estimatedMinutes,
      itemsCount: order.itemsCount,
      items: order.items
          .map((item) => wave_model.OrderItem(
                itemId: item.itemId,
                name: item.name,
                quantity: item.quantity,
                price: 0, // OrderOffer local class doesn't have price
                imageUrl: null,
                notes: null,
              ))
          .toList(),
      sentAt: order.createdAt,
      expiresAt: order.createdAt.add(const Duration(seconds: 30)),
      specialInstructions: null,
    );
  }

  // إظهار تفاصيل الطلب (Legacy - Deprecated)
  void _showOrderDetails(OrderOffer offer) {
    // تحويل OrderOffer إلى WaveOffer
    final waveOffer = _convertOrderOfferToWaveOffer(offer);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OrderDetailsBottomSheet(
        offer: waveOffer,
        canAccept: true,
        onAccept: () => _acceptOffer(offer),
        onReject: () => _rejectOffer(offer),
      ),
    );
  }

  // إظهار رسالة قبول الطلب
  void _showOrderAcceptedDialog(OrderOffer offer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('تم قبول الطلب'),
        content:
            Text('تم قبول طلب ${offer.customerName}\nمن ${offer.storeName}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // هنا يمكن الانتقال إلى شاشة تنفيذ الطلب
            },
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    // إضافة تفاصيل إضافية للوقت
    final dayDifference = time.difference(DateTime.now()).inDays;
    final timeString = '$hour12:$minute $period';

    if (dayDifference > 0) {
      return '$timeString (اليوم التالي)';
    }

    return timeString;
  }

  Future<void> _searchMapStores() async {
    final picked = await showModalBottomSheet<NearbyStore>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (_) => MapStoreSearchSheet(
            stores: _mapData?.nearbyStores ?? [],
            initialQuery: _storeSearchQuery));
    if (!mounted || picked == null) return;
    setState(() => _storeSearchQuery = picked.name);
    _updateMapMarkers();
    await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(picked.lat, picked.lng), 17));
  }

  Future<void> _centerDriverMap() async {
    if (_displayDriverLocation == null) {
      _initializeLocation();
    }
    if (!mounted || _displayDriverLocation == null) return;
    await _mapController
        ?.animateCamera(CameraUpdate.newLatLngZoom(_driverMapPoint, 16));
  }

  int get _busyReadyMinimum =>
      (_mapData?.mapTools?['busyMinimumReady'] as int?) ?? 3;
  int get _activityRefreshSeconds =>
      (_mapData?.mapTools?['refreshSeconds'] as int?) ?? 40;

  int _pickupMarkerLevel(NearbyStore store) {
    if (!_heatEnabled ||
        _activityExpiresAt == null ||
        !_activityExpiresAt!.isAfter(DateTime.now())) return 0;
    final count = _readyPickups[store.storeId] ?? 0;
    return count >= _busyReadyMinimum
        ? 2
        : count > 0
            ? 1
            : 0;
  }

  Future<void> _refreshPickupActivity() async {
    if (!_heatEnabled ||
        _activityLoading ||
        !mounted ||
        ref.read(selectedTabProvider) != DriverTabs.home ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
      return;
    setState(() {
      _activityLoading = true;
      _activityError = null;
    });
    try {
      final d = await MapActivityService.load(
          (_mapData?.nearbyStores ?? []).map((s) => s.storeId).toList());
      if (!mounted || !_heatEnabled) return;
      final items = List<Map>.from(d['items'] ?? []);
      setState(() {
        if (d['enabled'] != true) {
          _heatEnabled = false;
          _mapActivityTimer?.cancel();
          _activityError = 'أوقفت الإدارة عرض النشاط حاليًا.';
        }
        _activityIsTestData = d['isTestData'] == true;
        _readyPickups = {
          for (final item in items)
            if (item['state'] == 'CURRENT')
              item['storeId'] as String: item['readyCount'] as int
        };
        _activityExpiresAt = DateTime.tryParse(d['expiresAt'] ?? '');
        _activityError = d['enabled'] != true
            ? 'أوقفت الإدارة عرض النشاط حاليًا.'
            : items.any((i) => i['state'] == 'UPDATING')
                ? 'بعض المتاجر قيد التحديث.'
                : null;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _readyPickups = {};
          _activityExpiresAt = null;
          _activityError = 'تعذر تحديث نشاط الاستلام. أعد المحاولة.';
        });
    } finally {
      if (mounted) {
        setState(() => _activityLoading = false);
        _updateMapMarkers();
        _pickupHaloExpiryTimer?.cancel();
        final remaining = _activityExpiresAt?.difference(DateTime.now());
        if (remaining != null && remaining > Duration.zero) {
          _pickupHaloExpiryTimer = Timer(remaining, () {
            if (mounted) _updateMapMarkers();
          });
        }
      }
    }
  }

  void _showPickupActivity() {
    final enabledByAdmin = _mapData?.mapTools?['heatEnabled'] == true;
    showModalBottomSheet(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
            builder: (c, update) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        const Expanded(
                            child: Text('نشاط الاستلام الحالي',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondary))),
                        IconButton(
                            tooltip: 'إغلاق',
                            onPressed: () => Navigator.pop(c),
                            icon: const Icon(Icons.close,
                                color: AppColors.secondary))
                      ]),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('إظهار النشاط على الخريطة'),
                          value: _heatEnabled,
                          activeTrackColor: AppColors.secondary,
                          onChanged: !enabledByAdmin
                              ? null
                              : (enabled) async {
                                  setState(() {
                                    _heatEnabled = enabled;
                                    _readyPickups = {};
                                    _activityExpiresAt = null;
                                  });
                                  update(() {});
                                  _updateMapMarkers();
                                  _pickupHaloExpiryTimer?.cancel();
                                  _mapActivityTimer?.cancel();
                                  if (enabled) {
                                    final future = _refreshPickupActivity();
                                    update(() {});
                                    await future;
                                    if (sheetContext.mounted) update(() {});
                                    if (_heatEnabled)
                                      _mapActivityTimer = Timer.periodic(
                                          Duration(
                                              seconds: _activityRefreshSeconds),
                                          (_) => _refreshPickupActivity());
                                  }
                                }),
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.circle,
                              color: Color(0xFFE45252)),
                          title: const Text('نشاط أعلى'),
                          subtitle: Text(
                              '$_busyReadyMinimum طلبات جاهزة أو أكثر لم تُسند إلى سائق.')),
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.circle,
                              color: AppColors.primary),
                          title: const Text('طلبات جاهزة'),
                          subtitle: Text(
                              'من طلب واحد إلى ${_busyReadyMinimum - 1} طلبات جاهزة ولم تُسند إلى سائق.')),
                      const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.circle_outlined,
                              color: Color(0xFF8592A8)),
                          title: Text('دون توهج'),
                          subtitle: Text(
                              'لا توجد طلبات جاهزة مؤكدة حاليًا، أو لم يكتمل تحديث البيانات.')),
                      if (!enabledByAdmin)
                        const Text(
                            'نشاط الاستلام غير متاح حاليًا وفق إعدادات الإدارة أو تعذر تحميلها.',
                            style: TextStyle(color: AppColors.secondary)),
                      if (_activityLoading)
                        const LinearProgressIndicator(
                            color: AppColors.secondary),
                      if (_activityError != null)
                        Text(_activityError!,
                            style: const TextStyle(color: AppColors.secondary)),
                      const SizedBox(height: 8),
                      const Text(
                          'تعكس الخريطة آخر تحديث، وقد تُسند الطلبات أو تُلغى بعده. التوهج لا يضمن وصول عرض ولا يتجاوز شروط الأهلية والموجات.',
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: Color(0xFF53627B))),
                    ]))));
  }

  void _showMapSupport() {
    final configuredPhone = _mapData?.customerServicePhone ?? '';
    final phone = RegExp(r'^\+?[0-9 ()-]{7,24}$').hasMatch(configuredPhone)
        ? configuredPhone.trim()
        : '';
    showModalBottomSheet(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        builder: (c) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('خدمة العملاء والإبلاغ',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondary))),
                    IconButton(
                        tooltip: 'إغلاق',
                        onPressed: () => Navigator.pop(c),
                        icon:
                            const Icon(Icons.close, color: AppColors.secondary))
                  ]),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.phone_outlined,
                          color: AppColors.secondary),
                      title: const Text('الاتصال بخدمة العملاء'),
                      subtitle: Text(phone.isEmpty
                          ? 'رقم خدمة العملاء لم يُضبط بعد؛ يمكنك مراسلة الدعم.'
                          : phone),
                      onTap: phone.isEmpty
                          ? null
                          : () async {
                              final opened = await launchUrl(
                                  Uri(scheme: 'tel', path: phone));
                              if (!opened && mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('تعذر فتح الاتصال.')));
                            }),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.chat_bubble_outline,
                          color: AppColors.secondary),
                      title: const Text('الإبلاغ أو مراسلة الدعم'),
                      subtitle: const Text('تواصل مباشر مع فريق خدمة العملاء'),
                      onTap: () {
                        Navigator.pop(c);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const LiveChatScreen()));
                      }),
                ])));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map background (full screen like Spark)
          _buildMapView(),

          // Bottom draggable sheet that starts minimized
          _buildDraggableBottomSheet(),
          Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              right: 16,
              child: DriverMapButton(
                  icon: Icons.home_outlined,
                  label: 'المزيد والحساب',
                  onPressed: () => ref
                      .read(selectedTabProvider.notifier)
                      .state = DriverTabs.more)),
          Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 16,
              child: DriverMapButton(
                  icon: Icons.search,
                  label: 'بحث المطاعم والمتاجر',
                  onPressed: _searchMapStores)),
          if (_heatEnabled &&
              _activityIsTestData &&
              _activityExpiresAt?.isAfter(DateTime.now()) == true)
            Positioned(
                top: MediaQuery.paddingOf(context).top +
                    (_storeSearchQuery.isEmpty ? 72 : 120),
                left: 16,
                right: 16,
                child: const Center(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.all(Radius.circular(16))),
                        child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.science_outlined,
                                  size: 16, color: AppColors.secondary),
                              SizedBox(width: 6),
                              Text('نشاط تجريبي مؤقت',
                                  style: TextStyle(
                                      color: AppColors.secondary, fontSize: 12))
                            ]))))),
          if (_storeSearchQuery.isNotEmpty)
            Positioned(
                top: MediaQuery.paddingOf(context).top + 70,
                left: 16,
                right: 16,
                child: Center(
                    child: InputChip(
                        label: Text(_storeSearchQuery),
                        backgroundColor: Colors.white,
                        onDeleted: () {
                          setState(() => _storeSearchQuery = '');
                          _updateMapMarkers();
                        }))),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    if (_displayDriverLocation == null)
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.location_searching, color: Color(0xFF00509D)),
        const SizedBox(height: 12),
        const Text('بانتظار موقع السائق من GPS'),
        TextButton(
            onPressed: _initializeLocation, child: const Text('تحديث الموقع')),
      ]));
    return ValueListenableBuilder<double>(
        valueListenable: _locationWavePhase,
        builder: (context, phase, _) => GoogleMap(
              circles: _locationWaves(
                  MediaQuery.of(context).disableAnimations ? .2 : phase),
              onCameraMove: (position) {
                _locationWaveZoom = position.zoom;
              },
              initialCameraPosition: CameraPosition(
                target: _driverMapPoint,
                zoom: 14,
              ),
              markers: _markers.map((marker) {
                if (marker.markerId != const MarkerId('driver_location') ||
                    _driverBreathingIcons.isEmpty) return marker;
                final motionOff = MediaQuery.of(context).disableAnimations;
                final index = motionOff
                    ? 0
                    : (phase * _driverBreathingIcons.length).floor() %
                        _driverBreathingIcons.length;
                return marker.copyWith(iconParam: _driverBreathingIcons[index]);
              }).toSet(),
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: MapType.normal, // خريطة شوارع عادية
              compassEnabled: true,
              rotateGesturesEnabled: true,
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: true,
              zoomGesturesEnabled: true,
              mapToolbarEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
                unawaited(_ensureDriverMapMarker());
                _loadMapData();
              },
            ));
  }

  /// Load map data from backend API
  Future<void> _loadMapData() async {
    if (_isLoadingMapData) return;

    setState(() {
      _isLoadingMapData = true;
    });

    try {
      // ⏰ انتظار قليلاً للتأكد من جاهزية Auth token
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      await _requireDispatchPosition();
      final data = await MapDataService.fetchMapData(
        lat:
            _dispatchLat, // Fresh GPS, or the explicitly scoped staging test override.
        lng: _dispatchLng,
      );

      if (!mounted) return;

      setState(() {
        _outsideCoverageNoticeShown = false;
        _outsideCoverageConfirmed = false;
        _mapData = data;
        _updateMapMarkers();
        _isLoadingMapData = false;
      });

      // 🔄 بدء التحديث التلقائي لحالة المطاعم بعد التحميل الأول
      _startStoresStatusAutoRefresh();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMapData = false;
      });

      if (e is MapDataFailure && e.kind == MapDataFailureKind.outsideCoverage) {
        _markOutsideCoverage();
        await _showOutsideCoverage();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is MapDataFailure ? e.toString() : 'تعذر تحديد موقعك. تحقق من إذن الموقع وGPS ثم أعد المحاولة.'),
        backgroundColor: AppColors.secondary,
        action: SnackBarAction(label: 'إعادة المحاولة', textColor: Colors.white, onPressed: () => unawaited(_loadMapData())),
      ));
    }
  }

  /// 🎨 Create custom circular marker icon
  /// Creates a light navy gradient marker with a navy category icon
  Future<BitmapDescriptor> _createStoreMarkerIcon({
    required String category,
    required bool isCoreRegion,
    required int hotScore,
    required bool isOpen,
    required int activityLevel,
  }) async {
    try {
      // Select icon based on category
      IconData iconData;
      switch (category.toLowerCase()) {
        case 'restaurant':
        case 'مطعم':
          iconData = Icons.restaurant;
          break;
        case 'store':
        case 'supermarket':
        case 'grocery':
        case 'متجر':
        case 'سوبر ماركت':
          iconData = Icons.shopping_basket;
          break;
        case 'pharmacy':
        case 'صيدلية':
          iconData = Icons.local_pharmacy;
          break;
        case 'cafe':
        case 'coffee':
        case 'مقهى':
          iconData = Icons.local_cafe;
          break;
        case 'bakery':
        case 'مخبز':
          iconData = Icons.bakery_dining;
          break;
        default:
          iconData = Icons.store;
      }

      // Size based on priority
      final double baseSize = isCoreRegion ? 44.0 : 40.0;
      final double iconSize = isCoreRegion ? 20.0 : 18.0;
      final double canvasSize = baseSize + 4 + (activityLevel > 0 ? 24 : 0);
      final double centerOffset = canvasSize / 2;

      // Colors
      const Color iconColor = AppColors.secondary; // Navy
      final double opacity = isCoreRegion ? 1.0 : 0.7;

      // Start drawing
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      paintStoreMarkerHalo(canvas, Offset(centerOffset, centerOffset),
          baseSize / 2, activityLevel);

      // 🔥 Draw hot glow effect
      if (hotScore >= 5) {
        Color glowColor = hotScore >= 10
            ? Colors.red.withOpacity(0.6)
            : Colors.orange.withOpacity(0.5);

        final glowPaint = Paint()
          ..color = glowColor
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

        canvas.drawCircle(
          Offset(centerOffset, centerOffset),
          (baseSize / 2) + 6,
          glowPaint,
        );
      }

      // Light navy tints behind the darker category icons.
      final circlePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.white, AppColors.secondary, 0.12)!
                .withValues(alpha: opacity),
            Color.lerp(Colors.white, AppColors.secondary, 0.24)!
                .withValues(alpha: opacity),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(centerOffset, centerOffset),
          radius: baseSize / 2,
        ))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(centerOffset, centerOffset),
        baseSize / 2,
        circlePaint,
      );

      // Draw border
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(
        Offset(centerOffset, centerOffset),
        baseSize / 2,
        borderPaint,
      );

      // Draw icon
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );

      textPainter.text = TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: iconData.fontFamily,
          color: iconColor.withOpacity(opacity),
          fontWeight: FontWeight.bold,
        ),
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          centerOffset - (textPainter.width / 2),
          centerOffset - (textPainter.height / 2),
        ),
      );

      // Draw hot score number
      if (hotScore >= 5) {
        final scorePainter = TextPainter(
          textDirection: TextDirection.ltr,
        );

        scorePainter.text = TextSpan(
          text: hotScore.toString(),
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(opacity),
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        );

        scorePainter.layout();
        scorePainter.paint(
          canvas,
          Offset(
            centerOffset - (scorePainter.width / 2),
            centerOffset + (baseSize / 2) - 18,
          ),
        );
      }

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        canvasSize.toInt(),
        canvasSize.toInt(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

      return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    } catch (e) {
      print('❌ خطأ في إنشاء أيقونة مخصصة: $e');
      return BitmapDescriptor.defaultMarkerWithHue(
        hotScore >= 10
            ? BitmapDescriptor.hueRed
            : hotScore >= 5
                ? BitmapDescriptor.hueOrange
                : BitmapDescriptor.hueBlue,
      );
    }
  }

  /// 📍 Create driver location marker (blue circle)
  Future<BitmapDescriptor> _createDriverLocationMarker(
      {double breath = 1}) async {
    try {
      const double size = 32.0;
      final double circleSize = 15.0 + breath;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // رسم الدائرة الزرقاء (اللون الثانوي للتطبيق)
      final circlePaint = Paint()
        ..color = AppColors.secondary.withValues(alpha: .86 + .14 * breath)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        circleSize / 2,
        circlePaint,
      );

      // رسم حدود بيضاء للوضوح
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        circleSize / 2,
        borderPaint,
      );

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

      return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    } catch (e) {
      print('❌ خطأ في إنشاء marker موقع السائق: $e');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  /// 🖼️ Create custom info window marker with store photo and name
  /// This creates a marker that shows the store photo with name when tapped
  Future<BitmapDescriptor> _createInfoWindowMarkerWithPhoto({
    required String storeName,
    required String? photoUrl,
    required String category,
  }) async {
    try {
      const double width = 200;
      const double height = 80;
      const double imageSize = 60;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw white background with shadow
      final backgroundPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      // Shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(2, 2, width, height),
          const Radius.circular(12),
        ),
        shadowPaint,
      );

      // Background
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, width, height),
          const Radius.circular(12),
        ),
        backgroundPaint,
      );

      // Try to load and draw store image
      ui.Image? storeImage;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(photoUrl));
          if (response.statusCode == 200) {
            final bytes = response.bodyBytes;
            storeImage = await decodeImageFromList(bytes);
          }
        } catch (e) {
          print('⚠️ Failed to load store image: $e');
        }
      }

      // Draw image or fallback icon
      if (storeImage != null) {
        final srcRect = Rect.fromLTWH(
          0,
          0,
          storeImage.width.toDouble(),
          storeImage.height.toDouble(),
        );
        const dstRect = Rect.fromLTWH(10, 10, imageSize, imageSize);

        // Clip to rounded rectangle
        canvas.save();
        canvas.clipRRect(
          RRect.fromRectAndRadius(dstRect, const Radius.circular(8)),
        );
        canvas.drawImageRect(storeImage, srcRect, dstRect, Paint());
        canvas.restore();
      } else {
        // Draw fallback icon
        final iconPaint = Paint()..color = Colors.grey[300]!;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(10, 10, imageSize, imageSize),
            const Radius.circular(8),
          ),
          iconPaint,
        );

        // Draw category icon
        IconData iconData = category.toLowerCase() == 'restaurant'
            ? Icons.restaurant
            : category.toLowerCase() == 'pharmacy'
                ? Icons.local_pharmacy
                : Icons.store;

        final textPainter = TextPainter(textDirection: TextDirection.ltr);
        textPainter.text = TextSpan(
          text: String.fromCharCode(iconData.codePoint),
          style: TextStyle(
            fontSize: 30,
            fontFamily: iconData.fontFamily,
            color: Colors.grey[600],
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            10 + (imageSize - textPainter.width) / 2,
            10 + (imageSize - textPainter.height) / 2,
          ),
        );
      }

      // Draw store name
      final namePainter = TextPainter(
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
      );

      namePainter.text = TextSpan(
        text: storeName,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      );

      namePainter.layout(maxWidth: width - imageSize - 30);
      namePainter.paint(
        canvas,
        Offset(
          width - namePainter.width - 10,
          (height - namePainter.height) / 2,
        ),
      );

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

      return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    } catch (e) {
      print('❌ خطأ في إنشاء info window مخصص: $e');
      return BitmapDescriptor.defaultMarker;
    }
  }

  /// Update map markers based on loaded data with proper visual hierarchy
  void _updateMapMarkers() async {
    if (_mapData == null) return;

    final generation = ++_markerBuildVersion;
    final nextMarkers = <Marker>{};

    // 📍 إضافة marker لموقع السائق الحالي
    try {
      final driverIcon =
          _driverLocationIcon ?? await _createDriverLocationMarker();
      _driverLocationIcon = driverIcon;
      nextMarkers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: _driverMapPoint,
          icon: driverIcon,
          anchor: const Offset(0.5, 0.5),
          zIndex: 1000, // أعلى من باقي الـ markers
        ),
      );
    } catch (e) {
      print('⚠️ فشل إنشاء marker موقع السائق: $e');
    }

    // Add store markers with design based on expansion_priority
    for (final store
        in matchingMapStores(_mapData!.nearbyStores, _storeSearchQuery)) {
      // 🎨 تحديد اللون حسب الأولوية:
      // - priority 0 (Core): أصفر كامل (hueYellow = 60)
      // - priority 1 (Extended): أصفر فاتح (hueOrange = 30)
      // - Hot stores: أحمر مع توهج

      if (store.isHot) {
        // 🔥 المتاجر الساخنة: أحمر
      } else if (store.expansionPriority == 0) {
        // ⭐ Core region: أصفر كامل
      } else if (store.expansionPriority == 1) {
        // 📍 Extended region: برتقالي (أصفر فاتح)
      } else {
        // منطقة بعيدة (نادرًا ما تظهر)
      }

      // Create custom circular marker
      final photoSize = store.expansionPriority == 0 ? 48.0 : 44.0;
      final icon = _storePhotoMarkers.cached(store.photoUrl, photoSize,
              activityLevel: _pickupMarkerLevel(store)) ??
          await _createStoreMarkerIcon(
            category: store.category,
            isCoreRegion: store.expansionPriority == 0,
            hotScore: 0,
            isOpen: store.isOpen,
            activityLevel: _pickupMarkerLevel(store),
          );

      nextMarkers.add(
        Marker(
          markerId: MarkerId(store.storeId),
          anchor: const Offset(.5, .5),
          position: LatLng(store.lat, store.lng),
          icon: icon,
          infoWindow: InfoWindow(
            title: store.name,
          ),
          onTap: () => _showStoreDetails(store),
        ),
      );
    }

    if (!mounted || generation != _markerBuildVersion) return;
    setState(() {
      _markers
        ..clear()
        ..addAll(nextMarkers);
    });
    unawaited(_loadStoreMarkerPhotos(generation));
  }

  Future<void> _loadStoreMarkerPhotos(int generation) async {
    final stores =
        matchingMapStores(_mapData?.nearbyStores ?? [], _storeSearchQuery);
    for (var i = 0; i < stores.length; i += 4) {
      if (!mounted || generation != _markerBuildVersion) return;
      await Future.wait(stores.skip(i).take(4).map((store) async {
        final size = store.expansionPriority == 0 ? 48.0 : 44.0;
        final level = _pickupMarkerLevel(store);
        if (_storePhotoMarkers.cached(store.photoUrl, size,
                activityLevel: level) !=
            null) return;
        final icon = await _storePhotoMarkers.load(store.photoUrl, size,
            activityLevel: level);
        if (!mounted || icon == null || generation != _markerBuildVersion)
          return;
        final stillCurrent = (_mapData?.nearbyStores ?? []).any(
            (s) => s.storeId == store.storeId && s.photoUrl == store.photoUrl);
        if (!stillCurrent) return;
        final found =
            _markers.where((m) => m.markerId == MarkerId(store.storeId));
        if (found.isEmpty) return;
        final marker = found.first;
        setState(() {
          _markers.remove(marker);
          _markers.add(marker.copyWith(iconParam: icon));
        });
      }));
    }
  }

  /// Show store details in bottom sheet when tapped
  /// 🗺️ Open maps application with navigation from driver location to store
  Future<void> _openMapsNavigation(NearbyStore store) async {
    // استخدام الإحداثيات الثابتة للاختبار أو الموقع الفعلي
    final driverLat = _currentPosition?.latitude ?? _dispatchLat;
    final driverLng = _currentPosition?.longitude ?? _dispatchLng;
    final storeLat = store.lat;
    final storeLng = store.lng;

    debugPrint('');
    debugPrint('🚗🗺️ ========== NAVIGATION REQUEST ==========');
    debugPrint('📍 Driver Location:');
    debugPrint('   Latitude:  $driverLat');
    debugPrint('   Longitude: $driverLng');
    debugPrint('📍 Store Location:');
    debugPrint('   Name:      ${store.name}');
    debugPrint('   Latitude:  $storeLat');
    debugPrint('   Longitude: $storeLng');
    debugPrint('   Address:   ${store.address}');

    // حساب المسافة التقريبية
    final distance = store.distanceKm;
    debugPrint('📏 Distance: ${distance.toStringAsFixed(2)} km');

    // ✅ Apple Maps - التنسيق الصحيح الذي يدعم الاتجاهات
    // استخدام daddr فقط مع ll (current location) يعمل بشكل أفضل
    final appleMapsAppUrl =
        'maps://?ll=$storeLat,$storeLng&q=${Uri.encodeComponent(store.name)}&saddr=$driverLat,$driverLng&daddr=$storeLat,$storeLng';

    debugPrint('');
    debugPrint('🔗 Apple Maps App URL:');
    debugPrint(appleMapsAppUrl);

    // ✅ Google Maps App URL - التنسيق الموثوق
    final googleMapsAppUrl =
        'comgooglemaps://?saddr=$driverLat,$driverLng&daddr=$storeLat,$storeLng&directionsmode=driving';

    debugPrint('');
    debugPrint('🔗 Google Maps App URL:');
    debugPrint(googleMapsAppUrl);

    // ✅ Waze App URL (إذا كان مثبتاً - شائع في العراق)
    final wazeAppUrl = 'waze://?ll=$storeLat,$storeLng&navigate=yes';

    debugPrint('');
    debugPrint('🔗 Waze App URL:');
    debugPrint(wazeAppUrl);

    final appleMapsUrl = Uri.parse(appleMapsAppUrl);
    final googleMapsUrl = Uri.parse(googleMapsAppUrl);
    final wazeUrl = Uri.parse(wazeAppUrl);

    debugPrint('=========================================');
    debugPrint('');

    try {
      // عرض dialog لاختيار التطبيق
      if (mounted) {
        final selectedApp = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('اختر تطبيق الخرائط'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.map, color: Colors.blue),
                  title: const Text('Apple Maps'),
                  subtitle: const Text('التطبيق الافتراضي'),
                  onTap: () => Navigator.pop(context, 'apple'),
                ),
                ListTile(
                  leading: const Icon(Icons.map, color: Colors.green),
                  title: const Text('Google Maps'),
                  subtitle: const Text('خرائط دقيقة للعراق'),
                  onTap: () => Navigator.pop(context, 'google'),
                ),
                ListTile(
                  leading: const Icon(Icons.navigation, color: Colors.cyan),
                  title: const Text('Waze'),
                  subtitle: const Text('ملاحة مباشرة'),
                  onTap: () => Navigator.pop(context, 'waze'),
                ),
              ],
            ),
          ),
        );

        if (selectedApp == null) return;

        // فتح التطبيق المحدد
        Uri? selectedUrl;
        String appName = '';

        switch (selectedApp) {
          case 'apple':
            selectedUrl = appleMapsUrl;
            appName = 'Apple Maps';
            debugPrint('🗺️ Opening Apple Maps App...');
            break;
          case 'google':
            selectedUrl = googleMapsUrl;
            appName = 'Google Maps';
            debugPrint('🗺️ Opening Google Maps App...');
            break;
          case 'waze':
            selectedUrl = wazeUrl;
            appName = 'Waze';
            debugPrint('🗺️ Opening Waze App...');
            break;
        }

        if (selectedUrl != null) {
          debugPrint('   From: ($driverLat,$driverLng)');
          debugPrint('   To:   ($storeLat,$storeLng)');

          // محاولة فتح التطبيق مباشرة (canLaunchUrl قد يفشل حتى لو التطبيق مثبت)
          try {
            final success = await launchUrl(
              selectedUrl,
              mode: LaunchMode.externalApplication,
            );

            if (success) {
              debugPrint('✅ $appName opened successfully');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🗺️ فتح $appName مع الاتجاهات'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              return;
            } else {
              debugPrint('⚠️ $appName launch returned false');
              throw Exception('Launch returned false');
            }
          } catch (e) {
            debugPrint('❌ $appName error: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ $appName غير مثبت على هذا الجهاز'),
                  backgroundColor: Colors.orange,
                  action: SnackBarAction(
                    label: 'جرب آخر',
                    textColor: Colors.white,
                    onPressed: () => _openMapsNavigation(store),
                  ),
                ),
              );
            }
          }
        }
      }

      // إذا فشل كل شيء
      debugPrint('❌ No maps app available');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ لا يوجد تطبيق خرائط متاح على هذا الجهاز'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error opening maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح الخرائط: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showStoreDetails(NearbyStore store) {
    // 🔄 إيجاد البيانات المحدثة للمطعم من _mapData
    final updatedStore = _mapData?.nearbyStores.firstWhere(
          (s) => s.storeId == store.storeId,
          orElse: () => store, // استخدام البيانات القديمة إذا لم توجد محدثة
        ) ??
        store;

    print(
        '📊 Store details - Old: isOpen=${store.isOpen}, acceptingOrders=${store.acceptingOrders}');
    print(
        '📊 Store details - New: isOpen=${updatedStore.isOpen}, acceptingOrders=${updatedStore.acceptingOrders}');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🏪 Store name and category
            Row(
              children: [
                // صورة المطعم الحقيقية - دائرية وأصغر
                ClipOval(
                  child: updatedStore.photoUrl != null &&
                          updatedStore.photoUrl!.isNotEmpty
                      ? Image.network(
                          updatedStore.photoUrl!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                updatedStore.category == 'restaurant'
                                    ? Icons.restaurant
                                    : updatedStore.category == 'pharmacy'
                                        ? Icons.local_pharmacy
                                        : Icons.store,
                                color: Colors.grey[400],
                                size: 24,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            updatedStore.category == 'restaurant'
                                ? Icons.restaurant
                                : updatedStore.category == 'pharmacy'
                                    ? Icons.local_pharmacy
                                    : Icons.store,
                            color: Colors.grey[400],
                            size: 24,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        updatedStore.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        updatedStore.category == 'restaurant'
                            ? 'مطعم'
                            : updatedStore.category == 'pharmacy'
                                ? 'صيدلية'
                                : 'متجر',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // 🔥 Hot indicator
                if (updatedStore.isHot)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red, width: 1),
                    ),
                    child: const Row(
                      children: [
                        Text('🔥', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 4),
                        Text(
                          'Hot',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // 📍 Distance
            Row(
              children: [
                Icon(Icons.route, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${updatedStore.distanceKm.toStringAsFixed(1)} كم من موقعك',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 📍 Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    updatedStore.address,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ⭐ Priority level
            Row(
              children: [
                Icon(
                  updatedStore.expansionPriority == 0
                      ? Icons.star
                      : Icons.star_border,
                  size: 20,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  updatedStore.expansionPriority == 0
                      ? 'منطقة عمل أساسية (Core)'
                      : 'منطقة موسّعة (Extended)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 🟢 Open/Closed/Busy status - نظام محسّن مثل wizzuser
            Row(
              children: [
                Icon(
                  _getStoreStatusIcon(updatedStore),
                  size: 20,
                  color: _getStoreStatusColor(updatedStore),
                ),
                const SizedBox(width: 8),
                Text(
                  _getStoreStatusText(updatedStore),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _getStoreStatusColor(updatedStore),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 🧭 Navigate button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _openMapsNavigation(updatedStore);
                },
                icon: const Icon(Icons.navigation, size: 22),
                label: const Text(
                  'توجيه إلى المتجر',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, // اللون الأساسي الأصفر
                  foregroundColor:
                      Colors.black87, // نص أسود للقراءة الواضحة على الأصفر
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        28), // حواف دائرية مثل زر شارك الآن
                  ),
                  elevation: 4,
                  shadowColor: AppColors.primary.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOldMapView() {
    return Container(
      color: const Color(0xFFF5F5F5), // خلفية رمادية فاتحة أنيقة
      child: Stack(
        children: [
          // Simple map-like gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF8F9FA),
                  Color(0xFFF1F3F4),
                ],
              ),
            ),
          ),

          // Roads simulation
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).size.height * 0.3,
            child: Container(
              height: 4,
              color: Colors.grey[400],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).size.height * 0.6,
            child: Container(
              height: 4,
              color: Colors.grey[400],
            ),
          ),

          // Current location (blue dot like Spark)
          if (_currentPosition != null)
            Positioned(
              left: MediaQuery.of(context).size.width * 0.5 - 12,
              top: MediaQuery.of(context).size.height * 0.45,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            ),

          // Sample delivery hotspots (red circles like Spark)
          ...List.generate(3, (index) {
            final positions = [
              {'left': 0.25, 'top': 0.25},
              {'left': 0.75, 'top': 0.35},
              {'left': 0.4, 'top': 0.7},
            ];
            final pos = positions[index];

            return Positioned(
              left: MediaQuery.of(context).size.width * pos['left']!,
              top: MediaQuery.of(context).size.height * pos['top']!,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.black87,
                  size: 20,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDraggableBottomSheet() {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(children: [
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.25, // Start small at bottom like Spark
          minChildSize: 0.25, // Minimum size to stay visible
          maxChildSize: 0.85, // Maximum when fully expanded
          snap: true,
          snapSizes: const [0.25, 0.5, 0.85],
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar for dragging
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Sheet content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: IgnorePointer(
                        ignoring: _isStartingOnline,
                        child: AnimatedOpacity(
                          opacity: _onlineSheetOpacity,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeInOut,
                          child: _isStartingOnline && !_isSearchingForOffers
                              ? const Center(
                                  child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(),
                                ))
                              : _buildSheetContent(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        AnimatedBuilder(
            animation: _sheetController,
            builder: (context, _) {
              final extent =
                  _sheetController.isAttached ? _sheetController.size : .25;
              if (constraints.maxHeight * (1 - extent) < 310)
                return const SizedBox.shrink();
              return Positioned(
                  right: 16,
                  bottom: constraints.maxHeight * extent + 12,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DriverMapButton(
                        icon: Icons.local_fire_department_outlined,
                        label: 'نشاط الاستلام الحالي',
                        selected: _heatEnabled,
                        onPressed: _showPickupActivity),
                    const SizedBox(height: 8),
                    DriverMapButton(
                        icon: Icons.bar_chart_rounded,
                        label: 'إحصائيات أوقات الطلب',
                        onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            backgroundColor: Colors.white,
                            builder: (_) => const MapDemandSheet())),
                    const SizedBox(height: 8),
                    DriverMapButton(
                        icon: Icons.support_agent_outlined,
                        label: 'الاتصال والإبلاغ للدعم',
                        onPressed: _showMapSupport),
                    const SizedBox(height: 8),
                    DriverMapButton(
                        icon: Icons.my_location,
                        label: 'توسيط الخريطة على موقعي',
                        onPressed: _centerDriverMap),
                  ]));
            }),
        if (!_isSearchingForOffers)
          AnimatedBuilder(
            animation: _sheetController,
            builder: (context, child) {
              final extent =
                  _sheetController.isAttached ? _sheetController.size : 0.25;
              return Positioned(
                left: 0,
                right: 0,
                bottom: math.min(constraints.maxHeight * extent + 12,
                    math.max(0, constraints.maxHeight - 92)),
                child: Center(child: child),
              );
            },
            child: GoOnlineButton(
              busy: _isStartingOnline || _isCheckingWalletBalance || _checkingCoverageForStart,
              onPressed: _startSearchingForOffers,
            ),
          ),
      ]);
    });
  }

  Widget _buildSheetContent() {
    if (_isSearchingForOffers) {
      return _buildSearchingContent();
    } else {
      return _buildInitialContent();
    }
  }

  Widget _buildSearchingContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              const Row(
                textDirection: TextDirection.rtl,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: 8),
                  ),
                  SizedBox(width: 6),
                  Text('متصل',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 270),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showSparkNowTimeSelection,
                        borderRadius: BorderRadius.circular(18),
                        child: ConstrainedBox(
                          // Keep a comfortable touch target around the slim pill.
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.secondary.withValues(alpha: .045),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.secondary
                                      .withValues(alpha: .14),
                                ),
                              ),
                              child: Row(
                                textDirection: TextDirection.rtl,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Flexible(
                                    child: Text(
                                      'الحصول على طلبات حتى',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF53627B)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatTime(_searchEndTime ??
                                        DateTime.now()
                                            .add(const Duration(hours: 1))),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 5),
                                  const Icon(Icons.edit_outlined,
                                      size: 13, color: AppColors.secondary),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Searching indicator
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.secondary),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'البحث عن طلبات حولك',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // 🌊 Wave System Offers (NEW - PRIORITY)
        if (_currentWaveOffers.isNotEmpty) ...[
          const SizedBox(height: 20),
          ...List.generate(_currentWaveOffers.length, (index) {
            final offer = _currentWaveOffers[index];
            return _buildWaveOfferCard(offer);
          }),
        ],

        // Available offers list (Legacy - Deprecated)
        if (_availableOffers.isNotEmpty) ...[
          const SizedBox(height: 20),
          ...List.generate(_availableOffers.length, (index) {
            final offer = _availableOffers[index];
            return _buildOfferCard(offer);
          }),
        ],

        // إظهار المحتوى المشترك فقط عندما لا توجد طلبات
        if (_availableOffers.isEmpty && _currentWaveOffers.isEmpty) ...[
          const SizedBox(height: 20),
          _buildCommonContent(),
        ],
      ],
    );
  }

  Widget _buildInitialContent() {
    return Column(
      children: [
        // Error message display
        if (_errorMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15), // أزرق شفاف
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.secondary.withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.secondary, // أزرق
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.secondary, // أزرق
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.primary, // أصفر
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

        _buildCommonContent(),
      ],
    );
  }

  Widget _buildCommonContent() {
    return Column(
      children: [
        const LocationPermissionNotice(),

        // Popular offer times section
        if (_outsideCoverageConfirmed)
          const Padding(padding: EdgeInsets.all(20), child: Text('أنت خارج مناطق الخدمة حاليًا', style: TextStyle(color: AppColors.secondary)))
        else const DemandCard(),
      ],
    );
  }

  @override
  void dispose() {
    DriverSearchApiService.confirmedStopEvents
        .removeListener(_onConfirmedSearchStop);
    _searchPositionTimer?.cancel();
    _mapActivityTimer?.cancel();
    _pickupHaloExpiryTimer?.cancel();
    _locationWaveTimer?.cancel();
    _locationWavePhase.dispose();
    _displayLocationSubscription?.cancel();
    _offerAuthEpoch++;
    _performancePreview.clear();
    _offerClosureScope.bind(null);
    _offerAuthSubscription?.cancel();
    _financialPushSubscription?.cancel();
    try {
      print('🧹 Disposing SparkHomeSimpleArabic resources...');

      // 🔔 Cancel notification tap subscription
      try {
        _notificationTapSubscription?.cancel();
        print('🔔 Notification tap subscription cancelled');
      } catch (notifError) {
        print('⚠️ Error cancelling notification subscription: $notifError');
      }

      // 🌊 Cancel Wave System subscriptions
      try {
        _waveOfferSubscription?.cancel();
        _offerExpiredSubscription?.cancel();
        _offerTakenSubscription?.cancel();
        _currentWaveOffer = null;
        print('🌊 Wave System subscriptions cancelled');
      } catch (waveError) {
        print('⚠️ Error cancelling Wave subscriptions: $waveError');
      }

      // 🆕 Cancel offer expiry cleanup timer
      try {
        if (_offerExpiryCleanupTimer != null &&
            _offerExpiryCleanupTimer!.isActive) {
          _offerExpiryCleanupTimer!.cancel();
          _offerExpiryCleanupTimer = null;
        }
        print('🧹 Offer expiry cleanup timer cancelled');
      } catch (cleanupError) {
        print('⚠️ Error cancelling cleanup timer: $cleanupError');
      }

      // Clear lists and data structures first
      try {
        _availableOffers.clear();
        _rejectedOfferIds.clear();
        _timeOptions?.clear();
        print('📊 Data structures cleared');
      } catch (listError) {
        print('⚠️ Error clearing data structures: $listError');
      }

      // إلغاء Timers with null checks
      try {
        if (_searchTimer != null && _searchTimer!.isActive) {
          _searchTimer!.cancel();
          _searchTimer = null;
        }
        // Legacy simulation removed - Wave System only
        if (_storesStatusRefreshTimer != null &&
            _storesStatusRefreshTimer!.isActive) {
          _storesStatusRefreshTimer!.cancel();
          _storesStatusRefreshTimer = null;
        }
        print('⏰ Timers cancelled safely');
      } catch (timerError) {
        print('⚠️ Error cancelling timers: $timerError');
      }

      // WebSocket callbacks are automatically cleaned up by service
      print('🔌 WebSocket cleanup handled by service');

      // تنظيف مشغل الصوت مع حماية إضافية
      try {
        _audioPlayer.stop(); // Stop any playing audio first
        _audioPlayer.dispose();
        print('🔊 Audio player disposed safely');
      } catch (audioError) {
        print('⚠️ Error disposing audio player: $audioError');
        // Try force dispose
        try {
          _audioPlayer.dispose();
        } catch (forceError) {
          print('🚨 Force dispose audio failed: $forceError');
        }
      }

      // تنظيف الcontrollers
      try {
        _sheetController.dispose();
        print('📋 Sheet controller disposed');
      } catch (controllerError) {
        print('⚠️ Error disposing sheet controller: $controllerError');
      }

      // Remove app lifecycle observer
      try {
        WidgetsBinding.instance.removeObserver(this);
        print('👁️ App lifecycle observer removed');
      } catch (observerError) {
        print('⚠️ Error removing lifecycle observer: $observerError');
      }

      // تنظيف الذاكرة والموارد الإضافية
      try {
        // Clear any remaining resources
        print('🧹 Additional cleanup completed');
      } catch (memoryError) {
        print('⚠️ Additional cleanup error: $memoryError');
      }

      print('✅ All resources disposed successfully');

      // Call super.dispose() at the very end
      super.dispose();
    } catch (e, stackTrace) {
      print('🚨 CRITICAL: Error in dispose: $e');
      print('Stack trace: $stackTrace');

      // Force cleanup in case of error
      try {
        _searchTimer?.cancel();
        _storesStatusRefreshTimer?.cancel();
        _audioPlayer.dispose();
        _sheetController.dispose();
      } catch (forceError) {
        print('🚨 Force cleanup failed: $forceError');
      }

      // تأكد من استدعاء super.dispose() حتى في حالة الخطأ
      try {
        super.dispose();
      } catch (superError) {
        print('🚨 Error in super.dispose(): $superError');
      }
    }
  }

  Widget _buildSparkNowModal(StateSetter setModalState) {
    final timeOptions = _timeOptions ?? <DateTime>[];
    final busy = _isCheckingWalletBalance || _isStartingOnline || _checkingCoverageForStart;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return Container(
      height: MediaQuery.sizeOf(context).height * .78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFDFE3EB),
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.schedule_rounded,
                    color: AppColors.secondary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                _isSearchingForOffers ? 'تحديث البحث' : 'انطلق',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary),
              )),
              IconButton(
                tooltip: 'إغلاق',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded,
                    color: Color(0xFF748198), size: 22),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('اختر موعد انتهاء استقبال الطلبات',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.secondary.withValues(alpha: .65))),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              itemCount: timeOptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final time = timeOptions[index];
                final selected = _selectedEndTime?.millisecondsSinceEpoch ==
                    time.millisecondsSinceEpoch;
                return Semantics(
                  selected: selected,
                  child: Material(
                    color: selected
                        ? AppColors.secondary.withValues(alpha: .065)
                        : const Color(0xFFF8F9FC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                          color: selected
                              ? AppColors.secondary
                              : const Color(0xFFE9ECF2)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => setModalState(() => _selectedEndTime = time),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        child: Row(children: [
                          Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 21,
                              color: selected
                                  ? AppColors.secondary
                                  : const Color(0xFFA2ADBD)),
                          const SizedBox(width: 12),
                          Text(_formatTime(time),
                              style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.secondary,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal)),
                          const Spacer(),
                          const Icon(Icons.access_time_rounded,
                              size: 17, color: Color(0xFF8A97AA)),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEEF0F5))),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_isSearchingForOffers) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: busy
                        ? null
                        : () {
                            Navigator.pop(context);
                            _stopSearching();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.secondary,
                      elevation: 0,
                      shape: buttonShape,
                    ),
                    icon: const Icon(Icons.pause_rounded, size: 20),
                    label: const Text('إيقاف البحث',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(children: [
                Expanded(
                    child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _selectedEndTime != null && !busy
                        ? () => _confirmSparkNow(_selectedEndTime!)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE9EDF4),
                      disabledForegroundColor: const Color(0xFF8793A6),
                      elevation: 0,
                      shape: buttonShape,
                    ),
                    child: busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_isSearchingForOffers ? 'تحديث الوقت' : 'انطلق',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                )),
                const SizedBox(width: 10),
                SizedBox(
                  width: 88,
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      shape: buttonShape,
                    ),
                    child: const Text('إلغاء', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // ========== 🏪 Store Status Helpers (like wizzuser) ==========

  /// تحديد أيقونة حالة المطعم بناءً على المنطق الصحيح
  /// 🔄 بدء التحديث التلقائي لحالة المطاعم (Polling مثل تطبيق المستخدم)
  void _startStoresStatusAutoRefresh() {
    // إلغاء أي Timer سابق
    _storesStatusRefreshTimer?.cancel();

    // بدء التحديث التلقائي كل 30 ثانية (نفس تطبيق wizzuser)
    _storesStatusRefreshTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _mapData != null) {
        print('🔄 Driver: تحديث تلقائي لحالة المطاعم (Polling)');
        _refreshStoresStatus();
      }
    });

    print('✅ Driver: بدء نظام التحديث التلقائي لحالة المطاعم (كل 30 ثانية)');
  }

  /// 🛑 إيقاف التحديث التلقائي
  void _stopStoresStatusAutoRefresh() {
    _storesStatusRefreshTimer?.cancel();
    _storesStatusRefreshTimer = null;
    print('⏹️ Driver: إيقاف التحديث التلقائي لحالة المطاعم');
  }

  /// 🔄 تحديث حالة المطاعم عن طريق مسح الكاش وإعادة التحميل
  Future<void> _refreshStoresStatus() async {
    if (!mounted || _mapData == null) return;

    try {
      // مسح الكاش لجميع المطاعم الظاهرة
      for (final store in _mapData!.nearbyStores) {
        await BusinessStatusCache.forceInvalidateBusinessStatus(store.storeId);
      }

      // إعادة تحميل بيانات الخريطة (سيجلب الحالة الجديدة من Backend)
      await _requireDispatchPosition();
      final data = await MapDataService.fetchMapData(
        lat: _dispatchLat,
        lng: _dispatchLng,
      );

      if (!mounted) return;

      setState(() => _mapData = data);
      _updateMapMarkers();
      if (_heatEnabled) unawaited(_refreshPickupActivity());
    } catch (e) {
      print('❌ Driver: خطأ في تحديث حالة المطاعم: $e');
    }
  }

  /// مغلق: خارج ساعات العمل أو isClosed=true
  /// مشغول: acceptingOrders=false
  /// مفتوح: isOpen=true AND acceptingOrders=true
  IconData _getStoreStatusIcon(NearbyStore store) {
    if (!store.acceptingOrders) {
      return Icons.schedule; // مشغول - لا يستقبل طلبات
    }

    if (!store.isOpen) {
      return Icons.access_time; // مغلق - خارج ساعات العمل
    }

    return Icons.check_circle; // مفتوح ويستقبل طلبات
  }

  /// تحديد لون حالة المطعم
  Color _getStoreStatusColor(NearbyStore store) {
    if (!store.acceptingOrders) {
      return Colors.orange; // مشغول
    }

    if (!store.isOpen) {
      return Colors.red; // مغلق
    }

    return Colors.green; // مفتوح
  }

  /// تحديد نص حالة المطعم
  String _getStoreStatusText(NearbyStore store) {
    if (!store.acceptingOrders) {
      return 'مشغول'; // لا يستقبل طلبات (acceptingOrders=false من جدول Businesses)
    }

    if (!store.isOpen) {
      return 'مغلق'; // خارج ساعات العمل أو isClosed=true من جدول WorkingHours
    }

    return 'مفتوح الآن'; // مفتوح ويستقبل طلبات
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 🌊 WAVE SYSTEM HANDLERS
  // ═════════════════════════════════════════════════════════════════════════

  Future<String?> _bindOfferOwner() async {
    final epoch = _offerAuthEpoch;
    try {
      final user = await Amplify.Auth.getCurrentUser();
      if (!mounted || epoch != _offerAuthEpoch) return null;
      if (_offerClosureScope.owner != null &&
          _offerClosureScope.owner != user.userId) {
        setState(() {
          _currentWaveOffers.clear();
          _currentWaveOffer = null;
        });
      }
      _offerClosureScope.bind(user.userId);
      return user.userId;
    } catch (_) {
      if (mounted && epoch == _offerAuthEpoch) {
        _offerClosureScope.bind(null);
        setState(() {
          _currentWaveOffers.clear();
          _currentWaveOffer = null;
        });
      }
      return null;
    }
  }

  Future<void> _refreshOfferClosures() async {
    if (_closureRefreshInFlight || !mounted) return;
    _closureRefreshInFlight = true;
    final epoch = _offerAuthEpoch;
    try {
      final owner = await _bindOfferOwner();
      if (owner == null) return;
      final closures = await OfferClosureInbox.read(owner);
      if (!mounted ||
          epoch != _offerAuthEpoch ||
          _offerClosureScope.owner != owner) return;
      for (final closure in closures) {
        _handleWaveOfferTaken(closure.offerId,
            orderId: closure.orderId, cycleId: closure.cycleId);
      }
    } catch (_) {
      if (mounted && epoch == _offerAuthEpoch) {
        setState(() {
          _currentWaveOffers.clear();
          _currentWaveOffer = null;
        });
      }
    } finally {
      _closureRefreshInFlight = false;
    }
  }

  Future<bool> _offerStillVisible(WaveOffer offer) async {
    try {
      return await _offerClosureScope.allows(
          offerId: offer.offerId,
          orderId: offer.orderId,
          cycleId: offer.dispatchCycleId,
          expiresAt: offer.expiresAt);
    } catch (_) {
      return false;
    }
  }

  /// Both live offers and cached push offers consult the same closure scope.
  Future<void> _handleWaveOffer(WaveOffer waveOffer,
      {bool fromSocket = true}) async {
    try {
      final owner = await _bindOfferOwner();
      if (owner == null ||
          (fromSocket && _webSocketService.driverId != owner) ||
          !await _offerStillVisible(waveOffer) ||
          !mounted) return;
      setState(() {
        _currentWaveOffers.removeWhere((o) => o.offerId == waveOffer.offerId);
        _currentWaveOffers.add(waveOffer);
        _currentWaveOffer = waveOffer;
      });
      ref.read(selectedTabProvider.notifier).state = 0;
      unawaited(_performancePreview.prefetch(owner));
      await DriverOfferAudio.play(waveOffer.offerId);
    } catch (_) {/* A failed scope check cannot display a stale offer. */}
  }

  /// معالج انتهاء صلاحية wave offer
  void _handleWaveOfferExpired(String offerId) {
    print('⏰ Wave offer expired: $offerId');

    // إغلاق نافذة تأكيد الرفض إذا كانت مفتوحة لنفس العرض
    if (_currentRejectConfirmationOfferId == offerId) {
      print('🚪 Closing reject confirmation sheet for expired offer: $offerId');
      _currentRejectConfirmationOfferId = null;
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }

    setState(() {
      _currentWaveOffers.removeWhere((offer) => offer.offerId == offerId);
      if (_currentWaveOffer?.offerId == offerId) {
        _currentWaveOffer = null;
      }
    });

    // عرض رسالة انتهاء الوقت
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('انتهى وقت العرض'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }

    print(
        '✅ Offer removed from list. Remaining offers: ${_currentWaveOffers.length}');
  }

  /// معالج قبول wave offer من سائق آخر
  void _handleWaveOfferTaken(String offerId,
      {String? orderId, String? cycleId}) {
    if (!mounted) return;
    bool matches(WaveOffer o) =>
        o.offerId == offerId &&
        (orderId == null || o.orderId == orderId) &&
        (cycleId == null ||
            o.dispatchCycleId == null ||
            o.dispatchCycleId == cycleId);
    final existed = _currentWaveOffers.any(matches);
    if (!existed) return; // Push + WebSocket + resume produce one UI removal.
    if (_currentRejectConfirmationOfferId == offerId) {
      _currentRejectConfirmationOfferId = null;
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
    setState(() {
      _currentWaveOffers.removeWhere(matches);
      if (_currentWaveOffer != null && matches(_currentWaveOffer!))
        _currentWaveOffer = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('لم يعد هذا العرض متاحًا'),
        duration: Duration(seconds: 2)));
  }

  /// عرض dialog لـ wave offer
  void _showWaveOfferDialog(WaveOffer waveOffer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WaveOfferDialog(
        offer: waveOffer,
        onAccept: () => _acceptWaveOffer(waveOffer),
        onReject: () => _showRejectConfirmationSheet(
            waveOffer), // ✅ عرض Bottom Sheet للتأكيد
      ),
    );
  }

  /// ⏱️ معالج انتهاء الوقت (Timeout) - بدون استدعاء API
  void _handleTimeout(WaveOffer waveOffer) {
    print('⏱️ Wave offer timeout: ${waveOffer.offerId}');
    print('   - Timer in OrderOfferCard expired (90 seconds)');
    print('   - Will trigger _handleWaveOfferExpired to close any open sheets');

    // ✅ استدعاء _handleWaveOfferExpired لإغلاق نافذة التأكيد إن كانت مفتوحة
    _handleWaveOfferExpired(waveOffer.offerId);

    print('✅ Timeout handled - العرض تمت إزالته من UI');
  }

  /// قبول wave offer
  Future<void> _acceptWaveOffer(WaveOffer waveOffer) async {
    try {
      final epoch = _offerAuthEpoch;
      final owner = await _bindOfferOwner();
      if (owner == null ||
          !await _offerStillVisible(waveOffer) ||
          !mounted ||
          !_currentWaveOffers.any((o) => o.offerId == waveOffer.offerId))
        return;
      print('✅ Accepting wave offer: ${waveOffer.offerId}');

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 16),
                Text('جاري قبول الطلب...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Get driver ID from authenticated session
      final driverId = owner;

      if (driverId.isEmpty) {
        throw Exception('معرف السائق غير موجود - يرجى تسجيل الدخول مرة أخرى');
      }

      print('📞 Calling acceptWaveOffer API');
      print('   - offerId: ${waveOffer.offerId}');
      print('   - driverId: $driverId');
      print('   - orderId: ${waveOffer.orderId}');
      print('   - waveNumber: ${waveOffer.waveNumber}');

      // Call API
      final result = await DriverSearchApiService.acceptWaveOffer(
        offerId: waveOffer.offerId,
        driverId: driverId,
        financialOrderId:
            waveOffer.financialTerms != null ? waveOffer.orderId : null,
        financialWaveNumber:
            waveOffer.financialTerms != null ? waveOffer.waveNumber : null,
      );

      if (!mounted ||
          epoch != _offerAuthEpoch ||
          _offerClosureScope.owner != owner) return;
      print('📡 acceptWaveOffer API response:');
      print('   - success: ${result['success']}');
      print('   - message: ${result['message']}');
      print('   - full response: $result');

      // Hide loading snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (result['success'] == true) {
        _performancePreview.clear();
        // Success
        print('✅ Wave offer accepted successfully');
        print('📝 Order ID: ${waveOffer.orderId}');
        print('📱 Context mounted: $mounted');

        // إزالة العرض فقط بعد نجاح القبول فعلياً من الباكند
        if (mounted) {
          setState(() {
            _currentWaveOffers
                .removeWhere((offer) => offer.offerId == waveOffer.offerId);
            _currentWaveOffer = null;
          });
        }

        // ✅ استخراج holdId من الاستجابة
        final String? holdId = result['data']?['holdId'];
        final String? holdStatus = result['data']?['holdStatus'];
        final double? holdAmount = result['data']?['holdAmount'] != null
            ? (result['data']?['holdAmount'] as num).toDouble()
            : null;

        if (holdId != null) {
          print('💰 Hold created successfully: $holdId');
          print('   - Status: $holdStatus');
          print('   - Amount: $holdAmount IQD');
        }

        // ✅ تحديث رصيد المحفظة بعد Hold
        try {
          final _ = ref.refresh(walletBalanceProvider);
          print('💳 Wallet balance refreshed after Hold');
        } catch (e) {
          print('⚠️ Failed to refresh wallet balance: $e');
        }

        // ✅ حفظ الطلب النشط محلياً للحماية من فقدان البيانات
        try {
          await OrderPersistenceService.saveActiveOrder(
            orderId: waveOffer.orderId,
            status: 'accepted',
            orderData: {
              'orderId': waveOffer.orderId,
              'offerId': waveOffer.offerId,
              'restaurantId': waveOffer.restaurantId,
              'restaurantName': waveOffer.restaurantName,
              'restaurantAddress': waveOffer.restaurantAddress,
              'restaurantLat': waveOffer.restaurantLat,
              'restaurantLng': waveOffer.restaurantLng,
              'customerName': waveOffer.customerName,
              'customerPhone': waveOffer.customerPhone,
              'customerAddress': waveOffer.customerAddress,
              'customerLat': waveOffer.customerLat,
              'customerLng': waveOffer.customerLng,
              'orderTotal': waveOffer.orderTotal,
              'deliveryFee': waveOffer.deliveryFee,
              'acceptedAt': DateTime.now().toIso8601String(),
              'status': 'accepted',
              'holdId': holdId,
              'holdStatus': holdStatus,
              'holdAmount': holdAmount,
            },
          );
          print('💾 Active order saved locally for protection');
        } catch (e) {
          print('⚠️ Failed to save active order locally: $e');
          // لا نفشل العملية بسبب مشكلة الحفظ المحلي
        }

        // ✅ لا نوقف البحث - الباكند يتحكم في ذلك عبر isSearching, status, activeOrdersCount
        // السائق سيبقى متصل بـ WebSocket ولكن لن يستقبل عروض جديدة لأنه busy

        if (mounted) {
          print('🚀 Attempting navigation to active order screen...');
          print(
              '🚀 Navigating to active order screen with orderId: ${waveOffer.orderId}');

          // الانتقال مباشرة إلى شاشة الطلب النشط باستخدام GoRouter
          try {
            // استخدام GoRouter.of(context) للتأكد من الحصول على GoRouter الصحيح
            GoRouter.of(context).go('/active-order', extra: {
              'orderId': waveOffer.orderId,
            });
            print('✅ Successfully navigated to active order screen');
          } catch (error) {
            print('❌ Error navigating to active order screen: $error');
            // في حالة فشل الانتقال، اعرض رسالة
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم قبول الطلب بنجاح'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        }
      } else {
        // Failed
        print('❌ Failed to accept wave offer: ${result['message']}');

        // ✅ تحقق إذا كانت الرسالة تتعلق بقبول سائق آخر - لا تعرض رسالة حمراء
        // لأن WebSocket سبق وأرسل رسالة برتقالية
        final message = result['message'] ?? 'فشل في قبول الطلب';
        final isOrderTakenByAnother =
            message.contains('تم قبول الطلب من سائق آخر') ||
                message.contains('ORDER_ALREADY_ACCEPTED') ||
                message.contains('HOLD_ALREADY_EXISTS');

        // إذا قُبل الطلب من سائق آخر فعلاً، نحذف العرض من الواجهة
        if (mounted && isOrderTakenByAnother) {
          setState(() {
            _currentWaveOffers
                .removeWhere((offer) => offer.offerId == waveOffer.offerId);
            _currentWaveOffer = null;
          });
        }

        if (mounted && !isOrderTakenByAnother) {
          // عرض رسالة فقط للأخطاء الأخرى (ليس "تم قبول من سائق آخر")
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error accepting wave offer: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في قبول الطلب: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// 📊 جلب metrics السائق من الـ API
  /// 🚫 عرض Bottom Sheet لتأكيد الرفض
  Future<void> _showRejectConfirmationSheet(WaveOffer waveOffer) async {
    if (!mounted ||
        _preparingRejectOfferId != null ||
        _currentRejectConfirmationOfferId != null) return;
    final epoch = _offerAuthEpoch;
    _preparingRejectOfferId = waveOffer.offerId;
    Map<String, dynamic>? performance;
    try {
      final owner = await _bindOfferOwner();
      if (owner == null || !mounted || epoch != _offerAuthEpoch) return;
      performance = await _performancePreview.read(owner);
      if (!mounted ||
          epoch != _offerAuthEpoch ||
          _offerClosureScope.owner != owner ||
          !_currentWaveOffers.any((o) => o.offerId == waveOffer.offerId) ||
          !await _offerStillVisible(waveOffer) ||
          !mounted ||
          epoch != _offerAuthEpoch) return;
    } finally {
      _preparingRejectOfferId = null;
    }
    print('📄 Opening reject confirmation for offer: ${waveOffer.offerId}');

    // تسجيل العرض الذي نعرض له نافذة التأكيد
    _currentRejectConfirmationOfferId = waveOffer.offerId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (sheetContext) {
        return WillPopScope(
          onWillPop: () async {
            print('🚪 Reject confirmation sheet dismissed by user');
            _currentRejectConfirmationOfferId = null;
            return true;
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.grey[200], // رمادي فاتح للدائرة الخارجية
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    size: 32,
                    color: Color(0xFF00296B), // أزرق ثانوي لعلامة التعجب
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                const Text(
                  'تأكيد رفض الطلب',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00296B),
                  ),
                ),

                const SizedBox(height: 12),

                // Motivational message
                Text(
                  'راجع أثر الرفض على معدل قبولك قبل التأكيد.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

                DeclineAcceptanceImpact(
                    offerId: waveOffer.offerId,
                    sentAt: waveOffer.sentAt,
                    snapshot: performance),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    // Cancel button (التراجع)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _currentRejectConfirmationOfferId = null;
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor:
                              const Color(0xFFFDC500), // اللون الأساسي الأصفر
                          foregroundColor: const Color(0xFF00296B), // نص أزرق
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: const Text(
                          'تراجع',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Confirm Reject button (تأكيد الرفض)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _currentRejectConfirmationOfferId = null;
                          Navigator.pop(context); // إغلاق Bottom Sheet
                          _rejectWaveOffer(waveOffer); // تنفيذ الرفض
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.grey[300], // رمادي فاتح
                          foregroundColor: Colors.grey[800], // نص رمادي داكن
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: const Text(
                          'تأكيد الرفض',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Bottom padding for safe area
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      print('🚪 Reject confirmation sheet closed');
      _currentRejectConfirmationOfferId = null;
    });
  }

  /// رفض wave offer
  Future<void> _rejectWaveOffer(WaveOffer waveOffer) async {
    final epoch = _offerAuthEpoch;
    final owner = await _bindOfferOwner();
    if (owner == null ||
        !await _offerStillVisible(waveOffer) ||
        !mounted ||
        !_currentWaveOffers.any((o) => o.offerId == waveOffer.offerId)) return;
    print('🚀🚀🚀 REJECT BUTTON PRESSED! 🚀🚀🚀');
    print('📋 WaveOffer details:');
    print('   - offerId: ${waveOffer.offerId}');
    print('   - orderId: ${waveOffer.orderId}');

    try {
      print('❌ [1/5] Starting reject process...');

      // Get driver ID FIRST before removing from UI
      print('❌ [2/5] Getting driver ID...');
      final driverId = owner;

      if (driverId.isEmpty) {
        print('⚠️ Driver ID not found - ABORTING');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('خطأ: لم يتم العثور على معرف السائق'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      print('✅ Driver ID: $driverId');
      print('❌ [3/5] Calling rejectWaveOffer API...');

      // Call API FIRST before removing from UI
      try {
        final result = await DriverSearchApiService.rejectWaveOffer(
          offerId: waveOffer.offerId,
          driverId: driverId,
          financialOrderId:
              waveOffer.financialTerms != null ? waveOffer.orderId : null,
          financialWaveNumber:
              waveOffer.financialTerms != null ? waveOffer.waveNumber : null,
          reason: 'driver_declined',
        );
        if (!mounted ||
            epoch != _offerAuthEpoch ||
            _offerClosureScope.owner != owner) return;

        _performancePreview.clear();
        print('✅ [4/5] API response received: $result');

        // Only remove from UI after successful API call
        print('❌ [5/5] Removing from UI...');
        setState(() {
          _currentWaveOffers
              .removeWhere((offer) => offer.offerId == waveOffer.offerId);
          _currentWaveOffer = null;
        });

        print('✅✅✅ REJECT COMPLETE! ✅✅✅');

        // إظهار رسالة نجاح
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفض الطلب بنجاح'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (apiError, stackTrace) {
        print('❌❌❌ API ERROR: $apiError');
        print('📚 Stack trace: $stackTrace');

        // إظهار رسالة خطأ
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في رفض الطلب: $apiError'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌❌❌ OUTER ERROR: $e');
      print('📚 Stack trace: $stackTrace');
    }
  }

  /// التحقق من كفاية رصيد المحفظة لقبول العرض
  bool _canAcceptWaveOfferFromDetails(WaveOffer offer) {
    if (!_currentWaveOffers.any((o) => o.offerId == offer.offerId) ||
        !offer.expiresAt.isAfter(DateTime.now())) return false;
    final walletState = ref.read(walletBalanceProvider);
    return walletState.maybeWhen(
      data: (wallet) {
        final requiredAmount = offer.requiredBalanceAmount;
        if (requiredAmount <= 0) return true;
        return wallet.availableBalance >= requiredAmount;
      },
      orElse: () => true,
    );
  }

  /// عرض تفاصيل Wave Order في bottom sheet
  void _showWaveOrderDetails(WaveOffer offer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OrderDetailsBottomSheet(
        offer: offer,
        canAccept: _canAcceptWaveOfferFromDetails(offer),
        onAccept: () => _acceptWaveOffer(offer),
        onReject: () => _showRejectConfirmationSheet(offer),
      ),
    );
  }
}
