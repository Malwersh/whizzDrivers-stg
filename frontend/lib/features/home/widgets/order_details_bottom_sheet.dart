import 'package:flutter/material.dart';
import '../../../models/wave_offer.dart';

// ألوان التطبيق
class AppColors {
  static const Color primary = Color(0xFFFDC500); // اللون الأساسي - أصفر ذهبي
  static const Color secondary = Color(0xFF00296B); // اللون الثانوي - أزرق داكن
  static const Color accent = Color(0xFF00c1e8); // لون مساعد - أزرق فاتح
}

class OrderDetailsBottomSheet extends StatelessWidget {
  final WaveOffer offer;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const OrderDetailsBottomSheet({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text(
                  'تفاصيل الطلب',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Earnings breakdown
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // العنوان والإجمالي
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'تفاصيل الأرباح',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${offer.estimatedEarnings.toStringAsFixed(0)} ${offer.currency}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // خط فاصل
                        Divider(color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        
                        // التفاصيل
                        _buildEarningsRow('الأساسي', '${offer.deliveryFee.toStringAsFixed(0)} ${offer.currency}'),
                        
                        // المكافأة (البونص) - إذا وُجدت
                        if (offer.bonusAmount > 0)
                          _buildEarningsRow(
                            'المكافأة (البونص)', 
                            '+${offer.bonusAmount.toStringAsFixed(0)} ${offer.currency}',
                          ),
                        
                        // الإكرامية - دائماً تُعرض
                        _buildEarningsRow(
                          'الإكرامية (tip)', 
                          offer.tip > 0 
                              ? '+${offer.tip.toStringAsFixed(0)} ${offer.currency}'
                              : '0 ${offer.currency}',
                        ),
                        
                        const SizedBox(height: 8),
                        Divider(color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        
                        // الإجمالي
                        _buildEarningsRow(
                          'الإجمالي',
                          '${offer.estimatedEarnings.toStringAsFixed(0)} ${offer.currency}',
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Trip details
                  const Text(
                    'تفاصيل الرحلة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              '${offer.distance.toStringAsFixed(1)} كم',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              ' • ',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                            Text(
                              '${offer.estimatedMinutes} دقيقة',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _showOrderItemsBottomSheet(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${offer.itemsCount} عنصر',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: AppColors.secondary,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Pickup location
                _buildLocationSection(
                  'استلام من المتجر',
                  offer.restaurantName,
                  offer.restaurantAddress,
                  Icons.store,
                  AppColors.secondary,
                ),                  const SizedBox(height: 20),
                  
                  // Delivery location
                _buildLocationSection(
                  'توصيل إلى',
                  offer.customerName,
                  offer.customerAddress,
                  Icons.person,
                  AppColors.accent,
                ),                  // Special instructions
                  if (offer.specialInstructions != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'تعليمات خاصة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Text(
                        offer.specialInstructions!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.amber[800],
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Bottom buttons
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Reject button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onReject();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        backgroundColor: Colors.grey[200],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'رفض',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Accept button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onAccept();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'قبول',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsRow(String label, String amount, {String? subtext, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isBold ? Colors.black : Colors.grey[700],
                  fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: isBold ? AppColors.secondary : Colors.black,
                ),
              ),
            ],
          ),
          if (subtext != null) ...[
            const SizedBox(height: 4),
            Text(
              subtext,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationSection(String title, String name, String address, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              // Use customer avatar for delivery section, regular icon for pickup
              title == 'توصيل إلى' 
                ? _buildCustomerAvatar(name)
                : Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: _buildLocationIcon(icon, color, title == 'استلام من المتجر'),
                  ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // دالة عرض العناصر في قائمة سفلية
  void _showOrderItemsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OrderItemsBottomSheet(
        items: offer.items,
        currency: offer.currency,
      ),
    );
  }

  // دالة بناء أيقونة الموقع مع صورة المطعم
  Widget _buildLocationIcon(IconData icon, Color color, bool isStore) {
    print('🖼️ OrderDetailsBottomSheet - isStore: $isStore, Restaurant Image URL: ${offer.restaurantImageUrl}');
    print('🖼️ OrderDetailsBottomSheet - Restaurant Name: ${offer.restaurantName}');
    if (isStore && offer.restaurantImageUrl != null) {
      return ClipOval(
        child: Image.network(
          offer.restaurantImageUrl!,
          width: 60,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(icon, color: color, size: 24);
          },
        ),
      );
    }
    return Icon(icon, color: color, size: 24);
  }

  /// Builds a circular avatar with the first letter of the customer name
  Widget _buildCustomerAvatar(String customerName) {
    // Get first letter of customer name, fallback to 'ز' if empty
    String firstLetter = customerName.isNotEmpty ? customerName[0].toUpperCase() : 'ز';
    
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.primary, // اللون الأساسي - أصفر ذهبي
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: const TextStyle(
            color: AppColors.secondary, // اللون الثانوي - أزرق داكن
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// القائمة السفلية لعرض العناصر
class OrderItemsBottomSheet extends StatelessWidget {
  final List<OrderItem> items;
  final String currency;

  const OrderItemsBottomSheet({
    super.key,
    required this.items,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text(
                  'عناصر الطلب',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length} عنصر',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Items list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildOrderItemCard(item);
              },
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOrderItemCard(OrderItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // صورة العنصر
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.imageUrl != null
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.restaurant,
                            color: Colors.grey,
                            size: 30,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.restaurant,
                        color: Colors.grey,
                        size: 30,
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 16),

          // تفاصيل العنصر
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // دائرة الكمية
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  Text(
                    item.notes!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  '${(item.price / 1000).toStringAsFixed(0)} $currency',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a circular avatar with the first letter of the customer name
  Widget _buildCustomerAvatar(String customerName) {
    // Get first letter of customer name, fallback to 'ز' if empty
    String firstLetter = customerName.isNotEmpty ? customerName[0].toUpperCase() : 'ز';
    
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.primary, // اللون الأساسي - أصفر ذهبي
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: const TextStyle(
            color: AppColors.secondary, // اللون الثانوي - أزرق داكن
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}