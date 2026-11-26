import 'package:flutter/material.dart';
import '../../../design_system/app_colors.dart';
import '../../../models/wallet_transaction.dart';

/// Transaction Tile Widget
/// 
/// Displays a single wallet transaction with icon, title, amount, and date
class TransactionTile extends StatelessWidget {
  final WalletTransaction transaction;
  final bool useBaghdadTime;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.useBaghdadTime=false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderLight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon (neutral, calm)
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              transaction.icon,
              color: AppColors.secondary,
              size: 20,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.displayTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (transaction.statusLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    transaction.statusLabel!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatDate(useBaghdadTime ? transaction.createdAt.toUtc().add(const Duration(hours:3)) : transaction.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Amount (the only color accent)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${transaction.amountSign}${transaction.getFormattedAmount(includeSign: false)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: transaction.color,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'د.ع',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = useBaghdadTime ? DateTime.now().toUtc().add(const Duration(hours:3)) : DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txnDate = DateTime(date.year, date.month, date.day);
    
    if (txnDate == today) {
      return 'اليوم ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (txnDate == today.subtract(const Duration(days: 1))) {
      return 'أمس ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
