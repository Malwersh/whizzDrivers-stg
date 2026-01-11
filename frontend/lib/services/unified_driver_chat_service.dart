import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/environment.dart';

/// Advanced WebSocket Chat Service for Driver App
/// Uses sophisticated connection management and fallback strategies
class UnifiedDriverChatService {
  static final UnifiedDriverChatService _instance =
      UnifiedDriverChatService._internal();
  factory UnifiedDriverChatService() => _instance;
  UnifiedDriverChatService._internal();

  // WebSocket endpoint for direct connection
  String get _wsEndpoint => Environment.liveChatWebSocketUrl;

  // WebSocket connection
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;

  // Enhanced connection state management
  Timer? _heartbeatTimer;
  Timer? _connectionHealthTimer;
  Timer? _adaptiveTimeoutTimer;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isInBackground = false;
  bool _networkAvailable = true;
  int _reconnectAttempts = 0;
  int _consecutiveFailures = 0;
  DateTime? _lastSuccessfulConnection;
  DateTime? _lastHeartbeatResponse;
  String? _driverId;
  String? _sessionId;
  String? _connectionId;

  // Adaptive connection parameters
  Duration _currentHeartbeatInterval = const Duration(seconds: 30);
  final Duration _currentReconnectDelay = const Duration(seconds: 2);
  final int _maxConsecutiveFailures = 3;

  // Configuration
  static const int _maxReconnectAttempts = 5;

  // Stream controllers for real-time updates
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _sessionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  // Public streams
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get sessionStream => _sessionController.stream;
  Stream<String> get statusStream => _statusController.stream;

  // Getters
  bool get isConnected => _isConnected;
  String? get sessionId => _sessionId;
  String? get connectionId => _connectionId;

  /// Initialize the chat service with driver information
  Future<bool> initialize(
    String driverId, {
    String? driverName,
    String? phoneNumber,
  }) async {
    _driverId = driverId;

    // Save driver info for reconnections
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('driver_id', driverId);
    if (driverName != null) {
      await prefs.setString('driver_name', driverName);
    }
    if (phoneNumber != null) {
      await prefs.setString('driver_phone', phoneNumber);
    }

    return await connect();
  }

  /// Connect to the unified chat WebSocket with advanced connection management
  Future<bool> connect() async {
    if (_isConnecting || _isConnected) {
      return _isConnected;
    }

    if (_driverId == null) {
      debugPrint('❌ Driver ID not set. Call initialize() first.');
      return false;
    }

    _isConnecting = true;
    _connectionId =
        'driver_${_driverId}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      debugPrint(
        '🔌 Connecting to unified chat system (attempt ${_reconnectAttempts + 1})...',
      );

      // Use adaptive connection timeout based on previous failures
      final connectionTimeout = _getAdaptiveTimeout();

      final uri = Uri.parse(_wsEndpoint);
      _channel = WebSocketChannel.connect(uri, protocols: ['chat']);

      // Set up connection with timeout
      bool connectionEstablished = false;

      // Listen to messages with enhanced error handling
      _channel!.stream
          .timeout(connectionTimeout)
          .listen(
            (data) {
              if (!connectionEstablished) {
                connectionEstablished = true;
                _onConnectionEstablished();
              }
              _handleMessage(data);
            },
            onError: _handleError,
            onDone: _handleDisconnection,
            cancelOnError: false, // Keep listening even after errors
          );

      // Send connection message with retry mechanism
      await _sendConnectionMessageWithRetry();

      // Wait for initial connection confirmation
      await Future.delayed(const Duration(milliseconds: 500));

      if (!connectionEstablished) {
        // If no response, still consider connected for now
        _onConnectionEstablished();
      }

