import 'dart:async';
import '../../../services/driver_search_api_service.dart';
import '../services/store_navigation.dart';
import '../widgets/trip_arrival_slider.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/active_order_model.dart';
import '../services/trip_route_service.dart';
import '../../../providers/riverpod/active_order_provider.dart';
import '../widgets/active_trip_summary.dart';
import 'return_order_screen.dart';
import '../widgets/driver_trip_help.dart';

import '../../home/widgets/order_items_bottom_sheet.dart';

class HeadingToCustomerScreen extends ConsumerStatefulWidget {
  const HeadingToCustomerScreen(
      {super.key,
      required this.order,
      this.loadOrder,
      this.loadRoute,
      this.mapBuilder});
  final ActiveOrder order;
  final Future<ActiveOrder> Function(String)? loadOrder;
  final Future<TripRoadRoute> Function(String)? loadRoute;
  final Widget Function(Set<Marker>, Set<Polyline>)? mapBuilder;
  @override
  ConsumerState<HeadingToCustomerScreen> createState() =>
      _HeadingToCustomerScreenState();
}

class _HeadingToCustomerScreenState
    extends ConsumerState<HeadingToCustomerScreen> {
  late ActiveOrder _order;
  TripRoadRoute? _route;
  GoogleMapController? _map;
  Set<Marker> _markers = {};
  bool _routeLoading = true, _arriving = false, _fresh = false;
  String? _readError, _routeError;
  int _generation = 0;
  Timer? _locationTimer;
  bool _locating = false;
  Marker? _driverMarker;
  @override
  void initState() {
    super.initState();
    _order = widget.order;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      _updateLocation();
    });
    _locationTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _updateLocation());
  }

  bool get _hasUsefulLandmark {
    final value = _order.customerNearestLandmark?.trim() ?? '';
    return value.isNotEmpty &&
        !{'موقع محدد من الخريطة', 'محدد من الخريطة', 'موقع على الخريطة'}
            .contains(value);
  }

  Future<void> _updateLocation() async {
    if (_locating || !mounted) return;
    _locating = true;
    try {
      final position = await DriverSearchApiService.getCurrentPosition();
      if (!mounted) return;
      setState(() => _driverMarker = position == null
          ? null
          : Marker(
              markerId: const MarkerId('driver'),
              position: LatLng(position.latitude, position.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure),
              infoWindow: const InfoWindow(title: 'موقعك')));
    } catch (_) {
      if (mounted) setState(() => _driverMarker = null);
    } finally {
      _locating = false;
    }
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    setState(() => _readError = null);
    try {
      final order = await (widget.loadOrder ??
          ref.read(activeOrderServiceProvider).getOrderById)(_order.orderId);
      if (!mounted || generation != _generation) return;
      if (order.orderId != widget.order.orderId) throw Exception('تغير الطلب');
      setState(() {
        _order = order;
        _fresh = true;
      });
      ref.read(activeOrderProvider.notifier).updateOrder(order);
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() {
          _fresh = false;
          _readError = 'تعذر تحديث بيانات الطلب؛ اسحب لإعادة المحاولة';
        });
    }
    if (!mounted || generation != _generation) return;
    await _loadRoadRoute();
  }

  Future<void> _loadRoadRoute() async {
    if (!mounted) return;
    final generation = _generation;
    setState(() {
      _routeLoading = true;
      _routeError = null;
      _route = null;
    });
    _createMarkers();
    try {
      final route =
          await (widget.loadRoute ?? TripRouteService().load)(_order.orderId);
      if (!mounted || generation != _generation) return;
      setState(() => _route = route);
      _fitMap();
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() => _routeError = 'تعذر تحميل مسار الطريق');
    } finally {
      if (mounted && generation == _generation)
        setState(() => _routeLoading = false);
    }
  }

  Future<void> _createMarkers() async {
    final generation = _generation;
    final pickup = await _createCircleMarkerWithIcon(
        Icons.storefront, TripStyle.ink, TripStyle.yellow, 90);
    final dropoff = await _createCircleMarkerWithIcon(
        Icons.home_outlined, Colors.white, TripStyle.blue, 90);
    if (!mounted || generation != _generation) return;
    setState(() => _markers = {
          Marker(
              markerId: const MarkerId('pickup'),
              position: LatLng(_order.restaurantLat, _order.restaurantLng),
              icon: pickup,
              anchor: const Offset(.5, .5),
              infoWindow: InfoWindow(
                  title: _order.restaurantName, snippet: 'نقطة الاستلام')),
          Marker(
              markerId: const MarkerId('dropoff'),
              position: LatLng(_order.customerLat, _order.customerLng),
              icon: dropoff,
              anchor: const Offset(.5, .5),
              infoWindow: InfoWindow(
                  title: _order.customerName, snippet: 'نقطة التسليم')),
        });
    _fitMap();
  }

  Set<Polyline> get _polylines {
    final points = _route?.coordinates.map((p) => LatLng(p[1], p[0])).toList();
    if (points == null) return {};
    return {
      Polyline(
          polylineId: const PolylineId('outline'),
          points: points,
          color: Colors.white,
          width: 9,
          zIndex: 1),
      Polyline(
          polylineId: const PolylineId('road'),
          points: points,
          color: TripStyle.blue,
          width: 5,
          zIndex: 2)
    };
  }

  Future<void> _fitMap() async {
    final map = _map;
    if (map == null || !mounted) return;
    final points = _route?.coordinates ??
        [
          [_order.restaurantLng, _order.restaurantLat],
          [_order.customerLng, _order.customerLat]
        ];
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in points) {
      if (p[1] < minLat) minLat = p[1];
      if (p[1] > maxLat) maxLat = p[1];
      if (p[0] < minLng) minLng = p[0];
      if (p[0] > maxLng) maxLng = p[0];
    }
    try {
      await map.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(
              southwest: LatLng(minLat - .001, minLng - .001),
              northeast: LatLng(maxLat + .001, maxLng + .001)),
          45));
    } catch (_) {}
  }

  Future<void> _launch(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication))
        throw Exception();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح التطبيق؛ حاول مجددًا')));
    }
  }

  Future<void> _help() async {
    final action = await showModalBottomSheet<DriverTripHelpAction>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            DriverTripHelp(order: _order, allowUnableToDeliver: true));
    if (!mounted || action == null) return;
    switch (action) {
      case DriverTripHelpAction.callStore:
        await _launch(Uri(scheme: 'tel', path: _order.restaurantPhone));
        break;
      case DriverTripHelpAction.callCustomer:
        await _launch(Uri(scheme: 'tel', path: _order.customerPhone));
        break;
      case DriverTripHelpAction.items:
        _showItems();
        break;
      case DriverTripHelpAction.unableToDeliver:
        await showDeliveryFailureSheet(context, _order);
        break;
      case DriverTripHelpAction.unassign:
      case DriverTripHelpAction.reportPickup:
        break;
    }
  }

  void _showItems() => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderItemsBottomSheet(
          items: _order.items, restaurantName: _order.restaurantName));
  Future<void> _arrive() async {
    if (_arriving) return;
    setState(() {
      _arriving = true;
    });
    try {
      final current = await (widget.loadOrder ??
          ref.read(activeOrderServiceProvider).getOrderById)(_order.orderId);
      if (!mounted) return;
      if (current.orderId != _order.orderId ||
          !['heading_to_customer', 'arrived_at_customer', 'at_customer']
              .contains(current.status)) throw Exception();
      ref.read(activeOrderProvider.notifier).updateOrder(current);
      final success =
          ['arrived_at_customer', 'at_customer'].contains(current.status) ||
              await ref.read(activeOrderProvider.notifier).arriveAtCustomer();
      if (!mounted) return;
      final updated = ref.read(activeOrderProvider).order;
      if (!success || updated == null || updated.orderId != _order.orderId)
        throw Exception();
      context.go('/at-customer', extra: updated);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('لم يتأكد تسجيل الوصول؛ أعد المحاولة')));
    } finally {
      if (mounted) setState(() => _arriving = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _locationTimer?.cancel();
    _map?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: TripStyle.background,
        appBar: AppBar(
            title: const Text('في الطريق إلى الزبون',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: TripStyle.ink,
            elevation: 0,
            actions: [
              TextButton.icon(
                  onPressed: _arriving ? null : _help,
                  icon: const Icon(Icons.help_outline, size: 19),
                  label: const Text('مساعدة'),
                  style: TextButton.styleFrom(foregroundColor: TripStyle.blue))
            ]),
        body: Column(children: [
          Expanded(
              child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    if (_readError != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(_readError!,
                              style: const TextStyle(color: Colors.red))),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: SizedBox(
                            height: 260,
                            child: widget.mapBuilder?.call({
                                  ..._markers,
                                  if (_driverMarker != null) _driverMarker!
                                }, _polylines) ??
                                GoogleMap(
                                    initialCameraPosition: CameraPosition(
                                        target: LatLng(
                                            (_order.restaurantLat +
                                                    _order.customerLat) /
                                                2,
                                            (_order.restaurantLng +
                                                    _order.customerLng) /
                                                2),
                                        zoom: 12),
                                    onMapCreated: (map) {
                                      _map = map;
                                      _fitMap();
                                    },
                                    markers: {
                                      ..._markers,
                                      if (_driverMarker != null) _driverMarker!
                                    },
                                    polylines: _polylines,
                                    zoomControlsEnabled: false,
                                    mapToolbarEnabled: false,
                                    myLocationButtonEnabled: false,
                                    compassEnabled: false))),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.route_outlined,
                          color: TripStyle.blue, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                          child: Text('مسار الطريق من المتجر إلى الزبون',
                              style: TextStyle(
                                  color: TripStyle.muted, fontSize: 12)))
                    ]),
                    const SizedBox(height: 12),
                    if (_routeLoading)
                      const LinearProgressIndicator(color: TripStyle.blue),
                    if (_routeError != null)
                      _card(Row(children: [
                        Expanded(
                            child: Text(_routeError!,
                                style:
                                    const TextStyle(color: TripStyle.muted))),
                        TextButton(
                            onPressed: _loadRoadRoute,
                            style: TextButton.styleFrom(
                                foregroundColor: TripStyle.blue),
                            child: const Text('إعادة المحاولة'))
                      ])),
                    if (_route != null)
                      _card(Row(children: [
                        Expanded(
                            child: _metric(
                                Icons.straighten,
                                '${(_route!.distanceMeters / 1000).toStringAsFixed(1)} كم',
                                'مسافة المسار كاملًا')),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _metric(
                                Icons.schedule,
                                '${(_route!.durationSeconds / 60).ceil()} دقيقة',
                                'مدة المسار كاملًا'))
                      ])),
                    const SizedBox(height: 16),
                    _stop(Icons.location_on_outlined, 'نقطة التسليم',
                        _order.customerName, _order.customerAddress),
                    if (_hasUsefulLandmark)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _card(Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.place_outlined,
                                    color: TripStyle.blue),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(
                                        'علامة قريبة: ${_order.customerNearestLandmark}',
                                        style: const TextStyle(
                                            color: TripStyle.ink, height: 1.6)))
                              ]))),
                    if (_order.customerPhone.trim().isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: OutlinedButton.icon(
                              onPressed: () => _launch(Uri(
                                  scheme: 'tel', path: _order.customerPhone)),
                              icon: const Icon(Icons.call_outlined),
                              label: const Text('الاتصال بالزبون'),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: TripStyle.blue,
                                  minimumSize:
                                      const Size(double.infinity, 48)))),
                    const SizedBox(height: 12),
                    _card(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(_order.orderNumber ?? _order.orderId,
                              style: const TextStyle(color: TripStyle.muted)),
                          const SizedBox(height: 12),
                          Text(
                              _order.isCashPayment
                                  ? 'المطلوب تحصيله عند التسليم'
                                  : 'طريقة الدفع',
                              style: const TextStyle(color: TripStyle.muted)),
                          const SizedBox(height: 6),
                          Text(
                              _order.isCashPayment
                                  ? '${_order.totalAmount.toStringAsFixed(0)} د.ع'
                                  : 'مدفوع إلكترونيًا',
                              style: const TextStyle(
                                  color: TripStyle.ink,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold))
                        ])),
                    const SizedBox(height: 12),
                    _card(Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            const Icon(Icons.receipt_long_outlined,
                                color: TripStyle.blue),
                            const SizedBox(width: 10),
                            const Expanded(
                                child: Text('محتويات الطلب',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: TripStyle.ink))),
                            Text(
                                '${_order.items.fold<int>(0, (sum, item) => sum + item.quantity)} قطع',
                                style: const TextStyle(color: TripStyle.muted))
                          ]),
                          const SizedBox(height: 12),
                          ..._order.items.take(3).map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('${item.quantity} × ${item.name}',
                                  style:
                                      const TextStyle(color: TripStyle.ink)))),
                          if (_order.items.length > 3)
                            TextButton(
                                onPressed: _showItems,
                                style: TextButton.styleFrom(
                                    foregroundColor: TripStyle.blue),
                                child: const Text('عرض جميع الأصناف'))
                        ])),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                        onPressed: () async {
                          final uri = await StoreNavigation.forStore(
                              _order.customerLat, _order.customerLng);
                          if (mounted) await _launch(uri);
                        },
                        icon: const Icon(Icons.navigation_outlined),
                        label: const Text('توجّه إلى الزبون'),
                        style: FilledButton.styleFrom(
                            backgroundColor: TripStyle.blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)))),
                  ]))),
          Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE3E9F1)))),
              child: SafeArea(top: false, child: _arrivalSlider())),
        ]),
      ));
  Widget _card(Widget child) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE3E9F1))),
      child: child);
  Widget _metric(IconData icon, String value, String label) =>
      Column(children: [
        Icon(icon, color: TripStyle.blue, size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: TripStyle.ink)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: TripStyle.muted))
      ]);
  Widget _stop(IconData icon, String label, String name, String address) =>
      _card(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFEDF3FA),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: TripStyle.blue)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: TripStyle.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(name.isEmpty ? 'جارٍ تحديث اسم المتجر' : name,
              style: const TextStyle(
                  color: TripStyle.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          if (address.isNotEmpty)
            Text(address,
                style: const TextStyle(color: TripStyle.muted, height: 1.6))
        ]))
      ]));
  Widget _arrivalSlider() => TripArrivalSlider(
      enabled: !_arriving && _fresh,
      onConfirm: _arrive,
      semanticsLabel: 'اسحب إلى اليسار لتأكيد الوصول إلى الزبون');
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
}
