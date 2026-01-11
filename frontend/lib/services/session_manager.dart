import 'dart:async';
import 'dart:convert';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:rxdart/rxdart.dart';

import '../models/session_state.dart';
import '../services/logging/auth_logger.dart';

/// خدمة إدارة الجلسات الشاملة للسائقين
/// تدير جلسات المصادقة، حفظ التوكينات، تجديدها، والحماية من التضارب
class SessionManager extends ChangeNotifier {
  static final SessionManager _instance = SessionManager._internal();
  static SessionManager get instance => _instance;
  SessionManager._internal();

  // Session state stream
  final BehaviorSubject<SessionState> _sessionStateController = 
      BehaviorSubject<SessionState>.seeded(const SessionInitial());
  
  Stream<SessionState> get sessionStateStream => _sessionStateController.stream;
  SessionState get currentSessionState => _sessionStateController.value;

  // Logger for debugging
  AuthLogger? logger;

  // Session data
  SessionState _currentState = const SessionInitial();
  Timer? _tokenRefreshTimer;
  Timer? _sessionValidationTimer;

  // Storage keys for SharedPreferences (simpler approach)
  static const String _accessTokenKey = 'driver_access_token';
  static const String _idTokenKey = 'driver_id_token';
  static const String _refreshTokenKey = 'driver_refresh_token';
  static const String _driverDataKey = 'driver_data';
  static const String _loginTimeKey = 'login_time';

  // Session validation intervals
  static const Duration _tokenRefreshInterval = Duration(minutes: 45); // قبل انتهاء الصلاحية بـ 15 دقيقة
  static const Duration _sessionValidationInterval = Duration(minutes: 5);

  /// تهيئة مدير الجلسات وتحميل الجلسة السابقة
  Future<void> initialize() async {
    debugPrint('🚀 تهيئة مدير الجلسات...');
    
    try {
      _emitState(const SessionLoading(message: 'تحميل الجلسة السابقة...'));
      
      // تحقق من وجود جلسة محفوظة
      await _loadSavedSession();
      
      // بدء مراقبة الجلسة
      _startSessionValidation();
      
      debugPrint('✅ تم تهيئة مدير الجلسات بنجاح');
    } catch (e) {
      debugPrint('❌ خطأ في تهيئة مدير الجلسات: $e');
      _emitState(SessionError(error: 'فشل في تهيئة الجلسة', details: e.toString()));
    }
  }

