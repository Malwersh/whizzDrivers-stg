import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/design_system/app_theme.dart';
import 'package:wizz_driver/features/more/more_tab.dart';
import 'package:wizz_driver/features/earnings/earnings_screen.dart';
import 'package:wizz_driver/features/more/screens/driver_performance_screen.dart';
import 'package:wizz_driver/features/more/screens/live_chat_screen.dart';
import 'package:wizz_driver/features/wallet/screens/wallet_home_screen.dart';
import 'package:wizz_driver/l10n/app_localizations.dart';
import 'package:wizz_driver/models/driver_profile.dart';

DriverProfile profile({String name = 'Mohammed Daash', int count = 0}) =>
    DriverProfile.fromJson({
      'driverId': 'fixture-driver',
      'name': name,
      'createdAt': '2026-10-01T00:00:00Z',
      'isVerified': true,
      'customerRating': count > 0 ? 4.8 : null,
      'customerRatingCount': count,
    });
Widget app(Widget child, {ThemeData? theme}) => ProviderScope(
    child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme ?? AppTheme.lightTheme,
        home: child));
void main() {
  testWidgets(
      'profile separates rating and join date without manufactured rating',
      (tester) async {
    await tester.pumpWidget(app(MoreTab(loadProfile: () async => profile())));
    await tester.pumpAndSettle();
    expect(find.text('Mohammed Daash'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('انضممت في أكتوبر 2026'), findsOneWidget);
    expect(find.textContaining('Driver since'), findsNothing);
    expect(find.textContaining('4.9'), findsNothing);
    expect(find.byTooltip('تحديث الحساب'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'existing performance support and real wallet destinations are retained',
      (tester) async {
    await tester
        .pumpWidget(app(MoreTab(loadProfile: () async => profile(count: 2))));
    await tester.pumpAndSettle();
    expect(find.text('4.8'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.textContaining('2 تقييم'), findsNothing);
    // Inspect route construction without mounting money/support screens or making API calls.
    final routes = <Route<dynamic>>[];
    final observer = _Observer(routes);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            navigatorObservers: [observer],
            home: MoreTab(loadProfile: () async => profile()))));
    await tester.pumpAndSettle();
    final local = AppLocalizations.of(tester.element(find.byType(MoreTab)))!;
    for (final spec in [
      (local.wallet, WalletHomeScreen),
      (local.earnings, EarningsScreen),
      ('أدائي', DriverPerformanceScreen),
      (local.liveChat, LiveChatScreen)
    ]) {
      await tester.scrollUntilVisible(find.text(spec.$1), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(spec.$1));
      await tester.pumpAndSettle();
      // Inspect the pushed route and pop it before pumping/mounting service screens.
      await tester.tap(find.text(spec.$1));
      final route = routes.last as MaterialPageRoute<dynamic>;
      final built = route.builder(tester.element(find.byType(MoreTab)));
      expect(built.runtimeType, spec.$2);
      route.navigator!.pop();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'unsupported menu entries cannot open dummy pages or claim actions succeeded',
      (tester) async {
    final routes = <Route<dynamic>>[];
    final observer = _Observer(routes);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            navigatorObservers: [observer],
            home:
                MoreTab(isDashing: true, loadProfile: () async => profile()))));
    await tester.pumpAndSettle();
    final local = AppLocalizations.of(tester.element(find.byType(MoreTab)))!;
    for (final title in [
      local.paymentMethods,
      local.instantPay,
      local.deliveryEquipment,
      local.phoneNumber,
      local.safetyToolkit,
      local.emergencyContacts,
      local.identityVerification,
      local.termsOfService,
      local.privacyPolicy,
      local.occupationalAccidentPolicy,
      local.settings,
      local.wizzOff
    ]) {
      await tester.scrollUntilVisible(find.text(title), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(title));
      await tester.pumpAndSettle();
      final row = find
          .ancestor(of: find.text(title), matching: find.byType(InkWell))
          .first;
      expect(tester.widget<InkWell>(row).onTap, isNull, reason: title);
    }
    expect(routes.length, 1);
    expect(find.text('Zain Cash'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('refresh updates profile and disposal during loading is safe',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(app(MoreTab(loadProfile: () async {
      calls++;
      return profile(name: 'حساب $calls');
    })));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('تحديث الحساب'));
    await tester.pumpAndSettle();
    expect(find.text('حساب 2'), findsOneWidget);
    await tester.pumpWidget(app(MoreTab(
        key: const ValueKey('slow'),
        loadProfile: () async {
          await Future<void>.delayed(const Duration(seconds: 1));
          return profile();
        })));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('narrow large-text layout preserves profile and section labels',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!),
            home: MoreTab(
                loadProfile: () async => profile(
                    name: 'محمد علي محمد اسم طويل لاختبار العرض',
                    count: 100)))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('أدائي'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('portrait fixture can be visually inspected', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('MorePreviewArabic')
      ..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final theme = AppTheme.lightTheme;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: app(MoreTab(loadProfile: () async => profile()),
            theme: theme.copyWith(
                textTheme:
                    theme.textTheme.apply(fontFamily: 'MorePreviewArabic')))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final output = Platform.environment['MORE_SCREENSHOT'];
    if (output != null) {
      await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(output).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}

class _Observer extends NavigatorObserver {
  final List<Route<dynamic>> routes;
  _Observer(this.routes);
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    routes.add(route);
  }
}
