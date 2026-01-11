import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/app_colors.dart';
import '../../../design_system/colors.dart';
import '../../../providers/riverpod/driver_connection_provider.dart';

/// Widget for displaying incoming orders
class IncomingOrderWidget extends ConsumerWidget {
  const IncomingOrderWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingOrders = ref.watch(incomingOrdersProvider);
    final actions = ref.watch(driverConnectionActionsProvider);

    return incomingOrders.when(
      data: (orderData) => _buildOrderCard(context, orderData, actions),
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> orderData, DriverConnectionActions actions) {
    if (orderData['type'] != 'new_order') {
      return const SizedBox.shrink();
    }

    final order = orderData['order'];
    final orderId = order['id']?.toString() ?? '';
    final customerName = order['customer_name'] ?? 'عميل';
    final restaurantName = order['restaurant_name'] ?? 'مطعم';
    final deliveryAddress = order['delivery_address'] ?? 'عنوان التوصيل';
    final orderTotal = order['total']?.toString() ?? '0';
    final estimatedDistance = order['estimated_distance']?.toString() ?? 'غير محدد';

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 0, // Remove elevation for monochrome design
        color: Colors.white, // Monochrome: white background
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: HadhirColors.brandingYellow, // Yellow border accent
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.delivery_dining,
                    color: Colors.black,
                    size: 32,
                  ), // Monochrome: black icon
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'طلب جديد!',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.black, // Monochrome: black text
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'رقم الطلب: $orderId',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black.withValues(
                                  alpha: 0.7,
                                ), // Monochrome: dark gray text
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Order Details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(
                    alpha: 0.1,
                  ), // Monochrome: light gray background
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: HadhirColors.brandingGreen.withOpacity(
                      0.3,
                    ), // Subtle green border
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    _buildOrderRow(Icons.restaurant, 'المطعم', restaurantName),
                    const SizedBox(height: 8),
                    _buildOrderRow(Icons.person, 'العميل', customerName),
                    const SizedBox(height: 8),
                    _buildOrderRow(Icons.location_on, 'عنوان التوصيل', deliveryAddress),
                    const SizedBox(height: 8),
                    _buildOrderRow(Icons.monetization_on, 'المبلغ الإجمالي', '$orderTotal د.ع'),
                    const SizedBox(height: 8),
                    _buildOrderRow(Icons.route, 'المسافة المقدرة', '$estimatedDistance كم'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => actions.acceptOrder(orderId),
                      icon: const Icon(Icons.check),
                      label: const Text('قبول الطلب'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(context, orderId, actions),
                      icon: const Icon(Icons.close),
                      label: const Text('رفض الطلب'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.white,
                        side: const BorderSide(color: AppColors.white),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.white, size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _showRejectDialog(BuildContext context, String orderId, DriverConnectionActions actions) {
    final reasons = [
      'بعيد جداً',
      'مشغول حالياً',
      'مشكلة في المركبة',
      'سبب آخر',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سبب رفض الطلب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((reason) => ListTile(
            title: Text(reason),
            onTap: () {
              Navigator.of(context).pop();
              actions.rejectOrder(orderId, reason);
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }
}