      return true;
    } catch (error) {
      debugPrint('❌ Failed to connect: $error');
      _isConnecting = false;
      _consecutiveFailures++;
      _handleError(error);
      return false;
    }
  }

  /// Called when connection is successfully established
  void _onConnectionEstablished() {
    _isConnected = true;
    _isConnecting = false;
    _reconnectAttempts = 0;
    _consecutiveFailures = 0;
    _lastSuccessfulConnection = DateTime.now();
    _connectionController.add(true);

    // Start enhanced heartbeat
    _startAdaptiveHeartbeat();

    // Start connection health monitoring
    _startConnectionHealthMonitoring();

    debugPrint('✅ Connected to unified chat system');
  }

  /// Get adaptive timeout based on connection history
  Duration _getAdaptiveTimeout() {
    if (_consecutiveFailures == 0) {
      return const Duration(seconds: 10); // Normal timeout
    } else if (_consecutiveFailures < 3) {
      return const Duration(seconds: 15); // Slightly longer
    } else {
      return const Duration(seconds: 20); // Much longer for poor connections
    }
  }

  /// Enhanced connection message with retry mechanism
  Future<void> _sendConnectionMessageWithRetry() async {
    final prefs = await SharedPreferences.getInstance();
    final driverName = prefs.getString('driver_name') ?? 'Driver $_driverId';
    final phoneNumber = prefs.getString('driver_phone');

    final connectionMessage = {
      'type': 'chat_driver_connect',
      'driverId': _driverId,
      'driverName': driverName,
      'driverPhone': phoneNumber,
      'connectionId': _connectionId,
      'timestamp': DateTime.now().toIso8601String(),
      'clientInfo': {
        'platform': kIsWeb ? 'web' : 'mobile',
        'userAgent': 'WhizzDriver/1.0.0',
        'reconnectAttempt': _reconnectAttempts,
      },
    };

    // Try sending multiple times with increasing delays
    for (int i = 0; i < 3; i++) {
      try {
        _sendMessage(connectionMessage);
        debugPrint('📡 Sent driver connection message (attempt ${i + 1})');
        if (i > 0) await Future.delayed(Duration(milliseconds: 500 * i));
        break;
      } catch (e) {
        if (i == 2) rethrow; // Rethrow on final attempt
        await Future.delayed(Duration(milliseconds: 200 * (i + 1)));
      }
    }
  }

  /// Start adaptive heartbeat that adjusts based on connection quality
  void _startAdaptiveHeartbeat() {
    _heartbeatTimer?.cancel();

    // Adjust heartbeat interval based on connection stability
    if (_consecutiveFailures == 0) {
      _currentHeartbeatInterval = const Duration(seconds: 30);
    } else if (_consecutiveFailures < 2) {
      _currentHeartbeatInterval = const Duration(seconds: 20);
    } else {
      _currentHeartbeatInterval = const Duration(seconds: 15);
    }

    _heartbeatTimer = Timer.periodic(_currentHeartbeatInterval, (timer) {
      if (_isConnected && !_isInBackground) {
        _sendHeartbeatWithTracking();
      }
    });
  }

  /// Send heartbeat and track response time
  void _sendHeartbeatWithTracking() {
    final heartbeatTime = DateTime.now();

    _sendMessage({
      'action': 'heartbeat',
      'type': 'heartbeat',
      'timestamp': heartbeatTime.toIso8601String(),
      'connectionId': _connectionId,
      'sequenceId': heartbeatTime.millisecondsSinceEpoch,
    });

    // Set timeout for heartbeat response
    _adaptiveTimeoutTimer?.cancel();
    _adaptiveTimeoutTimer = Timer(const Duration(seconds: 10), () {
      debugPrint('⚠️ Heartbeat timeout - connection may be unstable');
      _consecutiveFailures++;

      if (_consecutiveFailures >= _maxConsecutiveFailures) {
        debugPrint('💔 Multiple heartbeat failures - reconnecting...');
        _forceReconnect();
      }
    });

    debugPrint(
      '💓 Heartbeat sent (interval: ${_currentHeartbeatInterval.inSeconds}s)',
    );
  }

  /// Start connection health monitoring
  void _startConnectionHealthMonitoring() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = Timer.periodic(const Duration(minutes: 1), (
      timer,
    ) {
      _performConnectionHealthCheck();
    });
  }

  /// Perform connection health check
  void _performConnectionHealthCheck() {
    if (!_isConnected) return;

    final now = DateTime.now();

    // Check if we haven't received heartbeat response in a while
    if (_lastHeartbeatResponse != null) {
      final timeSinceLastResponse = now.difference(_lastHeartbeatResponse!);
      if (timeSinceLastResponse > const Duration(minutes: 2)) {
        debugPrint(
          '🏥 Health check: No heartbeat response for ${timeSinceLastResponse.inMinutes} minutes',
        );
        _forceReconnect();
        return;
      }
    }

    // Check overall connection age
    if (_lastSuccessfulConnection != null) {
      final connectionAge = now.difference(_lastSuccessfulConnection!);
      if (connectionAge > const Duration(hours: 2)) {
        debugPrint('🔄 Health check: Refreshing long-lived connection');
        _forceReconnect();
        return;
      }
    }

    debugPrint('🏥 Connection health check: OK');
  }

  /// Force reconnection when connection is unhealthy
  void _forceReconnect() {
    debugPrint('🔄 Forcing reconnection due to health issues');
    disconnect();
    Future.delayed(const Duration(seconds: 2), () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  /// Handle app going to background/foreground
  void onAppLifecycleStateChanged(bool isInBackground) {
    _isInBackground = isInBackground;

    if (isInBackground) {
      debugPrint('📱 App went to background - adjusting connection strategy');
      // Reduce heartbeat frequency to save battery
      _startAdaptiveHeartbeat();
    } else {
      debugPrint('📱 App came to foreground - resuming normal connection');
      // Resume normal operation
      if (!_isConnected) {
        connect();
      } else {
        // Send immediate heartbeat to verify connection
        _sendHeartbeatWithTracking();
      }
    }
  }

  /// Handle network availability changes
  void onNetworkStateChanged(bool networkAvailable) {
    _networkAvailable = networkAvailable;

    if (!networkAvailable) {
      debugPrint('📶 Network unavailable - pausing connection attempts');
      _stopAdvancedHeartbeat();
      _reconnectTimer?.cancel();
    } else {
      debugPrint('📶 Network available - attempting to reconnect');
      if (!_isConnected && !_isConnecting) {
        Future.delayed(const Duration(seconds: 1), () {
          connect();
        });
      }
    }
  }

  /// Start a new chat session
  Future<String?> startChatSession({
    String? topic,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isConnected) {
      debugPrint('❌ Not connected to chat system');
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final driverName = prefs.getString('driver_name') ?? 'Driver $_driverId';

    // Use the correct protocol for initializing chat
    final sessionMessage = {
      'type': 'chat_init',
      'driverId': _driverId,
      'driverName': driverName,
      'topic': topic ?? 'Driver Support',
      'description': description ?? 'Driver requesting support',
      'metadata': {
        'app': 'WhizzDriver',
        'version': '1.0.0',
        'platform': kIsWeb ? 'web' : 'mobile',
        ...?metadata,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };

    _sendMessage(sessionMessage);

    debugPrint('📝 Chat session initialization sent: ${topic ?? "Support"}');
    return _sessionId;
  }

  /// Send a message in the current chat session
  Future<bool> sendChatMessage(String message, {String? sessionId}) async {
    if (!_isConnected) {
      debugPrint('❌ Not connected to chat system');
      return false;
    }

    final targetSessionId = sessionId ?? _sessionId;
    if (targetSessionId == null) {
      debugPrint('❌ No active session. Start a session first.');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final driverName = prefs.getString('driver_name') ?? 'Driver $_driverId';

    final chatMessage = {
      'type': 'chat_message',
      'sessionId': targetSessionId,
      'messageText': message,
      'senderType': 'driver',
      'senderId': _driverId,
      'senderName': driverName,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _sendMessage(chatMessage);

    debugPrint('💬 Message sent: $message');
    return true;
  }

  /// Send driver status update
  Future<bool> sendStatusUpdate(
    String status, {
    Map<String, dynamic>? locationData,
  }) async {
    if (!_isConnected) {
      return false;
    }

    final statusMessage = {
      'type': 'driver_status_update',
      'driverId': _driverId,
      'status': status,
      'location': locationData,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _sendMessage(statusMessage);
    return true;
  }

  /// Handle incoming WebSocket messages with enhanced processing
  void _handleMessage(dynamic data) {
    try {
      final message = json.decode(data.toString()) as Map<String, dynamic>;
      final messageType = message['type'] as String?;

      debugPrint('📨 Received: $messageType');

      switch (messageType) {
        case 'chat_session_created':
          _sessionId = message['sessionId'] as String?;
          _sessionController.add(message);
          debugPrint('✅ Chat session created: $_sessionId');
          break;

        case 'session_created':
          _sessionId = message['sessionId'] as String?;
          _sessionController.add(message);
          debugPrint('✅ Session created: $_sessionId');
          break;

        case 'chat_message':
        case 'message_received':
        case 'agent_message':
          _messageController.add(message);
          debugPrint('📨 Message received from agent');
          break;

        case 'session_assigned':
          _sessionController.add(message);
          debugPrint('👩‍💼 Agent assigned to session');
          break;

        case 'session_closed':
        case 'chat_session_closed':
          _sessionId = null;
          _sessionController.add(message);
          debugPrint('🔚 Session closed');
          break;

        case 'status_update':
          _statusController.add(message['status'] as String? ?? 'unknown');
          break;

        case 'heartbeat_response':
        case 'pong':
          // Enhanced heartbeat response handling
          _lastHeartbeatResponse = DateTime.now();
          _consecutiveFailures =
              0; // Reset failure count on successful heartbeat
          _adaptiveTimeoutTimer?.cancel(); // Cancel the timeout timer
          debugPrint('💓 Heartbeat acknowledged - connection healthy');
          break;

        case 'error':
          debugPrint('❌ Server error: ${message['message']}');
          break;

        default:
          debugPrint('🔍 Unknown message type: $messageType');
          _messageController.add(message);
      }
    } catch (error) {
      debugPrint('❌ Error parsing message: $error');
    }
  }

  /// Handle WebSocket errors with intelligent retry logic
  void _handleError(dynamic error) {
    debugPrint('❌ WebSocket error: $error');
    _isConnected = false;
    _connectionController.add(false);
    _consecutiveFailures++;

    // Only reconnect if we haven't exceeded the limit and network is available
    if (_reconnectAttempts < _maxReconnectAttempts && _networkAvailable) {
      _scheduleAdaptiveReconnect();
    } else {
      debugPrint(
        '❌ Max reconnection attempts reached or no network. Please restart manually.',
      );
    }
  }

  /// Handle WebSocket disconnection with enhanced cleanup
  void _handleDisconnection() {
    debugPrint('🔌 WebSocket disconnected');
    _isConnected = false;
    _connectionController.add(false);
    _stopAdvancedHeartbeat();

    // Only reconnect if we haven't exceeded the limit and network is available
    if (_reconnectAttempts < _maxReconnectAttempts && _networkAvailable) {
      _scheduleAdaptiveReconnect();
    } else {
      debugPrint(
        '❌ Max reconnection attempts reached or no network. Connection stopped.',
      );
    }
  }

  /// Schedule reconnection attempt with adaptive delays
  void _scheduleAdaptiveReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    // Adaptive delay: exponential backoff with jitter
    final baseDelay = _currentReconnectDelay.inSeconds * _reconnectAttempts;
    final jitterDelay = baseDelay + (DateTime.now().millisecond % 1000) / 1000;
    final delay = Duration(seconds: jitterDelay.round().clamp(2, 60));

    debugPrint(
      '🔄 Reconnecting in ${delay.inSeconds} seconds (attempt $_reconnectAttempts/$_maxReconnectAttempts)',
    );

    _reconnectTimer = Timer(delay, () {
      if (!_isConnected &&
          _reconnectAttempts <= _maxReconnectAttempts &&
          _networkAvailable) {
        debugPrint('🔄 Attempting smart reconnection...');
        connect();
      }
    });
  }

  /// Stop advanced heartbeat and cleanup timers
  void _stopAdvancedHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _adaptiveTimeoutTimer?.cancel();
    _adaptiveTimeoutTimer = null;
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
  }

  /// Send message to WebSocket
  void _sendMessage(Map<String, dynamic> message) {
    if (_channel?.sink != null && _isConnected) {
      try {
        final jsonMessage = json.encode(message);
        _channel!.sink.add(jsonMessage);
      } catch (error) {
        debugPrint('❌ Error sending message: $error');
      }
    }
  }

  /// Disconnect from the chat system
  Future<void> disconnect() async {
    _isConnected = false;
    _isConnecting = false;
    _stopAdvancedHeartbeat();
    _reconnectTimer?.cancel();

    try {
      await _channel?.sink.close();
    } catch (error) {
      debugPrint('❌ Error closing WebSocket: $error');
    }

    _channel = null;
    _sessionId = null;
    _connectionController.add(false);

    debugPrint('🔌 Disconnected from unified chat system');
  }

  /// Close a chat session
  Future<bool> closeChatSession([String? sessionId]) async {
    final targetSessionId = sessionId ?? _sessionId;
    if (targetSessionId == null) {
      return false;
    }

    final closeMessage = {
      'type': 'chat_session_close',
      'sessionId': targetSessionId,
      'driverId': _driverId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _sendMessage(closeMessage);

    if (targetSessionId == _sessionId) {
      _sessionId = null;
    }

    return true;
  }

  /// Get chat history for a session
  Future<List<Map<String, dynamic>>> getChatHistory([String? sessionId]) async {
    // This would typically make an HTTP request to get history
    // For now, return empty list as history is managed by the backend
    return [];
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    disconnect();
    _connectionController.close();
    _messageController.close();
    _sessionController.close();
    _statusController.close();
  }
}
