import 'dart:math' as math;

import '../models/order_model.dart';

/// Enum to describe the type of order batching
enum BatchType {
  sameRestaurant, // Both orders from same restaurant
  nearbyRestaurants, // Orders from nearby restaurants (<1km apart)
  onDeliveryRoute, // Second pickup is on route to first delivery
  sameArea, // Both deliveries in same area (<2km apart)
}

/// Model representing a batch of optimized orders
class BatchedOrderNotification {
  final String batchId;
  final List<OrderModel> orders;
  final BatchType batchType;
  final double totalEarnings;
  final double totalDistance;
  final int estimatedTimeMinutes;
  final DateTime createdAt;
  final String optimizationReason;
  final double distanceSavedInKm;
  final int timeSavedInMinutes;

  BatchedOrderNotification({
    required this.batchId,
    required this.orders,
    required this.batchType,
    required this.totalEarnings,
    required this.totalDistance,
    required this.estimatedTimeMinutes,
    required this.optimizationReason,
    this.distanceSavedInKm = 0.0,
    this.timeSavedInMinutes = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Get primary restaurant (first order's restaurant)
  String get primaryRestaurant => orders.first.restaurantName;

  /// Get all unique restaurants
  List<String> get restaurants =>
      orders.map((o) => o.restaurantName).toSet().toList();

  /// Get all customer addresses
  List<String> get customerAddresses =>
      orders.map((o) => o.customerAddress).toList();

  /// Check if orders are from same restaurant
  bool get isSameRestaurant => restaurants.length == 1;

  /// Get batch description for UI
  String get batchDescription {
    switch (batchType) {
      case BatchType.sameRestaurant:
        return '${orders.length} orders from $primaryRestaurant';
      case BatchType.nearbyRestaurants:
        return '${orders.length} orders from nearby restaurants';
      case BatchType.onDeliveryRoute:
        return '${orders.length} orders on optimal route';
      case BatchType.sameArea:
        return '${orders.length} orders in same delivery area';
    }
  }

  /// Get the pickup sequence based on optimization
  List<OrderModel> get optimizedPickupSequence {
    switch (batchType) {
      case BatchType.sameRestaurant:
        // All from same restaurant, order by customer distance from restaurant
        return List.from(orders)
          ..sort((a, b) => a.deliveryDistance.compareTo(b.deliveryDistance));

      case BatchType.nearbyRestaurants:
        // Order by restaurant distance from driver's current location
        return List.from(
          orders,
        )..sort((a, b) => a.restaurantDistance.compareTo(b.restaurantDistance));

      case BatchType.onDeliveryRoute:
        // First order pickup, then second pickup (on route), then deliveries
        return orders;

      case BatchType.sameArea:
        // Order by total efficiency (distance + time)
        return List.from(orders)..sort(
          (a, b) => (a.restaurantDistance + a.deliveryDistance).compareTo(
            b.restaurantDistance + b.deliveryDistance,
          ),
        );
    }
  }

  /// Get the delivery sequence based on optimization
  List<OrderModel> get optimizedDeliverySequence {
    // Always deliver in order of proximity to minimize total distance
    final pickupSequence = optimizedPickupSequence;

    if (pickupSequence.length <= 1) return pickupSequence;

    // For multiple orders, optimize delivery route
    // Simple optimization: deliver closest to last pickup first
    final lastPickup = pickupSequence.last.restaurantLocation;

    return List.from(pickupSequence)..sort((a, b) {
      final distanceA = _calculateDistance(
        lastPickup.latitude,
        lastPickup.longitude,
        a.customerLocation.latitude,
        a.customerLocation.longitude,
      );
      final distanceB = _calculateDistance(
        lastPickup.latitude,
        lastPickup.longitude,
        b.customerLocation.latitude,
        b.customerLocation.longitude,
      );
      return distanceA.compareTo(distanceB);
    });
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// Get the optimal sequence of order IDs
  List<String> getOptimalSequence() {
    return optimizedPickupSequence.map((order) => order.id).toList();
  }

  /// Create a copy with updated properties
  BatchedOrderNotification copyWith({
    String? batchId,
    List<OrderModel>? orders,
    BatchType? batchType,
    double? totalEarnings,
    double? totalDistance,
    int? estimatedTimeMinutes,
    String? optimizationReason,
    double? distanceSavedInKm,
    int? timeSavedInMinutes,
    DateTime? createdAt,
  }) {
    return BatchedOrderNotification(
      batchId: batchId ?? this.batchId,
      orders: orders ?? this.orders,
      batchType: batchType ?? this.batchType,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      totalDistance: totalDistance ?? this.totalDistance,
      estimatedTimeMinutes: estimatedTimeMinutes ?? this.estimatedTimeMinutes,
      optimizationReason: optimizationReason ?? this.optimizationReason,
      distanceSavedInKm: distanceSavedInKm ?? this.distanceSavedInKm,
      timeSavedInMinutes: timeSavedInMinutes ?? this.timeSavedInMinutes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Create a single order batch for backward compatibility
  static BatchedOrderNotification singleOrder(OrderModel order) {
    return BatchedOrderNotification(
      batchId: 'single_${order.id}',
      orders: [order],
      batchType: BatchType.sameRestaurant,
      totalEarnings: order.totalAmount,
      totalDistance: order.distance,
      estimatedTimeMinutes: order.estimatedTripDuration.inMinutes,
      optimizationReason: 'Single order notification',
    );
  }

  /// Get primary order (first order)
  OrderModel get primaryOrder => orders.first;

  /// Get batch identifier
  String get id => batchId;

  /// Convert to JSON for API communication
  Map<String, dynamic> toJson() {
    return {
      'batchId': batchId,
      'orders': orders.map((order) => order.toJson()).toList(),
      'batchType': batchType.name,
      'totalEarnings': totalEarnings,
      'totalDistance': totalDistance,
      'estimatedTimeMinutes': estimatedTimeMinutes,
      'optimizationReason': optimizationReason,
      'distanceSavedInKm': distanceSavedInKm,
      'timeSavedInMinutes': timeSavedInMinutes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create from JSON for API communication
  factory BatchedOrderNotification.fromJson(Map<String, dynamic> json) {
    return BatchedOrderNotification(
      batchId: json['batchId'] ?? '',
      orders:
          (json['orders'] as List<dynamic>?)
              ?.map(
                (orderJson) =>
                    OrderModel.fromJson(orderJson as Map<String, dynamic>),
              )
              .toList() ??
          [],
      batchType: BatchType.values.firstWhere(
        (e) => e.name == json['batchType'],
        orElse: () => BatchType.sameRestaurant,
      ),
      totalEarnings: json['totalEarnings']?.toDouble() ?? 0.0,
      totalDistance: json['totalDistance']?.toDouble() ?? 0.0,
      estimatedTimeMinutes: json['estimatedTimeMinutes'] ?? 0,
      optimizationReason: json['optimizationReason'] ?? '',
      distanceSavedInKm: json['distanceSavedInKm']?.toDouble() ?? 0.0,
      timeSavedInMinutes: json['timeSavedInMinutes'] ?? 0,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
