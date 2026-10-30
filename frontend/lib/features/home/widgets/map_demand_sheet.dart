import 'package:flutter/material.dart';
import '../../demand/demand_service.dart';
import '../../demand/demand_card.dart';
import 'map_tools.dart';

class MapDemandSheet extends StatefulWidget {
  const MapDemandSheet({super.key, this.service});
  final DemandService? service;
  @override
  State<MapDemandSheet> createState() => _MapDemandSheetState();
}

class _MapDemandSheetState extends State<MapDemandSheet> {
  late final DemandService api;
  Map<String, dynamic>? data;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    api = widget.service ?? DemandService();
    load();
  }

  @override
  void dispose() {
    if (widget.service == null) api.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final d = await api.load();
      if (mounted) setState(() => data = d);
    } catch (_) {
      if (mounted)
        setState(() => error = 'تعذر تحديث الإحصائيات. أعد المحاولة.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = List<Map>.from(data?['days'] ?? []);
    return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .82,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        const Expanded(
                            child: Text('أوقات الطلب المتوقعة',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: mapInk))),
                        IconButton(
                            tooltip: 'تحديث',
                            onPressed: busy ? null : load,
                            icon: const Icon(Icons.refresh, color: mapInk)),
                        IconButton(
                            tooltip: 'إغلاق',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: mapInk))
                      ])),
                  if (busy) const LinearProgressIndicator(color: mapInk),
                  Expanded(
                      child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                        if (error != null)
                          Text(error!, style: const TextStyle(color: mapInk)),
                        if (data != null) ...[
                          Text(
                              'منطقة العمل: ${data?['area']?['name'] ?? 'غير محددة'}',
                              style: const TextStyle(
                                  color: mapInk, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          const Text(
                              'توقع لسبعة أيام مبني على النشاط السابق، وليس عدد طلبات جاهزة الآن. جميع الأوقات بتوقيت العراق، ولا يضمن وصول عروض.',
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.6,
                                  color: Color(0xFF53627B))),
                          if (data?['isTestData'] == true)
                            const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('بيانات تجريبية',
                                    style: TextStyle(
                                        color: mapInk,
                                        fontWeight: FontWeight.w600))),
                          if (data?['isWiderArea'] == true)
                            Text(
                                'التقدير على مستوى ${data?['sourceArea']?['name']} لعدم كفاية بيانات المنطقة.',
                                style: const TextStyle(color: mapInk)),
                          if (days.isEmpty)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: Text(stateMessage(data?['state']))),
                          if (days.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            WeekDemandOverview(days: days),
                          ],
                          for (final day in days)
                            Container(
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    border: Border.all(
                                        color: const Color(0xFFE2E7F0)),
                                    borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(dayLabel(day['date']),
                                          style: const TextStyle(
                                              color: mapInk,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 14),
                                      if ((day['slots'] as List? ?? [])
                                          .isNotEmpty)
                                        DemandBars(
                                            slots: List<Map>.from(day['slots']))
                                      else
                                        const Text(
                                            'لا توجد بيانات كافية لهذا اليوم.'),
                                    ])),
                          if (days.isNotEmpty)
                            const Padding(
                                padding: EdgeInsets.only(top: 16),
                                child: Wrap(spacing: 14, children: [
                                  DemandLegend('منخفض', DemandColors.low),
                                  DemandLegend('متوسط', DemandColors.medium),
                                  DemandLegend('مرتفع', DemandColors.high)
                                ])),
                        ]
                      ]))
                ]))));
  }
}

class WeekDemandOverview extends StatelessWidget {
  const WeekDemandOverview({super.key, required this.days});
  final List<Map> days;
  @override
  Widget build(BuildContext context) {
    final scores = days
        .map((d) => (d['slots'] as List? ?? []).fold<double>(
            0, (sum, s) => sum + ((s['score'] as num?)?.toDouble() ?? 0)))
        .toList();
    final max = scores.fold<double>(0, (a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('مقارنة النشاط المتوقع خلال الأسبوع',
          style: TextStyle(color: mapInk, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      SizedBox(
          height: 110,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                    Container(
                        width: 17,
                        height: max > 0 ? 8 + scores[i] / max * 66 : 8,
                        decoration: BoxDecoration(
                            color: max > 0
                                ? mapInk.withValues(
                                    alpha: .45 + scores[i] / max * .55)
                                : const Color(0xFFE2E7F0),
                            borderRadius: BorderRadius.circular(5))),
                    const SizedBox(height: 8),
                    Text('${DateTime.parse(days[i]['date']).day}',
                        style: const TextStyle(color: mapInk, fontSize: 12)),
                  ])),
          ])),
    ]);
  }
}
