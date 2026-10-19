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
  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  // بعض المسارات القديمة قد ترسل المبالغ بوحدة fils (IQD * 1000).
  // نحولها إلى IQD عندما تظهر بصيغة مضخمة مقارنة بالمرجع.
  static double _normalizeIqd(dynamic rawAmount, {double? reference}) {
    final amount = _toDouble(rawAmount);
    if (amount <= 0) return 0;

    final ref = reference ?? 0;
    if (ref > 0) {
      final ratio = amount / ref;
      if (ratio >= 900 && ratio <= 1100) {
        return amount / 1000;
      }
      // fallback heuristic for legacy payloads: huge order amount vs modest earnings.
      if (ratio > 200 && amount >= 100000) {
        return amount / 1000;
      }
    }

    if (amount >= 100000 && amount % 1000 == 0) {
      return amount / 1000;
    }

    return amount;
  }

  // ===== معلومات العرض =====
  final String offerId;
  final String orderId;
  final String jobId;
  final String? dispatchCycleId;

  // ===== معلومات الموجة =====
  final int waveNumber; // 1, 2, or 3
  final int rank; // 1-5 (ترتيب السائق في الموجة)
  final double score; // النقاط المحسوبة (0-100)
  final bool isEmergencyWave; // هل هي موجة طارئة

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
  final Map<String, dynamic>? financialTerms;
  final int? legacySourceVersion;
  final String? moneyUnit;
  final double orderTotal; // مجموع الطلب
  final double deliveryFee; // أجرة التوصيل الأساسية
  final double bonusAmount; // المكافأة (البونص) من الموجة
  final double tip; // الإكرامية من العميل
  final double
      estimatedEarnings; // الأرباح المتوقعة (deliveryFee + bonusAmount)
  final double? holdRequiredAmount; // المبلغ المطلوب فعلياً للحجز على المحفظة
  final String currency; // رمز العملة (IQD, USD, etc.)

  // ===== المسافة والوقت =====
  final double distance; // بالكيلومتر
  final int estimatedMinutes; // الوقت المتوقع

  // ===== العناصر =====
  final int itemsCount; // عدد العناصر الإجمالي
  final List<OrderItem> items; // قائمة العناصر

  // ===== التوقيت =====
  final DateTime sentAt;
  final DateTime expiresAt;

  // ===== ملاحظات =====
  final String? specialInstructions;

  // ===== Wallet Hold Info =====
  final String? holdId; // Hold ID من Wallet Service
  final String? holdStatus; // ACTIVE, RELEASED, SETTLED
  final double? holdAmount; // المبلغ المحجوز

  WaveOffer({
    required this.offerId,
    required this.orderId,
    required this.jobId,
    this.dispatchCycleId,
    required this.waveNumber,
    this.isEmergencyWave = false,
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
    this.holdRequiredAmount,
    this.financialTerms,
    this.legacySourceVersion,
    this.moneyUnit,
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
    if (['DRIVER_OFFER_PROPOSAL', 'DRIVER_DELIVERY_FUNDED_OFFER']
        .contains(json['kind'])) {
      double readAmount(dynamic value) {
        if (value is! Map ||
            value['currency'] != 'IQD' ||
            value['scale'] != 1000 ||
            value['moneySchemaVersion'] != 1 ||
            value['minorAmount'] is! int ||
            value['minorAmount'] < 0 ||
            value['minorAmount'] > 9007199254740991) {
          throw const FormatException('Invalid financial offer money');
        }
        return value['minorAmount'] / 1000.0;
      }

      double amount(String field) => readAmount(json[field]);
      if ((json['kind'] == 'DRIVER_OFFER_PROPOSAL'
              ? json['schemaVersion'] != 1
              : json['schemaVersion'] != 2) ||
          json['paymentMethod'] != 'COD' ||
          json['waveNumber'] is! int ||
          json['waveNumber'] < 1 ||
          json['offerDigest'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(json['offerDigest']) ||
          json['offerId'] is! String ||
          !(json['offerId'] as String).startsWith('FINO:')) {
        throw const FormatException('Invalid financial offer');
      }
      for (final field in [
        'driverCashRetained',
        'laterWalletEarningCredit',
        'laterWalletTipCredit'
      ]) {
        amount(field);
      }
      if ((amount('driverEarning') +
                  amount('driverTip') -
                  amount('driverTotalEntitlement'))
              .abs() >
          0.00001) {
        throw const FormatException('Inconsistent financial offer entitlement');
      }
      final display = json['display'];
      final displayItems = <OrderItem>[];
      Map restaurant = {};
      Map customer = {};
      if (display != null) {
        if (display is! Map ||
            display['schemaVersion'] != 1 ||
            display['items'] is! List ||
            display['restaurant'] is! Map) {
          throw const FormatException('Invalid offer display');
        }
        restaurant = display['restaurant'];
        if (display['customer'] != null) {
          final recipient = display['customer'];
          if (recipient is! Map ||
              recipient['name'] is! String ||
              recipient['address'] is! String) {
            throw const FormatException('Invalid offer recipient');
          }
          customer = recipient;
        }
        for (final item in display['items']) {
          if (item is! Map ||
              item['name'] is! String ||
              item['quantity'] is! int ||
              item['quantity'] < 1) {
            throw const FormatException('Invalid offer item');
          }
          final notes = <String>[
            if (item['notes'] is String && item['notes'].isNotEmpty)
              item['notes'],
            if (item['modifiers'] is List)
              ...List<String>.from(item['modifiers'])
          ].join(' • ');
          displayItems.add(OrderItem(
              itemId: item['itemId'] ?? '',
              name: item['name'],
              quantity: item['quantity'],
              price: readAmount(item['unitPrice']),
              imageUrl: item['imageUrl'],
              notes: notes));
        }
        if (display['lineCount'] != displayItems.length ||
            display['totalQuantity'] !=
                displayItems.fold<int>(0, (n, i) => n + i.quantity)) {
          throw const FormatException('Inconsistent offer item count');
        }
      }
      final pickup = json['pickupLocation'] as Map<String, dynamic>;
      return WaveOffer(
          dispatchCycleId: json['dispatchCycleId'],
          offerId: json['offerId'],
          orderId: json['orderId'],
          jobId: '',
          waveNumber: json['waveNumber'],
          rank: 1,
          score: 0,
          restaurantId: json['branchId'],
          restaurantName: restaurant['name'] ?? 'استلام الطلب',
          restaurantAddress: restaurant['address'] ?? '',
          restaurantImageUrl: restaurant['imageUrl'],
          restaurantLat: (pickup['latitude'] as num).toDouble(),
          restaurantLng: (pickup['longitude'] as num).toDouble(),
          customerId: '',
          customerName: customer['name'] ?? '',
          customerAddress: customer['address'] ?? '',
          customerLat: 0,
          customerLng: 0,
          orderTotal: amount('customerCashToCollect'),
          deliveryFee: amount('driverEarning'),
          tip: amount('driverTip'),
          estimatedEarnings: amount('driverTotalEntitlement'),
          holdRequiredAmount: amount('driverWalletHold'),
          currency: 'IQD',
          distance: (json['totalDistanceMeters'] as num) / 1000,
          estimatedMinutes: ((json['totalDurationSeconds'] as num) / 60).ceil(),
          itemsCount: displayItems.fold<int>(0, (n, i) => n + i.quantity),
          items: displayItems,
          sentAt: DateTime.parse(json['createdAt']),
          expiresAt: DateTime.parse(json['expiresAt']),
          financialTerms: Map<String, dynamic>.unmodifiable(json));
    }
    // Parse items list
    List<OrderItem> itemsList = [];
    if (json['items'] != null && json['items'] is List) {
      itemsList = (json['items'] as List)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    final explicitLegacy =
        json['legacySourceVersion'] != null || json['moneyUnit'] != null;
    double whole(String field) {
      final raw = json[field];
      final value = raw is num
          ? raw.toDouble()
          : raw is String && RegExp(r'^\d+$').hasMatch(raw)
              ? double.tryParse(raw)
              : null;
      if (value == null ||
          !value.isFinite ||
          value < 0 ||
          value > 9007199254740991 ||
          value != value.truncateToDouble()) {
        throw const FormatException('Invalid explicit IQD amount');
      }
      return value;
    }

    if (explicitLegacy) {
      if (json['legacySourceVersion'].toString() != '1' ||
          json['moneyUnit'] != 'IQD_WHOLE' ||
          json['currency'] != 'IQD' ||
          whole('bonusAmount') != 0 ||
          json['isEmergencyWave'] == true ||
          json['isEmergencyWave'] == 'true' ||
          whole('deliveryFee') + whole('tip') > 9007199254740991 ||
          whole('estimatedEarnings') != whole('deliveryFee') + whole('tip') ||
          whole('holdRequiredAmount') + whole('estimatedEarnings') >
              9007199254740991 ||
          whole('orderTotal') !=
              whole('holdRequiredAmount') + whole('estimatedEarnings')) {
        throw const FormatException('Inconsistent explicit legacy offer');
      }
    }
    final deliveryFeeRaw = _toDouble(json['deliveryFee']);
    final bonusAmountRaw = _toDouble(json['bonusAmount']);
    final tipRaw = _toDouble(json['tip']);
    final estimatedEarningsRaw = _toDouble(json['estimatedEarnings']);
    final orderTotalRaw = _toDouble(json['orderTotal']);

    final normalizedDeliveryFee =
        explicitLegacy ? whole('deliveryFee') : _normalizeIqd(deliveryFeeRaw);
    final normalizedBonusAmount =
        explicitLegacy ? whole('bonusAmount') : _normalizeIqd(bonusAmountRaw);
    final normalizedTip = explicitLegacy ? whole('tip') : _normalizeIqd(tipRaw);
    final normalizedEstimatedEarnings = explicitLegacy
        ? whole('estimatedEarnings')
        : _normalizeIqd(
            estimatedEarningsRaw,
            reference: normalizedDeliveryFee > 0 ? normalizedDeliveryFee : null,
          );
    final normalizedOrderTotal = explicitLegacy
        ? whole('orderTotal')
        : _normalizeIqd(
            orderTotalRaw,
            reference: normalizedEstimatedEarnings > 0
                ? normalizedEstimatedEarnings
                : null,
          );
    final normalizedHoldRequired = explicitLegacy
        ? whole('holdRequiredAmount')
        : json['holdRequiredAmount'] != null
            ? _normalizeIqd(
                json['holdRequiredAmount'],
                reference:
                    normalizedOrderTotal > 0 ? normalizedOrderTotal : null,
              )
            : null;

    return WaveOffer(
      offerId: json['offerId'] ?? '',
      orderId: json['orderId'] ?? '',
      jobId: json['jobId'] ?? '',
      dispatchCycleId: json['dispatchCycleId'] ?? json['cycleId'],
      waveNumber: json['waveNumber'] ?? 1,
      isEmergencyWave: json['isEmergencyWave'] == true ||
          json['isEmergencyWave']?.toString().toLowerCase() == 'true',
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
      legacySourceVersion: explicitLegacy ? 1 : null,
      moneyUnit: explicitLegacy ? 'IQD_WHOLE' : null,
      orderTotal: normalizedOrderTotal,
      deliveryFee: normalizedDeliveryFee,
      bonusAmount: normalizedBonusAmount,
      tip: normalizedTip,
      estimatedEarnings: normalizedEstimatedEarnings,
      holdRequiredAmount: normalizedHoldRequired,
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
      holdAmount: json['holdAmount'] != null
          ? (json['holdAmount'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    if (financialTerms != null)
      return Map<String, dynamic>.from(financialTerms!);
    return {
      'offerId': offerId,
      'orderId': orderId,
      'jobId': jobId,
      if (dispatchCycleId != null) 'dispatchCycleId': dispatchCycleId,
      'waveNumber': waveNumber,
      'isEmergencyWave': isEmergencyWave,
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
      if (legacySourceVersion != null)
        'legacySourceVersion': legacySourceVersion,
      if (moneyUnit != null) 'moneyUnit': moneyUnit,
      'tip': tip,
      'bonusAmount': bonusAmount,
      'orderTotal': orderTotal,
      'deliveryFee': deliveryFee,
      'estimatedEarnings': estimatedEarnings,
      'holdRequiredAmount': holdRequiredAmount,
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
  int get durationSeconds =>
      expiresAt.difference(sentAt).inSeconds.clamp(1, 3600);

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

  /// المبلغ المعتمد للتحقق من كفاية الرصيد
  double get requiredBalanceAmount {
    if (holdRequiredAmount != null && holdRequiredAmount! >= 0)
      return holdRequiredAmount!;
    return orderTotal;
  }

  /// مجموع كمية العناصر
  int get totalItemsQuantity {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }
}
