import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/environment.dart';

/// Unified HTTP Bridge Chat Service for Driver App
/// Connects to the central platform's unified chat system via HTTP bridge
class UnifiedDriverChatService {
  static final UnifiedDriverChatService _instance =
      UnifiedDriverChatService._internal();
  factory UnifiedDriverChatService() => _instance;
  UnifiedDriverChatService._internal();

  // Central Platform HTTP Bridge endpoint - use environment configuration
  String get _bridgeEndpoint =>
      Environment.chatBridgeApiUrl; // e.g., https://.../<stage>/api
  static const String _apiKey = 'wizzdriver_mobile_app_v1';

  // Connection state
  Timer? _heartbeatTimer;
  Timer? _statusCheckTimer;
  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  String? _driverId;
  String? _sessionId;
  String? _connectionId;

  // Configuration
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _statusCheckInterval = Duration(seconds: 10);
  static const Duration _reconnectDelay = Duration(seconds: 5);
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

  /// Connect to the unified chat HTTP bridge
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
      debugPrint('🔌 Connecting to chat bridge...');

      // Optional: lightweight ping (ignore status to avoid false negatives)
      try {
        await http.get(
          Uri.parse('$_bridgeEndpoint/ping'),
          headers: {'Content-Type': 'application/json', 'X-API-Key': _apiKey},
        );
      } catch (_) {}

      // Send connection message
      await _sendConnectionMessage();

      // Start periodic status checks and heartbeat
      _startStatusChecking();
      _startHeartbeat();

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _connectionController.add(true);

