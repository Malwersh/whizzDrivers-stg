import 'package:flutter/material.dart';

/// نافذة فك الارتباط من الطلب - يستخدم فقط قبل استلام الطلب
/// بعد الاستلام: يجب استخدام الإلغاء بدلاً من فك الارتباط
class UnassignOrderBottomSheet extends StatefulWidget {
  final String orderId;
  final Function(String reason) onUnassign;

  const UnassignOrderBottomSheet({
    super.key,
    required this.orderId,
    required this.onUnassign,
  });

  @override
  State<UnassignOrderBottomSheet> createState() => _UnassignOrderBottomSheetState();
}

class _UnassignOrderBottomSheetState extends State<UnassignOrderBottomSheet> {
  String? _selectedReason;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _unassignReasons = [
    {
      'value': 'VehicleIssue',
      'label': 'مشكلة في السيارة',
      'icon': Icons.car_crash,
      'color': Colors.orange,
    },
    {
      'value': 'Emergency',
      'label': 'حالة طارئة',
      'icon': Icons.emergency,
      'color': Colors.red,
    },
    {
      'value': 'TooFar',
      'label': 'المسافة بعيدة جداً',
      'icon': Icons.social_distance,
      'color': Colors.blue,
    },
    {
      'value': 'TrafficJam',
      'label': 'ازدحام مروري شديد',
      'icon': Icons.traffic,
      'color': Colors.deepOrange,
    },
    {
      'value': 'Other',
      'label': 'سبب آخر',
      'icon': Icons.help_outline,
      'color': Colors.grey,
    },
  ];

  Future<void> _handleUnassign() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار سبب فك الارتباط'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onUnassign(_selectedReason!);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // أيقونة تحذير
              Center(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.link_off_rounded,
                    color: Colors.orange,
                    size: 35,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // العنوان
              const Text(
                'فك الارتباط من الطلب',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00509D),
                ),
              ),
              const SizedBox(height: 8),

              // الوصف
              Text(
                'سيتم إعادة تعيين الطلب لسائق آخر',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // أسباب فك الارتباط
              const Text(
                'اختر السبب:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // قائمة الأسباب
              ...List.generate(
                _unassignReasons.length,
                (index) {
                  final reason = _unassignReasons[index];
                  final isSelected = _selectedReason == reason['value'];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _selectedReason = reason['value'];
                              });
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00509D).withOpacity(0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF00509D)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: (reason['color'] as Color).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                reason['icon'],
                                color: reason['color'],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                reason['label'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF00509D)
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF00509D),
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // أزرار الإجراء
              Row(
                children: [
                  // زر الإلغاء
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              Navigator.pop(context, false);
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[400]!),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'رجوع',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // زر التأكيد
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isSubmitting || _selectedReason == null)
                          ? null
                          : _handleUnassign,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'تأكيد فك الارتباط',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
