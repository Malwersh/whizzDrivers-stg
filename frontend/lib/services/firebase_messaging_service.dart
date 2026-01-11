import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';

// Stub Firebase Messaging Service (no external Firebase packages)
class FirebaseMessagingService {
  static final FirebaseMessagingService _instance = FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  bool _isInitialized = false;
  String? _fcmToken;

  // Callbacks
  Function(OrderModel)? onOrderReceived;
  Function(String)? onEmergencyAlert;
  Function(Map<String, dynamic>)? onGeneralNotification;

  Future<void> initialize() async {
    try {
      debugPrint('🔥 Initializing Firebase Messaging Service (offline stub)...');
      _fcmToken = 'stub_token_${DateTime.now().millisecondsSinceEpoch}';
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ Failed to initialize Firebase Messaging Service: $e');
      _isInitialized = false;
    }
  }

  bool get isInitialized => _isInitialized;
  String? get fcmToken => _fcmToken;

  Future<String?> getToken() async => _fcmToken;
  Future<void> subscribeToTopic(String topic) async {}
  Future<void> unsubscribeFromTopic(String topic) async {}
}