      debugPrint('✅ Connected to chat bridge');
      return true;
    } catch (error) {
      debugPrint('❌ Failed to connect: $error');
      _isConnecting = false;
      _handleError(error);
      return false;
    }
  }

  /// Send connection message to register as driver
  Future<void> _sendConnectionMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final driverName = prefs.getString('driver_name') ?? 'Driver $_driverId';
    final phoneNumber = prefs.getString('driver_phone');

    // Follow the correct protocol: send chat_driver_connect first
    final connectionMessage = {
      'type': 'chat_driver_connect',
      'driverId': _driverId,
      'driverName': driverName,
      'driverPhone': phoneNumber,
      'businessId': Environment.businessId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _sendMessage(connectionMessage);
    debugPrint('📡 Sent driver connection message');
  }

  /// Start a new chat session
  Future<String?> startChatSession({
    String? topic,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isConnected) {
      debugPrint('❌ Not connected to chat bridge');
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final driverName = prefs.getString('driver_name') ?? 'Driver $_driverId';

    // Use the correct protocol for initializing chat
    final sessionMessage = {
      'type': 'chat_init',
      'driverId': _driverId,
      'driverName': driverName,
      'businessId': Environment.businessId,
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

    final response = await _sendMessage(sessionMessage);
    if (response != null && response['sessionId'] != null) {
      _sessionId = response['sessionId'];
      _sessionController.add({
        'type': 'session_created',
        'sessionId': _sessionId,
        'status': 'active',
      });
    }

    debugPrint('📝 Chat session initialization sent: ${topic ?? "Support"}');
    return _sessionId;
  }

  /// Send a message in the current chat session
  Future<bool> sendChatMessage(String message, {String? sessionId}) async {
    if (!_isConnected) {
      debugPrint('❌ Not connected to chat bridge');
      return false;
    }

    final targetSessionId = sessionId ?? _sessionId;
    final prefs = await SharedPreferences.getInstance();
    final driverName = prefs.getString('driver_name') ?? 'Driver $_driverId';

    final chatMessage = {
      'type': 'chat_message',
      'sessionId': targetSessionId,
      'message': message,
      'messageText': message,
      'senderType': 'driver',
      'senderId': _driverId,
      'senderName': driverName,
      'driverId': _driverId,
      'driverName': driverName,
      'businessId': Environment.businessId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final response = await _sendMessage(chatMessage);
    if (response != null) {
      // Add the message to our own stream for immediate UI update
      _messageController.add({
        'type': 'message_sent',
        'messageText': message,
        'senderType': 'driver',
        'senderName': driverName,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    debugPrint('💬 Message sent: $message');
    return response != null;
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
      'businessId': Environment.businessId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final response = await _sendMessage(statusMessage);
    return response != null;
  }

  /// Send message to HTTP bridge
  Future<Map<String, dynamic>?> _sendMessage(
    Map<String, dynamic> message,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_bridgeEndpoint/chat/send'), // results in /dev/api/chat/send
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': _apiKey,
        },
        body: json.encode(message),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Message sent successfully: ${responseData['messageId']}');
        return responseData;
      } else {
        debugPrint(
          '❌ Failed to send message: ${response.statusCode} ${response.body}',
        );
        return null;
      }
    } catch (error) {
      debugPrint('❌ Error sending message: $error');
      return null;
    }
  }

  /// Start periodic status checking to simulate real-time updates
  void _startStatusChecking() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(_statusCheckInterval, (timer) async {
      if (_isConnected) {
        await _checkForUpdates();
      }
    });
  }

  /// Check for new messages and updates via HTTP polling
  Future<void> _checkForUpdates() async {
    try {
      // Query recent history to detect activity (since /chat/status may not exist)
      final response = await http.get(
        Uri.parse('$_bridgeEndpoint/chat/history?limit=1'),
        headers: {'Content-Type': 'application/json', 'X-API-Key': _apiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        // If sessions exist, fetch messages
        final sessions = data['sessions'] as List<dynamic>?;
        if (sessions != null && sessions.isNotEmpty) {
          await _fetchMessageHistory();
        }
      }
    } catch (error) {
      debugPrint('❌ Error checking for updates: $error');
    }
  }

  /// Fetch message history from bridge
  Future<void> _fetchMessageHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$_bridgeEndpoint/chat/history'),
        headers: {'Content-Type': 'application/json', 'X-API-Key': _apiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final messages = data['messages'] as List<dynamic>? ?? [];

        // Process new messages
        for (final message in messages) {
          if (message is Map<String, dynamic>) {
            _handleIncomingMessage(message);
          }
        }
      }
    } catch (error) {
      debugPrint('❌ Error fetching message history: $error');
    }
  }

  /// Handle incoming messages from bridge
  void _handleIncomingMessage(Map<String, dynamic> message) {
    final messageType = message['type'] as String?;

    debugPrint('📨 Received: $messageType');

    switch (messageType) {
      case 'chat_session_created':
      case 'session_created':
        _sessionId = message['sessionId'] as String?;
        _sessionController.add(message);
        debugPrint('✅ Session created: $_sessionId');
        break;

      case 'chat_message':
      case 'message_received':
      case 'agent_message':
        // Only add if it's from an agent (not our own messages)
        if (message['senderType'] != 'driver' ||
            message['senderId'] != _driverId) {
          _messageController.add(message);
          debugPrint('📨 Message received from agent');
        }
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
        debugPrint('💓 Heartbeat acknowledged');
        break;

      case 'error':
        debugPrint('❌ Server error: ${message['message']}');
        break;

      default:
        debugPrint('🔍 Unknown message type: $messageType');
        _messageController.add(message);
    }
  }

  /// Handle connection errors
  void _handleError(dynamic error) {
    debugPrint('❌ Bridge error: $error');
    _isConnected = false;
    _connectionController.add(false);

    // Only reconnect if we haven't exceeded the limit
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
    } else {
      debugPrint(
        '❌ Max reconnection attempts reached. Please restart manually.',
      );
    }
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    _reconnectAttempts++;

    final delay = Duration(
      seconds: _reconnectDelay.inSeconds * _reconnectAttempts,
    );
    debugPrint(
      '🔄 Reconnecting in ${delay.inSeconds} seconds (attempt $_reconnectAttempts/$_maxReconnectAttempts)',
    );

    Timer(delay, () {
      if (!_isConnected && _reconnectAttempts <= _maxReconnectAttempts) {
        debugPrint('🔄 Attempting reconnection...');
        connect();
      }
    });
  }

  /// Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) async {
      if (_isConnected) {
        await _sendMessage({
          'type': 'heartbeat',
          'driverId': _driverId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('💓 Heartbeat sent');
      }
    });
  }

  /// Stop all timers
  void _stopTimers() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
  }

  /// Disconnect from the chat bridge
  Future<void> disconnect() async {
    _isConnected = false;
    _isConnecting = false;
    _stopTimers();

    _sessionId = null;
    _connectionController.add(false);

    debugPrint('🔌 Disconnected from chat bridge');
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
      'businessId': Environment.businessId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final response = await _sendMessage(closeMessage);

    if (targetSessionId == _sessionId) {
      _sessionId = null;
    }

    return response != null;
  }

  /// Get chat history for a session
  Future<List<Map<String, dynamic>>> getChatHistory([String? sessionId]) async {
    try {
      final response = await http.get(
        Uri.parse('$_bridgeEndpoint/chat/history'),
        headers: {'Content-Type': 'application/json', 'X-API-Key': _apiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final messages = data['messages'] as List<dynamic>? ?? [];
        return messages.cast<Map<String, dynamic>>();
      }
    } catch (error) {
      debugPrint('❌ Error fetching chat history: $error');
    }
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
