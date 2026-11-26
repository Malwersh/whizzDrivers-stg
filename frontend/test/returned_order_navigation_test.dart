import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/features/active_order/models/active_order_model.dart';
import 'package:wizz_driver/features/active_order/screens/driver_active_order_overview_screen.dart';
import 'package:wizz_driver/features/active_order/services/active_order_service.dart';
import 'package:wizz_driver/providers/riverpod/active_order_provider.dart';

class FinishedService extends ActiveOrderService {
  @override
  Future<ActiveOrder> getOrderById(String id) async => ActiveOrder.fromJson({'orderId':id,'status':'returned','items':[]});
  @override
  Future<ActiveOrder?> getActiveOrder() async => null;
}
void main() {
  for (final byId in [true,false]) {
    testWidgets('terminal overview returns home automatically, byId=$byId', (tester) async {
      SharedPreferences.setMockInitialValues({'active_order':'old-return','order_state':'return_arrived','order_data_old-return':'{}','isSearchingForOffers':true});
      final router=GoRouter(initialLocation:'/active-order',routes:[GoRoute(path:'/',builder:(_,__)=>const Scaffold(body:Text('HOME'))),GoRoute(path:'/active-order',builder:(_,__)=>DriverActiveOrderOverviewScreen(orderId:byId?'old-return':null))]);
      await tester.pumpWidget(ProviderScope(overrides:[activeOrderServiceProvider.overrideWithValue(FinishedService())],child:MaterialApp.router(routerConfig:router)));
      await tester.pumpAndSettle();
      expect(find.text('HOME'),findsOneWidget);
      expect(find.text('الطلب النشط'),findsNothing);
      expect((await SharedPreferences.getInstance()).getBool('isSearchingForOffers'),true);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
  }
}
