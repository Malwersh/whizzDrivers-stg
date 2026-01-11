import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import '../models/active_order_model.dart';
import '../../../providers/riverpod/active_order_provider.dart';
import '../widgets/cancel_order_dialog.dart';
import '../widgets/unassign_order_bottom_sheet.dart';
import '../../home/widgets/order_items_bottom_sheet.dart';
import '../../../services/driver_service.dart';
import 'dart:async';

/// شاشة التوجه للمطعم - المرحلة 1
class HeadingToRestaurantScreen extends ConsumerStatefulWidget {
  final ActiveOrder order;

  const HeadingToRestaurantScreen({
    super.key,
    required this.order,
  });

  @override
  ConsumerState<HeadingToRestaurantScreen> createState() =>
      _HeadingToRestaurantScreenState();
}

class _HeadingToRestaurantScreenState
    extends ConsumerState<HeadingToRestaurantScreen> {
  StreamSubscription<Position>? _positionStream;
  double? _distanceRestaurantToCustomer;
  double? _estimatedTime;
  double _slidePosition = 0.0;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _markersReady = false;

  @override
  void initState() {
    super.initState();
    _calculateDistanceAndTime();
    _startLocationTracking();
    _createCustomMarkers();
    
    // طباعة تشخيصية لمعلومات المطعم
    print('🍽️ Restaurant Name: ${widget.order.restaurantName}');
    print('📍 Restaurant Address: ${widget.order.restaurantAddress}');
    print('🆔 Restaurant ID: ${widget.order.restaurantId}');
    
    // تحديث الـ Provider بالطلب الحالي (مهم بعد hot restart)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeOrderProvider.notifier).updateOrder(widget.order);
    });
  }

  Future<void> _createCustomMarkers() async {
    const primaryYellow = Color(0xFFFDC500);
    const secondaryBlue = Color(0xFF00509D);
    const black = Color(0xFF000000);

    try {
      final restaurantIcon = await _createCircleMarkerWithIcon(
        Icons.restaurant,
        primaryYellow,
        black,
        100.0,
      );

      final driverIcon = await _createCircleMarker(
        secondaryBlue,
        60.0,
      );

      final customerIcon = await _createCircleMarkerWithIcon(
        Icons.home,
        primaryYellow,
        black,
        100.0,
      );

      const driverLat = 31.913292;
      const driverLng = 44.476014;

      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('driver'),
            position: const LatLng(driverLat, driverLng),
            icon: driverIcon,
            anchor: const Offset(0.5, 0.5),
          ),
          Marker(
            markerId: const MarkerId('restaurant'),
            position: LatLng(
              widget.order.restaurantLat,
              widget.order.restaurantLng,
            ),
            icon: restaurantIcon,
            anchor: const Offset(0.5, 0.5),
          ),
          Marker(
            markerId: const MarkerId('customer'),
            position: LatLng(
              widget.order.customerLat,
              widget.order.customerLng,
            ),
            icon: customerIcon,
            anchor: const Offset(0.5, 0.5),
          ),
        };

        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: [
              const LatLng(driverLat, driverLng),
              LatLng(widget.order.restaurantLat, widget.order.restaurantLng),
              LatLng(widget.order.customerLat, widget.order.customerLng),
            ],
            color: Colors.black,
            width: 8,
          ),
        };

        _markersReady = true;
      });
    } catch (e) {
      debugPrint('❌ Error creating markers: $e');
    }
  }

  Future<BitmapDescriptor> _createCircleMarker(
    Color color,
    double size,
  ) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = color;

    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2,
      paint,
    );

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(buffer);
  }

  Future<BitmapDescriptor> _createCircleMarkerWithIcon(
    IconData icon,
    Color iconColor,
    Color circleColor,
    double size,
  ) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    final circlePaint = Paint()..color = circleColor;
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2,
      circlePaint,
    );

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * 0.5,
        fontFamily: icon.fontFamily,
        color: iconColor,
        package: icon.fontPackage,
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
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(buffer);
  }

  // إنشاء custom markers بتصميم احترافي


  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  void _showCancelDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CancelOrderDialog(
        orderId: widget.order.orderId,
        onCancel: (reason, notes) async {
          // استدعاء API الإلغاء من خلال الـ Provider
          final success = await ref
              .read(activeOrderProvider.notifier)
              .cancelOrderByDriver(reason: reason, notes: notes);
          
          if (!success && mounted) {
            throw Exception('فشل في إلغاء الطلب');
          }
        },
      ),
    );
  }

  void _showUnassignBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UnassignOrderBottomSheet(
        orderId: widget.order.orderId,
        onUnassign: (reason) async {
          // استدعاء API فك الارتباط
          final result = await DriverService.unassignActiveOrder(reason);
          
          if (result['success'] == true) {
            if (mounted) {
              // عرض رسالة نجاح
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['message'] ?? 'تم فك الارتباط من الطلب بنجاح'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
              
              // مسح الطلب النشط من الـ Provider
              ref.read(activeOrderProvider.notifier).clearOrder();
              
              // تحديث حالة البحث في SharedPreferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isSearchingForOffers', true);
              await prefs.setString('searchEndTime', 
                DateTime.now().add(const Duration(hours: 2)).toIso8601String());
              
              // العودة للصفحة الرئيسية
              context.go('/');
            }
          } else {
            throw Exception(result['message'] ?? 'فشل في فك الارتباط من الطلب');
          }
        },
      ),
    );
  }

  void _calculateDistanceAndTime() {
    // Calculate distance from restaurant to customer
    _distanceRestaurantToCustomer = Geolocator.distanceBetween(
      widget.order.restaurantLat,
      widget.order.restaurantLng,
      widget.order.customerLat,
      widget.order.customerLng,
    );

    // Estimate time: assume 30 km/h average speed in city
    if (_distanceRestaurantToCustomer != null) {
      _estimatedTime = (_distanceRestaurantToCustomer! / 1000) / 30 * 60; // minutes
    }
  }

  void _startLocationTracking() {
    // Optional: Track position for future features
    // Currently not needed since we're not showing driver location
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      // Position tracked but not used in this version
      // Can be used later for real-time distance updates
    });
  }

  Future<void> _openGoogleMaps() async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${widget.order.restaurantLat},${widget.order.restaurantLng}&travelmode=driving';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _arriveAtRestaurant() async {
    print('🎯 _arriveAtRestaurant Screen: Starting...');
    
    // إعادة تعيين الزر للبداية قبل البدء
    setState(() {
      _slidePosition = 0;
    });
    
    print('🎯 _arriveAtRestaurant Screen: Calling provider.arriveAtStore()...');
    final success = await ref.read(activeOrderProvider.notifier).arriveAtStore();
    
    print('🎯 _arriveAtRestaurant Screen: Result = $success');
    
    if (success && mounted) {
      // الحصول على الطلب المحدث من الـ Provider
      final updatedOrder = ref.read(activeOrderProvider).order;
      print('✅ _arriveAtRestaurant Screen: Success! Navigating to AtRestaurantScreen');
      if (updatedOrder != null) {
        // Navigate to next screen (at restaurant) using GoRouter
        context.go('/at-restaurant', extra: updatedOrder);
      }
    } else if (mounted) {
      // في حالة الفشل، إظهار رسالة خطأ
      print('❌ _arriveAtRestaurant Screen: Failed! Showing error message');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل في تسجيل الوصول. حاول مرة أخرى'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOrderItems() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OrderItemsBottomSheet(
        items: widget.order.items,
        restaurantName: widget.order.restaurantName,
      ),
    );
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
      final hours = minutes ~/ 60;
      final mins = (minutes % 60).toStringAsFixed(0);
      return '$hours س $mins د';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('التوجه إلى المطعم'),
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
            
            // Restaurant Info
            _buildRestaurantInfo(),
            
            const SizedBox(height: 12),
            
            // Customer Info
            _buildCustomerInfo(),
            
            const SizedBox(height: 16),
            
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
    final centerLat = (driverLat + widget.order.restaurantLat + widget.order.customerLat) / 3;
    final centerLng = (driverLng + widget.order.restaurantLng + widget.order.customerLng) / 3;

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
          zoom: 11,
        ),
        markers: _markers,
        polylines: _polylines,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        myLocationButtonEnabled: false,
        compassEnabled: false,
        onMapCreated: (controller) {
          // ضبط الكاميرا لإظهار جميع النقاط بعد تحميل الخريطة
          Future.delayed(const Duration(milliseconds: 500), () {
            final bounds = LatLngBounds(
              southwest: LatLng(
                [driverLat, widget.order.restaurantLat, widget.order.customerLat].reduce((a, b) => a < b ? a : b) - 0.02,
                [driverLng, widget.order.restaurantLng, widget.order.customerLng].reduce((a, b) => a < b ? a : b) - 0.02,
              ),
              northeast: LatLng(
                [driverLat, widget.order.restaurantLat, widget.order.customerLat].reduce((a, b) => a > b ? a : b) + 0.02,
                [driverLng, widget.order.restaurantLng, widget.order.customerLng].reduce((a, b) => a > b ? a : b) + 0.02,
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
                    _formatDistance(_distanceRestaurantToCustomer),
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

  Widget _buildRestaurantInfo() {
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.restaurant_outlined,
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
                  'المطعم',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.order.restaurantName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.order.restaurantAddress,
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
      child: Row(
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
              'توجه إلى المطعم',
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
          
          // Unassign Button
          OutlinedButton.icon(
            onPressed: _showUnassignBottomSheet,
            icon: const Icon(Icons.link_off_rounded, size: 20),
            label: const Text(
              'فك الارتباط من الطلب',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange, width: 1.5),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Arrived at Restaurant - Slide to Confirm
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
          _arriveAtRestaurant();
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
                'اسحب لتأكيد وصولك إلى المطعم',
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

/// Custom painter لرسم المؤشرات والخط على الخريطة الثابتة

