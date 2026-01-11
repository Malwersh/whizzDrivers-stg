import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/session_state.dart';
import '../services/session_manager.dart';

/// حارس الجلسة للتحكم في التوجيه حسب حالة المصادقة
/// يتعامل مع جميع حالات الجلسة ويوجه المستخدم للشاشة المناسبة
class SessionGuard {
  static final SessionManager _sessionManager = SessionManager.instance;
  static StreamSubscription<SessionState>? _sessionSubscription;
  static GoRouter? _router;

  /// تهيئة حارس الجلسة مع router
  static void initialize(GoRouter router) {
    _router = router;
    
    // بدء مراقبة حالة الجلسة
    _sessionSubscription?.cancel();
    _sessionSubscription = _sessionManager.sessionStateStream.listen(
      _handleSessionStateChange,
      onError: (error) {
        debugPrint('❌ SessionGuard: خطأ في مراقبة الجلسة: $error');
      },
    );
  }

  /// التعامل مع تغيير حالة الجلسة
  static void _handleSessionStateChange(SessionState sessionState) {
    if (_router == null) return;

    final currentLocation = _router!.routerDelegate.currentConfiguration.uri.path;
    
    debugPrint('🔒 SessionGuard: تغيير حالة الجلسة إلى ${sessionState.runtimeType}');
    debugPrint('🔒 SessionGuard: الموقع الحالي: $currentLocation');

    switch (sessionState.runtimeType) {
      case SessionActive:
        _handleActiveSession(sessionState as SessionActive, currentLocation);
        break;
        
      case SessionUnauthenticated:
        _handleUnauthenticatedSession(currentLocation);
        break;
        
      case SessionExpired:
        _handleExpiredSession(sessionState as SessionExpired, currentLocation);
        break;
        
      case SessionError:
        _handleErrorSession(sessionState as SessionError, currentLocation);
        break;
        
      case SessionConflict:
        // تعامل مع التضارب في شاشة تسجيل الدخول
        if (!_isAuthRoute(currentLocation)) {
          _router!.go('/login');
        }
        break;
        
      case SessionLoading:
        // لا نحتاج لإعادة توجيه أثناء التحميل
        break;
        
      default:
        debugPrint('⚠️ SessionGuard: حالة جلسة غير معروفة: ${sessionState.runtimeType}');
    }
  }

  /// التعامل مع الجلسة النشطة
  static void _handleActiveSession(SessionActive session, String currentLocation) {
    // إذا كان المستخدم في شاشة مصادقة، وجهه للصفحة الرئيسية
    if (_isAuthRoute(currentLocation)) {
      debugPrint('✅ SessionGuard: جلسة نشطة، التوجيه للصفحة الرئيسية');
      _router!.go('/');
    }
    
    // تحقق من حالة الملف الشخصي للسائق
    final driverStatus = session.userData['status'] as String?;
    if (driverStatus != null && _shouldRedirectForProfileStatus(driverStatus, currentLocation)) {
      _redirectForProfileStatus(driverStatus);
    }
  }

  /// التعامل مع الجلسة غير المصدقة
  static void _handleUnauthenticatedSession(String currentLocation) {
    // إذا كان المستخدم في صفحة محمية، وجهه لتسجيل الدخول
    if (!_isAuthRoute(currentLocation) && !_isPublicRoute(currentLocation)) {
      debugPrint('🔒 SessionGuard: جلسة غير مصدقة، التوجيه لتسجيل الدخول');
      _router!.go('/login');
    }
  }

  /// التعامل مع الجلسة المنتهية الصلاحية
  static void _handleExpiredSession(SessionExpired session, String currentLocation) {
    debugPrint('⏰ SessionGuard: جلسة منتهية الصلاحية: ${session.reason}');
    
    // وجه للتسجيل مع رسالة انتهاء الصلاحية
    if (!_isAuthRoute(currentLocation)) {
      _router!.go('/login?expired=true&reason=${Uri.encodeComponent(session.reason)}');
    }
  }

  /// التعامل مع خطأ في الجلسة
  static void _handleErrorSession(SessionError session, String currentLocation) {
    debugPrint('❌ SessionGuard: خطأ في الجلسة: ${session.error}');
    
    // وجه للتسجيل مع رسالة الخطأ
    if (!_isAuthRoute(currentLocation)) {
      _router!.go('/login?error=true&message=${Uri.encodeComponent(session.error)}');
    }
  }

  /// تحقق إذا كان المسار خاص بالمصادقة
  static bool _isAuthRoute(String path) {
    final authRoutes = [
      '/login',
      '/register-method',
      '/register-email',
      '/register-phone',
      '/forgot-password',
      '/verify-email',
      '/verify-phone',
    ];
    
    return authRoutes.any((route) => path.startsWith(route));
  }

  /// تحقق إذا كان المسار عام (لا يحتاج مصادقة)
  static bool _isPublicRoute(String path) {
    final publicRoutes = [
      '/privacy',
      '/terms',
      '/help',
      '/about',
    ];
    
    return publicRoutes.any((route) => path.startsWith(route));
  }

  /// تحقق إذا كان يجب إعادة التوجيه حسب حالة الملف الشخصي
  static bool _shouldRedirectForProfileStatus(String status, String currentLocation) {
    switch (status) {
      case 'PENDING_PROFILE':
        return !currentLocation.startsWith('/profile-completion');
      case 'PENDING_REVIEW':
        return !currentLocation.startsWith('/pending-review');
      case 'REJECTED':
        return !currentLocation.startsWith('/profile-rejected');
      case 'SUSPENDED':
        return !currentLocation.startsWith('/account-suspended');
      default:
        return false;
    }
  }

  /// إعادة التوجيه حسب حالة الملف الشخصي
  static void _redirectForProfileStatus(String status) {
    switch (status) {
      case 'PENDING_PROFILE':
        debugPrint('📝 SessionGuard: ملف شخصي غير مكتمل، التوجيه لإكمال التسجيل');
        _router!.go('/profile-completion');
        break;
      case 'PENDING_REVIEW':
        debugPrint('⏳ SessionGuard: ملف شخصي قيد المراجعة');
        _router!.go('/pending-review');
        break;
      case 'REJECTED':
        debugPrint('❌ SessionGuard: ملف شخصي مرفوض');
        _router!.go('/profile-rejected');
        break;
      case 'SUSPENDED':
        debugPrint('🚫 SessionGuard: حساب معلق');
        _router!.go('/account-suspended');
        break;
    }
  }

  /// تحقق من صحة الجلسة الحالية
  static Future<bool> isValidSession() async {
    final currentState = _sessionManager.currentSessionState;
    return currentState is SessionActive;
  }

  /// الحصول على بيانات السائق الحالي
  static Map<String, dynamic>? getCurrentDriverData() {
    final currentState = _sessionManager.currentSessionState;
    if (currentState is SessionActive) {
      return currentState.userData;
    }
    return null;
  }

  /// فرض تسجيل خروج
  static Future<void> forceSignOut() async {
    await _sessionManager.signOut();
  }

  /// تنظيف الموارد
  static void dispose() {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _router = null;
  }
}
