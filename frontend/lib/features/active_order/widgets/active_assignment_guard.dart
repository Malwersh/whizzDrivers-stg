import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/riverpod/active_order_provider.dart';
import '../models/active_order_model.dart';
import '../services/order_persistence_service.dart';

/// Reconcile a visible pre-pickup trip even when no push notification arrives.
/// Only an authoritative successful read may dismiss the trip.
class ActiveAssignmentGuard extends ConsumerStatefulWidget {
  const ActiveAssignmentGuard(
      {super.key,
      required this.order,
      required this.child,
      this.enabled = true});
  final ActiveOrder order;
  final Widget child;
  final bool enabled;
  @override
  ConsumerState<ActiveAssignmentGuard> createState() =>
      _ActiveAssignmentGuardState();
}

class _ActiveAssignmentGuardState extends ConsumerState<ActiveAssignmentGuard>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _reading = false, _leaving = false;
  static const _beforePickup = {
    'assigned',
    'accepted',
    'ready_for_pickup',
    'heading_to_store',
    'at_store',
    'arrived_at_store',
    'cancelled',
    'canceled'
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _reconcile());
    WidgetsBinding.instance.addPostFrameCallback((_) => _reconcile());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconcile();
    }
  }

  Future<void> _reconcile() async {
    if (!mounted ||
        _reading ||
        _leaving ||
        !widget.enabled ||
        !_beforePickup.contains(widget.order.status)) {
      return;
    }
    final visible = widget.order;
    final local = ref.read(activeOrderProvider).order;
    if (local != null &&
        (local.orderId != visible.orderId ||
            !_beforePickup.contains(local.status))) {
      return;
    }
    _reading = true;
    try {
      final active =
          await ref.read(activeOrderServiceProvider).getActiveOrder();
      if (!mounted ||
          !widget.enabled ||
          widget.order.orderId != visible.orderId ||
          !_beforePickup.contains(widget.order.status)) {
        return;
      }
      final current = ref.read(activeOrderProvider).order;
      if (current != null &&
          (current.orderId != visible.orderId ||
              !_beforePickup.contains(current.status))) {
        return;
      }
      // A different live trip belongs to a newer assignment: never clear it.
      if (active != null &&
          active.orderId == visible.orderId &&
          !{'cancelled', 'canceled'}.contains(active.status)) {
        return;
      }
      _leaving = true;
      await OrderPersistenceService.clearActiveOrder(
          expectedOrderId: visible.orderId);
      if (!mounted) {
        return;
      }
      final latest = ref.read(activeOrderProvider).order;
      if (latest != null && latest.orderId != visible.orderId) {
        _leaving = false;
        return;
      }
      ref.read(activeOrderProvider.notifier).clearOrder();
      final router = GoRouter.of(context);
      final messenger = ScaffoldMessenger.of(context);
      // Replacement screens are also opened through Navigator, not only GoRouter.
      Navigator.of(context, rootNavigator: true)
          .popUntil((route) => route.isFirst);
      if (active != null && active.orderId != visible.orderId) {
        ref.read(activeOrderProvider.notifier).setOrder(active);
        router.go('/active-order', extra: {'orderId': active.orderId});
      } else {
        router.go('/');
      }
      messenger.showSnackBar(const SnackBar(
          backgroundColor: Color(0xFF082C63),
          content: Text(
              'انتهى إسناد هذا الطلب إليك. يمكنك استقبال طلبات جديدة خلال فترة اتصالك.')));
    } catch (_) {
      // Offline/unauthorized/server failure is not evidence of cancellation.
    } finally {
      _reading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
