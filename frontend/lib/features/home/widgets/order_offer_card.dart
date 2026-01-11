import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../../models/wave_offer.dart';
import '../../wallet/providers/wallet_provider.dart';

// ألوان التطبيق
class AppColors {
  static const Color primary = Color(0xFFFDC500); // اللون الأساسي - أصفر ذهبي
  static const Color secondary = Color(0xFF00296B); // اللون الثانوي - أزرق داكن
  static const Color accent = Color(0xFF00c1e8); // لون مساعد - أزرق فاتح
}

/// Custom painter لرسم دائرة تقدم منقطة ورفيعة
class DashedCircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  DashedCircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    
    // رسم الخلفية بالكامل
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // رسم التقدم
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(DashedCircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class OrderOfferCard extends ConsumerStatefulWidget {
  final WaveOffer offer; // تغيير من OrderOffer إلى WaveOffer
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onTimeout; // ✅ جديد: معالج منفصل لانتهاء الوقت
  final VoidCallback onTap;

  const OrderOfferCard({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onReject,
    required this.onTimeout,
    required this.onTap,
  });
  
  @override
  ConsumerState<OrderOfferCard> createState() => _OrderOfferCardState();
}

class _OrderOfferCardState extends ConsumerState<OrderOfferCard>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<double> _animation;
  late Timer _tickTimer;
  int _remainingSeconds = 30;

  void _startOrRestartCountdown() {
    // Cancel any previous tick timer
    try {
      _tickTimer.cancel();
    } catch (_) {
      // ignore - timer may not be initialized yet
    }

    // Calculate remaining seconds from expiresAt
    _remainingSeconds = widget.offer.remainingSeconds;
    if (_remainingSeconds <= 0 || _remainingSeconds > 90) {
      _remainingSeconds = 90; // 90 ثانية = 1:30 دقيقة
    }

    // Reset animation controller to match the new remaining duration
    _controller.duration = Duration(seconds: _remainingSeconds);
    _controller.reset();
    _controller.forward();

    // Timer to update countdown every second based on expiresAt
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final remainingFromExpiry =
          widget.offer.expiresAt.difference(DateTime.now()).inSeconds;

      final nextRemaining = remainingFromExpiry > 0 ? remainingFromExpiry : 0;

      if (_remainingSeconds != nextRemaining) {
        setState(() {
          _remainingSeconds = nextRemaining;
        });
      }

      if (_remainingSeconds <= 0) {
        timer.cancel();
        widget.onTimeout();
      }
    });
  }
  
  @override
  void initState() {
    super.initState();
    
    // تهيئة Animation Controller
    _controller = AnimationController(
      duration: Duration(seconds: _remainingSeconds),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    
    // Start countdown using current offer
    _startOrRestartCountdown();
  }

  @override
  void didUpdateWidget(covariant OrderOfferCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If Flutter reuses this State for a different offer (e.g., list item removed),
    // restart timers so the displayed countdown matches the correct offer.
    if (oldWidget.offer.offerId != widget.offer.offerId ||
        oldWidget.offer.expiresAt != widget.offer.expiresAt) {
      _startOrRestartCountdown();
    }
  }
  
  @override
  void dispose() {
    _tickTimer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        children: [
          // Wave Header with Timer
          _buildWaveHeader(),
          
          // Main Card Content
          InkWell(
            onTap: widget.onTap,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // Header with earnings
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Earnings
                      Text(
                        '${widget.offer.estimatedEarnings.toStringAsFixed(0)} ${widget.offer.currency}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Trip details
                  Text(
                    '${widget.offer.distance.toStringAsFixed(1)} كم • ${widget.offer.estimatedMinutes} دقيقة',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Order total (قيمة الطلب الإجمالي)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'قيمة الطلب: ${widget.offer.orderTotal.toStringAsFixed(0)} ${widget.offer.currency}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Store pickup info
                  Row(
                    children: [
                      _buildStoreIcon(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'استلام • توصيل فقط',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              widget.offer.restaurantName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Customer delivery info
                  Row(
                    children: [
                      _buildCustomerAvatar(widget.offer.customerName),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'توصيل للزبون',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              widget.offer.customerName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showOrderItems(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.secondary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '${widget.offer.itemsCount} عنصر',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Special instructions if available
                  if (widget.offer.specialInstructions != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber[700],
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.offer.specialInstructions!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // ⭐ Wallet balance indicator (SECURE)
                  _buildWalletBalanceIndicator(),
                  
                  const SizedBox(height: 16),
                  
                  // Accept and Reject buttons
                  Row(
                    children: [
                      // Reject button
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: TextButton(
                            onPressed: () {
                              print('🔴🔴🔴 REJECT BUTTON TAPPED IN ORDER_OFFER_CARD! 🔴🔴🔴');
                              widget.onReject();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              backgroundColor: Colors.grey[200],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              'رفض',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Accept button
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isBalanceSufficient() ? widget.onAccept : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isBalanceSufficient() ? AppColors.primary : Colors.grey[400],
                              foregroundColor: _isBalanceSufficient() ? Colors.black87 : Colors.white,
                              disabledBackgroundColor: Colors.grey[400],
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'قبول',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
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
        ],
      ),
    );
  }
  
  /// Wave Header مع المؤقت
  Widget _buildWaveHeader() {
    // حساب التقدم بناءً على الوقت الفعلي المتبقي
    const totalSeconds = 90; // 90 ثانية = 1:30
    final progress = _remainingSeconds / totalSeconds;
    const color = AppColors.secondary;
    
    // حساب الدقائق والثواني
    final minutes = (_remainingSeconds / 60).floor();
    final seconds = _remainingSeconds % 60;
    final timeText = '$minutes:${seconds.toString().padLeft(2, '0')}';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Timer
          Row(
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: CustomPaint(
                        painter: DashedCircularProgressPainter(
                          progress: progress,
                          color: color,
                          backgroundColor: Colors.grey[300]!,
                        ),
                      ),
                    ),
                    Text(
                      timeText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'وقت القبول',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    'متبقي للرد',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Rank badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, color: AppColors.secondary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'ترتيب ${widget.offer.rank}',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// العداد التنازلي - لم يعد مستخدماً (تم نقله للـ Header)
  Widget _buildCountdownTimer() {
    return const SizedBox.shrink();
  }

  Widget _oldBuildCountdownTimer() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = _animation.value;
        final color = progress > 0.33
            ? Colors.green
            : progress > 0.16
                ? Colors.orange
                : Colors.red;
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_remainingSeconds ثانية',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    'متبقية للقبول',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build store icon with restaurant image or fallback icon
  Widget _buildStoreIcon() {
    print('🖼️ OrderOfferCard - Restaurant Image URL: ${widget.offer.restaurantImageUrl}');
    print('🖼️ OrderOfferCard - Restaurant Name: ${widget.offer.restaurantName}');
    if (widget.offer.restaurantImageUrl != null && widget.offer.restaurantImageUrl!.isNotEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
        child: ClipOval(
          child: Image.network(
            widget.offer.restaurantImageUrl!,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // Fallback to icon if image fails to load
              return Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.store,
                  color: Colors.white,
                  size: 20,
                ),
              );
            },
          ),
        ),
      );
    }

    // Fallback to default icon
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.secondary,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.store,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  /// Show order items in a bottom sheet
  void _showOrderItems(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'عناصر الطلب',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // Items list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.offer.items.length,
                itemBuilder: (context, index) {
                  final item = widget.offer.items[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        // Item image
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.restaurant_menu,
                                      color: Colors.grey[600],
                                      size: 30,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.restaurant_menu,
                                color: Colors.grey[600],
                                size: 30,
                              ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Item details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              if (item.notes != null && item.notes!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    item.notes!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        // Quantity circle
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a circular avatar with the first letter of the customer name
  Widget _buildCustomerAvatar(String customerName) {
    // Get first letter of customer name, fallback to 'ز' if empty
    String firstLetter = customerName.isNotEmpty ? customerName[0].toUpperCase() : 'ز';
    
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.primary, // اللون الأساسي - أصفر ذهبي
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: const TextStyle(
            color: AppColors.secondary, // اللون الثانوي - أزرق داكن
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// ⭐ SECURE: Build wallet balance indicator
  /// Shows ONLY if driver does NOT have enough balance
  Widget _buildWalletBalanceIndicator() {
    final walletState = ref.watch(walletBalanceProvider);
    
    return walletState.when(
      data: (wallet) {
        // SECURITY: Validate order total is positive
        if (widget.offer.orderTotal <= 0) {
          return const SizedBox.shrink();
        }
        
        // SECURITY: Check if driver has enough balance
        final hasEnoughBalance = wallet.availableBalance >= widget.offer.orderTotal;
        
        // ✅ إخفاء المؤشر إذا الرصيد كافٍ
        if (hasEnoughBalance) {
          return const SizedBox.shrink();
        }
        
        // ⚠️ عرض المؤشر الأحمر فقط عند عدم كفاية الرصيد
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.red.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'رصيدك غير كافٍ لهذا الطلب (يحتاج ${widget.offer.orderTotal.toStringAsFixed(0)} ${widget.offer.currency})',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(), // لا نعرض شيء أثناء التحميل
      error: (error, stack) {
        // SECURITY: Log error but don't expose details
        debugPrint('❌ Wallet balance check error: $error');
        return const SizedBox.shrink(); // لا نعرض خطأ للمستخدم
      },
    );
  }
  
  /// 🔒 SECURE: Check if driver has sufficient wallet balance
  bool _isBalanceSufficient() {
    final walletState = ref.watch(walletBalanceProvider);
    
    return walletState.maybeWhen(
      data: (wallet) {
        if (widget.offer.orderTotal <= 0) return true;
        return wallet.availableBalance >= widget.offer.orderTotal;
      },
      orElse: () => true, // Allow accept during loading/error (will fail on backend)
    );
  }
}