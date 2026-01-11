import 'package:flutter/material.dart';

/// Wallet Transaction Model
/// 
/// Represents a single ledger entry (transaction) in the wallet.
/// Each transaction has a direction (CREDIT/DEBIT) and a type.
class WalletTransaction {
  final String entryId;
  final String walletId;
  final String direction;        // CREDIT or DEBIT
  final int amount;              // بالدينار العراقي
  final String type;             // TOPUP, HOLD, RELEASE_HOLD, SETTLE_GROSS, SETTLE_EARNINGS, etc.
  final String status;           // POSTED, REVERSED
  final String? description;
  final String? relatedOrderId;
  final String? relatedHoldId;
  final String? relatedTopupId;
  final DateTime createdAt;

  WalletTransaction({
    required this.entryId,
    required this.walletId,
    required this.direction,
    required this.amount,
    required this.type,
    required this.status,
    this.description,
    this.relatedOrderId,
    this.relatedHoldId,
    this.relatedTopupId,
    required this.createdAt,
  });

  /// Check if transaction is a credit (adding money)
  bool get isCredit => direction == 'CREDIT';

  /// Check if transaction is a debit (removing money)
  bool get isDebit => direction == 'DEBIT';

  /// Check if transaction is reversed
  bool get isReversed => status == 'REVERSED';

  /// Get user-friendly title based on transaction type
  String get displayTitle {
    switch (type) {
      case 'SETTLE_GROSS':
        return relatedOrderId != null 
            ? '💰 توصيل طلب #$relatedOrderId'
            : '💰 توصيل طلب';
      case 'SETTLE_EARNINGS':
        return relatedOrderId != null
            ? '🎁 أرباحك من الطلب #$relatedOrderId'
            : '🎁 أرباحك';
      case 'HOLD':
        return relatedOrderId != null
            ? '🔒 حجز لطلب #$relatedOrderId'
            : '🔒 حجز مبلغ';
      case 'RELEASE_HOLD':
        return relatedOrderId != null
            ? '🔓 إلغاء حجز الطلب #$relatedOrderId'
            : '🔓 إلغاء حجز';
      case 'TOPUP':
        return '💳 شحن رصيد';
      case 'PLATFORM_CREDIT':
        return '⭐ رصيد من المنصة';
      case 'TRANSFER':
        return '↔️ تحويل';
      case 'ADJUSTMENT':
        return '🔧 تصحيح';
      case 'REVERSAL':
        return '↩️ عكس معاملة';
      default:
        return description ?? 'معاملة';
    }
  }

  /// Get icon for transaction type
  IconData get icon {
    switch (type) {
      case 'SETTLE_GROSS':
      case 'SETTLE_EARNINGS':
        return Icons.local_shipping;
      case 'HOLD':
        return Icons.lock;
      case 'RELEASE_HOLD':
        return Icons.lock_open;
      case 'TOPUP':
        return Icons.add_circle;
      case 'PLATFORM_CREDIT':
        return Icons.card_giftcard;
      case 'TRANSFER':
        return Icons.swap_horiz;
      case 'ADJUSTMENT':
        return Icons.settings;
      case 'REVERSAL':
        return Icons.undo;
      default:
        return Icons.receipt;
    }
  }

  /// Get color for transaction (green for credit, red for debit)
  Color get color {
    if (isReversed) return Colors.grey;
    return isCredit ? Colors.green : Colors.red;
  }

  /// Get background color for transaction icon
  Color get backgroundColor {
    if (isReversed) return Colors.grey.withValues(alpha: 0.1);
    return isCredit 
        ? Colors.green.withValues(alpha: 0.1) 
        : Colors.red.withValues(alpha: 0.1);
  }

  /// Get formatted amount with sign
  String getFormattedAmount({bool includeSign = true}) {
    final sign = includeSign ? (isCredit ? '+' : '-') : '';
    final formattedAmount = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$sign$formattedAmount';
  }

  /// Factory constructor to create WalletTransaction from JSON
  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      entryId: json['entryId'] as String,
      walletId: json['walletId'] as String,
      direction: json['direction'] as String,
      amount: json['amount'] as int,
      type: json['type'] as String,
      status: json['status'] as String,
      description: json['description'] as String?,
      relatedOrderId: json['relatedOrderId'] as String?,
      relatedHoldId: json['relatedHoldId'] as String?,
      relatedTopupId: json['relatedTopupId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Convert WalletTransaction to JSON
  Map<String, dynamic> toJson() {
    return {
      'entryId': entryId,
      'walletId': walletId,
      'direction': direction,
      'amount': amount,
      'type': type,
      'status': status,
      'description': description,
      'relatedOrderId': relatedOrderId,
      'relatedHoldId': relatedHoldId,
      'relatedTopupId': relatedTopupId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'WalletTransaction(entryId: $entryId, direction: $direction, amount: $amount, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletTransaction &&
        other.entryId == entryId &&
        other.walletId == walletId &&
        other.direction == direction &&
        other.amount == amount &&
        other.type == type;
  }

  @override
  int get hashCode {
    return Object.hash(entryId, walletId, direction, amount, type);
  }
}
