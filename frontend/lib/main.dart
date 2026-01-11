import 'dart:async';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Updated email verification configuration
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;

import 'utils/memory_manager.dart';

import 'config/amplifyconfiguration.dart';
import 'config/app_config.dart';
import 'design_system/app_theme.dart';
import 'design_system/colors.dart';
import 'providers/riverpod/router_provider.dart';
import 'providers/riverpod/tab_provider.dart';
import 'services/global_app_state_manager.dart';
import 'config/environment.dart';
import 'services/push_notifications_service.dart';

import 'features/more/more_tab.dart';
import 'features/trips/trips_screen.dart';
import 'features/earnings/earnings_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/wallet/screens/wallet_home_screen.dart';
import 'l10n/app_localizations.dart';
import 'features/home/spark_home_simple_arabic.dart';
import 'providers/simple_app_provider.dart';
import 'models/driver_status.dart';

void main() async {
  // Trigger hot reload for SSO debug button and comprehensive tests - Fixed presign endpoint 2
  print('Hot reload triggered at ${DateTime.now()} - SSO test added');
  
  // Initialize crash protection and memory management BEFORE WidgetsFlutterBinding
  CrashHandler.initialize();
  
  // Register global error handler with enhanced protection
  runZonedGuarded(() async {
    // Initialize Flutter bindings INSIDE the zone to prevent zone mismatch
    WidgetsFlutterBinding.ensureInitialized();
    
    try {
      await _initializeApp();
    } catch (e, stackTrace) {
      debugPrint('🚨 Critical error in app initialization: $e');
      debugPrint('Stack: $stackTrace');
      // Continue despite error - don't crash
    }
  }, (error, stackTrace) {
    debugPrint('🚨 Zone error caught: $error');
    debugPrint('Stack: $stackTrace');
    // Don't crash - just log and continue
  });
}

Future<void> _initializeApp() async {
  // Reduce debug noise on web by filtering errors
  if (kIsWeb) {
    FlutterError.onError = (FlutterErrorDetails details) {
      // Filter out known debug service null errors
      if (!details.exception.toString().contains('Cannot send Null') &&
          !details.exception.toString().contains('DebugService')) {
        FlutterError.presentError(details);
      }
    };
  }

  // Configure background execution and app lifecycle
  try {
    if (!kIsWeb) {
      // Enable background app refresh capabilities for iOS
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
      ));
      
      debugPrint('📱 Background capabilities initialized');
    }
  } catch (e) {
    debugPrint('⚠️ Background setup warning: $e');
  }

  // Initialize app configuration with AWS Cognito integration
  await AppConfig.initialize();
  await AppConfig.setAWSIntegration(true); // Enable AWS Cognito
  await AppConfig.setForceProductionMode(false); // Development mode
  AppConfig.printConfig();

  // Fail-fast if staging config is missing or still points to /dev
  Environment.validateOrThrow();

  // Initialize Global App State Management for persistent WebSocket
  GlobalAppStateManager().initialize();
  debugPrint('✅ Global App State Manager initialized');

  // Initialize Amplify
  await _configureAmplify();

  // Initialize push notifications (non-blocking if Firebase is not configured yet)
  // NOTE: PushNotificationsService is initialized in MyApp (with a tap handler).

  // Run app
  runApp(const riverpod.ProviderScope(child: MyApp()));
}

Future<void> _configureAmplify() async {
  try {
    if (Amplify.isConfigured) {
      safePrint('Amplify already configured');
      return;
    }

    // Add Cognito Auth plugin
    final auth = AmplifyAuthCognito();
    await Amplify.addPlugin(auth);

    // Configure Amplify with amplify configuration
    await Amplify.configure(amplifyconfig);

    safePrint('Successfully configured Amplify');
  } on Exception catch (e) {
    safePrint('An error occurred configuring Amplify: $e');
  }
}

// Legacy StateNotifier removed - use localeNotifierProvider from providers/riverpod/locale_provider.dart instead

