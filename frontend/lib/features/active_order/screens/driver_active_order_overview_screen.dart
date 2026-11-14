import 'package:go_router/go_router.dart';
import '../services/order_persistence_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/active_order_model.dart';
import '../../../providers/riverpod/active_order_provider.dart';
import '../widgets/active_trip_summary.dart';
import '../widgets/driver_unassign_flow.dart';
import 'heading_to_restaurant_screen.dart';
import 'at_restaurant_screen.dart';
import 'heading_to_customer_screen.dart';
import 'at_customer_screen.dart';

/// شاشة ملخص الطلب النشط - المركز الرئيسي للتحكم
class DriverActiveOrderOverviewScreen extends ConsumerStatefulWidget {
  final String? orderId;

  const DriverActiveOrderOverviewScreen({
    super.key,
    this.orderId,
  });

  @override
  ConsumerState<DriverActiveOrderOverviewScreen> createState() =>
      _DriverActiveOrderOverviewScreenState();
}

class _DriverActiveOrderOverviewScreenState
    extends ConsumerState<DriverActiveOrderOverviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrder();
    });
  }

  Future<void> _loadOrder() async {
    if (widget.orderId != null) {
      await ref
          .read(activeOrderProvider.notifier)
          .fetchOrderById(widget.orderId!);
    } else {
      await ref.read(activeOrderProvider.notifier).fetchActiveOrder();
    }
    if (!mounted) return;
    final state = ref.read(activeOrderProvider);
    if (state.error == null &&
        (state.order == null ||
            ['returned', 'delivered', 'completed', 'cancelled']
                .contains(state.order!.status))) {
      if (state.order != null) {
        await OrderPersistenceService.clearActiveOrder(
            expectedOrderId: state.order!.orderId);
        if (!mounted) return;
        if (ref.read(activeOrderProvider).order?.orderId ==
            state.order!.orderId) {
          ref.read(activeOrderProvider.notifier).clearOrder();
        }
      }
      if (mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // منع الرجوع للخلف
      child: Scaffold(
        backgroundColor: TripStyle.background,
        appBar: AppBar(
          automaticallyImplyLeading: false, // إخفاء زر الرجوع
          title: const Text(
            'الطلب النشط',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: TripStyle.ink,
          elevation: 0,
        ),
        body: Builder(
          builder: (context) {
            final orderState = ref.watch(activeOrderProvider);

            // Loading
            if (orderState.isLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'جاري تحميل بيانات الطلب...',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            // Error
            if (orderState.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'حدث خطأ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        orderState.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => ref
                            .read(activeOrderProvider.notifier)
                            .fetchActiveOrder(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // No active order
            if (orderState.order == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا يوجد طلب نشط',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'لم يتم العثور على طلب نشط حالياً',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Success - Show order details
            final order = orderState.order!;

            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(activeOrderProvider.notifier).fetchActiveOrder(),
              child: ActiveTripSummary(
                order: order,
                action: _buildMainActionButton(
                    context, order, orderState.isLoading),
                onUnassign: orderState.isLoading
                    ? null
                    : () => showDriverUnassignFlow(context, ref, order),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainActionButton(
    BuildContext context,
    ActiveOrder order,
    bool isLoading,
  ) {
    String buttonText;
    VoidCallback? onPressed;

    switch (order.status) {
      case 'accepted':
      case 'assigned': // الحالة التي تأتي من API عند قبول الطلب
        buttonText = 'انطلق إلى المطعم';
        onPressed = () async {
          // ✅ تحديث حالة الطلب في قاعدة البيانات أولاً
          final success = await ref
              .read(activeOrderProvider.notifier)
              .startHeadingToStore();
          if (success && mounted) {
            // ثم الانتقال لشاشة التوجه
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => HeadingToRestaurantScreen(
                  order: ref.read(activeOrderProvider).order!,
                ),
              ),
            );
          } else if (mounted) {
            // في حالة الفشل
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('فشل في بدء التوجه. حاول مرة أخرى'),
                backgroundColor: Colors.red,
              ),
            );
          }
        };
        break;

      case 'heading_to_store':
        buttonText = 'متابعة الطريق إلى المطعم';
        onPressed = () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HeadingToRestaurantScreen(order: order)));
        break;

      case 'at_store':
      case 'arrived_at_store':
        buttonText = 'استلام الطلب';
        onPressed = () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AtRestaurantScreen(order: order),
            ),
          );
        };
        break;

      case 'heading_to_customer':
      case 'picked_up':
        buttonText = 'انطلق إلى العميل';
        onPressed = () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => HeadingToCustomerScreen(order: order),
            ),
          );
        };
        break;

      case 'at_customer':
      case 'arrived_at_customer':
        buttonText = 'تسليم الطلب';
        onPressed = () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AtCustomerScreen(order: order),
            ),
          );
        };
        break;

      case 'delivered':
      case 'completed':
        buttonText = 'تم التسليم ✓';
        onPressed = null;
        break;

      default:
        buttonText = 'حدّث حالة الطلب للمتابعة';
        onPressed = _loadOrder;
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: TripStyle.yellow,
        foregroundColor: TripStyle.ink,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              buttonText,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: TripStyle.ink,
              ),
            ),
    );
  }
}
