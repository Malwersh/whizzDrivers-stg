import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/driver_quality_service.dart';

class DriverQualityScreen extends StatefulWidget {
  final DriverQualityService? service;
  const DriverQualityScreen({super.key, this.service});
  @override
  State<DriverQualityScreen> createState() => _DriverQualityScreenState();
}

class _DriverQualityScreenState extends State<DriverQualityScreen> {
  static const navy = Color(0xFF00296B);
  late final DriverQualityService _service;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true, _complete = false;
  String? _error;
  static const labels = {
    'ORDER_DAMAGE': 'تلف الأصناف',
    'MISSING_ITEMS': 'أصناف ناقصة',
    'CONDUCT': 'السلوك والتعامل',
    'ROAD_SAFETY': 'السلامة المرورية',
    'PERSONAL_SAFETY': 'سلامة الأشخاص',
    'OTHER': 'ملاحظة أخرى',
    'NORMAL': 'اعتيادي',
    'HIGH': 'مرتفع',
    'URGENT': 'عاجل',
    'OPEN': 'قيد المراجعة',
    'APPEAL_OPEN': 'اعتراضك قيد المراجعة',
    'RESOLVED': 'اكتملت المراجعة',
    'VERIFICATION_PENDING': 'جارٍ التحقق من السجل',
    'SUBSTANTIATED': 'واقعة مثبتة بعد المراجعة',
    'NOT_SUBSTANTIATED': 'لم تثبت مسؤوليتك',
    'PENDING_REVIEW': 'بانتظار أدلة إضافية'
  };
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DriverQualityService();
    _load();
  }

  @override
  void dispose() {
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  String _message(Object error) {
    final code = error is DriverQualityException ? error.code : '';
    return code == 'UNAUTHORIZED'
        ? 'أعد تسجيل الدخول لعرض ملاحظاتك.'
        : code == 'DRIVER_QUALITY_APPEAL_CONFLICT' ||
                code == 'DRIVER_QUALITY_REVIEW_CONFLICT'
            ? 'تغيرت حالة القضية. حدّث القائمة قبل المحاولة مجددًا.'
            : 'تعذر تأكيد النتيجة. أعد المحاولة أو حدّث القائمة للتحقق.';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
    });
    try {
      final data = await _service.load();
      if (!mounted) return;
      if (data['schemaVersion'] != 1 ||
          data['items'] is! List ||
          data['coverageComplete'] is! bool) {
        throw const DriverQualityException('QUALITY_UNAVAILABLE');
      }
      final items = (data['items'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      if (items.any((i) =>
          i['incidentId'] is! String ||
          i['orderId'] is! String ||
          i['version'] is! int ||
          i['canAppeal'] is! bool)) {
        throw const DriverQualityException('QUALITY_UNAVAILABLE');
      }
      setState(() {
        _items = items;
        _complete = data['coverageComplete'] == true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _appeal(Map<String, dynamic> item) async {
    final sent = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _QualityAppealSheet(service: _service, item: item));
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل اعتراضك للمراجعة.')));
      await _load();
    }
  }

  Widget _card(Map<String, dynamic> item) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEAECF0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(labels[item['category']] ?? 'ملاحظة جودة أو سلامة',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
        const SizedBox(height: 8),
        Text(
            '${item['orderNumber'] ?? 'طلب سابق'} · ${labels[item['state']] ?? 'قيد المراجعة'}',
            style: const TextStyle(color: Color(0xFF667085), height: 1.6)),
        if (item['decision'] != null) ...[
          const Divider(height: 24),
          Text(labels[item['decision']] ?? 'قيد المراجعة',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (item['decisionReason'] is String)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(item['decisionReason'],
                    style: const TextStyle(height: 1.6)))
        ],
        if (item['canAppeal'] == true)
          Padding(
              padding: const EdgeInsets.only(top: 14),
              child: OutlinedButton(
                  onPressed: () => _appeal(item),
                  child: const Text('اعتراض على القرار'))),
      ]));
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          appBar: AppBar(
              title: const Text('الجودة والسلامة'),
              foregroundColor: navy,
              backgroundColor: Colors.white,
              actions: [
                IconButton(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'تحديث الملاحظات')
              ]),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(_error!, textAlign: TextAlign.center),
                            TextButton(
                                onPressed: _load,
                                child: const Text('إعادة المحاولة'))
                          ])))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          children: [
                            const Text('الملاحظات والاعتراضات',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: navy)),
                            const SizedBox(height: 10),
                            const Text(
                                'البلاغ لا يثبت مسؤوليتك وحده. يمكنك الاطلاع على القرار والاعتراض عليه. لا تغيّر هذه الصفحة تقييمك أو مستحقاتك تلقائيًا.',
                                style: TextStyle(
                                    color: Color(0xFF667085), height: 1.7)),
                            const SizedBox(height: 20),
                            if (!_complete)
                              const Padding(
                                  padding: EdgeInsets.only(bottom: 16),
                                  child: Text(
                                      'هذه النتائج تغطي جزءًا من سجل الرحلات. تواصل مع الدعم للاستفسار عن واقعة أقدم.',
                                      style: TextStyle(
                                          color: Color(0xFF667085),
                                          height: 1.6))),
                            if (_items.isEmpty)
                              Text(
                                  _complete
                                      ? 'لا توجد ملاحظات جودة أو سلامة موثقة في السجل المتاح.'
                                      : 'لا توجد ملاحظات في الجزء الذي تم تحميله.',
                                  style: const TextStyle(height: 1.7)),
                            ..._items.map(_card),
                          ]))));
}

class _QualityAppealSheet extends StatefulWidget {
  final DriverQualityService service;
  final Map<String, dynamic> item;
  const _QualityAppealSheet({required this.service, required this.item});
  @override
  State<_QualityAppealSheet> createState() => _QualityAppealSheetState();
}

class _QualityAppealSheetState extends State<_QualityAppealSheet> {
  final _reason = TextEditingController(), _keys = <String, String>{};
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final text = _reason.text.trim();
    if (text.length < 5) {
      setState(() => _error = 'اكتب سببًا واضحًا من خمسة أحرف على الأقل.');
      return;
    }
    final key = _keys.putIfAbsent(text, () => const Uuid().v4());
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.appeal({
        'action': 'APPEAL',
        'orderId': widget.item['orderId'],
        'incidentId': widget.item['incidentId'],
        'expectedVersion': widget.item['version'],
        'idempotencyKey': key,
        'reason': text
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is DriverQualityException &&
                e.code == 'UNAUTHORIZED'
            ? 'أعد تسجيل الدخول.'
            : 'تعذر تأكيد إرسال الاعتراض. أعد المحاولة بالبيانات نفسها، أو حدّث القائمة للتحقق.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('اعتراض على القرار',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00296B))),
                const SizedBox(height: 10),
                const Text(
                    'وضح ما حدث وسبب اعتراضك. سيراجعه فريق الدعم مع سجل القضية.',
                    style: TextStyle(height: 1.6)),
                const SizedBox(height: 16),
                TextField(
                    controller: _reason,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                        labelText: 'سبب الاعتراض',
                        border: OutlineInputBorder())),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!,
                          style: const TextStyle(color: Color(0xFFB42318)))),
                FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00296B),
                        foregroundColor: Colors.white),
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'جارٍ الإرسال…' : 'إرسال الاعتراض')),
              ])));
}