class MyApp extends riverpod.ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  riverpod.ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends riverpod.ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();

    // Initialize push notifications once; route notification taps to the home/search tab.
    // Router redirects will handle unauthenticated users.
    unawaited(
      PushNotificationsService.initialize(
        onNotificationTap: (message) async {
          try {
            // Persist wave-offer tap payload so Home can show it even on cold start.
            await PushNotificationsService.stashWaveOfferFromTap(message);
            // Persist a pending tab index; SplashPage will consume it after auth/profile checks.
            await PushNotificationsService.stashPendingTabFromTap(message);

            final type = (message.data['type'] ?? '').toString();
            // Wave offers should always open the search/home tab.
            final targetTab = type == 'new_wave_offer' ? 0 : 4;
            ref.read(selectedTabProvider.notifier).state = targetTab;
          } catch (_) {
            // ignore
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use GoRouter for navigation
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'سائق Wizz',
      theme: AppTheme.lightTheme, // Arctic Cyan light theme
      darkTheme: AppTheme.darkTheme, // Arctic Cyan dark theme
      themeMode: ThemeMode.system,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

class DriverHomePage extends riverpod.ConsumerStatefulWidget {
  final String? selectedZone;
  final bool shouldStartDash;
  final int initialTabIndex;

  const DriverHomePage({
    super.key,
    this.selectedZone,
    this.shouldStartDash = false,
    this.initialTabIndex = 0,
  });

  @override
  riverpod.ConsumerState<DriverHomePage> createState() =>
      _DriverHomePageState();
}

class _DriverHomePageState extends riverpod.ConsumerState<DriverHomePage> {
  Timer? _queueTimer;

  @override
  void initState() {
    super.initState();
    ref.read(selectedTabProvider.notifier).state = widget.initialTabIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppController();
      _processPendingQueue(initial: true);
      _startQueueTimer();
    });
  }

  @override
  void didUpdateWidget(covariant DriverHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the route query param (?tab=) changes (e.g., from a notification tap),
    // update the selected tab even if this widget state is already alive.
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      ref.read(selectedTabProvider.notifier).state = widget.initialTabIndex;
    }
  }

  void _startQueueTimer() {
    // Retry queue processing disabled for production
    debugPrint('RetryQueue: Queue processing disabled in production mode');
  }

  Future<void> _processPendingQueue({bool initial = false}) async {
    // Retry queue processing disabled for production
    debugPrint('RetryQueue: Queue processing disabled in production mode');
  }

  Future<void> _initializeAppController() async {
    await ref.read(appControllerProvider.notifier).initialize(context);

    if (widget.shouldStartDash && widget.selectedZone != null) {
      await ref
          .read(appControllerProvider.notifier)
          .startShift(selectedZone: widget.selectedZone);
    }
  }

  @override
  void dispose() {
    _queueTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider);
    final selectedIndex = ref.watch(selectedTabProvider);

    // Keep all tabs alive so the Home/search screen isn't disposed when switching tabs.
    // This prevents wave offers + search state from being reset/restarted unexpectedly.
    final tabs = <Widget>[
      const SparkHomeSimpleArabic(),
      const TripsScreen(),
      const WalletHomeScreen(),
      const EarningsScreen(),
      const NotificationsScreen(),
      MoreTab(
        isDashing: appState.driverStatus != DriverStatus.offline,
        onDashStatusChanged: (status) {},
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: selectedIndex,
            children: tabs,
          ),
          if (appState.isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white, // ✅ خلفية بيضاء
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05), // ✅ ظل بسيط جداً في الأعلى
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, -1), // ظل للأعلى فقط
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: selectedIndex,
            onTap: (index) {
              final previousIndex = selectedIndex;
              final fromTab = previousIndex == 0 ? 'home' : previousIndex == 1 ? 'trips' : previousIndex == 2 ? 'wallet' : previousIndex == 3 ? 'earnings' : previousIndex == 4 ? 'notifications' : 'more';
              final toTab = index == 0 ? 'home' : index == 1 ? 'trips' : index == 2 ? 'wallet' : index == 3 ? 'earnings' : index == 4 ? 'notifications' : 'more';
              GlobalAppStateManager().onTabNavigation(fromTab, toTab);
              ref.read(selectedTabProvider.notifier).state = index;
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: HadhirColors.secondary,
            unselectedItemColor: Colors.grey,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'الرئيسية',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.local_taxi_outlined),
                activeIcon: Icon(Icons.local_taxi),
                label: 'رحلاتي',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.wallet_outlined),
                activeIcon: Icon(Icons.wallet),
                label: 'المحفظة',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.attach_money_outlined),
                activeIcon: Icon(Icons.attach_money),
                label: 'أرباحي',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications_outlined),
                activeIcon: Icon(Icons.notifications),
                label: 'الإشعارات',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz_outlined),
                activeIcon: Icon(Icons.more_horiz),
                label: 'المزيد',
              ),
            ],
          ),
        ),
    );
  }
}
