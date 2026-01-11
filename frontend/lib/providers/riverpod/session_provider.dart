import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/session_state.dart';
import '../../services/session_manager.dart';
import 'services_provider.dart';

/// مزود مدير الجلسات
final sessionManagerProvider = Provider<SessionManager>((ref) {
  final manager = SessionManager.instance;
  
  // إضافة logger إذا كان متوفر
  try {
    final logger = ref.read(authLoggerProvider);
    manager.logger = logger;
  } catch (e) {
    // تجاهل إذا لم يكن logger متوفر
  }
  
  return manager;
});

/// مزود حالة الجلسة الحالية
final sessionStateProvider = StreamProvider<SessionState>((ref) {
  final manager = ref.watch(sessionManagerProvider);
  return manager.sessionStateStream;
});

/// مزود للتحقق من حالة المصادقة
final isAuthenticatedProvider = Provider<bool>((ref) {
  final sessionState = ref.watch(sessionStateProvider);
  return sessionState.when(
    data: (state) => state is SessionActive,
    loading: () => false,
    error: (error, stackTrace) => false,
  );
});

/// مزود بيانات السائق الحالي
final currentDriverProvider = Provider<Map<String, dynamic>?>((ref) {
  final sessionState = ref.watch(sessionStateProvider);
  return sessionState.when(
    data: (state) => state is SessionActive ? state.userData : null,
    loading: () => null,
    error: (error, stackTrace) => null,
  );
});

/// مزود معرف السائق الحالي
final currentDriverIdProvider = Provider<String?>((ref) {
  final sessionState = ref.watch(sessionStateProvider);
  return sessionState.when(
    data: (state) => state is SessionActive ? state.driverId : null,
    loading: () => null,
    error: (error, stackTrace) => null,
  );
});

/// مزود التوكين الحالي
final currentAccessTokenProvider = Provider<String?>((ref) {
  final sessionState = ref.watch(sessionStateProvider);
  return sessionState.when(
    data: (state) => state is SessionActive ? state.accessToken : null,
    loading: () => null,
    error: (error, stackTrace) => null,
  );
});

/// مزود حالة التحميل
final sessionLoadingProvider = Provider<bool>((ref) {
  final sessionState = ref.watch(sessionStateProvider);
  return sessionState.when(
    data: (state) => state is SessionLoading,
    loading: () => true,
    error: (error, stackTrace) => false,
  );
});

/// مزود رسائل الخطأ
final sessionErrorProvider = Provider<String?>((ref) {
  final sessionState = ref.watch(sessionStateProvider);
  return sessionState.when(
    data: (state) => state is SessionError ? state.error : null,
    loading: () => null,
    error: (error, stackTrace) => error.toString(),
  );
});

/// مزود حالة التضارب
final sessionConflictProvider = Provider<SessionConflict?>((ref) {
  final sessionState = ref.watch(sessionStateProvider);
  return sessionState.when(
    data: (state) => state is SessionConflict ? state : null,
    loading: () => null,
    error: (error, stackTrace) => null,
  );
});

/// مزود حالة انتهاء الجلسة
final sessionExpiredProvider = Provider<SessionExpired?>((ref) {
  final sessionState = ref.watch(sessionStateProvider);
  return sessionState.when(
    data: (state) => state is SessionExpired ? state : null,
    loading: () => null,
    error: (error, stackTrace) => null,
  );
});
