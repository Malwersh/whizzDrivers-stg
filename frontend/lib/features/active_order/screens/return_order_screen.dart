import 'package:flutter/material.dart';
import '../models/active_order_model.dart';
import '../services/active_order_service.dart';
import '../services/financial_order_actions.dart';

class ReturnOrderScreen extends StatefulWidget {
  final ActiveOrder order;
  final Future<ActiveOrder> Function(String)? load;
  final FinancialOrderActions? actions;
  const ReturnOrderScreen(
      {super.key, required this.order, this.load, this.actions});
  @override
  State<ReturnOrderScreen> createState() => _ReturnOrderScreenState();
}

class _ReturnOrderScreenState extends State<ReturnOrderScreen> {
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
    refresh();
  }

  @override
  void didUpdateWidget(covariant ReturnOrderScreen old) {
    super.didUpdateWidget(old);
    if (old.order.orderId != widget.order.orderId) refresh();
  }

  Future<void> refresh() async {
    final turn = ++generation;
    setState(() {
      busy = true;
      current = null;
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
      await actions.send(order!.orderId, action, order.financialAssignment!,
          reason: reason);
      if (!mounted || turn != generation) return;
      await refresh();
    } catch (_) {
      if (mounted && turn == generation)
        setState(() {
          current = null;
          error = 'لم تتأكد العملية. حدّث الطلب قبل إعادة المحاولة.';
          busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = current, state = order?.financialAssignment?['returnStatus'];
    return Scaffold(
      appBar: AppBar(title: const Text('إرجاع الطلب للفرع'), actions: [
        IconButton(
            onPressed: busy ? null : refresh, icon: const Icon(Icons.refresh))
      ]),
      body: Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text('الطلب ${widget.order.orderId}'),
            const SizedBox(height: 12),
            const Text(
                'يبقى الحجز قائمًا حتى تأكيد الفرع استلام الأصناف. الوصول وحده لا يحرر الحجز. أجرة العودة تُراجع وفق السياسة المعتمدة.'),
            if (busy) const LinearProgressIndicator(),
            if (error != null) ...[
              Text(error!, style: const TextStyle(color: Colors.red)),
              TextButton(
                  onPressed: busy ? null : refresh,
                  child: const Text('إعادة التحميل'))
            ],
            if (order != null && order.isReturning) ...[
              Text(state == 'REVIEW_REQUIRED'
                  ? 'الاستلام قيد المراجعة؛ الحجز ما زال قائمًا'
                  : state == 'ARRIVED_AT_BRANCH'
                      ? 'بانتظار تأكيد استلام الفرع'
                      : 'أعد الأصناف إلى الفرع'),
              if (state == 'RETURNING')
                FilledButton(
                    onPressed: busy ? null : () => act('arrive-return'),
                    child: const Text('وصلت إلى الفرع ومعي الأصناف')),
            ] else if (order != null &&
                ['picked_up', 'heading_to_customer', 'arrived_at_customer']
                    .contains(order.status)) ...[
              DropdownButtonFormField<String>(
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
              const Text('إذا استلمت نقدًا، تواصل مع الدعم للمراجعة المالية.'),
              FilledButton(
                  onPressed:
                      busy || !noCash ? null : () => act('request-return'),
                  child: const Text('بدء العودة مع بقاء الحجز')),
            ] else if (order != null)
              Text(order.status == 'returned'
                  ? 'أكد الفرع الاستلام وانتهت العودة'
                  : 'هذه الحالة لا تسمح ببدء عودة'),
          ])),
    );
  }
}
