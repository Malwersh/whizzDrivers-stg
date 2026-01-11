import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';

/// مدير ذاكرة متقدم لتطبيق السائق
class MemoryManager {
  static final MemoryManager _instance = MemoryManager._internal();
  factory MemoryManager() => _instance;
  MemoryManager._internal();

  // Memory monitoring
  static int _streamControllerCount = 0;
  static int _timerCount = 0;
  static final List<StreamController> _activeControllers = [];
  static final List<Timer> _activeTimers = [];

  /// تسجيل stream controller جديد
  static void registerStreamController(StreamController controller) {
    _streamControllerCount++;
    _activeControllers.add(controller);
    debugPrint('📊 Memory: StreamController registered. Total: $_streamControllerCount');
  }

  /// إلغاء تسجيل stream controller
  static void unregisterStreamController(StreamController controller) {
    _streamControllerCount--;
    _activeControllers.remove(controller);
    debugPrint('📊 Memory: StreamController unregistered. Total: $_streamControllerCount');
  }

  /// تسجيل timer جديد
  static void registerTimer(Timer timer) {
    _timerCount++;
    _activeTimers.add(timer);
    debugPrint('📊 Memory: Timer registered. Total: $_timerCount');
  }

  /// إلغاء تسجيل timer
  static void unregisterTimer(Timer timer) {
    _timerCount--;
    _activeTimers.remove(timer);
    debugPrint('📊 Memory: Timer unregistered. Total: $_timerCount');
  }

  /// تنظيف شامل للذاكرة
  static void cleanup() {
    debugPrint('🧹 Memory: Starting comprehensive cleanup...');
    
    // Clean up all active controllers
    for (final controller in _activeControllers.toList()) {
      try {
        if (!controller.isClosed) {
          controller.close();
        }
      } catch (e) {
        debugPrint('⚠️ Memory: Error closing controller: $e');
      }
    }
    _activeControllers.clear();
    _streamControllerCount = 0;

    // Clean up all active timers
    for (final timer in _activeTimers.toList()) {
      try {
        if (timer.isActive) {
          timer.cancel();
        }
      } catch (e) {
        debugPrint('⚠️ Memory: Error cancelling timer: $e');
      }
    }
    _activeTimers.clear();
    _timerCount = 0;

    debugPrint('✅ Memory: Cleanup completed');
  }

  /// تقرير حالة الذاكرة
  static void reportMemoryUsage() {
    debugPrint('📊 Memory Report:');
    debugPrint('   Active StreamControllers: $_streamControllerCount');
    debugPrint('   Active Timers: $_timerCount');
    debugPrint('   Total Objects: ${_streamControllerCount + _timerCount}');
  }
}

/// معالج أخطاء متقدم للتطبيق
class CrashHandler {
  static bool _initialized = false;

  /// تهيئة معالج الأخطاء
  static void initialize() {
    if (_initialized) return;

    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('🚨 Flutter Error Caught:');
      debugPrint('Error: ${details.exception}');
      debugPrint('Stack: ${details.stack}');
      
      // Don't crash - just log
      debugPrint('✅ Error handled safely - app continues');
    };

    _initialized = true;
    debugPrint('✅ CrashHandler initialized');
  }

  /// معالجة آمنة للأخطاء
  static T safeExecute<T>(T Function() operation, T fallback) {
    try {
      return operation();
    } catch (e, stackTrace) {
      debugPrint('🚨 Safe execution caught error: $e');
      debugPrint('Stack: $stackTrace');
      return fallback;
    }
  }

  /// معالجة آمنة للعمليات غير المتزامنة
  static Future<T> safeExecuteAsync<T>(Future<T> Function() operation, T fallback) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      debugPrint('🚨 Safe async execution caught error: $e');
      debugPrint('Stack: $stackTrace');
      return fallback;
    }
  }
}

/// Safe JSON handler
class SafeJsonHandler {
  /// تحويل آمن إلى JSON
  static String safeEncode(dynamic object) {
    return CrashHandler.safeExecute(
      () => jsonEncode(object),
      '{"error": "json_encode_failed"}',
    );
  }

  /// تحليل آمن من JSON
  static Map<String, dynamic> safeDecode(String jsonString) {
    return CrashHandler.safeExecute(
      () => jsonDecode(jsonString) as Map<String, dynamic>,
      <String, dynamic>{'error': 'json_decode_failed'},
    );
  }
}

/// مراقب الأداء
class PerformanceMonitor {
  static final Map<String, DateTime> _operationStarts = {};

  /// بدء مراقبة عملية
  static void startOperation(String operationName) {
    _operationStarts[operationName] = DateTime.now();
    debugPrint('⏱️ Performance: Started $operationName');
  }

  /// انتهاء مراقبة عملية
  static void endOperation(String operationName) {
    final start = _operationStarts[operationName];
    if (start != null) {
      final duration = DateTime.now().difference(start);
      debugPrint('⏱️ Performance: $operationName took ${duration.inMilliseconds}ms');
      _operationStarts.remove(operationName);
    }
  }
}