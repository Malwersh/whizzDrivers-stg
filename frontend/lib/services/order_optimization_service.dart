import 'dart:math';

import '../models/batched_order_model.dart';
import '../models/order_model.dart';

/// Service responsible for optimizing and batching orders for drivers
class OrderOptimizationService {
  static const double _nearbyRestaurantThresholdKm = 1.0;
  static const double _sameAreaThresholdKm = 2.0;
  static const double _onRouteThresholdKm = 0.5;

  /// Analyze if two orders can be batched together efficiently
  static BatchedOrderNotification? canBatchOrders(
    OrderModel order1,
    OrderModel order2, {
    double? driverLat,
    double? driverLng,
  }) {
    // Calculate distances between locations
    final restaurantDistance = _calculateDistance(
      order1.restaurantLocation.latitude,
      order1.restaurantLocation.longitude,
      order2.restaurantLocation.latitude,
      order2.restaurantLocation.longitude,
    );

    final deliveryDistance = _calculateDistance(
      order1.customerLocation.latitude,
      order1.customerLocation.longitude,
      order2.customerLocation.latitude,
      order2.customerLocation.longitude,
    );

    // Strategy 1: Same Restaurant
    if (order1.restaurantName == order2.restaurantName) {
      return _createBatchedOrder(
        [order1, order2],
        BatchType.sameRestaurant,
        'Both orders from ${order1.restaurantName}',
      );
    }

    // Strategy 2: Nearby Restaurants
    if (restaurantDistance <= _nearbyRestaurantThresholdKm) {
      return _createBatchedOrder(
        [order1, order2],
        BatchType.nearbyRestaurants,
        'Restaurants only ${restaurantDistance.toStringAsFixed(1)}km apart',
      );
    }

    // Strategy 3: Same Delivery Area
    if (deliveryDistance <= _sameAreaThresholdKm) {
      return _createBatchedOrder(
        [order1, order2],
        BatchType.sameArea,
        'Deliveries in same area (${deliveryDistance.toStringAsFixed(1)}km apart)',
      );
    }

    // Strategy 4: On Delivery Route (second pickup is on route to first delivery)
    if (_isOnDeliveryRoute(order1, order2)) {
      return _createBatchedOrder(
        [order1, order2],
        BatchType.onDeliveryRoute,
        'Second pickup is on route to first delivery',
      );
    }

    return null; // Orders cannot be efficiently batched
  }

  /// Check if second order's pickup is on route to first order's delivery
  static bool _isOnDeliveryRoute(OrderModel order1, OrderModel order2) {
    // Calculate if restaurant2 is roughly on the path from restaurant1 to customer1
    final restaurant1ToCustomer1 = _calculateDistance(
      order1.restaurantLocation.latitude,
      order1.restaurantLocation.longitude,
      order1.customerLocation.latitude,
      order1.customerLocation.longitude,
    );

    final restaurant1ToRestaurant2 = _calculateDistance(
      order1.restaurantLocation.latitude,
      order1.restaurantLocation.longitude,
      order2.restaurantLocation.latitude,
      order2.restaurantLocation.longitude,
    );

    final restaurant2ToCustomer1 = _calculateDistance(
      order2.restaurantLocation.latitude,
      order2.restaurantLocation.longitude,
      order1.customerLocation.latitude,
      order1.customerLocation.longitude,
    );

    // If going restaurant1 -> restaurant2 -> customer1 is not much longer
    // than restaurant1 -> customer1, then restaurant2 is "on route"
    final directDistance = restaurant1ToCustomer1;
    final routeDistance = restaurant1ToRestaurant2 + restaurant2ToCustomer1;
    final detourRatio = routeDistance / directDistance;

    // Allow up to 20% detour for batching efficiency
    return detourRatio <= 1.2 &&
        restaurant1ToRestaurant2 <= _onRouteThresholdKm;
  }

  /// Create optimized batched order from multiple orders
  static BatchedOrderNotification _createBatchedOrder(
    List<OrderModel> orders,
    BatchType batchType,
    String reason,
  ) {
    final totalEarnings = orders.fold(
      0.0,
      (sum, order) => sum + order.totalAmount,
    );
    final totalDistance = _calculateOptimizedTotalDistance(orders, batchType);
    final estimatedTime = _calculateEstimatedTime(orders, batchType);

    return BatchedOrderNotification(
      batchId: 'BATCH_${DateTime.now().millisecondsSinceEpoch}',
      orders: orders,
      batchType: batchType,
      totalEarnings: totalEarnings,
      totalDistance: totalDistance,
      estimatedTimeMinutes: estimatedTime,
      optimizationReason: reason,
    );
  }

