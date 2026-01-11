import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/active_order_model.dart';
import '../../../providers/riverpod/active_order_provider.dart';
import '../widgets/order_status_timeline.dart';
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
      await ref.read(activeOrderProvider.notifier).fetchOrderById(widget.orderId!);
    } else {
      await ref.read(activeOrderProvider.notifier).fetchActiveOrder();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // منع الرجوع للخلف
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false, // إخفاء زر الرجوع
          title: const Text(
            'الطلب النشط',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.blue,
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
                        onPressed: () => ref.read(activeOrderProvider.notifier).fetchActiveOrder(),
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
              onRefresh: () => ref.read(activeOrderProvider.notifier).fetchActiveOrder(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Restaurant Header
                    _buildRestaurantHeader(order),

                    const SizedBox(height: 16),

                    // Order Info Card
                    _buildOrderInfoCard(order),

                    const SizedBox(height: 16),

                    // Status Timeline
                    OrderStatusTimeline(currentStatus: order.status),

                    const SizedBox(height: 24),

                    // Main Action Button
                    _buildMainActionButton(context, order, orderState.isLoading),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRestaurantHeader(ActiveOrder order) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.orange[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.restaurant,
            size: 28,
            color: Colors.orange[800],
          ),
        ),
        title: Text(
          order.restaurantName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'رقم الطلب: #${order.orderNumber ?? order.shortOrderId}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderInfoCard(ActiveOrder order) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معلومات الطلب',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.person,
              'العميل',
              order.customerName,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.attach_money,
              'القيمة',
              '${(order.total ?? order.totalAmount).toStringAsFixed(2)} دينار',
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.payment,
              'طريقة الدفع',
              order.isCashPayment ? '💵 نقدي' : '💳 بطاقة',
              valueColor:
                  order.isCashPayment ? Colors.green[700] : Colors.blue[700],
            ),
            if (order.isCashPayment) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تذكير: استلم المبلغ من العميل عند التسليم',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.amber[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildMainActionButton(
    BuildContext context,
    ActiveOrder order,
    bool isLoading,
  ) {
    String buttonText;
    VoidCallback? onPressed;
    Color buttonColor = Colors.blue;

    switch (order.status) {
      case 'accepted':
      case 'assigned':  // الحالة التي تأتي من API عند قبول الطلب
        buttonText = 'انطلق إلى المطعم';
        onPressed = () async {
          // ✅ تحديث حالة الطلب في قاعدة البيانات أولاً
          final success = await ref.read(activeOrderProvider.notifier).startHeadingToStore();
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
        buttonColor = Colors.green;
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
        buttonColor = Colors.orange;
        break;

      case 'picked_up':
        buttonText = 'انطلق إلى العميل';
        onPressed = () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => HeadingToCustomerScreen(order: order),
            ),
          );
        };
        buttonColor = Colors.green;
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
        buttonColor = Colors.purple;
        break;

      case 'delivered':
      case 'completed':
        buttonText = 'تم التسليم ✓';
        onPressed = null;
        buttonColor = Colors.green;
        break;

      default:
        // الحالة الافتراضية - بداية الرحلة
        buttonText = 'بدء التوصيل';
        onPressed = () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => HeadingToRestaurantScreen(order: order),
            ),
          );
        };
        buttonColor = Colors.blue;
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
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
                color: Colors.white,
              ),
            ),
    );
  }
}
