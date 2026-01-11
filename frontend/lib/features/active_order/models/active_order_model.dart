/// تفاصيل التسعير للطلب
class OrderPricing {
  final double goodsSubtotal;   // قيمة البضائع فقط (المبلغ المحجوز على السائق)
  final double deliveryFee;     // رسوم التوصيل (يستلمها السائق نقداً)
  final double tip;             // البقشيش (يستلمه السائق نقداً)
  final double waveBonus;       // مكافأة من المنصة (تدفع يدوياً لاحقاً)
  final double total;           // الإجمالي الكامل (goodsSubtotal + deliveryFee + tip)

  OrderPricing({
    required this.goodsSubtotal,
    required this.deliveryFee,
    required this.tip,
    required this.waveBonus,
    required this.total,
  });

  factory OrderPricing.fromJson(Map<String, dynamic> json) => OrderPricing(
    goodsSubtotal: (json['goodsSubtotal'] ?? 0).toDouble(),
    deliveryFee: (json['deliveryFee'] ?? 0).toDouble(),
    tip: (json['tip'] ?? 0).toDouble(),
    waveBonus: (json['waveBonus'] ?? 0).toDouble(),
    total: (json['total'] ?? 0).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'goodsSubtotal': goodsSubtotal,
    'deliveryFee': deliveryFee,
    'tip': tip,
    'waveBonus': waveBonus,
    'total': total,
  };
}

/// Model للطلب النشط الذي قبله السائق
class ActiveOrder {
  final String orderId;
  final String? orderNumber; // رقم الطلب القصير من API
  final String status; // accepted, heading_to_store, arrived_at_store, picked_up, heading_to_customer, arrived_at_customer, delivered
  
  // معلومات المطعم
  final String restaurantId;
  final String restaurantName;
  final String restaurantAddress;
  final double restaurantLat;
  final double restaurantLng;
  final String? restaurantPhone;
  
  // معلومات العميل
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final double customerLat;
  final double customerLng;
  final String? customerNearestLandmark;
  
  // معلومات الطلب
  final double totalAmount;
  final double? total; // القيمة الإجمالية من API
  final OrderPricing? pricing; // تفاصيل التسعير الكامل
  final String paymentMethod; // cash أو card
  final List<OrderItem> items;
  final String? specialInstructions;
  
  // معلومات التوقيت
  final DateTime acceptedAt;
  final DateTime? arrivedAtStoreAt;
  final DateTime? pickedUpAt;
  final DateTime? arrivedAtCustomerAt;
  final DateTime? deliveredAt;
  
  // معلومات السائق
  final double? driverEarnings;
  
  // ===== Wallet Hold Info =====
  final String? holdId;              // Hold ID من Wallet Service
  final String? holdStatus;          // ACTIVE, RELEASED, SETTLED
  final double? holdAmount;          // المبلغ المحجوز

  ActiveOrder({
    required this.orderId,
    this.orderNumber,
    required this.status,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.restaurantLat,
    required this.restaurantLng,
    this.restaurantPhone,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.customerLat,
    required this.customerLng,
    this.customerNearestLandmark,
    required this.totalAmount,
    this.total,
    this.pricing,
    required this.paymentMethod,
    required this.items,
    this.specialInstructions,
    required this.acceptedAt,
    this.arrivedAtStoreAt,
    this.pickedUpAt,
    this.arrivedAtCustomerAt,
    this.deliveredAt,
    this.driverEarnings,
    this.holdId,
    this.holdStatus,
    this.holdAmount,
  });

  /// استخراج العنوان من Object أو String
  static String _extractAddress(dynamic address) {
    if (address == null) return '';
    if (address is String) return address;
    if (address is Map) {
      return (address['detailedAddress'] as String?) ?? 
             (address['fullAddress'] as String?) ?? 
             (address['addressLine1'] as String?) ?? 
             '';
    }
    return '';
  }

  /// استخراج المعلم من Object العنوان
  static String? _extractLandmark(dynamic address) {
    if (address is Map) {
      return address['landmark'] as String?;
    }
    return null;
  }

