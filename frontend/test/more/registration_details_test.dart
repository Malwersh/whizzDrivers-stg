import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/models/driver_profile.dart';
import 'package:wizz_driver/features/more/screens/account_details_screen.dart';
import 'package:wizz_driver/features/more/screens/vehicle_info_screen.dart';
import 'package:wizz_driver/features/more/screens/registration_details_widgets.dart';

DriverProfile registered() => DriverProfile.fromJson({
      'driverId': 'd',
      'name': 'سائق الاختبار',
      'profileSchemaVersion': 2,
      'status': 'APPROVED',
      'isVerified': true,
      'city': 'Baghdad',
      'governorate_name': 'النجف',
      'work_region_name': 'الحيرة',
      'work_region_id': 'region',
      'home_address_text': 'قرب المدرسة',
      'vehicleType': 'motorcycle',
      'registrationPaperUrl': 's3://private/registration',
      'drivingLicenseUrl': 's3://private/license',
      'nationalIdUrl': 's3://private/id',
    });

Map<String, dynamic> vehicleData() => {
      'version': 1,
      'initialized': true,
      'activeId': null,
      'eligibility': {'eligible': false, 'code': 'ACTIVE_VEHICLE_NOT_APPROVED'},
      'vehicles': [
        {
          'id': 'one',
          'type': 'motorcycle',
          'plateNumber': '123',
          'effectiveStatus': 'PENDING_REVIEW',
          'review': null
        }
      ],
      'documents': [],
    };

void main() {
  test(
      'registration fields and canonical document survive copying and serialization',
      () {
    final p = DriverProfile.fromJson(
        registered().copyWith(name: 'اسم جديد').toJson());
    expect(p.profileSchemaVersion, 2);
    expect(p.governorateName, 'النجف');
    expect(p.workRegionName, 'الحيرة');
    expect(p.workRegionId, 'region');
    expect(p.landmark, 'قرب المدرسة');
    expect(p.vehicleRegistrationUrl, 's3://private/registration');
    expect(p.vehicleRegistrationStatus, isNull);
  });
  test('upload and individual review are independent of account approval', () {
    expect(registrationDocumentState(registered().vehicleRegistrationUrl, null),
        'مرفوعة · لم تُسجّل نتيجة المراجعة');
    expect(registrationDocumentState(null, 'VERIFIED'), 'لم تُرفع الوثيقة');
    expect(registrationDocumentState('url', 'APPROVED'), 'مرفوعة · معتمدة');
    expect(registrationDocumentState('url', 'REJECTED'),
        'مرفوعة · تحتاج إلى تصحيح');
  });
  testWidgets(
      'schema2 account shows registered region instead of stale free-text city',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: AccountDetailsScreen(loadProfile: () async => registered())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('منطقة العمل المسجلة'), 220);
    expect(find.text('Baghdad'), findsNothing);
    await tester.scrollUntilVisible(find.text('قرب المدرسة'), 100);
    expect(find.text('قرب المدرسة'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('سنوية المركبة'), 150);
    expect(find.text('رقم إجازة السوق'), findsNothing);
    expect(find.text('مرفوعة · لم تُسجّل نتيجة المراجعة'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'vehicle screen reads actual registration without invented insurance or plate',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: VehicleInfoScreen(loadVehicles: () async => vehicleData())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('دراجة نارية ·'), 150);
    expect(find.textContaining('دراجة نارية ·'), findsOneWidget);
    expect(find.textContaining('Insurance'), findsNothing);
    expect(find.textContaining('Model'), findsNothing);
    expect(find.text('قيد المراجعة'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('vehicle load failure is not rendered as missing registration',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: VehicleInfoScreen(
            loadVehicles: () async => throw StateError("network"))));
    await tester.pumpAndSettle();
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.text('لم تُرفع الوثيقة'), findsNothing);
  });
}
