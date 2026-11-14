import 'dart:async';
import 'package:flutter/material.dart';
import '../active_order/widgets/active_trip_summary.dart';
import 'demand_service.dart';

class DemandColors {
  static const high = TripStyle.ink;
  static const medium = Color(0xFF4D6997);
  static const low = Color(0xFF99AAC4);
  static const surface = Color(0xFFF4F6FA);
  static const outline = Color(0xFFD6DEEA);
  static const action = TripStyle.ink;
}

class DemandCard extends StatefulWidget {
  const DemandCard({super.key, this.service});
  final DemandService? service;
  @override
  State<DemandCard> createState() => _DemandCardState();
}

class _DemandCardState extends State<DemandCard> with WidgetsBindingObserver {
  late final DemandService service;
  Map<String, dynamic>? data;
  bool loading = true, failed = false;
  int generation = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    service = widget.service ?? DemandService();
    WidgetsBinding.instance.addObserver(this);
    load();
    timer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed)
        load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    final turn = ++generation;
    setState(() {
      loading = true;
      failed = false;
      data = null;
    });
    try {
      final response = await service.load();
      if (mounted && turn == generation) setState(() => data = response);
    } catch (_) {
      if (mounted && turn == generation) setState(() => failed = true);
    } finally {
      if (mounted && turn == generation) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.service == null) service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = (data?['days'] as List? ?? []).cast<Map>();
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: DemandColors.outline)),
            child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: data == null ? null : () => showDetails(context, data!),
                child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            const Icon(Icons.bar_chart_rounded,
                                color: DemandColors.action),
                            const SizedBox(width: 8),
                            const Expanded(
                                child: Text('أوقات الطلب المتوقعة',
                                    style: TextStyle(
                                        color: TripStyle.ink,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16))),
                            IconButton(
                                tooltip: 'تحديث التوقعات',
                                onPressed: loading ? null : load,
                                icon: const Icon(Icons.refresh,
                                    color: DemandColors.action, size: 20))
                          ]),
                          if (loading)
                            const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: DemandColors.action)))
                          else if (failed) ...[
                            const Text('تعذر تحميل التوقعات',
                                style: TextStyle(color: TripStyle.muted)),
                            TextButton(
                                onPressed: load,
                                child: const Text('إعادة المحاولة'))
                          ] else ...[
                            if (data?['area'] != null)
                              Text('منطقة العمل: ${data!['area']['name']}',
                                  style:
                                      const TextStyle(color: TripStyle.muted)),
                            if (data?['isTestData'] == true)
                              const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text('بيانات تجريبية',
                                      style: TextStyle(
                                          color: DemandColors.action,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                            if (data?['isWiderArea'] == true)
                              Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                      'التقدير على مستوى ${data!['sourceArea']['name']}',
                                      style: const TextStyle(
                                          color: TripStyle.muted,
                                          fontSize: 12))),
                            const SizedBox(height: 14),
                            if (days.isNotEmpty &&
                                (days.first['slots'] as List).isNotEmpty) ...[
                              const Text('اليوم',
                                  style: TextStyle(color: TripStyle.ink)),
                              DemandBars(
                                  slots: List<Map>.from(days.first['slots'])),
                              const SizedBox(height: 12),
                              const Wrap(spacing: 16, runSpacing: 8, children: [
                                DemandLegend('منخفض', DemandColors.low),
                                DemandLegend('متوسط', DemandColors.medium),
                                DemandLegend('مرتفع', DemandColors.high),
                              ]),
                            ] else
                              Text(stateMessage(data?['state']),
                                  style: const TextStyle(
                                      color: TripStyle.muted, height: 1.6)),
                            const SizedBox(height: 10),
                            Row(children: [
                              const Expanded(
                                  child: Text('تقدير للطلب، لا يضمن وصول عروض',
                                      style: TextStyle(
                                          color: TripStyle.muted,
                                          fontSize: 11))),
                              if (days.isNotEmpty)
                                const Icon(Icons.chevron_left,
                                    color: DemandColors.action)
                            ])
                          ]
                        ])))));
  }
}

String stateMessage(dynamic state) => switch (state) {
      'NO_REGION' => 'حدد منطقة العمل لعرض توقعاتها.',
      'UPDATING' => 'توقعات المنطقة قيد التحديث. حاول مجددًا لاحقًا.',
      _ => 'نجمع بيانات كافية لتحديد أوقات الطلب في هذه المنطقة.'
    };
void showDetails(BuildContext context, Map<String, dynamic> data) =>
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => DemandDetails(data: data));

