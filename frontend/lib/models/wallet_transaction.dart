import 'package:flutter/material.dart';
import '../design_system/app_colors.dart';

/// Wallet Transaction Model
///
/// Represents a single ledger entry (transaction) in the wallet.
/// Each transaction has a direction (CREDIT/DEBIT) and a type.
class WalletTransaction {
  final String entryId;
  final String walletId;
  final String direction; // CREDIT or DEBIT
  final int amount; // بالدينار العراقي
  final String
      type; // TOPUP, HOLD, RELEASE_HOLD, SETTLE_GROSS, SETTLE_EARNINGS, etc.
  final String status; // POSTED, REVERSED
  final String? balanceType; // Explicit AVAILABLE/LOCKED ledger bucket.
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
    this.balanceType,
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

  /// Hold placed when accepting an order (money temporarily locked, NOT lost).
  bool get isHoldCreated => type == 'HOLD_CREATED' || type == 'HOLD';

  /// Hold returned to the available balance (e.g. order cancelled/unassigned).
  bool get isHoldReleased =>
      type == 'HOLD_RELEASED' ||
      type == 'HOLD_PARTIAL_RELEASE' ||
      type == 'RELEASE_HOLD';

  /// Hold captured on successful delivery (real deduction / platform fee).
  bool get isHoldCaptured => type == 'HOLD_CAPTURED';

  /// Short, human-friendly order reference (first segment of the UUID).
  String? get shortOrderId {
    final id = relatedOrderId;
    if (id == null || id.isEmpty) return null;
    final dash = id.indexOf('-');
    return dash > 0
        ? id.substring(0, dash)
        : id.substring(0, id.length.clamp(0, 8));
  }

  /// Internal double-entry "mirror" rows that should be hidden from the driver:
  /// the locked-account side of a hold creation (`#HOLD_CREDIT`) and the
  /// locked-account side of a hold release. Showing them double-counts the
  /// money and confuses the driver.
  bool get isInternalMirror {
    if (entryId.endsWith('#HOLD_CREDIT')) return true;
    if (isHoldCreated && balanceType == 'LOCKED' && isCredit) return true;
    if (isHoldReleased && isDebit) return true;
    return false;
  }

  /// Filters a raw ledger list down to the events that are meaningful to a
  /// driver (removes internal accounting mirrors).
  static List<WalletTransaction> driverVisible(List<WalletTransaction> all) =>
      all.where((t) => !t.isInternalMirror).toList();

  /// Sign shown before the amount. A hold is neutral (money is only locked,
  /// not spent) so no sign is shown.
  String get amountSign {
    if (isHoldCreated) return '';
    return isCredit ? '+' : '-';
  }

  /// Short status chip describing what happened, in driver terms.
  String? get statusLabel {
    if (isReversed) return 'ملغاة';
    if (isHoldCreated) return 'محجوز مؤقتاً';
    if (isHoldReleased) return 'أُعيد إلى رصيدك';
    if (isHoldCaptured) return 'سُوّي عند التسليم';
    if (type == 'TOPUP') return 'شحن رصيد';
    if (type == 'SETTLE_EARNINGS' ||
        type == 'SETTLEMENT_RECEIVED' ||
        type == 'SETTLE_GROSS') {
      return 'أرباح';
    }
    return null;
  }

  /// Get user-friendly title based on transaction type
  String get displayTitle {
    final order = shortOrderId != null ? ' #$shortOrderId' : '';
    switch (type) {
      case 'HOLD_CREATED':
      case 'HOLD':
        return '🔒 حجز مؤقت لطلب$order';
      case 'HOLD_RELEASED':
      case 'HOLD_PARTIAL_RELEASE':
      case 'RELEASE_HOLD':
        return '🔓 إرجاع مبلغ محجوز$order';
      case 'HOLD_CAPTURED':
        return '✅ تسوية ضمان الطلب$order';
      case 'SETTLEMENT_RECEIVED':
      case 'SETTLE_GROSS':
        return '💰 أرباح توصيل الطلب$order';
      case 'SETTLE_EARNINGS':
        return '🎁 أرباحك من الطلب$order';
      case 'TOPUP':
        return '💳 شحن رصيد';
      case 'FULL_CASH_COMPLETED':
        return 'تسوية تحصيل الطلب$order';
      case 'CASH_ADJUDICATION_SETTLED':
        return 'تسوية مراجعة التحصيل$order';
      case 'ORDER_EXCEPTION_FINANCIAL':
        return 'تعويض أو تسوية مراجعة الطلب$order';
      case 'PLATFORM_CREDIT':
        return '⭐ رصيد من المنصة';
      case 'TRANSFER':
        return '↔️ تحويل';
      case 'ADJUSTMENT':
        return '🔧 تصحيح رصيد';
      case 'REVERSAL':
        return '↩️ عكس معاملة';
      default:
        return description ?? 'معاملة';
    }
  }

