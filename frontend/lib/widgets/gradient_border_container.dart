import 'package:flutter/material.dart';

/// GradientBorderContainer
/// A reusable container that paints a multicolor gradient border around any child.
///
/// - Uses a SweepGradient with brand colors in a smooth loop
/// - Supports circular (avatars) and rounded-rectangle shapes
/// - Customizable borderWidth and borderRadius (radius ignored for circles)
///
/// Example (rounded rectangle):
/// GradientBorderContainer(
///   borderWidth: 4,
///   borderRadius: 16,
///   child: YourCardWidget(),
/// )
///
/// Example (circle avatar):
/// GradientBorderContainer.circular(
///   borderWidth: 4,
///   child: CircleAvatar(radius: 36, backgroundImage: ...),
/// )
class GradientBorderContainer extends StatelessWidget {
  /// Width of the gradient border. Defaults to 3.
  final double borderWidth;

  /// Corner radius for rounded rectangles. Ignored for circular variant.
  /// Defaults to 0 (sharp corners).
  final double borderRadius;

  /// The inner widget to display.
  final Widget child;

  /// Whether to render as a circle (e.g., for avatars).
  final bool isCircular;

  const GradientBorderContainer({
    super.key,
    this.borderWidth = 3,
    this.borderRadius = 0,
    required this.child,
  }) : isCircular = false;

  /// Circular convenience constructor. `borderRadius` is ignored when circular.
  const GradientBorderContainer.circular({
    super.key,
    this.borderWidth = 3,
    required this.child,
  }) : borderRadius = 0,
       isCircular = true;

  // Brand colors in the requested order, repeated first color at end for seamless loop
  static const List<Color> _brandGradientColors = <Color>[
    Color(0xFF1299A1), // Viridian Green
    Color(0xFFFD5933), // Portland Orange
    Color(0xFFEF9A4E), // Royal Orange
    Color(0xFFE6D8CF), // Bone
    Color(0xFFE84F99), // Raspberry Pink
    Color(0xFF7E4E9E), // Royal Purple
    Color(0xFF1299A1), // Repeat start color for smooth loop
  ];

  @override
  Widget build(BuildContext context) {
    final double bw = borderWidth.clamp(0.0, double.infinity);

    // Sweep gradient for the border ring
    const gradient = SweepGradient(
      colors: _brandGradientColors,
      // Optional: set transform to align gradient start at top center
      transform: GradientRotation(-3.14159 / 2),
    );

    // Inner background defaults to surface to ensure the border is visible
    final Color innerBackground = Theme.of(context).colorScheme.surface;

    if (isCircular) {
      return DecoratedBox(
        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: gradient),
        child: Padding(
          padding: EdgeInsets.all(bw),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors
                  .white, // Fallback; overridden by themed Container below
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: innerBackground,
              ),
              child: ClipOval(child: child),
            ),
          ),
        ),
      );
    }

    final radius = Radius.circular(borderRadius.clamp(0.0, double.infinity));
    final borderR = BorderRadius.all(radius);

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: borderR, gradient: gradient),
      child: Padding(
        padding: EdgeInsets.all(bw),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderR,
            color: innerBackground,
          ),
          child: ClipRRect(borderRadius: borderR, child: child),
        ),
      ),
    );
  }
}
