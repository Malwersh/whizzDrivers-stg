import 'package:flutter/material.dart';
import '../models/restaurant_data.dart';

class RestaurantDetailsBottomSheet extends StatelessWidget {
  final RestaurantData restaurant;

  const RestaurantDetailsBottomSheet({
    super.key,
    required this.restaurant,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 16),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Restaurant content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Restaurant header
                Row(
                  children: [
                    // Restaurant image placeholder
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        image: restaurant.imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(restaurant.imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: restaurant.imageUrl.isEmpty
                          ? Icon(
                              Icons.restaurant,
                              color: Colors.grey[400],
                              size: 30,
                            )
                          : null,
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Restaurant info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            restaurant.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          
                          const SizedBox(height: 4),
                          
                          Text(
                            restaurant.category,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          
                          const SizedBox(height: 4),
                          
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                restaurant.rating.toString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Online status indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: restaurant.isOnline ? Colors.green[100] : Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        restaurant.isOnline ? 'متاح' : 'مغلق',
                        style: TextStyle(
                          fontSize: 12,
                          color: restaurant.isOnline ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Address
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        restaurant.address,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Active orders info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getOrderDensityColor(restaurant.orderDensity).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getOrderDensityColor(restaurant.orderDensity).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: _getOrderDensityColor(restaurant.orderDensity),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الطلبات النشطة',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            '${restaurant.activeOrders} طلب',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _getOrderDensityColor(restaurant.orderDensity),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getOrderDensityColor(restaurant.orderDensity),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getOrderDensityText(restaurant.orderDensity),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: restaurant.isOnline && restaurant.activeOrders > 0
                        ? () {
                            Navigator.pop(context);
                            // Navigate to restaurant details or orders
                            _navigateToRestaurantOrders(context, restaurant);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: Text(
                      restaurant.isOnline && restaurant.activeOrders > 0
                          ? 'عرض الطلبات المتاحة'
                          : 'لا توجد طلبات متاحة',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getOrderDensityColor(OrderDensity density) {
    switch (density) {
      case OrderDensity.high:
        return const Color(0xFFD32F2F); // أحمر غامق
      case OrderDensity.medium:
        return const Color(0xFFE57373); // أحمر فاتح
      case OrderDensity.low:
        return const Color(0xFFFF8A65); // أصفر محمر
      case OrderDensity.none:
        return Colors.grey;
    }
  }

  String _getOrderDensityText(OrderDensity density) {
    switch (density) {
      case OrderDensity.high:
        return 'مزدحم جداً';
      case OrderDensity.medium:
        return 'مزدحم';
      case OrderDensity.low:
        return 'هادئ';
      case OrderDensity.none:
        return 'لا توجد طلبات';
    }
  }

  void _navigateToRestaurantOrders(BuildContext context, RestaurantData restaurant) {
    // هنا يمكن الانتقال لصفحة طلبات المطعم
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('عرض طلبات ${restaurant.name}'),
        backgroundColor: const Color(0xFF1E88E5),
      ),
    );
  }
}