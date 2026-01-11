import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import '../models/active_order_model.dart';
import '../../../providers/riverpod/active_order_provider.dart';
import '../widgets/customer_unavailable_dialog.dart';
import '../services/order_persistence_service.dart';

/// شاشة عند العميل - المرحلة 4 (التسليم النهائي)
class AtCustomerScreen extends ConsumerStatefulWidget {
  final ActiveOrder order;

  const AtCustomerScreen({
    super.key,
    required this.order,
  });

  @override
  ConsumerState<AtCustomerScreen> createState() => _AtCustomerScreenState();
}

class _AtCustomerScreenState extends ConsumerState<AtCustomerScreen> {
  bool _isLoading = false;
  File? _deliveryPhoto;
  final ImagePicker _picker = ImagePicker();
  bool _cashCollected = false;

  // Calculate total cash amount using new pricing model
  double get cashAmount => widget.order.pricing?.total ?? widget.order.totalAmount;

  @override
  void initState() {
    super.initState();
    // Debug: طباعة قيم المبلغ
    debugPrint('💰 DEBUG cashAmount:');
    debugPrint('   pricing?.total: ${widget.order.pricing?.total}');
    debugPrint('   totalAmount: ${widget.order.totalAmount}');
    debugPrint('   total: ${widget.order.total}');
    debugPrint('   FINAL cashAmount: $cashAmount');
    
    // تحديث الـ Provider بالطلب الحالي (مهم بعد hot restart)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeOrderProvider.notifier).updateOrder(widget.order);
    });
  }

  void _showUnavailableDialog() {
    showDialog(
      context: context,
      builder: (context) => CustomerUnavailableDialog(
        orderId: widget.order.orderId,
        customerPhone: widget.order.customerPhone,
        onConfirmUnavailable: () async {
          // TODO: Call API to report customer unreachable
          await Future.delayed(const Duration(seconds: 1));
          print('Customer unavailable reported');
        },
      ),
    );
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _deliveryPhoto = File(photo.path);
        });
      }
    } catch (e) {
      print('❌ Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل التقاط الصورة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeDelivery() async {
    // تحقق من checkbox إذا كان الدفع نقدي
    if (widget.order.isCashPayment && !_cashCollected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تأكيد استلام المبلغ النقدي'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // TODO: Upload photo if available
    // if (_deliveryPhoto != null) {
    //   await _uploadPhoto(_deliveryPhoto!);
    // }

    // إرسال بيانات استلام النقدية للـ API
    // نستخدم pricing.total (goodsSubtotal + deliveryFee + tip) وهو المبلغ الذي يستلمه السائق نقداً
    // يشمل: deliveryFee + tip (يستلمهما السائق نقداً) + goodsSubtotal (يحجز من محفظة السائق)
    final result = await ref.read(activeOrderProvider.notifier).deliverOrder(
      cashCollected: _cashCollected ? cashAmount : null,
      deliveryNotes: null,
    );

    setState(() => _isLoading = false);

    if (result != null && result['success'] == true && mounted) {
      // ✅ مسح الطلب النشط من التخزين المحلي بعد التسليم الناجح
      try {
        await OrderPersistenceService.clearActiveOrder();
        debugPrint('🗑️ Active order cleared from local storage after successful delivery');
      } catch (e) {
        debugPrint('⚠️ Failed to clear active order from local storage: $e');
        // لا نفشل العملية بسبب مشكلة المسح
      }
      
      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green[600],
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'تم التسليم بنجاح!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result['message'] ?? 'تم إتمام الطلب بنجاح',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'رقم الطلب: #${widget.order.orderNumber ?? widget.order.shortOrderId}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Close dialog first
                Navigator.of(context).pop();
                
                // Navigate to home using GoRouter (page-based routing)
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (context.mounted) {
                    context.go('/');
                  }
                });
              },
              child: const Text(
                'العودة للرئيسية',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00509D),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result?['message'] ?? 'فشل تأكيد التسليم. حاول مرة أخرى.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('تسليم الطلب'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Customer info card
            _buildCustomerCard(),

            const SizedBox(height: 16),

            // Order summary
            _buildOrderSummary(),

            const SizedBox(height: 16),

            // Photo section
            _buildPhotoSection(),

            const SizedBox(height: 24),

            // Cash collection warning (if cash payment)
            if (widget.order.isCashPayment) _buildCashWarning(),

            const SizedBox(height: 16),

            // Complete delivery button
            ElevatedButton(
              onPressed: _isLoading ? null : _completeDelivery,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'تأكيد التسليم ✓',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),

            const SizedBox(height: 12),

            // Customer unavailable button
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _showUnavailableDialog,
              icon: Icon(Icons.person_off, color: Colors.orange[700]),
              label: Text(
                'العميل غير متاح',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                side: BorderSide(color: Colors.orange[700]!, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.purple[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.person,
                color: Colors.purple[800],
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.order.customerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.order.customerAddress,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                // TODO: Call customer
              },
              icon: Icon(Icons.phone, color: Colors.green[700]),
              iconSize: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملخص الطلب',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'رقم الطلب',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
                Text(
                  '#${widget.order.orderNumber ?? widget.order.shortOrderId}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'عدد الأصناف',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
                Text(
                  '${widget.order.items.length} صنف',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المبلغ الإجمالي',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
                Text(
                  '${cashAmount.toStringAsFixed(0)} دينار',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'طريقة الدفع',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
                Text(
                  widget.order.isCashPayment ? '💵 نقدي' : '💳 بطاقة',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: widget.order.isCashPayment
                        ? Colors.green[700]
                        : Colors.blue[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'صورة التسليم',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  '(اختياري)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_deliveryPhoto == null)
              InkWell(
                onTap: _takePhoto,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'التقط صورة',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _deliveryPhoto!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: () => setState(() => _deliveryPhoto = null),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber[800],
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تحصيل المبلغ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تأكد من تحصيل ${cashAmount.toStringAsFixed(0)} دينار نقداً من العميل',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber[900],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Checkbox
          InkWell(
            onTap: () => setState(() => _cashCollected = !_cashCollected),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cashCollected ? Colors.green[50] : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _cashCollected ? Colors.green[300]! : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _cashCollected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: _cashCollected ? Colors.green[700] : Colors.grey[400],
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'استلمت المبلغ بالكامل',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _cashCollected ? Colors.green[900] : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
