/// Delivery order model for food delivery drivers
/// Represents a delivery order from restaurant to customer
class DeliveryOrder {
  final String id;
  final String restaurantName;
  final String customerName;
  final String pickupAddress;
  final String deliveryAddress;
  final double distance; // in kilometers
  final int estimatedTime; // in minutes
  final double earnings; // in SAR
  final int items; // number of items
  final bool isUrgent;
  final double pickupLatitude;
  final double pickupLongitude;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final DateTime? createdAt;
  final String? customerPhone;
  final String? specialInstructions;
  final String status;
  final List<String>? itemsList; // قائمة العناصر المطلوبة

  const DeliveryOrder({
    required this.id,
    required this.restaurantName,
    required this.customerName,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.distance,
    required this.estimatedTime,
    required this.earnings,
    required this.items,
    required this.isUrgent,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    this.createdAt,
    this.customerPhone,
    this.specialInstructions,
    this.status = 'available',
    this.itemsList,
  });

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    return DeliveryOrder(
      id: json['id'] ?? '',
      restaurantName: json['restaurantName'] ?? '',
      customerName: json['customerName'] ?? '',
      pickupAddress: json['pickupAddress'] ?? '',
      deliveryAddress: json['deliveryAddress'] ?? '',
      distance: (json['distance'] ?? 0.0).toDouble(),
      estimatedTime: json['estimatedTime'] ?? 0,
      earnings: (json['earnings'] ?? 0.0).toDouble(),
      items: json['items'] ?? 0,
      isUrgent: json['isUrgent'] ?? false,
      pickupLatitude: (json['pickupLatitude'] ?? 0.0).toDouble(),
      pickupLongitude: (json['pickupLongitude'] ?? 0.0).toDouble(),
      deliveryLatitude: (json['deliveryLatitude'] ?? 0.0).toDouble(),
      deliveryLongitude: (json['deliveryLongitude'] ?? 0.0).toDouble(),
      createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt']) 
        : null,
      customerPhone: json['customerPhone'],
      specialInstructions: json['specialInstructions'],
      status: json['status'] ?? 'available',
      itemsList: json['itemsList'] != null 
        ? List<String>.from(json['itemsList']) 
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantName': restaurantName,
      'customerName': customerName,
      'pickupAddress': pickupAddress,
      'deliveryAddress': deliveryAddress,
      'distance': distance,
      'estimatedTime': estimatedTime,
      'earnings': earnings,
      'items': items,
      'isUrgent': isUrgent,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'createdAt': createdAt?.toIso8601String(),
      'customerPhone': customerPhone,
      'specialInstructions': specialInstructions,
      'status': status,
      'itemsList': itemsList,
    };
  }

  DeliveryOrder copyWith({
    String? id,
    String? restaurantName,
    String? customerName,
    String? pickupAddress,
    String? deliveryAddress,
    double? distance,
    int? estimatedTime,
    double? earnings,
    int? items,
    bool? isUrgent,
    double? pickupLatitude,
    double? pickupLongitude,
    double? deliveryLatitude,
    double? deliveryLongitude,
    DateTime? createdAt,
    String? customerPhone,
    String? specialInstructions,
    String? status,
    List<String>? itemsList,
  }) {
    return DeliveryOrder(
      id: id ?? this.id,
      restaurantName: restaurantName ?? this.restaurantName,
      customerName: customerName ?? this.customerName,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      distance: distance ?? this.distance,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      earnings: earnings ?? this.earnings,
      items: items ?? this.items,
      isUrgent: isUrgent ?? this.isUrgent,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      createdAt: createdAt ?? this.createdAt,
      customerPhone: customerPhone ?? this.customerPhone,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      status: status ?? this.status,
      itemsList: itemsList ?? this.itemsList,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeliveryOrder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DeliveryOrder(id: $id, restaurant: $restaurantName, earnings: $earnings SAR)';
  }

  // إضافة خصائص للتوافق مع شاشة البحث عن العروض
  String get pickupLocation => pickupAddress;
  String get deliveryLocation => deliveryAddress;
  double get estimatedPrice => earnings;
  int get estimatedDuration => estimatedTime;
  String get orderType => 'طعام'; // نوع الطلب افتراضي
}
