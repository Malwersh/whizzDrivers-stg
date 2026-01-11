import 'wallet_transaction.dart';

/// Transaction History Model
/// 
/// Represents a paginated list of wallet transactions with metadata.
class TransactionHistory {
  final List<WalletTransaction> transactions;
  final int totalCount;
  final String? nextToken;  // للـ pagination - null إذا لا يوجد المزيد

  TransactionHistory({
    required this.transactions,
    required this.totalCount,
    this.nextToken,
  });

  /// Check if there are more transactions to load
  bool get hasMore => nextToken != null && nextToken!.isNotEmpty;

  /// Check if this is an empty result
  bool get isEmpty => transactions.isEmpty;

  /// Check if this is a non-empty result
  bool get isNotEmpty => transactions.isNotEmpty;

  /// Get number of loaded transactions
  int get count => transactions.length;

  /// Factory constructor to create TransactionHistory from JSON
  factory TransactionHistory.fromJson(Map<String, dynamic> json) {
    return TransactionHistory(
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((t) => WalletTransaction.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      totalCount: json['totalCount'] as int? ?? 0,
      nextToken: json['nextToken'] as String?,
    );
  }

  /// Convert TransactionHistory to JSON
  Map<String, dynamic> toJson() {
    return {
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'totalCount': totalCount,
      'nextToken': nextToken,
    };
  }

  /// Create a copy with updated values
  TransactionHistory copyWith({
    List<WalletTransaction>? transactions,
    int? totalCount,
    String? nextToken,
  }) {
    return TransactionHistory(
      transactions: transactions ?? this.transactions,
      totalCount: totalCount ?? this.totalCount,
      nextToken: nextToken ?? this.nextToken,
    );
  }

  /// Append more transactions (for pagination)
  TransactionHistory appendTransactions(TransactionHistory newHistory) {
    return TransactionHistory(
      transactions: [...transactions, ...newHistory.transactions],
      totalCount: newHistory.totalCount,
      nextToken: newHistory.nextToken,
    );
  }

  @override
  String toString() {
    return 'TransactionHistory(count: $count, totalCount: $totalCount, hasMore: $hasMore)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionHistory &&
        other.transactions == transactions &&
        other.totalCount == totalCount &&
        other.nextToken == nextToken;
  }

  @override
  int get hashCode {
    return Object.hash(transactions, totalCount, nextToken);
  }
}
