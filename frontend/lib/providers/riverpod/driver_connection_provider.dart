import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/driver_status.dart';
import '../../services/driver_websocket_service.dart';

/// Provider for driver WebSocket connection service
final driverWebSocketServiceProvider = Provider<DriverWebSocketService>((ref) {
  final service = DriverWebSocketService();
  
  // Dispose service when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// Provider for connection status
final driverConnectionStatusProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(driverWebSocketServiceProvider);
  return service.connectionStream;
});

/// Simple provider for connection status (alias for backward compatibility)
final driverConnectionProvider = driverConnectionStatusProvider;

/// Provider for driver status
final driverStatusProvider = StreamProvider<DriverStatus>((ref) {
  final service = ref.watch(driverWebSocketServiceProvider);
  return service.statusStream;
});

/// Provider for incoming orders
final incomingOrdersProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final service = ref.watch(driverWebSocketServiceProvider);
  return service.orderStream;
});

/// Provider for WebSocket messages
final driverMessagesProvider = StreamProvider<String>((ref) {
  final service = ref.watch(driverWebSocketServiceProvider);
  return service.messageStream;
});

/// Provider for driver location
final driverLocationProvider = Provider<Position?>((ref) {
  final service = ref.watch(driverWebSocketServiceProvider);
  return service.lastKnownLocation;
});

/// Actions provider for WebSocket operations
final driverConnectionActionsProvider = Provider<DriverConnectionActions>((ref) {
  final service = ref.watch(driverWebSocketServiceProvider);
  return DriverConnectionActions(service);
});

/// Actions class for WebSocket operations
class DriverConnectionActions {
  final DriverWebSocketService _service;

  DriverConnectionActions(this._service);

  /// Connect to WebSocket
  Future<bool> connect(String driverId) => _service.connect(driverId);

  /// Disconnect from WebSocket
  Future<void> disconnect() async => _service.disconnect();

  /// Set driver status
  Future<void> setStatus(DriverStatus status) => _service.setStatus(status);
  
  /// Go online
  Future<void> goOnline() => _service.setStatus(DriverStatus.online);
  
  /// Go offline
  Future<void> goOffline() => _service.setStatus(DriverStatus.offline);
  
  /// Accept an order
  Future<void> acceptOrder(String orderId) => _service.acceptOrder(orderId);
  
  /// Reject an order
  Future<void> rejectOrder(String orderId, String reason) => 
      _service.rejectOrder(orderId, reason);
  
  /// Update order status
  Future<void> updateOrderStatus(String orderId, String status, {Map<String, dynamic>? extra}) =>
      _service.updateOrderStatus(orderId, status, extra: extra);
}
