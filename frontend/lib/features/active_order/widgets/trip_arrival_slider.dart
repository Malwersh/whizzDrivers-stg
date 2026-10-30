import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'active_trip_summary.dart';

class TripArrivalSlider extends StatefulWidget {
  const TripArrivalSlider(
      {super.key,
      required this.onConfirm,
      this.enabled = true,
      this.label = 'اسحب لتأكيد الوصول',
      this.confirmingLabel = 'جارٍ تأكيد الوصول',
      this.releaseLabel = 'أفلت لتأكيد الوصول',
      this.semanticsLabel = 'اسحب إلى اليسار لتأكيد الوصول إلى المتجر'});
  final Future<void> Function() onConfirm;
  final bool enabled;
  final String label, confirmingLabel, releaseLabel, semanticsLabel;
  @override
  State<TripArrivalSlider> createState() => _TripArrivalSliderState();
}

class _TripArrivalSliderState extends State<TripArrivalSlider> {
  double offset = 0;
  bool dragging = false, busy = false, threshold = false;
  Future<void> _finish(double max) async {
    if (busy || !widget.enabled) return;
    if (offset < max * .82) {
      setState(() {
        offset = 0;
        dragging = false;
        threshold = false;
      });
      return;
    }
    setState(() {
      busy = true;
      dragging = false;
      offset = max;
    });
    HapticFeedback.mediumImpact();
    try {
      await widget.onConfirm();
    } finally {
      if (mounted)
        setState(() {
          busy = false;
          offset = 0;
          threshold = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final max = (constraints.maxWidth - 64).clamp(1.0, double.infinity),
            progress = (offset / max).clamp(0.0, 1.0);
        return Semantics(
            label: widget.semanticsLabel,
            enabled: widget.enabled && !busy,
            child: GestureDetector(
              onHorizontalDragStart: widget.enabled && !busy
                  ? (_) => setState(() => dragging = true)
                  : null,
              onHorizontalDragUpdate: widget.enabled && !busy
                  ? (event) {
                      final next = (offset - event.delta.dx).clamp(0.0, max);
                      final reached = next >= max * .82;
                      if (reached && !threshold)
                        HapticFeedback.selectionClick();
                      setState(() {
                        offset = next;
                        threshold = reached;
                      });
                    }
                  : null,
              onHorizontalDragEnd:
                  widget.enabled && !busy ? (_) => _finish(max) : null,
              onHorizontalDragCancel: () => setState(() {
                dragging = false;
                offset = 0;
                threshold = false;
              }),
              child: Container(
                  height: 68,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                      color: const Color(0xFFEDF3FA),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFDCE6F2))),
                  child: Stack(children: [
                    AnimatedPositioned(
                        duration: dragging
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: offset + 64,
                        child: DecoratedBox(
                            key: const Key('arrival-progress'),
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [
                                  TripStyle.yellow
                                      .withValues(alpha: .18 * progress),
                                  TripStyle.yellow
                                      .withValues(alpha: .55 * progress)
                                ],
                                    begin: Alignment.centerRight,
                                    end: Alignment.centerLeft)))),
                    Positioned.fill(
                        child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 66),
                            child: Center(
                                child: Opacity(
                                    opacity: busy ? 1 : (1 - progress * .9),
                                    child: Text(
                                        busy
                                            ? widget.confirmingLabel
                                            : threshold
                                                ? widget.releaseLabel
                                                : widget.label,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: TripStyle.ink,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)))))),
                    AnimatedPositioned(
                        duration: dragging
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        right: offset + 5,
                        top: 5,
                        bottom: 5,
                        child: Container(
                            key: const Key('arrival-thumb'),
                            width: 56,
                            decoration: BoxDecoration(
                                color: TripStyle.yellow,
                                shape: BoxShape.circle,
                                boxShadow: progress == 0
                                    ? []
                                    : [
                                        BoxShadow(
                                            color: TripStyle.yellow.withValues(
                                                alpha: .22 * progress),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2))
                                      ]),
                            child: busy
                                ? const Padding(
                                    padding: EdgeInsets.all(18),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: TripStyle.ink))
                                : Icon(
                                    threshold
                                        ? Icons.check
                                        : Icons.arrow_back_rounded,
                                    textDirection: TextDirection.ltr,
                                    color: TripStyle.ink,
                                    size: 27))),
                  ])),
            ));
      });
}
