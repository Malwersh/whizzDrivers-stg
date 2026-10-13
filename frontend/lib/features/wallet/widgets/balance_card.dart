import '../screens/topup_screen.dart';
import 'package:flutter/material.dart';
import '../../../design_system/app_colors.dart';
import '../../../models/wallet_balance.dart';

/// Balance Card Widget
///
/// Displays driver's wallet balance including available, locked, and total balance
/// with visual status indicator
class BalanceCard extends StatelessWidget {
  final WalletBalance balance;
  final VoidCallback? onTransfer;

  const BalanceCard({
    super.key,
    required this.balance,
    this.onTransfer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
                color: AppColors.secondary,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'رصيدك الحالي',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
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
                AppColors.secondary,
              ),
              _buildBalanceColumn(
                'محجوز',
                balance.lockedBalance,
                AppColors.warning,
              ),
              _buildBalanceColumn(
                'الإجمالي',
                balance.totalBalance,
                AppColors.textPrimary,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Divider
          Container(
            height: 1,
            color: AppColors.borderLight,
          ),

          const SizedBox(height: 16),

          // Status Indicator
          _buildStatusIndicator(),

          const SizedBox(height: 16),

          // Actions (top-up / monthly statement) live inside the balance card
          _buildActions(context),
          if (onTransfer != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
                onPressed: onTransfer,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('تحويل الرصيد'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: AppColors.secondary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)))),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text(
              'شحن الرصيد',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TopupScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.receipt_long_rounded,
                size: 18, color: AppColors.secondary),
            label: const Text(
              'الكشف الشهري',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: BorderSide(
                color: AppColors.secondary.withValues(alpha: 0.35),
                width: 1.25,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('الكشف الشهري - قريباً'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      ],
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
    final color = isActive ? AppColors.secondary : AppColors.warning;
    final icon = isActive ? Icons.check_circle : Icons.warning;
    final text = isActive ? 'المحفظة نشطة' : 'المحفظة معلقة';

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w700,
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
