import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/chat_message_model.dart';
import '../models/order_model.dart';
import 'ecosystem_communication_service.dart';
import 'location_service.dart';
import 'unified_notification_service.dart';
import 'websocket_service.dart';

/// Real-time communication service that orchestrates WebSocket, notifications, and location services
/// for seamless integration with the food delivery ecosystem
class RealtimeCommunicationService extends ChangeNotifier {
  static final RealtimeCommunicationService _instance = RealtimeCommunicationService._internal();
  factory RealtimeCommunicationService() => _instance;
  RealtimeCommunicationService._internal();

  // Service instances
  late WebSocketService _webSocketService;
  late UnifiedNotificationService _notificationService;
  late LocationService _locationService;
  final EcosystemCommunicationService _ecosystemCommunicationService =
      EcosystemCommunicationService();

  // Driver state
  String? _driverId;
  bool _isOnline = false;
  bool _isInitialized = false;
  String? _currentZone;
  Timer? _locationUpdateTimer;

  // Active orders and messaging
  final Map<String, OrderModel> _activeOrders = {};
  final List<ChatMessage> _chatMessages = [];

  // Callbacks for UI updates
  Function(OrderModel)? onNewOrder;
  Function(OrderModel)? onOrderUpdated;
  Function(ChatMessage)? onNewMessage;
  Function(String)? onEmergencyAlert;
  Function(Map<String, dynamic>)? onSystemNotification;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isOnline => _isOnline;
  bool get isConnected => _webSocketService.isConnected;
  String? get driverId => _driverId;
  String? get currentZone => _currentZone;
  List<OrderModel> get activeOrders => _activeOrders.values.toList();
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);

  /// Initialize the real-time communication service (offline-safe)
  Future<void> initialize({
    required String driverId,
    required String driverName,
    required String driverPhone,
    required String authToken,
  }) async {
    if (_isInitialized) {
      debugPrint('⚠️ RealtimeCommunicationService already initialized');
      return;
    }

    try {
      debugPrint('🚀 Initializing RealtimeCommunicationService (offline-safe)...');

      _driverId = driverId;

      // Initialize services
      _webSocketService = WebSocketService();
      _notificationService = UnifiedNotificationService();
      _locationService = LocationService();

      // Initialize services but do not connect to any real endpoints in offline mode
      await _notificationService.initialize(
          driverPhoneNumber: driverPhone, driverName: driverName);
      await _locationService.initialize();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to initialize RealtimeCommunicationService: $e');
      _isInitialized = false;
    }
  }

  Future<void> goOnline({String? zone}) async {
    // In offline mode, just set flags and simulate success
    _currentZone = zone;
    _isOnline = true;
    notifyListeners();
  }

  Future<void> goOffline() async {
    _isOnline = false;
    _currentZone = null;
    _locationUpdateTimer?.cancel();
    notifyListeners();
  }

  Future<void> sendMessageToCustomer(String orderId, String message) async {
    await _ecosystemCommunicationService.sendMessageToCustomer(orderId, message);
  }

  Future<void> sendMessageToMerchant(String orderId, String message) async {
    await _ecosystemCommunicationService.sendMessageToMerchant(orderId, message);
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }
}
