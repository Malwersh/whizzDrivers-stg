import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/batched_order_model.dart';
import '../models/driver_status.dart';
import '../models/order_model.dart';
import 'api_service.dart';
import 'audio_notification_service.dart';
import 'driver_websocket_service.dart';
import 'firebase_messaging_service.dart';
import 'unified_notification_service.dart';

/// Real-time order notification service for drivers
/// Uses Firebase for all SMS notifications (AWS SNS removed)
class OrderNotificationService {
  static final OrderNotificationService _instance =
      OrderNotificationService._internal();
  factory OrderNotificationService() => _instance;
  OrderNotificationService._internal();

  // Dependencies
  final DriverWebSocketService _webSocketService = DriverWebSocketService();
  final UnifiedNotificationService _unifiedNotificationService =
      UnifiedNotificationService();
  final AudioNotificationService _audioService = AudioNotificationService();
  final FirebaseMessagingService _firebaseService = FirebaseMessagingService();

  // State management
  bool _isInitialized = false;
  bool _isListening = false;
  String? _driverId;
  String? _driverToken;
  Position? _currentLocation;

  // Notification streams
  final StreamController<OrderModel> _singleOrderController =
      StreamController<OrderModel>.broadcast();
  final StreamController<BatchedOrderNotification> _batchedOrderController =
      StreamController<BatchedOrderNotification>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _errorController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Public streams
  Stream<OrderModel> get singleOrderStream => _singleOrderController.stream;
  Stream<BatchedOrderNotification> get batchedOrderStream =>
      _batchedOrderController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get errorStream => _errorController.stream;

  // Subscription management
  StreamSubscription? _webSocketSubscription;
  StreamSubscription? _locationSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  // Configuration
  static const Duration _reconnectInterval = Duration(seconds: 30);
  static const Duration _heartbeatInterval = Duration(seconds: 60);
  static const double _locationUpdateThreshold = 50.0; // meters

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String? get driverId => _driverId;

  /// Initialize the order notification service
  Future<bool> initialize({
    required String driverId,
    required String driverToken,
    required String driverPhone,
    String? driverName,
  }) async {
    try {
      _driverId = driverId;
      _driverToken = driverToken;

      // Initialize API service with auth token
      ApiService.setAuthToken(driverToken);

      // Initialize unified notification service
      await _unifiedNotificationService.initialize(
        driverPhoneNumber: driverPhone,
        driverName: driverName,
      );

      // Initialize Firebase messaging for push notifications
      await _firebaseService.initialize();
      await _firebaseService.subscribeToTopic('driver_notifications');

      // Initialize audio notification service
      await _audioService.initialize();

      // Get current location
      await _updateCurrentLocation();

      _isInitialized = true;
      _addStatus('Order notification service initialized successfully');

      debugPrint(
        '🔔 OrderNotificationService initialized for driver: $driverId',
      );
      return true;
    } catch (e) {
      _addError('Failed to initialize order notification service', e);
      return false;
    }
  }

  /// Start listening for order notifications
  Future<bool> startListening() async {
    if (!_isInitialized) {
      _addError('Service not initialized', 'Call initialize() first');
      return false;
    }

    if (_isListening) {
      debugPrint('🔔 Already listening for order notifications');
      return true;
    }

    try {
      // Connect to WebSocket for real-time notifications
      final connected = await _webSocketService.connect(_driverToken!);
      if (!connected) {
        throw Exception('Failed to connect to WebSocket service');
      }

      // Subscribe to WebSocket order stream
      _webSocketSubscription = _webSocketService.orderStream.listen(
        _handleWebSocketOrder,
        onError: _handleWebSocketError,
      );

      // Subscribe to driver status updates and order topics
      await _webSocketService.setStatus(DriverStatus.online);
      await _webSocketService.subscribe('orders.new.$_driverId');
      await _webSocketService.subscribe('orders.batch.$_driverId');

      // Start location updates
      _startLocationUpdates();

      // Start heartbeat timer
      _startHeartbeat();

      _isListening = true;
      _addStatus('Started listening for order notifications');

      debugPrint('🔔 OrderNotificationService started listening');
      return true;
    } catch (e) {
      _addError('Failed to start listening for notifications', e);
      return false;
    }
  }

