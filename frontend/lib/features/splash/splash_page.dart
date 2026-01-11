import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/riverpod/services_provider.dart';
import '../../features/active_order/services/active_order_service.dart';
import '../../services/push_notifications_service.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});
  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    // Wait for animation to complete
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    try {
      debugPrint('🔐 Splash: Starting authentication check...');
      debugPrint('🔐🔐🔐 SPLASH VERSION: 2.0 - Active Order Check Enabled');
      
      // CRITICAL: Check Amplify session first (don't trust cached token)
      final authService = ref.read(authServiceProvider);
      final isAuthenticated = await authService.checkAuthentication();
      
      debugPrint('🔐 Splash: Amplify session check = $isAuthenticated');

      if (!mounted) return;

      // If NOT authenticated, go directly to login
      if (!isAuthenticated) {
        debugPrint('🔀 Splash: No valid session → Navigating to /login');
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        context.go('/login');
        return;
      }

      // User is authenticated - try to load profile
      debugPrint('✅ Splash: User authenticated, checking profile...');
      
      try {
        final cognitoAuthService = ref.read(cognitoAuthServiceProvider);
        await cognitoAuthService.persistPendingRegistrationIfAny();
        await cognitoAuthService.getCurrentDriver();
        debugPrint('✅ Splash: Profile loaded successfully');
      } catch (e) {
        debugPrint('⚠️ Splash: Could not load profile: $e');
      }

      // Clear temp password if exists
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('temp_registration_password');
      } catch (_) {}

      if (!mounted) return;

      // Check if profile is complete
      try {
        final profileService = ref.read(profileCompletionServiceProvider);
        final profileStatus = await profileService.checkProfileCompleteness();
        
        debugPrint('🔍 Splash: Profile status = ${profileStatus.status.name}');
        debugPrint('🔍 Splash: Needs redirect = ${profileStatus.needsRedirect}');
        
        if (profileStatus.needsRedirect && profileStatus.redirectPath != null) {
          debugPrint('🔀 Splash: Profile incomplete → ${profileStatus.redirectPath}');
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          context.go(profileStatus.redirectPath!);
          return; // ✅ مهم: return مباشرة
        }
        
        // ✅ Profile complete - Check for active order FIRST
        debugPrint('✅ Splash: Profile complete, checking for active order...');
        await _checkAndNavigateToActiveOrder();
        
      } catch (e) {
        debugPrint('❌ Splash: Profile check error: $e');
        // If profile check fails, go to setup as safe fallback
        if (!mounted) return;
        context.go('/driver-profile-setup');
      }
    } catch (e) {
      debugPrint('❌ Splash: Critical error: $e');
      if (!mounted) return;
      context.go('/login');
    }
  }

  /// ✅ فحص بسيط للطلب النشط وتوجيه السائق للشاشة الصحيحة
  Future<void> _checkAndNavigateToActiveOrder() async {
    try {
      debugPrint('🔍 Splash: Checking for active order...');
      
      final activeOrderService = ActiveOrderService();
      final activeOrder = await activeOrderService.getActiveOrder();
      
      if (activeOrder == null) {
        debugPrint('ℹ️ Splash: No active order found');
        // Go to home (search screen). If a push-tap requested a specific tab,
        // consume it here (after auth/profile checks) to avoid cold-start races.
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 300));
        final pendingTab = await PushNotificationsService.consumePendingTabFromTap();
        if (!mounted) return;
        if (pendingTab != null) {
          context.go('/?tab=$pendingTab');
        } else {
          context.go('/');
        }
        return;
      }
      
      debugPrint('✅ Splash: Active order found!');
      debugPrint('   OrderID: ${activeOrder.orderId}');
      debugPrint('   Status: ${activeOrder.status}');
      debugPrint('   Restaurant: ${activeOrder.restaurantName}');
      
      // Navigate to correct screen based on order status
      String targetScreen = _getScreenForOrderStatus(activeOrder.status);
      debugPrint('🔀 Splash: Navigating to $targetScreen');
      
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Handle different screen types
      if (targetScreen == '/active-order') {
        // For active-order screen, pass orderId in extra map
        context.go(targetScreen, extra: {'orderId': activeOrder.orderId});
      } else {
        // For other screens (heading-to-restaurant, etc.), pass full order object
        context.go(targetScreen, extra: activeOrder);
      }
      
    } catch (e) {
      debugPrint('❌ Splash: Error checking active order: $e');
      // On error, go to home
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 300));
      context.go('/');
    }
  }

  /// ✅ دالة بسيطة لتحديد الشاشة حسب حالة الطلب
  String _getScreenForOrderStatus(String status) {
    switch (status) {
      // شاشة القبول الأولية (بعد قبول الطلب مباشرة)
      case 'accepted':
      case 'assigned':
        debugPrint('📋 Order accepted but not started - showing overview screen');
        return '/active-order';
      
      // شاشة الطريق إلى المطعم (بعد الضغط على "بدء التوجه")
      case 'ready_for_pickup':
      case 'heading_to_store':
        return '/heading-to-restaurant';
      
      // شاشة المطعم
      case 'at_store':
      case 'arrived_at_store':
        return '/at-restaurant';
      
      // شاشة الطريق إلى العميل
      case 'picked_up':
      case 'heading_to_customer':
        return '/heading-to-customer';
      
      // شاشة العميل
      case 'at_customer':
      case 'arrived_at_customer':
        return '/at-customer';
      
      // الطلب انتهى
      case 'delivered':
      case 'completed':
        debugPrint('ℹ️ Order is already completed');
        return '/';
      
      default:
        debugPrint('⚠️ Unknown order status: $status');
        return '/';
    }
  }

  @override
  Widget build(BuildContext context) {
    // الحصول على عرض الشاشة
    final screenWidth = MediaQuery.of(context).size.width;
    
    // حجم الأيقونة: 35% من عرض الشاشة، مع حد أقصى 280dp (أكبر من السابق)
    final iconSize = (screenWidth * 0.35).clamp(220.0, 280.0);
    
    return Scaffold(
      backgroundColor: const Color(0xFFFDC500), // ✅ خلفية صفراء #FDC500
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // ✅ أيقونة W في المنتصف مع فراغ حولها (أكبر من السابق)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.15),
                      child: Image.asset(
                        'assets/Wiz_Logo/Wizz_AB_icon_w_1024_Blue.png',
                        width: iconSize,
                        height: iconSize,
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ✅ مؤشر التحميل باللون الأزرق
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00509D), // أزرق #00509D
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
