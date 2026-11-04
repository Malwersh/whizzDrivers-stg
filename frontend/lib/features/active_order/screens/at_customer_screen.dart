import 'delivery_completion_screen.dart';
import '../services/delivery_proof_service.dart';
import '../widgets/delivery_proof_card.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/active_trip_summary.dart';
import '../widgets/trip_arrival_slider.dart';
import 'customer_cash_review_screen.dart';
import '../services/customer_cash_review_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../models/active_order_model.dart';
import '../../../providers/riverpod/active_order_provider.dart';
import '../widgets/customer_unavailable_dialog.dart';
import 'return_order_screen.dart';
import '../services/order_persistence_service.dart';

/// شاشة عند العميل - المرحلة 4 (التسليم النهائي)
class AtCustomerScreen extends ConsumerStatefulWidget {
  final ActiveOrder order;
  final DeliveryProofService? proofService;
  final Future<ActiveOrder> Function(String)? loadOrder;

  const AtCustomerScreen({
    super.key,
    required this.order,
    this.loadOrder,
    this.proofService,
  });

  @override
  ConsumerState<AtCustomerScreen> createState() => _AtCustomerScreenState();
}

class _AtCustomerScreenState extends ConsumerState<AtCustomerScreen>
    with WidgetsBindingObserver {
  bool _showCompletion = false;
  ActiveOrder? _completedOrder;
  bool _isLoading = false;
  bool _proofBusy = false;
  bool _cashCollected = false;
  Timer? _completionPoll;
  bool _checkingCompletion = false;
  bool _leaving = false;

  // Calculate total cash amount using new pricing model
  double get cashAmount =>
      widget.order.pricing?.total ?? widget.order.totalAmount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _completionPoll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isLoading &&
          !_proofBusy &&
          ModalRoute.of(context)?.isCurrent == true &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed)) {
        _refreshCompletion();
      }
    });
    // تحديث الـ Provider بالطلب الحالي (مهم بعد hot restart)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(activeOrderProvider).order;
      if (current == null || current.orderId == widget.order.orderId) {
        ref.read(activeOrderProvider.notifier).updateOrder(widget.order);
      }
      _refreshCompletion();
    });
  }

  @override
  void dispose() {
    _completionPoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isLoading) _refreshCompletion();
  }

  // Read the specific order. Missing data or a read failure never proves delivery.
  Future<bool?> _refreshCompletion({bool showError = false}) async {
    if (!mounted || _checkingCompletion || _leaving) return null;
    _checkingCompletion = true;
    try {
      final latest = await (widget.loadOrder ??
          ref
              .read(activeOrderServiceProvider)
              .getOrderById)(widget.order.orderId);
      if (!mounted || latest.orderId != widget.order.orderId) return null;
      if (!['delivered', 'completed', 'returned', 'cancelled']
          .contains(latest.status.toLowerCase())) {
        if (!['arrived_at_customer', 'at_customer']
            .contains(latest.status.toLowerCase()))
          throw StateError('Invalid delivery stage');
        final current = ref.read(activeOrderProvider).order;
        if (current != null && current.orderId != latest.orderId)
          throw StateError('Different active order');
        ref.read(activeOrderProvider.notifier).updateOrder(latest);
        return false;
      }
      _leaving = true;
      _completionPoll?.cancel();
      await OrderPersistenceService.clearActiveOrder(
          expectedOrderId: widget.order.orderId);
      if (!mounted) return true;
      if (ref.read(activeOrderProvider).order?.orderId ==
          widget.order.orderId) {
        ref.read(activeOrderProvider.notifier).clearOrder();
      }
      if (mounted) {
        final anotherOrder = ref.read(activeOrderProvider).order;
        if (['delivered', 'completed'].contains(latest.status.toLowerCase()) &&
            anotherOrder == null) {
          setState(() {
            _completedOrder = latest;
            _showCompletion = true;
          });
        } else {
          context.go('/');
        }
      }
      return true;
    } catch (_) {
      if (mounted && showError) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('تعذر تحديث حالة الطلب؛ أعد المحاولة قبل تأكيد التسليم.'),
        ));
      }
      return null;
    } finally {
      _checkingCompletion = false;
    }
  }

  void _showUnavailableDialog() {
    if (widget.order.financialAssignment != null) {
      showDeliveryFailureSheet(context, widget.order);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => CustomerUnavailableDialog(
        orderId: widget.order.orderId,
        customerPhone: widget.order.customerPhone,
        onConfirmUnavailable: () async {
          // TODO: Call API to report customer unreachable
          await Future.delayed(const Duration(seconds: 1));
          debugPrint('Customer unavailable reported');
        },
      ),
    );
  }

  Future<void> _openCashReview() async {
    setState(() => _cashCollected = false);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CustomerCashReviewScreen(
        driver: true,
        call: (body) =>
            CustomerCashReviewService().call(widget.order.orderId, body),
      ),
    ));
    if (mounted) await _refreshCompletion(showError: true);
  }

  Future<void> _completeDelivery() async {
    if (_isLoading || _proofBusy || _leaving || _checkingCompletion) return;
    final finished = await _refreshCompletion(showError: true);
    if (!mounted || finished != false) return;
    // تحقق من checkbox إذا كان الدفع نقدي
    if (widget.order.isCashPayment && !_cashCollected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تأكيد استلام المبلغ النقدي'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ref.read(activeOrderProvider.notifier).deliverOrder(
          cashCollected: _cashCollected ? cashAmount : null,
          deliveryNotes: null,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result != null && result['success'] == true && mounted) {
      // ✅ مسح الطلب النشط من التخزين المحلي بعد التسليم الناجح
      try {
        await OrderPersistenceService.clearActiveOrder(
            expectedOrderId: widget.order.orderId);
        debugPrint(
            '🗑️ Active order cleared from local storage after successful delivery');
      } catch (e) {
        debugPrint('⚠️ Failed to clear active order from local storage: $e');
        // لا نفشل العملية بسبب مشكلة المسح
      }

      if (!mounted) return;
      _completionPoll?.cancel();
      setState(() {
        _leaving = true;
        _showCompletion = true;
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(result?['message'] ?? 'فشل تأكيد التسليم. حاول مرة أخرى.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _callCustomer() async {
    try {
      if (!await launchUrl(Uri(scheme: 'tel', path: widget.order.customerPhone),
          mode: LaunchMode.externalApplication)) throw Exception();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح الاتصال؛ حاول مجددًا')));
    }
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE3E9F1))),
        child: child,
      );
  Widget _title(String text) => Text(text,
      style: const TextStyle(
          color: TripStyle.ink, fontSize: 18, fontWeight: FontWeight.bold));

  @override
  Widget build(BuildContext context) => _showCompletion
      ? DeliveryCompletionScreen(
          orderId: widget.order.orderId,
          orderNumber: widget.order.orderNumber ?? widget.order.shortOrderId,
          confirmedOrder: _completedOrder,
          loadOrder: widget.loadOrder ??
              ref.read(activeOrderServiceProvider).getOrderById,
          onHome: () => context.go('/'))
      : Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: TripStyle.background,
            appBar: AppBar(
                title: const Text('تسليم الطلب',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                centerTitle: true,
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: TripStyle.ink,
                actions: [
                  IconButton(
                      tooltip: 'تحديث حالة الطلب',
                      icon: const Icon(Icons.refresh),
                      onPressed: _isLoading
                          ? null
                          : () => _refreshCompletion(showError: true))
                ]),
            body: Column(children: [
              Expanded(
                  child: RefreshIndicator(
                      onRefresh: () async {
                        await _refreshCompletion(showError: true);
                      },
                      child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            _card(Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Row(children: [
                                    Icon(Icons.location_on_outlined,
                                        color: TripStyle.blue),
                                    SizedBox(width: 8),
                                    Text('نقطة التسليم',
                                        style:
                                            TextStyle(color: TripStyle.muted))
                                  ]),
                                  const SizedBox(height: 12),
                                  _title(widget.order.customerName),
                                  const SizedBox(height: 6),
                                  Text(widget.order.customerAddress,
                                      style: const TextStyle(
                                          color: TripStyle.muted, height: 1.6)),
                                  if (widget.order.customerPhone
                                      .trim()
                                      .isNotEmpty)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: OutlinedButton.icon(
                                            onPressed:
                                                (_isLoading || _proofBusy)
                                                    ? null
                                                    : _callCustomer,
                                            icon:
                                                const Icon(Icons.call_outlined),
                                            label:
                                                const Text('الاتصال بالزبون'),
                                            style: OutlinedButton.styleFrom(
                                                foregroundColor: TripStyle.blue,
                                                minimumSize: const Size(
                                                    double.infinity, 48)))),
                                ])),
                            const SizedBox(height: 12),
                            _card(Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _title('ملخص الطلب'),
                                  const SizedBox(height: 12),
                                  SelectableText(
                                      widget.order.orderNumber ??
                                          widget.order.orderId,
                                      style: const TextStyle(
                                          color: TripStyle.muted)),
                                  const SizedBox(height: 12),
                                  Text(
                                      '${widget.order.items.length} صنف • ${widget.order.items.fold<int>(0, (n, item) => n + item.quantity)} قطعة',
                                      style: const TextStyle(
                                          color: TripStyle.muted)),
                                  const SizedBox(height: 8),
                                  ...widget.order.items.map((item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                          '${item.quantity} × ${item.name}',
                                          style: const TextStyle(
                                              color: TripStyle.ink)))),
                                  const Divider(height: 24),
                                  Text(
                                      widget.order.isCashPayment
                                          ? 'المطلوب تحصيله من الزبون'
                                          : 'إجمالي الطلب',
                                      style: const TextStyle(
                                          color: TripStyle.muted)),
                                  const SizedBox(height: 6),
                                  Text('${cashAmount.toStringAsFixed(0)} د.ع',
                                      style: const TextStyle(
                                          color: TripStyle.ink,
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text(
                                      widget.order.isCashPayment
                                          ? 'الدفع نقدًا عند التسليم'
                                          : 'دفع غير نقدي',
                                      style: const TextStyle(
                                          color: TripStyle.muted)),
                                ])),
                            const SizedBox(height: 12),
                            DeliveryProofCard(
                                service: widget.proofService,
                                order: widget.order,
                                onBusy: (value) {
                                  if (mounted)
                                    setState(() => _proofBusy = value);
                                }),
                            const SizedBox(height: 12),
                            if (widget.order.isCashPayment)
                              _card(Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _title('تأكيد التحصيل'),
                                    const SizedBox(height: 8),
                                    const Text(
                                        'أكد استلام النقد بعد عدّه وتسليم الطلب للزبون.',
                                        style: TextStyle(
                                            color: TripStyle.muted,
                                            height: 1.6)),
                                    const SizedBox(height: 12),
                                    CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        activeColor: TripStyle.blue,
                                        value: _cashCollected,
                                        onChanged: _isLoading
                                            ? null
                                            : (v) => setState(() =>
                                                _cashCollected = v == true),
                                        title: Text(
                                            'استلمت ${cashAmount.toStringAsFixed(0)} د.ع بالكامل',
                                            style: const TextStyle(
                                                color: TripStyle.ink,
                                                fontWeight: FontWeight.w600)),
                                        controlAffinity:
                                            ListTileControlAffinity.leading),
                                    const Divider(height: 24),
                                    const Text(
                                        'استلمت مبلغًا مختلفًا؟ سجّل ما استلمته فعليًا، ولا تؤكد التحصيل الكامل.',
                                        style: TextStyle(
                                            color: TripStyle.muted,
                                            height: 1.6)),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                        onPressed: (_isLoading || _proofBusy)
                                            ? null
                                            : _openCashReview,
                                        icon:
                                            const Icon(Icons.payments_outlined),
                                        label: const Text(
                                            'مراجعة النقد ورد المبلغ'),
                                        style: OutlinedButton.styleFrom(
                                            foregroundColor: TripStyle.blue,
                                            minimumSize: const Size(
                                                double.infinity, 48))),
                                  ])),
                            const SizedBox(height: 16),
                            if (widget.order.financialAssignment != null)
                              OutlinedButton.icon(
                                  onPressed: (_isLoading || _proofBusy)
                                      ? null
                                      : _showUnavailableDialog,
                                  icon: const Icon(Icons.person_off_outlined),
                                  label: const Text('تعذّر تسليم الطلب للزبون'),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: TripStyle.blue,
                                      minimumSize:
                                          const Size(double.infinity, 50))),
                          ]))),
              Container(
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      border:
                          Border(top: BorderSide(color: Color(0xFFE3E9F1)))),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: SafeArea(
                      top: false,
                      child: TripArrivalSlider(
                          enabled: !_isLoading &&
                              !_proofBusy &&
                              (!widget.order.isCashPayment || _cashCollected),
                          label: 'اسحب لتأكيد التسليم',
                          confirmingLabel: 'جارٍ تأكيد التسليم',
                          releaseLabel: 'أفلت لتأكيد التسليم',
                          semanticsLabel: 'اسحب إلى اليسار لتأكيد تسليم الطلب',
                          onConfirm: _completeDelivery))),
            ]),
          ),
        );
}
