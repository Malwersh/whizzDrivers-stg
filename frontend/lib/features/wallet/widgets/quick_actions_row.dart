import '../screens/monthly_statement_screen.dart';
import '../providers/wallet_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/topup_screen.dart';
import 'package:flutter/material.dart';
import '../../../design_system/app_colors.dart';

/// Quick Actions Row Widget
///
/// Provides quick access buttons for common wallet actions
/// - Top up balance (شحن الرصيد)
/// - Monthly statement (الكشف الشهري)
class QuickActionsRow extends ConsumerWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          // Top up button
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text(
                'شحن الرصيد',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TopupScreen()));
                if (context.mounted)
                  ref.read(walletRefreshProvider.notifier).state++;
              },
            ),
          ),

          const SizedBox(width: 12),

          // Monthly statement button
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
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                  color: AppColors.secondary.withValues(alpha: 0.35),
                  width: 1.25,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const MonthlyStatementScreen()));
              },
            ),
          ),
        ],
      ),
    );
  }
}
