import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/demand_map_screen.dart';
import '../../screens/auth/phone_only_registration_screen.dart';
import '../../features/authentication/screens/new_email_verification_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../features/authentication/screens/new_phone_verification_screen.dart';
import '../../features/authentication/screens/driver_profile_setup_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../features/authentication/screens/password_reset_verification_screen.dart';
import '../../screens/auth/registration_method_selection_screen.dart';
import '../../screens/auth/email_registration_screen.dart';
import '../../features/authentication/screens/pending_review_screen.dart';
import '../../features/authentication/screens/account_status_screen.dart';
// Navigation page removed - placeholder for navigation
import '../../features/splash/splash_page.dart';
import '../../features/active_order/screens/driver_active_order_overview_screen.dart';
import '../../features/active_order/screens/heading_to_restaurant_screen.dart';
import '../../features/active_order/screens/at_restaurant_screen.dart';
import '../../features/active_order/screens/heading_to_customer_screen.dart';
import '../../features/active_order/screens/at_customer_screen.dart';
import '../../features/active_order/models/active_order_model.dart';

import '../../main.dart' show DriverHomePage;
import '../../models/order_model.dart';
import 'services_provider.dart';

part 'router_provider.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  // Use the auth service to check authentication status
  final authService = ref.watch(authServiceProvider);
  final profileCompletionService = ref.watch(profileCompletionServiceProvider);

  return GoRouter(
    initialLocation: '/splash',
    errorBuilder: (context, state) {
      debugPrint('🚨 GoRouter error: ${state.error}');
      debugPrint('🚨 GoRouter uri: ${state.uri}');

      final details = state.error?.toString() ?? 'Unknown routing error';
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Navigation error\n\n$details',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    },
    redirect: (BuildContext context, GoRouterState state) async {
      // ✅ FIXED: Check Amplify session asynchronously
      final isAuthenticated = await authService.checkAuthentication();

      final isAuthRoute =
          state.uri.path.startsWith('/login') ||
          state.uri.path.startsWith('/register') ||
          state.uri.path.startsWith('/register-method') ||
          state.uri.path.startsWith('/register-phone') ||
          state.uri.path.startsWith('/register-email') ||
          state.uri.path.startsWith('/forgot-password') ||
          state.uri.path.startsWith('/password-reset-verification') ||
          state.uri.path.startsWith('/verify-phone') ||
          state.uri.path.startsWith('/email-verification') ||
          state.uri.path.startsWith('/verify-email') ||
          state.uri.path.startsWith('/new-login') ||
          state.uri.path.startsWith('/splash');

      final isProfileSetupRoute =
          state.uri.path.startsWith('/driver-profile-setup') ||
          state.uri.path.startsWith('/upload-documents') ||
          state.uri.path.startsWith('/pending-review') ||
          state.uri.path.startsWith('/account-status');

      final isDebugRoute = 
          state.uri.path.startsWith('/config-debug') ||
          state.uri.path.startsWith('/email-test') ||
          state.uri.path.startsWith('/comprehensive-email-test') ||
          state.uri.path.startsWith('/sso-email-test') ||
          state.uri.path.startsWith('/registration-debug');

      debugPrint(
        '🔀 Router redirect: path=${state.uri.path}, isAuthenticated=$isAuthenticated, isAuthRoute=$isAuthRoute, isProfileSetupRoute=$isProfileSetupRoute',
      );

      // Allow splash screen to handle auth check
      if (state.uri.path == '/splash') {
        return null; // Let splash screen handle navigation
      }

      // If user is not authenticated and not on auth/debug route, redirect to login
      if (!isAuthenticated && !isAuthRoute && !isProfileSetupRoute && !isDebugRoute) {
        debugPrint('🔀 Redirecting to login (not authenticated)');
        return '/login';
      }

      // If user is authenticated, check profile completion status
      if (isAuthenticated) {
        // If trying to access auth routes, check profile first before redirecting
        if (isAuthRoute) {
          try {
            final profileStatus = await profileCompletionService.checkProfileCompleteness();
            debugPrint('🔍 Profile status check: ${profileStatus.status}, needsRedirect: ${profileStatus.needsRedirect}');
            
            if (profileStatus.needsRedirect && profileStatus.redirectPath != null) {
              debugPrint('🔀 Redirecting to ${profileStatus.redirectPath} (incomplete profile)');
              return profileStatus.redirectPath;
            }
            
            // Profile is complete, redirect to home
            debugPrint('🔀 Redirecting to home (profile complete)');
            return '/';
          } catch (e) {
            debugPrint('❌ Error checking profile status: $e');
            // On error, redirect to profile setup to be safe
            return '/driver-profile-setup';
          }
        }

        // ✅ REMOVED: Active order check moved to Splash (simpler approach)
        // Router will no longer check for active orders
        // All navigation happens from Splash after profile check

        // If trying to access home or other protected routes, verify profile is complete
        if (state.uri.path == '/' || state.uri.path.startsWith('/demand-map') || state.uri.path.startsWith('/navigation')) {
          try {
            final profileStatus = await profileCompletionService.checkProfileCompleteness();
            debugPrint('🔍 Profile status check for protected route: ${profileStatus.status}');
            
            if (profileStatus.needsRedirect && profileStatus.redirectPath != null) {
              debugPrint('🔀 Redirecting to ${profileStatus.redirectPath} (incomplete profile)');
              return profileStatus.redirectPath;
            }
          } catch (e) {
            debugPrint('❌ Error checking profile status: $e');
            return '/driver-profile-setup';
          }
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/new-login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register-method',
        builder: (context, state) => const RegistrationMethodSelectionScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const PhoneOnlyRegistrationScreen(),
      ),
      GoRoute(
        path: '/register-phone',
        builder: (context, state) => const PhoneOnlyRegistrationScreen(),
      ),
      GoRoute(
        path: '/register-email',
        builder: (context, state) => const EmailRegistrationScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/password-reset-verification',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final identifier = extra?['identifier'] as String? ?? '';
          final resetMethod = extra?['resetMethod'] as String? ?? 'email';
          return PasswordResetVerificationScreen(
            identifier: identifier,
            resetMethod: resetMethod,
          );
        },
      ),
      // Legacy path support: redirect old '/driver-signup' to new unified '/register'
      GoRoute(
        path: '/driver-signup',
        redirect: (context, state) => '/register',
      ),
      GoRoute(
        path: '/verify-phone',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final phone = extra?['phone'] as String? ?? '';
          final isNewRegistration =
              extra?['isNewRegistration'] as bool? ?? false;
          return NewPhoneVerificationScreen(
            phoneNumber: phone,
            isNewRegistration: isNewRegistration,
          );
        },
      ),
      GoRoute(
        path: '/driver-profile-setup',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final phone = extra?['phone'] as String? ?? '';
          return DriverProfileSetupScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: '/pending-review',
        builder: (context, state) => const PendingReviewScreen(),
      ),
      GoRoute(
        path: '/account-status',
        builder: (context, state) => const AccountStatusScreen(),
      ),
      // Email verification route
      GoRoute(
        path: '/email-verification',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final email = extra?['email'] as String? ?? '';
          final delivery = extra?['delivery'] as String?;
          final fromSignup = extra?['fromSignup'] as bool? ?? false;
          final username =
              extra?['username'] as String? ??
              email; // Fallback to email for safety
          return NewEmailVerificationScreen(
            username: username,
            email: email,
            delivery: delivery,
            fromSignup: fromSignup,
          );
        },
      ),
      // Legacy verify-email route for compatibility
      GoRoute(
        path: '/verify-email',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final email = extra?['email'] as String? ?? '';
          final delivery = extra?['delivery'] as String?;
          final fromSignup = extra?['fromSignup'] as bool? ?? false;
          final username =
              extra?['username'] as String? ??
              email; // Fallback to email for safety
          return NewEmailVerificationScreen(
            username: username,
            email: email,
            delivery: delivery,
            fromSignup: fromSignup,
          );
        },
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          final tabParam = state.uri.queryParameters['tab'];
          int initialTab = 0;
          if (tabParam != null) {
            initialTab = int.tryParse(tabParam) ?? 0;
            initialTab = initialTab.clamp(0, 5); // 6 tabs: 0..5
          }

          return DriverHomePage(
            selectedZone: state.uri.queryParameters['zone'],
            shouldStartDash: state.uri.queryParameters['startDash'] == 'true',
            initialTabIndex: initialTab,
          );
        },
      ),
      GoRoute(
        path: '/demand-map',
        builder: (context, state) => const DemandMapScreen(),
      ),
      // مسار شاشة الطلب النشط
      GoRoute(
        path: '/active-order',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final orderId = extra?['orderId'] as String?;
          return DriverActiveOrderOverviewScreen(orderId: orderId);
        },
      ),
      // مسارات المراحل المنفصلة (Legacy - تحتاج Order في extra)
      GoRoute(
        path: '/heading-to-restaurant',
        builder: (context, state) {
          final order = state.extra as ActiveOrder;
          return HeadingToRestaurantScreen(order: order);
        },
      ),
      GoRoute(
        path: '/at-restaurant',
        builder: (context, state) {
          final order = state.extra as ActiveOrder;
          return AtRestaurantScreen(order: order);
        },
      ),
      GoRoute(
        path: '/heading-to-customer',
        builder: (context, state) {
          final order = state.extra as ActiveOrder;
          return HeadingToCustomerScreen(order: order);
        },
      ),
      GoRoute(
        path: '/at-customer',
        builder: (context, state) {
          final order = state.extra as ActiveOrder;
          return AtCustomerScreen(order: order);
        },
      ),
      
      // ✅ REMOVED: /active-order/* routes (using simple routes via splash instead)
      
      GoRoute(
        path: '/navigation',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final order = extra?['order'] as OrderModel?;
          if (order == null) {
            return const LoginScreen();
          }
          // Placeholder: Navigation page to be implemented
          return Scaffold(
            appBar: AppBar(title: const Text('التنقل')),
            body: const Center(
              child: Text('صفحة التنقل - سيتم إضافتها لاحقاً'),
            ),
          );
        },
      ),
    ],
  );
}
