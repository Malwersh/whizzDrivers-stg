import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/trip_model.dart';
import '../../services/trips_service.dart';
import '../active_order/models/active_order_model.dart';
import '../active_order/screens/customer_cash_review_screen.dart';
import '../active_order/screens/return_continuation_screen.dart';
import '../active_order/services/customer_cash_review_service.dart';
import '../active_order/services/return_continuation_service.dart';
import '../active_order/widgets/active_trip_summary.dart';
import '../active_order/widgets/delivery_proof_card.dart';
import 'trip_presentation.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen(
      {super.key, required this.trip, this.loadTrip, this.mapBuilder});
  final Trip trip;
  final Future<Trip> Function(String)? loadTrip;
  final Widget Function(Set<Marker>)? mapBuilder;
  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late Trip trip;
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    trip = widget.trip;
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value =
          await (widget.loadTrip ?? TripsService.fetchTrip)(trip.orderId);
      if (value.orderId != widget.trip.orderId) throw Exception();
      if (mounted) setState(() => trip = value);
    } catch (_) {
      if (mounted)
        setState(() => error = 'تعذر تحديث التفاصيل؛ اسحب لإعادة المحاولة.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool valid(Map<String, double> p) =>
      p['lat'] != null &&
      p['lng'] != null &&
      p['lat']!.abs() <= 90 &&
      p['lng']!.abs() <= 180 &&
      (p['lat'] != 0 || p['lng'] != 0);
  Widget valueRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(color: TripStyle.muted, height: 1.5))),
        const SizedBox(width: 16),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    color: TripStyle.ink,
                    fontWeight: FontWeight.w600,
                    height: 1.5)))
      ]));
  Widget title(String text) => Text(text,
      style: const TextStyle(
          color: TripStyle.ink, fontSize: 18, fontWeight: FontWeight.bold));
  Widget stop(IconData icon, String label, String name, String address,
          DateTime? time) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
            backgroundColor: const Color(0xFFEDF3FA),
            child: Icon(icon, color: TripStyle.blue)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(label,
                  style: const TextStyle(color: TripStyle.muted, fontSize: 12)),
              const SizedBox(height: 5),
              if (name.isNotEmpty)
                Text(name,
                    style: const TextStyle(
                        color: TripStyle.ink,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              if (address.isNotEmpty)
                Text(address,
                    style:
                        const TextStyle(color: TripStyle.muted, height: 1.6)),
              if (time != null)
                Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                        '${time.day}/${time.month}/${time.year} • ${Trip.time(time)}',
                        style: const TextStyle(
                            color: TripStyle.blue, fontSize: 12)))
            ]))
      ]);
  Widget map() {
    final a = LatLng(trip.pickupLocation['lat']!, trip.pickupLocation['lng']!),
        b = LatLng(
            trip.deliveryLocation['lat']!, trip.deliveryLocation['lng']!);
    final markers = {
      Marker(
          markerId: const MarkerId('pickup'),
          position: a,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow:
              InfoWindow(title: trip.restaurantName, snippet: 'نقطة الاستلام')),
      Marker(
          markerId: const MarkerId('dropoff'),
          position: b,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'وجهة الطلب'))
    };
    return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
            height: 190,
            child: widget.mapBuilder?.call(markers) ??
                GoogleMap(
                    initialCameraPosition: CameraPosition(
                        target: LatLng((a.latitude + b.latitude) / 2,
                            (a.longitude + b.longitude) / 2),
                        zoom: 12),
                    markers: markers,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationButtonEnabled: false,
                    onMapCreated: (controller) {
                      controller.moveCamera(CameraUpdate.newLatLngBounds(
                          LatLngBounds(
                              southwest: LatLng(
                                  math.min(a.latitude, b.latitude) - .001,
                                  math.min(a.longitude, b.longitude) - .001),
                              northeast: LatLng(
                                  math.max(a.latitude, b.latitude) + .001,
                                  math.max(a.longitude, b.longitude) + .001)),
                          35));
                    })));
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: TripStyle.background,
          appBar: AppBar(
              title: const Text('تفاصيل الرحلة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              centerTitle: true,
              backgroundColor: Colors.white,
              foregroundColor: TripStyle.ink,
              elevation: 0,
              actions: [
                IconButton(
                    tooltip: 'تحديث التفاصيل',
                    onPressed: loading ? null : load,
                    icon: const Icon(Icons.refresh))
              ]),
          body: RefreshIndicator(
              onRefresh: load,
              color: TripStyle.blue,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                if (loading)
                  const LinearProgressIndicator(color: TripStyle.blue),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(error!,
                          style: const TextStyle(color: TripStyle.muted))),
                Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                        color: TripStyle.ink,
                        borderRadius: BorderRadius.circular(24)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            const Icon(Icons.route_outlined,
                                color: TripStyle.yellow),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(trip.displayReference,
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13)))
                          ]),
                          const SizedBox(height: 24),
                          Text(tripEarningTitle(trip),
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text(tripEarningAmount(trip),
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize:
                                      trip.driverEarnings == null ? 22 : 34,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Text(tripEarningDescription(trip),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 20),
                          Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text(trip.getStatusText(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600))))
                        ])),
                const SizedBox(height: 14),
                if (trip.driverBaseEarnings != null) ...[
                  tripPanel(Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title('تفاصيل الاستحقاق'),
                        const SizedBox(height: 8),
                        valueRow(
                            'أجرة التوصيل', tripMoney(trip.driverBaseEarnings)),
                        valueRow('الإكرامية', tripMoney(trip.tip)),
                        const Divider(),
                        valueRow('الإجمالي', tripEarningAmount(trip))
                      ])),
                  const SizedBox(height: 14)
                ],
                if (valid(trip.pickupLocation) &&
                    valid(trip.deliveryLocation)) ...[
                  map(),
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('نقطتا الاستلام ووجهة الطلب',
                          style:
                              TextStyle(color: TripStyle.muted, fontSize: 12)))
                ],
                tripPanel(Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title('مراحل الرحلة'),
                      const SizedBox(height: 18),
                      if (trip.acceptedAt != null) ...[
                        valueRow('قبول الطلب', Trip.time(trip.acceptedAt)),
                        const Divider(height: 24)
                      ],
                      stop(
                          Icons.storefront_outlined,
                          'الاستلام من المتجر',
                          trip.restaurantName,
                          trip.pickupAddress,
                          trip.pickupTime),
                      const Padding(
                          padding: EdgeInsetsDirectional.only(start: 19),
                          child: SizedBox(
                              height: 28,
                              child: VerticalDivider(
                                  color: Color(0xFFDDE5EF), thickness: 2))),
                      stop(
                          Icons.location_on_outlined,
                          trip.status == TripStatus.completed
                              ? 'التسليم للزبون'
                              : 'وجهة الطلب',
                          trip.customerName,
                          trip.deliveryAddress,
                          trip.deliveryTime),
                      if (trip.durationSeconds != null ||
                          trip.estimatedDistanceMeters != null) ...[
                        const Divider(height: 28),
                        if (trip.durationSeconds != null)
                          valueRow('مدة الرحلة',
                              '${trip.durationSeconds! ~/ 60} دقيقة'),
                        if (trip.estimatedDistanceMeters != null)
                          valueRow('المسافة المقدّرة',
                              '${(trip.estimatedDistanceMeters! / 1000).toStringAsFixed(1)} كم')
                      ]
                    ])),
                const SizedBox(height: 14),
                tripPanel(Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title('بيانات الطلب'),
                      const SizedBox(height: 10),
                      SelectableText(
                          trip.orderNumber.isEmpty
                              ? trip.orderId
                              : trip.orderNumber,
                          style: const TextStyle(color: TripStyle.muted)),
                      if (trip.quantity != null)
                        valueRow('الكمية', '${trip.quantity} قطع'),
                      valueRow('الحالة', trip.getStatusText())
                    ])),
                if (trip.cashCollectedAmount != null) ...[
                  const SizedBox(height: 14),
                  tripPanel(Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title('التحصيل والتسوية'),
                        const SizedBox(height: 10),
                        valueRow('المحصّل نقدًا من الزبون',
                            tripMoney(trip.cashCollectedAmount)),
                        if (trip.driverCashRetained != null)
                          valueRow('استحقاقك المحتفظ به نقدًا',
                              tripMoney(trip.driverCashRetained)),
                        if (trip.settledCollateral != null)
                          valueRow('المبلغ المسوّى من الحجز',
                              tripMoney(trip.settledCollateral)),
                        if (trip.driverWalletCredit != null)
                          valueRow('إضافة للمحفظة عند الإكمال',
                              tripMoney(trip.driverWalletCredit)),
                        if (trip.driverCashRetained != null)
                          const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text(
                                  'الاستحقاق المحتفظ به نقدًا جزء من إجمالي استحقاقك، ولا يُضاف إليه مرة ثانية.',
                                  style: TextStyle(
                                      color: TripStyle.muted,
                                      height: 1.6,
                                      fontSize: 12)))
                      ]))
                ],
                if (trip.deliveryProofCount > 0) ...[
                  const SizedBox(height: 14),
                  DeliveryProofCard(
                      order: ActiveOrder.fromJson({
                        'orderId': trip.orderId,
                        'status': 'delivered',
                        'items': []
                      }),
                      onBusy: (_) {},
                      readOnly: true)
                ],
                const SizedBox(height: 18),
                tripPanel(Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title('المساعدة والمتابعة'),
                      const SizedBox(height: 10),
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.payments_outlined,
                              color: TripStyle.blue),
                          title: const Text('مراجعة النقد ورد المبلغ',
                              style: TextStyle(color: TripStyle.ink)),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CustomerCashReviewScreen(
                                      driver: true,
                                      call: (body) =>
                                          CustomerCashReviewService()
                                              .call(trip.orderId, body))))),
                      if (trip.hasReturnCase)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                                Icons.assignment_return_outlined,
                                color: TripStyle.blue),
                            title: const Text('متابعة المرتجع',
                                style: TextStyle(color: TripStyle.ink)),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => ReturnContinuationScreen(
                                        orderId: trip.orderId,
                                        caseKey: 'CURRENT',
                                        driver: true,
                                        call: (body) =>
                                            ReturnContinuationService()
                                                .call(trip.orderId, body)))))
                    ])),
              ]))));
}