  /// Stop listening for order notifications
  Future<void> stopListening() async {
    try {
      _isListening = false;

      // Cancel subscriptions
      await _webSocketSubscription?.cancel();
      _webSocketSubscription = null;

      await _locationSubscription?.cancel();
      _locationSubscription = null;

      // Cancel timers
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;

      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      // Unsubscribe from WebSocket topics
      if (_driverId != null) {
        await _webSocketService.unsubscribe('orders.new.$_driverId');
        await _webSocketService.unsubscribe('orders.batch.$_driverId');
        await _webSocketService.setStatus(DriverStatus.offline);
      }

      // Disconnect WebSocket
      _webSocketService.disconnect();

      _addStatus('Stopped listening for order notifications');
      debugPrint('🔔 OrderNotificationService stopped listening');
    } catch (e) {
      _addError('Error stopping notification service', e);
    }
  }

  /// Accept a single order
  Future<bool> acceptOrder(String orderId) async {
    try {
      // Use existing WebSocket service method
      await _webSocketService.acceptOrder(orderId);

      // Also send via REST API as backup
      final response = await ApiService.acceptOrder(orderId);

      _addStatus('Order $orderId accepted successfully');
      return response['success'] == true;
    } catch (e) {
      _addError('Failed to accept order $orderId', e);
      return false;
    }
  }

  /// Accept a batched order
  Future<bool> acceptBatchedOrder(String batchId) async {
    try {
      // For batched orders, we'll update the order status for all orders in the batch
      // This is a simplified approach - in production you might want batch-specific handling
      await _webSocketService.updateOrderStatus(batchId, 'accepted');

      // Also send via REST API as backup
      final response = await ApiService.acceptBatchedOrder(batchId);

      _addStatus('Batched order $batchId accepted successfully');
      return response['success'] == true;
    } catch (e) {
      _addError('Failed to accept batched order $batchId', e);
      return false;
    }
  }

  /// Reject an order
  Future<bool> rejectOrder(String orderId, {String? reason}) async {
    try {
      // Use existing WebSocket service method
      await _webSocketService.rejectOrder(
        orderId,
        reason ?? 'declined_by_driver',
      );

      // Also send via REST API as backup
      final response = await ApiService.rejectOrder(orderId, reason: reason);

      _addStatus('Order $orderId rejected');
      return response['success'] == true;
    } catch (e) {
      _addError('Failed to reject order $orderId', e);
      return false;
    }
  }

  /// Handle incoming WebSocket order notification
  void _handleWebSocketOrder(Map<String, dynamic> data) {
    try {
      final messageType = data['action'] as String? ?? data['type'] as String?;

      switch (messageType) {
        case 'new_order':
        case 'order_new':
          _handleSingleOrder(data['payload'] ?? data);
          break;
        case 'batched_order':
        case 'batch_order':
          _handleBatchedOrder(data['payload'] ?? data);
          break;
        case 'order_update':
        case 'order_status_update':
          _handleOrderUpdate(data['payload'] ?? data);
          break;
        case 'order_cancelled':
        case 'order_cancel':
          _handleOrderCancellation(data['payload'] ?? data);
          break;
        default:
          debugPrint('🔔 Unknown order message type: $messageType');
      }
    } catch (e) {
      _addError('Error handling WebSocket order', e);
    }
  }

  /// Handle single order notification
  void _handleSingleOrder(Map<String, dynamic> orderData) {
    try {
      final order = OrderModel.fromJson(orderData);

      // Play notification sound using existing method
      _audioService.playNewOrderSound();

      // Send SMS notification if enabled
      _sendSmsNotification(order);

      // Emit to stream
      _singleOrderController.add(order);

      _addStatus('New order received: ${order.id}');
      debugPrint(
        '🔔 New order notification: ${order.restaurantName} → ${order.customerName}',
      );
    } catch (e) {
      _addError('Error processing single order notification', e);
    }
  }

  /// Handle batched order notification
  void _handleBatchedOrder(Map<String, dynamic> batchData) {
    try {
      final batchedOrder = BatchedOrderNotification.fromJson(batchData);

      // Play urgent sound for batch orders
      _audioService.playUrgentOrderSound();

      // Send SMS notification for batch
      _sendBatchSmsNotification(batchedOrder);

      // Emit to stream
      _batchedOrderController.add(batchedOrder);

      _addStatus('New batched order received: ${batchedOrder.batchId}');
      debugPrint('🔔 New batched order: ${batchedOrder.orders.length} orders');
    } catch (e) {
      _addError('Error processing batched order notification', e);
    }
  }

