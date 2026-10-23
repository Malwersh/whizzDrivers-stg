import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/active_order_model.dart';
import '../../../providers/riverpod/active_order_provider.dart';
import '../widgets/active_trip_summary.dart';
import '../widgets/driver_trip_help.dart';
import '../widgets/store_issue_bottom_sheet.dart';
import '../widgets/driver_unassign_flow.dart';
import '../widgets/trip_arrival_slider.dart';
import '../../home/widgets/order_items_bottom_sheet.dart';

class AtRestaurantScreen extends ConsumerStatefulWidget {
  const AtRestaurantScreen({super.key, required this.order, this.onContinue});
  final ActiveOrder order;
  final void Function(ActiveOrder)? onContinue;
  @override
  ConsumerState<AtRestaurantScreen> createState() => _AtRestaurantScreenState();
}

class _AtRestaurantScreenState extends ConsumerState<AtRestaurantScreen> {
  late ActiveOrder _order;
  bool _reading = false, _busy = false, _fresh = false;
  String? _error;
  bool get _pickedUp =>
      ['picked_up', 'heading_to_customer'].contains(_order.status);
  bool get _canConfirm =>
      _fresh &&
      !_reading &&
      !_busy &&
      ['at_store', 'arrived_at_store', 'picked_up', 'heading_to_customer']
          .contains(_order.status);
  @override
  void initState() {
    super.initState();
    _order = widget.order;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<ActiveOrder> _read() async {
    final order = await ref
        .read(activeOrderServiceProvider)
        .getOrderById(widget.order.orderId);
    if (!mounted) throw StateError('Screen closed');
    if (order.orderId != widget.order.orderId)
      throw StateError('Order changed');
    setState(() {
      _order = order;
      _fresh = true;
    });
    ref.read(activeOrderProvider.notifier).updateOrder(order);
    return order;
  }

  Future<void> _refresh() async {
    if (_busy || _reading) return;
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      await _read();
    } catch (_) {
      if (mounted)
        setState(() {
          _fresh = false;
          _error = 'تعذر تحديث الطلب. تحقق من الاتصال وأعد المحاولة.';
        });
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  void _continue(ActiveOrder order) {
    if (widget.onContinue != null) {
      widget.onContinue!(order);
    } else {
      context.go('/heading-to-customer', extra: order);
    }
  }

  Future<void> _confirmPickup() async {
    if (!_canConfirm) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _read();
      if (!mounted) return;
      if (_order.status == 'heading_to_customer') {
        _continue(_order);
        return;
      }
      if (['at_store', 'arrived_at_store'].contains(_order.status)) {
        final success =
            await ref.read(activeOrderProvider.notifier).pickupOrder();
        if (!mounted) return;
        if (success) {
          final updated = ref.read(activeOrderProvider).order;
          if (updated == null || updated.orderId != _order.orderId)
            throw StateError('Order changed');
          setState(() => _order = updated);
        } else {
          await _read();
          if (!['picked_up', 'heading_to_customer'].contains(_order.status))
            throw StateError('Pickup unconfirmed');
        }
      }
      if (!mounted) return;
      if (_order.status == 'heading_to_customer') {
        _continue(_order);
        return;
      }
      if (_order.status != 'picked_up')
        throw StateError('Pickup stage changed');
      final heading =
          await ref.read(activeOrderProvider.notifier).startHeadingToCustomer();
      if (!mounted) return;
      if (heading) {
        final updated = ref.read(activeOrderProvider).order;
        if (updated == null || updated.orderId != _order.orderId)
          throw StateError('Order changed');
        setState(() => _order = updated);
      } else {
        await _read();
      }
      if (_order.status == 'heading_to_customer') {
        _continue(_order);
      } else {
        setState(() => _error =
            'تم تأكيد الاستلام. أعد السحب لمتابعة التوصيل إلى الزبون.');
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = _pickedUp
            ? 'تم تأكيد الاستلام. حدّث الطلب للمتابعة إلى الزبون.'
            : 'لم يتأكد استلام الطلب. حدّث الطلب وأعد المحاولة.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    try {
      if (!await launchUrl(Uri(scheme: 'tel', path: phone),
          mode: LaunchMode.externalApplication)) throw Exception();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر فتح الاتصال')));
    }
  }

  Future<void> _help() async {
    if (_busy || _reading) return;
    final action = await showModalBottomSheet<DriverTripHelpAction>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DriverTripHelp(order: _order));
    if (!mounted || action == null) return;
    switch (action) {
      case DriverTripHelpAction.unableToDeliver:
        break;
      case DriverTripHelpAction.callStore:
        await _call(_order.restaurantPhone);
        break;
      case DriverTripHelpAction.callCustomer:
        await _call(_order.customerPhone);
        break;
      case DriverTripHelpAction.items:
        await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => OrderItemsBottomSheet(
                items: _order.items, restaurantName: _order.restaurantName));
        break;
      case DriverTripHelpAction.unassign:
        await showDriverUnassignFlow(context, ref, _order);
        break;
      case DriverTripHelpAction.reportPickup:
        if (!TripStyle.canUnassign(_order)) return;
        final saved = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            isDismissible: false,
            enableDrag: false,
            backgroundColor: Colors.transparent,
            builder: (_) => StoreIssueBottomSheet(
                orderId: _order.orderId,
                onSubmit: (type, notes) async {
                  final result = await ref
                      .read(activeOrderServiceProvider)
                      .reportStoreIssue(_order.orderId,
                          issueType: type,
                          notes: notes,
                          assignment: _order.financialAssignment);
                  if (result['success'] != true ||
                      result['orderId'] != _order.orderId)
                    throw Exception('لم يتأكد حفظ البلاغ');
                }));
        if (saved == true && mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم حفظ بلاغ مشكلة الاستلام')));
        break;
    }
  }

