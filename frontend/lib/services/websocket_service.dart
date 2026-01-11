import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

import '../config/environment.dart';
import '../models/order_model.dart';
import '../models/wave_offer.dart';
import 'native_websocket_channel.dart';

enum WebSocketStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

enum MessageType {
  // Authentication & Connection
  driverConnect,
  driverDisconnect,
  driverAuthenticate,

  // Driver Status Updates
  driverLocationUpdate,
  driverStatusUpdate,
  driverOnline,
  driverOffline,

  // Order Lifecycle (Cross-app communication)
  newOrderAssignment, // Platform → Driver: New order assigned
  orderAccepted, // Driver → Platform → Customer + Merchant
  orderRejected, // Driver → Platform → Customer + Merchant
  orderPickedUp, // Driver → Platform → Customer + Merchant
  orderDelivered, // Driver → Platform → Customer + Merchant
  orderCancelled, // Any app → Platform → All relevant apps
  orderStatusUpdate, // Driver → Platform → Customer + Merchant

  // Real-time Communication (Cross-app)
  merchantMessage, // Merchant → Platform → Driver
  customerMessage, // Customer → Platform → Driver
  platformMessage, // Platform → Driver
  driverMessage, // Driver → Platform → Customer/Merchant
  emergencyAlert, // Driver → Platform → All apps

  // System Events
  heartbeat,
  systemNotification,
  configUpdate,

  // Ecosystem-wide events
  orderCreated, // Customer → Platform → Available drivers
  merchantAccepted, // Merchant → Platform → Assigned driver
  driverAssigned, // Platform → Driver + Customer + Merchant
  deliveryTracking, // Driver → Platform → Customer
}

class WebSocketMessage {
  final MessageType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? targetId;
  final String messageId;

  WebSocketMessage({
    required this.type,
    required this.data,
    DateTime? timestamp,
    this.targetId,
    String? messageId,
  })  : timestamp = timestamp ?? DateTime.now(),
        messageId =
            messageId ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'target_id': targetId,
        'message_id': messageId,
      };

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.systemNotification,
      ),
      data: json['data'] ?? {},
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      targetId: json['target_id'],
      messageId: json['message_id'],
    );
  }
}

class WebSocketService extends ChangeNotifier {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  // WebSocket connection
  WebSocketChannel? _channel;
  NativeWebSocketChannel? _nativeChannel; // 🆕 Native iOS WebSocket
  StreamSubscription? _subscription;
  StreamSubscription? _nativeSubscription; // 🆕 Native stream subscription
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  Timer? _connectionRefreshTimer; // 🆕 Proactive refresh timer
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  bool _useNativeWebSocket = false; // 🆕 Use native on iOS
  bool _isReconnecting = false; // ✅ NEW: Flag to prevent infinite loops

  // Connection state
  WebSocketStatus _status = WebSocketStatus.disconnected;
  String? _driverId;
  String? _authToken;
  static const Duration _heartbeatInterval =
      Duration(seconds: 15); // More frequent heartbeat
  static const Duration _connectionRefreshInterval = Duration(
      minutes: 8); // 🆕 Refresh every 8 minutes (before AWS 10min timeout)
  DateTime? _lastHeartbeatReceived;
  DateTime? _connectionEstablishedAt; // 🆕 Track connection age

  // Authentication state
  Completer<bool>? _authenticationCompleter;
  bool _isAuthenticated = false;

  // App State Management for persistent connection
  Timer? _connectionHealthTimer;
  static const Duration _connectionHealthInterval = Duration(seconds: 30);

  // Message handlers
  final Map<MessageType, List<Function(WebSocketMessage)>> _messageHandlers =
      {};
  final List<WebSocketMessage> _messageQueue = [];

  // 🆕 Wave Offer Streams
  final _waveOfferController = StreamController<WaveOffer>.broadcast();
  final _offerExpiredController = StreamController<String>.broadcast();
  final _offerTakenController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  WebSocketStatus get status => _status;
  bool get isConnected => _status == WebSocketStatus.connected;
  bool get isAuthenticated => _isAuthenticated;
  String? get driverId => _driverId;

  bool get _isTransportConnected {
    if (!isConnected) return false;

    if (_useNativeWebSocket) {
      return _nativeChannel?.isConnected ?? false;
    }

    // Best-effort: the Dart channel doesn't expose a reliable "isOpen" flag.
    // We rely on onDone/onError to flip status, but also require a non-null channel.
    return _channel != null;
  }

  // 🆕 Wave Offer Streams (Public)
  Stream<WaveOffer> get waveOfferStream => _waveOfferController.stream;
  Stream<String> get offerExpiredStream => _offerExpiredController.stream;
  Stream<Map<String, dynamic>> get offerTakenStream =>
      _offerTakenController.stream;