  /// تحميل الجلسة المحفوظة
  Future<void> _loadSavedSession() async {
    try {
      // تحقق من وجود tokens محفوظة
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_accessTokenKey);
      final idToken = prefs.getString(_idTokenKey);
      final refreshToken = prefs.getString(_refreshTokenKey);
      
      if (accessToken == null || idToken == null) {
        debugPrint('📭 لا توجد جلسة محفوظة');
        _emitState(const SessionUnauthenticated());
        return;
      }

      // تحقق من صحة التوكينات
      if (_isTokenExpired(accessToken)) {
        debugPrint('⚠️ التوكين منتهي الصلاحية، محاولة تجديد...');
        
        if (refreshToken != null) {
          await _refreshTokens(refreshToken);
          return;
        } else {
          debugPrint('❌ لا يوجد refresh token، مسح الجلسة');
          await _clearSession();
          return;
        }
      }

      // تحقق من الجلسة مع AWS Cognito
      final isValidSession = await _validateCognitoSession();
      if (!isValidSession) {
        debugPrint('❌ جلسة Cognito غير صالحة');
        await _clearSession();
        return;
      }

      // تحميل بيانات السائق
      final driverDataString = (await SharedPreferences.getInstance()).getString(_driverDataKey);
      final loginTimeString = (await SharedPreferences.getInstance()).getString(_loginTimeKey);
      
      if (driverDataString == null || loginTimeString == null) {
        debugPrint('❌ بيانات الجلسة ناقصة');
        await _clearSession();
        return;
      }

      final driverData = jsonDecode(driverDataString) as Map<String, dynamic>;
      final loginTime = DateTime.parse(loginTimeString);

      // إنشاء حالة جلسة نشطة
      final sessionState = SessionActive(
        userData: driverData,
        accessToken: accessToken,
        idToken: idToken,
        refreshToken: refreshToken,
        loginTime: loginTime,
        driverId: driverData['driver_id'] ?? driverData['id'] ?? 'unknown',
      );

      _emitState(sessionState);
      _startTokenRefreshTimer();
      
      debugPrint('✅ تم تحميل الجلسة المحفوظة للسائق: ${driverData['name']}');
      
    } catch (e) {
      debugPrint('❌ خطأ في تحميل الجلسة المحفوظة: $e');
      await _clearSession();
    }
  }

  /// تسجيل دخول جديد
  Future<SessionState> signIn({
    required String identifier,
    required String password,
    bool forceSignIn = false,
  }) async {
    debugPrint('🔐 محاولة تسجيل دخول للمعرف: $identifier');
    
    try {
      _emitState(const SessionLoading(message: 'جارٍ تسجيل الدخول...'));

      // تحقق من وجود جلسة نشطة
      if (!forceSignIn && _currentState is SessionActive) {
        final conflict = SessionConflict(
          conflictReason: 'يوجد مستخدم مسجل دخول بالفعل',
          existingUserData: (_currentState as SessionActive).userData,
        );
        _emitState(conflict);
        return conflict;
      }

      // فرض تسجيل خروج إذا كان مطلوب
      if (forceSignIn) {
        await _forceSignOut();
      }

      // محاولة تسجيل الدخول مع AWS Cognito
      final signInResult = await Amplify.Auth.signIn(
        username: identifier,
        password: password,
      );

      if (!signInResult.isSignedIn) {
        const error = SessionError(
          error: 'فشل في تسجيل الدخول',
          details: 'تسجيل الدخول غير مكتمل',
        );
        _emitState(error);
        return error;
      }

      // الحصول على التوكينات
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      if (!session.isSignedIn) {
        const error = SessionError(
          error: 'فشل في الحصول على التوكينات',
        );
        _emitState(error);
        return error;
      }

      final tokens = session.userPoolTokensResult.value;
      final accessToken = tokens.accessToken.toString();
      final idToken = tokens.idToken.toString();
      final refreshToken = tokens.refreshToken.toString();

      // الحصول على بيانات المستخدم
      final cognitoUser = await Amplify.Auth.getCurrentUser();
      final userAttributes = await Amplify.Auth.fetchUserAttributes();
      
      // بناء بيانات السائق
      final driverData = _buildDriverData(cognitoUser, userAttributes);
      
      // حفظ الجلسة
      await _saveSession(
        driverData: driverData,
        accessToken: accessToken,
        idToken: idToken,
        refreshToken: refreshToken,
      );

      // إنشاء حالة جلسة نشطة
      final sessionState = SessionActive(
        userData: driverData,
        accessToken: accessToken,
        idToken: idToken,
        refreshToken: refreshToken,
        loginTime: DateTime.now(),
        driverId: driverData['driver_id'] ?? driverData['id'] ?? 'unknown',
      );

      _emitState(sessionState);
      _startTokenRefreshTimer();
      
      debugPrint('✅ تم تسجيل الدخول بنجاح للسائق: ${driverData['name']}');
      
      return sessionState;
      
    } catch (e) {
      debugPrint('❌ خطأ في تسجيل الدخول: $e');
      final error = SessionError(
        error: 'خطأ في تسجيل الدخول',
        details: e.toString(),
      );
      _emitState(error);
      return error;
    }
  }

  /// تسجيل الخروج
  Future<void> signOut({bool clearCognito = true}) async {
    debugPrint('🚪 بدء عملية تسجيل الخروج...');
    
    try {
      _emitState(const SessionLoading(message: 'جارٍ تسجيل الخروج...'));
      
      // إيقاف المؤقتات
      _stopTimers();
      
      // تسجيل خروج من AWS Cognito
      if (clearCognito) {
        try {
          await Amplify.Auth.signOut();
          debugPrint('✅ تم تسجيل الخروج من AWS Cognito');
        } catch (e) {
          debugPrint('⚠️ خطأ في تسجيل الخروج من Cognito: $e');
        }
      }
      
      // مسح الجلسة المحلية
      await _clearSession();
      
      debugPrint('✅ تم تسجيل الخروج بنجاح');
      
    } catch (e) {
      debugPrint('❌ خطأ في تسجيل الخروج: $e');
      // فرض مسح الجلسة حتى لو حدث خطأ
      await _clearSession();
    }
  }

  /// فرض تسجيل خروج (لحل تضارب الجلسات)
  Future<void> _forceSignOut() async {
    debugPrint('⚡ فرض تسجيل خروج...');
    
    try {
      // محاولة تسجيل خروج من Cognito
      await Amplify.Auth.signOut();
    } catch (e) {
      debugPrint('⚠️ تجاهل خطأ فرض تسجيل الخروج: $e');
    }
    
    // مسح الجلسة المحلية
    await _clearSession();
  }

  /// تجديد التوكينات
  Future<void> _refreshTokens(String refreshToken) async {
    debugPrint('🔄 تجديد التوكينات...');
    
    try {
      // AWS Cognito يدير تجديد التوكينات تلقائياً
      final session = await Amplify.Auth.fetchAuthSession(
        options: const FetchAuthSessionOptions(forceRefresh: true),
      ) as CognitoAuthSession;
      
      if (!session.isSignedIn) {
        throw Exception('فشل في تجديد التوكينات');
      }

      final tokens = session.userPoolTokensResult.value;
      final newAccessToken = tokens.accessToken.toString();
      final newIdToken = tokens.idToken.toString();
      final newRefreshToken = tokens.refreshToken.toString();

      // تحديث التوكينات المحفوظة
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, newAccessToken);
      await prefs.setString(_idTokenKey, newIdToken);
      await prefs.setString(_refreshTokenKey, newRefreshToken);

      // تحديث حالة الجلسة
      if (_currentState is SessionActive) {
        final currentSession = _currentState as SessionActive;
        final updatedSession = SessionActive(
          userData: currentSession.userData,
          accessToken: newAccessToken,
          idToken: newIdToken,
          refreshToken: newRefreshToken,
          loginTime: currentSession.loginTime,
          driverId: currentSession.driverId,
        );
        _emitState(updatedSession);
      }
      
      debugPrint('✅ تم تجديد التوكينات بنجاح');
      
    } catch (e) {
      debugPrint('❌ فشل في تجديد التوكينات: $e');
      _emitState(const SessionExpired(reason: 'فشل في تجديد التوكينات'));
      await _clearSession();
    }
  }

  /// التحقق من صحة جلسة Cognito
  Future<bool> _validateCognitoSession() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session.isSignedIn;
    } catch (e) {
      debugPrint('❌ خطأ في التحقق من جلسة Cognito: $e');
      return false;
    }
  }

  /// التحقق من انتهاء صلاحية التوكين
  bool _isTokenExpired(String token) {
    try {
      return JwtDecoder.isExpired(token);
    } catch (e) {
      debugPrint('⚠️ خطأ في فحص انتهاء صلاحية التوكين: $e');
      return true; // اعتبره منتهي الصلاحية في حالة الخطأ
    }
  }

  /// بناء بيانات السائق من معلومات Cognito
  Map<String, dynamic> _buildDriverData(
    AuthUser cognitoUser,
    List<AuthUserAttribute> attributes,
  ) {
    final driverData = <String, dynamic>{
      'driver_id': cognitoUser.userId,
      'id': cognitoUser.userId,
      'username': cognitoUser.username,
      'signInDetails': cognitoUser.signInDetails,
    };

    // إضافة الخصائص
    for (final attribute in attributes) {
      final key = attribute.userAttributeKey.key;
      final value = attribute.value;
      
      switch (key) {
        case 'email':
          driverData['email'] = value;
          break;
        case 'phone_number':
          driverData['phone'] = value;
          break;
        case 'name':
          driverData['name'] = value;
          break;
        case 'custom:city':
          driverData['city'] = value;
          break;
        case 'custom:vehicle_type':
          driverData['vehicle_type'] = value;
          break;
        default:
          driverData[key] = value;
      }
    }

    return driverData;
  }

  /// حفظ الجلسة
  Future<void> _saveSession({
    required Map<String, dynamic> driverData,
    required String accessToken,
    required String idToken,
    String? refreshToken,
  }) async {
    // حفظ بيانات الجلسة في SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_accessTokenKey, accessToken),
      prefs.setString(_idTokenKey, idToken),
      if (refreshToken != null) prefs.setString(_refreshTokenKey, refreshToken),
      prefs.setString(_driverDataKey, jsonEncode(driverData)),
      prefs.setString(_loginTimeKey, DateTime.now().toIso8601String()),
    ]);

    debugPrint('💾 تم حفظ الجلسة بنجاح');
  }

  /// مسح الجلسة
  Future<void> _clearSession() async {
    // مسح بيانات الجلسة من SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_accessTokenKey),
      prefs.remove(_idTokenKey),
      prefs.remove(_refreshTokenKey),
      prefs.remove(_driverDataKey),
      prefs.remove(_loginTimeKey),
    ]);

    _emitState(const SessionUnauthenticated());
    debugPrint('🧹 تم مسح الجلسة');
  }

  /// بدء مؤقت تجديد التوكينات
  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = Timer.periodic(_tokenRefreshInterval, (timer) async {
      if (_currentState is SessionActive) {
        final session = _currentState as SessionActive;
        if (session.refreshToken != null) {
          await _refreshTokens(session.refreshToken!);
        }
      }
    });
  }

  /// بدء مراقبة الجلسة
  void _startSessionValidation() {
    _sessionValidationTimer?.cancel();
    _sessionValidationTimer = Timer.periodic(_sessionValidationInterval, (timer) async {
      await _validateCurrentSession();
    });
  }

  /// التحقق من صحة الجلسة الحالية
  Future<void> _validateCurrentSession() async {
    if (_currentState is! SessionActive) {
      return;
    }

    try {
      final isValid = await _validateCognitoSession();
      if (!isValid) {
        debugPrint('⚠️ جلسة Cognito غير صالحة، مسح الجلسة');
        _emitState(const SessionExpired(reason: 'انتهت صلاحية الجلسة'));
        await _clearSession();
      }
    } catch (e) {
      debugPrint('❌ خطأ في مراقبة الجلسة: $e');
    }
  }

  /// إيقاف المؤقتات
  void _stopTimers() {
    _tokenRefreshTimer?.cancel();
    _sessionValidationTimer?.cancel();
  }

  /// إرسال حالة جديدة
  void _emitState(SessionState state) {
    _currentState = state;
    _sessionStateController.add(state);
    notifyListeners();
  }

  // Getters للوصول السريع
  bool get isAuthenticated => _currentState is SessionActive;
  String? get currentDriverId => _currentState is SessionActive 
      ? (_currentState as SessionActive).driverId 
      : null;
  Map<String, dynamic>? get currentDriverData => _currentState is SessionActive 
      ? (_currentState as SessionActive).userData 
      : null;
  String? get currentAccessToken => _currentState is SessionActive 
      ? (_currentState as SessionActive).accessToken 
      : null;

  /// تنظيف الموارد
  @override
  void dispose() {
    _stopTimers();
    _sessionStateController.close();
    super.dispose();
  }
}
