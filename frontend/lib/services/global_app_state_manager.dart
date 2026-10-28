import 'package:flutter/material.dart';
import '../services/websocket_service.dart';

/// Global App State Manager to handle WebSocket persistence across navigation
class GlobalAppStateManager with WidgetsBindingObserver {
  static final GlobalAppStateManager _instance =
      GlobalAppStateManager._internal();
  factory GlobalAppStateManager() => _instance;
  GlobalAppStateManager._internal();

  final WebSocketService _webSocketService = WebSocketService();
  bool _isInitialized = false;

  /// Initialize global app state management
  void initialize() {
    if (_isInitialized) return;

    debugPrint('🌐 Initializing Global App State Manager...');

    // Observe Flutter lifecycle without replacing its platform channel handler.
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null) notifyAppStateChange(state);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    notifyAppStateChange(state);
  }

  /// Call this when navigating between tabs
  void onTabNavigation(String fromTab, String toTab) {
    debugPrint('📋 Tab navigation: $fromTab → $toTab');

    // Maintain persistent WebSocket connection
    _webSocketService.maintainPersistentConnection();

    // Special handling for home tab (where orders are received)
    if (toTab == 'home') {
      debugPrint('🏠 Navigated to home - ensuring WebSocket is active');
      _ensureWebSocketActive();
    }
  }

  /// Ensure WebSocket is active and healthy
  void _ensureWebSocketActive() {
    if (!_webSocketService.isConnected) {
      debugPrint('🔄 WebSocket inactive on home navigation - reconnecting');
      _webSocketService.connect();
    }
  }

  /// Call this when app is backgrounded/foregrounded manually
  void notifyAppStateChange(AppLifecycleState state) {
    debugPrint('📱 Manual app state change: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _webSocketService.notifyAppLifecycleChange(false);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _webSocketService.notifyAppLifecycleChange(true);
        break;
      case AppLifecycleState.detached:
        debugPrint('📱 App detached - WebSocket should persist');
        break;
    }
  }

  /// Get WebSocket service instance
  WebSocketService get webSocketService => _webSocketService;

  /// Dispose resources
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isInitialized = false;
    debugPrint('🗑️ Global App State Manager disposed');
  }
}