  Widget _card(Widget child) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE0E7F0))),
      child: child);
  Widget _sectionTitle(IconData icon, String text) => Row(children: [
        Icon(icon, color: TripStyle.blue, size: 22),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: TripStyle.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)))
      ]);
  @override
  Widget build(BuildContext context) {
    final quantity =
        _order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final number = _order.orderNumber ?? _order.shortOrderId;
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            backgroundColor: TripStyle.background,
            appBar: AppBar(
                title: const Text('استلام الطلب',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                centerTitle: true,
                backgroundColor: Colors.white,
                foregroundColor: TripStyle.ink,
                elevation: 0,
                actions: [
                  TextButton.icon(
                      onPressed: _busy || _reading ? null : _help,
                      icon: const Icon(Icons.help_outline, size: 19),
                      label: const Text('مساعدة'),
                      style:
                          TextButton.styleFrom(foregroundColor: TripStyle.blue))
                ]),
            body: Column(children: [
              if (_reading)
                const LinearProgressIndicator(color: TripStyle.blue),
              Expanded(
                  child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                    color: TripStyle.ink,
                                    borderRadius: BorderRadius.circular(22)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(children: [
                                        Container(
                                            padding: const EdgeInsets.all(9),
                                            decoration: BoxDecoration(
                                                color: TripStyle.yellow,
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            child: const Icon(
                                                Icons.shopping_bag_outlined,
                                                color: TripStyle.ink)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Text(
                                                _pickedUp
                                                    ? 'تم استلام الطلب'
                                                    : 'طابق الطلب قبل استلامه',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 19,
                                                    fontWeight:
                                                        FontWeight.bold)))
                                      ]),
                                      const SizedBox(height: 18),
                                      const Text('رقم الطلب',
                                          style: TextStyle(
                                              color: Color(0xFFD8E4F2),
                                              fontSize: 12)),
                                      Row(children: [
                                        Expanded(
                                            child: SelectableText(number,
                                                textDirection:
                                                    TextDirection.ltr,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        IconButton(
                                            tooltip: 'نسخ رقم الطلب',
                                            onPressed: () async {
                                              await Clipboard.setData(
                                                  ClipboardData(text: number));
                                              if (mounted)
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(const SnackBar(
                                                        content: Text(
                                                            'تم نسخ رقم الطلب')));
                                            },
                                            icon: const Icon(
                                                Icons.copy_outlined,
                                                color: Colors.white,
                                                size: 20))
                                      ]),
                                    ])),
                            const SizedBox(height: 16),
                            _card(Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _sectionTitle(Icons.storefront_outlined,
                                      'نقطة الاستلام'),
                                  const SizedBox(height: 12),
                                  Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              Text(_order.restaurantName,
                                                  style: const TextStyle(
                                                      fontSize: 19,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: TripStyle.ink)),
                                              if (_order
                                                  .restaurantAddress.isNotEmpty)
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 6),
                                                    child: Text(
                                                        _order
                                                            .restaurantAddress,
                                                        style: const TextStyle(
                                                            color:
                                                                TripStyle.muted,
                                                            height: 1.6)))
                                            ])),
                                        if (_order.restaurantPhone
                                                ?.trim()
                                                .isNotEmpty ==
                                            true)
                                          IconButton(
                                              tooltip: 'الاتصال بالمتجر',
                                              onPressed: _busy
                                                  ? null
                                                  : () => _call(
                                                      _order.restaurantPhone),
                                              icon: const Icon(
                                                  Icons.call_outlined,
                                                  color: TripStyle.blue))
                                      ])
                                ])),
                            const SizedBox(height: 16),
                            _card(Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _sectionTitle(Icons.receipt_long_outlined,
                                      'الأصناف المطلوبة'),
                                  const SizedBox(height: 6),
                                  Text(
                                      '${_order.items.length} أصناف • $quantity قطع',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: TripStyle.muted)),
                                  const SizedBox(height: 16),
                                  if (_order.items.isEmpty)
                                    const Text(
                                        'تعذر عرض الأصناف. حدّث الطلب للتحقق.',
                                        style:
                                            TextStyle(color: TripStyle.muted)),
                                  ..._order.items.asMap().entries.map((entry) {
                                    final item = entry.value;
                                    return Column(children: [
                                      if (entry.key > 0)
                                        const Divider(height: 28),
                                      Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                                constraints:
                                                    const BoxConstraints(
                                                        minWidth: 42),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFEDF3FA),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                                child: Text('×${item.quantity}',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                        color: TripStyle.blue,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16))),
                                            const SizedBox(width: 12),
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text(item.name,
                                                      style: const TextStyle(
                                                          color: TripStyle.ink,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 16)),
                                                  if (item.modifiers
                                                          ?.isNotEmpty ==
                                                      true)
                                                    Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(top: 4),
                                                        child: Text(
                                                            item
                                                                .modifiers!
                                                                .join('، '),
                                                            style: const TextStyle(
                                                                color: TripStyle
                                                                    .muted,
                                                                height: 1.6))),
                                                  if (item.notes
                                                          ?.trim()
                                                          .isNotEmpty ==
                                                      true)
                                                    Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(top: 4),
                                                        child: Text(item.notes!,
                                                            style: const TextStyle(
                                                                color: TripStyle
                                                                    .muted,
                                                                height: 1.6)))
                                                ]))
                                          ])
                                    ]);
                                  }),
                                  const SizedBox(height: 16),
                                  Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFFFF7D9),
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: const Text(
                                          'تحقق من رقم الطلب والأصناف والكميات قبل تأكيد الاستلام.',
                                          style: TextStyle(
                                              color: TripStyle.ink,
                                              fontSize: 12,
                                              height: 1.6))),
                                ])),
                            if (_order.specialInstructions?.trim().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 16),
                              _card(Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _sectionTitle(
                                        Icons.notes_outlined, 'ملاحظات الطلب'),
                                    const SizedBox(height: 10),
                                    Text(_order.specialInstructions!,
                                        style: const TextStyle(
                                            color: TripStyle.muted,
                                            height: 1.6))
                                  ]))
                            ],
                            const SizedBox(height: 16),
                            _card(Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _sectionTitle(Icons.location_on_outlined,
                                      'نقطة التسليم'),
                                  const SizedBox(height: 12),
                                  Text(_order.customerName,
                                      style: const TextStyle(
                                          color: TripStyle.ink,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  if (_order.customerAddress.isNotEmpty)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(_order.customerAddress,
                                            style: const TextStyle(
                                                color: TripStyle.muted,
                                                height: 1.6)))
                                ])),
                            const SizedBox(height: 16),
                            _card(Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _sectionTitle(
                                      Icons.payments_outlined,
                                      _order.isCashPayment
                                          ? 'التحصيل عند التسليم'
                                          : 'طريقة الدفع'),
                                  const SizedBox(height: 12),
                                  Text(
                                      '${(_order.total ?? _order.totalAmount).toStringAsFixed(0)} د.ع',
                                      style: const TextStyle(
                                          color: TripStyle.ink,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                      _order.isCashPayment
                                          ? 'نقدًا • يُحصّل من الزبون عند التسليم'
                                          : 'الدفع بالبطاقة',
                                      style: const TextStyle(
                                          color: TripStyle.muted, height: 1.6))
                                ])),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              _card(Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(_error!,
                                        style: const TextStyle(
                                            color: Color(0xFFAF2536),
                                            height: 1.6)),
                                    TextButton(
                                        onPressed: _busy ? null : _refresh,
                                        style: TextButton.styleFrom(
                                            foregroundColor: TripStyle.blue),
                                        child: const Text('تحديث الطلب'))
                                  ]))
                            ],
                          ]))),
              Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      border:
                          Border(top: BorderSide(color: Color(0xFFE0E7F0)))),
                  child: SafeArea(
                      top: false,
                      child: TripArrivalSlider(
                          enabled: _canConfirm,
                          onConfirm: _confirmPickup,
                          label: _pickedUp
                              ? 'اسحب لمتابعة التوصيل'
                              : 'اسحب لتأكيد الاستلام',
                          confirmingLabel: _pickedUp
                              ? 'جارٍ بدء التوصيل'
                              : 'جارٍ تأكيد الاستلام',
                          releaseLabel: _pickedUp
                              ? 'أفلت لمتابعة التوصيل'
                              : 'أفلت لتأكيد الاستلام',
                          semanticsLabel: _pickedUp
                              ? 'اسحب إلى اليسار لمتابعة التوصيل'
                              : 'اسحب إلى اليسار لتأكيد استلام الطلب'))),
            ])));
  }
}