  /// انتظار اكتمال المصادقة
  Future<bool> waitForAuthentication(
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (_isAuthenticated) {
      return true;
    }

    if (_authenticationCompleter == null ||
        _authenticationCompleter!.isCompleted) {
      _authenticationCompleter = Completer<bool>();
    }

    try {
      return await _authenticationCompleter!.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint(
              '⚠️ Authentication timeout after ${timeout.inSeconds} seconds');
          return false;
        },
      );
    } catch (e) {
      debugPrint('❌ Error waiting for authentication: $e');
      return false;
    }
  }

  // Callbacks
  Function(OrderModel)? onNewOrderAssignment;
  Function(String, String)? onMerchantMessage;
  Function(String, String)? onCustomerMessage;
  Function(String)? onEmergencyAlert;
  Function(Map<String, dynamic>)? onSystemNotification;

  /// Get unique device identifier
  Future<String> _getUniqueDeviceId() async {
    try {
      // Try to get device info if available
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return 'ios_${iosInfo.identifierForVendor ?? 'unknown'}_$_driverId';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return 'android_${androidInfo.id}_$_driverId';
      }

      // Fallback to timestamp-based ID
      return 'device_${DateTime.now().millisecondsSinceEpoch}_$_driverId';
    } catch (e) {
      debugPrint('⚠️ Could not get device info: $e');
      // Fallback to timestamp-based ID
      return 'device_${DateTime.now().millisecondsSinceEpoch}_$_driverId';
    }
  }

  /// Initialize WebSocket service
  Future<void> initialize({
    required String driverId,
    required String authToken,
  }) async {
    // ✅ CRITICAL FIX: Prevent duplicate initialization during reconnection
    if (_isReconnecting) {
      debugPrint(
          '⚠️ Reconnection in progress - skipping duplicate initialization request');
      return;
    }

    // ✅ CRITICAL FIX: Prevent duplicate initialization
    if (_status == WebSocketStatus.connecting ||
        _status == WebSocketStatus.connected) {
      debugPrint(
          '⚠️ WebSocket already ${_status.name} - skipping duplicate initialization');
      return;
    }

    debugPrint('🔌 Initializing WebSocket Service...');

    _driverId = driverId;
    _authToken = authToken;

    // Set up message handlers
    _setupMessageHandlers();

    // Connect to WebSocket
    await connect();

    debugPrint('✅ WebSocket Service initialized');
  }

  /// Connect to WebSocket server
  Future<void> connect() async {
    if (_status == WebSocketStatus.connecting ||
        _status == WebSocketStatus.connected) {
      return;
    }

    // Don't attempt to connect before we have a real authenticated driver context.
    // This service can be triggered by lifecycle events even while the app is on /login.
    if (_driverId == null || _driverId!.isEmpty || _driverId == 'unknown') {
      debugPrint(
          '⏭️ WebSocket connect skipped: missing driverId (not logged in yet)');
      _setStatus(WebSocketStatus.disconnected);
      return;
    }

    try {
      _setStatus(WebSocketStatus.connecting);
      debugPrint('🔌 Connecting to WebSocket server...');

      // 🔧 FIX: Get JWT token for authentication like WizzUser app
      String? token = _authToken;
      try {
        // Try to get JWT token from Amplify/Cognito like users do
        final result = await Amplify.Auth.fetchAuthSession();
        if (result.isSignedIn) {
          final cognitoSession = result as CognitoAuthSession;
          token = cognitoSession.userPoolTokensResult.value.idToken.raw;
          debugPrint('🔧 JWT Token obtained for driver authentication');
        } else {
          debugPrint('⏭️ WebSocket connect skipped: not signed in');
          _setStatus(WebSocketStatus.disconnected);
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Could not get JWT token: $e');
      }

      if (token == null || token.isEmpty) {
        debugPrint('⏭️ WebSocket connect skipped: no auth token available');
        _setStatus(WebSocketStatus.disconnected);
        return;
      }

      final workingEndpoint = Environment.webSocketUrl;

      // Create unique device identifier to prevent multiple connections
      final deviceId = await _getUniqueDeviceId();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 🔧 FIX: DON'T send token in query params - iOS has URL length limit!
      // We'll send token in first authentication message instead
      final queryParams = <String, String>{
        'driverId':
            _driverId ?? 'unknown', // Primary identification for Wave System
        'userType': 'driver', // Specify this is a driver connection
        'businessId': Environment.businessId,
        'platform': 'ios',
        'appVersion': '2.0',
        'deviceId': deviceId,
        'timestamp': timestamp.toString(),
        'entityType': 'driver', // Clear entity type for backend routing
      };

      // Store token to send in authentication message after connection
      if (token.isNotEmpty) {
        _authToken = token;
        debugPrint('🔧 JWT Token will be sent in auth message (not URL)');
      }

      final uri =
          Uri.parse(workingEndpoint).replace(queryParameters: queryParams);

      debugPrint('🔗 FINAL Connecting WebSocket to: $uri');
      debugPrint('📱 Device ID: $deviceId');

      // ✅ CRITICAL iOS FIX: Use Native URLSessionWebSocketTask on iOS
      // iOS Dart SDK transforms wss:// to https://:0 causing 502 errors
      try {
        if (Platform.isIOS && !kIsWeb) {
          debugPrint(
              '🍎 iOS detected: Using Native WebSocket (URLSessionWebSocketTask)');
          _useNativeWebSocket = true;

          _nativeChannel = NativeWebSocketChannel();

          // ✅ CRITICAL FIX: Connect FIRST to initialize controllers
          // Then access stream to listen
          await _nativeChannel!.connect(uri.toString());

          // Now access stream (controllers are already initialized in connect())
          final nativeStream = _nativeChannel!.stream;

          // Listen to native stream
          _nativeSubscription = nativeStream.listen(
            (message) {
              try {
                _handleMessage(message);
              } catch (e) {
                debugPrint('❌ Error handling native message: $e');
              }
            },
            onError: (error) {
              debugPrint('❌ Native WebSocket stream error: $error');
              _handleError(error);
            },
            onDone: () {
              debugPrint('🔌 Native WebSocket stream closed');
              _handleDisconnection();
            },
            cancelOnError: false,
          );

          debugPrint('✅ Native WebSocket connected');
        } else {
          debugPrint('🔧 Using standard Dart WebSocket');
          _useNativeWebSocket = false;

          _channel = IOWebSocketChannel.connect(uri);

          // Listen to messages with better error handling
          _subscription = _channel!.stream.listen(
            _handleMessage,
            onError: _handleError,
            onDone: _handleDisconnection,
            cancelOnError: false,
          );

          debugPrint('✅ Standard WebSocket channel created');
        }
      } catch (connectError) {
        debugPrint('❌ WebSocket connect error: $connectError');
        debugPrint('   Error type: ${connectError.runtimeType}');
        _setStatus(WebSocketStatus.error);
        return;
      }

      // Start heartbeat
      _startHeartbeat();

      // 🆕 Start proactive connection refresh timer
      _startConnectionRefreshTimer();

      // 🆕 Track connection establishment time
      _connectionEstablishedAt = DateTime.now();

      _setStatus(WebSocketStatus.connected);

      // Send driver connection registration (includes authentication with JWT token)
      await _sendDriverConnectionRegistration();

      // Send queued messages
      await _sendQueuedMessages();

      debugPrint('✅ WebSocket connected successfully to unified endpoint');
    } catch (e) {
      debugPrint('❌ WebSocket connection failed: $e');
      _setStatus(WebSocketStatus.error);
      // Do not reconnect automatically; user can manually retry.
      return;
    }
  }

  /// Disconnect from WebSocket server
  Future<void> disconnect() async {
    debugPrint('🔌 Disconnecting from WebSocket...');

    _heartbeatTimer?.cancel();
    _connectionRefreshTimer?.cancel();
    _subscription?.cancel();
    _nativeSubscription?.cancel(); // 🆕 Cancel native subscription

    // Send disconnect message
    await _sendMessage(
      WebSocketMessage(
        type: MessageType.driverDisconnect,
        data: {'driver_id': _driverId},
      ),
    );

    // Close appropriate channel
    if (_useNativeWebSocket && _nativeChannel != null) {
      await _nativeChannel!.disconnect();
      _nativeChannel = null;
    } else if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }

    _connectionEstablishedAt = null;
    _setStatus(WebSocketStatus.disconnected);
    debugPrint('✅ WebSocket disconnected');
  }

  /// Send driver location update
  Future<void> sendLocationUpdate({
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    double? accuracy,
  }) async {
    await _sendMessage(
      WebSocketMessage(
        type: MessageType.driverLocationUpdate,
        data: {
          'driver_id': _driverId,
          'location': {
            'latitude': latitude,
            'longitude': longitude,
            'heading': heading,
            'speed': speed,
            'accuracy': accuracy,
          },
          'timestamp': DateTime.now().toIso8601String(),
        },
      ),
    );
  }

  /// Send driver status update (online/offline/busy)
  Future<void> sendStatusUpdate({
    required String status,
    String? currentZone,
    Map<String, dynamic>? metadata,
  }) async {
    await _sendMessage(
      WebSocketMessage(
        type: MessageType.driverStatusUpdate,
        data: {
          'driver_id': _driverId,
          'status': status,
          'current_zone': currentZone,
          'metadata': metadata ?? {},
          'timestamp': DateTime.now().toIso8601String(),
        },
      ),
    );
  }

  /// Accept an order
  Future<void> acceptOrder(String orderId) async {
    await _sendMessage(
      WebSocketMessage(
        type: MessageType.orderAccepted,
        data: {
          'driver_id': _driverId,
          'order_id': orderId,
          'accepted_at': DateTime.now().toIso8601String(),
        },
      ),
    );
  }

  /// Reject an order
  Future<void> rejectOrder(String orderId, {String? reason}) async {
    await _sendMessage(
      WebSocketMessage(
        type: MessageType.orderRejected,
        data: {
          'driver_id': _driverId,
          'order_id': orderId,
          'reason': reason ?? 'Driver declined',
          'rejected_at': DateTime.now().toIso8601String(),
        },
      ),
    );
  }

  /// Update order status
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    Map<String, dynamic>? metadata,
  }) async {
    await _sendMessage(
      WebSocketMessage(
        type: MessageType.orderStatusUpdate,
        data: {
          'driver_id': _driverId,
          'order_id': orderId,
          'status': status,
          'metadata': metadata ?? {},
          'timestamp': DateTime.now().toIso8601String(),
        },
      ),
    );
  }

  /// Send message to merchant
  Future<void> sendMessageToMerchant({
    required String merchantId,
    required String message,
    String? orderId,
  }) async {
    await _sendMessage(
      WebSocketMessage(
        type: MessageType.merchantMessage,
        targetId: merchantId,
        data: {
          'driver_id': _driverId,
          'merchant_id': merchantId,
          'order_id': orderId,
          'message': message,
          'timestamp': DateTime.now().toIso8601String(),
        },
      ),
    );
  }

  /// Send message to customer
  Future<void> sendMessageToCustomer({
    required String customerId,
    required String message,
    String? orderId,
  }) async {
    await _sendMessage(
      WebSocketMessage(
        type: MessageType.customerMessage,
        targetId: customerId,
        data: {
          'driver_id': _driverId,
          'customer_id': customerId,
          'order_id': orderId,
          'message': message,
          'timestamp': DateTime.now().toIso8601String(),
        },
      ),
    );
  }

  /// Send emergency alert
  Future<void> sendEmergencyAlert({
    required String alertType,
    required double latitude,
    required double longitude,
    String? description,
  }) async {
    await _sendMessage(
      WebSocketMessage(
        type: MessageType.emergencyAlert,
        data: {
          'driver_id': _driverId,
          'alert_type': alertType,
          'location': {'latitude': latitude, 'longitude': longitude},
          'description': description,
          'timestamp': DateTime.now().toIso8601String(),
        },
      ),
    );
  }

  /// Subscribe to specific message types
  void subscribe(MessageType messageType, Function(WebSocketMessage) handler) {
    _messageHandlers[messageType] ??= [];
    _messageHandlers[messageType]!.add(handler);
  }

  /// Unsubscribe from message types
  void unsubscribe(
    MessageType messageType,
    Function(WebSocketMessage) handler,
  ) {
    _messageHandlers[messageType]?.remove(handler);
  }

  /// Send message through WebSocket
  Future<void> _sendMessage(WebSocketMessage message) async {
    if (!isConnected) {
      debugPrint(
        '⚠️ WebSocket not connected, queuing message: ${message.type.name}',
      );
      _messageQueue.add(message);
      return;
    }

    try {
      final jsonMessage = jsonEncode(message.toJson());

      // Use appropriate channel
      if (_useNativeWebSocket && _nativeChannel != null) {
        await _nativeChannel!.send(jsonMessage);
      } else if (_channel != null) {
        _channel!.sink.add(jsonMessage);
      } else {
        throw Exception('No WebSocket channel available');
      }

      debugPrint('📤 Sent message: ${message.type.name}');
    } catch (e) {
      debugPrint('❌ Failed to send message: $e');

      // If the transport is actually down, flip status so reconnect logic can run.
      if (isConnected) {
        final errorText = e.toString();
        if (errorText.contains('WebSocket not connected') ||
            errorText.contains('No WebSocket channel available')) {
          _handleDisconnection();
        }
      }

      _messageQueue.add(message); // Queue failed messages
    }
  }

  Future<void> _sendQueuedMessages() async {
    while (_messageQueue.isNotEmpty && isConnected) {
      final message = _messageQueue.removeAt(0);
      sendMessage(message);
      debugPrint('📤 Sent queued message: ${message.type.name}');
    }
  }

  /// Handle incoming WebSocket messages with enhanced crash protection
  void _handleMessage(dynamic data) {
    try {
      debugPrint('WEBSOCKET MESSAGE RECEIVED');
      debugPrint('RAW MESSAGE RECEIVED: ${data.toString()}');
      debugPrint('🔍 MESSAGE TYPE: ${data.runtimeType}');
      debugPrint('🔍 MESSAGE LENGTH: ${data.toString().length}');
      debugPrint('⏰ RECEIVED AT: ${DateTime.now().toIso8601String()}');

      if (data == null || data.toString().isEmpty) {
        debugPrint('⚠️ Received empty or null message');
        return;
      }

      final Map<String, dynamic> json;
      try {
        json = jsonDecode(data.toString());
        debugPrint('📥 PARSED JSON: $json');
      } catch (jsonError) {
        debugPrint('❌ Failed to parse JSON: $jsonError');
        debugPrint('Raw data: ${data.toString()}');
        return;
      }

      // Handle unified websocket message format with error protection
      if (json.containsKey('type') || json.containsKey('action')) {
        debugPrint(
            '🔍 UNIFIED MESSAGE DETECTED - Type: ${json['type']} - Action: ${json['action']}');
        try {
          _handleUnifiedWebSocketMessage(json);
        } catch (unifiedError) {
          debugPrint('❌ Error in unified message handler: $unifiedError');
          // Continue processing - don't crash
        }
        return;
      }

      // Handle standard WebSocket message format
      WebSocketMessage message;
      try {
        message = WebSocketMessage.fromJson(json);
        debugPrint('📥 Received message: ${message.type.name}');
      } catch (messageError) {
        debugPrint('❌ Failed to create WebSocketMessage: $messageError');
        return;
      }

      // Handle specific message types with individual error protection
      try {
        switch (message.type) {
          case MessageType.newOrderAssignment:
            _handleNewOrderAssignment(message);
            break;
          case MessageType.merchantMessage:
            _handleMerchantMessage(message);
            break;
          case MessageType.customerMessage:
            _handleCustomerMessage(message);
            break;
          case MessageType.emergencyAlert:
            _handleEmergencyAlert(message);
            break;
          case MessageType.systemNotification:
            _handleSystemNotification(message);
            break;
          case MessageType.heartbeat:
            // Heartbeat acknowledged
            _lastHeartbeatReceived = DateTime.now();
            debugPrint('💓 Heartbeat acknowledged at $_lastHeartbeatReceived');
            break;
          default:
            debugPrint('🔍 Unhandled message type: ${message.type.name}');
            break;
        }
      } catch (handlerError) {
        debugPrint('❌ Error in message type handler: $handlerError');
        // Continue processing - don't crash
      }

      // Call registered handlers with individual error protection
      final handlers = _messageHandlers[message.type];
      if (handlers != null) {
        for (final handler in handlers) {
          try {
            handler(message);
          } catch (e) {
            debugPrint('❌ Message handler error: $e');
            // Continue with other handlers - don't crash
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('🚨 CRITICAL: Unhandled error in _handleMessage: $e');
      debugPrint('Stack trace: $stackTrace');
      // Log critical error but don't crash the app
    }
  }

  /// Handle WebSocket errors
  void _handleError(error) {
    debugPrint('❌ WebSocket error: $error');
    _setStatus(WebSocketStatus.error);
    // Do not auto-reconnect after error; allow manual retry
  }

  /// Handle WebSocket disconnection
  void _handleDisconnection() {
    debugPrint('⚠️ WebSocket disconnected');
    _setStatus(WebSocketStatus.disconnected);

    // ✅ CRITICAL FIX: Don't auto-reconnect if already in reconnection flow
    // This prevents infinite reconnection loops
    if (_isReconnecting) {
      debugPrint('⏭️ Already reconnecting, skipping...');
      return;
    }

    // ✅ CRITICAL FIX: Auto-reconnect when connection is lost
    // This handles API Gateway timeout/expiration scenarios
    if (_driverId != null && _authToken != null) {
      debugPrint('🔄 Connection lost - will attempt auto-reconnect...');
      _attemptReconnect();
    } else {
      debugPrint('⚠️ Cannot reconnect - missing credentials');
    }
  }

  // Helper method to send raw JSON
  Future<void> _sendRawJson(String jsonMessage) async {
    if (_useNativeWebSocket && _nativeChannel != null) {
      await _nativeChannel!.send(jsonMessage);
    } else if (_channel != null) {
      _channel!.sink.add(jsonMessage);
    } else {
      throw Exception('No WebSocket channel available');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      // ✅ CRITICAL FIX: Don't send heartbeat or attempt reconnect if already reconnecting
      if (_isReconnecting) {
        debugPrint('💔 Heartbeat skipped - currently reconnecting');
        return;
      }

      if (_isTransportConnected) {
        try {
          // Send heartbeat compatible with unified websocket system
          final heartbeatMessage = {
            'action': 'heartbeat',
            'type': 'ping',
            'driverId': _driverId,
            'userId': _driverId,
            'userType': 'driver',
            'timestamp': DateTime.now().toIso8601String(),
          };
          try {
            await _sendRawJson(jsonEncode(heartbeatMessage));
            debugPrint('💓 Heartbeat sent successfully at ${DateTime.now()}');
          } catch (sendError) {
            debugPrint('❌ Failed to send heartbeat: $sendError');
            rethrow;
          }

          // ✅ ENHANCED: Check if we haven't received a heartbeat response in a while
          // This catches API Gateway timeouts that don't send close events
          if (_lastHeartbeatReceived != null) {
            final timeSinceLastHeartbeat =
                DateTime.now().difference(_lastHeartbeatReceived!);

            // If no heartbeat response for 30 seconds (2 heartbeat intervals), connection is stale
            if (timeSinceLastHeartbeat > const Duration(seconds: 30)) {
              debugPrint(
                  '⚠️ Connection stale: No heartbeat response for ${timeSinceLastHeartbeat.inSeconds}s');
              debugPrint('🔄 Forcing reconnection due to stale connection...');
              _handleConnectionStale();
            }
          }
        } catch (e) {
          debugPrint('❌ Error sending heartbeat: $e');
          _handleConnectionError();
        }
      } else {
        // If our internal status claims connected but transport is not, flip status.
        if (isConnected) {
          debugPrint(
              '⚠️ Transport disconnected while status=connected; marking disconnected');
          _handleDisconnection();
        }

        debugPrint('💔 Heartbeat skipped - not connected');
        // ✅ FIX: DON'T auto-reconnect on every heartbeat failure!
        // Only reconnect if we haven't received heartbeat response for extended period
        // Auto-reconnection should only happen in _handleDisconnection()
        debugPrint(
            '⚠️ Waiting for disconnection event to trigger reconnection');
      }
    });
  }

  void _handleConnectionStale() {
    if (_isReconnecting) {
      debugPrint('⏭️ Already reconnecting, skipping stale detection');
      return;
    }
    debugPrint('🔄 Connection appears stale, attempting to refresh...');
    _attemptReconnect();
  }

  void _handleConnectionError() {
    if (_isReconnecting) {
      debugPrint('⏭️ Already reconnecting, skipping error handling');
      return;
    }
    debugPrint('❌ Connection error detected, will attempt reconnect');
    _setStatus(WebSocketStatus.error);
    _attemptReconnect();
  }

  /// 🆕 Start proactive connection refresh timer
  /// This prevents the AWS API Gateway 10-minute idle timeout by
  /// refreshing the connection every 8 minutes BEFORE it becomes stale
  void _startConnectionRefreshTimer() {
    _connectionRefreshTimer?.cancel();

    _connectionRefreshTimer =
        Timer.periodic(_connectionRefreshInterval, (timer) async {
      if (isConnected && _connectionEstablishedAt != null) {
        final connectionAge =
            DateTime.now().difference(_connectionEstablishedAt!);
        debugPrint(
            '🔄 Proactive connection refresh - Age: ${connectionAge.inMinutes}m ${connectionAge.inSeconds % 60}s');

        // Refresh connection to prevent AWS API Gateway timeout
        await _refreshConnection();
      }
    });

    debugPrint(
        '⏰ Connection refresh timer started (every ${_connectionRefreshInterval.inMinutes} minutes)');
  }

  /// 🆕 Refresh WebSocket connection proactively
  /// Called automatically every 8 minutes or manually when starting/stopping search
  ///
  /// 🚨 CRITICAL FIX: Instead of disconnect+reconnect (which causes iOS URL bug),
  /// we just send a heartbeat/ping to keep connection alive
  Future<void> _refreshConnection() async {
    if (!_isTransportConnected) {
      debugPrint('⚠️ Cannot refresh - not connected');
      return;
    }

    try {
      debugPrint('🔄 Refreshing WebSocket connection (sending keepalive)...');

      // ✅ FIX: Don't disconnect! Just send a raw keepalive heartbeat.
      // Using raw send here ensures we don't silently "queue" and mistakenly report success.
      final keepalive = {
        'action': 'heartbeat',
        'type': 'ping',
        'driverId': _driverId,
        'userId': _driverId,
        'userType': 'driver',
        'purpose': 'connection_refresh',
        'timestamp': DateTime.now().toIso8601String(),
      };
      try {
        await _sendRawJson(jsonEncode(keepalive));
        debugPrint('✅ Connection keepalive sent successfully');
      } catch (sendError) {
        debugPrint('❌ Failed to send keepalive: $sendError');
        // Don't rethrow - just log and let next heartbeat handle it
      }
    } catch (e) {
      debugPrint('❌ Error refreshing connection: $e');
      // Don't call _attemptReconnect() here - it will cause iOS URL bug
      // Just log and continue - next heartbeat will handle it
    }
  }

  /// 🆕 Public method to manually refresh connection
  /// Call this when starting/stopping driver search
  Future<void> refreshConnection() async {
    debugPrint('🔄 Manual connection refresh requested');
    await _refreshConnection();
  }

  void _attemptReconnect() {
    // ✅ CRITICAL FIX: Set reconnecting flag to prevent loops
    _isReconnecting = true;

    // ✅ CRITICAL FIX: Stop heartbeat timer during reconnection to prevent infinite loop
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint(
          '❌ Max reconnection attempts reached ($_maxReconnectAttempts)');
      debugPrint('🔄 Resetting counter - will try again in 30 seconds...');

      // ✅ FIX: Don't give up! Reset after cooldown period
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 30), () {
        debugPrint('🔄 Cooldown complete - resetting reconnect attempts');
        _reconnectAttempts = 0;
        _attemptReconnect();
      });
      _setStatus(WebSocketStatus.reconnecting);
      return;
    }

    if (_status == WebSocketStatus.reconnecting &&
        _reconnectTimer != null &&
        _reconnectTimer!.isActive) {
      debugPrint(
          '⏳ Reconnection already in progress - skipping duplicate attempt');
      return; // Already attempting to reconnect
    }

    _setStatus(WebSocketStatus.reconnecting);
    _reconnectAttempts++;

    // ✅ IMPROVED: Exponential backoff (1s, 2s, 4s, 8s, 16s)
    final backoffDelay =
        Duration(seconds: (1 << (_reconnectAttempts - 1)).clamp(1, 16));

    debugPrint(
        '🔄 Attempting reconnection #$_reconnectAttempts in ${backoffDelay.inSeconds}s...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(backoffDelay, () async {
      try {
        // ✅ CRITICAL FIX: Cancel heartbeat again right before disconnecting
        // This prevents heartbeat timer from detecting disconnected state and triggering another reconnection
        _heartbeatTimer?.cancel();
        _heartbeatTimer = null;

        debugPrint('🔌 Disconnecting before reconnect...');
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 500));

        debugPrint('🔌 Reconnecting to WebSocket...');
        await connect();

        if (_status == WebSocketStatus.connected) {
          _reconnectAttempts = 0; // Reset on successful connection
          _isReconnecting = false; // ✅ Clear reconnecting flag
          debugPrint('✅ Reconnection successful! New connection established.');
        } else {
          _isReconnecting = false; // ✅ Clear flag even if failed
        }
      } catch (e) {
        debugPrint('❌ Reconnection attempt #$_reconnectAttempts failed: $e');
        _isReconnecting = false; // ✅ Clear flag on error
        if (_reconnectAttempts < _maxReconnectAttempts) {
          _attemptReconnect(); // Try again with exponential backoff
        }
      }
    });
  }

  /// Send a message through the WebSocket.
  Future<void> sendMessage(WebSocketMessage message) async {
    if (isConnected) {
      await _sendRawJson(jsonEncode(message.toJson()));
    } else {
      _messageQueue.add(message);
      debugPrint(
          '⚠️ WebSocket not connected. Queued message: ${message.type.name}');
      // Do not automatically reconnect here to avoid loops.
      // Reconnection should be handled manually or with a more robust strategy.
    }
  }

  /// Register a handler for a specific message type.
  void on(MessageType type, Function(WebSocketMessage) handler) {
    if (!_messageHandlers.containsKey(type)) {
      _messageHandlers[type] = [];
    }
    _messageHandlers[type]!.add(handler);
  }

  /// Set up message handlers
  void _setupMessageHandlers() {
    // Set up built-in handlers
    subscribe(MessageType.newOrderAssignment, (message) {
      _handleNewOrderAssignment(message);
    });
  }

  /// Handle new order assignment
  void _handleNewOrderAssignment(WebSocketMessage message) {
    try {
      final orderData = message.data['order'];
      if (orderData != null) {
        final order = OrderModel.fromJson(orderData);
        onNewOrderAssignment?.call(order);
      }
    } catch (e) {
      debugPrint('❌ Failed to handle new order assignment: $e');
    }
  }

  /// Handle merchant message
  void _handleMerchantMessage(WebSocketMessage message) {
    final merchantId = message.data['merchant_id'];
    final messageContent = message.data['message'];

    if (merchantId != null && messageContent != null) {
      onMerchantMessage?.call(merchantId, messageContent);
    }
  }

  /// Handle customer message
  void _handleCustomerMessage(WebSocketMessage message) {
    final customerId = message.data['customer_id'];
    final messageContent = message.data['message'];

    if (customerId != null && messageContent != null) {
      onCustomerMessage?.call(customerId, messageContent);
    }
  }

  /// Handle emergency alert
  void _handleEmergencyAlert(WebSocketMessage message) {
    final alertType = message.data['alert_type'];
    if (alertType != null) {
      onEmergencyAlert?.call(alertType);
    }
  }

  /// Handle system notification
  void _handleSystemNotification(WebSocketMessage message) {
    onSystemNotification?.call(message.data);
  }

  /// Set connection status
  void _setStatus(WebSocketStatus status) {
    if (_status != status) {
      _status = status;
      notifyListeners();
      debugPrint('🔌 WebSocket status changed: ${status.name}');
    }
  }

  /// Handle unified websocket messages from WizzUser system
  void _handleUnifiedWebSocketMessage(Map<String, dynamic> json) {
    try {
      debugPrint('🔥🔥🔥 UNIFIED MESSAGE HANDLER CALLED! 🔥🔥🔥');
      final String messageType = json['type'] ?? json['action'] ?? 'unknown';
      debugPrint('📥 Received unified message: $messageType');
      debugPrint('📥 Full message content: ${json.toString()}');
      debugPrint('🔍 Message keys: ${json.keys.toList()}');

      switch (messageType) {
        case 'connection_ack':
          debugPrint('✅ Driver connection acknowledged');
          final connectionId = json['connectionId'];
          if (connectionId != null) {
            debugPrint('🔑 ConnectionID: $connectionId');
            debugPrint(
                '📝 Store this connectionId - Backend will use it to send orders!');
          }
          break;

        // 🌊 WAVE SYSTEM OFFERS (Priority-Based Dispatch)
        case 'new_wave_offer':
        case 'wave_offer':
          debugPrint('🌊🌊🌊 WAVE OFFER RECEIVED! 🌊🌊🌊');
          debugPrint('📊 Wave offer data: ${json.toString()}');
          _handleWaveOffer(json);
          break;

        case 'offer_expired':
          _handleOfferExpired(json);
          break;

        case 'offer_accepted_by_other':
        case 'offer_no_longer_available':
        case 'offer_taken': // 🆕 NEW: Backend notification when another driver accepts
          _handleOfferAcceptedByOther(json);
          break;

        case 'offer_acceptance_confirmed':
          _handleOfferAcceptanceConfirmed(json);
          break;

        // Legacy Order Assignment
        case 'order_offer':
        case 'driver_offer':
          _handleOrderOffer(json);
          break;

        case 'order_assigned':
          _handleOrderAssigned(json);
          break;

        case 'order_cancelled':
        case 'order_canceled':
          _handleOrderCancelled(json);
          break;

        case 'order_unassigned':
          _handleOrderUnassigned(json);
          break;

        case 'heartbeat_response':
        case 'pong':
        case 'heartbeat':
          _lastHeartbeatReceived = DateTime.now();
          debugPrint(
              '💓 Heartbeat response received at $_lastHeartbeatReceived');
          break;

        case 'auth_success':
          _handleAuthSuccess(json);
          break;

        case 'auth_error':
          _handleAuthError(json);
          break;

        case 'system_notification':
          _handleSystemMessage(json);
          break;

        default:
          debugPrint('⚠️ Unknown unified message type: $messageType');
          break;
      }
    } catch (e) {
      debugPrint('❌ Error handling unified message: $e');
    }
  }

  /// Handle order offer from central platform
  void _handleOrderOffer(Map<String, dynamic> json) {
    try {
      debugPrint('🍔 New order offer received!');

      final orderData = json['order'] ?? json['data'] ?? json;
      final orderId =
          orderData['orderId'] ?? orderData['order_id'] ?? orderData['id'];

      if (orderId != null) {
        // Create OrderModel from the data
        final order = OrderModel.fromJson(orderData);

        // Notify the app about new order
        onNewOrderAssignment?.call(order);

        debugPrint('📝 Order offer processed: $orderId');
      } else {
        debugPrint('⚠️ Order offer missing orderId');
      }
    } catch (e) {
      debugPrint('❌ Error handling order offer: $e');
    }
  }

  /// Handle order assignment confirmation
  void _handleOrderAssigned(Map<String, dynamic> json) {
    try {
      debugPrint('✅ Order assignment confirmed');

      final orderData = json['order'] ?? json['data'] ?? json;
      final orderId =
          orderData['orderId'] ?? orderData['order_id'] ?? orderData['id'];

      if (orderId != null) {
        final order = OrderModel.fromJson(orderData);
        onNewOrderAssignment?.call(order);
      }
    } catch (e) {
      debugPrint('❌ Error handling order assignment: $e');
    }
  }

  /// Handle order cancellation
  void _handleOrderCancelled(Map<String, dynamic> json) {
    try {
      debugPrint('❌ Order cancelled notification');

      final orderData = json['order'] ?? json['data'] ?? json;
      final orderId =
          orderData['orderId'] ?? orderData['order_id'] ?? orderData['id'];

      if (orderId != null) {
        // Notify app about order cancellation
        onSystemNotification?.call({
          'type': 'order_cancelled',
          'orderId': orderId,
          'message': 'الطلب تم إلغاؤه',
        });
      }
    } catch (e) {
      debugPrint('❌ Error handling order cancellation: $e');
    }
  }

  /// Handle order unassignment (driver unassigned, order still active)
  void _handleOrderUnassigned(Map<String, dynamic> json) {
    try {
      debugPrint('🔗 Order unassignment notification received');
      debugPrint('📥 Unassignment data: ${json.toString()}');

      final data = json['data'] ?? json;
      final orderId = data['orderId'] ?? data['order_id'] ?? data['id'];
      final message = data['message'] ?? 'تم فك ارتباطك من الطلب';
      final reason = data['reason'];

      if (orderId != null) {
        debugPrint('🔗 Unassigned from order: $orderId');
        debugPrint('📝 Reason: $reason');
        debugPrint('💬 Message: $message');

        // Notify app about order unassignment
        onSystemNotification?.call({
          'type': 'order_unassigned',
          'orderId': orderId,
          'message': message,
          'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        debugPrint('⚠️ Unassignment notification missing orderId');
      }
    } catch (e) {
      debugPrint('❌ Error handling order unassignment: $e');
    }
  }

  /// Handle system messages
  void _handleSystemMessage(Map<String, dynamic> json) {
    try {
      final message = json['message'] ?? 'إشعار نظام';
      debugPrint('🔔 System notification: $message');

      onSystemNotification?.call(json);
    } catch (e) {
      debugPrint('❌ Error handling system message: $e');
    }
  }

  /// 🌊 Handle Wave Offer from Wave System (Priority-Based)
  void _handleWaveOffer(Map<String, dynamic> json) {
    try {
      debugPrint('🌊🌊🌊 WAVE OFFER HANDLER CALLED! 🌊🌊🌊');
      debugPrint('📊 Full Wave JSON: $json');

      final messageType = json['type'];
      final offerData = json['offer'] ?? json['data'] ?? json;

      debugPrint('🌊 Message type: $messageType');
      debugPrint('🌊 Offer data extracted: $offerData');

      // Verify this is actually a Wave Offer
      final hasWaveNumber =
          offerData['waveNumber'] != null || offerData['wave_number'] != null;
      final hasRank =
          offerData['rank'] != null || offerData['priority'] != null;

      if (!hasWaveNumber && !hasRank) {
        debugPrint(
            '⚠️ WARNING: Message claims to be wave_offer but missing wave data!');
        debugPrint(
            '⚠️ This might be a legacy offer mistakenly labeled as wave_offer');
        return;
      }

      // Convert to WaveOffer model
      try {
        final waveOffer = WaveOffer.fromJson(offerData);
        debugPrint('✅ WaveOffer created successfully!');
        debugPrint('   📋 Offer ID: ${waveOffer.offerId}');
        debugPrint('   🌊 Wave Number: ${waveOffer.waveNumber}');
        debugPrint('   🏆 Driver Rank: ${waveOffer.rank}');
        debugPrint('   🏪 Restaurant: ${waveOffer.restaurantName}');
        debugPrint('   💰 Earnings: ${waveOffer.estimatedEarnings} IQD');
        debugPrint('   📦 Items: ${waveOffer.itemsCount}');
        debugPrint('   ⏱️ Expires: ${waveOffer.expiresAt}');

        debugPrint('🔥🔥🔥 Broadcasting to waveOfferStream! 🔥🔥🔥');
        _waveOfferController.add(waveOffer);
        debugPrint('✅ Wave offer broadcasted successfully to UI!');
      } catch (e, stackTrace) {
        debugPrint('❌ Error converting to WaveOffer: $e');
        debugPrint('❌ Stack trace: $stackTrace');
        debugPrint('❌ Offer data that failed: $offerData');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Critical error in _handleWaveOffer: $e');
      debugPrint('❌ Stack trace: $stackTrace');
    }
  }

  /// Handle offer expiration
  void _handleOfferExpired(Map<String, dynamic> json) {
    try {
      final offerId = json['offerId'] ?? json['offer_id'] ?? json['id'];

      if (offerId != null) {
        debugPrint('⏰ Wave offer expired: $offerId');
        _offerExpiredController.add(offerId);
      }
    } catch (e) {
      debugPrint('❌ Error handling offer expiration: $e');
    }
  }

  /// Handle offer accepted by another driver
  void _handleOfferAcceptedByOther(Map<String, dynamic> json) {
    try {
      final offerId = json['offerId'] ?? json['offer_id'] ?? json['id'];

      if (offerId != null) {
        debugPrint('🤝 Wave offer accepted by another driver: $offerId');
        _offerTakenController.add({
          'offerId': offerId,
          'message': json['message'] ?? 'Offer taken by another driver'
        });
      }
    } catch (e) {
      debugPrint('❌ Error handling offer acceptance by other: $e');
    }
  }

  /// Handle offer acceptance confirmation
  void _handleOfferAcceptanceConfirmed(Map<String, dynamic> json) {
    try {
      debugPrint('✅ Wave offer acceptance confirmed');

      final orderData = json['order'] ?? json['data'] ?? json;
      final orderId =
          orderData['orderId'] ?? orderData['order_id'] ?? orderData['id'];

      if (orderId != null && orderData != null) {
        final order = OrderModel.fromJson(orderData);
        onNewOrderAssignment?.call(order);
      }

      onSystemNotification?.call({
        'type': 'offer_accepted',
        'message': 'تم قبول الطلب بنجاح',
        'data': json
      });
    } catch (e) {
      debugPrint('❌ Error handling offer acceptance confirmation: $e');
    }
  }

  /// Send driver connection registration for unified websocket system
  Future<void> _sendDriverConnectionRegistration() async {
    if (!isConnected || _driverId == null) return;

    try {
      // Registration message compatible with unified WizzUser websocket system
      // Send an explicit authentication message that the backend expects
      final registrationMessage = {
        'action': 'authenticate',
        'type': 'authenticate',
        'userId': _driverId,
        'userType': 'driver',
        'driverId': _driverId,
        'token': _authToken,
        'deviceId': 'driver_device_$_driverId',
        'platform': 'ios',
        'appVersion': '1.0.0',
        'businessId': Environment.businessId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _sendRawJson(jsonEncode(registrationMessage));
      debugPrint(
          '📝 Driver authentication sent to unified websocket: $_driverId');

      // Also send driver online status
      await Future.delayed(const Duration(milliseconds: 500));
      await _sendDriverOnlineStatus();
    } catch (e) {
      debugPrint('❌ Failed to send driver registration: $e');
    }
  }

  /// Send driver online status
  Future<void> _sendDriverOnlineStatus() async {
    if (!isConnected || _driverId == null) return;

    try {
      final onlineMessage = {
        'action': 'driver_status',
        'type': 'driver_online',
        'driverId': _driverId,
        'userId': _driverId,
        'userType': 'driver',
        'status': 'online',
        'isActive': true,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _sendRawJson(jsonEncode(onlineMessage));
      debugPrint('🟢 Driver online status sent: $_driverId');
    } catch (e) {
      debugPrint('❌ Failed to send driver online status: $e');
    }
  }

  /// Handle authentication success response
  void _handleAuthSuccess(Map<String, dynamic> json) {
    try {
      debugPrint('✅ Driver authentication successful');

      final userType = json['userType'];

      if (userType == 'driver') {
        debugPrint('🔐 Authenticated as driver');

        // تعيين حالة المصادقة
        _isAuthenticated = true;
        if (_authenticationCompleter != null &&
            !_authenticationCompleter!.isCompleted) {
          _authenticationCompleter!.complete(true);
        }

        // Notify the app about successful authentication
        onSystemNotification?.call({
          'type': 'auth_success',
          'message': 'تم تسجيل الدخول بنجاح',
          'userType': userType,
          'timestamp': json['timestamp']
        });
      } else {
        debugPrint('⚠️ Invalid auth success response');
        if (_authenticationCompleter != null &&
            !_authenticationCompleter!.isCompleted) {
          _authenticationCompleter!.complete(false);
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling auth success: $e');
      if (_authenticationCompleter != null &&
          !_authenticationCompleter!.isCompleted) {
        _authenticationCompleter!.complete(false);
      }
    }
  }

  /// Handle authentication error response
  void _handleAuthError(Map<String, dynamic> json) {
    try {
      final message = json['message'] ?? 'Authentication failed';
      final error = json['error'] ?? 'Unknown error';

      debugPrint('❌ Driver authentication failed: $message');

      // Notify the app about authentication failure
      onSystemNotification?.call({
        'type': 'auth_error',
        'message': 'فشل في تسجيل الدخول',
        'error': error,
        'details': message,
        'timestamp': json['timestamp']
      });

      // Optionally disconnect and retry
      disconnect();
    } catch (e) {
      debugPrint('❌ Error handling auth error: $e');
    }
  }

  /// Handle app lifecycle changes - call this from anywhere in the app
  void notifyAppLifecycleChange(bool appInBackground) {
    if (appInBackground) {
      debugPrint(
          '📱 App moved to background - maintaining persistent WebSocket');
      _handleAppPaused();
    } else {
      debugPrint('📱 App resumed - ensuring WebSocket connection');
      _handleAppResumed();
    }
  }

  /// Handle app paused (background)
  void _handleAppPaused() {
    // Don't disconnect WebSocket in background - iOS should maintain it
    // Just start more aggressive health monitoring
    _startConnectionHealthMonitoring();
  }

  /// Handle app resumed (foreground)
  void _handleAppResumed() {
    // Stop aggressive health monitoring
    _stopConnectionHealthMonitoring();

    // ✅ ENHANCED: Check connection health immediately when returning to foreground
    if (!isConnected) {
      debugPrint('🔄 WebSocket disconnected during background - reconnecting');
      // Reset reconnection attempts for fresh start
      _reconnectAttempts = 0;
      connect();
    } else {
      debugPrint('✅ WebSocket still connected after resume - verifying...');

      // ✅ CRITICAL FIX: Verify connection is actually alive, not just flagged as connected
      // If last heartbeat response was more than 30s ago, connection is likely stale
      if (_lastHeartbeatReceived != null) {
        final timeSinceLastHeartbeat =
            DateTime.now().difference(_lastHeartbeatReceived!);
        if (timeSinceLastHeartbeat > const Duration(seconds: 30)) {
          debugPrint(
              '⚠️ Connection appears stale (${timeSinceLastHeartbeat.inSeconds}s since last heartbeat)');
          debugPrint('🔄 Forcing reconnection to ensure fresh connection...');
          _reconnectAttempts = 0;
          disconnect().then((_) {
            Future.delayed(const Duration(milliseconds: 500), () {
              connect();
            });
          });
          return;
        }
      }

      // Connection looks good - just send a ping to verify
      _sendPing();
    }
  }

  /// Start aggressive connection health monitoring for background
  void _startConnectionHealthMonitoring() {
    _stopConnectionHealthMonitoring(); // Stop existing timer

    _connectionHealthTimer = Timer.periodic(_connectionHealthInterval, (timer) {
      if (!isConnected) {
        debugPrint(
            '🚨 WebSocket disconnected in background - attempting reconnect');
        connect();
      } else {
        // Send background heartbeat
        _sendPing();
      }
    });
  }

  /// Stop connection health monitoring
  void _stopConnectionHealthMonitoring() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
  }

  /// Send ping to test connection
  Future<void> _sendPing() async {
    if (isConnected) {
      try {
        final pingMessage = {
          'type': 'ping',
          'timestamp': DateTime.now().toIso8601String(),
          'driverId': _driverId,
          'source': 'driver_app'
        };
        await _sendRawJson(jsonEncode(pingMessage));
        debugPrint('📡 Sent background ping');
      } catch (e) {
        debugPrint('❌ Failed to send ping: $e');
      }
    }
  }

  /// Enhanced persistent connection for navigation between tabs
  void maintainPersistentConnection() {
    if (!isConnected) {
      debugPrint('🔄 Maintaining persistent connection - reconnecting');
      connect();
    } else {
      debugPrint('✅ Persistent connection maintained');
    }
  }

  /// Generate WebSocket key for handshake (iOS fix)
  /// Dispose resources
  @override
  void dispose() {
    _stopConnectionHealthMonitoring();
    disconnect();
    _messageHandlers.clear();
    _messageQueue.clear();

    // Close Wave Offer streams
    _waveOfferController.close();
    _offerExpiredController.close();
    _offerTakenController.close();

    super.dispose();
  }
}
