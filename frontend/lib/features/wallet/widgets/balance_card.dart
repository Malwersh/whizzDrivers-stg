import 'package:flutter/material.dart';
import '../../../design_system/app_colors.dart';
import '../../../models/wallet_balance.dart';

/// Balance Card Widget
/// 
/// Displays driver's wallet balance including available, locked, and total balance
/// with visual status indicator
class BalanceCard extends StatelessWidget {
  final WalletBalance balance;

  const BalanceCard({
    super.key,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: AppColors.success,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                '💰 رصيدك الحالي',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Balance Columns
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBalanceColumn(
                'متاح',
                balance.availableBalance,
                AppColors.success,
              ),
              _buildBalanceColumn(
                'محجوز',
                balance.lockedBalance,
                AppColors.warning,
              ),
              _buildBalanceColumn(
                'الإجمالي',
                balance.totalBalance,
                AppColors.secondary,
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Divider
          Container(
            height: 1,
            color: AppColors.border,
          ),
          
          const SizedBox(height: 16),
          
          // Status Indicator
          _buildStatusIndicator(),
        ],
      ),
    );
  }

  Widget _buildBalanceColumn(String label, int amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'د.ع',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final isActive = balance.isActive;
    final color = isActive ? AppColors.success : AppColors.error;
    final icon = isActive ? Icons.check_circle : Icons.warning;
    final text = isActive ? 'المحفظة نشطة' : 'المحفظة معلقة';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
