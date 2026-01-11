import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/order_model.dart';

enum OrderType { delivery, pickup }

class OrderMarker {
  final String id;
  final LatLng location;
  final LatLng? customerLocation;
  final OrderStatus status;
  final OrderType type;
  final String restaurantName;
  final String customerName;
  final String address;
  final double estimatedEarnings;
  final int estimatedTime; // in minutes
  final double distance; // in kilometers
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final String? notes;
  final List<String> items;
  final double totalAmount;
  final String paymentMethod;

  OrderMarker({
    required this.id,
    required this.location,
    this.customerLocation,
    required this.status,
    required this.type,
    required this.restaurantName,
    required this.customerName,
    required this.address,
    required this.estimatedEarnings,
    required this.estimatedTime,
    required this.distance,
    required this.createdAt,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.notes,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
  });

  factory OrderMarker.fromJson(Map<String, dynamic> json) {
    return OrderMarker(
      id: json['id'],
      location: LatLng(json['latitude'], json['longitude']),
      customerLocation:
          json['customer_latitude'] != null &&
              json['customer_longitude'] != null
          ? LatLng(json['customer_latitude'], json['customer_longitude'])
          : null,
      status: OrderStatus.values.byName(json['status']),
      type: OrderType.values.byName(json['type']),
      restaurantName: json['restaurant_name'],
      customerName: json['customer_name'],
      address: json['address'],
      estimatedEarnings: json['estimated_earnings'].toDouble(),
      estimatedTime: json['estimated_time'],
      distance: json['distance'].toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'])
          : null,
      pickedUpAt: json['picked_up_at'] != null
          ? DateTime.parse(json['picked_up_at'])
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'])
          : null,
      notes: json['notes'],
      items: List<String>.from(json['items']),
      totalAmount: json['total_amount'].toDouble(),
      paymentMethod: json['payment_method'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'customer_latitude': customerLocation?.latitude,
      'customer_longitude': customerLocation?.longitude,
      'status': status.name,
      'type': type.name,
      'restaurant_name': restaurantName,
      'customer_name': customerName,
      'address': address,
      'estimated_earnings': estimatedEarnings,
      'estimated_time': estimatedTime,
      'distance': distance,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'picked_up_at': pickedUpAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'notes': notes,
      'items': items,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
    };
  }

  OrderMarker copyWith({
    String? id,
    LatLng? location,
    LatLng? customerLocation,
    OrderStatus? status,
    OrderType? type,
    String? restaurantName,
    String? customerName,
    String? address,
    double? estimatedEarnings,
    int? estimatedTime,
    double? distance,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    String? notes,
    List<String>? items,
    double? totalAmount,
    String? paymentMethod,
  }) {
    return OrderMarker(
      id: id ?? this.id,
      location: location ?? this.location,
      customerLocation: customerLocation ?? this.customerLocation,
      status: status ?? this.status,
      type: type ?? this.type,
      restaurantName: restaurantName ?? this.restaurantName,
      customerName: customerName ?? this.customerName,
      address: address ?? this.address,
      estimatedEarnings: estimatedEarnings ?? this.estimatedEarnings,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      distance: distance ?? this.distance,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  bool get isActive => [
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.onTheWay,
      ].contains(status);
  bool get isPending => status == OrderStatus.pending;
  bool get isCompleted =>
      [OrderStatus.delivered, OrderStatus.cancelled].contains(status);

  String get statusDisplayText {
    switch (status) {
      case OrderStatus.pending:
        return 'قيد الانتظار';
      case OrderStatus.confirmed:
        return 'مؤكد';
      case OrderStatus.accepted:
        return 'مقبول';
      case OrderStatus.preparing:
        return 'قيد التحضير';
      case OrderStatus.ready:
        return 'جاهز';
      case OrderStatus.arrivedAtRestaurant:
        return 'وصل للمطعم';
      case OrderStatus.pickedUp:
        return 'تم الاستلام';
      case OrderStatus.onTheWay:
        return 'في الطريق';
      case OrderStatus.arrivedToCustomer:
        return 'وصل للعميل';
      case OrderStatus.delivered:
        return 'تم التوصيل';
      case OrderStatus.cancelled:
        return 'ملغي';
      case OrderStatus.failed:
        return 'فشل';
    }
  }

  String get formattedEarnings => '\$${estimatedEarnings.toStringAsFixed(2)}';
  String get formattedTime => '${estimatedTime}min';
  String get formattedDistance => '${distance.toStringAsFixed(1)}km';
}
