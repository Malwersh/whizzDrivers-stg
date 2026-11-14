import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/riverpod/active_order_provider.dart';
import '../../../services/driver_service.dart';
import '../models/active_order_model.dart';
import '../services/financial_order_actions.dart';
import '../services/order_persistence_service.dart';
import 'active_trip_summary.dart';
import 'unassign_order_bottom_sheet.dart';

/// The sheet only submits; navigation/cleanup happens after it returns success.
Future<void> showDriverUnassignFlow(
    BuildContext context, WidgetRef ref, ActiveOrder order) async {
  if (!TripStyle.canUnassign(order)) return;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => UnassignOrderBottomSheet(
        orderId: order.orderId,
        onUnassign: (reason) async {
          final result = order.financialAssignment != null
              ? await FinancialOrderActions().send(order.orderId,
                  'financial-unassign', order.financialAssignment!,
                  reason: reason)
              : await DriverService.unassignActiveOrder(reason);
          if (result['success'] != true)
            throw Exception(
                'لم يؤكد الخادم فك الإسناد؛ حدّث الطلب قبل إعادة المحاولة');
        }),
  );
  if (confirmed != true || !context.mounted) return;
  await OrderPersistenceService.clearActiveOrder(
      expectedOrderId: order.orderId);
  if (!context.mounted) return;
  final current = ref.read(activeOrderProvider).order;
  if (current != null && current.orderId != order.orderId) return;
  ref.read(activeOrderProvider.notifier).clearOrder();
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('تم الاعتذار عن التوصيل؛ سيبحث النظام عن سائق بديل')));
  context.go('/');
}