  /// Get icon for transaction type
  IconData get icon {
    switch (type) {
      case 'SETTLEMENT_RECEIVED':
      case 'SETTLE_GROSS':
      case 'SETTLE_EARNINGS':
        return Icons.local_shipping;
      case 'HOLD_CREATED':
      case 'HOLD':
        return Icons.lock;
      case 'HOLD_RELEASED':
      case 'HOLD_PARTIAL_RELEASE':
      case 'HOLD_CAPTURED':
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

  /// Get color for transaction (green for credit, red for debit, amber for a
  /// temporary hold which is neither earned nor spent).
  Color get color {
    if (isReversed) return Colors.grey;
    if (isHoldCreated) return AppColors.warning;
    return isCredit ? Colors.green : Colors.red;
  }

  /// Get background color for transaction icon
  Color get backgroundColor {
    if (isReversed) return Colors.grey.withValues(alpha: 0.1);
    if (isHoldCreated) return AppColors.warning.withValues(alpha: 0.12);
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
    final metadata = json['metadata'] is Map<String, dynamic>
        ? json['metadata'] as Map<String, dynamic>
        : <String, dynamic>{};

    final rawType = (json['type'] ?? '').toString().toUpperCase();
    final rawCategory = (json['category'] ?? '').toString().toUpperCase();
    var normalizedType = rawCategory.isNotEmpty ? rawCategory : rawType;
    if (normalizedType == 'FULL_CASH_RELEASED')
      normalizedType = 'HOLD_RELEASED';
    if (normalizedType == 'FULL_CASH_COMPLETED' &&
        metadata['balanceType'] == 'LOCKED') normalizedType = 'HOLD_CAPTURED';

    final direction = (json['direction'] as String?) ??
        (rawType == 'DEBIT' || rawType == 'CREDIT'
            ? rawType
            : ((json['amount'] as num?) != null && (json['amount'] as num) < 0
                ? 'DEBIT'
                : 'CREDIT'));

    final bucket = metadata['balanceType']?.toString().toUpperCase();
    if (rawCategory == 'COD_COMPLETED' &&
        metadata['financialSchemaVersion'] == 2 &&
        (json['walletId']?.toString().startsWith('WALLET#DRIVER#') ?? false) &&
        bucket == 'LOCKED' &&
        direction == 'DEBIT') {
      normalizedType = 'HOLD_CAPTURED';
    }
    final amountNum = (json['amount'] as num?) ?? 0;

    return WalletTransaction(
      // Prefer the ledger sort key (`sk`) as the unique identity: it is unique
      // per entry within a wallet. `transactionId` is NOT unique because the two
      // sides of a double-entry (e.g. HOLD_DEBIT and HOLD_CREDIT) share the same
      // transactionId, which would cause legitimate entries to be dropped by the
      // de-duplication logic in the transaction list.
      entryId: (json['sk'] as String?) ??
          (json['entryId'] as String?) ??
          (json['transactionId'] as String?) ??
          (json['txnId'] as String?) ??
          '${json['walletId'] ?? 'wallet'}-${json['createdAt'] ?? json['timestamp'] ?? DateTime.now().toIso8601String()}',
      walletId: (json['walletId'] as String?) ?? '',
      direction: direction,
      balanceType: bucket,
      amount: amountNum.abs().toInt(),
      type: normalizedType.isNotEmpty ? normalizedType : 'TRANSFER',
      status: (json['status'] as String?) ?? 'POSTED',
      description: json['description'] as String?,
      relatedOrderId: (json['relatedOrderId'] as String?) ??
          (metadata['orderId'] as String?) ??
          ((json['relatedEntityType']?.toString().toUpperCase() == 'ORDER' ||
                  json['relatedEntityType']?.toString().toUpperCase() == 'HOLD')
              ? json['relatedEntityId'] as String?
              : null),
      relatedHoldId: (json['relatedHoldId'] as String?) ??
          (metadata['holdId'] as String?) ??
          (json['relatedEntityType']?.toString().toUpperCase() == 'HOLD'
              ? json['relatedEntityId'] as String?
              : null),
      relatedTopupId: (json['relatedTopupId'] as String?) ??
          (metadata['topupId'] as String?) ??
          (json['relatedEntityType']?.toString().toUpperCase() == 'TOPUP'
              ? json['relatedEntityId'] as String?
              : null),
      createdAt: DateTime.tryParse(
            (json['createdAt'] ??
                    json['timestamp'] ??
                    DateTime.now().toIso8601String())
                .toString(),
          ) ??
          DateTime.now(),
    );
  }

  /// Convert WalletTransaction to JSON
  Map<String, dynamic> toJson() {
    return {
      'entryId': entryId,
      'walletId': walletId,
      'direction': direction,
      'metadata': {if (balanceType != null) 'balanceType': balanceType},
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
