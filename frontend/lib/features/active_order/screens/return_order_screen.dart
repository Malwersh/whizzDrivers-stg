import '../widgets/active_trip_summary.dart';
import 'return_continuation_screen.dart';
import '../services/return_continuation_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../more/screens/live_chat_screen.dart';
import 'dart:async';
import 'delivery_attempt_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/riverpod/active_order_provider.dart';
import '../services/order_persistence_service.dart';
import 'package:flutter/material.dart';
import '../models/active_order_model.dart';
import '../services/active_order_service.dart';
import '../services/financial_order_actions.dart';

class ReturnOrderScreen extends StatefulWidget {
  final ActiveOrder order;
  final bool asSheet;
  final Future<ActiveOrder> Function(String)? load;
  final FinancialOrderActions? actions;
  final Future<void> Function(String)? onFinished;
  final Future<Map<String, dynamic>> Function()? locate;
  const ReturnOrderScreen(
      {super.key,
      required this.order,
      this.asSheet = false,
      this.load,
      this.actions,
      this.onFinished,
      this.locate});
  @override
  State<ReturnOrderScreen> createState() => _ReturnOrderScreenState();
}

class _ReturnOrderScreenState extends State<ReturnOrderScreen>
    with WidgetsBindingObserver {
  Timer? poll;
  ActiveOrder? current;
  String? error;
  bool busy = false;
  int generation = 0;
  String reason = 'CUSTOMER_UNREACHABLE';
  bool noCash = false;
  late final actions = widget.actions ?? FinancialOrderActions();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    poll = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!busy &&
          (current?.isReturning == true || current == null) &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed)) {
        refresh(silent: true);
      }
    });
    refresh();
  }

  @override
  void dispose() {
    poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !busy &&
        current?.status != 'returned') refresh();
  }

  Future<void> finish() async {
    final value = current;
    if (busy || value?.status != 'returned') return;
    setState(() => busy = true);
    try {
      if (widget.onFinished != null) {
        await widget.onFinished!(value!.orderId);
      } else {
        await OrderPersistenceService.clearActiveOrder(
            expectedOrderId: value!.orderId);
        if (!mounted) return;
        final container = ProviderScope.containerOf(context, listen: false);
        if (container.read(activeOrderProvider).order?.orderId ==
            value.orderId) {
          container.read(activeOrderProvider.notifier).clearOrder();
        }
        if (mounted) context.go('/');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void didUpdateWidget(covariant ReturnOrderScreen old) {
    super.didUpdateWidget(old);
    if (old.order.orderId != widget.order.orderId) refresh();
  }

  Future<void> refresh({bool silent = false}) async {
    final turn = ++generation;
    setState(() {
      busy = true;
      if (!silent) current = null;
      error = null;
    });
    try {
      final value = await (widget.load ??
          ActiveOrderService().getOrderById)(widget.order.orderId);
      if (!mounted || turn != generation) return;
      if (value.orderId != widget.order.orderId)
        throw Exception('تغير نطاق الطلب');
      setState(() {
        current = value;
      });
      if (widget.asSheet && value.isReturning) {
        Navigator.pop(context, value);
        return;
      }
      if (value.status == 'returned') {
        // Server-confirmed terminal state: leave automatically, preserving search preferences.
        setState(() => busy = false);
        await finish();
      }
    } catch (_) {
      if (mounted && turn == generation)
        setState(() {
          error = 'تعذر تأكيد حالة الطلب. أعد التحميل.';
        });
    } finally {
      if (mounted && turn == generation)
        setState(() {
          busy = false;
        });
    }
  }

  Future<void> act(String action) async {
    final order = current;
    if (busy || order?.financialAssignment == null) return;
    final turn = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      Map<String, dynamic>? position;
      if (action == 'arrive-return') position = await locate();
      if (action == 'request-return') {
        try {
          position = await locate();
        } catch (_) {
          /* The report remains available; automatic authorization will be ineligible. */
        }
      }
      await actions.send(order!.orderId, action, order.financialAssignment!,
          reason: reason, position: position);
      if (!mounted || turn != generation) return;
      await refresh();
    } catch (_) {
      if (mounted && turn == generation)
        setState(() {
          current = null;
          error =
              'لم تتأكد العملية. تحقق من الموقع والاتصال، ثم حدّث الطلب قبل إعادة المحاولة.';
          busy = false;
        });
    }
  }

  Future<Map<String, dynamic>> locate() async {
    if (widget.locate != null) return widget.locate!();
    if (!await Geolocator.isLocationServiceEnabled())
      throw Exception('فعّل الموقع لتوثيق الوصول');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever)
      throw Exception('اسمح بالوصول للموقع أو تواصل مع الدعم');
    final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
    return {
      'latitude': p.latitude,
      'longitude': p.longitude,
      'accuracyMeters': p.accuracy,
      'capturedAt': p.timestamp.toUtc().toIso8601String()
    };
  }

  Future<void> reportObstacle() async {
    if (busy || current == null) return;
    String selected = 'BRANCH_CLOSED', note = '';
    final approved = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, change) => AlertDialog(
                    title: const Text('تعذّر تسليم المرتجع'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selected,
                          items: const [
                            DropdownMenuItem(
                                value: 'BRANCH_CLOSED',
                                child: Text('المطعم مغلق')),
                            DropdownMenuItem(
                                value: 'AUTHORIZED_PERSON_ABSENT',
                                child: Text('لا يوجد مسؤول مخوّل')),
                            DropdownMenuItem(
                                value: 'RECEIPT_REFUSED',
                                child: Text('رفض الاستلام')),
                            DropdownMenuItem(
                                value: 'RECEIVED_WITHOUT_CONFIRMATION',
                                child: Text('استلم دون تأكيد')),
                            DropdownMenuItem(
                                value: 'OTHER', child: Text('سبب آخر'))
                          ],
                          onChanged: (v) => change(() => selected = v!)),
                      TextField(
                          maxLength: 1000,
                          decoration: const InputDecoration(
                              labelText: 'وضح ما حدث ومن تواصلت معه'),
                          onChanged: (v) => change(() => note = v)),
                      const Text(
                          'يُسجل البلاغ للمراجعة؛ لا ينهي العهدة ولا يسمح بترك الأصناف.')
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('رجوع')),
                      FilledButton(
                          onPressed: note.trim().length < 5
                              ? null
                              : () => Navigator.pop(ctx, true),
                          child: const Text('إبلاغ الدعم'))
                    ])));
    if (approved != true || !mounted) return;
    final value = current!;
    setState(() => busy = true);
    try {
      final position = await locate();
      await actions.send(
          value.orderId, 'report-return-obstacle', value.financialAssignment!,
          reason: selected,
          position: position,
          issueId: const Uuid().v4(),
          note: note.trim());
      if (mounted) {
        setState(() => busy = false);
        await refresh();
      }
    } catch (_) {
      if (mounted)
        setState(() {
          busy = false;
          error =
              'لم يتأكد تسجيل البلاغ. تحقق من وجودك قرب المطعم ودقة الموقع، ثم حدّث الحالة.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = current, state = order?.financialAssignment?['returnStatus'];
    final issue = order?.financialAssignment?['returnHandover'];
    final instructions = order?.financialAssignment?['returnInstructions'];
    final deadline = DateTime.tryParse(issue?['escalationAt'] ?? '');
    final serverNow =
        DateTime.tryParse(order?.financialAssignment?['serverNow'] ?? '');
    final remaining = deadline != null && serverNow != null
        ? deadline.difference(serverNow).inSeconds.clamp(0, 1800)
        : null;
    final content = Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
            shrinkWrap: widget.asSheet,
            padding: const EdgeInsets.all(20),
            children: [
              SelectableText(
                  'الطلب ${widget.order.orderNumber ?? widget.order.shortOrderId}',
                  style: const TextStyle(color: TripStyle.muted)),
              const SizedBox(height: 12),
              if (order?.status != 'returned')
                const Text(
                    'احتفظ بالطلب معك حتى تصلك تعليمات المعالجة. اختر سبب التعذّر وأكد حالة التحصيل.'),
              if (order?.financialAssignment?['returnId'] != null)
                OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ReturnContinuationScreen(
                                    orderId: order!.orderId,
                                    caseKey: 'CURRENT',
                                    driver: true,
                                    call: (body) => ReturnContinuationService()
                                        .call(order.orderId, body)))),
                    child: const Text('متابعة العهدة والاعتراضات')),
              if (busy) const LinearProgressIndicator(),
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: Colors.red)),
                TextButton(
                    onPressed: busy ? null : refresh,
                    child: const Text('إعادة التحميل'))
              ],
              if (order != null && order.isReturning) ...[
                Text(state == 'REQUESTED'
                    ? 'أُرسل البلاغ للإدارة. انتظر تعليمات المعالجة، ولا تتصرف بالأصناف من نفسك.'
                    : state == 'REVIEW_REQUIRED'
                        ? 'الاستلام قيد المراجعة؛ الحجز ما زال قائمًا'
                        : state == 'ARRIVED_AT_BRANCH'
                            ? 'وصلت للمطعم — بانتظار تأكيد استلام المرتجع'
                            : 'أعد الأصناف إلى الفرع'),
                if (state == 'RETURNING')
                  FilledButton(
                      onPressed: busy ? null : () => act('arrive-return'),
                      child: const Text('وصلت إلى الفرع ومعي الأصناف')),
                if (state == 'ARRIVED_AT_BRANCH') ...[
                  const Text('سلّم الأصناف للمسؤول، ولا تتركها دون استلام.'),
                  if (issue == null)
                    OutlinedButton(
                        onPressed: busy ? null : reportObstacle,
                        child: const Text('تعذّر تسليم المرتجع')),
                  if (issue != null) ...[
                    const Text('سُجل البلاغ — بانتظار تعليمات الدعم'),
                    if (remaining != null)
                      Text(remaining > 0
                          ? 'التصعيد خلال ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}'
                          : 'انتهت مهلة الانتظار؛ يلزم تدخل عاجل من الإدارة.'),
                    const Text(
                        'لا يعني انتهاء المهلة تأكيد استلام المطعم أو السماح بالمغادرة أو تحرير الضمان.')
                  ],
                  if (instructions != null)
                    Text('تعليمات الدعم: ${instructions['text']}'),
                  TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LiveChatScreen())),
                      child: const Text('التواصل مع الدعم')),
                ],
              ] else if (order != null &&
                  ['picked_up', 'heading_to_customer', 'arrived_at_customer']
                      .contains(order.status)) ...[
                DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: reason,
                    items: const [
                      DropdownMenuItem(
                          value: 'CUSTOMER_UNREACHABLE',
                          child: Text('تعذر الوصول للزبون')),
                      DropdownMenuItem(
                          value: 'CUSTOMER_REFUSED',
                          child: Text('الزبون رفض الاستلام')),
                      DropdownMenuItem(
                          value: 'DELIVERY_BLOCKED',
                          child: Text('تعذر إكمال التوصيل')),
                      DropdownMenuItem(value: 'OTHER', child: Text('سبب آخر')),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                              reason = v!;
                            })),
                CheckboxListTile(
                    value: noCash,
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                              noCash = v ?? false;
                            }),
                    title: const Text('لم أستلم أي مبلغ نقدي من الزبون')),
                const Text(
                    'إذا استلمت نقدًا، تواصل مع الدعم للمراجعة المالية.'),
                FilledButton(
                    onPressed: busy || !noCash
                        ? null
                        : () async {
                            if (reason == 'CUSTOMER_UNREACHABLE' &&
                                order.financialAssignment?[
                                        'exceptionPolicyVersion'] !=
                                    null) {
                              final ready = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          DeliveryAttemptScreen(order: order)));
                              if (!mounted || ready != true) return;
                            }
                            await act('request-return');
                          },
                    child: Text(reason == 'CUSTOMER_UNREACHABLE' &&
                            order.financialAssignment?[
                                    'exceptionPolicyVersion'] !=
                                null
                        ? 'توثيق الوصول والتواصل'
                        : order.financialAssignment?[
                                    'exceptionPolicyVersion'] !=
                                null
                            ? 'إرسال بلاغ وطلب تعليمات'
                            : 'بدء العودة مع بقاء الحجز')),
              ] else if (order?.status == 'returned') ...[
                const Text('أكد الفرع الاستلام وانتهت العودة'),
                FilledButton(
                    onPressed: busy ? null : finish,
                    child: const Text('العودة للرئيسية')),
              ] else if (order != null)
                const Text('هذه الحالة لا تسمح ببدء عودة'),
            ]));
    final header = Row(children: [
      const Expanded(
          child: Text('تعذّر تسليم الطلب',
              style: TextStyle(
                  color: TripStyle.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.bold))),
      IconButton(
          tooltip: 'تحديث الحالة',
          onPressed: busy ? null : refresh,
          icon: const Icon(Icons.refresh, color: TripStyle.blue)),
      IconButton(
          tooltip: 'العودة إلى الطلب',
          onPressed: busy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: TripStyle.muted)),
    ]);
    final page = widget.asSheet
        ? Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .9),
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: SafeArea(
                top: false,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(height: 10),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: const Color(0xFFDDE5EF),
                          borderRadius: BorderRadius.circular(8))),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                      child: header),
                  Flexible(child: content),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: OutlinedButton.icon(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('العودة إلى الطلب'),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48)))),
                ])))
        : Scaffold(
            backgroundColor: TripStyle.background,
            appBar: AppBar(title: const Text('معالجة تعذّر التسليم'), actions: [
              IconButton(
                  onPressed: busy ? null : refresh,
                  icon: const Icon(Icons.refresh))
            ]),
            body: content);
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: TripStyle.blue, secondary: TripStyle.yellow),
              appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: TripStyle.ink,
                  elevation: 0),
              inputDecorationTheme: InputDecorationTheme(
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFDDE5EF)))),
              filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                      backgroundColor: TripStyle.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)))),
              outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: TripStyle.blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)))),
            ),
            child: PopScope(canPop: !busy, child: page)));
  }
}

Future<void> showDeliveryFailureSheet(
  BuildContext context,
  ActiveOrder order, {
  Future<ActiveOrder> Function(String)? load,
  FinancialOrderActions? actions,
  Future<Map<String, dynamic>> Function()? locate,
}) async {
  final returning = await showModalBottomSheet<ActiveOrder>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => ReturnOrderScreen(
          order: order,
          asSheet: true,
          load: load,
          actions: actions,
          locate: locate));
  if (returning != null && returning.isReturning && context.mounted) {
    ProviderScope.containerOf(context, listen: false)
        .read(activeOrderProvider.notifier)
        .updateOrder(returning);
    await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ReturnOrderScreen(
            order: returning, load: load, actions: actions, locate: locate)));
  }
}
