/// Wallet Balance Model
/// 
/// Represents a driver's wallet balance including available, locked,
/// and minimum required balances.
class WalletBalance {
  final String walletId;
  final int availableBalance;    // المبلغ المتاح للاستخدام (بالدينار العراقي)
  final int lockedBalance;       // المبلغ المحجوز (لطلبات نشطة)
  final int minRequiredBalance;  // الحد الأدنى المطلوب (25,000 للسائقين)
  final String status;           // ACTIVE, SUSPENDED, CLOSED
  final String currency;         // IQD
  final DateTime? createdAt;     // Optional: may not be returned by API
  final DateTime? updatedAt;     // Optional: may not be returned by API

  WalletBalance({
    required this.walletId,
    required this.availableBalance,
    required this.lockedBalance,
    required this.minRequiredBalance,
    required this.status,
    required this.currency,
    this.createdAt,
    this.updatedAt,
  });

  /// Total balance = available + locked
  int get totalBalance => availableBalance + lockedBalance;

  /// Check if available balance is above minimum required
  bool get isAboveMinimum => availableBalance >= minRequiredBalance;

  /// Check if wallet is active
  bool get isActive => status == 'ACTIVE';

  /// Check if wallet is suspended
  bool get isSuspended => status == 'SUSPENDED';

  /// Get percentage of available balance relative to minimum required
  double get minimumBalancePercentage {
    if (minRequiredBalance == 0) return 1.0;
    return (availableBalance / minRequiredBalance).clamp(0.0, 1.0);
  }

  /// Factory constructor to create WalletBalance from JSON
  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      walletId: json['walletId'] as String,
      availableBalance: json['availableBalance'] as int,
      lockedBalance: json['lockedBalance'] as int,
      minRequiredBalance: json['minRequiredBalance'] as int,
      status: json['status'] as String,
      currency: json['currency'] as String,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
    );
  }

  /// Convert WalletBalance to JSON
  Map<String, dynamic> toJson() {
    return {
      'walletId': walletId,
      'availableBalance': availableBalance,
      'lockedBalance': lockedBalance,
      'minRequiredBalance': minRequiredBalance,
      'status': status,
      'currency': currency,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  /// Copy with method for immutable updates
  WalletBalance copyWith({
    String? walletId,
    int? availableBalance,
    int? lockedBalance,
    int? minRequiredBalance,
    String? status,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WalletBalance(
      walletId: walletId ?? this.walletId,
      availableBalance: availableBalance ?? this.availableBalance,
      lockedBalance: lockedBalance ?? this.lockedBalance,
      minRequiredBalance: minRequiredBalance ?? this.minRequiredBalance,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'WalletBalance(walletId: $walletId, available: $availableBalance, locked: $lockedBalance, total: $totalBalance, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletBalance &&
        other.walletId == walletId &&
        other.availableBalance == availableBalance &&
        other.lockedBalance == lockedBalance &&
        other.minRequiredBalance == minRequiredBalance &&
        other.status == status &&
        other.currency == currency;
  }

  @override
  int get hashCode {
    return Object.hash(
      walletId,
      availableBalance,
      lockedBalance,
      minRequiredBalance,
      status,
      currency,
    );
  }
}
