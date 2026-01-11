import 'dart:async';
import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../config/environment.dart';

/// Enhanced Live Chat Service with multi-tier connection strategy
/// Provides WebSocket → HTTP Bridge → Offline Queue fallback
class WizzCentralSupportChatService extends ChangeNotifier {
  static final WizzCentralSupportChatService _instance =
      WizzCentralSupportChatService._internal();
  factory WizzCentralSupportChatService() => _instance;
  WizzCentralSupportChatService._internal();

  // Connection state
  bool _isInitialized = false;
  bool _isConnecting = false;
  String _connectionStatus = 'disconnected';

  // Driver information
  String? _driverId;
  String? _driverName;
  String? _driverPhone;
  String? _sessionId;

  // WebSocket connection
  WebSocketChannel? _webSocket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _heartbeatInterval = Duration(seconds: 50);

  // Message queue for offline messages
  final List<Map<String, dynamic>> _messageQueue = [];
  static const int _maxQueueSize = 50;

  // Stream controllers for UI updates
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Public streams
  Stream<String> get connectionStatusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _connectionStatus == 'connected';
  String get connectionStatus => _connectionStatus;

  static const String _apiKey = 'wizzdriver_mobile_app_v1';

  /// Initialize the support chat service
  Future<bool> initializeSupportChat({
    required String driverId,
    required String driverName,
    String? driverPhone,
  }) async {
    if (_isInitialized) {
      debugPrint('🔄 Support chat already initialized');
      return true;
    }

    try {
      _driverId = driverId;
      _driverName = driverName;
      _driverPhone = driverPhone;
      _sessionId =
          'session_${driverId}_${DateTime.now().millisecondsSinceEpoch}';

      debugPrint('🚀 Initializing WizzCentral Support Chat...');
      debugPrint('📋 Driver: $_driverName ($_driverId)');

      _setConnectionStatus('initializing');

      // Try WebSocket connection first
      final webSocketConnected = await _connectWebSocket();
      
      if (webSocketConnected) {
        _isInitialized = true;
        debugPrint('✅ Support chat initialized via WebSocket');
        return true;
      }

      // Fallback: HTTP Bridge mode
      debugPrint('🔄 WebSocket failed, using HTTP Bridge mode');
      _setConnectionStatus('http_bridge');
      _isInitialized = true;

      return true;
    } catch (e) {
      debugPrint('❌ Failed to initialize support chat: $e');
      _setConnectionStatus('error');
      return false;
    }
  }

