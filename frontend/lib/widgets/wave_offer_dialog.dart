import 'package:flutter/material.dart';
import 'dart:async';
import '../models/wave_offer.dart';
import '../widgets/items_list_bottom_sheet.dart';

/// 🌊 Wave Offer Dialog
/// 
/// Dialog لعرض العرض الموجي مع:
/// - معلومات الموجة (wave number, rank)
/// - عد تنازلي دائري (30 ثانية)
/// - تفاصيل الطلب
/// - زر العناصر (يفتح Bottom Sheet)
/// - أزرار القبول والرفض

class WaveOfferDialog extends StatefulWidget {
  final WaveOffer offer;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const WaveOfferDialog({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<WaveOfferDialog> createState() => _WaveOfferDialogState();
}

class _WaveOfferDialogState extends State<WaveOfferDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Timer _tickTimer;
  int _remainingSeconds = 30;

  @override
  void initState() {
    super.initState();

    // حساب الوقت المتبقي الفعلي
    _remainingSeconds = widget.offer.remainingSeconds;
    if (_remainingSeconds <= 0) {
      _remainingSeconds = 30;
    }

    // تهيئة Animation Controller
    _controller = AnimationController(
      duration: Duration(seconds: _remainingSeconds),
      vsync: this,
    );

    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    // بدء العد التنازلي
    _controller.forward();

    // Timer لتحديث العداد كل ثانية
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds = (_animation.value * widget.offer.remainingSeconds).ceil();
          if (_remainingSeconds <= 0) {
            timer.cancel();
          }
        });
      }
    });

    // إغلاق تلقائي عند انتهاء الوقت
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          Navigator.of(context).pop();
          widget.onReject();
        }
      }
    });
  }

  @override
  void dispose() {
    _tickTimer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 16,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              const Color(0xFFFDC500).withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildCountdownTimer(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildItemsButton(),
                    const SizedBox(height: 16),
                    _buildOrderDetails(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildActionButtons(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF00296B),
            Color(0xFF003d8f),
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.waves,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'عرض جديد',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'موجة ${widget.offer.waveNumber}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFDC500),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFDC500).withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: Color(0xFF00296B),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'ترتيبك: ${widget.offer.rank}/5',
                  style: const TextStyle(
                    color: Color(0xFF00296B),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final progress = _animation.value;
          final color = progress > 0.33
              ? Colors.green
              : progress > 0.16
                  ? Colors.orange
                  : Colors.red;

          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_remainingSeconds',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    'ثانية',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemsButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => ItemsListBottomSheet(
              items: widget.offer.items,
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFDC500).withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFDC500),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDC500),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'عناصر الطلب',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00296B),
                      ),
                    ),
                    Text(
                      '${widget.offer.itemsCount} عنصر • اضغط للعرض',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left,
                color: Color(0xFF00296B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderDetails() {
    return Column(
      children: [
        _buildDetailRow(
          Icons.store,
          'المطعم',
          widget.offer.restaurantName,
          valueColor: const Color(0xFF00296B),
        ),
        const Divider(height: 24),
        _buildDetailRow(
          Icons.location_on,
          'العنوان',
          widget.offer.customerAddress,
        ),
        const Divider(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildDetailRow(
                Icons.route,
                'المسافة',
                '${widget.offer.distance.toStringAsFixed(1)} كم',
                compact: true,
              ),
            ),
            Expanded(
              child: _buildDetailRow(
                Icons.access_time,
                'الوقت',
                '${widget.offer.estimatedMinutes} دقيقة',
                compact: true,
              ),
            ),
          ],
        ),
        const Divider(height: 24),
        _buildDetailRow(
          Icons.attach_money,
          'الأرباح',
          '${widget.offer.estimatedEarnings.toStringAsFixed(0)} د.ع',
          valueColor: Colors.green,
          valueBold: true,
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    bool valueBold = false,
    bool compact = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: const Color(0xFF00296B).withOpacity(0.6),
          size: compact ? 18 : 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 12 : 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: compact ? 14 : 16,
                  fontWeight: valueBold ? FontWeight.bold : FontWeight.w500,
                  color: valueColor ?? const Color(0xFF00296B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // إغلاق Dialog أولاً ثم استدعاء reject
                Navigator.of(context).pop();
                widget.onReject();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'رفض',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                // إغلاق Dialog أولاً ثم استدعاء accept
                Navigator.of(context).pop();
                widget.onAccept();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDC500),
                foregroundColor: const Color(0xFF00296B),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: const Color(0xFFFDC500).withOpacity(0.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'قبول الطلب',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
