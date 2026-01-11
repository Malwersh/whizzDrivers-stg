class RestaurantData {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int activeOrders;
  final bool isOnline;
  final String category;
  final double rating;
  final String imageUrl;

  RestaurantData({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.activeOrders,
    required this.isOnline,
    required this.category,
    required this.rating,
    required this.imageUrl,
  });

  // تحديد لون النقطة حسب عدد الطلبات النشطة
  OrderDensity get orderDensity {
    if (!isOnline) return OrderDensity.none;
    if (activeOrders >= 15) return OrderDensity.high;
    if (activeOrders >= 8) return OrderDensity.medium;
    if (activeOrders >= 3) return OrderDensity.low;
    return OrderDensity.none;
  }

  factory RestaurantData.fromJson(Map<String, dynamic> json) {
    return RestaurantData(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      activeOrders: json['activeOrders'] ?? 0,
      isOnline: json['isOnline'] ?? false,
      category: json['category'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'activeOrders': activeOrders,
      'isOnline': isOnline,
      'category': category,
      'rating': rating,
      'imageUrl': imageUrl,
    };
  }
}

enum OrderDensity {
  high,    // طلبات عالية - أحمر غامق
  medium,  // طلبات متوسطة - أحمر فاتح
  low,     // طلبات قليلة - أصفر محمر
  none,    // لا توجد طلبات - لا يظهر
}