import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/features/home/widgets/map_tools.dart';
import 'package:wizz_driver/features/home/widgets/map_demand_sheet.dart';
import 'package:wizz_driver/features/demand/demand_service.dart';
import 'package:wizz_driver/models/map_data.dart';
import 'package:wizz_driver/providers/riverpod/tab_provider.dart';

NearbyStore store(String id, String name, double lat) => NearbyStore.fromJson(
    {'store_id': id, 'name': name, 'lat': lat, 'lng': 44.4});

class Forecast extends DemandService {
  @override
  Future<Map<String, dynamic>> load() async => {
        'success': true,
        'isTestData': true,
        'timezone': 'Asia/Baghdad',
        'area': {'name': 'مركز المناذرة'},
        'days': List.generate(
            7,
            (d) => {
                  'date': DateTime(2026, 10, 28 + d)
                      .toIso8601String()
                      .substring(0, 10),
                  'slots': List.generate(16,
                      (h) => {'hour': h + 6, 'score': h % 3, 'level': 'LOW'})
                })
      };
}

void main() {
  test('map policy and service phone come from central response', () {
    final data = MapDataResponse.fromJson({
      'map_tools': {
        'customerServicePhone': '+9647831367435',
        'heatEnabled': false,
        'busyMinimumReady': 5,
        'refreshSeconds': 60
      }
    });
    expect(data.customerServicePhone, '+9647831367435');
    expect(data.mapTools?['heatEnabled'], isFalse);
    expect(data.mapTools?['busyMinimumReady'], 5);
  });

  test('Arabic search is normalized and bad coordinates cannot move camera',
      () {
    final rows = [
      store('a', 'أسواق الحيرة', 31.9),
      store('b', 'مطعم المدينة', 31.8),
      store('bad', 'أسواق', 100)
    ];
    expect(matchingMapStores(rows, 'اسواق').map((s) => s.storeId), ['a']);
    expect(matchingMapStores(rows, 'المدينه').single.storeId, 'b');
  });
  test('More stable links survive bottom bar removal', () {
    expect(DriverTabs.bottomVisible, [0, 1, 2, 4]);
    expect(DriverTabs.position(5), 4);
    expect(DriverTabs.normalize(3), 5);
    expect(DriverTabs.bottomPosition(5), 0);
  });
  testWidgets(
      'compact circular tools have accessible labels and real callbacks',
      (t) async {
    int taps = 0;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DriverMapButton(
                icon: Icons.search,
                label: 'بحث المتاجر',
                onPressed: () => taps++))));
    await t.tap(find.byTooltip('بحث المتاجر'));
    expect(taps, 1);
    expect(t.getSize(find.byType(InkWell)), const Size(52, 52));
  });
  testWidgets('search filters nearby stores and returns the selected store',
      (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetViewInsets);
    NearbyStore? picked;
    await t.pumpWidget(MaterialApp(
        home: Builder(
            builder: (c) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      picked = await showModalBottomSheet<NearbyStore>(
                          context: c,
                          isScrollControlled: true,
                          builder: (_) => MapStoreSearchSheet(stores: [
                                store('a', 'أسواق الحيرة', 31.9),
                                store('b', 'مطعم المدينة', 31.9)
                              ]));
                    },
                    child: const Text('بحث'))))));
    await t.tap(find.text('بحث'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'اسواق');
    await t.pumpAndSettle();
    expect(find.text('مطعم المدينة'), findsNothing);
    await t.tap(find.text('أسواق الحيرة'));
    await t.pumpAndSettle();
    expect(picked?.storeId, 'a');
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'seven-day statistics scroll on a narrow RTL screen and label test data',
      (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: MapDemandSheet(service: Forecast()))));
    await t.pumpAndSettle();
    expect(find.text('بيانات تجريبية'), findsOneWidget);
    expect(find.textContaining('توقع لسبعة أيام'), findsOneWidget);
    await t.drag(find.byType(ListView).first, const Offset(0, -600));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
