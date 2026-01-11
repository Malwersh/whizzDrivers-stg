// filepath: lib/services/logging/auth_logger.dart
// Structured, PII-safe authentication & verification logging utility.
// Phase 1 foundation: JSON events -> debugPrint sink. Future extension: remote transport.

import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import '../../features/authentication/utils/identity_normalizer.dart';
import '../../config/environment.dart';

/// Simple pluggable sink so we can later forward to CloudWatch / Firehose etc.
abstract class LogSink {
  void emit(Map<String, dynamic> event);
}

class DebugPrintSink implements LogSink {
  @override
  void emit(Map<String, dynamic> event) {
    debugPrint('[AUTH_LOG] ${jsonEncode(event)}');
  }
}

/// Centralized auth & verification logger (no raw PII)
class AuthLogger {
  AuthLogger({LogSink? sink}) : _sink = sink ?? DebugPrintSink();

  final LogSink _sink;

  // Common envelope builder
  Map<String, dynamic> _base(String event) => {
        'ts': DateTime.now().toUtc().toIso8601String(),
        'cat': 'auth',
        'event': event,
        'env': AppConfig.environment,
        'aws': AppConfig.enableAWSIntegration,
        'appMode': AppConfig.forceProductionMode ? 'forcedProd' : 'normal',
        'ws': Environment.webSocketUrl,
        'ver': _appVersion, // placeholder if versioning added later
      };

  static const String _appVersion = '0.0.0'; // TODO: inject real build/version

  void logAppStart() {
    final data = _base('app_start')
      ..addAll({
        'config': AppConfig.awsConfig,
      });
    _sink.emit(data);
  }

  void logLoginAttempt({required String identity, required String channel}) {
    final data = _base('login_attempt')
      ..addAll({
        'identityHash': IdentityNormalizer.hashIdentity(identity),
        'channel': channel,
      });
    _sink.emit(data);
  }

  void logLoginResult({
    required String identity,
    required String channel,
    required bool success,
    String? failureReason,
  }) {
    final data = _base('login_result')
      ..addAll({
        'identityHash': IdentityNormalizer.hashIdentity(identity),
        'channel': channel,
        'success': success,
        if (!success && failureReason != null) 'reason': failureReason,
      });
    _sink.emit(data);
  }

  void logLogout({required String identity}) {
    final data = _base('logout')
      ..addAll({'identityHash': IdentityNormalizer.hashIdentity(identity)});
    _sink.emit(data);
  }

  void logSendCode({
    required String identity,
    required String channel, // email | phone | password_reset
    required String purpose, // login | signup | password_reset
    int? attempt,
    int? cooldownSeconds,
  }) {
    final data = _base('send_code')
      ..addAll({
        'identityHash': IdentityNormalizer.hashIdentity(identity),
        'channel': channel,
        'purpose': purpose,
        if (attempt != null) 'attempt': attempt,
        if (cooldownSeconds != null) 'cooldown': cooldownSeconds,
      });
    _sink.emit(data);
  }

  void logVerifyCode({
    required String identity,
    required String channel,
    required String purpose,
    required bool success,
    int? attempt,
    String? failureReason,
  }) {
    final data = _base('verify_code')
      ..addAll({
        'identityHash': IdentityNormalizer.hashIdentity(identity),
        'channel': channel,
        'purpose': purpose,
        'success': success,
        if (attempt != null) 'attempt': attempt,
        if (!success && failureReason != null) 'reason': failureReason,
      });
    _sink.emit(data);
  }

  void logThrottlePenalty({
    required String identity,
    required String channel,
    required int penaltyLevel,
    required int enforcedCooldownSeconds,
  }) {
    final data = _base('throttle_penalty')
      ..addAll({
        'identityHash': IdentityNormalizer.hashIdentity(identity),
        'channel': channel,
        'penaltyLevel': penaltyLevel,
        'cooldown': enforcedCooldownSeconds,
      });
    _sink.emit(data);
  }

  void logWebSocketEvent({
    required String event,
    String? phase,
    String? reason,
    bool? success,
    int? attempt,
    String? topic,
    int? activeTopics,
  }) {
    final data = _base('ws_$event')
      ..addAll({
        'cat': 'ws',
        if (phase != null) 'phase': phase,
        if (reason != null) 'reason': reason,
        if (success != null) 'success': success,
        if (attempt != null) 'attempt': attempt,
        if (topic != null) 'topic': topic,
        if (activeTopics != null) 'activeTopics': activeTopics,
      });
    _sink.emit(data);
  }

  void logProfileSetup({
    required String phoneNumber,
    required String name,
    required String city,
    required String vehicleType,
    required bool success,
    String? error,
  }) {
    final data = _base('profile_setup')
      ..addAll({
        'phoneHash': IdentityNormalizer.hashIdentity(phoneNumber),
        'city': city,
        'vehicleType': vehicleType,
        'success': success,
        if (!success && error != null) 'error': error,
      });
    _sink.emit(data);
  }

  void logChallenge({
    required String challengeType,
    required String identity,
    String? reason,
    bool success = false,
    String? error,
  }) {
    final data = _base('challenge')
      ..addAll({
        'challengeType': challengeType,
        'identity': IdentityNormalizer.normalize(identity),
        if (reason != null) 'reason': reason,
        'success': success,
        if (!success && error != null) 'error': error,
      });
    _sink.emit(data);
  }
}
