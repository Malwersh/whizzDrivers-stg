import 'dart:async';
import 'package:flutter/foundation.dart';
import 'websocket_service.dart';

/// Service to handle cross-app communication using the merchant app's WebSocket infrastructure
/// Uses AWS API Gateway WebSocket: wss://<api-id>.execute-api.<region>.amazonaws.com/<stage>
class EcosystemCommunicationService extends ChangeNotifier {
  static final EcosystemCommunicationService _instance = 
      EcosystemCommunicationService._internal();
  factory EcosystemCommunicationService() => _instance;
  EcosystemCommunicationService._internal();

  final WebSocketService _webSocketService = WebSocketService();
  
  // Communication callbacks for cross-app messaging
  Function(Map<String, dynamic>)? onNewOrderFromPlatform;
  Function(String, String)? onMessageFromMerchant;
  Function(String, String)? onMessageFromCustomer;
  Function(String)? onOrderCancelledByCustomer;
  Function(String)? onOrderCancelledByMerchant;
  Function(Map<String, dynamic>)? onPlatformNotification;

  /// Initialize ecosystem communication using shared WebSocket infrastructure
  Future<void> initialize({
    required String driverId,
    required String authToken,
  }) async {
    // driverId is passed to the underlying WebSocket service; no local field needed
    
    // Initialize WebSocket service with shared merchant app infrastructure
    await _webSocketService.initialize(
      driverId: driverId,
      authToken: authToken,
    );

    // Set up cross-app message handlers
    _setupEcosystemHandlers();
    
    debugPrint('✅ Ecosystem Communication Service initialized with merchant app WebSocket');
  }

  /// Set up message handlers for cross-app communication
  void _setupEcosystemHandlers() {
    // Order lifecycle events
    _webSocketService.subscribe(MessageType.newOrderAssignment, (message) {
      _handleNewOrderAssignment(message);
    });

    _webSocketService.subscribe(MessageType.merchantAccepted, (message) {
      _handleMerchantAccepted(message);
    });

    _webSocketService.subscribe(MessageType.orderCreated, (message) {
      _handleOrderCreated(message);
    });

    // Communication from other apps
    _webSocketService.subscribe(MessageType.merchantMessage, (message) {
      _handleMerchantMessage(message);
    });

    _webSocketService.subscribe(MessageType.customerMessage, (message) {
      _handleCustomerMessage(message);
    });

    _webSocketService.subscribe(MessageType.platformMessage, (message) {
      _handlePlatformMessage(message);
    });

    // State synchronization
    _webSocketService.subscribe(MessageType.orderStatusUpdate, (message) {
      _handleOrderStatusSync(message);
    });
  }

