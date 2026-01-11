import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// نافذة معالجة حالة عدم توفر العميل
class CustomerUnavailableDialog extends StatefulWidget {
  final String orderId;
  final String customerPhone;
  final Function() onConfirmUnavailable;

  const CustomerUnavailableDialog({
    super.key,
    required this.orderId,
    required this.customerPhone,
    required this.onConfirmUnavailable,
  });

  @override
  State<CustomerUnavailableDialog> createState() =>
      _CustomerUnavailableDialogState();
}

class _CustomerUnavailableDialogState extends State<CustomerUnavailableDialog> {
  bool _hasAttemptedCall = false;
  bool _isSubmitting = false;

  Future<void> _callCustomer() async {
    final uri = Uri.parse('tel:${widget.customerPhone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      setState(() {
        _hasAttemptedCall = true;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن فتح تطبيق الهاتف'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmUnavailable() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onConfirmUnavailable();
      
      if (mounted) {
        Navigator.pop(context);
        
        // رسالة تأكيد
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 32),
                SizedBox(width: 12),
                Text('تم الإبلاغ'),
              ],
            ),
            content: const Text(
              'تم تسجيل عدم توفر العميل. سيتواصل معك فريق الدعم قريباً لتحديد الإجراء المناسب.',
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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // الأيقونة
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _hasAttemptedCall ? Icons.phone_disabled : Icons.phone_in_talk,
                size: 40,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 20),

            // العنوان والرسالة
            if (!_hasAttemptedCall) ...[
              const Text(
                'العميل لا يرد؟',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'يرجى محاولة الاتصال بالعميل أولاً قبل تأكيد عدم التوفر',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // زر الاتصال
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _callCustomer,
                  icon: const Icon(Icons.phone, color: Colors.white),
                  label: const Text(
                    'الاتصال بالعميل',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else ...[
              const Text(
                'ما زال العميل لا يرد؟',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'إذا لم يرد العميل بعد المحاولة، يمكنك تأكيد عدم التوفر وسيتواصل معك فريق الدعم.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // زر تأكيد عدم التوفر
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _confirmUnavailable,
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
                          'تأكيد عدم التوفر',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // زر إعادة المحاولة
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _callCustomer,
                  icon: Icon(Icons.phone, color: Colors.green.shade700),
                  label: Text(
                    'إعادة الاتصال',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.green.shade700, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // زر الإلغاء
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
    );
  }
}
