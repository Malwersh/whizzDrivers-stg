import 'package:flutter/material.dart';

/// Widget لعرض Timeline مراحل الطلب
class OrderStatusTimeline extends StatelessWidget {
  final String currentStatus;

  const OrderStatusTimeline({
    super.key,
    required this.currentStatus,
  });

  @override
  Widget build(BuildContext context) {
    final steps = _getSteps();
    final currentIndex = steps.indexWhere((step) => step.id == currentStatus);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مراحل الطلب',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              // المرحلة الأولى (القبول) دائماً مكتملة
              final isCompleted = index < currentIndex || (index == 0 && currentIndex >= 0);
              final isCurrent = index == currentIndex;
              final isLast = index == steps.length - 1;

              return _TimelineStep(
                label: step.label,
                icon: step.icon,
                isCompleted: isCompleted,
                isCurrent: isCurrent,
                isLast: isLast,
              );
            }),
          ],
        ),
      ),
    );
  }

  List<_Step> _getSteps() {
    return [
      _Step(
        id: 'accepted',
        label: 'تم القبول',
        icon: Icons.check_circle,
      ),
      _Step(
        id: 'heading_to_store',
        label: 'التوجه للمطعم',
        icon: Icons.delivery_dining,
      ),
      _Step(
        id: 'arrived_at_store',
        label: 'وصول للمطعم',
        icon: Icons.store,
      ),
      _Step(
        id: 'picked_up',
        label: 'استلام الطلب',
        icon: Icons.shopping_bag,
      ),
      _Step(
        id: 'heading_to_customer',
        label: 'التوجه للعميل',
        icon: Icons.motorcycle,
      ),
      _Step(
        id: 'arrived_at_customer',
        label: 'وصول للعميل',
        icon: Icons.location_on,
      ),
      _Step(
        id: 'delivered',
        label: 'تم التسليم',
        icon: Icons.done_all,
      ),
    ];
  }
}

class _Step {
  final String id;
  final String label;
  final IconData icon;

  _Step({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class _TimelineStep extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  const _TimelineStep({
    required this.label,
    required this.icon,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    Color labelColor;
    Color lineColor;

    if (isCompleted) {
      iconColor = Colors.green;
      labelColor = Colors.grey[700]!;
      lineColor = Colors.green;
    } else if (isCurrent) {
      iconColor = Colors.blue;
      labelColor = Colors.black;
      lineColor = Colors.grey[300]!;
    } else {
      iconColor = Colors.grey[400]!;
      labelColor = Colors.grey[500]!;
      lineColor = Colors.grey[300]!;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column with icon and line
          Column(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent ? iconColor.withOpacity(0.1) : Colors.transparent,
                  border: Border.all(
                    color: iconColor,
                    width: isCurrent ? 2 : 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: isCurrent ? 24 : 20,
                ),
              ),
              
              // Vertical line
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: lineColor,
                  ),
                ),
            ],
          ),

          const SizedBox(width: 12),

          // Label
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isCurrent ? 16 : 15,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: labelColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