  /// Handle order update notification
  void _handleOrderUpdate(Map<String, dynamic> updateData) {
    try {
      final orderId = updateData['order_id'] as String;
      final status = updateData['status'] as String;

      _addStatus('Order $orderId updated: $status');
      debugPrint('🔔 Order update: $orderId → $status');
    } catch (e) {
      _addError('Error processing order update', e);
    }
  }

  /// Handle order cancellation notification
  void _handleOrderCancellation(Map<String, dynamic> cancelData) {
    try {
      final orderId = cancelData['order_id'] as String;
      final reason = cancelData['reason'] as String?;

      // Play rejection sound for cancelled orders
      _audioService.playOrderRejectedSound();

      _addStatus(
        'Order $orderId cancelled${reason != null ? ': $reason' : ''}',
      );
      debugPrint('🔔 Order cancelled: $orderId');
    } catch (e) {
      _addError('Error processing order cancellation', e);
    }
  }

  /// Handle WebSocket errors
  void _handleWebSocketError(dynamic error) {
    _addError('WebSocket error', error);

    // Attempt to reconnect
    _scheduleReconnect();
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive == true) return;

    _reconnectTimer = Timer(_reconnectInterval, () async {
      if (_isListening && !_webSocketService.isConnected) {
        debugPrint('🔔 Attempting to reconnect...');
        await startListening();
      }
    });
  }

  /// Start location updates
  void _startLocationUpdates() {
    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((position) {
          if (_currentLocation == null ||
              Geolocator.distanceBetween(
                    _currentLocation!.latitude,
                    _currentLocation!.longitude,
                    position.latitude,
                    position.longitude,
                  ) >
                  _locationUpdateThreshold) {
            _currentLocation = position;
            _updateDriverLocation(position);
          }
        });
  }

  /// Update driver location via WebSocket
  Future<void> _updateDriverLocation(Position position) async {
    try {
      // Use the WebSocket service's existing location update method if available
      // For now, we'll update the order status which also sends location
      await _webSocketService.updateOrderStatus(
        'location_update',
        'driver_available',
        extra: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
        },
      );
    } catch (e) {
      debugPrint('🔔 Failed to update driver location: $e');
    }
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) async {
      try {
        // Use status update as heartbeat
        if (_driverId != null) {
          await _webSocketService.setStatus(DriverStatus.online);
        }
      } catch (e) {
        debugPrint('🔔 Heartbeat failed: $e');
      }
    });
  }

  /// Get current location
  Future<void> _updateCurrentLocation() async {
    try {
      _currentLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('🔔 Failed to get current location: $e');
    }
  }

  /// Send SMS notification for single order (Firebase-based)
  /// Note: For order notifications, push notifications are preferred over SMS
  Future<void> _sendSmsNotification(OrderModel order) async {
    try {
      // SMS notifications for orders are now disabled in favor of push notifications
      // If SMS is still needed, implement using FirebasePhoneAuthService for verification purposes only
      debugPrint(
        '🔔 SMS order notifications disabled - using push notifications instead',
      );
    } catch (e) {
      debugPrint('🔔 Failed to process order notification: $e');
    }
  }

  /// Send SMS notification for batched order (Firebase-based)
  /// Note: For order notifications, push notifications are preferred over SMS
  Future<void> _sendBatchSmsNotification(BatchedOrderNotification batch) async {
    try {
      // SMS notifications for orders are now disabled in favor of push notifications
      // If SMS is still needed, implement using FirebasePhoneAuthService for verification purposes only
      debugPrint(
        '🔔 SMS batch notifications disabled - using push notifications instead',
      );
    } catch (e) {
      debugPrint('🔔 Failed to process batch notification: $e');
    }
  }

  /// Add status message
  void _addStatus(String message) {
    _statusController.add(message);
  }

  /// Add error message
  void _addError(String message, dynamic error) {
    final errorData = {
      'message': message,
      'error': error.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    _errorController.add(errorData);
    debugPrint('🔔 Error: $message - $error');
  }

  /// Dispose of the service
  Future<void> dispose() async {
    await stopListening();

    await _singleOrderController.close();
    await _batchedOrderController.close();
    await _statusController.close();
    await _errorController.close();

    _isInitialized = false;
    debugPrint('🔔 OrderNotificationService disposed');
  }
}
