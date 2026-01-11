class EarningsData {
  final double todayEarnings;
  final double weeklyEarnings;
  final double monthlyEarnings;
  final double totalEarnings;
  final int todayDeliveries;
  final int weeklyDeliveries;
  final int monthlyDeliveries;
  final int totalDeliveries;
  final double averageOrderValue;
  final double topRating;
  final List<DailyEarning> dailyBreakdown;
  final List<PaymentMethod> paymentMethods;

  EarningsData({
    required this.todayEarnings,
    required this.weeklyEarnings,
    required this.monthlyEarnings,
    required this.totalEarnings,
    required this.todayDeliveries,
    required this.weeklyDeliveries,
    required this.monthlyDeliveries,
    required this.totalDeliveries,
    required this.averageOrderValue,
    required this.topRating,
    required this.dailyBreakdown,
    required this.paymentMethods,
  });

  factory EarningsData.fromJson(Map<String, dynamic> json) {
    return EarningsData(
      todayEarnings: (json['today_earnings'] ?? 0.0).toDouble(),
      weeklyEarnings: (json['weekly_earnings'] ?? 0.0).toDouble(),
      monthlyEarnings: (json['monthly_earnings'] ?? 0.0).toDouble(),
      totalEarnings: (json['total_earnings'] ?? 0.0).toDouble(),
      todayDeliveries: json['today_deliveries'] ?? 0,
      weeklyDeliveries: json['weekly_deliveries'] ?? 0,
      monthlyDeliveries: json['monthly_deliveries'] ?? 0,
      totalDeliveries: json['total_deliveries'] ?? 0,
      averageOrderValue: (json['average_order_value'] ?? 0.0).toDouble(),
      topRating: (json['top_rating'] ?? 0.0).toDouble(),
      dailyBreakdown:
          (json['daily_breakdown'] as List?)
              ?.map((e) => DailyEarning.fromJson(e))
              .toList() ??
          [],
      paymentMethods:
          (json['payment_methods'] as List?)
              ?.map((e) => PaymentMethod.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class DailyEarning {
  final DateTime date;
  final double amount;
  final int deliveries;

  DailyEarning({
    required this.date,
    required this.amount,
    required this.deliveries,
  });

  factory DailyEarning.fromJson(Map<String, dynamic> json) {
    return DailyEarning(
      date: DateTime.parse(json['date']),
      amount: (json['amount'] ?? 0.0).toDouble(),
      deliveries: json['deliveries'] ?? 0,
    );
  }
}

class PaymentMethod {
  final String id;
  final String type; // zain_cash, asia_cell_pay, ki_card, cash, bank_account
  final String displayName;
  final String? accountNumber;
  final String? phoneNumber;
  final bool isDefault;
  final bool isActive;

  PaymentMethod({
    required this.id,
    required this.type,
    required this.displayName,
    this.accountNumber,
    this.phoneNumber,
    required this.isDefault,
    required this.isActive,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      displayName: json['display_name'] ?? '',
      accountNumber: json['account_number'],
      phoneNumber: json['phone_number'],
      isDefault: json['is_default'] ?? false,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'display_name': displayName,
      'account_number': accountNumber,
      'phone_number': phoneNumber,
      'is_default': isDefault,
      'is_active': isActive,
    };
  }
}