  /// Calculate optimized total distance for the batch
  static double _calculateOptimizedTotalDistance(
    List<OrderModel> orders,
    BatchType batchType,
  ) {
    if (orders.length == 1) return orders.first.distance;

    switch (batchType) {
      case BatchType.sameRestaurant:
        // Driver -> Restaurant -> Customer1 -> Customer2
        final customer1 = orders.first.customerLocation;
        final customer2 = orders.last.customerLocation;

        return orders.first.restaurantDistance + // Driver to restaurant
            orders.first.deliveryDistance + // Restaurant to customer1
            _calculateDistance(
              // Customer1 to customer2
              customer1.latitude,
              customer1.longitude,
              customer2.latitude,
              customer2.longitude,
            );

      case BatchType.nearbyRestaurants:
        // Driver -> Restaurant1 -> Restaurant2 -> Customer1 -> Customer2
        return orders.first.restaurantDistance +
            _calculateDistance(
              orders.first.restaurantLocation.latitude,
              orders.first.restaurantLocation.longitude,
              orders.last.restaurantLocation.latitude,
              orders.last.restaurantLocation.longitude,
            ) +
            orders.first.deliveryDistance +
            orders.last.deliveryDistance;

      case BatchType.onDeliveryRoute:
        // Driver -> Restaurant1 -> Restaurant2 -> Customer1 -> Customer2
        final restaurant1 = orders.first.restaurantLocation;
        final restaurant2 = orders.last.restaurantLocation;
        final customer1 = orders.first.customerLocation;
        final customer2 = orders.last.customerLocation;

        return orders.first.restaurantDistance + // Driver to restaurant1
            _calculateDistance(
              // Restaurant1 to restaurant2
              restaurant1.latitude,
              restaurant1.longitude,
              restaurant2.latitude,
              restaurant2.longitude,
            ) +
            _calculateDistance(
              // Restaurant2 to customer1
              restaurant2.latitude,
              restaurant2.longitude,
              customer1.latitude,
              customer1.longitude,
            ) +
            _calculateDistance(
              // Customer1 to customer2
              customer1.latitude,
              customer1.longitude,
              customer2.latitude,
              customer2.longitude,
            );

      case BatchType.sameArea:
        // Calculate shortest route between all points
        return orders.fold(0.0, (sum, order) => sum + order.distance) *
            0.8; // 20% efficiency gain
    }
  }

  /// Calculate estimated time for completing the batch
  static int _calculateEstimatedTime(
    List<OrderModel> orders,
    BatchType batchType,
  ) {
    const int baseTimePerOrder = 25; // Base time per order in minutes

    switch (batchType) {
      case BatchType.sameRestaurant:
        return baseTimePerOrder +
            (orders.length - 1) * 10; // Slight efficiency gain

      case BatchType.nearbyRestaurants:
        return baseTimePerOrder * orders.length - 5; // Small efficiency gain

      case BatchType.onDeliveryRoute:
        return baseTimePerOrder * orders.length - 10; // Good efficiency gain

      case BatchType.sameArea:
        return baseTimePerOrder * orders.length - 8; // Moderate efficiency gain
    }
  }

  /// Calculate distance between two points using Haversine formula
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Analyze multiple orders and find the best batch combinations
  static List<BatchedOrderNotification> findOptimalBatches(
    List<OrderModel> availableOrders, {
    double? driverLat,
    double? driverLng,
  }) {
    final List<BatchedOrderNotification> batches = [];
    final List<OrderModel> processedOrders = [];

    for (int i = 0; i < availableOrders.length; i++) {
      if (processedOrders.contains(availableOrders[i])) continue;

      for (int j = i + 1; j < availableOrders.length; j++) {
        if (processedOrders.contains(availableOrders[j])) continue;

        final batch = canBatchOrders(
          availableOrders[i],
          availableOrders[j],
          driverLat: driverLat,
          driverLng: driverLng,
        );

        if (batch != null) {
          batches.add(batch);
          processedOrders.addAll([availableOrders[i], availableOrders[j]]);
          break; // Found a batch for this order, move to next
        }
      }
    }

    // Sort batches by efficiency (earnings per minute)
    batches.sort((a, b) {
      final efficiencyA = a.totalEarnings / a.estimatedTimeMinutes;
      final efficiencyB = b.totalEarnings / b.estimatedTimeMinutes;
      return efficiencyB.compareTo(efficiencyA);
    });

    return batches;
  }
}
