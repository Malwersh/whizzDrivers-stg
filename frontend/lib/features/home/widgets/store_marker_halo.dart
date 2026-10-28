import 'package:flutter/material.dart';

/// A screen-sized glow hugs the marker at every map zoom; it is not a
/// geographic radius and does not imply a delivery or dispatch coverage area.
void paintStoreMarkerHalo(
    Canvas canvas, Offset center, double radius, int level) {
  if (level <= 0) return;
  final color = level >= 2 ? const Color(0xFFF22238) : const Color(0xFFFFC000);
  canvas.drawCircle(
      center,
      radius + 6,
      Paint()
        ..color = color.withValues(alpha: .92)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5));
  canvas.drawCircle(
      center, radius + 4.5, Paint()..color = color.withValues(alpha: .96));
}
