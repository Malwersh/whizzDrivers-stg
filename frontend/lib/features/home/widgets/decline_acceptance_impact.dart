import 'package:flutter/material.dart';

/// Estimate using the same published, verified last-100 window as dispatch.
class DeclineAcceptanceEstimate {
  final double? current;
  final double? after;
  const DeclineAcceptanceEstimate(this.current, this.after);
  static DeclineAcceptanceEstimate read(Map<String, dynamic>? data,
      {required String offerId, required DateTime sentAt}) {
    final rate = data?['acceptanceRate'];
    final current =
        rate is num && rate >= 0 && rate <= 1 ? rate.toDouble() : null;
    final a = data?['acceptance'];
    final projection = data?['projection'];
    final details = data?['details'];
    final events = details is Map ? details['acceptance'] : null;
    if (projection is! Map ||
        projection['status'] != 'CURRENT' ||
        a is! Map ||
        a['windowComplete'] != true ||
        events is! List ||
        a['sampleSize'] is! int ||
        a['accepted'] is! int) {
      return DeclineAcceptanceEstimate(current, null);
    }
    final size = a['sampleSize'] as int, accepted = a['accepted'] as int;
    if (size < 0 ||
        size > 100 ||
        accepted < 0 ||
        accepted > size ||
        events.length != size ||
        events.any((e) => e is! Map || e['offerId'] == offerId)) {
      return DeclineAcceptanceEstimate(current, null);
    }
    if (size < 100)
      return DeclineAcceptanceEstimate(current, accepted / (size + 1));
    if (events.any((e) =>
        e['sentAt'] is! String ||
        DateTime.tryParse(e['sentAt']) == null ||
        !['ACCEPTED', 'DECLINED', 'EXPIRED_DELIVERED'].contains(e['status']))) {
      return DeclineAcceptanceEstimate(current, null);
    }
    final window = events.map((e) => Map<String, dynamic>.from(e)).toList()
      ..add({
        'offerId': offerId,
        'sentAt': sentAt.toUtc().toIso8601String(),
        'status': 'DECLINED'
      });
    window.sort((a, b) {
      final order =
          DateTime.parse(b['sentAt']).compareTo(DateTime.parse(a['sentAt']));
      return order != 0
          ? order
          : '${b['offerId']}'.compareTo('${a['offerId']}');
    });
    final next =
        window.take(100).where((e) => e['status'] == 'ACCEPTED').length / 100;
    return DeclineAcceptanceEstimate(current, next);
  }
}

class DeclineAcceptanceImpact extends StatelessWidget {
  final String offerId;
  final DateTime sentAt;
  final Map<String, dynamic>? snapshot;
  const DeclineAcceptanceImpact(
      {super.key,
      required this.offerId,
      required this.sentAt,
      required this.snapshot});
  String rate(double? value) =>
      value == null ? '—' : '${(value * 100).toStringAsFixed(1)}٪';
  @override
  Widget build(BuildContext context) {
    final estimate = DeclineAcceptanceEstimate.read(snapshot,
        offerId: offerId, sentAt: sentAt);
    return Column(children: [
      if (estimate.current != null || estimate.after != null)
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Expanded(
                  child: _value('معدل القبول الحالي', rate(estimate.current))),
              const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF64748B), size: 20),
              Expanded(child: _value('بعد تأكيد الرفض', rate(estimate.after))),
            ])),
      const SizedBox(height: 10),
      Text(
          estimate.after == null
              ? 'تعذر تحميل تقدير معدل القبول الآن. يمكنك متابعة قرارك؛ لا يُسجل الرفض إلا عند التأكيد.'
              : 'تقدير وفق آخر ١٠٠ عرض مؤهل. تُحدّث النسبة النهائية بعد تسجيل قرارك، وقد تتغير إذا وصلت استجابات أخرى.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 12, height: 1.5, color: Color(0xFF64748B))),
    ]);
  }

  Widget _value(String label, String value) => Column(children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
        const SizedBox(height: 6),
        Text(value,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: Color(0xFF00296B))),
      ]);
}
