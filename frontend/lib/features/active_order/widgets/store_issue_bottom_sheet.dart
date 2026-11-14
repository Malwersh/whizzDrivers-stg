import 'package:flutter/material.dart';
import 'active_trip_summary.dart';

class StoreIssueBottomSheet extends StatefulWidget {
  const StoreIssueBottomSheet(
      {super.key, required this.orderId, required this.onSubmit});
  final String orderId;
  final Future<void> Function(String issueType, String? notes) onSubmit;
  @override
  State<StoreIssueBottomSheet> createState() => _StoreIssueBottomSheetState();
}

class _StoreIssueBottomSheetState extends State<StoreIssueBottomSheet> {
  String? selected, error;
  bool submitting = false;
  final notes = TextEditingController();
  static const options = [
    (
      'ItemUnavailable',
      'صنف غير متوفر',
      'أحد الأصناف المطلوبة غير متاح',
      Icons.inventory_2_outlined
    ),
    (
      'StoreClosed',
      'المتجر مغلق',
      'تعذر الاستلام لأن المتجر مغلق',
      Icons.storefront_outlined
    ),
    (
      'LongDelay',
      'تأخير في تجهيز الطلب',
      'الطلب غير جاهز والاستلام متأخر',
      Icons.schedule_outlined
    ),
    (
      'WrongOrder',
      'مشكلة في محتويات الطلب',
      'أصناف مختلفة أو طلب غير مطابق',
      Icons.receipt_long_outlined
    ),
    ('Other', 'مشكلة أخرى', 'أضف التفاصيل لتوضيح ما حدث', Icons.more_horiz),
  ];
  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (submitting || selected == null) return;
    if (selected == 'Other' && notes.text.trim().isEmpty) {
      setState(() => error = 'اكتب تفاصيل المشكلة قبل إرسال البلاغ');
      return;
    }
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await widget.onSubmit(
          selected!, notes.text.trim().isEmpty ? null : notes.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() {
          submitting = false;
          error = 'لم يتأكد حفظ البلاغ. تحقق من الاتصال وأعد المحاولة.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Directionality(
        textDirection: TextDirection.rtl,
        child: PopScope(
            canPop: !submitting,
            child: Padding(
                padding: EdgeInsets.only(bottom: inset),
                child: Container(
                  height: (MediaQuery.sizeOf(context).height * .9 - inset)
                      .clamp(260.0, 1000.0),
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28))),
                  child: Column(children: [
                    const SizedBox(height: 10),
                    Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: const Color(0xFFD7DFEA),
                            borderRadius: BorderRadius.circular(8))),
                    Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: Row(children: [
                          Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFEDF3FA),
                                  borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.report_outlined,
                                  color: TripStyle.blue)),
                          const SizedBox(width: 12),
                          const Expanded(
                              child: Text('مشكلة في الاستلام',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 21,
                                      color: TripStyle.ink))),
                          IconButton(
                              tooltip: 'إغلاق',
                              onPressed: submitting
                                  ? null
                                  : () => Navigator.pop(context, false),
                              icon: const Icon(Icons.close,
                                  color: TripStyle.muted))
                        ])),
                    Expanded(
                        child: ListView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            children: [
                          const Text('ما الذي يمنع استلام الطلب؟',
                              style: TextStyle(color: TripStyle.muted)),
                          const SizedBox(height: 12),
                          ...options.map((o) {
                            final active = selected == o.$1;
                            return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Material(
                                    color: active
                                        ? const Color(0xFFEDF3FA)
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                            color: active
                                                ? TripStyle.blue
                                                : const Color(0xFFE0E7F0))),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                        onTap: submitting
                                            ? null
                                            : () => setState(() {
                                                  selected = o.$1;
                                                  error = null;
                                                }),
                                        child: Padding(
                                            padding: const EdgeInsets.all(14),
                                            child: Row(children: [
                                              Icon(o.$4, color: TripStyle.blue),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    Text(o.$2,
                                                        style: const TextStyle(
                                                            color:
                                                                TripStyle.ink,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 15)),
                                                    const SizedBox(height: 3),
                                                    Text(o.$3,
                                                        style: const TextStyle(
                                                            color:
                                                                TripStyle.muted,
                                                            fontSize: 12))
                                                  ])),
                                              const SizedBox(width: 8),
                                              Icon(
                                                  active
                                                      ? Icons.check_circle
                                                      : Icons
                                                          .radio_button_unchecked,
                                                  color: active
                                                      ? TripStyle.blue
                                                      : const Color(0xFFB4C1D2),
                                                  size: 21)
                                            ])))));
                          }),
                          if (selected != null) ...[
                            const SizedBox(height: 8),
                            TextField(
                                controller: notes,
                                enabled: !submitting,
                                minLines: 2,
                                maxLines: 4,
                                maxLength: 1000,
                                decoration: InputDecoration(
                                    labelText: selected == 'Other'
                                        ? 'تفاصيل المشكلة (مطلوبة)'
                                        : 'تفاصيل إضافية (اختيارية)',
                                    alignLabelWithHint: true,
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14))))
                          ],
                          const SizedBox(height: 12),
                          Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7D9),
                                  borderRadius: BorderRadius.circular(14)),
                              child: const Text(
                                  'اختر المشكلة التي واجهتك، وأضف تفاصيل تساعدنا على متابعتها.',
                                  style: TextStyle(
                                      color: TripStyle.ink,
                                      fontSize: 12,
                                      height: 1.6))),
                          if (error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(error!,
                                    style: const TextStyle(
                                        color: Color(0xFFAF2536)))),
                        ])),
                    Container(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        decoration: const BoxDecoration(
                            border: Border(
                                top: BorderSide(color: Color(0xFFE3E9F1)))),
                        child: SafeArea(
                            top: false,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FilledButton(
                                      onPressed: submitting || selected == null
                                          ? null
                                          : submit,
                                      style: FilledButton.styleFrom(
                                          backgroundColor: TripStyle.blue,
                                          foregroundColor: Colors.white,
                                          minimumSize:
                                              const Size(double.infinity, 52),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16))),
                                      child: submitting
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white))
                                          : const Text('إرسال البلاغ',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold))),
                                  TextButton(
                                      onPressed: submitting
                                          ? null
                                          : () => Navigator.pop(context, false),
                                      style: TextButton.styleFrom(
                                          foregroundColor: TripStyle.muted),
                                      child: const Text('رجوع'))
                                ]))),
                  ]),
                ))));
  }
}
