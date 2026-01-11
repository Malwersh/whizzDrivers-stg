import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/unified_driver_chat_service.dart';

/// Provider for unified chat service
final unifiedChatServiceProvider = Provider<UnifiedDriverChatService>((ref) {
  return UnifiedDriverChatService();
});

/// Provider for chat connection status
final chatConnectionStatusProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(unifiedChatServiceProvider);
  return service.connectionStream;
});

/// Provider for incoming chat messages
final chatMessagesProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final service = ref.watch(unifiedChatServiceProvider);
  return service.messageStream;
});

/// Provider for session updates
final chatSessionProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final service = ref.watch(unifiedChatServiceProvider);
  return service.sessionStream;
});

/// Provider for chat status updates
final chatStatusProvider = StreamProvider<String>((ref) {
  final service = ref.watch(unifiedChatServiceProvider);
  return service.statusStream;
});
