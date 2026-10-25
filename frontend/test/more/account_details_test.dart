import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/models/driver_profile.dart';
import 'package:wizz_driver/features/more/screens/account_details_screen.dart';

DriverProfile profile({bool rated = false}) => DriverProfile.fromJson({
      'driverId': 'test',
      'name': 'سائق الاختبار',
      'city': 'النجف',
      'phone': '+9647800000000',
      'status': 'APPROVED',
      'nationalId': 'PENDING',
      'licenseNumber': 'PENDING',
      'rating': 5.0,
      if (rated) 'customerRating': 4.5,
      if (rated) 'customerRatingCount': 2,
    });
void main() {
  testWidgets('unknown ratings and documents are not zero or verified facts',
      (tester) async {
    tester.view.physicalSize = const Size(480, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: AccountDetailsScreen(loadProfile: () async => profile())));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0.0'), findsNothing);
    expect(find.text('PENDING'), findsNothing);
    await tester.scrollUntilVisible(find.text('التحقق من الوثائق'), 250);
    expect(find.text('لا تتوفر نتيجة تحقق موثقة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('verified rating, responsive layout and save failure',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!),
        home: AccountDetailsScreen(
            loadProfile: () async => profile(rated: true),
            saveProfile: (_) async => false)));
    await tester.pumpAndSettle();
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('عدد التقييمات: 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('تعديل'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('حفظ التعديلات'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('حفظ التعديلات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ التعديلات'));
    await tester.pumpAndSettle();
    expect(find.text('تعذر حفظ التعديلات. حاول مرة أخرى.'), findsOneWidget);
    expect(find.text('إلغاء'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('load failure offers retry', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: AccountDetailsScreen(loadProfile: () async => null)));
    await tester.pumpAndSettle();
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });
}
