import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wizz_driver/widgets/location_permission_notice.dart';

Widget app(Widget child, {double textScale = 1}) => MaterialApp(
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!),
    home: Scaffold(
        body: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(16), child: child)))));
void main() {
  testWidgets('full permission with enabled location hides the notice',
      (tester) async {
    await tester.pumpWidget(app(LocationPermissionNotice(
        readAccess: () async => const DriverLocationAccess(
            serviceEnabled: true, permission: LocationPermission.always))));
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
    expect(find.textContaining('طلبات أكثر'), findsNothing);
  });
  testWidgets(
      'disabled service opens device location settings even when permission is always',
      (tester) async {
    var location = 0, application = 0;
    await tester.pumpWidget(app(LocationPermissionNotice(
        readAccess: () async => const DriverLocationAccess(
            serviceEnabled: false, permission: LocationPermission.always),
        openLocationSettings: () async {
          location++;
          return true;
        },
        openAppSettings: () async {
          application++;
          return true;
        })));
    await tester.pumpAndSettle();
    expect(find.text('خدمات الموقع متوقفة'), findsOneWidget);
    await tester.tap(find.text('فتح إعدادات الموقع'));
    await tester.pumpAndSettle();
    expect(location, 1);
    expect(application, 0);
  });
  for (final permission in [
    LocationPermission.whileInUse,
    LocationPermission.denied,
    LocationPermission.deniedForever
  ]) {
    testWidgets(
        '$permission opens application settings without changing permission automatically',
        (tester) async {
      var opened = 0;
      await tester.pumpWidget(app(LocationPermissionNotice(
          readAccess: () async => DriverLocationAccess(
              serviceEnabled: true, permission: permission),
          openAppSettings: () async {
            opened++;
            return true;
          })));
      await tester.pumpAndSettle();
      expect(find.text('فتح إعدادات التطبيق'), findsOneWidget);
      await tester.tap(find.text('فتح إعدادات التطبيق'));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.textContaining('طلبات أكثر'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'returning from settings rereads actual permission and hides resolved notice',
      (tester) async {
    var permission = LocationPermission.whileInUse;
    await tester.pumpWidget(app(LocationPermissionNotice(
        readAccess: () async => DriverLocationAccess(
            serviceEnabled: true, permission: permission))));
    await tester.pumpAndSettle();
    expect(find.text('فتح إعدادات التطبيق'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    permission = LocationPermission.always;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
  });
  testWidgets('checking and settings failures remain truthful and retryable',
      (tester) async {
    var fails = true;
    await tester.pumpWidget(app(LocationPermissionNotice(
        readAccess: () async {
          if (fails) throw StateError('unavailable');
          return const DriverLocationAccess(
              serviceEnabled: true, permission: LocationPermission.denied);
        },
        openAppSettings: () async => false)));
    await tester.pumpAndSettle();
    expect(find.text('تعذر فحص صلاحيات الموقع'), findsOneWidget);
    fails = false;
    await tester.tap(find.text('إعادة التحقق'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح إعدادات التطبيق'));
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذر فتح الإعدادات.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unknown permission is retryable rather than a false denial',
      (tester) async {
    await tester.pumpWidget(app(LocationPermissionNotice(
        readAccess: () async => const DriverLocationAccess(
            serviceEnabled: true,
            permission: LocationPermission.unableToDetermine))));
    await tester.pumpAndSettle();
    expect(find.text('تعذر فحص صلاحيات الموقع'), findsOneWidget);
    expect(find.text('إعادة التحقق'), findsOneWidget);
  });
  testWidgets('pending permission read is safe when widget is disposed',
      (tester) async {
    final pending = Completer<DriverLocationAccess>();
    await tester.pumpWidget(
        app(LocationPermissionNotice(readAccess: () => pending.future)));
    await tester.pumpWidget(const SizedBox());
    pending.complete(const DriverLocationAccess(
        serviceEnabled: true, permission: LocationPermission.always));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('notice remains readable on narrow screens with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(
        LocationPermissionNotice(
            readAccess: () async => const DriverLocationAccess(
                serviceEnabled: true,
                permission: LocationPermission.whileInUse)),
        textScale: 1.6));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
