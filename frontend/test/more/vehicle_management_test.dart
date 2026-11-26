import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/features/more/screens/vehicle_info_screen.dart';
import 'package:wizz_driver/services/driver_vehicle_service.dart';

Map<String, dynamic> data() => {
      'version': 4,
      'initialized': true,
      'activeId': 'a',
      'eligibility': {'eligible': true, 'code': 'ELIGIBLE'},
      'vehicles': [
        {
          'id': 'a',
          'type': 'car',
          'plateNumber': '111',
          'effectiveStatus': 'APPROVED'
        },
        {
          'id': 'b',
          'type': 'motorcycle',
          'plateNumber': '222',
          'effectiveStatus': 'APPROVED'
        },
        {
          'id': 'pending',
          'type': 'car',
          'plateNumber': '333',
          'effectiveStatus': 'PENDING_REVIEW'
        },
      ],
      'documents': [
        {'kind': 'nationalId', 'uploaded': true, 'status': 'APPROVED'}
      ]
    };
void main() {
  testWidgets(
      'sole already approved vehicle is selected before displaying the page',
      (t) async {
    final only = {
      ...data(),
      'activeId': null,
      'vehicles': [(data()['vehicles'] as List).first]
    };
    final calls = <Map<String, dynamic>>[];
    await t.pumpWidget(MaterialApp(
        home: VehicleInfoScreen(
      loadVehicles: () async => only,
      perform: (body) async {
        calls.add(body);
        return {...only, 'activeId': 'a', 'version': 5};
      },
    )));
    await t.pumpAndSettle();
    expect(calls.single, {'action': 'SELECT_DEFAULT', 'expectedVersion': 4});
    expect(find.text('استخدام للعمل'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('multiple vehicles never trigger automatic selection', (t) async {
    var calls = 0;
    await t.pumpWidget(MaterialApp(
        home: VehicleInfoScreen(
      loadVehicles: () async => {...data(), 'activeId': null},
      perform: (_) async {
        calls++;
        return data();
      },
    )));
    await t.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('approved alternate vehicle can be selected; pending one cannot',
      (t) async {
    final calls = <Map<String, dynamic>>[];
    await t.pumpWidget(MaterialApp(
        home: VehicleInfoScreen(
            loadVehicles: () async => data(),
            perform: (body) async {
              calls.add(body);
              return {...data(), 'version': 5, 'activeId': 'b'};
            })));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('استخدام للعمل'), 200);
    expect(find.text('استخدام للعمل'), findsOneWidget);
    await t.ensureVisible(find.text('استخدام للعمل'));
    await t.pumpAndSettle();
    await t.tap(find.text('استخدام للعمل'));
    await t.pumpAndSettle();
    expect(calls.single,
        {'action': 'SELECT', 'expectedVersion': 4, 'vehicleId': 'b'});
    expect(find.text('تم اختيار المركبة للعمل.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'server offline restriction is shown without pretending switch succeeded',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: VehicleInfoScreen(
            loadVehicles: () async => data(),
            perform: (_) async => throw StateError(DriverVehicleService.message(
                'VEHICLE_CHANGE_REQUIRES_OFFLINE')))));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('استخدام للعمل'), 200);
    await t.ensureVisible(find.text('استخدام للعمل'));
    await t.pumpAndSettle();
    await t.tap(find.text('استخدام للعمل'));
    await t.pumpAndSettle();
    expect(find.textContaining('أوقف استقبال الطلبات'), findsWidgets);
    expect(find.text('تم اختيار المركبة للعمل.'), findsNothing);
  });
  testWidgets('removal needs confirmation and can be cancelled without a write',
      (t) async {
    var calls = 0;
    await t.pumpWidget(MaterialApp(
        home: VehicleInfoScreen(
            loadVehicles: () async => data(),
            perform: (_) async {
              calls++;
              return data();
            })));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('إزالة المركبة').first, 200);
    await t.tap(find.text('إزالة المركبة').first);
    await t.pumpAndSettle();
    expect(find.textContaining('يُحفظ سجل الرحلات السابقة'), findsOneWidget);
    await t.tap(find.text('تراجع'));
    await t.pumpAndSettle();
    expect(calls, 0);
  });
}
