
/// Base class for all session states
abstract class SessionState {
  const SessionState();
}

/// Initial session state when app starts
class SessionInitial extends SessionState {
  const SessionInitial();
}

/// Active session with user data and tokens
class SessionActive extends SessionState {
  final Map<String, dynamic> userData;
  final String accessToken;
  final String? idToken;
  final String? refreshToken;
  final DateTime loginTime;
  final String driverId;

  const SessionActive({
    required this.userData,
    required this.accessToken,
    this.idToken,
    this.refreshToken,
    required this.loginTime,
    required this.driverId,
  });

  /// Get driver ID from session
  String get userId => driverId;

  /// Check if session is expired based on token validation
  bool get isExpired {
    // Check if session is older than 24 hours
    final now = DateTime.now();
    final sessionAge = now.difference(loginTime);
    return sessionAge.inHours >= 24;
  }

  /// Get session duration
  Duration get sessionDuration {
    return DateTime.now().difference(loginTime);
  }

  @override
  String toString() => 'SessionActive(driverId: $driverId, loginTime: $loginTime)';
}

/// Session expired state
class SessionExpired extends SessionState {
  final String reason;

  const SessionExpired({this.reason = 'Session expired'});

  @override
  String toString() => 'SessionExpired(reason: $reason)';
}

/// Session error state
class SessionError extends SessionState {
  final String error;
  final String? details;

  const SessionError({
    required this.error,
    this.details,
  });

  @override
  String toString() => 'SessionError(error: $error, details: $details)';
}

/// Session loading state
class SessionLoading extends SessionState {
  final String? message;

  const SessionLoading({this.message});

  @override
  String toString() => 'SessionLoading(message: $message)';
}

/// Session conflict state - another user is already signed in
class SessionConflict extends SessionState {
  final String conflictReason;
  final Map<String, dynamic>? existingUserData;

  const SessionConflict({
    required this.conflictReason,
    this.existingUserData,
  });

  @override
  String toString() => 'SessionConflict(reason: $conflictReason)';
}

/// Unauthenticated session state
class SessionUnauthenticated extends SessionState {
  final String? lastError;

  const SessionUnauthenticated({this.lastError});

  @override
  String toString() => 'SessionUnauthenticated(lastError: $lastError)';
}
