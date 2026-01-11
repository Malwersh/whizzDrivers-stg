import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import 'dart:async';
import '../models/active_order_model.dart';
import '../../../providers/riverpod/active_order_provider.dart';

/// شاشة التوجه للعميل - المرحلة 3 (Modern UI)
class HeadingToCustomerScreen extends ConsumerStatefulWidget {
  final ActiveOrder order;

  const HeadingToCustomerScreen({
    super.key,
    required this.order,
  });

  @override
  ConsumerState<HeadingToCustomerScreen> createState() =>
      _HeadingToCustomerScreenState();
}

class _HeadingToCustomerScreenState
    extends ConsumerState<HeadingToCustomerScreen> {
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  double _slidePosition = 0.0;
  double? _distanceToCustomer;
  double? _estimatedTime;
  bool _markersReady = false;
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializeMapData();
    _startLocationUpdates();
    
    // تحديث الـ Provider بالطلب الحالي (مهم بعد hot restart)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeOrderProvider.notifier).updateOrder(widget.order);
    });
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }


  Future<void> _initializeMapData() async {
    try {
      // Create custom markers
      await _createCustomMarkers();
      
      // Calculate initial distance and time
      _calculateDistanceAndTime();
      
      setState(() {
        _markersReady = true;
      });
    } catch (e) {
      print('❌ Error initializing map: $e');
    }
  }

  Future<void> _createCustomMarkers() async {
    try {
      // Create driver marker (blue circle)
      final driverIcon = await _createCircleMarkerWithIcon(
        Icons.delivery_dining,
        const Color(0xFF00509D), // Blue
        Colors.white,
        80,
      );

      // Create customer marker (yellow circle with home icon)
      final customerIcon = await _createCircleMarkerWithIcon(
        Icons.home,
        const Color(0xFFFDC500), // Yellow
        Colors.white,
        80,
      );

      // Fixed driver location (for demonstration - in production use real GPS)
      const driverLat = 31.913292;
      const driverLng = 44.476014;

      _markers = {
        Marker(
          markerId: const MarkerId('driver'),
          position: const LatLng(driverLat, driverLng),
          icon: driverIcon,
        ),
        Marker(
          markerId: const MarkerId('customer'),
          position: LatLng(
            widget.order.customerLat,
            widget.order.customerLng,
          ),
          icon: customerIcon,
        ),
      };

      // Create polyline between driver and customer
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [
            const LatLng(driverLat, driverLng),
            LatLng(widget.order.customerLat, widget.order.customerLng),
          ],
          color: const Color(0xFF00509D),
          width: 4,
        ),
      };
    } catch (e) {
      print('❌ Error creating markers: $e');
    }
  }

  Future<BitmapDescriptor> _createCircleMarkerWithIcon(
    IconData icon,
    Color bgColor,
    Color iconColor,
    double size,
  ) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    // Draw circle background
    final paint = Paint()..color = bgColor;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2, borderPaint);

    // Draw icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * 0.5,
        fontFamily: icon.fontFamily,
        color: iconColor,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  void _calculateDistanceAndTime() {
    // Fixed driver location (for demonstration)
    const driverLat = 31.913292;
    const driverLng = 44.476014;

    _distanceToCustomer = Geolocator.distanceBetween(
      driverLat,
      driverLng,
      widget.order.customerLat,
      widget.order.customerLng,
    );

    // Estimate time (assuming 40 km/h average speed)
    if (_distanceToCustomer != null) {
      final hours = (_distanceToCustomer! / 1000) / 40;
      _estimatedTime = hours * 60; // Convert to minutes
    }
  }

  void _startLocationUpdates() {
    // Update location every 10 seconds (in production use Geolocator stream)
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _calculateDistanceAndTime();
        setState(() {});
      }
    });
  }

  String _formatDistance(double? distance) {
    if (distance == null) return '...';
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} م';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} كم';
    }
  }

  String _formatTime(double? minutes) {
    if (minutes == null) return '...';
    if (minutes < 60) {
      return '${minutes.toStringAsFixed(0)} دقيقة';
    } else {
      final hours = (minutes / 60).floor();
      final mins = (minutes % 60).toStringAsFixed(0);
      return '$hours س $mins د';
    }
  }

  Future<void> _openGoogleMaps() async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${widget.order.customerLat},${widget.order.customerLng}&travelmode=driving';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _arriveAtCustomer() async {
    final success =
        await ref.read(activeOrderProvider.notifier).arriveAtCustomer();
    if (success && mounted) {
      final updatedOrder = ref.read(activeOrderProvider).order;
      if (updatedOrder != null) {
        context.go('/at-customer', extra: updatedOrder);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل في تسجيل الوصول. حاول مرة أخرى'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _callCustomer() async {
    final phone = widget.order.customerPhone;
    if (phone.isNotEmpty) {
      final url = 'tel:$phone';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    }
  }

  void _showOrderItems() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'العناصر المطلوبة (${widget.order.items.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.order.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.order.items[index];
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${item.quantity}x',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      title: Text(item.name),
                      subtitle: item.notes != null && item.notes!.isNotEmpty
                          ? Text('ملاحظات: ${item.notes}')
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('هل تحتاج مساعدة؟'),
        content: const Text(
          'يمكنك الاتصال بالدعم الفني أو إلغاء الطلب إذا واجهت مشكلة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Call support
            },
            child: const Text('اتصال بالدعم'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('التوجه إلى العميل'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _showCancelDialog,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text(
              'مساعدة',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00509D),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Static Map Header
            _buildMapHeader(),
            
            const SizedBox(height: 16),
            
            // Distance and Time
            _buildDistanceTimeRow(),
            
            const SizedBox(height: 16),
            
            // Customer Info
            _buildCustomerInfo(),
            
            const SizedBox(height: 12),
            
            // Order Items List
            _buildOrderItemsList(),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            _buildActionButtons(),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMapHeader() {
    if (!_markersReady) {
      return Container(
        height: 200,
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFDC500),
          ),
        ),
      );
    }

    const driverLat = 31.913292;
    const driverLng = 44.476014;
    final centerLat = (driverLat + widget.order.customerLat) / 2;
    final centerLng = (driverLng + widget.order.customerLng) / 2;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(centerLat, centerLng),
          zoom: 12,
        ),
        markers: _markers,
        polylines: _polylines,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        myLocationButtonEnabled: false,
        compassEnabled: false,
        onMapCreated: (controller) {
          Future.delayed(const Duration(milliseconds: 500), () {
            final bounds = LatLngBounds(
              southwest: LatLng(
                [driverLat, widget.order.customerLat].reduce((a, b) => a < b ? a : b) - 0.02,
                [driverLng, widget.order.customerLng].reduce((a, b) => a < b ? a : b) - 0.02,
              ),
              northeast: LatLng(
                [driverLat, widget.order.customerLat].reduce((a, b) => a > b ? a : b) + 0.02,
                [driverLng, widget.order.customerLng].reduce((a, b) => a > b ? a : b) + 0.02,
              ),
            );
            controller.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 60),
            );
          });
        },
      ),
    );
  }

  Widget _buildDistanceTimeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Estimated Time
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.access_time_outlined,
                    color: Color(0xFFFDC500),
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(_estimatedTime),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'الوقت المتوقع',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Distance
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.straighten_outlined,
                    color: Color(0xFF00509D),
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDistance(_distanceToCustomer),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'المسافة',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
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

  Widget _buildCustomerInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Colors.black87,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'العميل',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.order.customerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.order.customerAddress,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Call button
              IconButton(
                onPressed: _callCustomer,
                icon: const Icon(
                  Icons.phone,
                  color: Color(0xFF00509D),
                  size: 24,
                ),
              ),
            ],
          ),
          if (widget.order.customerNearestLandmark != null &&
              widget.order.customerNearestLandmark!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFDC500).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFFFDC500),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'معلم قريب: ${widget.order.customerNearestLandmark}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF212121),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderItemsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: Colors.black87,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'العناصر المطلوبة',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),
              const Spacer(),
              Text(
                '${widget.order.items.length} عنصر',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.order.items.take(3).map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${item.quantity}x',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF424242),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
          if (widget.order.items.length > 3)
            TextButton(
              onPressed: _showOrderItems,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'عرض جميع العناصر (${widget.order.items.length})',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF00509D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Navigate Now Button
          ElevatedButton.icon(
            onPressed: _openGoogleMaps,
            icon: const Icon(Icons.navigation_outlined, size: 22),
            label: const Text(
              'توجه إلى العميل',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00509D),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              elevation: 0,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Arrived at Customer - Slide to Confirm
          _buildSlideToConfirm(),
        ],
      ),
    );
  }

  Widget _buildSlideToConfirm() {
    final maxSlide = MediaQuery.of(context).size.width - 32 - 60;
    final slideProgress = _slidePosition / maxSlide;
    final buttonColor = Color.lerp(
      const Color(0xFFFDC500),
      const Color(0xFF00509D),
      slideProgress,
    )!;
    
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          // RTL: السحب من اليمين لليسار
          _slidePosition -= details.delta.dx;
          if (_slidePosition < 0) _slidePosition = 0;
          if (_slidePosition > maxSlide) {
            _slidePosition = maxSlide;
          }
        });
      },
      onHorizontalDragEnd: (details) {
        if (_slidePosition > maxSlide * 0.8) {
          // تم السحب بنجاح - استدعاء الوصول
          _arriveAtCustomer();
        } else {
          // لم يكتمل السحب - إعادة الزر للبداية
          setState(() {
            _slidePosition = 0;
          });
        }
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            // Progress indicator
            Positioned(
              right: 0,
              child: Container(
                width: _slidePosition + 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00509D).withOpacity(0.1),
                      const Color(0xFF00509D).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            
            // Background text
            const Center(
              child: Text(
                'اسحب لتأكيد وصولك إلى العميل',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            
            // Sliding button - RTL from right
            Positioned(
              right: _slidePosition,
              child: Container(
                width: 56,
                height: 56,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: buttonColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
