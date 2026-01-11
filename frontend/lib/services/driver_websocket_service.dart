import 'dart:async';
import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/environment.dart';
import '../models/driver_status.dart';
import 'aws_dynamodb_service.dart';
import 'logging/auth_logger.dart';

/// WebSocket service for real-time driver connection and order management
class DriverWebSocketService {
  // Removed hardcoded localhost; use Environment.webSocketUrl (unified API Gateway)
  static const String _devFallback = 'ws://localhost:8001/ws';
  String get _baseUrl => Environment.webSocketUrl.isNotEmpty
      ? Environment.webSocketUrl
      : _devFallback;

  // Cache last successful auth token for reconnection
  String? _lastAuthToken;

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _locationUpdateTimer;
  Timer? _reconnectTimer;

  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  DriverStatus _status = DriverStatus.offline;
  Position? _lastKnownLocation;

  // Streams for UI updates
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<DriverStatus> _statusController =
      StreamController<DriverStatus>.broadcast();
  final StreamController<Map<String, dynamic>> _orderController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();

  // Public streams
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<DriverStatus> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get orderStream => _orderController.stream;
  Stream<String> get messageStream => _messageController.stream;

  // Getters
  bool get isConnected => _isConnected;
  DriverStatus get status => _status;
  Position? get lastKnownLocation => _lastKnownLocation;

  AuthLogger? _logger; // optional structured logger
  int _reconnectAttempts = 0;

  void attachLogger(AuthLogger logger) {
    _logger = logger;
  }

  final Set<String> _activeTopics = <String>{};
  final Duration _baseBackoff = const Duration(seconds: 3);
  final Duration _maxBackoff = const Duration(seconds: 60);

  // Public accessor for topics
  Set<String> get activeTopics => Set.unmodifiable(_activeTopics);

  /// Get valid authentication token from Amplify
  Future<String> _getValidAuthToken() async {
    try {
      final authSession = await Amplify.Auth.fetchAuthSession();
      if (authSession is CognitoAuthSession) {
        final token = authSession.userPoolTokensResult.value.idToken.raw;
        debugPrint('🔑 DriverWebSocket: Retrieved fresh Amplify auth token');
        return token;
      }
    } catch (e) {
      debugPrint('⚠️ DriverWebSocket: Failed to get Amplify token: $e');
    }

    // Fallback to stored token
    if (_lastAuthToken != null && _lastAuthToken!.isNotEmpty) {
      debugPrint('🔑 DriverWebSocket: Using stored auth token');
      return _lastAuthToken!;
    }

    throw Exception(
        'No valid authentication token available for driver WebSocket');
  }

