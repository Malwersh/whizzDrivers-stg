import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ReturnContinuationScreen extends StatefulWidget {
  final String orderId, caseKey;
  final bool driver;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) call;
  const ReturnContinuationScreen(
      {super.key,
      required this.orderId,
      required this.caseKey,
      required this.driver,
      required this.call});
  @override
  State<ReturnContinuationScreen> createState() =>
      _ReturnContinuationScreenState();
}

class _ReturnContinuationScreenState extends State<ReturnContinuationScreen> {
  Map<String, dynamic>? data;
  final note = TextEditingController(),
      appealReference = TextEditingController();
  final keys = <String, String>{}, conditions = <String, String>{};
  bool busy = false;
  String? message;
  String topic = 'RESPONSIBILITY';
  static const treatments = {
    'RETURN_TO_MERCHANT': 'إعادة إلى المطعم',
    'TRANSFER_TO_CUSTODIAN': 'نقل إلى عهدة الشركة',
    'DISPOSE_AUTHORIZED': 'تصرف مصرح دون إعادة تقديم',
    'INVESTIGATE_MISSING': 'مراجعة الكمية غير المحددة'
  };
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    note.dispose();
    appealReference.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final result = await widget.call({
        'action': 'READ_RETURN_CONTINUATION',
        'caseKey': data?['caseKey'] ?? widget.caseKey
      });
      if (mounted) setState(() => data = result);
    } catch (_) {
      if (mounted)
        setState(() => message =
            'تعذر تحميل القضية أو لا توجد قضية مرتبطة بحسابك لهذا الطلب. أعد التحديث.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> execute(
      String action, Map<String, dynamic> extra, String confirmation) async {
    if (busy || data == null) return;
    if (note.text.trim().length < 5) {
      setState(() => message = 'اكتب تعليلًا ومرجعًا من خمسة أحرف على الأقل.');
      return;
    }
    var acknowledged = false;
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                    title: const Text('مراجعة الإقرار'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(confirmation),
                      CheckboxListTile(
                          value: acknowledged,
                          onChanged: (v) =>
                              update(() => acknowledged = v ?? false),
                          title: const Text(
                              'أؤكد أن هذا الإقرار يطابق ما حدث فعلًا. لا يعني صرف الحقوق أو تحرير الضمان.'))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('رجوع')),
                      FilledButton(
                          onPressed: acknowledged
                              ? () => Navigator.pop(context, true)
                              : null,
                          child: const Text('حفظ الإقرار'))
                    ])));
    if (yes != true || !mounted) return;
    final body = <String, dynamic>{
      'action': action,
      'caseKey': data!['caseKey'],
      'caseId': data!['caseId'],
      'expectedVersion': data!['version'],
      'reason': note.text.trim(),
      ...extra
    };
    body['idempotencyKey'] =
        keys.putIfAbsent(jsonEncode(body), () => const Uuid().v4());
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.call(body);
      if (!mounted) return;
      setState(() => busy = false);
      await load();
      if (mounted)
        setState(() => message =
            'حُفظ الإقرار. تنفيذ الحقوق المالية ومراجعة المسؤولية مستقلان.');
    } catch (e) {
      if (mounted)
        setState(() {
          busy = false;
          message = e.toString().contains('WINDOW_EXPIRED')
              ? 'انتهت مهلة الاعتراض العادي. تبقى بلاغات السلامة والنقد للمراجعة وفق السياسة.'
              : 'لم يتأكد الحفظ. حدّث القضية قبل إعادة المحاولة؛ قد تغيرت الحالة أو يلزم إقرار الطرف الآخر.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = data?['plan'],
        lines = (plan?['lines'] as List?) ?? [],
        execution = data?['execution']?['lines'] ?? {},
        balance = data?['balance'];
    return Scaffold(
        appBar: AppBar(
            title: const Text('متابعة العهدة والاعتراضات'),
            actions: [
              IconButton(
                  onPressed: busy ? null : load,
                  icon: const Icon(Icons.refresh))
            ]),
        body: Directionality(
            textDirection: TextDirection.rtl,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              if (busy) const LinearProgressIndicator(),
              if (message != null)
                Text(message!, style: const TextStyle(color: Colors.blueGrey)),
              const Text(
                  'يُحفظ كل إقرار استلام مستقلًا؛ لا يُنشأ إقرار باسم طرف لم يسجله. لا تُنسب مسؤولية أو تُصرف أموال تلقائيًا.'),
              if (data?['taskCompleted'] == true)
                const Text(
                    'انتهت عهدة السائق؛ أي عهدة للشركة والحقوق تستمر متابعتها.'),
              if (balance != null)
                Text(
                    'المتبقي مع السائق: ${balance['driverRemainingTotal']} · مع الشركة: ${balance['companyRemainingTotal']}'),
              if (plan != null) Text('خطة المعالجة: ${plan['reason']}'),
              for (final raw in lines)
                Builder(builder: (context) {
                  final line = Map<String, dynamic>.from(raw as Map),
                      id = line['lineId'] as String,
                      state = execution[id] ?? {},
                      type = line['treatment'],
                      handover = type == 'RETURN_TO_MERCHANT'
                          ? state['handover']
                          : state['companyHandover'];
                  final canHand = widget.driver &&
                      data?['taskCompleted'] != true &&
                      state['handover'] == null &&
                      state['terminal'] == null &&
                      type != 'INVESTIGATE_MISSING' &&
                      (type != 'TRANSFER_TO_CUSTODIAN' ||
                          line['recipient'] != null);
                  final canReceive = !widget.driver &&
                      handover != null &&
                      state['terminal'] == null &&
                      ['RETURN_TO_MERCHANT', 'TRANSFER_TO_CUSTODIAN']
                          .contains(type);
                  return Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('${line['name']} — ${line['quantity']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                Text(treatments[type] ?? 'تحتاج مراجعة'),
                                if (line['recipient'] != null)
                                  Text('الأمين المحدد: ${line['recipient']}'),
                                if (state['terminal'] != null)
                                  const Text('حُفظ إثبات حسم هذه الكمية.'),
                                if (state['companyReceipt'] != null &&
                                    state['terminal'] == null)
                                  const Text(
                                      'الكمية في عهدة الشركة حتى توثيق معالجتها.'),
                                if (widget.driver &&
                                    state['handover'] != null &&
                                    state['terminal'] == null &&
                                    state['companyReceipt'] == null)
                                  const Text(
                                      'سُجل إقرارك؛ بانتظار تأكيد الطرف المختص.'),
                                if (canHand)
                                  FilledButton(
                                      onPressed: busy
                                          ? null
                                          : () => execute(
                                              'RECORD_RETURN_HANDOVER',
                                              {
                                                'lineId': id,
                                                'planId': plan['planId'],
                                                'confirmPhysicalExecution':
                                                    true,
                                                'reference': note.text
                                                    .trim()
                                                    .substring(
                                                        0,
                                                        note.text
                                                            .trim()
                                                            .length
                                                            .clamp(0, 500))
                                              },
                                              'سأسجل ${type == 'DISPOSE_AUTHORIZED' ? 'التصرف المصرح الذي نفذته' : 'التسليم الذي نفذته'} لكمية ${line['quantity']} من ${line['name']}.'),
                                      child: Text(type == 'DISPOSE_AUTHORIZED'
                                          ? 'أسجل تنفيذي التصرف المصرح'
                                          : 'أسجل تسليمي الكمية فعليًا')),
                                if (canReceive) ...[
                                  DropdownButtonFormField<String>(
                                      initialValue: conditions[id],
                                      decoration: const InputDecoration(
                                          labelText:
                                              'حالة الكمية المستلمة فعليًا'),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'SEALED_INTACT',
                                            child: Text('مغلفة وسليمة')),
                                        DropdownMenuItem(
                                            value: 'INTACT_NOT_RESALEABLE',
                                            child: Text(
                                                'سليمة ظاهريًا دون تصريح إعادة تقديم')),
                                        DropdownMenuItem(
                                            value: 'DAMAGED',
                                            child: Text('تالفة')),
                                        DropdownMenuItem(
                                            value: 'SPOILED',
                                            child: Text('مشكلة سلامة')),
                                        DropdownMenuItem(
                                            value: 'UNKNOWN',
                                            child: Text('تحتاج مراجعة'))
                                      ],
                                      onChanged: busy
                                          ? null
                                          : (v) => setState(() {
                                                if (v != null)
                                                  conditions[id] = v;
                                              })),
                                  FilledButton(
                                      onPressed: busy || conditions[id] == null
                                          ? null
                                          : () => execute(
                                              'RECEIVE_RETURN_REMAINDER',
                                              {
                                                'lineId': id,
                                                'planId': plan['planId'],
                                                'handoverId':
                                                    handover['recordId'],
                                                'condition': conditions[id],
                                                'confirmPhysicalReceipt': true,
                                                'reference': note.text
                                                    .trim()
                                                    .substring(
                                                        0,
                                                        note.text
                                                            .trim()
                                                            .length
                                                            .clamp(0, 500))
                                              },
                                              'أؤكد استلام ${line['quantity']} من ${line['name']} فعليًا، كإقرار محفوظ مستقل عن أي إقرار سابق.'),
                                      child: const Text(
                                          'أؤكد استلامي الكمية المرتبطة بالخطة')),
                                ],
                              ])));
                }),
              TextField(
                  controller: note,
                  maxLength: 2000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'تعليل الإجراء أو الاعتراض ومرجع الإثبات')),
              const Divider(),
              const Text('اعتراضاتي ومراجعتها'),
              for (final a in (data?['appeals'] as List?) ?? [])
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                            '${a['reason']}\n${a['status'] == 'OPEN' ? 'بانتظار المراجعة' : a['status'] == 'UPHELD' ? 'أُبقي القرار السابق' : 'مراجعة إضافية'}${a['decision'] != null ? '\n${a['decision']['reason']}' : ''}'))),
              if (data != null) ...[
                Text(
                    'مهلة الاعتراض العادي: ${(data!['claimPolicy']['appealSeconds'] as num) ~/ 3600} ساعة وفق السياسة المحفوظة للقضية.'),
                DropdownButtonFormField<String>(
                    initialValue: topic,
                    decoration:
                        const InputDecoration(labelText: 'موضوع الاعتراض'),
                    items: const [
                      DropdownMenuItem(
                          value: 'RESPONSIBILITY', child: Text('المسؤولية')),
                      DropdownMenuItem(value: 'CUSTODY', child: Text('العهدة')),
                      DropdownMenuItem(
                          value: 'FINANCIAL', child: Text('الحقوق المالية')),
                      DropdownMenuItem(value: 'SAFETY', child: Text('السلامة')),
                      DropdownMenuItem(value: 'CASH', child: Text('النقد'))
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() => topic = v ?? topic)),
                TextField(
                    controller: appealReference,
                    maxLength: 500,
                    decoration: const InputDecoration(
                        labelText: 'مرجع المستند أو التواصل المؤيد للاعتراض')),
                OutlinedButton(
                    onPressed: busy
                        ? null
                        : () {
                            if (appealReference.text.trim().length < 3) {
                              setState(() =>
                                  message = 'اكتب مرجعًا واضحًا للاعتراض.');
                              return;
                            }
                            execute(
                                'OPEN_CASE_APPEAL',
                                {
                                  'topic': topic,
                                  'reference': appealReference.text.trim()
                                },
                                'سيسجل الاعتراض للمراجعة، ولن يعيد صرف حقوق أو يثبت مسؤولية بمجرده.');
                          },
                    child: const Text('تسجيل اعتراض للمراجعة')),
              ],
            ])));
  }
}
