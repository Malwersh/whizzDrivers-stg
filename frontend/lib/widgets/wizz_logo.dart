import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WizzLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? textColor;
  final bool
  useSvgAsset; // New parameter to choose between SVG and programmatic

  const WizzLogo({
    super.key,
    this.size = 120,
    this.showText = true,
    this.textColor,
    this.useSvgAsset = false, // Default to programmatic version
  });

  @override
  Widget build(BuildContext context) {
    if (useSvgAsset) {
      // Use the official WIZZ SVG logo
      return SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(
          'assets/images/wizz_logo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      );
    }

    // Use the programmatic gradient version
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(24),
        gradient: const SweepGradient(
          colors: [
            Color(0xFF1299A1), // Viridian Green
            Color(0xFFFD5933), // Portland Orange
            Color(0xFFEF9A4E), // Royal Orange
            Color(0xFFE6D8CF), // Bone
            Color(0xFFE84F99), // Raspberry Pink
            Color(0xFF7E4E9E), // Royal Purple
            Color(0xFF1299A1), // repeat for smooth loop
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51), // Adjusted alpha value
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: showText
          ? Center(
              child: Text(
                "WIZZ",
                style: TextStyle(
                  fontSize: size / 3,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? Colors.white,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      color: Colors.black.withAlpha(77), // Adjusted alpha value
                      blurRadius: 4,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

/// Compact version for app bars and small spaces
class WizzLogoCompact extends StatelessWidget {
  final double size;
  final bool animated;

  const WizzLogoCompact({super.key, this.size = 32, this.animated = false});

  @override
  Widget build(BuildContext context) {
    Widget logo = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFF1299A1), // Viridian Green
            Color(0xFFFD5933), // Portland Orange
            Color(0xFFEF9A4E), // Royal Orange
            Color(0xFFE6D8CF), // Bone
            Color(0xFFE84F99), // Raspberry Pink
            Color(0xFF7E4E9E), // Royal Purple
            Color(0xFF1299A1), // repeat for smooth loop
          ],
        ),
      ),
      child: Center(
        child: Text(
          "W",
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );

    if (animated) {
      return TweenAnimationBuilder<double>(
        duration: const Duration(seconds: 2),
        tween: Tween<double>(begin: 0, end: 1),
        builder: (context, value, child) {
          return Transform.rotate(angle: value * 2 * 3.14159, child: logo);
        },
      );
    }

    return logo;
  }
}
