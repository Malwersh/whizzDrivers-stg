import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../services/trips_service.dart';
import '../active_order/widgets/active_trip_summary.dart';
import 'trip_detail_screen.dart';
import 'trip_presentation.dart';

typedef TripPageLoader = Future<Map<String, dynamic>> Function(
    {String? nextToken, String? status, DateTime? from, DateTime? to});

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key, this.isActive = true, this.loadPage});
  final bool isActive;
  final TripPageLoader? loadPage;
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<Trip> trips = [];
  bool loading = false, more = false;
  String? cursor, error, status;
  int generation = 0;
  DateTimeRange? range;
  @override
  void initState() {
    super.initState();
    if (widget.isActive) load();
  }

  @override
  void didUpdateWidget(covariant TripsScreen old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) load();
  }

  Future<void> load({bool append = false}) async {
    if (append && (loading || !more)) return;
    final turn = ++generation;
    setState(() {
      loading = true;
      error = null;
      if (!append) {
        trips = [];
        cursor = null;
        more = false;
      }
    });
    Map<String, dynamic> result;
    try {
      result = await (widget.loadPage ??
              (
                      {String? nextToken,
                      String? status,
                      DateTime? from,
                      DateTime? to}) =>
                  TripsService.fetchDriverTrips(
                      nextToken: nextToken,
                      status: status,
                      from: from,
                      to: to))(
          nextToken: append ? cursor : null,
          status: status,
          from: range?.start,
          to: range == null
              ? null
              : DateTime(range!.end.year, range!.end.month, range!.end.day + 1)
                  .subtract(const Duration(milliseconds: 1)));
    } catch (_) {
      result = {'success': false};
    }
    if (!mounted || turn != generation) return;
    setState(() {
      loading = false;
      if (result['success'] != true) {
        error = 'تعذر تحميل الرحلات. أعد المحاولة.';
        return;
      }
      final unique = {
        for (final t in trips) t.orderId: t,
        for (final t in result['trips'] as List<Trip>) t.orderId: t
      };
      trips = unique.values.toList()
        ..sort((a, b) => (b.activityDate ?? DateTime(1970))
            .compareTo(a.activityDate ?? DateTime(1970)));
      final next = result['nextToken'] as String?;
      more = result['hasMore'] == true && next != null && next != cursor;
      cursor = next;
    });
  }

  Future<void> chooseRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year, now.month, now.day),
        initialDateRange: range,
        helpText: 'اختر فترة الرحلات',
        saveText: 'تطبيق',
        cancelText: 'رجوع',
        builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: TripStyle.blue, secondary: TripStyle.yellow)),
            child: child!));
    if (!mounted || picked == null) return;
    setState(() => range = picked);
    load();
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Trip>>{};
    for (final trip in trips) {
      groups.putIfAbsent(trip.dateKey, () => []).add(trip);
    }
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            backgroundColor: TripStyle.background,
            appBar: AppBar(
                title: const Text('رحلاتي',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.white,
                foregroundColor: TripStyle.ink,
                elevation: 0,
                centerTitle: true,
                actions: [
                  IconButton(
                      tooltip: 'تحديث الرحلات',
                      onPressed: loading ? null : () => load(),
                      icon: const Icon(Icons.refresh))
                ]),
            body: RefreshIndicator(
                onRefresh: () => load(),
                color: TripStyle.blue,
                child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          sliver: SliverToBoxAdapter(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                const Text('سجل الرحلات',
                                    style: TextStyle(
                                        color: TripStyle.ink,
                                        fontSize: 23,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                const Text(
                                    'حالة كل رحلة واستحقاقك وتفاصيل التسليم',
                                    style: TextStyle(color: TripStyle.muted)),
                                const SizedBox(height: 18),
                                Row(children: [
                                  Expanded(
                                      child: OutlinedButton.icon(
                                          onPressed: chooseRange,
                                          icon: const Icon(
                                              Icons.date_range_outlined,
                                              size: 19),
                                          label: Text(
                                              range == null
                                                  ? 'كل الفترات'
                                                  : '${range!.start.day}/${range!.start.month}/${range!.start.year} — ${range!.end.day}/${range!.end.month}/${range!.end.year}',
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                              foregroundColor: TripStyle.blue,
                                              minimumSize: const Size(0, 46),
                                              backgroundColor: Colors.white,
                                              side: const BorderSide(
                                                  color: Color(0xFFDDE5EF)),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14))))),
                                  if (range != null)
                                    IconButton(
                                        tooltip: 'إلغاء الفترة',
                                        onPressed: () {
                                          setState(() => range = null);
                                          load();
                                        },
                                        icon: const Icon(Icons.close,
                                            color: TripStyle.blue))
                                ]),
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(children: [
                                      for (final entry
                                          in const <String?, String>{
                                        null: 'الكل',
                                        'completed': 'مكتملة',
                                        'cancelled': 'ملغاة',
                                        'returned': 'مرتجعة'
                                      }.entries)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(left: 8),
                                            child: ChoiceChip(
                                                label: Text(entry.value),
                                                selected: status == entry.key,
                                                onSelected: (_) {
                                                  setState(
                                                      () => status = entry.key);
                                                  load();
                                                },
                                                selectedColor: TripStyle.ink,
                                                labelStyle: TextStyle(
                                                    color: status == entry.key
                                                        ? Colors.white
                                                        : TripStyle.ink),
                                                checkmarkColor:
                                                    TripStyle.yellow,
                                                backgroundColor: Colors.white,
                                                side: const BorderSide(
                                                    color: Color(0xFFDDE5EF))))
                                    ])),
                              ]))),
                      if (loading && trips.isEmpty)
                        const SliverToBoxAdapter(
                            child: Padding(
                                padding: EdgeInsets.all(48),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: TripStyle.blue)))),
                      if (!loading && trips.isEmpty)
                        SliverToBoxAdapter(
                            child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: tripPanel(Column(children: [
                                  Icon(
                                      error == null
                                          ? Icons.route_outlined
                                          : Icons.cloud_off_outlined,
                                      color: TripStyle.blue,
                                      size: 40),
                                  const SizedBox(height: 14),
                                  Text(
                                      error ??
                                          (more
                                              ? 'تابع تحميل السجل لعرض الرحلات المطابقة'
                                              : 'لا توجد رحلات ضمن هذا الاختيار'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: TripStyle.ink, fontSize: 17)),
                                  if (error != null)
                                    TextButton(
                                        onPressed: () => load(),
                                        child: const Text('إعادة المحاولة'))
                                ])))),
                      for (final group in groups.values) ...[
                        SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                            sliver: SliverToBoxAdapter(
                                child: Text(group.first.getFormattedDate(),
                                    style: const TextStyle(
                                        color: TripStyle.muted,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)))),
                        SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                    (context, index) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: card(group[index])),
                                    childCount: group.length))),
                      ],
                      if (error != null && trips.isNotEmpty)
                        SliverToBoxAdapter(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: TripStyle.muted)))),
                      if (more)
                        SliverToBoxAdapter(
                            child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: OutlinedButton(
                                    onPressed: loading
                                        ? null
                                        : () => load(append: true),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: TripStyle.blue,
                                        minimumSize:
                                            const Size(double.infinity, 48)),
                                    child: loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : Text(error == null
                                            ? 'تحميل المزيد'
                                            : 'إعادة محاولة تحميل المزيد')))),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    ]))));
  }

  Widget card(Trip trip) => Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE0E7F0))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip))),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    trip.restaurantName.isEmpty
                                        ? 'رحلة توصيل'
                                        : trip.restaurantName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: TripStyle.ink,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 5),
                                Text(trip.displayReference,
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                        color: TripStyle.muted, fontSize: 11))
                              ])),
                          const SizedBox(width: 12),
                          const Icon(Icons.chevron_left, color: TripStyle.muted)
                        ]),
                    const SizedBox(height: 16),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(tripEarningTitle(trip),
                                style: const TextStyle(
                                    color: TripStyle.muted, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(tripEarningAmount(trip),
                                style: TextStyle(
                                    color: TripStyle.ink,
                                    fontSize:
                                        trip.driverEarnings == null ? 14 : 23,
                                    fontWeight: FontWeight.bold))
                          ])),
                      TripStatusBadge(trip: trip)
                    ]),
                    const SizedBox(height: 12),
                    Text(
                        '${Trip.time(trip.activityDate)} • طلب واحد${trip.quantity == null ? '' : ' • ${trip.quantity} قطع'}',
                        style: const TextStyle(
                            color: TripStyle.muted, fontSize: 12)),
                  ]))));
}
