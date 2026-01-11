class Trip {
  final String tripId;
  final String orderId;
  final String orderNumber;
  final double deliveryFee; // الرسوم الأساسية
  final double waveBonus; // البونص (25% في الموجة 5)
  final double tip; // الإكرامية من العميل
  final double finalDeliveryFee; // الإجمالي
  final int? waveNumber; // رقم الموجة (1-5)
  final bool isEmergencyWave; // هل هي موجة طوارئ؟
  final Map<String, double> pickupLocation;
  final String pickupAddress;
  final DateTime? pickupTime;
  final Map<String, double> deliveryLocation;
  final String deliveryAddress;
  final DateTime? deliveryTime;
  final TripStatus status;
  final String customerName;
  final String restaurantName;
  final DateTime createdAt;
  final DateTime? completedAt;

  Trip({
    required this.tripId,
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
  }) : finalDeliveryFee = finalDeliveryFee ?? (deliveryFee + waveBonus);

  // Factory constructor from JSON
  factory Trip.fromJson(Map<String, dynamic> json) {
    final baseDeliveryFee = (json['deliveryFee'] ?? 0).toDouble();
    final waveBonus = (json['waveBonus'] ?? 0).toDouble();
    final tip = (json['tip'] ?? 0).toDouble();
    final finalDeliveryFee = (json['finalDeliveryFee'] ?? (baseDeliveryFee + waveBonus)).toDouble();
    
    return Trip(
      tripId: json['tripId'] ?? '',
      orderId: json['orderId'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      deliveryFee: baseDeliveryFee,
      waveBonus: waveBonus,
      tip: tip,
      finalDeliveryFee: finalDeliveryFee,
      waveNumber: json['waveNumber'],
      isEmergencyWave: json['isEmergencyWave'] ?? false,
      pickupLocation: {
        'lat': (json['pickupLocation']?['lat'] ?? 0).toDouble(),
        'lng': (json['pickupLocation']?['lng'] ?? 0).toDouble(),
      },
      pickupAddress: json['pickupAddress'] ?? 'غير محدد',
      pickupTime: json['pickupTime'] != null 
          ? DateTime.parse(json['pickupTime']) 
          : null,
      deliveryLocation: {
        'lat': (json['deliveryLocation']?['lat'] ?? 0).toDouble(),
        'lng': (json['deliveryLocation']?['lng'] ?? 0).toDouble(),
      },
      deliveryAddress: json['deliveryAddress'] ?? 'غير محدد',
      deliveryTime: json['deliveryTime'] != null 
          ? DateTime.parse(json['deliveryTime']) 
          : null,
      status: _parseStatus(json['status']),
      customerName: json['customerName'] ?? 'عميل',
      restaurantName: json['restaurantName'] ?? 'مطعم غير محدد',
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : null,
    );
  }

  static TripStatus _parseStatus(String? status) {
    switch (status) {
      case 'completed':
        return TripStatus.completed;
      case 'cancelled':
        return TripStatus.cancelled;
      case 'in_progress':
        return TripStatus.inProgress;
      default:
        return TripStatus.completed;
    }
  }

  // Helper to format time as "8:19 AM"
  String getFormattedPickupTime() {
    if (pickupTime == null) return '--:--';
    final hour = pickupTime!.hour;
    final minute = pickupTime!.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String getFormattedDeliveryTime() {
    if (deliveryTime == null) return '--:--';
    final hour = deliveryTime!.hour;
    final minute = deliveryTime!.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  // Helper to format date as "الأحد، 16 نوفمبر"
  String getFormattedDate() {
    const arabicMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    const arabicDays = [
      'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
    ];
    
    final dayName = arabicDays[createdAt.weekday - 1];
    final day = createdAt.day;
    final monthName = arabicMonths[createdAt.month - 1];
    
    return '$dayName، $day $monthName';
  }

  String getStatusText() {
    switch (status) {
      case TripStatus.completed:
        return 'مكتملة';
      case TripStatus.cancelled:
        return 'ملغاة';
      case TripStatus.inProgress:
        return 'جارية';
    }
  }
}

enum TripStatus {
  completed,
  cancelled,
  inProgress,
}
