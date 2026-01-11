import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service for managing audio notifications in the driver app
class AudioNotificationService {
  static final AudioNotificationService _instance =
      AudioNotificationService._internal();
  factory AudioNotificationService() => _instance;
  AudioNotificationService._internal();

  late AudioPlayer _audioPlayer;
  bool _isInitialized = false;

  /// Initialize the audio service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _audioPlayer = AudioPlayer();
      _isInitialized = true;
      debugPrint('🔊 AudioNotificationService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize AudioNotificationService: $e');
    }
  }

  /// Play new order notification sound
  Future<void> playNewOrderSound() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Play system notification sound first for immediate feedback
      await HapticFeedback.heavyImpact();

      // Play custom notification sound using BytesSource for better control
      // Using a notification-like beep sound
      await _playNotificationBeep();

      debugPrint('🔊 New order notification sound played');
    } catch (e) {
      debugPrint('❌ Failed to play new order sound: $e');
      // Fallback to haptic feedback only
      await HapticFeedback.heavyImpact();
    }
  }

  /// Play urgent order notification sound (for multiple orders)
  Future<void> playUrgentOrderSound() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Strong haptic feedback for urgent notifications
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();

      // Play double beep for urgent notifications
      await _playNotificationBeep();
      await Future.delayed(const Duration(milliseconds: 300));
      await _playNotificationBeep();

      debugPrint('🔊 Urgent order notification sound played');
    } catch (e) {
      debugPrint('❌ Failed to play urgent order sound: $e');
      // Fallback to double haptic feedback
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
    }
  }

  /// Play order accepted sound
  Future<void> playOrderAcceptedSound() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await HapticFeedback.lightImpact();
      await _playSuccessBeep();
      debugPrint('🔊 Order accepted sound played');
    } catch (e) {
      debugPrint('❌ Failed to play order accepted sound: $e');
      await HapticFeedback.lightImpact();
    }
  }

  /// Play order rejected sound
  Future<void> playOrderRejectedSound() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await HapticFeedback.mediumImpact();
      await _playErrorBeep();
      debugPrint('🔊 Order rejected sound played');
    } catch (e) {
      debugPrint('❌ Failed to play order rejected sound: $e');
      await HapticFeedback.mediumImpact();
    }
  }

  /// Generate and play notification beep sound
  Future<void> _playNotificationBeep() async {
    try {
      // Create a simple notification beep using system sounds
      // This is a cross-platform approach that works on both iOS and Android
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      debugPrint('❌ Failed to play notification beep: $e');
    }
  }

  /// Generate and play success beep sound
  Future<void> _playSuccessBeep() async {
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('❌ Failed to play success beep: $e');
    }
  }

  /// Generate and play error beep sound
  Future<void> _playErrorBeep() async {
    try {
      // Use alert sound for error/rejection
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      debugPrint('❌ Failed to play error beep: $e');
    }
  }

  /// Stop all audio playback
  Future<void> stopAllSounds() async {
    if (!_isInitialized) return;

    try {
      await _audioPlayer.stop();
      debugPrint('🔊 All audio stopped');
    } catch (e) {
      debugPrint('❌ Failed to stop audio: $e');
    }
  }

  /// Dispose of the audio service
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      await _audioPlayer.dispose();
      _isInitialized = false;
      debugPrint('🔊 AudioNotificationService disposed');
    } catch (e) {
      debugPrint('❌ Failed to dispose AudioNotificationService: $e');
    }
  }
}
