// Centralized resend / throttle logic for verification codes (email & phone)
// Provides Riverpod Notifier to manage cooldowns per identity (normalized email/phone)

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/logging/auth_logger.dart';

/// Configuration constants (could be externalized later)
class VerificationThrottleConfig {
  static const int defaultCooldownSeconds = 60; // base cooldown
  static const int maxCooldownSeconds = 300; // cap
  static const int penaltyIncrementSeconds = 30; // added per rapid resend
  static const int windowForPenaltySeconds = 300; // look-back window
  static const int maxAttemptsInWindow = 5; // after this, escalate
}

class VerificationIdentityState {
  final String identity; // normalized (lowercased email or E.164 phone)
  final int cooldownRemaining; // seconds
  final DateTime? lastSentAt;
  final List<DateTime> recentSends; // timestamps within window
  final int currentCooldownDuration; // active cooldown duration applied when started
  final bool isSending;
  final String? error;

  const VerificationIdentityState({
    required this.identity,
    this.cooldownRemaining = 0,
    this.lastSentAt,
    this.recentSends = const [],
    this.currentCooldownDuration = VerificationThrottleConfig.defaultCooldownSeconds,
    this.isSending = false,
    this.error,
  });

  VerificationIdentityState copyWith({
    int? cooldownRemaining,
    DateTime? lastSentAt,
    List<DateTime>? recentSends,
    int? currentCooldownDuration,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) => VerificationIdentityState(
        identity: identity,
        cooldownRemaining: cooldownRemaining ?? this.cooldownRemaining,
        lastSentAt: lastSentAt ?? this.lastSentAt,
        recentSends: recentSends ?? this.recentSends,
        currentCooldownDuration: currentCooldownDuration ?? this.currentCooldownDuration,
        isSending: isSending ?? this.isSending,
        error: clearError ? null : error ?? this.error,
      );
}

class VerificationThrottleState {
  final Map<String, VerificationIdentityState> identities; // key = identity
  const VerificationThrottleState({this.identities = const {}});

  VerificationThrottleState copyWith({Map<String, VerificationIdentityState>? identities}) =>
      VerificationThrottleState(identities: identities ?? this.identities);

  VerificationIdentityState identityState(String id) => identities[id] ?? VerificationIdentityState(identity: id);
}

class VerificationThrottleNotifier extends StateNotifier<VerificationThrottleState> {
  // Optional logger injection (late-bound via ref override) to avoid tight coupling
  AuthLogger? logger;
  Timer? _ticker;

  VerificationThrottleNotifier() : super(const VerificationThrottleState()) {
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // Allow external to supply logger after creation (since we are inside provider)
  void attachLogger(AuthLogger l) {
    logger = l;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final updated = <String, VerificationIdentityState>{};
      bool changed = false;
      for (final entry in state.identities.entries) {
        final s = entry.value;
        if (s.cooldownRemaining > 0) {
          final next = s.copyWith(cooldownRemaining: s.cooldownRemaining - 1);
          updated[entry.key] = next;
          changed = true;
        } else {
          updated[entry.key] = s;
        }
      }
      if (changed) {
        state = state.copyWith(identities: updated);
      }
    });
  }

  VerificationIdentityState getIdentity(String identity) => state.identityState(identity);

  bool canSend(String identity) => getIdentity(identity).cooldownRemaining == 0 && !getIdentity(identity).isSending;

  /// Record a successful send and compute next cooldown
  void recordSend(String identity) {
    final current = getIdentity(identity);
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(seconds: VerificationThrottleConfig.windowForPenaltySeconds));
    final filtered = [
      ...current.recentSends.where((t) => t.isAfter(windowStart)),
      now,
    ];

    int dynamicCooldown = VerificationThrottleConfig.defaultCooldownSeconds;
    if (filtered.length > VerificationThrottleConfig.maxAttemptsInWindow) {
      final penaltyMultiplier = filtered.length - VerificationThrottleConfig.maxAttemptsInWindow;
      dynamicCooldown += penaltyMultiplier * VerificationThrottleConfig.penaltyIncrementSeconds;
      // Log penalty escalation exactly when we add penalty
      logger?.logThrottlePenalty(
        identity: identity,
        channel: identity.contains('@') ? 'email' : 'phone',
        penaltyLevel: penaltyMultiplier,
        enforcedCooldownSeconds: dynamicCooldown,
      );
    }
    if (dynamicCooldown > VerificationThrottleConfig.maxCooldownSeconds) {
      dynamicCooldown = VerificationThrottleConfig.maxCooldownSeconds;
    }

    final newState = current.copyWith(
      lastSentAt: now,
      recentSends: filtered,
      cooldownRemaining: dynamicCooldown,
      currentCooldownDuration: dynamicCooldown,
      isSending: false,
      clearError: true,
    );

    state = state.copyWith(
      identities: Map<String, VerificationIdentityState>.from(state.identities)
        ..[identity] = newState,
    );
  }

  void setSending(String identity, bool sending) {
    final current = getIdentity(identity);
    final newState = current.copyWith(isSending: sending);
    state = state.copyWith(
      identities: Map<String, VerificationIdentityState>.from(state.identities)
        ..[identity] = newState,
    );
  }

  void setError(String identity, String error) {
    final current = getIdentity(identity);
    final newState = current.copyWith(error: error, isSending: false);
    state = state.copyWith(
      identities: Map<String, VerificationIdentityState>.from(state.identities)
        ..[identity] = newState,
    );
  }

  void clear(String identity) {
    final newMap = {...state.identities}..remove(identity);
    state = state.copyWith(identities: newMap);
  }
}

// Provider definition
final verificationThrottleProvider = StateNotifierProvider<VerificationThrottleNotifier, VerificationThrottleState>((ref) {
  return VerificationThrottleNotifier();
});
