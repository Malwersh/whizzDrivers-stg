class Trip {
  final String tripId,
      orderId,
      orderNumber,
      pickupAddress,
      deliveryAddress,
      customerName,
      restaurantName;
  final String? tripNumber;
  final double deliveryFee, waveBonus, tip, finalDeliveryFee;
  final int? waveNumber;
  final bool isEmergencyWave;
  final Map<String, double> pickupLocation, deliveryLocation;
  final DateTime createdAt;
  final DateTime? pickupTime, deliveryTime, completedAt, acceptedAt;
  final TripStatus status;
  final double? driverEarnings,
      driverBaseEarnings,
      cashCollectedAmount,
      driverCashRetained,
      driverWalletCredit,
      settledCollateral,
      estimatedDistanceMeters;
  final int? durationSeconds, itemCount, quantity;
  final String earningsState;
  final String? paymentMethod, holdStatus;
  final int deliveryProofCount;
  final bool hasReturnCase;
  Trip(
      {required this.tripId,
      this.tripNumber,
      required this.orderId,
      required this.orderNumber,
      required this.deliveryFee,
      this.waveBonus = 0,
      this.tip = 0,
      double? finalDeliveryFee,
      this.waveNumber,
      this.isEmergencyWave = false,
      required this.pickupLocation,
      required this.pickupAddress,
      this.pickupTime,
      required this.deliveryLocation,
      required this.deliveryAddress,
      this.deliveryTime,
      required this.status,
      required this.customerName,
      required this.restaurantName,
      required this.createdAt,
      this.completedAt,
      this.acceptedAt,
      this.driverEarnings,
      this.driverBaseEarnings,
      this.earningsState = 'UNAVAILABLE',
      this.cashCollectedAmount,
      this.driverCashRetained,
      this.driverWalletCredit,
      this.settledCollateral,
      this.estimatedDistanceMeters,
      this.durationSeconds,
      this.itemCount,
      this.quantity,
      this.paymentMethod,
      this.holdStatus,
      this.deliveryProofCount = 0,
      this.hasReturnCase = false})
      : finalDeliveryFee = finalDeliveryFee ?? 0;
  static double? number(dynamic n) =>
      n is num && n.isFinite ? n.toDouble() : null;
  static DateTime? date(dynamic d) =>
      d is String ? DateTime.tryParse(d)?.toLocal() : null;
  static Map<String, double> point(dynamic p) {
    if (p is! Map) return {};
    final lat = number(p['lat']), lng = number(p['lng']);
    return {if (lat != null) 'lat': lat, if (lng != null) 'lng': lng};
  }

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
      tripId: j['tripId'] ?? '',
      tripNumber: j['tripNumber']?.toString(),
      orderId: j['orderId'] ?? '',
      orderNumber: j['orderNumber'] ?? '',
      deliveryFee: number(j['deliveryFee']) ?? 0,
      tip: number(j['driverTip'] ?? j['tip']) ?? 0,
      waveBonus: number(j['waveBonus']) ?? 0,
      finalDeliveryFee: number(j['finalDeliveryFee']),
      pickupLocation: point(j['pickupLocation']),
      deliveryLocation: point(j['deliveryLocation']),
      pickupAddress: j['pickupAddress'] ?? '',
      deliveryAddress: j['deliveryAddress'] ?? '',
      customerName: j['customerName'] ?? '',
      restaurantName: j['restaurantName'] ?? '',
      createdAt: date(j['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      completedAt: date(j['completedAt']),
      acceptedAt: date(j['acceptedAt']),
      pickupTime: date(j['pickupTime']),
      deliveryTime: date(j['deliveryTime']),
      status: switch (j['status']) {
        'completed' => TripStatus.completed,
        'cancelled' => TripStatus.cancelled,
        'returned' => TripStatus.returned,
        'in_progress' => TripStatus.inProgress,
        _ => TripStatus.unknown
      },
      driverEarnings: number(j['driverEarnings']),
      driverBaseEarnings: number(j['driverBaseEarnings']),
      earningsState: j['earningsState'] ?? 'UNAVAILABLE',
      cashCollectedAmount: number(j['cashCollectedAmount']),
      driverCashRetained: number(j['driverCashRetained']),
      driverWalletCredit: number(j['driverWalletCredit']),
      settledCollateral: number(j['settledCollateral']),
      estimatedDistanceMeters: number(j['estimatedDistanceMeters']),
      durationSeconds: (j['durationSeconds'] as num?)?.toInt(),
      itemCount: (j['itemCount'] as num?)?.toInt(),
      quantity: (j['quantity'] as num?)?.toInt(),
      paymentMethod: j['paymentMethod'],
      holdStatus: j['holdStatus'],
      deliveryProofCount: (j['deliveryProofCount'] as num?)?.toInt() ?? 0,
      hasReturnCase: j['hasReturnCase'] == true);
  DateTime? get activityDate =>
      completedAt ?? (createdAt.year > 1970 ? createdAt : null);
  String get displayReference => tripNumber?.trim().isNotEmpty == true
      ? tripNumber!.trim()
      : orderNumber.isNotEmpty
          ? orderNumber
          : tripId.split('-').first;
  String get dateKey {
    final d = activityDate;
    return d == null
        ? 'unknown'
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String time(DateTime? t) {
    if (t == null) return 'غير متاح';
    return '${t.hour % 12 == 0 ? 12 : t.hour % 12}:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'م' : 'ص'}';
  }

  String getFormattedPickupTime() => time(pickupTime);
  String getFormattedDeliveryTime() => time(deliveryTime);
  String getFormattedDate() {
    final d = activityDate;
    if (d == null) return 'تاريخ غير متاح';
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    const days = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ];
    return '${days[d.weekday - 1]}، ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String getStatusText() => switch (status) {
        TripStatus.completed => 'مكتملة',
        TripStatus.cancelled => 'ملغاة',
        TripStatus.returned => 'مرتجعة',
        TripStatus.inProgress => 'جارية',
        TripStatus.unknown => 'غير محددة'
      };
}

enum TripStatus { completed, cancelled, returned, inProgress, unknown }