  /// Handle new order assignment from platform
  void _handleNewOrderAssignment(WebSocketMessage message) {
    try {
      final orderData = message.data['order'];
      if (orderData != null) {
        // final order = OrderModel.fromJson(orderData);
        // _activeOrders[order.id] = order;
        // _orderStates[order.id] = 'assigned';
        
        debugPrint('📦 New order assigned: $orderData');
        onNewOrderFromPlatform?.call(orderData);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error handling new order assignment: $e');
    }
  }

  /// Handle merchant acceptance notification
  void _handleMerchantAccepted(WebSocketMessage message) {
    final orderId = message.data['order_id'];
    final merchantInfo = message.data['merchant_info'];
    
    if (orderId != null) {
      // _orderStates[orderId] = 'merchant_accepted';
      debugPrint('🏪 Merchant accepted order: $orderId');
      
      // Update order with merchant info if available
      if (merchantInfo != null) {
        // Update order object with merchant details
      }
      
      notifyListeners();
    }
  }

  /// Handle new order notification (for drivers to see available orders)
  void _handleOrderCreated(WebSocketMessage message) {
    final orderData = message.data['order'];
    if (orderData != null) {
      // final order = OrderModel.fromJson(orderData);
      debugPrint('🆕 New order available: $orderData');
      // This could trigger UI to show available orders in the area
    }
  }

  /// Handle message from merchant
  void _handleMerchantMessage(WebSocketMessage message) {
    final orderId = message.data['order_id'];
    final messageText = message.data['message'];
    
    if (orderId != null && messageText != null) {
      debugPrint('🏪💬 Merchant message for order $orderId: $messageText');
      onMessageFromMerchant?.call(orderId, messageText);
    }
  }

  /// Handle message from customer
  void _handleCustomerMessage(WebSocketMessage message) {
    final orderId = message.data['order_id'];
    final messageText = message.data['message'];
    
    if (orderId != null && messageText != null) {
      debugPrint('👤💬 Customer message for order $orderId: $messageText');
      onMessageFromCustomer?.call(orderId, messageText);
    }
  }

  /// Handle message from platform
  void _handlePlatformMessage(WebSocketMessage message) {
    final messageText = message.data['message'];
    if (messageText != null) {
      debugPrint('🏢💬 Platform message: $messageText');
      // onPlatformMessage?.call(messageText);
    }
  }

  /// Handle order status synchronization
  void _handleOrderStatusSync(WebSocketMessage message) {
    final orderId = message.data['order_id'];
    final status = message.data['status'];
    
    if (orderId != null && status != null) {
      // _orderStates[orderId] = status;
      // final order = _activeOrders[orderId]!;
      // Update order status and notify listeners
      // onOrderStateChanged?.call(order);
      notifyListeners();
    }
  }

  /// Driver accepts an order - notify all ecosystem apps
  Future<void> acceptOrder(String orderId) async {
    // if (!_activeOrders.containsKey(orderId)) return;

    try {
      _webSocketService.sendMessage(
        WebSocketMessage(
          type: MessageType.orderAccepted,
          data: {
            'order_id': orderId,
            'driver_id': _webSocketService.driverId,
            'timestamp': DateTime.now().toIso8601String(),
            'location': {
              // Add current driver location
            },
          },
        ),
      );

      // _orderStates[orderId] = 'driver_accepted';
      debugPrint('✅ Order accepted: $orderId');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to accept order: $e');
    }
  }

  /// Driver picks up order - notify customer and merchant
  Future<void> pickupOrder(String orderId) async {
    // if (!_activeOrders.containsKey(orderId)) return;

    try {
      _webSocketService.sendMessage(
        WebSocketMessage(
          type: MessageType.orderPickedUp,
          data: {
            'order_id': orderId,
            'driver_id': _webSocketService.driverId,
            'timestamp': DateTime.now().toIso8601String(),
            'pickup_location': {
              // Add merchant location
            },
          },
        ),
      );

      // _orderStates[orderId] = 'picked_up';
      debugPrint('📦 Order picked up: $orderId');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to update pickup status: $e');
    }
  }

  /// Driver delivers order - notify customer and platform
  Future<void> deliverOrder(String orderId) async {
    // if (!_activeOrders.containsKey(orderId)) return;

    try {
      _webSocketService.sendMessage(
        WebSocketMessage(
          type: MessageType.orderDelivered,
          data: {
            'order_id': orderId,
            'driver_id': _webSocketService.driverId,
            'timestamp': DateTime.now().toIso8601String(),
            'delivery_location': {
              // Add customer location
            },
          },
        ),
      );

      // _orderStates[orderId] = 'delivered';
      // _activeOrders.remove(orderId);
      // _orderStates.remove(orderId);
      
      debugPrint('🎉 Order delivered: $orderId');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to update delivery status: $e');
    }
  }

  /// Send message to customer
  Future<void> sendMessageToCustomer(String orderId, String message) async {
    try {
      _webSocketService.sendMessage(
        WebSocketMessage(
          type: MessageType.driverMessage,
          data: {
            'order_id': orderId,
            'target': 'customer',
            'message': message,
            'driver_id': _webSocketService.driverId,
            'timestamp': DateTime.now().toIso8601String(),
          },
        ),
      );

      debugPrint('💬 Message sent to customer for order $orderId');
    } catch (e) {
      debugPrint('❌ Failed to send message to customer: $e');
    }
  }

  /// Send message to merchant
  Future<void> sendMessageToMerchant(String orderId, String message) async {
    try {
      _webSocketService.sendMessage(
        WebSocketMessage(
          type: MessageType.driverMessage,
          data: {
            'order_id': orderId,
            'target': 'merchant', 
            'message': message,
            'driver_id': _webSocketService.driverId,
            'timestamp': DateTime.now().toIso8601String(),
          },
        ),
      );

      debugPrint('💬 Message sent to merchant for order $orderId');
    } catch (e) {
      debugPrint('❌ Failed to send message to merchant: $e');
    }
  }

  /// Send location update to all relevant apps
  Future<void> updateLocation(double latitude, double longitude) async {
    try {
      _webSocketService.sendMessage(
        WebSocketMessage(
          type: MessageType.deliveryTracking,
          data: {
            'driver_id': _webSocketService.driverId,
            'latitude': latitude,
            'longitude': longitude,
            'timestamp': DateTime.now().toIso8601String(),
            // 'active_orders': _activeOrders.keys.toList(),
          },
        ),
      );

      debugPrint('📍 Location updated and sent to ecosystem');
    } catch (e) {
      debugPrint('❌ Failed to send location update: $e');
    }
  }

  /// Get order state
  // String? getOrderState(String orderId) => _orderStates[orderId];

  /// Dispose resources
  @override
  void dispose() {
    // _activeOrders.clear();
    // _orderStates.clear();
    super.dispose();
  }
}
