import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../models/active_order_model.dart';
import '../widgets/active_trip_summary.dart';

class DeliveryCompletionScreen extends StatefulWidget {
  const DeliveryCompletionScreen(
      {super.key,
      required this.orderId,
      required this.orderNumber,
      required this.loadOrder,
      required this.onHome,
      this.confirmedOrder});
  final String orderId, orderNumber;
  final ActiveOrder? confirmedOrder;
  final Future<ActiveOrder> Function(String) loadOrder;
  final VoidCallback onHome;
  @override
  State<DeliveryCompletionScreen> createState() =>
      _DeliveryCompletionScreenState();
}

class _DeliveryCompletionScreenState extends State<DeliveryCompletionScreen> {
  ActiveOrder? order;
  bool loading = false;
  String? error;
  bool valid(ActiveOrder value) =>
      value.orderId == widget.orderId &&
      ['delivered', 'completed'].contains(value.status.toLowerCase()) &&
      value.driverEarnings != null &&
      value.driverEarnings!.isFinite &&
      value.driverEarnings! >= 0;
  @override
  void initState() {
    super.initState();
    final initial = widget.confirmedOrder;
    if (initial != null && valid(initial)) {
      order = initial;
    } else {
      load();
    }
  }

  Future<void> load() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.loadOrder(widget.orderId);
      if (!valid(value)) throw Exception();
      if (mounted) setState(() => order = value);
    } catch (_) {
      if (mounted)
        setState(() => error = 'تعذّر تحميل استحقاقك. يمكنك إعادة المحاولة.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) widget.onHome();
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.light,
              child: Scaffold(
                  backgroundColor: TripStyle.blue,
                  body: SafeArea(
                      child: Column(children: [
                    Expanded(
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(28, 44, 28, 28),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 20),
                                  Center(
                                      child: Container(
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: .12),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: .25))),
                                          child: const Icon(Icons.check_rounded,
                                              color: TripStyle.yellow,
                                              size: 62))),
                                  const SizedBox(height: 28),
                                  const Text('تم إكمال الطلب',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  const Text('تم تأكيد التسليم بنجاح',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 16)),
                                  const SizedBox(height: 12),
                                  Text(widget.orderNumber,
                                      textAlign: TextAlign.center,
                                      textDirection: TextDirection.ltr,
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: .8),
                                          fontSize: 14)),
                                  const SizedBox(height: 36),
                                  Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(24)),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            const Icon(
                                                Icons
                                                    .account_balance_wallet_outlined,
                                                color: TripStyle.blue,
                                                size: 30),
                                            const SizedBox(height: 12),
                                            const Text('استحقاقك من هذا الطلب',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    color: TripStyle.muted,
                                                    fontSize: 16)),
                                            const SizedBox(height: 14),
                                            if (order != null)
                                              Text(
                                                  '${NumberFormat('#,##0.###', 'en').format(order!.driverEarnings)} د.ع',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      color: TripStyle.ink,
                                                      fontSize: 38,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            if (loading)
                                              const Padding(
                                                  padding: EdgeInsets.all(18),
                                                  child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                              color: TripStyle
                                                                  .blue))),
                                            if (error != null) ...[
                                              Text(error!,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      color: TripStyle.muted,
                                                      height: 1.6)),
                                              TextButton.icon(
                                                  onPressed:
                                                      loading ? null : load,
                                                  icon:
                                                      const Icon(Icons.refresh),
                                                  label: const Text(
                                                      'إعادة المحاولة'))
                                            ],
                                          ])),
                                ]))),
                    Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                        child: FilledButton(
                            onPressed: widget.onHome,
                            style: FilledButton.styleFrom(
                                backgroundColor: TripStyle.yellow,
                                foregroundColor: TripStyle.ink,
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18))),
                            child: const Text('العودة للرئيسية',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold)))),
                  ]))))));
}
