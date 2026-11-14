import 'dart:async';
import 'package:flutter/material.dart';

/// Measures the actionable buttons, not a push or off-screen list insertion.
class OfferDisplayReceipt extends StatefulWidget {
  final Widget child;
  final DateTime expiresAt;
  final Future<bool> Function()? acknowledge;
  const OfferDisplayReceipt(
      {super.key,
      required this.child,
      required this.expiresAt,
      this.acknowledge});
  @override
  State<OfferDisplayReceipt> createState() => _OfferDisplayReceiptState();
}

class _OfferDisplayReceiptState extends State<OfferDisplayReceipt>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _sent = false, _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!mounted ||
        _sent ||
        _busy ||
        widget.acknowledge == null ||
        !DateTime.now().isBefore(widget.expiresAt)) return;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final visible = rect.intersect(Offset.zero & MediaQuery.sizeOf(context));
    // Both response controls must be practically visible before acknowledging.
    if (visible.width < rect.width * .95 || visible.height < rect.height * .95)
      return;
    _busy = true;
    try {
      _sent = await widget.acknowledge!();
      if (_sent) _timer?.cancel();
    } catch (_) {
      /* retry only while the offer is visible and valid */
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