class DemandDetails extends StatefulWidget {
  const DemandDetails({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  State<DemandDetails> createState() => _DemandDetailsState();
}

class _DemandDetailsState extends State<DemandDetails> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    final data = widget.data, days = List<Map>.from(data['days'] ?? []);
    return Directionality(
        textDirection: TextDirection.rtl,
        child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .85),
            child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            const Expanded(
                                child: Text('أوقات الطلب المتوقعة',
                                    style: TextStyle(
                                        color: TripStyle.ink,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold))),
                            IconButton(
                                tooltip: 'إغلاق',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close))
                          ]),
                          Text(
                              data['area'] != null
                                  ? 'منطقة العمل: ${data['area']['name']}'
                                  : 'منطقة العمل',
                              style: const TextStyle(color: TripStyle.muted)),
                          if (data['isTestData'] == true)
                            const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Text('بيانات تجريبية',
                                    style: TextStyle(
                                        color: DemandColors.action,
                                        fontWeight: FontWeight.bold))),
                          if (data['isWiderArea'] == true)
                            Text(
                                'لعدم كفاية بيانات المنطقة، يعرض التقدير على مستوى ${data['sourceArea']['name']}.',
                                style: const TextStyle(
                                    color: TripStyle.muted, height: 1.6)),
                          const SizedBox(height: 18),
                          if (days.isNotEmpty) ...[
                            SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: [
                                  for (var i = 0; i < days.length; i++)
                                    Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: ChoiceChip(
                                            label:
                                                Text(dayLabel(days[i]['date'])),
                                            selected: i == selected,
                                            checkmarkColor: Colors.white,
                                            selectedColor: DemandColors.high,
                                            labelStyle: TextStyle(
                                                color: i == selected
                                                    ? Colors.white
                                                    : TripStyle.ink),
                                            onSelected: (_) =>
                                                setState(() => selected = i)))
                                ])),
                            const SizedBox(height: 20),
                            if ((days[selected]['slots'] as List)
                                .isNotEmpty) ...[
                              DemandBars(
                                  slots:
                                      List<Map>.from(days[selected]['slots'])),
                              const SizedBox(height: 14),
                              const Wrap(spacing: 18, runSpacing: 8, children: [
                                DemandLegend('منخفض', DemandColors.low),
                                DemandLegend('متوسط', DemandColors.medium),
                                DemandLegend('مرتفع', DemandColors.high)
                              ])
                            ] else
                              const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Text(
                                      'لا تتوفر بيانات كافية لهذا اليوم بعد.',
                                      textAlign: TextAlign.center,
                                      style:
                                          TextStyle(color: TripStyle.muted))),
                          ] else
                            Text(stateMessage(data['state']),
                                style: const TextStyle(color: TripStyle.muted)),
                          const SizedBox(height: 22),
                          const Text(
                              'توقع مبني على نشاط الأيام المماثلة سابقًا. جميع الساعات بتوقيت العراق. لا يضمن عددًا محددًا من العروض أو الأرباح.',
                              style: TextStyle(
                                  color: TripStyle.muted,
                                  height: 1.7,
                                  fontSize: 13)),
                          if (data['generatedAt'] != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                    'آخر تحديث: ${updateLabel(data['generatedAt'])}',
                                    style: const TextStyle(
                                        color: TripStyle.muted, fontSize: 12))),
                          const SizedBox(height: 20),
                          OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: DemandColors.action),
                              child: const Text('العودة إلى الرئيسية'))
                        ])))));
  }
}

String dayLabel(String value) {
  final d = DateTime.parse(value);
  const names = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد'
  ];
  return '${names[d.weekday - 1]} ${d.day}/${d.month}';
}

String demandClock(int hour, {int? minute}) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  final digits =
      minute == null ? '$h' : '$h:${minute.toString().padLeft(2, '0')}';
  final arabic = digits.replaceAllMapped(
      RegExp(r'[0-9]'), (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)]);
  return '$arabic ${hour < 12 ? 'ص' : 'م'}';
}

String updateLabel(String value) {
  final d = DateTime.parse(value).toUtc().add(const Duration(hours: 3));
  return '${d.day}/${d.month} ${demandClock(d.hour, minute: d.minute)}';
}

class DemandLegend extends StatelessWidget {
  const DemandLegend(this.label, this.color, {super.key});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(color: TripStyle.muted, fontSize: 12))
      ]);
}

class DemandBars extends StatelessWidget {
  const DemandBars({super.key, required this.slots});
  final List<Map> slots;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        const Text('ارتفاع العمود يعكس مستوى الطلب المتوقع',
            style: TextStyle(color: TripStyle.muted, fontSize: 11)),
        const SizedBox(height: 12),
        Directionality(
            textDirection: TextDirection.ltr,
            child: Column(children: [
              Container(
                  key: const ValueKey('demand-plot'),
                  height: 96,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                      color: DemandColors.surface,
                      border: Border(
                          bottom: BorderSide(color: DemandColors.outline))),
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final slot in slots)
                          Expanded(
                              child: Tooltip(
                                  triggerMode: TooltipTriggerMode.tap,
                                  message:
                                      "${demandClock((slot['hour'] as num).toInt(), minute: 0)} • ${slot['level'] == 'HIGH' ? 'مرتفع' : slot['level'] == 'MEDIUM' ? 'متوسط' : slot['level'] == 'CLOSED' ? 'مغلق بحسب ساعات العمل' : 'منخفض'}",
                                  child: SizedBox(
                                      height: double.infinity,
                                      child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 2),
                                              child: Container(
                                                  height: (slot['score'] as num)
                                                          .clamp(0, 100) /
                                                      100 *
                                                      85,
                                                  decoration: BoxDecoration(
                                                      color: slot['level'] ==
                                                              'HIGH'
                                                          ? DemandColors.high
                                                          : slot['level'] ==
                                                                  'MEDIUM'
                                                              ? DemandColors
                                                                  .medium
                                                              : slot['level'] ==
                                                                      'CLOSED'
                                                                  ? const Color(
                                                                      0xFFDDE5EF)
                                                                  : DemandColors
                                                                      .low,
                                                      borderRadius:
                                                          const BorderRadius
                                                              .vertical(
                                                              top: Radius
                                                                  .circular(
                                                                      5)))))))))
                      ])),
              const SizedBox(height: 8),
              DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 11, color: TripStyle.muted),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('١٢ ص', textDirection: TextDirection.rtl),
                        Text('٦ ص', textDirection: TextDirection.rtl),
                        Text('١٢ م', textDirection: TextDirection.rtl),
                        Text('٦ م', textDirection: TextDirection.rtl),
                        Text('١١ م', textDirection: TextDirection.rtl)
                      ]))
            ])),
        const SizedBox(height: 6),
        const Text('الساعات بتوقيت العراق • اضغط على العمود لمعرفة الساعة',
            style: TextStyle(color: TripStyle.muted, fontSize: 10))
      ]));
}
