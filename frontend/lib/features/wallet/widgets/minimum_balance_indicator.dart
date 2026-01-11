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
    final progressColor = isAboveMin ? AppColors.success : AppColors.error;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: progressColor.withValues(alpha: 0.2),
        ),
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
                color: progressColor,
              ),
              const SizedBox(width: 8),
              const Text(
                '📊 الحد الأدنى المطلوب',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 24,
              child: Stack(
                children: [
                  // Background
                  Container(
                    color: AppColors.grey200,
                  ),
                  // Progress
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isAboveMin
                              ? [
                                  AppColors.success.withValues(alpha: 0.8),
                                  AppColors.success,
                                ]
                              : [
                                  AppColors.error.withValues(alpha: 0.8),
                                  AppColors.error,
                                ],
                        ),
                      ),
                    ),
                  ),
                  // Percentage Text (centered)
                  Center(
                    child: Text(
                      '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: progress > 0.5 ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Amount Text
          Text(
            '${_formatCurrency(balance.availableBalance)} / ${_formatCurrency(balance.minRequiredBalance)} د.ع',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Status Message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: progressColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
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
                        ? '✅ رصيدك أعلى من الحد المطلوب'
                        : '⚠️ يرجى شحن المحفظة للوصول للحد الأدنى',
                    style: TextStyle(
                      fontSize: 13,
                      color: progressColor,
                      fontWeight: FontWeight.w600,
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
