import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simple notification state model
class NotificationState {
  final List<dynamic> pendingNotifications;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.pendingNotifications = const [],
    this.isLoading = false,
    this.error,
  });

  NotificationState copyWith({
    List<dynamic>? pendingNotifications,
    bool? isLoading,
    String? error,
  }) {
    return NotificationState(
      pendingNotifications: pendingNotifications ?? this.pendingNotifications,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Simple notification notifier
class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(const NotificationState());

  void addNotification(dynamic notification) {
    state = state.copyWith(
      pendingNotifications: [...state.pendingNotifications, notification],
    );
  }

  void removeNotification(String id) {
    state = state.copyWith(
      pendingNotifications: state.pendingNotifications
          .where((notification) => notification['id'] != id)
          .toList(),
    );
  }

  void clearNotifications() {
    state = state.copyWith(pendingNotifications: []);
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }
}

// Provider for notifications
final notificationsProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier();
});
