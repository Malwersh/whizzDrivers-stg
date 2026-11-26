import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../active_order/widgets/active_trip_summary.dart';
import '../trips/trip_detail_screen.dart';
import '../trips/trip_presentation.dart';
import 'earnings_service.dart';
import 'earnings_summary.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen(
      {super.key, this.isActive = true, this.service, this.now});
  final bool isActive;
  final EarningsService? service;
  final DateTime? now;
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  late DateTimeRange range;
  String period = 'week';
  DateTime? day, updated;
  bool loading = false, expanded = false;
  String? error;
  EarningsSummary? summary;
  int generation = 0;
  DateTime get today {
    final n = widget.now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  late final service = widget.service ?? EarningsService();
  @override
  void initState() {
    super.initState();
    range = periodRange('week', today);
    if (widget.isActive) load();
  }

  @override
  void didUpdateWidget(covariant EarningsScreen old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) load();
    if (!widget.isActive && old.isActive) {
      generation++;
      loading = false;
    }
  }

  DateTimeRange periodRange(String mode, DateTime anchor) {
    if (mode == 'day') return DateTimeRange(start: anchor, end: anchor);
    if (mode == 'month')
      return DateTimeRange(
          start: DateTime(anchor.year, anchor.month),
          end: DateTime(anchor.year, anchor.month + 1, 0));
    final start =
        DateTime(anchor.year, anchor.month, anchor.day - anchor.weekday + 1);
    return DateTimeRange(
        start: start, end: DateTime(start.year, start.month, start.day + 6));
  }

  Future<void> load() async {
    final turn = ++generation;
    final chosen = range;
    setState(() {
      loading = true;
      error = null;
      summary = null;
      day = null;
      expanded = false;
    });
    try {
      final data = await service.load(
          chosen.start,
          DateTime(chosen.end.year, chosen.end.month, chosen.end.day + 1)
              .subtract(const Duration(milliseconds: 1)),
          isCurrent: () => mounted && turn == generation);
      if (!mounted || turn != generation) return;
      setState(() {
        summary = data;
        updated = DateTime.now();
      });
    } catch (_) {
      if (mounted && turn == generation)
        setState(() =>
            error = 'تعذر تحميل الفترة كاملة. تحقق من الاتصال وأعد المحاولة.');
    } finally {
      if (mounted && turn == generation) setState(() => loading = false);
    }
  }

  void choose(String mode) {
    setState(() {
      period = mode;
      range = periodRange(mode, today);
    });
    load();
  }

  void shift(int delta) {
    DateTime anchor;
    if (period == 'month') {
      anchor = DateTime(range.start.year, range.start.month + delta);
    } else {
      anchor = DateTime(range.start.year, range.start.month,
          range.start.day + delta * (period == 'day' ? 1 : 7));
    }
    if (anchor.isAfter(today)) return;
    setState(() => range = periodRange(period, anchor));
    load();
  }

  bool get canNext => period == 'month'
      ? DateTime(range.start.year, range.start.month + 1).isBefore(today) ||
          DateTime(range.start.year, range.start.month + 1) == today
      : !DateTime(range.start.year, range.start.month,
              range.start.day + (period == 'day' ? 1 : 7))
          .isAfter(today);
  Future<void> chooseDates() async {
    final end = range.end.isAfter(today) ? today : range.end;
    final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: today,
        initialDateRange: DateTimeRange(
            start: range.start.isAfter(end) ? end : range.start, end: end),
        helpText: 'فترة الأرباح',
        saveText: 'تطبيق',
        cancelText: 'رجوع',
        builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                    brightness: Brightness.light,
                    primary: TripStyle.blue,
                    onPrimary: Colors.white,
                    secondary: TripStyle.blue,
                    onSecondary: Colors.white,
                    surface: Colors.white,
                    onSurface: TripStyle.ink),
                datePickerTheme: DatePickerThemeData(
                    backgroundColor: Colors.white,
                    headerBackgroundColor: Colors.white,
                    headerForegroundColor: TripStyle.ink,
                    rangePickerBackgroundColor: Colors.white,
                    rangePickerHeaderBackgroundColor: Colors.white,
                    rangePickerHeaderForegroundColor: TripStyle.ink,
                    rangeSelectionBackgroundColor: const Color(0xFFE4EFFB),
                    rangeSelectionOverlayColor: WidgetStateProperty.all(
                        TripStyle.blue.withValues(alpha: .08)),
                    dayForegroundColor:
                        WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected))
                        return Colors.white;
                      if (states.contains(WidgetState.disabled))
                        return TripStyle.muted.withValues(alpha: .4);
                      return TripStyle.ink;
                    }),
                    dayBackgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? TripStyle.blue
                            : null),
                    todayForegroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.white
                            : TripStyle.blue),
                    todayBorder: const BorderSide(color: TripStyle.blue))),
            child: child!));
    if (!mounted || picked == null) return;
    setState(() {
      period = 'custom';
      range = picked;
    });
    load();
  }

  String dateLabel(DateTime d) => '${d.day}/${d.month}/${d.year}';
  String rangeLabel() => range.start == range.end
      ? dateLabel(range.start)
      : '${dateLabel(range.start)} — ${dateLabel(range.end)}';
  void help() => showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24))),
              child: SafeArea(
                  top: false,
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('كيف تُعرض أرباحك؟',
                                style: TextStyle(
                                    color: TripStyle.ink,
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 14),
                            const Text(
                                'المبلغ يجمع استحقاقات الرحلات المكتملة والمؤكدة خلال الفترة المختارة، بما فيها الإكرامية.\n\nقد تكون احتفظت باستحقاقك نقدًا عند التسليم؛ لا يُحتسب مرة أخرى كإضافة للمحفظة.\n\nشحن المحفظة والتحويلات والسحب ليست أرباح رحلات. يمكنك مراجعتها في المحفظة.',
                                style: TextStyle(
                                    color: TripStyle.muted, height: 1.7)),
                            const SizedBox(height: 18),
                            OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('العودة إلى الأرباح'))
                          ]))))));
  @override
  Widget build(BuildContext context) {
    final shown = summary == null
        ? null
        : day == null
            ? summary!
            : summary!.onDay(day!);
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            backgroundColor: TripStyle.background,
            appBar: AppBar(
                title: const Text('أرباحي',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                centerTitle: true,
                backgroundColor: Colors.white,
                foregroundColor: TripStyle.ink,
                elevation: 0,
                actions: [
                  IconButton(
                      tooltip: 'عن الأرباح',
                      onPressed: help,
                      icon: const Icon(Icons.info_outline)),
                  IconButton(
                      tooltip: 'تحديث الأرباح',
                      onPressed: loading ? null : load,
                      icon: const Icon(Icons.refresh))
                ]),
            body: RefreshIndicator(
                onRefresh: load,
                color: TripStyle.blue,
                child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [
                            for (final entry in const {
                              'day': 'اليوم',
                              'week': 'الأسبوع',
                              'month': 'الشهر',
                              'custom': 'فترة محددة'
                            }.entries)
                              Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: ChoiceChip(
                                      label: Text(entry.value),
                                      selected: period == entry.key,
                                      selectedColor: TripStyle.ink,
                                      backgroundColor: Colors.white,
                                      checkmarkColor: TripStyle.yellow,
                                      labelStyle: TextStyle(
                                          color: period == entry.key
                                              ? Colors.white
                                              : TripStyle.ink),
                                      onSelected: (_) => entry.key == 'custom'
                                          ? chooseDates()
                                          : choose(entry.key)))
                          ])),
                      const SizedBox(height: 12),
                      Row(children: [
                        if (period != 'custom')
                          IconButton(
                              tooltip: 'الفترة السابقة',
                              onPressed: () => shift(-1),
                              icon: const Icon(Icons.chevron_right,
                                  color: TripStyle.blue)),
                        Expanded(
                            child: TextButton(
                                onPressed: chooseDates,
                                child: Text(rangeLabel(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: TripStyle.blue, fontSize: 13)))),
                        if (period != 'custom')
                          IconButton(
                              tooltip: 'الفترة التالية',
                              onPressed: canNext ? () => shift(1) : null,
                              icon: const Icon(Icons.chevron_left))
                      ]),
                      const SizedBox(height: 14),
                      if (loading)
                        tripPanel(const Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(children: [
                              CircularProgressIndicator(color: TripStyle.blue),
                              SizedBox(height: 16),
                              Text('جارٍ تحميل أرباح الفترة',
                                  style: TextStyle(color: TripStyle.muted))
                            ]))),
                      if (error != null)
                        tripPanel(Column(children: [
                          const Icon(Icons.cloud_off_outlined,
                              color: TripStyle.blue, size: 38),
                          const SizedBox(height: 12),
                          Text(error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: TripStyle.muted, height: 1.6)),
                          TextButton(
                              onPressed: load,
                              child: const Text('إعادة المحاولة'))
                        ])),
                      if (shown != null) ...[
                        Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                                color: TripStyle.ink,
                                borderRadius: BorderRadius.circular(24)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(children: [
                                    const Icon(
                                        Icons.account_balance_wallet_outlined,
                                        color: TripStyle.yellow),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Text(
                                            day == null
                                                ? 'استحقاقات الفترة المؤكدة'
                                                : 'استحقاقات ${dateLabel(day!)}',
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14)))
                                  ]),
                                  const SizedBox(height: 18),
                                  Text(tripMoney(shown.total),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 14),
                                  Text('${shown.confirmed.length} رحلات مؤكدة',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 14))
                                ])),
                        if (shown.hasBreakdown) ...[
                          const SizedBox(height: 14),
                          tripPanel(Column(children: [
                            breakdown('أجور التوصيل', shown.base),
                            const Divider(height: 22),
                            breakdown('الإكرامية', shown.tips)
                          ]))
                        ],
                        if (shown.unconfirmedCount > 0)
                          Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: tripPanel(Text(
                                  '${shown.unconfirmedCount} رحلات مكتملة لا يتوفر لها مبلغ مؤكد؛ لم تُحتسب في الإجمالي.',
                                  style: const TextStyle(
                                      color: TripStyle.muted, height: 1.6)))),
                        if (summary!.confirmed.isNotEmpty &&
                            period == 'week') ...[
                          const SizedBox(height: 14),
                          weeklyChart()
                        ],
                        const SizedBox(height: 22),
                        Row(children: [
                          Expanded(
                              child: Text(
                                  day == null
                                      ? 'رحلات الفترة'
                                      : 'رحلات ${dateLabel(day!)}',
                                  style: const TextStyle(
                                      color: TripStyle.ink,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold))),
                          if (day != null)
                            TextButton(
                                onPressed: () => setState(() {
                                      day = null;
                                      expanded = false;
                                    }),
                                child: const Text('عرض الكل'))
                        ]),
                        const SizedBox(height: 12),
                        if (shown.trips.isEmpty)
                          tripPanel(const Column(children: [
                            Icon(Icons.route_outlined,
                                color: TripStyle.blue, size: 36),
                            SizedBox(height: 12),
                            Text('لا توجد رحلات مكتملة في هذه الفترة',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: TripStyle.muted))
                          ])),
                        ...shown.trips
                            .take(expanded ? shown.trips.length : 5)
                            .map((trip) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: tripRow(trip))),
                        if (shown.trips.length > 5 && !expanded)
                          OutlinedButton(
                              onPressed: () => setState(() => expanded = true),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: TripStyle.blue),
                              child: Text(
                                  'عرض بقية الرحلات (${shown.trips.length - 5})')),
                        if (updated != null)
                          Padding(
                              padding:
                                  const EdgeInsets.only(top: 12, bottom: 12),
                              child: Text('آخر تحديث ${Trip.time(updated)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: TripStyle.muted, fontSize: 11))),
                      ],
                    ]))));
  }

  Widget breakdown(String label, double amount) => Row(children: [
        Expanded(
            child: Text(label, style: const TextStyle(color: TripStyle.muted))),
        const SizedBox(width: 12),
        Text(tripMoney(amount),
            style: const TextStyle(
                color: TripStyle.ink,
                fontSize: 17,
                fontWeight: FontWeight.w600))
      ]);
  Widget tripRow(Trip trip) => Material(
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
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          trip.restaurantName.isEmpty
                              ? 'رحلة توصيل'
                              : trip.restaurantName,
                          style: const TextStyle(
                              color: TripStyle.ink,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                          '${trip.activityDate?.day}/${trip.activityDate?.month} • ${Trip.time(trip.activityDate)}',
                          style: const TextStyle(
                              color: TripStyle.muted, fontSize: 12))
                    ])),
                const SizedBox(width: 12),
                Flexible(
                    child: Text(
                        trip.earningsState == 'CONFIRMED'
                            ? tripMoney(trip.driverEarnings)
                            : 'غير مؤكد',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            color: TripStyle.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.bold))),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_left, color: TripStyle.muted, size: 20)
              ]))));
  Widget weeklyChart() {
    final dates = List.generate(
        7,
        (i) =>
            DateTime(range.start.year, range.start.month, range.start.day + i));
    final values = dates.map((d) => summary!.onDay(d).total).toList();
    final maxValue = values.fold<double>(1, (a, b) => a > b ? a : b);
    const names = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
    return tripPanel(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('التوزيع اليومي',
          style: TextStyle(color: TripStyle.ink, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('اختر يومًا لعرض استحقاقاته ورحلاته',
          style: TextStyle(color: TripStyle.muted, fontSize: 12)),
      const SizedBox(height: 18),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < 7; i++)
          Expanded(
              child: Semantics(
                  button: true,
                  selected: day == dates[i],
                  label: '${dateLabel(dates[i])}: ${tripMoney(values[i])}',
                  child: InkWell(
                      onTap: dates[i].isAfter(today)
                          ? null
                          : () => setState(() {
                                day = day == dates[i] ? null : dates[i];
                                expanded = false;
                              }),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 6),
                          child: Column(children: [
                            SizedBox(
                                height: 75,
                                child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                        height: values[i] == 0
                                            ? 2
                                            : 8 + values[i] / maxValue * 67,
                                        decoration: BoxDecoration(
                                            color: values[i] == 0
                                                ? const Color(0xFFDDE5EF)
                                                : day == dates[i]
                                                    ? TripStyle.blue
                                                    : TripStyle.ink,
                                            borderRadius:
                                                BorderRadius.circular(6))))),
                            const SizedBox(height: 8),
                            Text(names[dates[i].weekday - 1],
                                style: TextStyle(
                                    color: day == dates[i]
                                        ? TripStyle.blue
                                        : TripStyle.muted,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                            const SizedBox(height: 3),
                            Text('${dates[i].day}',
                                style: const TextStyle(
                                    color: TripStyle.muted, fontSize: 10))
                          ])))))
      ])
    ]));
  }
}
