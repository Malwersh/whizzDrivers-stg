// Arctic Cyan Theme Extensions for Material 3
import 'package:flutter/material.dart';
import 'package:wizz_driver/design_system/colors.dart';

/// Arctic Cyan Theme Extensions
/// Provides additional color properties and utilities for the Arctic Cyan design system
@immutable
class ArcticCyanColors extends ThemeExtension<ArcticCyanColors> {
  const ArcticCyanColors({
    required this.arcticCyan,
    required this.ultravioletPulse,
    required this.acidKiwi,
    required this.moonstoneMist,
    required this.obsidianCore,
    required this.statusPending,
    required this.statusAccepted,
    required this.statusInProgress,
    required this.statusCompleted,
    required this.statusCancelled,
    required this.functionalDelivery,
    required this.functionalPickup,
    required this.functionalRestaurant,
    required this.functionalCustomer,
  });

  final Color arcticCyan;
  final Color ultravioletPulse;
  final Color acidKiwi;
  final Color moonstoneMist;
  final Color obsidianCore;
  final Color statusPending;
  final Color statusAccepted;
  final Color statusInProgress;
  final Color statusCompleted;
  final Color statusCancelled;
  final Color functionalDelivery;
  final Color functionalPickup;
  final Color functionalRestaurant;
  final Color functionalCustomer;

  @override
  ArcticCyanColors copyWith({
    Color? arcticCyan,
    Color? ultravioletPulse,
    Color? acidKiwi,
    Color? moonstoneMist,
    Color? obsidianCore,
    Color? statusPending,
    Color? statusAccepted,
    Color? statusInProgress,
    Color? statusCompleted,
    Color? statusCancelled,
    Color? functionalDelivery,
    Color? functionalPickup,
    Color? functionalRestaurant,
    Color? functionalCustomer,
  }) {
    return ArcticCyanColors(
      arcticCyan: arcticCyan ?? this.arcticCyan,
      ultravioletPulse: ultravioletPulse ?? this.ultravioletPulse,
      acidKiwi: acidKiwi ?? this.acidKiwi,
      moonstoneMist: moonstoneMist ?? this.moonstoneMist,
      obsidianCore: obsidianCore ?? this.obsidianCore,
      statusPending: statusPending ?? this.statusPending,
      statusAccepted: statusAccepted ?? this.statusAccepted,
      statusInProgress: statusInProgress ?? this.statusInProgress,
      statusCompleted: statusCompleted ?? this.statusCompleted,
      statusCancelled: statusCancelled ?? this.statusCancelled,
      functionalDelivery: functionalDelivery ?? this.functionalDelivery,
      functionalPickup: functionalPickup ?? this.functionalPickup,
      functionalRestaurant: functionalRestaurant ?? this.functionalRestaurant,
      functionalCustomer: functionalCustomer ?? this.functionalCustomer,
    );
  }

  @override
  ArcticCyanColors lerp(ArcticCyanColors? other, double t) {
    if (other is! ArcticCyanColors) {
      return this;
    }
    return ArcticCyanColors(
      arcticCyan: Color.lerp(arcticCyan, other.arcticCyan, t)!,
      ultravioletPulse: Color.lerp(
        ultravioletPulse,
        other.ultravioletPulse,
        t,
      )!,
      acidKiwi: Color.lerp(acidKiwi, other.acidKiwi, t)!,
      moonstoneMist: Color.lerp(moonstoneMist, other.moonstoneMist, t)!,
      obsidianCore: Color.lerp(obsidianCore, other.obsidianCore, t)!,
      statusPending: Color.lerp(statusPending, other.statusPending, t)!,
      statusAccepted: Color.lerp(statusAccepted, other.statusAccepted, t)!,
      statusInProgress: Color.lerp(
        statusInProgress,
        other.statusInProgress,
        t,
      )!,
      statusCompleted: Color.lerp(statusCompleted, other.statusCompleted, t)!,
      statusCancelled: Color.lerp(statusCancelled, other.statusCancelled, t)!,
      functionalDelivery: Color.lerp(
        functionalDelivery,
        other.functionalDelivery,
        t,
      )!,
      functionalPickup: Color.lerp(
        functionalPickup,
        other.functionalPickup,
        t,
      )!,
      functionalRestaurant: Color.lerp(
        functionalRestaurant,
        other.functionalRestaurant,
        t,
      )!,
      functionalCustomer: Color.lerp(
        functionalCustomer,
        other.functionalCustomer,
        t,
      )!,
    );
  }

