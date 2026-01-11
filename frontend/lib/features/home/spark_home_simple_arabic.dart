import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:go_router/go_router.dart';
import 'widgets/order_offer_card.dart';
import 'widgets/order_details_bottom_sheet.dart';
import '../../services/websocket_service.dart';
import '../../services/global_app_state_manager.dart';
import '../../models/map_data.dart';
import '../../services/map_data_service.dart';
import '../../services/business_status_cache.dart';
import '../../models/wave_offer.dart' show WaveOffer;
import '../../models/wave_offer.dart' as wave_model;
import '../../widgets/wave_offer_dialog.dart';
import '../../services/push_notifications_service.dart';
import '../../services/driver_search_api_service.dart';
import '../../providers/driver_auth_provider.dart';
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
  ConsumerState<SparkHomeSimpleArabic> createState() => _SparkHomeSimpleArabicState();
}

class _SparkHomeSimpleArabicState extends ConsumerState<SparkHomeSimpleArabic> 
    with WidgetsBindingObserver {
  bool _isSearchingForOffers = false;
  DateTime? _searchEndTime;
  DateTime? _selectedEndTime;
  Position? _currentPosition;
  List<DateTime>? _timeOptions; // قائمة الأوقات المنشأة مرة واحدة
  bool _isCheckingWalletBalance = false; // حالة التحميل لفحص رصيد المحفظة
  Timer? _searchTimer; // Timer للتحقق من انتهاء وقت البحث
  final List<OrderOffer> _availableOffers = []; // قائمة الطلبات المتاحة (Legacy - Deprecated)
  final Set<String> _rejectedOfferIds = {}; // الطلبات المرفوضة
  Timer? _storesStatusRefreshTimer; // 🔄 Timer لتحديث حالة المطاعم تلقائياً (Polling مثل wizzuser)
  late AudioPlayer _audioPlayer; // مشغل الصوت للإشعارات
  String? _errorMessage; // رسالة الخطأ عند فشل البدء
  
  // 🌊 Wave System - New
  WaveOffer? _currentWaveOffer; // العرض الحالي من Wave System (DEPRECATED - use _currentWaveOffers)
  final List<WaveOffer> _currentWaveOffers = []; // قائمة عروض الموجات الحالية
  String? _currentRejectConfirmationOfferId; // معرّف العرض الذي يتم تأكيد رفضه حالياً
  StreamSubscription? _waveOfferSubscription;
  StreamSubscription? _offerExpiredSubscription;
  StreamSubscription? _offerTakenSubscription;
  Timer? _offerExpiryCleanupTimer; // 🆕 دوري لتنظيف العروض المنتهية الصلاحية
  
  // WebSocket Service for Wave System
  final WebSocketService _webSocketService = WebSocketService();
  
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  
  // Google Maps
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  MapDataResponse? _mapData;
  bool _isLoadingMapData = false;
  
  // 📊 Driver Performance Metrics
  double? _currentAcceptanceRate;
  int? _totalAccepted;
  int? _totalRejected;
  
  // ✅ Active Order Check
  bool _hasCheckedActiveOrder = false;
  
  // 🧪 إحداثيات ثابتة للاختبار (مركز المناذرة - Al-Manathirah Center - Level 3)
  // Coordinates: 31.895748, 44.377563 - ضمن مركز المناذرة (Rmhvcpnn3iy5f1)
  // ✅ Wave System: نفس منطقة السائق - يجب أن يسمح بالعمل
  // TODO: بعد الاختبار، احذف هذه وارجع لاستخدام _currentPosition من GPS
  static const double _testLatitude = 31.913292;
  static const double _testLongitude = 44.476014;
  
  @override
  void initState() {
    super.initState();
    try {
      print('🚀 Initializing SparkHomeSimpleArabic...');
      
      // Add app lifecycle observer for background/foreground handling
      WidgetsBinding.instance.addObserver(this);
      
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
    
    print('📱 App lifecycle changed: $state');
    
    // Use Global App State Manager instead of local handling
    GlobalAppStateManager().notifyAppStateChange(state);
    
    // Keep local handling for specific home screen needs
    switch (state) {
      case AppLifecycleState.resumed:
        print('📱 App resumed - home screen specific handling');
        _refreshLocationIfStale();
        
        // 🆕 Only handle resume if app was actually in background for a while
        // This prevents reconnection on simple tab switches within the app
        if (_lastPausedTime != null) {
          final backgroundDuration = DateTime.now().difference(_lastPausedTime!);
          print('⏱️ App was in background for: ${backgroundDuration.inSeconds} seconds');
          
          if (backgroundDuration >= _minimumBackgroundDuration) {
            print('✅ Real app resume detected - handling WebSocket');
            _handleAppResumed();
            
            // ✅ Check for active order when app resumes from background
            _hasCheckedActiveOrder = false;  // Reset flag
            _checkForActiveOrder();
          } else {
            print('ℹ️ Quick tab switch detected - ignoring (${backgroundDuration.inSeconds}s < ${_minimumBackgroundDuration.inSeconds}s)');
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

  void _refreshLocationIfStale() {
    if (_currentPosition == null) {
      print('🌍 Refreshing location on app resume');
      _initializeLocation();
    }
  }

  /// 🆕 معالجة استئناف التطبيق بعد إغلاق فعلي (ليس tab switch)
  Future<void> _handleAppResumed() async {
    try {
      print('🔄 App ACTUALLY resumed after real background - checking driver search state...');
      
      // ✅ أولاً: فحص وجود طلب نشط
      await _checkForActiveOrder();
      
      // التحقق إذا كان السائق يبحث عن طلبات
      if (_isSearchingForOffers) {
        print('🔍 Driver was searching when app went to background');
        print('🔌 Checking WebSocket connection health...');
        
        // التحقق من حالة WebSocket
        if (_webSocketService.isConnected) {
          print('✅ WebSocket still connected - refreshing connection proactively');
          // تحديث الاتصال احترازياً (قد يكون stale بعد background)
          await _webSocketService.refreshConnection();
          print('✅ WebSocket refreshed - connection is healthy and ready for offers');
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
      
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driver_id') ?? '74b83488-f041-70a4-52d7-d2370b7eec06';
      final authToken = prefs.getString('auth_token') ?? prefs.getString('id_token') ?? 'mock_token';
      
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
      print('🧪 TEST MODE: Using fixed coordinates: Najaf ($_testLatitude, $_testLongitude)');
      
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

      // ✅ If the app was opened from a push tap (lock screen / terminated),
      // consume the stashed wave offer and show it in the list.
      await _consumeWaveOfferFromPushTap();
      
      // 🆕 Start periodic cleanup of expired offers
      _startOfferExpiryCleanup();
      
      print('✅ Delayed initialization complete');
    } catch (e, stackTrace) {
      print('🚨 Error in delayed initialization: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _consumeWaveOfferFromPushTap() async {
    try {
      final data = await PushNotificationsService.consumeStashedWaveOfferFromTap();
      if (data == null) return;

      final offerId = (data['offerId'] ?? '').toString().trim();
      final orderId = (data['orderId'] ?? '').toString().trim();
      if (offerId.isEmpty || orderId.isEmpty) return;

      DateTime? expiresAt;
      final expiresAtRaw = (data['expiresAt'] ?? '').toString().trim();
      if (expiresAtRaw.isNotEmpty) {
        expiresAt = DateTime.tryParse(expiresAtRaw);
      }
      expiresAt ??= DateTime.now().add(const Duration(seconds: 45));

      // ✅ FIX: Check if offer already expired at consumption time
      if (DateTime.now().isAfter(expiresAt)) {
        print('⏰ Push-tap wave offer already expired: $offerId');
        // 🆕 Show snackbar to user: "Offer Expired"
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('عذراً، انتهت صلاحية هذا العرض'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final existing = _currentWaveOffers.any((o) => o.offerId == offerId);
      if (existing) {
        print('ℹ️ Push-tap wave offer already in list: $offerId');
        return;
      }

      final waveNumber = int.tryParse((data['waveNumber'] ?? '').toString()) ?? 1;
      final restaurantName = (data['restaurantName'] ?? '').toString().trim();

      // Create a minimal placeholder WaveOffer so the driver sees the offer after a cold start.
      // accept/reject uses offerId, so this is sufficient for the basic flow.
      final placeholder = WaveOffer(
        offerId: offerId,
        orderId: orderId,
        jobId: '',
        waveNumber: waveNumber,
        rank: 1,
        score: 0,
        restaurantId: '',
        restaurantName: restaurantName.isEmpty ? 'طلب جديد' : restaurantName,
        restaurantAddress: '',
        restaurantLat: 0,
        restaurantLng: 0,
        customerId: '',
        customerName: '',
        customerAddress: '',
        customerLat: 0,
        customerLng: 0,
        orderTotal: 0,
        deliveryFee: 0,
        bonusAmount: 0,
        tip: 0,
        estimatedEarnings: 0,
        currency: 'IQD',
        distance: 0,
        estimatedMinutes: 0,
        itemsCount: 0,
        items: const <wave_model.OrderItem>[],
        sentAt: DateTime.now(),
        expiresAt: expiresAt,
      );

      if (!mounted) return;
      setState(() {
        _currentWaveOffers.add(placeholder);
      });
      print('✅ Added push-tap placeholder offer: $offerId');
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
      
      final now = DateTime.now();
      int removedCount = 0;
      
      setState(() {
        _currentWaveOffers.removeWhere((offer) {
          final isExpired = now.isAfter(offer.expiresAt);
          if (isExpired) {
            print('🗑️ Auto-removing expired offer: ${offer.offerId}');
            removedCount++;
          }
          return isExpired;
        });
      });
      
      if (removedCount > 0) {
        print('✅ Cleaned up $removedCount expired offers. Remaining: ${_currentWaveOffers.length}');
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
          print('🌊 Wave offer received: ${waveOffer.offerId} (Wave ${waveOffer.waveNumber}, Rank ${waveOffer.rank})');
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
      
      _offerTakenSubscription = _webSocketService.offerTakenStream.listen(
        (data) {
          if (mounted) {
            final offerId = data['offerId'];
            final takenByDriverId = data['driverId'];
            print('👥 Wave offer taken by another driver: $offerId (by $takenByDriverId)');
            _handleWaveOfferTaken(offerId);
          }
        },
        onError: (error) {
          print('❌ Offer taken stream error: $error');
        },
      );
      
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
          print('🔍 Checking WebSocket connection status after state restore...');
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

  // مسح حالة البحث من SharedPreferences
  void _clearSearchState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isSearchingForOffers');
      await prefs.remove('searchEndTime');
      
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
  Future<void> _playNotificationSound() async {
    try {
      if (!mounted) {
        print('⚠️ Widget not mounted, skipping sound');
        return;
      }

      // التحقق من تهيئة مشغل الصوت
      try {
        // Ensure audio player is properly initialized
        await Future.delayed(const Duration(milliseconds: 50)); // Small delay to ensure stability
      } catch (initError) {
        print('❌ Audio player check failed: $initError');
        return;
      }

      // محاولة تشغيل الصوت مع timeout
      try {
        await _audioPlayer.play(AssetSource('sounds/Driver_Noti.mp3'))
            .timeout(const Duration(seconds: 5)); // 5 second timeout
        print('🔊 تم تشغيل صوت الإشعار بنجاح');
      } catch (playError) {
        print('❌ خطأ في تشغيل الصوت: $playError');
        
        // محاولة بديلة بصوت النظام
        try {
          await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
          print('🔊 تم تشغيل الصوت البديل');
        } catch (fallbackError) {
          print('❌ خطأ في الصوت البديل: $fallbackError');
          // Continue without sound - don't crash
        }
      }
      
    } catch (e, stackTrace) {
      print('🚨 CRITICAL: خطأ غير متوقع في تشغيل الصوت: $e');
      print('Stack trace: $stackTrace');
      // Log but don't crash the app
    }
  }

  /// تهيئة خدمة الموقع مع حماية كاملة من الانغلاق
  void _initializeLocation() async {
    try {
      if (!mounted) {
        print('⚠️ Widget not mounted, skipping location initialization');
        return;
      }
      
      print('🌍 Initializing location service safely...');
      
      // استخدام موقع افتراضي أولاً لتجنب الانغلاق
      _setFallbackLocation();
      
      // محاولة الحصول على الموقع الحقيقي في المرحلة التالية
      _attemptRealLocationAccess();
      
    } catch (e, stackTrace) {
      print('CRITICAL: Error in location initialization: $e');
      print('Stack trace: $stackTrace');
      _setFallbackLocation();
    }
  }

  /// تعيين موقع افتراضي آمن
  void _setFallbackLocation() {
    try {
      if (mounted) {
        setState(() {
          _currentPosition = Position(
            latitude: _testLatitude, // النجف - العراق (للاختبار)
            longitude: _testLongitude,
            timestamp: DateTime.now(),
            accuracy: 100.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
        });
        print('🏠 Fallback location set: Najaf, Iraq (Test Mode)');
      }
    } catch (e) {
      print('🚨 Error setting fallback location: $e');
    }
  }

  /// محاولة الحصول على الموقع الحقيقي بشكل آمن
  void _attemptRealLocationAccess() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1000)); // تأخير لضمان الاستقرار
      
      if (!mounted) return;
      
      // التحقق من الأذونات مع timeout
      LocationPermission permission;
      try {
        permission = await Geolocator.checkPermission()
            .timeout(const Duration(seconds: 5));
        print('🔒 Current permission status: $permission');
      } catch (permissionError) {
        print('❌ Permission check failed: $permissionError');
        return;
      }
      
      if (permission == LocationPermission.denied) {
        try {
          print('🔒 Requesting location permission...');
          permission = await Geolocator.requestPermission()
              .timeout(const Duration(seconds: 10));
          print('🔒 Permission after request: $permission');
        } catch (requestError) {
          print('❌ Permission request failed: $requestError');
          return;
        }
      }
      
      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        _getRealPosition();
      } else {
        print('⚠️ Location permission not granted: $permission');
      }
      
    } catch (e, stackTrace) {
      print('🚨 Error in real location access: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// الحصول على الموقع الحقيقي مع حماية كاملة
  void _getRealPosition() async {
    try {
      if (!mounted) return;
      
      print('🌍 Getting real position...');
      
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          print('⏰ Real location timeout - keeping fallback');
          throw TimeoutException('Location timeout', const Duration(seconds: 12));
        },
      );
      
      if (mounted) {
        // 🧪 للاختبار: استخدام الإحداثيات الثابتة بدلاً من GPS الفعلي
        // TODO: بعد الاختبار، أعد تفعيل GPS بإلغاء التعليق على السطر التالي وحذف الكود الثابت
        // _currentPosition = position;
        
        setState(() {
          _currentPosition = Position(
            latitude: _testLatitude,
            longitude: _testLongitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
        });
        print('✅ Test location set (not GPS): $_testLatitude, $_testLongitude');
        print('⚠️ GPS location ignored for testing: ${position.latitude}, ${position.longitude}');
      }
      
    } catch (e) {
      print('⚠️ Real location failed, using test location: $e');
      // استخدام الإحداثيات الثابتة للاختبار
      if (mounted) {
        setState(() {
          _currentPosition = Position(
            latitude: _testLatitude,
            longitude: _testLongitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
        });
      }
    }
  }

  void _startSearchingForOffers() {
    try {
      if (!mounted) {
        print('⚠️ Widget not mounted, cannot start search');
        return;
      }
      
      print('📱 فتح نافذة اختيار وقت البحث...');
      
      // إظهار modal اختيار الوقت أولاً مثل Spark
      _showSparkNowTimeSelection();
      
    } catch (e, stackTrace) {
      print('🚨 خطأ في بدء البحث: $e');
      print('Stack trace: $stackTrace');
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
    try {
      if (!mounted) {
        print('⚠️ Widget not mounted, cancelling search start');
        return;
      }
      
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
        
        final requiredMinimumBalance = wallet.minRequiredBalance;
        final hasMinimumBalance = wallet.availableBalance >= requiredMinimumBalance;
        print('💵 رصيد المحفظة: ${wallet.availableBalance} د.ع');
        print('🎯 الحد الأدنى مطلوب: ${requiredMinimumBalance.toString()} د.ع');
        print(hasMinimumBalance ? '✅ الرصيد كافٍ' : '❌ الرصيد غير كافٍ');
        
        if (!hasMinimumBalance) {
          // Close bottom sheet first
          if (mounted) {
            Navigator.pop(context);
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
                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                    SizedBox(width: 12),
                    Text('رصيد غير كافٍ'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'رصيدك الحالي غير كافٍ للبدء في استقبال الطلبات.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'الحد الأدنى المطلوب: ${requiredMinimumBalance.toString()} د.ع',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('حسناً'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Navigate to wallet recharge
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black87,
                    ),
                    child: const Text('تعبئة المحفظة'),
                  ),
                ],
              ),
            );
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
      
      // Close bottom sheet after successful wallet check
      if (mounted) {
        Navigator.pop(context);
      }
      
      print('🚀 بدء تأكيد البحث عن الطلبات...');
      print('🧪 TEST MODE: زر "تشغيل" يستخدم إحداثيات النجف الثابتة ($_testLatitude, $_testLongitude)');
      
      // تغيير الحالة بشكل آمن
      if (mounted) {
        setState(() {
          _isSearchingForOffers = true;
          _searchEndTime = endTime;
        });
      }
      
      // حفظ الحالة مع معالجة الأخطاء
      try {
        _saveSearchState();
        print('💾 تم حفظ حالة البحث');
      } catch (saveError) {
        print('⚠️ خطأ في حفظ الحالة: $saveError');
      }
      
      // بدء Timer للتحقق من انتهاء الوقت
      _startSearchTimer();
      
      // إغلاق الـ modal أولاً
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // تأخير قصير لضمان استقرار الواجهة
      await Future.delayed(const Duration(milliseconds: 500));
      
      // **تشغيل نظام البحث بشكل آمن**
      if (mounted) {
        await _startRealWebSocketConnection();
      }
      
      print('✅ تم بدء البحث حتى: ${_formatTime(endTime)}');
      
    } catch (e, stackTrace) {
      print('🚨 CRITICAL: خطأ في تأكيد البحث: $e');
      print('Stack trace: $stackTrace');
      
      // التراجع عن التغييرات في حالة الخطأ
      if (mounted) {
        setState(() {
          _isSearchingForOffers = false;
          _searchEndTime = null;
        });
      }
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
        print('⚠️ فشل الحصول على Token من Amplify، محاولة من SharedPreferences');
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString('auth_token') ?? prefs.getString('id_token');
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
          'disconnectAfterStop': false, // لا نريد قطع الاتصال كلياً، فقط إيقاف البحث
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
  Future<void> _startRealWebSocketConnection() async {
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
      
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driver_id') ?? '74b83488-f041-70a4-52d7-d2370b7eec06'; // Mustafa - مركز المناذرة
      final authToken = prefs.getString('auth_token') ?? prefs.getString('id_token') ?? 'mock_token';
      
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
        // No simulation fallback - Wave System only
      }
      
    } catch (e, stackTrace) {
      print('🚨 CRITICAL: خطأ في نظام البحث: $e');
      print('Stack trace: $stackTrace');
      // Wave System requires WebSocket - no simulation fallback
    }
  }
  
  /// استدعاء REST API /driver/start-searching لكتابة البيانات الكاملة
  Future<void> _callStartSearchingAPI() async {
    try {
      print('📡 استدعاء REST API /driver/start-searching لكتابة البيانات الكاملة...');
      
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token') ?? prefs.getString('id_token');
      
      if (authToken != null) {
        // 🧪 TEST MODE: استخدام إحداثيات النجف الثابتة
        final response = await http.post(
          Uri.parse('${Environment.apiBaseUrl}/driver/start-searching'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: json.encode({
            'lat': _testLatitude,  // 31.915514
            'lng': _testLongitude, // 44.471916
          }),
        );
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          print('✅ REST API: تم كتابة البيانات الكاملة في WizzDriverLiveState');
          print('📍 المنطقة: ${responseData['data']['current_work_region']['name']}');
          print('🏠 المحافظة: ${responseData['data']['current_work_region']['governorate_name']}');
          
          // 🌊 WAVE SYSTEM: الآن WizzDriverLiveState محدث بـ:
          // - isSearching = true
          // - current_work_region_id = naj_center_001
          // - allowed_region_ids = [...]
          // - metricsSnapshot_* = ...
          
          print('🌊 Wave System: السائق مسجل في النظام الموجي');
          print('✅ البيانات الكاملة محفوظة - جاهز للاتصال WebSocket');
          
        } else if (response.statusCode == 403) {
          final errorData = json.decode(response.body);
          print('⚠️ REST API: غير مسموح بالعمل في هذه المنطقة');
          print('📍 الرسالة: ${errorData['message']}');
          
          // إظهار رسالة للسائق
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorData['message'] ?? 'لا يمكن العمل في هذه المنطقة'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          
          // إيقاف البحث
          setState(() {
            _isSearchingForOffers = false;
            _searchEndTime = null;
          });
          throw Exception('Region not allowed');
          
        } else {
          print('⚠️ REST API: فشل بدء البحث - ${response.statusCode}');
          print('📄 الرد: ${response.body}');
          throw Exception('REST API failed: ${response.statusCode}');
        }
      } else {
        print('⚠️ لا يوجد Auth Token - لا يمكن استدعاء REST API');
        throw Exception('No auth token');
      }
    } catch (apiError) {
      print('❌ خطأ في استدعاء start-searching API: $apiError');
      rethrow;
    }
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
        onReject: () => _showRejectConfirmationSheet(offer), // ✅ عرض Bottom Sheet للتأكيد
        onTimeout: () => _handleTimeout(offer), // ✅ معالج منفصل لانتهاء الوقت
        onTap: () => _showWaveOrderDetails(offer),
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
      items: order.items.map((item) => wave_model.OrderItem(
        itemId: item.itemId,
        name: item.name,
        quantity: item.quantity,
        price: 0, // OrderOffer local class doesn't have price
        imageUrl: null,
        notes: null,
      )).toList(),
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
        onAccept: () {
          Navigator.pop(context);
          _acceptOffer(offer);
        },
        onReject: () {
          Navigator.pop(context);
          _rejectOffer(offer);
        },
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
        content: Text('تم قبول طلب ${offer.customerName}\nمن ${offer.storeName}'),
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
    final period = hour >= 12 ? 'مساءً' : 'صباحاً';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    // إضافة تفاصيل إضافية للوقت
    final dayDifference = time.difference(DateTime.now()).inDays;
    final timeString = '$hour12:$minute $period';
    
    if (dayDifference > 0) {
      return '$timeString (اليوم التالي)';
    }
    
    return timeString;
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
        ],
      ),
    );
  }

  Widget _buildMapView() {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(
          _testLatitude,
          _testLongitude,
        ),
        zoom: 14,
      ),
      markers: _markers,
      myLocationEnabled: true,
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
        _loadMapData();
      },
    );
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
      
      final data = await MapDataService.fetchMapData(
        lat: _testLatitude,   // إحداثيات ثابتة بدلاً من GPS
        lng: _testLongitude,
      );
      
      if (!mounted) return;
      
      setState(() {
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
      
      // 🔄 إعادة المحاولة مرة واحدة إذا كان الخطء Authentication
      if (e.toString().contains('Authentication')) {
        await Future.delayed(const Duration(seconds: 2));
        
        if (!mounted) return;
        
        try {
          final data = await MapDataService.fetchMapData(
            lat: _testLatitude,
            lng: _testLongitude,
          );
          
          if (!mounted) return;
          
          setState(() {
            _mapData = data;
            _updateMapMarkers();
          });
          
          return; // نجحت إعادة المحاولة
        } catch (retryError) {
        }
      }
      
      // عرض رسالة للمستخدم فقط إذا فشلت كل المحاولات
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('Authentication')
                ? 'خطأ في المصادقة - الرجاء إعادة تسجيل الدخول'
                : 'فشل تحميل المطاعم - تأكد من الاتصال بالإنترنت',
              textAlign: TextAlign.center,
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  /// 🎨 Create custom circular marker icon
  /// Creates a yellow circular marker with blue category icon
  Future<BitmapDescriptor> _createStoreMarkerIcon({
    required String category,
    required bool isCoreRegion,
    required int hotScore,
    required bool isOpen,
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
      final double canvasSize = hotScore >= 5 ? baseSize + 12 : baseSize + 4;
      final double centerOffset = canvasSize / 2;

      // Colors
      const Color backgroundColor = Color(0xFFFFD700); // Yellow/Gold
      const Color iconColor = AppColors.secondary; // Blue
      final double opacity = isCoreRegion ? 1.0 : 0.7;

      // Start drawing
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

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

      // Draw main yellow circle
      final circlePaint = Paint()
        ..color = backgroundColor.withOpacity(opacity)
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
                : BitmapDescriptor.hueYellow,
      );
    }
  }

  /// 📍 Create driver location marker (blue circle)
  Future<BitmapDescriptor> _createDriverLocationMarker() async {
    try {
      const double size = 24.0; // حجم صغير
      const double circleSize = 16.0; // الدائرة الرئيسية

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // رسم الدائرة الزرقاء (اللون الثانوي للتطبيق)
      final circlePaint = Paint()
        ..color = AppColors.secondary // اللون الثانوي الأزرق
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

    _markers.clear();

    // 📍 إضافة marker لموقع السائق الحالي
    try {
      final driverIcon = await _createDriverLocationMarker();
      _markers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: const LatLng(_testLatitude, _testLongitude),
          icon: driverIcon,
          anchor: const Offset(0.5, 0.5),
          zIndex: 1000, // أعلى من باقي الـ markers
        ),
      );
    } catch (e) {
      print('⚠️ فشل إنشاء marker موقع السائق: $e');
    }

    // Add store markers with design based on expansion_priority
    for (final store in _mapData!.nearbyStores) {
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
      final icon = await _createStoreMarkerIcon(
        category: store.category,
        isCoreRegion: store.expansionPriority == 0,
        hotScore: store.hotScore,
        isOpen: store.isOpen,
      );

      _markers.add(
        Marker(
          markerId: MarkerId(store.storeId),
          position: LatLng(store.lat, store.lng),
          icon: icon,
          infoWindow: InfoWindow(
            title: store.name,
          ),
          onTap: () => _showStoreDetails(store),
        ),
      );
    }

    setState(() {});
  }
  
  /// Show store details in bottom sheet when tapped
  /// 🗺️ Open maps application with navigation from driver location to store
  Future<void> _openMapsNavigation(NearbyStore store) async {
    // استخدام الإحداثيات الثابتة للاختبار أو الموقع الفعلي
    final driverLat = _currentPosition?.latitude ?? _testLatitude;
    final driverLng = _currentPosition?.longitude ?? _testLongitude;
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
    final wazeAppUrl = 
      'waze://?ll=$storeLat,$storeLng&navigate=yes';
    
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
    ) ?? store;
    
    print('📊 Store details - Old: isOpen=${store.isOpen}, acceptingOrders=${store.acceptingOrders}');
    print('📊 Store details - New: isOpen=${updatedStore.isOpen}, acceptingOrders=${updatedStore.acceptingOrders}');
    
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
                  child: updatedStore.photoUrl != null && updatedStore.photoUrl!.isNotEmpty
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
                                updatedStore.category == 'restaurant' ? Icons.restaurant :
                                updatedStore.category == 'pharmacy' ? Icons.local_pharmacy : Icons.store,
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
                            updatedStore.category == 'restaurant' ? Icons.restaurant :
                            updatedStore.category == 'pharmacy' ? Icons.local_pharmacy : Icons.store,
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
                        updatedStore.category == 'restaurant' ? 'مطعم' :
                        updatedStore.category == 'pharmacy' ? 'صيدلية' : 'متجر',
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
                  foregroundColor: Colors.black87, // نص أسود للقراءة الواضحة على الأصفر
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28), // حواف دائرية مثل زر شارك الآن
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
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.25, // Start small at bottom like Spark
      minChildSize: 0.25,     // Minimum size to stay visible
      maxChildSize: 0.85,     // Maximum when fully expanded
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: _buildSheetContent(),
                ),
              ),
            ],
          ),
        );
      },
    );
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
        // "Get offers until" section like Spark - clickable
        GestureDetector(
          onTap: () => _showSparkNowTimeSelection(), // إظهار قائمة الأوقات مع خيار الإيقاف
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'الحصول على طلبات حتى',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.secondary.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(_searchEndTime ?? DateTime.now().add(const Duration(hours: 1))),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.edit,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
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
        // Main Spark Now button (like in the original app)
        Container(
          width: double.infinity,
          height: 56,
          margin: const EdgeInsets.only(bottom: 24),
          child: ElevatedButton(
            onPressed: _startSearchingForOffers,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, // اللون الأساسي للتطبيق
              foregroundColor: Colors.black87, // نص أسود للقراءة الواضحة على الأصفر
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.3),
            ),
            child: const Text(
              'شارك الآن',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        
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
                color: AppColors.secondary.withOpacity(0.3), 
                width: 1.5
              ),
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
        // Getting more offers section (exactly like Spark)
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.settings,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الحصول على طلبات أكثر',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'تعيين وصول الموقع إلى المشاركة دائماً يساعد في الحصول على طلبات أكثر.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
        
        // Popular offer times section
        _buildPopularOfferTimes(),
      ],
    );
  }

  Widget _buildPopularOfferTimes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'أوقات الطلبات الشائعة: اليوم',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Flexible(
              child: Text(
                'استكشف أيام إضافية للقيادة هذا الأسبوع.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Time bars chart (simplified version like Spark)
        _buildOfferTimesBars(),
      ],
    );
  }

  Widget _buildOfferTimesBars() {
    final timeSlots = ['6a', '9a', '12p', '3p', '6p', '9p'];
    final values = [0.3, 0.4, 0.8, 0.9, 0.7, 0.6]; // Sample data
    final currentHour = DateTime.now().hour;
    
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(timeSlots.length, (index) {
          final isCurrentTime = _isCurrentTimeSlot(timeSlots[index], currentHour);
          final barHeight = 80 * values[index];
          
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 32,
                height: barHeight,
                decoration: BoxDecoration(
                  color: isCurrentTime ? AppColors.primary : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                timeSlots[index],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: isCurrentTime ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  bool _isCurrentTimeSlot(String timeSlot, int currentHour) {
    switch (timeSlot) {
      case '6a': return currentHour >= 6 && currentHour < 9;
      case '9a': return currentHour >= 9 && currentHour < 12;
      case '12p': return currentHour >= 12 && currentHour < 15;
      case '3p': return currentHour >= 15 && currentHour < 18;
      case '6p': return currentHour >= 18 && currentHour < 21;
      case '9p': return currentHour >= 21 || currentHour < 6;
      default: return false;
    }
  }

  @override
  void dispose() {
    try {
      print('🧹 Disposing SparkHomeSimpleArabic resources...');
      
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
        if (_offerExpiryCleanupTimer != null && _offerExpiryCleanupTimer!.isActive) {
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
        if (_storesStatusRefreshTimer != null && _storesStatusRefreshTimer!.isActive) {
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
    // استخدام القائمة المحفوظة بدلاً من إنشاء قائمة جديدة
    final timeOptions = _timeOptions ?? <DateTime>[];

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with Spark icon and title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Spark icon (blue star-like icon)
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star,
                    color: Colors.black87,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _isSearchingForOffers ? 'تحديث البحث' : 'شارك الآن',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Description text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _isSearchingForOffers 
                ? 'اختر وقت جديد للبحث أو أوقف البحث:'
                : 'مع تشغيل شارك الآن، ستتلقى عروض حتى:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Time options list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: timeOptions.length,
              itemBuilder: (context, index) {
                final time = timeOptions[index];
                final isSelected = _selectedEndTime != null && 
                    _selectedEndTime!.millisecondsSinceEpoch == time.millisecondsSinceEpoch;

                return GestureDetector(
                  onTap: () {
                    setModalState(() {
                      _selectedEndTime = time;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.secondary.withOpacity(0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.secondary : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.secondary : Colors.grey[400]!,
                              width: 2,
                            ),
                            color: Colors.white,
                          ),
                          child: isSelected
                              ? Container(
                                  margin: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.secondary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          _formatTime(time),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppColors.secondary : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom buttons
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // إذا كان في وضع البحث، إظهار زر "إيقاف البحث" أولاً
                if (_isSearchingForOffers) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _stopSearching();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'إيقاف البحث',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // زر إلغاء
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                    ),
                    child: Text(
                      _isSearchingForOffers ? 'إلغاء' : 'إيقاف',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // زر تشغيل/تحديث البحث
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_selectedEndTime != null && !_isCheckingWalletBalance)
                        ? () {
                            _confirmSparkNow(_selectedEndTime!);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isCheckingWalletBalance
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'جاري الفحص...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _isSearchingForOffers ? 'تحديث الوقت' : 'تشغيل',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    _storesStatusRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
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
      final data = await MapDataService.fetchMapData(
        lat: _testLatitude,
        lng: _testLongitude,
      );
      
      if (!mounted) return;
      
      // التحقق من وجود تغييرات في حالة المطاعم
      bool hasStatusChanges = false;
      if (_mapData != null) {
        for (int i = 0; i < data.nearbyStores.length; i++) {
          final newStore = data.nearbyStores[i];
          final oldStore = _mapData!.nearbyStores.firstWhere(
            (s) => s.storeId == newStore.storeId,
            orElse: () => newStore,
          );
          
          // مقارنة الحالات
          if (oldStore.isOpen != newStore.isOpen || 
              oldStore.acceptingOrders != newStore.acceptingOrders) {
            hasStatusChanges = true;
            print('🔄 Driver: تغيرت حالة المطعم ${newStore.name}: '
                  'isOpen: ${oldStore.isOpen} -> ${newStore.isOpen}, '
                  'acceptingOrders: ${oldStore.acceptingOrders} -> ${newStore.acceptingOrders}');
          }
        }
      }
      
      // تحديث الـ UI فقط إذا كان هناك تغييرات
      if (hasStatusChanges || _mapData == null) {
        setState(() {
          _mapData = data;
          _updateMapMarkers();
        });
        print('✅ Driver: تم تحديث حالة المطاعم بنجاح');
      } else {
        print('ℹ️ Driver: لا توجد تغييرات في حالة المطاعم');
      }
      
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
  
  /// معالج استقبال wave offer جديد
  void _handleWaveOffer(WaveOffer waveOffer) async {
    try {
      print('🌊 Processing wave offer: ${waveOffer.offerId}');
      print('🌊 Wave ${waveOffer.waveNumber}, Rank ${waveOffer.rank}, Score ${waveOffer.score}');
      
      // إضافة إلى قائمة العروض الحالية (بدلاً من فتح dialog)
      setState(() {
        // Remove any existing offer with same ID (e.g., placeholder injected from push tap)
        _currentWaveOffers.removeWhere((o) => o.offerId == waveOffer.offerId);
        _currentWaveOffers.add(waveOffer);
        _currentWaveOffer = waveOffer; // للتوافق مع الكود القديم
      });
      
      // تشغيل صوت الإشعار
      await _playNotificationSound();
      
      print('✅ Wave offer added to list. Total offers: ${_currentWaveOffers.length}');
      
    } catch (e) {
      print('❌ Error handling wave offer: $e');
    }
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
    
    print('✅ Offer removed from list. Remaining offers: ${_currentWaveOffers.length}');
  }
  
  /// معالج قبول wave offer من سائق آخر
  void _handleWaveOfferTaken(String offerId) {
    print('👥 Wave offer taken by another driver: $offerId');
    
    setState(() {
      _currentWaveOffers.removeWhere((offer) => offer.offerId == offerId);
      if (_currentWaveOffer?.offerId == offerId) {
        _currentWaveOffer = null;
      }
    });
    
    // عرض رسالة
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم قبول هذا الطلب من سائق آخر'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
    
    print('✅ Offer removed from list. Remaining offers: ${_currentWaveOffers.length}');
  }
  
  /// عرض dialog لـ wave offer
  void _showWaveOfferDialog(WaveOffer waveOffer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WaveOfferDialog(
        offer: waveOffer,
        onAccept: () => _acceptWaveOffer(waveOffer),
        onReject: () => _showRejectConfirmationSheet(waveOffer), // ✅ عرض Bottom Sheet للتأكيد
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
      print('✅ Accepting wave offer: ${waveOffer.offerId}');
      
      // إزالة العرض من القائمة فوراً
      setState(() {
        _currentWaveOffers.removeWhere((offer) => offer.offerId == waveOffer.offerId);
        _currentWaveOffer = null;
      });
      
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 16),
                Text('جاري قبول الطلب...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }
      
      // Get driver ID from authenticated session
      final driverId = await DriverAuthHelper.getCurrentDriverId();
      
      if (driverId == null || driverId.isEmpty) {
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
      );
      
      print('📡 acceptWaveOffer API response:');
      print('   - success: ${result['success']}');
      print('   - message: ${result['message']}');
      print('   - full response: $result');
      
      // Hide loading snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      
      if (result['success'] == true) {
        // Success
        print('✅ Wave offer accepted successfully');
        print('📝 Order ID: ${waveOffer.orderId}');
        print('📱 Context mounted: $mounted');
        
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
          print('🚀 Navigating to active order screen with orderId: ${waveOffer.orderId}');
          
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
        final isOrderTakenByAnother = message.contains('تم قبول الطلب من سائق آخر') ||
                                      message.contains('ORDER_ALREADY_ACCEPTED') ||
                                      message.contains('HOLD_ALREADY_EXISTS');
        
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
  Future<void> _fetchDriverMetrics() async {
    try {
      print('📡 Fetching driver metrics from API...');
      final metrics = await DriverSearchApiService.getDriverMetrics();
      print('📥 API Response: $metrics');
      
      if (metrics != null && mounted) {
        setState(() {
          _currentAcceptanceRate = (metrics['acceptanceRate'] ?? 0.0).toDouble();
          _totalAccepted = (metrics['totalAccepted'] ?? 0);
          _totalRejected = (metrics['totalRejected'] ?? 0);
        });
        print('✅ Metrics loaded from API:');
        print('   acceptanceRate = $_currentAcceptanceRate');
        print('   totalAccepted = $_totalAccepted');
        print('   totalRejected = $_totalRejected');
      } else {
        // قيم افتراضية في حال فشل جلب البيانات
        if (mounted) {
          setState(() {
            _currentAcceptanceRate = 0.75; // 75%
            _totalAccepted = 30;
            _totalRejected = 10;
          });
        }
        print('⚠️ Using default metrics values (API returned null)');
      }
    } catch (e) {
      print('❌ Error fetching driver metrics: $e');
      // استخدام قيم افتراضية عند الخطأ
      if (mounted) {
        setState(() {
          _currentAcceptanceRate = 0.75;
          _totalAccepted = 30;
          _totalRejected = 10;
        });
      }
    }
  }
  
  /// 📊 حساب معدل القبول المتوقع بعد الرفض
  double _calculateExpectedAcceptanceRate() {
    if (_totalAccepted == null || _totalRejected == null) {
      return 0.0;
    }
    
    final newTotalAccepted = _totalAccepted!;
    final newTotalRejected = _totalRejected! + 1; // بعد إضافة رفض واحد
    final newTotal = newTotalAccepted + newTotalRejected;
    
    if (newTotal == 0) return 0.0;
    
    return newTotalAccepted / newTotal;
  }
  
  /// 🚫 عرض Bottom Sheet لتأكيد الرفض
  Future<void> _showRejectConfirmationSheet(WaveOffer waveOffer) async {
    print('📄 Opening reject confirmation for offer: ${waveOffer.offerId}');
    
    // تسجيل العرض الذي نعرض له نافذة التأكيد
    _currentRejectConfirmationOfferId = waveOffer.offerId;
    
    // عرض loading أولاً
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
    
    // جلب metrics
    await _fetchDriverMetrics();
    
    if (!mounted) return;
    
    // إغلاق loading
    Navigator.pop(context);
    
    final currentRate = _currentAcceptanceRate ?? 0.0;
    final expectedRate = _calculateExpectedAcceptanceRate();
    final rateChange = expectedRate - currentRate;
    
    print('📊 Showing reject sheet with: current=$currentRate, expected=$expectedRate, change=$rateChange');
    
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
              'لا بأس! هناك دائماً فرص أفضل في الطريق 🌟',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Acceptance Rate Impact
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA), // أوف وايت
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  const Text(
                    'تأثير على معدل القبول',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00296B),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Current → Expected
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Current Rate
                      Column(
                        children: [
                          const Text(
                            'الحالي',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(currentRate * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00296B), // اللون الثانوي الأزرق
                            ),
                          ),
                        ],
                      ),
                      
                      // Arrow
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Icon(
                          Icons.arrow_forward, // السهم من اليمين إلى اليسار
                          size: 24,
                          color: Color(0xFF00296B), // اللون الثانوي الأزرق
                        ),
                      ),
                      
                      // Expected Rate
                      Column(
                        children: [
                          const Text(
                            'المتوقع',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(expectedRate * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.red, // اللون الأحمر للمعدل المتوقع
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Change indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00296B), // اللون الثانوي الأزرق للخلفية
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_downward, // سهم الانخفاض
                          size: 14,
                          color: Color(0xFFFDC500), // اللون الأساسي الأصفر
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(rateChange * 100).abs().toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFDC500), // اللون الأساسي الأصفر
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
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
                      backgroundColor: const Color(0xFFFDC500), // اللون الأساسي الأصفر
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
    print('🚀🚀🚀 REJECT BUTTON PRESSED! 🚀🚀🚀');
    print('📋 WaveOffer details:');
    print('   - offerId: ${waveOffer.offerId}');
    print('   - orderId: ${waveOffer.orderId}');
    
    try {
      print('❌ [1/5] Starting reject process...');
      
      // Get driver ID FIRST before removing from UI
      print('❌ [2/5] Getting driver ID...');
      final driverId = await DriverAuthHelper.getCurrentDriverId();
      
      if (driverId == null || driverId.isEmpty) {
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
          reason: 'driver_declined',
        );
        
        print('✅ [4/5] API response received: $result');
        
        // Only remove from UI after successful API call
        print('❌ [5/5] Removing from UI...');
        setState(() {
          _currentWaveOffers.removeWhere((offer) => offer.offerId == waveOffer.offerId);
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
  
  /// عرض تفاصيل Wave Order في bottom sheet
  void _showWaveOrderDetails(WaveOffer offer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OrderDetailsBottomSheet(
        offer: offer,
        onAccept: () {
          Navigator.pop(context);
          _acceptWaveOffer(offer);
        },
        onReject: () {
          Navigator.pop(context);
          _rejectWaveOffer(offer);
        },
      ),
    );
  }
}