  /// Initialize WebSocket connection
  Future<bool> connect(String authToken) async {
    if (_isConnecting || _isConnected) {
      return _isConnected;
    }

    _logger?.logWebSocketEvent(
        event: 'connect_attempt', attempt: _reconnectAttempts + 1);
    try {
      _isConnecting = true;

      // Get valid authentication token - prioritize fresh token from Amplify
      String tokenToUse;
      try {
        tokenToUse = await _getValidAuthToken();
      } catch (e) {
        debugPrint('⚠️ DriverWebSocket: Using provided token as fallback');
        if (authToken.isEmpty) {
          throw Exception('No valid authentication token available');
        }
        tokenToUse = authToken;
      }
      _lastAuthToken = tokenToUse;

      // Get current location
      await _updateLocation();

      // Identify driver for unified websocket connect handler (so it can create a driver connection record)
      final authUser = await Amplify.Auth.getCurrentUser();
      final driverId = authUser.userId;

      // Create WebSocket connection with auth token (JWT) per unified spec
      final wsUrl = Uri.parse(_baseUrl).replace(queryParameters: {
        'token': tokenToUse,
        'userType': 'driver',
        'entityType': 'driver',
        'driverId': driverId,
        'platform': 'flutter_driver_app',
      }).toString();
      print('🚗 DriverWebSocket: Connecting to: $wsUrl');
      _channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        headers: {
          'Authorization': 'Bearer $tokenToUse',
        },
      );

      // Listen to messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );

      // Send initial connection message with location
      await _sendConnectionMessage();

      // Start heartbeat and location updates
      _startHeartbeat();
      _startLocationUpdates();

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0; // reset after success
      _connectionController.add(true);
      _addMessage('✅ Connected to driver dispatch system');
      _logger?.logWebSocketEvent(event: 'connect', success: true);
      // Resubscribe to previous topics
      unawaited(_resubscribeAll());

      return true;
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      _connectionController.add(false);
      _addMessage('❌ Failed to connect: $e');
      _logger?.logWebSocketEvent(
          event: 'connect',
          success: false,
          reason: e.toString(),
          attempt: _reconnectAttempts + 1);
      return false;
    }
  }

  /// Disconnect from WebSocket
  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }

    _stopHeartbeat();
    _stopLocationUpdates();
    _stopReconnectTimer();

    _isConnected = false;
    _isConnecting = false;
    _connectionController.add(false);
    _addMessage('🔌 Disconnected from driver dispatch system');
    _logger?.logWebSocketEvent(event: 'disconnect', reason: 'manual');
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Set driver status (online/offline/busy)
  Future<void> setStatus(DriverStatus newStatus) async {
    if (!_isConnected) {
      _addMessage('❌ Not connected. Cannot change status.');
      return;
    }

    try {
      // Send to WebSocket for real-time updates
      await _sendAction('driver_status_update', payload: {
        'status': newStatus.toString().split('.').last,
        if (_lastKnownLocation != null)
          'driver_location': {
            'latitude': _lastKnownLocation!.latitude,
            'longitude': _lastKnownLocation!.longitude,
          },
      });

      // Update DynamoDB with availability status (separate from registration status)
      final statusString = newStatus.toString().split('.').last;

      final awsService = AWSDynamoDBService();
      final dbUpdateSuccess = await awsService.updateDriverAvailabilityStatus(
        driverId: 'self',
        status: statusString,
      );

      if (dbUpdateSuccess) {
        debugPrint(
          '✅ Driver availability status synced to DynamoDB: $statusString',
        );
      } else {
        debugPrint('⚠️ Failed to sync driver availability status to DynamoDB');
      }

      _status = newStatus;
      _statusController.add(_status);

      // Save status to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_status', newStatus.toString());

      _addMessage('✅ Status updated to: ${_getStatusText(newStatus)}');
    } catch (e) {
      _addMessage('❌ Failed to update status: $e');
    }
  }

  /// Accept an order
  Future<void> acceptOrder(String orderId) async {
    if (!_isConnected) {
      _addMessage('❌ Not connected. Cannot accept order.');
      return;
    }

    try {
      await _sendAction('driver_assignment_response', payload: {
        'order_id': orderId,
        'assignment_id': orderId, // Use orderId as assignmentId for now
        'response': 'accept',
        'estimated_pickup_time':
            DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
        if (_lastKnownLocation != null)
          'driver_location': {
            'latitude': _lastKnownLocation!.latitude,
            'longitude': _lastKnownLocation!.longitude,
          },
      });

      // Change status to busy
      await setStatus(DriverStatus.busy);
      _addMessage('✅ Order $orderId accepted');
    } catch (e) {
      _addMessage('❌ Failed to accept order: $e');
    }
  }

  /// Reject an order
  Future<void> rejectOrder(String orderId, String reason) async {
    if (!_isConnected) {
      return;
    }

    try {
      await _sendAction('driver_assignment_response', payload: {
        'order_id': orderId,
        'assignment_id': orderId, // Use orderId as assignmentId for now
        'response': 'decline',
        'reason': reason,
      });
      _addMessage('↩️ Order $orderId rejected');
    } catch (e) {
      _addMessage('❌ Failed to reject order: $e');
    }
  }

  /// Update order status (picked_up, delivered, etc.)
  Future<void> updateOrderStatus(String orderId, String status,
      {Map<String, dynamic>? extra}) async {
    if (!_isConnected) {
      return;
    }

    try {
      await _sendAction('order_status_update', payload: {
        'order_id': orderId,
        'status': status,
        if (_lastKnownLocation != null)
          'driver_location': {
            'latitude': _lastKnownLocation!.latitude,
            'longitude': _lastKnownLocation!.longitude,
          },
        ...?extra,
      });

      _addMessage('📦 Order $orderId status updated to: $status');
    } catch (e) {
      _addMessage('❌ Failed to update order status: $e');
    }
  }

  /// Send initial connection message
  Future<void> _sendConnectionMessage() async {
    try {
      // Get current user ID from Amplify Auth
      final authUser = await Amplify.Auth.getCurrentUser();
      final driverId = authUser.userId;

      // Send unified connection message for driver presence registration
      await _sendMessage({
        'type': 'driver_connect',
        'driverId': driverId,
        'userId': driverId, // Add userId field for consistency
        'status': 'online',
        'timestamp': DateTime.now().toIso8601String(),
        'entityType': 'driver',
        'userType': 'driver', // Add userType field
        'connectionType': 'driver_presence',
        'platform': 'flutter_driver_app',
        if (_lastKnownLocation != null)
          'driver_location': {
            'latitude': _lastKnownLocation!.latitude,
            'longitude': _lastKnownLocation!.longitude,
          }
      });

      _addMessage('✅ Driver presence registered: $driverId');
    } catch (e) {
      _addMessage('❌ Failed to register driver presence: $e');
      // Fallback: use a temporary ID if auth fails
      await _sendMessage({
        'type': 'driver_connect',
        'driverId': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'userId': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'status': 'online',
        'timestamp': DateTime.now().toIso8601String(),
        'entityType': 'driver',
        'userType': 'driver',
        'connectionType': 'driver_presence',
        'platform': 'flutter_driver_app',
        if (_lastKnownLocation != null)
          'driver_location': {
            'latitude': _lastKnownLocation!.latitude,
            'longitude': _lastKnownLocation!.longitude,
          }
      });
    }
  }

  /// Send status update

  /// Subscribe to a topic (driver:<id>, order:<id>, system:global, etc.)
  Future<void> subscribe(String topic) async {
    if (topic.isEmpty) return;
    _activeTopics.add(topic);
    if (_isConnected) {
      await _sendAction('subscribe', topic: topic);
      _logger?.logWebSocketEvent(
          event: 'subscribe',
          topic: topic,
          activeTopics: _activeTopics.length,
          success: true);
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribe(String topic) async {
    if (topic.isEmpty) return;
    _activeTopics.remove(topic);
    if (_isConnected) {
      await _sendAction('unsubscribe', topic: topic);
      _logger?.logWebSocketEvent(
          event: 'unsubscribe',
          topic: topic,
          activeTopics: _activeTopics.length,
          success: true);
    }
  }

  /// Resubscribe all topics after reconnect
  Future<void> _resubscribeAll() async {
    if (_activeTopics.isEmpty || !_isConnected) return;
    for (final t in _activeTopics) {
      await _sendAction('subscribe', topic: t);
    }
    _logger?.logWebSocketEvent(
        event: 'resubscribe',
        activeTopics: _activeTopics.length,
        success: true);
  }

  /// Send raw message to WebSocket
  Future<void> _sendMessage(Map<String, dynamic> message) async {
    if (_channel != null) {
      final jsonMessage = jsonEncode(message);
      _channel!.sink.add(jsonMessage);
      _addMessage('📤 Sent: $jsonMessage');
    } else {
      _addMessage('⚠️ Cannot send message: WebSocket not connected');
    }
  }

  /// Unified action sender
  Future<void> _sendAction(String action,
      {String? topic, Map<String, dynamic>? payload}) async {
    final envelope = <String, dynamic>{
      'action': action,
      'ts': DateTime.now().toUtc().toIso8601String(),
      if (topic != null) 'topic': topic,
      if (payload != null) 'payload': payload,
    };
    await _sendMessage(envelope);
  }

  /// LEGACY compatibility wrapper for old 'type' messages
  /// Handle incoming messages from the server
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message.toString());
      final action = data['action'];
      final type = data['type']; // legacy fallback

      switch (action ?? type) {
        case 'connection_confirmed':
          _addMessage('✅ Connection confirmed by server');
          break;
        case 'driver_assigned':
        case 'order_assignment':
          _handleDriverAssignment(data);
          break;
        case 'assignment_cancelled':
          _addMessage('❌ Order assignment cancelled: ${data['order_id']}');
          _orderController.add({
            'type': 'assignment_cancelled',
            'order_id': data['order_id'],
            'reason': data['reason'] ?? 'Assignment cancelled',
            'timestamp': DateTime.now().toIso8601String(),
          });
          break;
        case 'order_new':
        case 'new_order':
          _addMessage('🆕 New order received: ${data['order_id']}');
          _orderController.add(data);
          break;
        case 'order_cancel':
        case 'order_cancelled':
          _addMessage('❌ Order cancelled: ${data['order_id']}');
          _orderController.add(data);
          break;
        case 'assignment_response_confirmed':
          _addMessage('✅ Assignment response confirmed: ${data['response']}');
          break;
        case 'status_confirmed':
          _addMessage('✅ Status change confirmed');
          break;
        case 'error':
          _addMessage('❌ Server error: ${data['message']}');
          break;
        case 'ping':
          _sendAction('pong');
          break;
        case 'location_request':
          _updateLocationAndSend();
          break;
        case 'subscribed':
          _addMessage('📡 Subscribed to ${data['topic']}');
          break;
        case 'unsubscribed':
          _addMessage('📴 Unsubscribed from ${data['topic']}');
          break;
        default:
          _addMessage('📨 Unknown message action/type: ${action ?? type}');
      }
    } catch (e) {
      _addMessage('❌ Error processing message: $e');
    }
  }

  /// Handle driver assignment notification
  void _handleDriverAssignment(Map<String, dynamic> data) {
    final orderId = data['order_id'] ?? data['orderId'];
    final assignmentId = data['assignment_id'] ?? data['assignmentId'];

    _addMessage('🎯 Order assignment received: $orderId');

    // Emit order assignment event with all necessary data
    _orderController.add({
      'type': 'driver_assigned',
      'action': 'driver_assigned',
      'order_id': orderId,
      'assignment_id': assignmentId,
      'order_details': data['order_details'] ?? data,
      'timeout': data['timeout'] ?? 30,
      'customer_name': data['customer_name'] ?? data['customerName'],
      'restaurant_name': data['restaurant_name'] ?? data['restaurantName'],
      'delivery_address': data['delivery_address'] ?? data['deliveryAddress'],
      'total_amount':
          data['total_amount'] ?? data['totalAmount'] ?? data['total'],
      'estimated_distance':
          data['estimated_distance'] ?? data['estimatedDistance'],
      'pickup_location': data['pickup_location'] ?? data['pickupLocation'],
      'delivery_location':
          data['delivery_location'] ?? data['deliveryLocation'],
      'notes': data['notes'],
      'estimated_pickup_time':
          data['estimated_pickup_time'] ?? data['estimatedPickupTime'],
      'priority': data['priority'] ?? 1,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Handle WebSocket errors
  void _handleError(error) {
    _isConnected = false;
    _connectionController.add(false);
    _addMessage('❌ WebSocket error: $error');
    _logger?.logWebSocketEvent(event: 'error', reason: error.toString());
    _scheduleReconnection();
  }

  /// Handle WebSocket disconnection
  void _handleDisconnection() {
    _isConnected = false;
    _status = DriverStatus.offline;

    _connectionController.add(false);
    _statusController.add(_status);
    _addMessage('📴 WebSocket disconnected');
    _logger?.logWebSocketEvent(event: 'disconnect', reason: 'socket_closed');

    // Cancel timers
    _heartbeatTimer?.cancel();
    _locationUpdateTimer?.cancel();

    // Schedule reconnection if we were previously connected
    _scheduleReconnection();
  }

  /// Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected) {
        _sendMessage({
          'type': 'heartbeat',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  /// Start periodic location updates
  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (_isConnected && _status == DriverStatus.online) {
        _updateLocationAndSend();
      }
    });
  }

  /// Update current location
  Future<void> _updateLocation() async {
    try {
      if (Environment.useTestLocation) {
        _lastKnownLocation = Position(
          latitude: Environment.testLatitude,
          longitude: Environment.testLongitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        return;
      }
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _addMessage('⚠️ Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _addMessage('⚠️ Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _addMessage('⚠️ Location permissions are permanently denied');
        return;
      }

      _lastKnownLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      _addMessage('⚠️ Failed to get location: $e');
    }
  }

  /// Update location and send to server
  Future<void> _updateLocationAndSend() async {
    await _updateLocation();
    if (_lastKnownLocation != null && _isConnected) {
      await _sendMessage({
        'type': 'location_update',
        'latitude': _lastKnownLocation!.latitude,
        'longitude': _lastKnownLocation!.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Schedule reconnection attempt
  void _scheduleReconnection() {
    _reconnectTimer?.cancel();
    final attempt = _reconnectAttempts + 1;
    // exponential backoff with jitter (simple)
    int backoffMs = (_baseBackoff.inMilliseconds * (1 << (attempt - 1)));
    if (backoffMs > _maxBackoff.inMilliseconds)
      backoffMs = _maxBackoff.inMilliseconds;
    // jitter +/-20%
    final jitter = (backoffMs * 0.2).toInt();
    backoffMs =
        backoffMs + (DateTime.now().millisecond % (2 * jitter)) - jitter;
    final delay = Duration(
        milliseconds: backoffMs.clamp(1000, _maxBackoff.inMilliseconds));
    _logger?.logWebSocketEvent(
        event: 'reconnect_schedule',
        attempt: attempt,
        reason: 'after_disconnect');
    _reconnectTimer = Timer(delay, () {
      if (!_isConnected && _lastAuthToken != null) {
        _reconnectAttempts += 1;
        _addMessage(
            '🔄 Attempting to reconnect (attempt $_reconnectAttempts)...');
        connect(_lastAuthToken!);
      }
    });
  }

  /// Add message to stream
  void _addMessage(String message) {
    debugPrint('🚗 DriverWebSocket: $message');
    _messageController.add(message);
  }

  /// Get localized status text
  String _getStatusText(DriverStatus status) {
    switch (status) {
      case DriverStatus.online:
        return 'متاح';
      case DriverStatus.busy:
        return 'مشغول';
      case DriverStatus.offline:
        return 'غير متاح';
      case DriverStatus.onDuty:
        return 'مناوب';
    }
  }

  /// Dispose resources
  void dispose() {
    _heartbeatTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _reconnectTimer?.cancel();

    _connectionController.close();
    _statusController.close();
    _orderController.close();
    _messageController.close();

    _channel?.sink.close();
  }
}
