import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/app_colors.dart';
// Navigation page removed - placeholder for navigation
import '../models/batched_order_model.dart';
import '../models/order_model.dart';

class InnovativeOrderNotificationDialog extends StatefulWidget {
  final BatchedOrderNotification batchedOrder;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final Duration timeoutDuration;

  const InnovativeOrderNotificationDialog({
    super.key,
    required this.batchedOrder,
    required this.onAccept,
    required this.onReject,
    this.timeoutDuration = const Duration(seconds: 30),
  });

  @override
  State<InnovativeOrderNotificationDialog> createState() =>
      _InnovativeOrderNotificationDialogState();
}

class _InnovativeOrderNotificationDialogState
    extends State<InnovativeOrderNotificationDialog>
    with TickerProviderStateMixin {
  late Timer _timer;
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _bounceController;
  late AnimationController _glowController;
  late AnimationController _particleController;

  int _remainingSeconds = 30;
  List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();

    // Haptic feedback
    HapticFeedback.heavyImpact();

    _remainingSeconds = widget.timeoutDuration.inSeconds;

    // Initialize multiple animation controllers for different effects
    _progressController = AnimationController(
      duration: widget.timeoutDuration,
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Initialize particles for floating effect
    _initializeParticles();

    // Start animations
    _progressController.forward();
    _pulseController.repeat(reverse: true);
    _slideController.forward();
    _bounceController.forward();
    _glowController.repeat(reverse: true);
    _particleController.repeat();

    // Start countdown timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
        });

        if (_remainingSeconds <= 0) {
          _timer.cancel();
          if (mounted) {
            Navigator.of(context).pop();
          }
          widget.onReject();
        }
      }
    });
  }

  void _initializeParticles() {
    _particles = List.generate(20, (index) {
      return Particle(
        x: Random().nextDouble(),
        y: Random().nextDouble(),
        size: Random().nextDouble() * 4 + 2,
        speed: Random().nextDouble() * 0.02 + 0.01,
        opacity: Random().nextDouble() * 0.6 + 0.2,
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _progressController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _bounceController.dispose();
    _glowController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _acceptOrder() {
    _timer.cancel();
    _progressController.stop();
    _pulseController.stop();
    Navigator.of(context).pop();
    widget.onAccept();
    HapticFeedback.lightImpact();
    
    // Placeholder: Navigation to be implemented
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم قبول الطلب - سيتم إضافة التنقل لاحقاً'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _rejectOrder() {
    _timer.cancel();
    _progressController.stop();
    _pulseController.stop();
    Navigator.of(context).pop();
    widget.onReject();
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final batch = widget.batchedOrder;
    final isSingleOrder = batch.orders.length == 1;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          _buildAnimatedBackground(),
          Center(
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _slideController,
                      curve: Curves.elasticOut,
                    ),
                  ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _bounceController,
                    curve: Curves.bounceOut,
                  ),
                ),
                child: _buildGlassmorphismDialog(batch, isSingleOrder),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return RepaintBoundary(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [
                  Colors.black.withAlpha(51),
                  Colors.black.withAlpha(179),
                  Colors.black.withAlpha(230),
                ],
              ),
            ),
            child: CustomPaint(
              painter: ParticlePainter(_particles, _particleController.value),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassmorphismDialog(
    BatchedOrderNotification batch,
    bool isSingleOrder,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      constraints: const BoxConstraints(maxHeight: 700, maxWidth: 420),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withAlpha(64),
                  Colors.white.withAlpha(26),
                  Colors.white.withAlpha(13),
                ],
              ),
              border: Border.all(
                color: Colors.white.withAlpha(51),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInnovativeHeader(batch, isSingleOrder),
                _buildMainContent(batch, isSingleOrder),
                _buildInnovativeActionButtons(isSingleOrder),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInnovativeHeader(
    BatchedOrderNotification batch,
    bool isSingleOrder,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withAlpha(230),
            AppColors.secondary.withAlpha(204),
            AppColors.primary.withAlpha(179),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Animated icon with glow effect
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withAlpha(
                            (0.3 + _glowController.value * 0.4 * 255).round(),
                          ),
                          blurRadius: 15 + _glowController.value * 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSingleOrder
                            ? Icons.delivery_dining
                            : Icons.featured_play_list,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSingleOrder ? '🎯 طلب جديد' : '⚡ طلبات محسنة',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 2),
                            blurRadius: 4,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                    if (!isSingleOrder)
                      Text(
                        '${batch.orders.length} طلبات في مسار واحد',
                        style: TextStyle(
                          color: Colors.white.withAlpha(230),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              // Animated timer with circular progress
              _buildAnimatedTimer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedTimer() {
    return Semantics(
      label: 'Remaining time',
      value: '$_remainingSeconds seconds',
      liveRegion: true,
      child: AnimatedBuilder(
        animation: _progressController,
        builder: (context, child) {
          return Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(51),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Circular progress indicator
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    value: 1.0 - _progressController.value,
                    backgroundColor: Colors.white.withAlpha(77),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
                // Timer text
                Text(
                  '$_remainingSeconds',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(BatchedOrderNotification batch, bool isSingleOrder) {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Earnings highlight with animation
            _buildEarningsHighlight(batch),
            const SizedBox(height: 20),

            // Orders carousel
            _buildOrdersCarousel(batch, isSingleOrder),

            if (!isSingleOrder) ...[
              const SizedBox(height: 20),
              _buildOptimizationBadge(batch),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsHighlight(BatchedOrderNotification batch) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + _pulseController.value * 0.05,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.success.withAlpha(51),
                  AppColors.success.withAlpha(26),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.success.withAlpha(77),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withAlpha(26),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withAlpha(102),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.monetization_on,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\$${batch.totalEarnings.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                              color: Colors.black.withAlpha(51),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'أجور التوصيل',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.success.withAlpha(230),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${batch.totalDistance.toStringAsFixed(1)} كم',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${batch.estimatedTimeMinutes} دقيقة',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrdersCarousel(
    BatchedOrderNotification batch,
    bool isSingleOrder,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final scale = mediaQuery.textScaler.scale(1.0);
    final height = (160 * scale).clamp(160, 210).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TODO(localization): Extract hard coded strings & emojis to ARB.
        Text(
          isSingleOrder ? '📦 تفاصيل الطلب' : '🎯 ${batch.orders.length} طلبات',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(0, 2),
                blurRadius: 4,
                color: Colors.black26,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: height,
          child: PageView.builder(
            itemCount: batch.orders.length,
            itemBuilder: (context, index) {
              final order = batch.orders[index];
              return _buildModernOrderCard(order, index + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModernOrderCard(OrderModel order, int sequenceNumber) {
    return Semantics(
      label: 'Order card $sequenceNumber',
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withAlpha(64),
              Colors.white.withAlpha(26),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(77), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withAlpha(179),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(102),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$sequenceNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.restaurantName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        order.customerName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withAlpha(230),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.success,
                        AppColors.success.withAlpha(204),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order.formattedTotalAmount,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.white.withAlpha(230),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.customerAddress,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withAlpha(230),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.payment,
                          size: 16,
                          color: Colors.white.withAlpha(230),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          order.paymentMethod,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withAlpha(230),
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
      ),
    );
  }

  Widget _buildOptimizationBadge(BatchedOrderNotification batch) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withAlpha(230),
            AppColors.primary.withAlpha(204),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          width: 2,
          color: Colors.white.withAlpha(77),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withAlpha(77),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'توفير ${batch.distanceSavedInKm.toStringAsFixed(1)} كم و ${batch.timeSavedInMinutes.toStringAsFixed(0)} دقيقة',
              style: TextStyle(
                color: Colors.white.withAlpha(230),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInnovativeActionButtons(bool isSingleOrder) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Reject order',
              child: ElevatedButton(
                onPressed: _rejectOrder,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: Colors.white.withAlpha(51),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: const BorderSide(color: Colors.white, width: 1.5),
                  ),
                  elevation: 5,
                  shadowColor: Colors.black.withAlpha(128),
                ),
                child: const Text(
                  'رفض',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + _pulseController.value * 0.1,
                  child: Semantics(
                    button: true,
                    label: isSingleOrder ? 'Accept order' : 'Accept batch',
                    child: ElevatedButton(
                      onPressed: _acceptOrder,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 15,
                        shadowColor: AppColors.success.withAlpha(128),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                            child: const Icon(Icons.check_circle, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isSingleOrder ? '✅ قبول الطلب' : '🚀 قبول المجموعة',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
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

// Particle system for background animation
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;

  ParticlePainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var particle in particles) {
      // Update particle position
      particle.y -= particle.speed;
      if (particle.y < 0) {
        particle.y = 1.0;
        particle.x = Random().nextDouble();
      }

      paint.color = Colors.white.withAlpha((particle.opacity * 255).round());

      // Simple parallax effect
      final parallaxOffset = (particle.size / 4) * animationValue;

      canvas.drawCircle(
        Offset(
          particle.x * size.width + parallaxOffset,
          particle.y * size.height,
        ),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Particle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}
