import 'package:flutter/material.dart';
import '../../../design_system/app_colors.dart';

/// Quick Actions Row Widget
/// 
/// Provides quick access buttons for common wallet actions
/// - Top up balance (شحن الرصيد)
/// - Monthly statement (الكشف الشهري)
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Top up button
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text(
                '💳 شحن الرصيد',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: () {
                // TODO: Navigate to TopupRequestScreen (Phase 2)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('شحن الرصيد - قريباً'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Monthly statement button
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.receipt_long, size: 20, color: AppColors.secondary),
              label: const Text(
                '📄 الكشف الشهري',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(
                  color: AppColors.success,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                // TODO: Navigate to MonthlyStatementScreen (Phase 1B)
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
      ),
    );
  }
}
