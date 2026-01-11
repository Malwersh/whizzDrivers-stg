import 'order_item.dart';

enum OrderStatus {
  pending,
  confirmed,
  accepted,
  preparing,
  ready,
  arrivedAtRestaurant,
  pickedUp,
  onTheWay,
  arrivedToCustomer,
  delivered,
  cancelled,
  failed,
}

class LocationCoordinate {
  final double latitude;
  final double longitude;
  final String address;

  const LocationCoordinate({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude, 'address': address};
  }

  factory LocationCoordinate.fromJson(Map<String, dynamic> json) {
    return LocationCoordinate(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      address: json['address'] ?? '',
    );
  }
}

class OrderModel {
  final String id;
  final String restaurantName;
  final String? storeImageUrl;
  final String customerName;
  final String customerAddress;
  final List<OrderItem> items;
  final double totalAmount;
  final DateTime estimatedDeliveryTime;
  final double distance;
  OrderStatus status;
  final String paymentMethod;
  final String? specialInstructions;
  final DateTime createdAt;

  // Location coordinates for route visualization
  final LocationCoordinate restaurantLocation;
  final LocationCoordinate customerLocation;
  final double restaurantDistance;
  final double deliveryDistance;

  OrderModel({
    required this.id,
    required this.restaurantName,
    this.storeImageUrl,
    required this.customerName,
    required this.customerAddress,
    required this.items,
    required this.totalAmount,
    required this.estimatedDeliveryTime,
    required this.distance,
    this.status = OrderStatus.pending,
    required this.paymentMethod,
    this.specialInstructions,
    DateTime? createdAt,
    required this.restaurantLocation,
    required this.customerLocation,
    required this.restaurantDistance,
    required this.deliveryDistance,
  }) : createdAt = createdAt ?? DateTime.now();

  String get formattedTotalAmount => '${totalAmount.toStringAsFixed(0)} د.ع';
  String get formattedDistance => '${distance.toStringAsFixed(1)} كم';
  String get formattedRestaurantDistance =>
      '${restaurantDistance.toStringAsFixed(1)} كم';
  String get formattedDeliveryDistance =>
      '${deliveryDistance.toStringAsFixed(1)} كم';
  String get itemsSummary => items.map((item) => item.name).join('، ');

  double get totalTripDistance => restaurantDistance + deliveryDistance;
  String get formattedTotalTripDistance =>
      '${totalTripDistance.toStringAsFixed(1)} كم';

  Duration get estimatedTripDuration =>
      Duration(minutes: (totalTripDistance / 30 * 60).round());
  String get formattedTripDuration {
    final minutes = estimatedTripDuration.inMinutes;
    if (minutes < 60) {
      return '$minutes دقيقة';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours س $remainingMinutes د';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantName': restaurantName,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'items': items,
      'totalAmount': totalAmount,
      'estimatedDeliveryTime': estimatedDeliveryTime.toIso8601String(),
      'distance': distance,
      'status': status.name,
      'paymentMethod': paymentMethod,
      'specialInstructions': specialInstructions,
      'createdAt': createdAt.toIso8601String(),
      'restaurantLocation': restaurantLocation.toJson(),
      'customerLocation': customerLocation.toJson(),
      'restaurantDistance': restaurantDistance,
      'deliveryDistance': deliveryDistance,
    };
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? '',
      restaurantName: json['restaurantName'] ?? '',
      storeImageUrl: json['storeImageUrl'],
      customerName: json['customerName'] ?? '',
      customerAddress: json['customerAddress'] ?? '',
      items: (json['items'] as List?)?.map((item) {
        if (item is String) {
          // Handle old format (just strings)
          return OrderItem(
            itemId: item,
            name: item,
            quantity: 1,
            unitPrice: 0.0,
          );
        } else if (item is Map<String, dynamic>) {
          // Handle new format (OrderItem objects)
          return OrderItem.fromJson(item);
        }
        return OrderItem(
          itemId: item.toString(),
          name: item.toString(),
          quantity: 1,
          unitPrice: 0.0,
        );
      }).toList() ?? [],
      totalAmount: json['totalAmount']?.toDouble() ?? 0.0,
      estimatedDeliveryTime: DateTime.parse(
        json['estimatedDeliveryTime'] ?? DateTime.now().toIso8601String(),
      ),
      distance: json['distance']?.toDouble() ?? 0.0,
      status: OrderStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => OrderStatus.pending,
      ),
      paymentMethod: json['paymentMethod'] ?? '',
      specialInstructions: json['specialInstructions'],
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      restaurantLocation: LocationCoordinate.fromJson(
        json['restaurantLocation'] ?? {},
      ),
      customerLocation: LocationCoordinate.fromJson(
        json['customerLocation'] ?? {},
      ),
      restaurantDistance: json['restaurantDistance']?.toDouble() ?? 0.0,
      deliveryDistance: json['deliveryDistance']?.toDouble() ?? 0.0,
    );
  }

  OrderModel copyWith({
    String? id,
    String? restaurantName,
    String? storeImageUrl,
    String? customerName,
    String? customerAddress,
    List<OrderItem>? items,
    double? totalAmount,
    DateTime? estimatedDeliveryTime,
    double? distance,
    OrderStatus? status,
    String? paymentMethod,
    String? specialInstructions,
    DateTime? createdAt,
    LocationCoordinate? restaurantLocation,
    LocationCoordinate? customerLocation,
    double? restaurantDistance,
    double? deliveryDistance,
  }) {
    return OrderModel(
      id: id ?? this.id,
      restaurantName: restaurantName ?? this.restaurantName,
      storeImageUrl: storeImageUrl ?? this.storeImageUrl,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      distance: distance ?? this.distance,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      createdAt: createdAt ?? this.createdAt,
      restaurantLocation: restaurantLocation ?? this.restaurantLocation,
      customerLocation: customerLocation ?? this.customerLocation,
      restaurantDistance: restaurantDistance ?? this.restaurantDistance,
      deliveryDistance: deliveryDistance ?? this.deliveryDistance,
    );
  }
}
