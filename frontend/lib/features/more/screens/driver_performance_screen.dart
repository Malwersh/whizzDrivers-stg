import 'package:flutter/material.dart';
import '../../../models/driver_performance_snapshot.dart';
import '../../../services/driver_search_api_service.dart';

class DriverPerformanceScreen extends StatefulWidget {
  final Future<Map<String, dynamic>?> Function()? load;
  const DriverPerformanceScreen({super.key, this.load});
  @override
  State<DriverPerformanceScreen> createState() =>
      _DriverPerformanceScreenState();
}

class _DriverPerformanceScreenState extends State<DriverPerformanceScreen> {
  DriverPerformanceSnapshot? _metrics;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _metrics = null;
    });
    final data = await (widget.load?.call() ??
        DriverSearchApiService.getDriverPerformance());
    if (!mounted) return;
    setState(() {
      _metrics = data == null ? null : DriverPerformanceSnapshot(data);
      _loading = false;
    });
  }

  static const _navy = Color(0xFF00296B);
  static const _muted = Color(0xFF667085);

  int? _sample(String section, String field) {
    final data = _metrics?.data[section];
    final value = data is Map ? data[field] : null;
    return value is int && value >= 0 ? value : null;
  }

  String _sampleLabel(String section, String field, String unit) {
    final n = _sample(section, field);
    return n == null || n == 0 ? 'بانتظار بيانات موثقة' : 'بناءً على $n $unit';
  }

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: const Color(0xFFF0F3F8),
            borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475467))),
      );

  Widget _metricRow(
      {required String title,
      required String value,
      required String subtitle,
      required IconData icon,
      required String description,
      String? status,
      String? detailKey}) {
    final iconBox = Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: const Color(0xFFF0F4FA),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 20, color: _navy));
    final heading = Text(title,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF182230)));
    final sample = Text(subtitle,
        style: const TextStyle(fontSize: 12, color: _muted, height: 1.5));
    final number = Text(value,
        textDirection: TextDirection.ltr,
        style: const TextStyle(
            fontSize: 25, fontWeight: FontWeight.w700, color: _navy));
    const arrow =
        Icon(Icons.chevron_left_rounded, size: 18, color: Color(0xFF98A2B3));
    return Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => _showDetails(title, detailKey, description: description),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: LayoutBuilder(builder: (context, constraints) {
                final stacked = constraints.maxWidth < 270 ||
                    MediaQuery.textScalerOf(context).scale(16) > 20;
                if (stacked) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          iconBox,
                          const SizedBox(width: 12),
                          Expanded(child: heading),
                          const SizedBox(width: 6),
                          arrow
                        ]),
                        const SizedBox(height: 12),
                        Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: number),
                        const SizedBox(height: 5),
                        sample,
                        if (status != null) ...[
                          const SizedBox(height: 7),
                          Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: _badge(status))
                        ],
                      ]);
                }
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      iconBox,
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            heading,
                            const SizedBox(height: 5),
                            sample,
                            if (status != null) ...[
                              const SizedBox(height: 6),
                              Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: _badge(status))
                            ],
                          ])),
                      const SizedBox(width: 10),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [number, const SizedBox(height: 4), arrow]),
                    ]);
              })),
        ));
  }

  Widget _rateRow(String title, String key, String section, String unit,
      IconData icon, String description) {
    final value = _metrics?.rate(key);
    final provisional =
        value != null && _metrics?.data['${key}Status'] == 'PROVISIONAL';
    return _metricRow(
        title: title,
        value: value == null ? '—' : '${(value * 100).toStringAsFixed(1)}٪',
        subtitle: _sampleLabel(section, 'sampleSize', unit),
        icon: icon,
        description: description,
        status: value == null
            ? 'بيانات غير كافية'
            : provisional
                ? 'مبدئي'
                : null,
        detailKey: section);
  }

  Widget _guideItem(String title, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 5),
          Text(text,
              style: const TextStyle(
                  fontSize: 13, height: 1.7, color: Color(0xFF475467))),
        ]),
      );

  String get _acceptanceDescription {
    final d = _metrics?.data['acceptance'];
    if (d is! Map) return 'لا توجد بيانات موثقة كافية لعرض النسبة.';
    return 'قبلت ${d['accepted']} ورفضت ${d['declined']}، وانتهت مهلة ${d['expiredDelivered'] ?? 0} عروض ثبت ظهورها دون رد، ضمن عينة ${d['sampleSize']} عرضًا. '
        'استُبعد ${d['unconfirmedExcluded']} عرضًا لم يثبت وصوله و${d['withdrawnExcluded']} عرضًا مسحوبًا. '
        'المؤشر المبدئي يخص العروض المؤكدة، ولا يعني اكتمال سجل جميع العروض.';
  }

  String get _completionDescription {
    final d = _metrics?.data['completion'];
    if (d is! Map) return 'لا توجد التزامات محسومة كافية لعرض النسبة.';
    return 'تم تسليم ${d['completed']} وإرجاع ${d['returned']} بشكل موثق. '
        'إخفاقات مثبتة على السائق: ${d['driverFailures']}. '
        'قيد التنفيذ: ${d['inProgress']}، وقيد مراجعة أثر الأداء: ${d['reviewExcluded']}، وحالات معذورة مستبعدة: ${d['noFaultExcluded']}. '
        'الطلبات الجارية وقيد المراجعة لا تُحسب إخفاقًا. العينة: ${d['sampleSize']} التزامًا محسومًا.';
  }

  String get _punctualityDescription {
    final d = _metrics?.data['punctuality'];
    if (d is! Map) {
      return 'لا تتوفر بعد مواعيد أصلية موثقة لهذه الرحلات. لا تُحسب البيانات الناقصة تأخيرًا.';
    }
    return 'الوصول للمطعم والزبون ضمن الموعد الأصلي مع سماح ${((d['graceSeconds'] as num? ?? 300) / 60).round()} دقائق. '
        'ضمن الموعد: ${d['onTime']}، تجاوز الموعد المسجل: ${d['lateObserved']}، العينة: ${d['sampleSize']}. '
        'حالات معذورة بقرار مراجعة: ${d['excusedExcluded'] ?? 0}، قيد المراجعة: ${d['reviewExcluded']}، مستبعدة لعدم كفاية البيانات أو عدم التسليم: ${d['unavailableExcluded']}، جارية: ${d['inProgress']}. '
        'الأوقات مسجلة عند تأكيد مراحل الرحلة. تجاوز الموعد وحده لا يثبت مسؤوليتك، ولا يغيّر أهليتك تلقائيًا.';
  }

  Map? get _ratingWindow => _metrics?.data['ratingWindow'] is Map
      ? _metrics!.data['ratingWindow'] as Map
      : null;

  String get _ratingDescription {
    final w = _ratingWindow;
    if (w == null)
      return 'المتوسط المعروض من كامل السجل الموثق؛ نافذة آخر 100 لم تتوفر من الخادم بعد.';
    if (w['status'] == 'UNAVAILABLE')
      return 'تعذر التحقق من نافذة التقييمات الآن. حدّث المؤشرات؛ لا نستبدلها بمتوسط قديم أو بصفر نجوم.';
    final totals = w['allTime'] is Map ? w['allTime'] as Map : {};
    return 'متوسط آخر 100 تقييم صالح بحد أقصى، مرتبة بوقت تسجيل تقييم الزبون. '
        'العينة المحتسبة: ${w['count']}. تُملأ العينة بتقييمات أقدم عند استبعاد تقييم أو فتح مراجعته. '
        'في الجزء المفحوص: قيد المراجعة ${w['underReview'] ?? 0}، مستبعدة ${w['excluded'] ?? 0}، تحتاج تحققًا ${w['unverified'] ?? 0}. '
        'في كامل السجل: قيد المراجعة ${totals['underReview'] ?? 0}، مستبعدة ${totals['excluded'] ?? 0}. '
        '${w['status'] == 'PROVISIONAL' ? 'النافذة مبدئية؛ قراءة المصدر لم تتأكد بالكامل أو تأخر تحديث الفهرس. ' : ''}'
        'النجوم الأصلية محفوظة. هذا المؤشر لا يغير تقييم المطعم أو التعويضات أو أهليتك تلقائيًا.';
  }

  String get _activityDescription {
    final d = _metrics?.data['activity'];
    if (d is! Map) return 'يظهر نشاطك من سجل القبول الموثق بعد توفر البيانات.';
    return 'عدد العروض التي قبلتها خلال آخر 30 يومًا حتى وقت التحديث، وليس عدد الرحلات المكتملة أو ساعات العمل. '
        '${d['coverageComplete'] == true ? 'اكتملت قراءة الفترة المتاحة.' : 'قراءة الفترة جزئية؛ العدد المعروض حد أدنى وليس إجماليًا نهائيًا.'} '
        'استُبعد ${d['legacyExcluded'] ?? 0} عرضًا قديمًا لا يملك عقد القبول الموثق. '
        'النشاط للمعلومة، ولا يعاقبك على قلة ساعات العمل.';
  }

  String _eventLabel(dynamic value) =>
      const {
        'INCLUDED': 'تقييم محتسب',
        'UNVERIFIED': 'تقييم يحتاج تحققًا · غير محتسب',
        'ORIGINAL_VERIFIED_CUSTOMER_RATING': 'تقييم أصلي من زبون الطلب المسلّم',
        'RATING_REVIEW_CONFIRMED': 'اعتمد التقييم الأصلي بعد المراجعة',
        'RATING_REVIEW_EXCLUDED': 'مستبعد بقرار مراجعة',
        'RATING_REVIEW_PENDING': 'مراجعة مفتوحة · مستبعد مؤقتًا',
        'RATING_APPEAL_OPEN': 'اعتراض مفتوح · مستبعد مؤقتًا',
        'RATING_REVIEW_SOURCE_UNVERIFIED': 'تعذر التحقق من مصدر المراجعة',
        'RATING_REVIEW_EVENT_UNVERIFIED': 'سجل إجراء المراجعة يحتاج تحققًا',
        'RATING_REVIEW_STATE_UNVERIFIED': 'حالة المراجعة تحتاج تحققًا',
        'RATING_DECISION_UNVERIFIED': 'قرار المراجعة يحتاج تحققًا',
        'RATING_INDEX_SOURCE_CHANGED': 'تغير المصدر؛ أُوقف احتساب التقييم',
        'RATING_ORDER_SOURCE_UNVERIFIED': 'تعذر مطابقة التقييم بالطلب',
        'ACCEPTED': 'عرض مقبول',
        'DECLINED': 'عرض مرفوض',
        'EXPIRED_DELIVERED': 'انتهت المهلة بعد ظهور العرض',
        'FULFILLED': 'تسليم مكتمل',
        'FULFILLED_RETURN': 'إرجاع مؤكد',
        'DRIVER_FAILURE': 'عدم إكمال بقرار مراجعة',
        'EXCLUDED_NO_FAULT': 'حالة معذورة مستبعدة',
        'REVIEW': 'قيد المراجعة · مستبعد من النسبة',
        'IN_PROGRESS': 'قيد التنفيذ · مستبعد من النسبة',
        'EXCLUDED': 'مستبعد من النسبة',
        'ON_TIME': 'ضمن الموعد الأصلي',
        'LATE_OBSERVED': 'تجاوز الموعد المسجل · دون إسناد مسؤولية',
        'ORIGINAL_TARGET_UNAVAILABLE': 'لا يوجد موعد أصلي محفوظ لهذه المحاولة',
        'ORIGINAL_TARGET_INVALID': 'تعذر التحقق من الموعد الأصلي',
        'ASSIGNMENT_CHANGED': 'تغيرت محاولة الإسناد',
        'NOT_DELIVERED': 'هذه المحاولة لم تنته بتسليم للزبون',
        'AWAITING_COMPLETION': 'بانتظار انتهاء الرحلة',
        'COMPLETION_UNVERIFIED': 'تأكيد الإكمال غير مكتمل',
        'SERVER_EVENTS_INCOMPLETE': 'أوقات مراحل الرحلة غير مكتملة',
        'INVALID_EVENT_SEQUENCE': 'تسلسل الأوقات يحتاج مراجعة',
        'PICKUP_DELAY_REQUIRES_REVIEW':
            'تأخر الاستلام؛ يلزم تحديد سبب الانتظار',
        'STORE_ARRIVAL_AFTER_TARGET': 'الوصول للمطعم بعد الموعد الأصلي والسماح',
        'CUSTOMER_ARRIVAL_AFTER_TARGET':
            'الوصول للزبون بعد الموعد الأصلي والسماح',
        'TIMING_SOURCE_CHANGED': 'تغيرت بيانات الرحلة؛ يلزم تجديد المراجعة',
        'TIMING_APPEAL_OPEN': 'اعتراض قيد المراجعة؛ مستبعد من النسبة',
        'TIMING_REVIEW_PENDING': 'بانتظار قرار مراجعة التأخير',
        'TIMING_DECISION_UNVERIFIED': 'تعذر التحقق من قرار المراجعة',
        'VERIFIED_DELAY_EXCUSED': 'تأخير معذور بقرار موثق؛ مستبعد من النسبة',
        'REVIEW_CONFIRMED_LATE': 'تأخير مؤكد بعد مراجعة الأدلة',
        'WITHIN_ORIGINAL_TARGETS': 'الوصول ضمن الموعدين الأصليين والسماح',
      }[value] ??
      'بانتظار بيانات موثقة';

  String _baghdadTime(dynamic value) {
    final at =
        DateTime.tryParse('$value')?.toUtc().add(const Duration(hours: 3));
    if (at == null) return 'وقت غير متاح';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${at.year}/${two(at.month)}/${two(at.day)} · ${two(at.hour)}:${two(at.minute)} بتوقيت بغداد';
  }

  void _showDetails(String title, String? key, {required String description}) {
    final details = _metrics?.data['details'];
    final raw = details is Map ? details[key] : null;
    final events = raw is List ? raw.whereType<Map>().toList() : <Map>[];
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
                child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * .8,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                              child: Row(children: [
                                Expanded(
                                    child: Text('تفاصيل $title',
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF00296B)))),
                                IconButton(
                                    tooltip: 'إغلاق التفاصيل',
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close))
                              ])),
                          Expanded(
                              child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            children: [
                              Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFF4F6FA),
                                      borderRadius: BorderRadius.circular(16)),
                                  child: Text(description,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.8,
                                          color: Color(0xFF344054)))),
                              if (key != null) ...[
                                const SizedBox(height: 24),
                                const Text('الأحداث ضمن العينة',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _navy)),
                                const SizedBox(height: 12),
                                if (events.isEmpty)
                                  const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 20),
                                      child: Text(
                                          'لا توجد أحداث موثقة ضمن هذه العينة.',
                                          style: TextStyle(color: _muted))),
                                for (final e in events) ...[
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(_eventLabel(e['status']),
                                                style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: _navy)),
                                            const SizedBox(height: 6),
                                            Text(_baghdadTime(e['occurredAt']),
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: _muted)),
                                            if (e['stars'] is int)
                                              Text('${e['stars']} من 5',
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      height: 1.7)),
                                            if (e['orderNumber'] is String)
                                              Text('الطلب ${e['orderNumber']}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      height: 1.7)),
                                            if (e['attempt'] is int)
                                              Text(
                                                  'محاولة الإسناد: ${e['attempt']}',
                                                  style: const TextStyle(
                                                      height: 1.7,
                                                      fontSize: 13)),
                                            if (e['reason'] != null)
                                              Text(_eventLabel(e['reason']),
                                                  style: const TextStyle(
                                                      height: 1.7,
                                                      color:
                                                          Color(0xFF475467))),
                                            if (e['targets'] is Map) ...[
                                              Text(
                                                  'موعد المطعم الأصلي: ${_baghdadTime(e['targets']['pickupTargetAt'])}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      height: 1.7)),
                                              Text(
                                                  'موعد الزبون الأصلي: ${_baghdadTime(e['targets']['customerTargetAt'])}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      height: 1.7)),
                                            ],
                                          ])),
                                  const Divider(
                                      height: 1, color: Color(0xFFEAECF0)),
                                ],
                              ],
                            ],
                          )),
                        ])))));
  }

  @override
  Widget build(BuildContext context) {
    final count = _sample('activity', 'accepted');
    final activity = _metrics?.data['activity'];
    final activityPartial =
        activity is Map && activity['coverageComplete'] != true;
    final ratingCount = _metrics?.customerRatingCount ?? 0;
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          appBar: AppBar(
              title: const Text('أدائي'),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              actions: [
                IconButton(
                    tooltip: 'تحديث الأداء',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh))
              ]),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const Text('نظرة على أدائك',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: _navy)),
                        const SizedBox(height: 6),
                        const Text('مؤشراتك باختصار، والتفاصيل بلمسة.',
                            style: TextStyle(
                                color: _muted, fontSize: 14, height: 1.5)),
                        const SizedBox(height: 20),
                        if (_metrics == null)
                          Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('تعذر تحديث المؤشرات',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: _navy)),
                                    const SizedBox(height: 6),
                                    const Text(
                                        'لا توجد بيانات حديثة للعرض. حاول التحديث مجددًا.',
                                        style: TextStyle(
                                            color: _muted, height: 1.6)),
                                    TextButton(
                                        onPressed: _load,
                                        child: const Text('إعادة المحاولة')),
                                  ])),
                        Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: const Color(0xFFEAECF0))),
                            child: Column(children: [
                              _rateRow(
                                  'معدل القبول',
                                  'acceptanceRate',
                                  'acceptance',
                                  'عرضًا موثقًا',
                                  Icons.touch_app_outlined,
                                  _acceptanceDescription),
                              const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: Color(0xFFEAECF0)),
                              _rateRow(
                                  'معدل الإكمال',
                                  'completionRate',
                                  'completion',
                                  'التزامًا محسومًا',
                                  Icons.task_alt_outlined,
                                  _completionDescription),
                              const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: Color(0xFFEAECF0)),
                              _rateRow(
                                  'الالتزام بالوقت',
                                  'onTimeRate',
                                  'punctuality',
                                  'رحلة مؤهلة',
                                  Icons.schedule_outlined,
                                  _punctualityDescription),
                              const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: Color(0xFFEAECF0)),
                              _metricRow(
                                  title: 'تقييمات العملاء',
                                  value: ratingCount > 0
                                      ? _metrics!.customerRating!
                                          .toStringAsFixed(1)
                                      : '—',
                                  subtitle: _ratingWindow?['status'] ==
                                          'UNAVAILABLE'
                                      ? 'تعذر تحديث نافذة التقييمات'
                                      : _ratingWindow == null
                                          ? 'كامل السجل · $ratingCount تقييمًا'
                                          : 'آخر 100 تقييم صالح · $ratingCount محتسب',
                                  status: _ratingWindow?['status'] as String?,
                                  detailKey: 'rating',
                                  icon: Icons.star_outline_rounded,
                                  description: _ratingDescription),
                              const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: Color(0xFFEAECF0)),
                              _metricRow(
                                  title: 'نشاط آخر 30 يومًا',
                                  value: count?.toString() ?? '—',
                                  subtitle: 'عروض مقبولة خلال الفترة',
                                  icon: Icons.calendar_month_outlined,
                                  description: _activityDescription,
                                  status: count != null && activityPartial
                                      ? 'حد أدنى · قراءة جزئية'
                                      : null),
                            ])),
                        const SizedBox(height: 12),
                        const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.info_outline_rounded,
                                      size: 16, color: _muted)),
                              SizedBox(width: 7),
                              Expanded(
                                  child: Text(
                                      'مبدئي: النسبة مبنية على البيانات المؤكدة، وبعض السجل ناقص أو قيد المراجعة.',
                                      style: TextStyle(
                                          color: _muted,
                                          fontSize: 12,
                                          height: 1.6))),
                            ]),
                        const SizedBox(height: 24),
                        Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border:
                                    Border.all(color: const Color(0xFFEAECF0))),
                            child: Theme(
                                data: Theme.of(context)
                                    .copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  key:
                                      const PageStorageKey('performance-guide'),
                                  iconColor: _navy,
                                  collapsedIconColor: _navy,
                                  leading: const Icon(Icons.menu_book_outlined,
                                      color: _navy),
                                  title: const Text('كيف تُحسب مؤشراتك؟',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: _navy)),
                                  subtitle: const Text('التعريفات والاستثناءات',
                                      style: TextStyle(
                                          fontSize: 12, color: _muted)),
                                  childrenPadding:
                                      const EdgeInsets.fromLTRB(20, 12, 20, 0),
                                  children: [
                                    _guideItem('معدل القبول',
                                        'نسبة العروض التي قبلتها إلى آخر 100 عرض مؤهل أو المتاح منها. الرفض وانتهاء المهلة بعد إثبات ظهور العرض يُحسبان عدم قبول. العروض المسحوبة أو غير المؤكدة مستبعدة.'),
                                    _guideItem('معدل الإكمال',
                                        'نسبة الالتزامات المنجزة، بما فيها الإرجاع المؤكد، إلى الالتزامات المحسومة في آخر 100 قبول مؤهل أو المتاح منها. الطلب الجاري أو المعذور أو قيد المراجعة لا يُحسب إخفاقًا.'),
                                    _guideItem('الالتزام بالوقت',
                                        'الوصول للمطعم والزبون ضمن الموعد الأصلي لكل محاولة، مع سماح 5 دقائق. الرحلات القديمة دون موعد محفوظ أو أوقات مكتملة مستبعدة. التأخير المحتمل بسبب انتظار الاستلام يبقى للمراجعة، وتجاوز الموعد وحده لا يثبت مسؤوليتك.'),
                                    _guideItem('تقييمات العملاء',
                                        'متوسط آخر 100 تقييم صالح من العملاء كحد أقصى. تُستبعد المراجعات المفتوحة والتقييمات المستبعدة وتُملأ العينة من الأقدم. تقييم كامل السجل في ملفك قد يختلف. لا نفترض نجومًا عند غياب العينة.'),
                                    _guideItem('نشاط آخر 30 يومًا',
                                        'عدد العروض المقبولة خلال آخر 30 يومًا، وليس عدد الرحلات المكتملة أو ساعات العمل. إذا كانت القراءة جزئية، فالعدد حد أدنى وليس إجماليًا نهائيًا.'),
                                    _guideItem('استقبال الطلبات',
                                        'يعتمد أيضًا على اعتماد الحساب والموقع والتوفر وكفاية ضمان الطلب. هذه الصفحة لا تؤكد أهلية عرض معين، ولا يضيف مؤشر الوقت أو النشاط عقوبة تلقائية.'),
                                  ],
                                ))),
                        if (_metrics?.updatedAt != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: Text(
                                  'آخر تحديث: ${_baghdadTime(_metrics!.updatedAt!.toIso8601String())}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: _muted,
                                      fontSize: 11,
                                      height: 1.5))),
                      ]),
                ),
        ));
  }
}
