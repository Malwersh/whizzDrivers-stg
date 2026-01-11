import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/order_persistence_service.dart';
import '../services/active_order_service.dart';
import '../models/active_order_model.dart';
import '../screens/heading_to_restaurant_screen.dart';
import '../screens/at_restaurant_screen.dart';
import '../screens/heading_to_customer_screen.dart';
import '../screens/at_customer_screen.dart';

/// Helper للتحقق من واستعادة الطلب النشط عند فتح التطبيق
class OrderRestoreHelper {
  /// التحقق من وجود طلب نشط واستعادته
  static Future<void> checkAndRestoreActiveOrder(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      debugPrint('🔍 Checking for active order from server...');
      
      // ✅ استدعاء API مباشرة - الحقيقة الوحيدة هي السيرفر
      final activeOrderService = ActiveOrderService();
      final activeOrder = await activeOrderService.getActiveOrder();
      
      if (activeOrder == null) {
        debugPrint('ℹ️ No active order from server');
        // مسح أي بيانات محلية قديمة
        await OrderPersistenceService.clearActiveOrder();
        return;
      }

      debugPrint('✅ Active order found: ${activeOrder.orderId} (status: ${activeOrder.status})');
      
      // ✅ عرض BottomSheet للسائق
      if (!context.mounted) return;
      
      final shouldContinue = await showActiveOrderBottomSheet(
        context: context,
        order: activeOrder,
      );

      if (!context.mounted) return;

      if (shouldContinue == true) {
        // ✅ السائق اختار المتابعة - الانتقال للشاشة المناسبة
        debugPrint('✅ Driver chose to continue active order');
        await _navigateToOrderScreen(context, activeOrder);
        
        // ✅ حفظ محلياً كـ backup فقط
        await OrderPersistenceService.saveActiveOrder(
          orderId: activeOrder.orderId,
          status: activeOrder.status,
          orderData: activeOrder.toJson(),
        );
      } else if (shouldContinue == false) {
        // ❌ السائق اختار الإلغاء
        debugPrint('⚠️ Driver chose to cancel active order');
        await OrderPersistenceService.clearActiveOrder();
        // TODO: يمكن إضافة API call لإلغاء الطلب من السيرفر
      }

    } catch (e) {
      debugPrint('❌ Error checking active order: $e');
      // في حالة الخطأ، مسح البيانات المحلية
      await OrderPersistenceService.clearActiveOrder();
    }
  }

  /// الانتقال للشاشة المناسبة حسب حالة الطلب
  static Future<void> _navigateToOrderScreen(
    BuildContext context,
    ActiveOrder order,
  ) async {
    if (!context.mounted) return;

    Widget screen;
    
    switch (order.status) {
      case 'ready_for_pickup':
      case 'accepted':
      case 'assigned':
      case 'heading_to_store':
        screen = HeadingToRestaurantScreen(order: order);
        break;
        
      case 'at_store':
      case 'arrived_at_store':
        screen = AtRestaurantScreen(order: order);
        break;
        
      case 'picked_up':
      case 'heading_to_customer':
        screen = HeadingToCustomerScreen(order: order);
        break;
        
      case 'at_customer':
      case 'arrived_at_customer':
        screen = AtCustomerScreen(order: order);
        break;
        
      case 'delivered':
      case 'completed':
        // الطلب مكتمل، مسح البيانات المحلية
        await OrderPersistenceService.clearActiveOrder();
        debugPrint('ℹ️ Order already completed');
        return;
        
      default:
        // حالة غير معروفة
        debugPrint('⚠️ Unknown order status: ${order.status}');
        return;
    }

    // الانتقال للشاشة المناسبة
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => screen),
    );

    debugPrint('➡️ Navigated to: ${order.status}');
  }

  /// عرض BottomSheet لإعلام السائق بالطلب النشط
  static Future<bool?> showActiveOrderBottomSheet({
    required BuildContext context,
    required ActiveOrder order,
  }) async {
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // أيقونة وعنوان
              const Icon(
                Icons.delivery_dining,
                size: 64,
                color: Color(0xFFFFD700), // لون أصفر
              ),
              const SizedBox(height: 16),
              const Text(
                '🚗 لديك طلب نشط',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // معلومات الطلب
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('المرحلة', _getStatusLabel(order.status)),
                    const Divider(height: 16),
                    _buildInfoRow('المطعم', order.restaurantName),
                    const Divider(height: 16),
                    _buildInfoRow('رقم الطلب', '#${order.orderId.substring(0, 8)}'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // الرسالة
              Text(
                'هل تريد متابعة رحلة هذا الطلب؟',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // الأزرار
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'إلغاء الطلب',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFFFFD700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'متابعة الطلب',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
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

  /// بناء صف معلومات
  static Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  /// الحصول على نص مفهوم لحالة الطلب
  static String _getStatusLabel(String status) {
    switch (status) {
      case 'ready_for_pickup':
        return 'جاهز للاستلام';
      case 'accepted':
      case 'assigned':
        return 'تم قبول الطلب';
      case 'heading_to_store':
        return 'في الطريق للمطعم';
      case 'at_store':
      case 'arrived_at_store':
        return 'وصلت للمطعم';
      case 'picked_up':
        return 'تم استلام الطلب';
      case 'heading_to_customer':
        return 'في الطريق للعميل';
      case 'at_customer':
      case 'arrived_at_customer':
        return 'وصلت للعميل';
      case 'delivered':
        return 'تم التسليم';
      case 'completed':
        return 'مكتمل';
      default:
        return status;
    }
  }
}
