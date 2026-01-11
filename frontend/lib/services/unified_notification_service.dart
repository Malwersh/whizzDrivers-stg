import '../models/order_model.dart';
import 'package:flutter/foundation.dart';

class UnifiedNotificationService {
  static final UnifiedNotificationService _instance =
      UnifiedNotificationService._internal();
  factory UnifiedNotificationService() => _instance;
  UnifiedNotificationService._internal();

  // Internal state restored after cleanup
  String? _driverPhoneNumber;
  String? _driverName;
  bool _isInitialized = false;

  // Expose as read-only getters to avoid unused field warnings
  String? get driverPhoneNumber => _driverPhoneNumber;
  String? get driverName => _driverName;
  bool get isInitialized => _isInitialized;

  // Callbacks
  Function(OrderModel)? onOrderReceived;
  Function(String)? onEmergencyAlert;
  Function(Map<String, dynamic>)? onGeneralNotification;

  Future<void> initialize({
    required String driverPhoneNumber,
    String? driverName,
  }) async {
    _driverPhoneNumber = driverPhoneNumber;
    _driverName = driverName;
    _isInitialized = true; // no-op
    debugPrint('🔔 UnifiedNotificationService initialized (offline no-op)');
  }

  Future<void> dispose() async {
    _isInitialized = false;
  }

  Future<void> subscribeToTopic(String topic) async {}
  Future<void> unsubscribeFromTopic(String topic) async {}

  Future<void> sendOrderNotification({required OrderModel order}) async {}

  Future<void> sendEmergencyAlert({
    required String emergencyType,
    required String location,
    String? additionalInfo,
  }) async {}
}