  /// Light theme Arctic Cyan colors
  static const light = ArcticCyanColors(
    arcticCyan: HadhirColors.arcticCyan,
    ultravioletPulse: HadhirColors.ultravioletPulse,
    acidKiwi: HadhirColors.acidKiwi,
    moonstoneMist: HadhirColors.moonstoneMist,
    obsidianCore: HadhirColors.obsidianCore,
    statusPending: HadhirColors.pending,
    statusAccepted: HadhirColors.accepted,
    statusInProgress: HadhirColors.inProgress,
    statusCompleted: HadhirColors.completed,
    statusCancelled: HadhirColors.cancelled,
    functionalDelivery: HadhirColors.delivery,
    functionalPickup: HadhirColors.pickup,
    functionalRestaurant: HadhirColors.restaurant,
    functionalCustomer: HadhirColors.customer,
  );

  /// Dark theme Arctic Cyan colors
  static const dark = ArcticCyanColors(
    arcticCyan: HadhirColors.primaryDark,
    ultravioletPulse: HadhirColors.secondaryDark,
    acidKiwi: HadhirColors.tertiaryDark,
    moonstoneMist: HadhirColors.surfaceDark,
    obsidianCore: Color(0xFFE8F0F7), // Light text for dark theme
    statusPending: HadhirColors.warningDark,
    statusAccepted: HadhirColors.successDark,
    statusInProgress: HadhirColors.primaryDark,
    statusCompleted: HadhirColors.successDark,
    statusCancelled: HadhirColors.errorDark,
    functionalDelivery: HadhirColors.primaryDark,
    functionalPickup: HadhirColors.tertiaryDark,
    functionalRestaurant: HadhirColors.secondaryDark,
    functionalCustomer: HadhirColors.secondaryDark,
  );
}

/// Extension to easily access Arctic Cyan colors from ThemeData
extension ArcticCyanTheme on ThemeData {
  ArcticCyanColors get arcticCyan =>
      extension<ArcticCyanColors>() ?? ArcticCyanColors.light;
}

/// Extension to easily access Arctic Cyan colors from BuildContext
extension ArcticCyanContext on BuildContext {
  ArcticCyanColors get arcticCyan => Theme.of(this).arcticCyan;
}

/// Gradient utilities for special effects (avoiding gradients in main UI as requested)
/// These are provided for future use in specific components like loading states
class ArcticCyanGradients {
  static const LinearGradient primaryShimmer = LinearGradient(
    colors: [Color(0xFFE8EDF5), Color(0xFFF2F4F8), Color(0xFFE8EDF5)],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );

  static const LinearGradient loadingShimmer = LinearGradient(
    colors: [Color(0x33BDC7D1), Color(0x1ABDC7D1), Color(0x33BDC7D1)],
    begin: Alignment(-1.0, 0.0),
    end: Alignment(1.0, 0.0),
  );
}

/// Color utilities for Arctic Cyan system
class ArcticCyanUtils {
  /// Get appropriate text color for given background
  static Color getTextColorForBackground(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5
        ? HadhirColors.obsidianCore
        : const Color(0xFFE8F0F7);
  }

  /// Get surface elevation color
  static Color getSurfaceElevation(Color baseColor, double elevation) {
    final opacity = (elevation / 12).clamp(0.0, 0.15);
    return Color.alphaBlend(
      HadhirColors.arcticCyan.withOpacity(opacity),
      baseColor,
    );
  }

  /// Create disabled version of any color
  static Color getDisabledColor(Color color) {
    return color.withOpacity(0.38);
  }

  /// Get hover state color
  static Color getHoverColor(Color color) {
    return Color.alphaBlend(HadhirColors.arcticCyan.withOpacity(0.08), color);
  }

  /// Get pressed state color
  static Color getPressedColor(Color color) {
    return Color.alphaBlend(HadhirColors.arcticCyan.withOpacity(0.12), color);
  }
}
