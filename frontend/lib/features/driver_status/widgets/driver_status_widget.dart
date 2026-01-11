import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/app_colors.dart';
import '../../../models/driver_status.dart';
import '../../../providers/riverpod/driver_connection_provider.dart';

/// Widget for controlling driver online/offline status
class DriverStatusWidget extends ConsumerWidget {
  const DriverStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(driverConnectionStatusProvider);
    final driverStatus = ref.watch(driverStatusProvider);
    final actions = ref.watch(driverConnectionActionsProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wifi,
                  color: connectionStatus.when(
                    data: (connected) => connected ? AppColors.success : AppColors.error,
                    loading: () => AppColors.warning,
                    error: (_, __) => AppColors.error,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'حالة الاتصال',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                connectionStatus.when(
                  data: (connected) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: connected ? AppColors.success : AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      connected ? 'متصل' : 'غير متصل',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  loading: () => const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => const Icon(Icons.error, color: AppColors.error),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Driver Status
            driverStatus.when(
              data: (status) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'حالة السائق: ${status.displayText}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Status Controls
                  connectionStatus.when(
                    data: (connected) => connected ? _buildStatusControls(context, status, actions) : _buildConnectButton(actions),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => _buildConnectButton(actions),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text(
                'خطأ في تحميل حالة السائق',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusControls(BuildContext context, DriverStatus currentStatus, DriverConnectionActions actions) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: currentStatus == DriverStatus.online ? null : () => actions.goOnline(),
            icon: const Icon(Icons.radio_button_checked),
            label: const Text('متاح للطلبات'),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus == DriverStatus.online ? AppColors.success : null,
              foregroundColor: currentStatus == DriverStatus.online ? AppColors.white : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: currentStatus == DriverStatus.offline ? null : () => actions.goOffline(),
            icon: const Icon(Icons.radio_button_unchecked),
            label: const Text('غير متاح'),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus == DriverStatus.offline ? AppColors.error : null,
              foregroundColor: currentStatus == DriverStatus.offline ? AppColors.white : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectButton(DriverConnectionActions actions) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => actions.connect('some_driver_id'), // TODO: Replace with actual driver ID
        icon: const Icon(Icons.wifi),
        label: const Text('الاتصال بنظام التوصيل'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
        ),
      ),
    );
  }

  Color _getStatusColor(DriverStatus status) {
    switch (status) {
      case DriverStatus.online:
        return AppColors.success;
      case DriverStatus.busy:
        return AppColors.warning;
      case DriverStatus.offline:
        return AppColors.grey;
      case DriverStatus.onDuty:
        return AppColors.primary;
    }
  }
}
