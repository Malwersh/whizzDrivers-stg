/// 🌊 Wave Offer Model
/// 
/// نموذج العرض الموجي الذي يستقبله السائق من Wave System
/// 
/// يحتوي على:
/// - معلومات العرض (offerId, waveNumber, rank, score)
/// - تفاصيل الطلب (restaurant, customer, earnings)
/// - قائمة العناصر مع الصور
/// - التوقيت (sentAt, expiresAt)
library;

class OrderItem {
  final String itemId;
  final String name;
  final int quantity;
  final double price;
  final String? imageUrl;
  final String? notes;

  OrderItem({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.price,
    this.imageUrl,
    this.notes,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      itemId: json['itemId'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      price: (json['price'] ?? 0).toDouble(),
      imageUrl: json['imageUrl'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'name': name,
      'quantity': quantity,
      'price': price,
      'imageUrl': imageUrl,
      'notes': notes,
    };
  }
}

class WaveOffer {
  // ===== معلومات العرض =====
  final String offerId;
  final String orderId;
  final String jobId;
  
  // ===== معلومات الموجة =====
  final int waveNumber;              // 1, 2, or 3
  final int rank;                    // 1-5 (ترتيب السائق في الموجة)
  final double score;                // النقاط المحسوبة (0-100)
  
  // ===== تفاصيل المطعم =====
  final String restaurantId;
  final String restaurantName;
  final String restaurantAddress;
  final double restaurantLat;
  final double restaurantLng;
  final String? restaurantImageUrl;
  
  // ===== تفاصيل الزبون =====
  final String customerId;
  final String customerName;
  final String customerAddress;
  final double customerLat;
  final double customerLng;
  final String? customerPhone;
  
  // ===== المبالغ =====
  final double orderTotal;           // مجموع الطلب
  final double deliveryFee;          // أجرة التوصيل الأساسية
  final double bonusAmount;          // المكافأة (البونص) من الموجة
  final double tip;                  // الإكرامية من العميل
  final double estimatedEarnings;    // الأرباح المتوقعة (deliveryFee + bonusAmount)
  final String currency;             // رمز العملة (IQD, USD, etc.)
  
  // ===== المسافة والوقت =====
  final double distance;             // بالكيلومتر
  final int estimatedMinutes;        // الوقت المتوقع
  
  // ===== العناصر =====
  final int itemsCount;              // عدد العناصر الإجمالي
  final List<OrderItem> items;       // قائمة العناصر
  
  // ===== التوقيت =====
  final DateTime sentAt;
  final DateTime expiresAt;
  
  // ===== ملاحظات =====
  final String? specialInstructions;
  
  // ===== Wallet Hold Info =====
  final String? holdId;              // Hold ID من Wallet Service
  final String? holdStatus;          // ACTIVE, RELEASED, SETTLED
  final double? holdAmount;          // المبلغ المحجوز

  WaveOffer({
    required this.offerId,
    required this.orderId,
    required this.jobId,
    required this.waveNumber,
    required this.rank,
    required this.score,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.restaurantLat,
    required this.restaurantLng,
    this.restaurantImageUrl,
    required this.customerId,
    required this.customerName,
    required this.customerAddress,
    required this.customerLat,
    required this.customerLng,
    this.customerPhone,
    required this.orderTotal,
    required this.deliveryFee,
    this.bonusAmount = 0,
    this.tip = 0,
    required this.estimatedEarnings,
    required this.currency,
    required this.distance,
    required this.estimatedMinutes,
    required this.itemsCount,
    required this.items,
    required this.sentAt,
    required this.expiresAt,
    this.specialInstructions,
    this.holdId,
    this.holdStatus,
    this.holdAmount,
  });

  factory WaveOffer.fromJson(Map<String, dynamic> json) {
    // Parse items list
    List<OrderItem> itemsList = [];
    if (json['items'] != null && json['items'] is List) {
      itemsList = (json['items'] as List)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return WaveOffer(
      offerId: json['offerId'] ?? '',
      orderId: json['orderId'] ?? '',
      jobId: json['jobId'] ?? '',
      
      waveNumber: json['waveNumber'] ?? 1,
      rank: json['rank'] ?? 1,
      score: (json['score'] ?? 0).toDouble(),
      
      restaurantId: json['restaurantId'] ?? '',
      restaurantName: json['restaurantName'] ?? '',
      restaurantAddress: json['restaurantAddress'] ?? '',
      restaurantLat: (json['restaurantLat'] ?? 0).toDouble(),
      restaurantLng: (json['restaurantLng'] ?? 0).toDouble(),
      restaurantImageUrl: json['restaurantImageUrl'],
      
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      customerAddress: json['customerAddress'] ?? '',
      customerLat: (json['customerLat'] ?? 0).toDouble(),
      customerLng: (json['customerLng'] ?? 0).toDouble(),
      customerPhone: json['customerPhone'],
      
      orderTotal: (json['orderTotal'] ?? 0).toDouble(),
      deliveryFee: (json['deliveryFee'] ?? 0).toDouble(),
      bonusAmount: (json['bonusAmount'] ?? 0).toDouble(),
      tip: (json['tip'] ?? 0).toDouble(),
      estimatedEarnings: (json['estimatedEarnings'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'IQD',
      
      distance: (json['distance'] ?? 0).toDouble(),
      estimatedMinutes: json['estimatedMinutes'] ?? 0,
      
      itemsCount: json['itemsCount'] ?? itemsList.length,
      items: itemsList,
      
      sentAt: json['sentAt'] != null 
          ? DateTime.parse(json['sentAt']) 
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null 
          ? DateTime.parse(json['expiresAt']) 
          : DateTime.now().add(const Duration(seconds: 30)),
      
      specialInstructions: json['specialInstructions'],
      
      holdId: json['holdId'],
      holdStatus: json['holdStatus'],
      holdAmount: json['holdAmount'] != null ? (json['holdAmount'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'offerId': offerId,
      'orderId': orderId,
      'jobId': jobId,
      'waveNumber': waveNumber,
      'rank': rank,
      'score': score,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'restaurantAddress': restaurantAddress,
      'restaurantLat': restaurantLat,
      'restaurantLng': restaurantLng,
      'restaurantImageUrl': restaurantImageUrl,
      'customerId': customerId,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'customerLat': customerLat,
      'customerLng': customerLng,
      'customerPhone': customerPhone,
      'orderTotal': orderTotal,
      'deliveryFee': deliveryFee,
      'estimatedEarnings': estimatedEarnings,
      'currency': currency,
      'distance': distance,
      'estimatedMinutes': estimatedMinutes,
      'itemsCount': itemsCount,
      'items': items.map((item) => item.toJson()).toList(),
      'sentAt': sentAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'specialInstructions': specialInstructions,
      'holdId': holdId,
      'holdStatus': holdStatus,
      'holdAmount': holdAmount,
    };
  }

  /// حساب الوقت المتبقي بالثواني
  int get remainingSeconds {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) {
      return 0;
    }
    return expiresAt.difference(now).inSeconds;
  }

  /// هل العرض منتهي؟
  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  /// مجموع كمية العناصر
  int get totalItemsQuantity {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }
}