  /// Connect to WebSocket with JWT authentication
  Future<bool> _connectWebSocket() async {
    if (_isConnecting) {
      debugPrint('🔒 WebSocket connection already in progress');
      return false;
    }

    try {
      _isConnecting = true;
      _setConnectionStatus('connecting');

      // Get JWT token for authentication
      final jwtToken = await _getJWTToken();
      if (jwtToken == null) {
        debugPrint('❌ No JWT token available for WebSocket authentication');
        return false;
      }

      // Clean WebSocket URL (no query parameters)
      final wsUrl = Environment.liveChatWebSocketUrl;
      debugPrint('🔌 Connecting to WebSocket: $wsUrl');

      // Connect with JWT in Authorization header
      _webSocket = IOWebSocketChannel.connect(
        wsUrl,
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      // Set up message listener
      _webSocket!.stream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          debugPrint('❌ WebSocket error: $error');
          _handleWebSocketDisconnection('websocket_error');
        },
        onDone: () {
          debugPrint('🔌 WebSocket connection closed');
          _handleWebSocketDisconnection('connection_closed');
        },
      );

      // Send driver authentication
      await _sendDriverAuthentication();

      // Start heartbeat
      _startHeartbeat();

      _setConnectionStatus('connected');
      _reconnectAttempts = 0;

      debugPrint('✅ WebSocket connected successfully');
      return true;

    } catch (e) {
      debugPrint('❌ WebSocket connection failed: $e');
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  /// Get JWT token from AWS Cognito
  Future<String?> _getJWTToken() async {
    debugPrint('🔐 Attempting to get JWT token...');

    if (AppConfig.enableAWSIntegration) {
      try {
        debugPrint('🔐 AWS Integration enabled, checking Cognito session...');
        final session = await Amplify.Auth.fetchAuthSession();
        debugPrint('🔐 Session signed in: ${session.isSignedIn}');
        
        if (session.isSignedIn && session is CognitoAuthSession) {
          final tokens = session.userPoolTokensResult.value;
          final token = tokens.accessToken.raw;
          debugPrint('✅ JWT token obtained successfully');
          return token;
        } else {
          debugPrint('❌ No valid Cognito session found');
        }
      } catch (e) {
        debugPrint('❌ Error getting JWT token: $e');
      }
    } else {
      debugPrint('🔐 AWS Integration disabled');
    }
    
    return null;
  }

  /// Send driver authentication message
  Future<void> _sendDriverAuthentication() async {
    final authMessage = {
      'type': 'chat_init',
      'userId': _driverId,
      'userType': 'driver',
      'userDisplayName': _driverName,
      'context': {
        'driverId': _driverId,
        'driverName': _driverName,
        'driverPhone': _driverPhone,
        'platform': 'flutter',
        'app_version': '1.0.0',
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'wizzdriver_app',
      }
    };

    await _sendWebSocketMessage(authMessage);
    debugPrint('📤 Sent driver authentication');
  }

  /// Send a support message
  Future<bool> sendSupportMessage(String message) async {
    if (message.trim().isEmpty) {
      debugPrint('⚠️ Cannot send empty message');
      return false;
    }

    final messageData = {
      'action': 'chat_message',
      'type': 'chat_message',
      'sessionId': _sessionId,
      'messageText': message,
      'senderType': 'driver',
      'metadata': {
        'senderId': _driverId,
        'senderName': _driverName,
        'senderPhone': _driverPhone,
        'timestamp': DateTime.now().toIso8601String(),
        'platform': 'flutter',
        'source': 'wizzdriver_app',
      }
    };

    // Try WebSocket first
    if (_connectionStatus == 'connected' &&
        await _sendWebSocketMessage(messageData)) {
      debugPrint('✅ Message sent via WebSocket');
      return true;
    }

    // Fallback to HTTP Bridge
    debugPrint('🔄 Sending message via HTTP bridge...');
    return await _sendMessageViaHTTPBridge(message);
  }

  /// Send message via HTTP bridge as fallback
  Future<bool> _sendMessageViaHTTPBridge(String message) async {
    try {
      const bridgeUrl =
          '${Environment.chatBridgeApiUrl}/chat/send'; // aligns to /dev/api/chat/send

      final requestBody = {
        'participantToken': _sessionId,
        'message': message,
        'contentType': 'text/plain',
        'metadata': {
          'senderId': _driverId,
          'senderName': _driverName,
          'senderPhone': _driverPhone,
          'senderType': 'driver',
          'platform': 'flutter',
          'businessId': Environment.businessId,
          'timestamp': DateTime.now().toIso8601String(),
        }
      };

      debugPrint('📤 Sending to HTTP bridge: $bridgeUrl');

      final response = await http
          .post(
            Uri.parse(bridgeUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': _apiKey,
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ HTTP bridge response: ${responseData['message']}');
        
        // Update status to show HTTP bridge is working
        if (_connectionStatus != 'connected') {
          _setConnectionStatus('http_bridge_active');
        }

        return true;
      } else {
        debugPrint(
          '❌ HTTP bridge error: ${response.statusCode} - ${response.body}',
        );
        return false;
      }

    } catch (e) {
      debugPrint('❌ HTTP bridge failed: $e');

      // Queue message for later delivery
      _queueMessage({
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _setConnectionStatus('offline_queue');
      return false;
    }
  }

  /// Send WebSocket message
  Future<bool> _sendWebSocketMessage(Map<String, dynamic> message) async {
    if (_webSocket?.sink != null && _connectionStatus == 'connected') {
      try {
        _webSocket!.sink.add(jsonEncode(message));
        return true;
      } catch (e) {
        debugPrint('❌ Failed to send WebSocket message: $e');
        _handleWebSocketDisconnection('send_error');
        return false;
      }
    }
    return false;
  }

  /// Handle incoming WebSocket messages
  void _handleWebSocketMessage(dynamic data) {
    try {
      if (data == null || data.toString() == 'null') {
        debugPrint('📥 Received null message, ignoring...');
        return;
      }

      final message = jsonDecode(data.toString());
      debugPrint('📥 Received WebSocket message: ${message['type']}');

      // Emit message to UI
      _messageController.add(message);

      // Handle specific message types
      switch (message['type'] ?? message['action']) {
        case 'connection_confirmed':
          debugPrint('✅ Connection confirmed by server');
          break;
        case 'chat_session_created':
        case 'session_created':
          // Update session ID from server response
          if (message['sessionId'] != null) {
            _sessionId = message['sessionId'];
            debugPrint('📋 Session ID updated: $_sessionId');
          }
          break;
        case 'chat_message':
          // Handle incoming chat messages from agents
          final messageData = message['message'] ?? message;
          if (messageData['senderType'] == 'agent') {
            debugPrint(
              '💬 Agent message: ${messageData['text'] ?? messageData['messageText']}',
            );
          }
          break;
        case 'new_chat_session':
          debugPrint('🆕 New chat session notification');
          break;
        case 'heartbeat_response':
        case 'pong':
          debugPrint('💓 Heartbeat acknowledged');
          break;
        case 'error':
          debugPrint('❌ Server error: ${message['message']}');
          break;
        default:
          debugPrint('📨 Unknown message type: ${message['type']}');
      }
    } catch (e) {
      debugPrint('❌ Error processing WebSocket message: $e');
      debugPrint('📥 Raw message data: $data');
    }
  }

  /// Handle WebSocket disconnection
  void _handleWebSocketDisconnection(String reason) {
    debugPrint('📴 WebSocket disconnected: $reason');

    _stopHeartbeat();
    _setConnectionStatus('disconnected');

    // Attempt reconnection with exponential backoff
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnection();
    } else {
      debugPrint(
        '❌ Max reconnection attempts reached, switching to HTTP bridge mode',
      );
      _setConnectionStatus('http_bridge');
    }
  }

  /// Schedule reconnection attempt
  void _scheduleReconnection() {
    _reconnectTimer?.cancel();

    _reconnectAttempts++;
    final delay = Duration(
      seconds: 2 * _reconnectAttempts,
    ); // exponential backoff
    
    debugPrint(
      '🔄 Scheduling reconnection attempt $_reconnectAttempts in ${delay.inSeconds}s',
    );
    
    _reconnectTimer = Timer(delay, () {
      if (!_isConnecting && _connectionStatus != 'connected') {
        _connectWebSocket();
      }
    });
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    _stopHeartbeat();
    
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_connectionStatus == 'connected') {
        _sendWebSocketMessage({
          'type': 'heartbeat',
          'sessionId': _sessionId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        timer.cancel();
      }
    });
  }

  /// Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Queue message for offline delivery
  void _queueMessage(Map<String, dynamic> message) {
    if (_messageQueue.length >= _maxQueueSize) {
      _messageQueue.removeAt(0); // Remove oldest message
    }
    _messageQueue.add(message);
    debugPrint(
      '📝 Message queued for offline delivery (${_messageQueue.length} in queue)',
    );
  }

  /// Set connection status and notify listeners
  void _setConnectionStatus(String status) {
    if (_connectionStatus != status) {
      _connectionStatus = status;
      _statusController.add(status);
      notifyListeners();
      debugPrint('📊 Connection status: $status');
    }
  }

  /// Get human-readable status message
  String getStatusMessage() {
    switch (_connectionStatus) {
      case 'disconnected':
        return 'Disconnected';
      case 'initializing':
        return 'Initializing...';
      case 'connecting':
        return 'Connecting...';
      case 'connected':
        return 'Connected (Real-time)';
      case 'http_bridge':
        return 'Connected (HTTP Bridge)';
      case 'http_bridge_active':
        return 'Connected (Reliable Mode)';
      case 'offline_queue':
        return 'Offline (Messages Queued)';
      case 'error':
        return 'Connection Error';
      default:
        return 'Unknown Status';
    }
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    debugPrint('🔌 Disconnecting support chat...');

    _stopHeartbeat();
    _reconnectTimer?.cancel();

    if (_webSocket != null) {
      await _webSocket!.sink.close();
      _webSocket = null;
    }
    
    _setConnectionStatus('disconnected');
    _isInitialized = false;
    _isConnecting = false;
    _reconnectAttempts = 0;

    debugPrint('✅ Support chat disconnected');
  }

  /// Dispose resources
  @override
  void dispose() {
    disconnect();
    _statusController.close();
    _messageController.close();
    super.dispose();
  }
}
