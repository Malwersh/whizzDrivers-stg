import 'package:flutter/material.dart';
import '../../../design_system/app_colors.dart';
import '../../../models/wallet_balance.dart';

/// Minimum Balance Indicator Widget
/// 
/// Shows progress toward meeting the minimum required balance (25,000 IQD)
/// with visual progress bar and status message
class MinimumBalanceIndicator extends StatelessWidget {
  final WalletBalance balance;

  const MinimumBalanceIndicator({
    super.key,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final progress = balance.minimumBalancePercentage;
    final isAboveMin = balance.isAboveMinimum;
    final progressColor = isAboveMin ? AppColors.secondary : AppColors.error;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(
                Icons.show_chart,
                size: 20,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 8),
              const Text(
                'الحد الأدنى المطلوب',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 14),
          
          // Thin progress bar with the percentage shown outside, on the left
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 4,
                    child: Stack(
                      children: [
                        Container(color: AppColors.grey200),
                        FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(color: progressColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: progressColor,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Amount Text
          Text(
            '${_formatCurrency(balance.availableBalance)} / ${_formatCurrency(balance.minRequiredBalance)} د.ع',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Status Message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: progressColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  isAboveMin ? Icons.check_circle : Icons.warning,
                  color: progressColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAboveMin
                        ? 'رصيدك أعلى من الحد المطلوب'
                        : 'يرجى شحن المحفظة للوصول للحد الأدنى',
                    style: TextStyle(
                      fontSize: 13,
                      color: progressColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
