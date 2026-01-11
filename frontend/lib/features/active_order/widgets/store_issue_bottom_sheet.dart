import 'package:flutter/material.dart';

/// نافذة الإبلاغ عن مشكلات من المطعم
class StoreIssueBottomSheet extends StatefulWidget {
  final String orderId;
  final Function(String issueType, String? notes) onSubmit;

  const StoreIssueBottomSheet({
    super.key,
    required this.orderId,
    required this.onSubmit,
  });

  @override
  State<StoreIssueBottomSheet> createState() => _StoreIssueBottomSheetState();
}

class _StoreIssueBottomSheetState extends State<StoreIssueBottomSheet> {
  String? _selectedIssue;
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _issueOptions = [
    {
      'value': 'ItemUnavailable',
      'label': 'عنصر غير متوفر',
      'icon': Icons.inventory_2_outlined,
    },
    {
      'value': 'StoreClosed',
      'label': 'المطعم مغلق',
      'icon': Icons.store_outlined,
    },
    {
      'value': 'LongDelay',
      'label': 'تأخير طويل جداً',
      'icon': Icons.access_time,
    },
    {
      'value': 'WrongOrder',
      'label': 'خطأ في الطلب',
      'icon': Icons.error_outline,
    },
    {
      'value': 'Other',
      'label': 'أخرى',
      'icon': Icons.help_outline,
    },
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    if (_selectedIssue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار نوع المشكلة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedIssue == 'Other' && _notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة تفاصيل المشكلة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onSubmit(
        _selectedIssue!,
        _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        
        // رسالة تأكيد
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text('تم الإبلاغ'),
              ],
            ),
            content: const Text(
              'تم إرسال التقرير بنجاح. انتظر توجيهات من فريق الدعم.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'حسناً',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // مقبض السحب
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // العنوان
              Row(
                children: [
                  Icon(
                    Icons.report_problem,
                    color: Colors.orange.shade700,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'ما هي المشكلة؟',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // قائمة الخيارات
              ...List.generate(_issueOptions.length, (index) {
                final option = _issueOptions[index];
                final isSelected = _selectedIssue == option['value'];
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedIssue = option['value'];
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.orange.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.orange.shade300
                              : Colors.grey.shade200,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            option['icon'],
                            color: isSelected
                                ? Colors.orange.shade700
                                : Colors.grey.shade600,
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              option['label'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.orange.shade900
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: Colors.orange.shade700,
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // حقل الملاحظات (يظهر إذا اختار "أخرى")
              if (_selectedIssue == 'Other') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'اكتب تفاصيل المشكلة هنا...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // زر الإرسال
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'إرسال التقرير',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              // زر الإلغاء
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                child: Text(
                  'إلغاء',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
