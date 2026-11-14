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
      if (mounted) {
        setState(() => error = 'تعذّر تحميل استحقاقك. يمكنك إعادة المحاولة.');
      }
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
            value: SystemUiOverlayStyle.dark,
            child: Scaffold(
              backgroundColor: TripStyle.background,
              bottomNavigationBar: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: FilledButton.icon(
                    onPressed: widget.onHome,
                    icon: const Icon(Icons.home_outlined, size: 22),
                    label: const Text('العودة للرئيسية'),
                    style: FilledButton.styleFrom(
                      backgroundColor: TripStyle.yellow,
                      foregroundColor: TripStyle.ink,
                      minimumSize: const Size(double.infinity, 54),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 52)
                              .clamp(0, double.infinity)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                              child: Container(
                            width: 112,
                            height: 112,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: TripStyle.ink.withValues(alpha: .06),
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                  color: TripStyle.ink, shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 48),
                            ),
                          )),
                          const SizedBox(height: 26),
                          const Text('تم إكمال الطلب',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: TripStyle.ink,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          const Text('تم تأكيد التسليم بنجاح',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: TripStyle.muted,
                                  fontSize: 15,
                                  height: 1.6)),
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                  color: TripStyle.ink.withValues(alpha: .07)),
                            ),
                            child: Column(children: [
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                          color: TripStyle.background,
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                      child: const Icon(
                                          Icons.account_balance_wallet_outlined,
                                          color: TripStyle.ink,
                                          size: 22),
                                    ),
                                    const SizedBox(width: 10),
                                    const Flexible(
                                        child: Text('استحقاقك من هذا الطلب',
                                            style: TextStyle(
                                                color: TripStyle.muted,
                                                fontSize: 15))),
                                  ]),
                              const SizedBox(height: 20),
                              if (order != null)
                                Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    children: [
                                      Text(
                                          NumberFormat('#,##0.###', 'en')
                                              .format(order!.driverEarnings),
                                          textDirection: TextDirection.ltr,
                                          style: const TextStyle(
                                              color: TripStyle.ink,
                                              fontSize: 42,
                                              fontWeight: FontWeight.w700)),
                                      const Text('د.ع',
                                          style: TextStyle(
                                              color: TripStyle.ink,
                                              fontSize: 19,
                                              fontWeight: FontWeight.w500)),
                                    ]),
                              if (loading)
                                const Padding(
                                    padding: EdgeInsets.all(18),
                                    child: CircularProgressIndicator(
                                        color: TripStyle.ink)),
                              if (error != null) ...[
                                Text(error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: TripStyle.muted, height: 1.6)),
                                TextButton.icon(
                                    onPressed: loading ? null : load,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('إعادة المحاولة')),
                              ],
                              const SizedBox(height: 22),
                              Divider(
                                  height: 1,
                                  color: TripStyle.ink.withValues(alpha: .08)),
                              const SizedBox(height: 16),
                              Row(children: [
                                const Text('رقم الطلب',
                                    style: TextStyle(
                                        color: TripStyle.muted, fontSize: 13)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(widget.orderNumber,
                                        textAlign: TextAlign.left,
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                            color: TripStyle.ink,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500))),
                              ]),
                            ]),
                          ),
                          const SizedBox(height: 24),
                          const Text('شكرًا لك على توصيل الطلب',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: TripStyle.muted, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
