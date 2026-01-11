import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/active_order_model.dart';
import '../../../providers/riverpod/active_order_provider.dart';
import '../widgets/store_issue_bottom_sheet.dart';
import '../widgets/cancel_order_dialog.dart';
import '../widgets/unassign_order_bottom_sheet.dart';
import '../../../services/driver_service.dart';

/// شاشة في المطعم - المرحلة 2
class AtRestaurantScreen extends ConsumerStatefulWidget {
  final ActiveOrder order;

  const AtRestaurantScreen({
    super.key,
    required this.order,
  });

  @override
  ConsumerState<AtRestaurantScreen> createState() =>
      _AtRestaurantScreenState();
}

class _AtRestaurantScreenState extends ConsumerState<AtRestaurantScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // تحديث الـ Provider بالطلب الحالي (مهم بعد hot restart)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeOrderProvider.notifier).updateOrder(widget.order);
    });
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => CancelOrderDialog(
        orderId: widget.order.orderId,
        onCancel: (reason, notes) async {
          // استدعاء API الإلغاء من خلال الـ Provider
          final success = await ref
              .read(activeOrderProvider.notifier)
              .cancelOrderByDriver(reason: reason, notes: notes);
          
          if (!success && mounted) {
            throw Exception('فشل في إلغاء الطلب');
          }
        },
      ),
    );
  }

  void _showUnassignBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UnassignOrderBottomSheet(
        orderId: widget.order.orderId,
        onUnassign: (reason) async {
          // استدعاء API فك الارتباط
          final result = await DriverService.unassignActiveOrder(reason);
          
          if (result['success'] == true) {
            if (mounted) {
              // عرض رسالة نجاح
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['message'] ?? 'تم فك الارتباط من الطلب بنجاح'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
              
              // مسح الطلب النشط من الـ Provider
              ref.read(activeOrderProvider.notifier).clearOrder();
              
              // تحديث حالة البحث في SharedPreferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isSearchingForOffers', true);
              await prefs.setString('searchEndTime', 
                DateTime.now().add(const Duration(hours: 2)).toIso8601String());
              
              // العودة للصفحة الرئيسية
              context.go('/');
            }
          } else {
            throw Exception(result['message'] ?? 'فشل في فك الارتباط من الطلب');
          }
        },
      ),
    );
  }

  void _showIssueSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StoreIssueBottomSheet(
        orderId: widget.order.orderId,
        onSubmit: (issueType, notes) async {
          // TODO: Call API to report issue
          // For now, just show success
          await Future.delayed(const Duration(seconds: 1));
          print('Issue reported: $issueType - $notes');
        },
      ),
    );
  }

  Future<void> _pickupOrder() async {
    setState(() => _isLoading = true);

    // 1️⃣ أولاً: تحديث الحالة إلى picked_up
    final pickupSuccess =
        await ref.read(activeOrderProvider.notifier).pickupOrder();

    if (!pickupSuccess) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل تأكيد استلام الطلب. حاول مرة أخرى.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 2️⃣ ثانياً: تحديث الحالة إلى heading_to_customer
    final headingSuccess =
        await ref.read(activeOrderProvider.notifier).startHeadingToCustomer();

    setState(() => _isLoading = false);

    if (headingSuccess && mounted) {
      // 3️⃣ ثالثاً: الانتقال لشاشة التوجه للعميل
      final updatedOrder = ref.read(activeOrderProvider).order;
      if (updatedOrder != null) {
        context.go('/heading-to-customer', extra: updatedOrder);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل بدء التوجه للعميل. حاول مرة أخرى.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('استلام الطلب من المطعم'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.cancel_outlined),
            tooltip: 'إلغاء الطلب',
            onPressed: _showCancelDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Restaurant info card
            _buildRestaurantCard(),

            const SizedBox(height: 16),

            // Order details card
            _buildOrderDetailsCard(),

            const SizedBox(height: 16),

            // Items list
            _buildItemsList(),

            const SizedBox(height: 24),

            // Pickup button
            ElevatedButton(
              onPressed: _isLoading ? null : _pickupOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'تأكيد استلام الطلب',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),

            const SizedBox(height: 12),

            // Unassign button
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _showUnassignBottomSheet,
              icon: const Icon(Icons.link_off_rounded, size: 20),
              label: const Text(
                'فك الارتباط من الطلب',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange, width: 2),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Report issue button
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _showIssueSheet,
              icon: Icon(Icons.report_problem, color: Colors.red[700]),
              label: Text(
                'هناك مشكلة في الطلب',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                side: BorderSide(color: Colors.red[700]!, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.restaurant,
                color: Colors.orange[800],
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.order.restaurantName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.order.restaurantAddress,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                // TODO: Call restaurant
              },
              icon: Icon(Icons.phone, color: Colors.green[700]),
              iconSize: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تفاصيل الطلب',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.receipt,
              'رقم الطلب',
              '#${widget.order.orderNumber ?? widget.order.shortOrderId}',
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.person,
              'اسم العميل',
              widget.order.customerName,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.attach_money,
              'إجمالي المبلغ',
              '${(widget.order.total ?? widget.order.totalAmount).toStringAsFixed(0)} دينار',
              valueColor: Colors.green[700],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.payment,
              'طريقة الدفع',
              widget.order.isCashPayment ? '💵 نقدي' : '💳 بطاقة',
              valueColor: widget.order.isCashPayment
                  ? Colors.green[700]
                  : Colors.blue[700],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الأصناف',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.order.items.length} صنف',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...widget.order.items.map((item) => _buildItemRow(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.orange[100],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${item.quantity}×',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Special instructions removed - not in OrderItem model
              ],
            ),
          ),
          Text(
            '${item.price.toStringAsFixed(0)} د',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ],
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
}