  /// من JSON إلى Object
  factory ActiveOrder.fromJson(Map<String, dynamic> json) {
    return ActiveOrder(
      orderId: json['orderId'] ?? '',
      orderNumber: json['orderNumber'],
      status: json['status'] ?? 'accepted',
      restaurantId: json['storeId'] ?? json['restaurantId'] ?? '',
      restaurantName: json['storeName'] ?? json['restaurantName'] ?? '',
      restaurantAddress: json['storeAddress'] ?? json['restaurantAddress'] ?? '',
      restaurantLat: (json['restaurantLat'] ?? 0.0).toDouble(),
      restaurantLng: (json['restaurantLng'] ?? 0.0).toDouble(),
      restaurantPhone: json['restaurantPhone'],
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      customerAddress: _extractAddress(json['deliveryAddress'] ?? json['customerAddress']),
      customerLat: (json['customerLat'] ?? 0.0).toDouble(),
      customerLng: (json['customerLng'] ?? 0.0).toDouble(),
      customerNearestLandmark: _extractLandmark(json['deliveryAddress'] ?? json['customerAddress']) ?? json['customerNearestLandmark'],
      totalAmount: (json['total'] ?? json['totalAmount'] ?? 0.0).toDouble(),
      total: json['total'] != null ? (json['total'] as num).toDouble() : null,
      pricing: json['pricing'] != null ? OrderPricing.fromJson(json['pricing']) : null,
      paymentMethod: json['paymentMethod'] ?? 'cash',
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromJson(item))
              .toList() ??
          [],
      specialInstructions: json['specialInstructions'],
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.parse(json['acceptedAt'])
          : DateTime.now(),
      arrivedAtStoreAt: json['arrivedAtStoreAt'] != null
          ? DateTime.parse(json['arrivedAtStoreAt'])
          : null,
      pickedUpAt: json['pickedUpAt'] != null
          ? DateTime.parse(json['pickedUpAt'])
          : null,
      arrivedAtCustomerAt: json['arrivedAtCustomerAt'] != null
          ? DateTime.parse(json['arrivedAtCustomerAt'])
          : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.parse(json['deliveredAt'])
          : null,
      driverEarnings: json['driverEarnings'] != null
          ? (json['driverEarnings'] as num).toDouble()
          : null,
      holdId: json['holdId'],
      holdStatus: json['holdStatus'],
      holdAmount: json['holdAmount'] != null ? (json['holdAmount'] as num).toDouble() : null,
    );
  }

  /// من Object إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'orderNumber': orderNumber,
      'status': status,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'restaurantAddress': restaurantAddress,
      'restaurantLat': restaurantLat,
      'restaurantLng': restaurantLng,
      'restaurantPhone': restaurantPhone,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'customerLat': customerLat,
      'customerLng': customerLng,
      'customerNearestLandmark': customerNearestLandmark,
      'totalAmount': totalAmount,
      'total': total,
      'pricing': pricing?.toJson(),
      'paymentMethod': paymentMethod,
      'items': items.map((item) => item.toJson()).toList(),
      'specialInstructions': specialInstructions,
      'acceptedAt': acceptedAt.toIso8601String(),
      'arrivedAtStoreAt': arrivedAtStoreAt?.toIso8601String(),
      'pickedUpAt': pickedUpAt?.toIso8601String(),
      'arrivedAtCustomerAt': arrivedAtCustomerAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'driverEarnings': driverEarnings,
      'holdId': holdId,
      'holdStatus': holdStatus,
      'holdAmount': holdAmount,
    };
  }

  /// نسخ مع تغيير بعض الحقول
  ActiveOrder copyWith({
    String? orderId,
    String? orderNumber,
    String? status,
    String? restaurantId,
    String? restaurantName,
    String? restaurantAddress,
    double? restaurantLat,
    double? restaurantLng,
    String? restaurantPhone,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    double? customerLat,
    double? customerLng,
    String? customerNearestLandmark,
    double? totalAmount,
    double? total,
    OrderPricing? pricing,
    String? paymentMethod,
    List<OrderItem>? items,
    String? specialInstructions,
    DateTime? acceptedAt,
    DateTime? arrivedAtStoreAt,
    DateTime? pickedUpAt,
    DateTime? arrivedAtCustomerAt,
    DateTime? deliveredAt,
    double? driverEarnings,
    String? holdId,
    String? holdStatus,
    double? holdAmount,
  }) {
    return ActiveOrder(
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      status: status ?? this.status,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      restaurantAddress: restaurantAddress ?? this.restaurantAddress,
      restaurantLat: restaurantLat ?? this.restaurantLat,
      restaurantLng: restaurantLng ?? this.restaurantLng,
      restaurantPhone: restaurantPhone ?? this.restaurantPhone,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      customerLat: customerLat ?? this.customerLat,
      customerLng: customerLng ?? this.customerLng,
      customerNearestLandmark: customerNearestLandmark ?? this.customerNearestLandmark,
      totalAmount: totalAmount ?? this.totalAmount,
      total: total ?? this.total,
      pricing: pricing ?? this.pricing,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items ?? this.items,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      arrivedAtStoreAt: arrivedAtStoreAt ?? this.arrivedAtStoreAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      arrivedAtCustomerAt: arrivedAtCustomerAt ?? this.arrivedAtCustomerAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      driverEarnings: driverEarnings ?? this.driverEarnings,
      holdId: holdId ?? this.holdId,
      holdStatus: holdStatus ?? this.holdStatus,
      holdAmount: holdAmount ?? this.holdAmount,
    );
  }

  /// هل الدفع نقدي؟
  bool get isCashPayment => paymentMethod.toLowerCase() == 'cash';

  /// رقم الطلب المختصر (أول 8 أحرف)
  String get shortOrderId => orderId.length > 8 ? orderId.substring(0, 8) : orderId;
}

/// عنصر في الطلب
class OrderItem {
  final String itemId;
  final String name;
  final int quantity;
  final double price;
  final String? notes;
  final List<String>? modifiers;

  OrderItem({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.price,
    this.notes,
    this.modifiers,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      itemId: json['itemId'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      price: (json['price'] ?? 0.0).toDouble(),
      notes: json['notes'],
      modifiers: json['modifiers'] != null
          ? List<String>.from(json['modifiers'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'name': name,
      'quantity': quantity,
      'price': price,
      'notes': notes,
      'modifiers': modifiers,
    };
  }

  /// السعر الإجمالي للعنصر
  double get totalPrice => price * quantity;
}
