// Material Design 3 Color System for Hadhir Driver App
import 'package:flutter/material.dart';

/// Material Design 3 color tokens following the Material You color system
/// New color scheme with bright yellow primary and green secondary
class HadhirColors {
  // ========================================
  // MAIN COLOR SYSTEM
  // ========================================

  // Primary: Bright Yellow (#FFFC00) - Bold and vibrant
  static const Color primary = Color(0xFFFFFC00);

  // Secondary: Green (#32C759) - Fresh and clean
  static const Color secondary = Color(0xFF32C759);

  // ========================================
  // TEXT COLORS
  // ========================================

  // Primary text - Black
  static const Color textBlack = Color(0xFF000000);

  // Secondary text - White
  static const Color textWhite = Color(0xFFFFFFFF);

  // Text on primary (yellow) background - Black for contrast
  static const Color textOnPrimary = Color(0xFF000000);

  // Text on secondary (green) background - White for contrast
  static const Color textOnSecondary = Color(0xFFFFFFFF);

  // ========================================
  // MATERIAL 3 SYSTEM COLORS
  // ========================================

  // Primary colors
  static const Color onPrimary = textBlack; // Black text on yellow
  static const Color primaryContainer = Color(
    0xFFFFFE80,
  ); // Light yellow container
  static const Color onPrimaryContainer = textBlack; // Black on light yellow

  // Secondary colors
  static const Color onSecondary = textWhite; // White text on green
  static const Color secondaryContainer = Color(
    0xFFB8E6C1,
  ); // Light green container
  static const Color onSecondaryContainer = textBlack; // Black on light green

  // Tertiary colors - using a complementary orange
  static const Color tertiary = Color(0xFFFF8F00);
  static const Color onTertiary = textWhite;
  static const Color tertiaryContainer = Color(0xFFFFE0B3);
  static const Color onTertiaryContainer = textBlack;

  // Error colors
  static const Color error = Color(0xFFFF4444);
  static const Color onError = textWhite;
  static const Color errorContainer = Color(0xFFFFE6EA);
  static const Color onErrorContainer = textBlack;

  // Success colors - using secondary green
  static const Color success = secondary;
  static const Color onSuccess = textWhite;
  static const Color successContainer = secondaryContainer;
  static const Color onSuccessContainer = textBlack;

  // Warning colors - using tertiary orange
  static const Color warning = tertiary;
  static const Color onWarning = textWhite;
  static const Color warningContainer = tertiaryContainer;
  static const Color onWarningContainer = textBlack;

  // ========================================
  // SURFACE COLORS
  // ========================================

  // Main surface - White
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = textBlack;

  // Surface variants
  static const Color surfaceContainer = Color(0xFFF8F9FA); // Light gray
  static const Color surfaceContainerHigh = Color(
    0xFFF0F1F3,
  ); // Slightly darker
  static const Color surfaceContainerHighest = Color(
    0xFFE8EAED,
  ); // Darkest surface
  static const Color onSurfaceVariant = Color(0xFF666666); // Gray text

  // Background
  static const Color background = Color(0xFFFFFFFF); // White background
  static const Color onBackground = textBlack;

  // Outline colors
  static const Color outline = Color(0xFFDDDDDD); // Light gray outline
  static const Color outlineVariant = Color(0xFFEEEEEE); // Very light outline

  // ========================================
  // DARK THEME COLORS
  // ========================================

  // Dark theme primary - keep yellow but slightly dimmed
  static const Color primaryDark = Color(0xFFE6E300);
  static const Color onPrimaryDark = textBlack;
  static const Color primaryContainerDark = Color(0xFF4D4A00);
  static const Color onPrimaryContainerDark = textWhite;

  // Dark theme secondary - keep green but dimmed
  static const Color secondaryDark = Color(0xFF28A745);
  static const Color onSecondaryDark = textWhite;
  static const Color secondaryContainerDark = Color(0xFF1A5928);
  static const Color onSecondaryContainerDark = textWhite;

  // Dark surfaces
  static const Color surfaceDark = Color(0xFF121212);
  static const Color onSurfaceDark = textWhite;
  static const Color surfaceContainerDark = Color(0xFF1E1E1E);
  static const Color onSurfaceVariantDark = Color(0xFFCCCCCC);

  static const Color backgroundDark = Color(0xFF121212);
  static const Color onBackgroundDark = textWhite;

  // ========================================
  // FUNCTIONAL COLORS
  // ========================================

  // Business logic colors
  static const Color delivery = primary; // Yellow for delivery
  static const Color pickup = secondary; // Green for pickup
  static const Color restaurant = tertiary; // Orange for restaurant
  static const Color customer = Color(0xFF2196F3); // Blue for customer

  // Status colors
  static const Color pending = warning; // Orange for pending
  static const Color accepted = success; // Green for accepted
  static const Color inProgress = Color(0xFF2196F3); // Blue for in progress
  static const Color completed = success; // Green for completed
  static const Color cancelled = error; // Red for cancelled

  // Map colors
  static const Color mapPrimary = primary;
  static const Color mapRoute = Color(0xFF2196F3); // Blue route
  static const Color mapMarker = secondary;
  static const Color mapArea = Color(0x1AFFFC00); // Translucent yellow area

  // ========================================
  // LEGACY COMPATIBILITY
  // ========================================

  // Legacy colors mapped to new system
  static const Color arcticCyan = Color(
    0xFF2196F3,
  ); // Blue for legacy arctic cyan
  static const Color ultravioletPulse = error; // Red for legacy purple
  static const Color acidKiwi = secondary; // Green for legacy acid kiwi
  static const Color moonstoneMist = surfaceContainer; // Light gray background
  static const Color obsidianCore = textBlack; // Black text

  // Basic colors
  static const Color white = textWhite;
  static const Color black = textBlack;

  // Utility colors
  static const Color textPrimary = textBlack;
  static const Color textSecondary = Color(0xFF666666); // Gray text
  static const Color border = outline;
  static const Color borderLight = outlineVariant;

  // Gray scale
  static const Color grey100 = Color(0xFFF8F9FA);
  static const Color grey200 = Color(0xFFE9ECEF);
  static const Color grey300 = Color(0xFFDEE2E6);
  static const Color grey400 = Color(0xFFCED4DA);
  static const Color grey500 = Color(0xFFADB5BD);
  static const Color grey600 = Color(0xFF6C757D);
  static const Color grey700 = Color(0xFF495057);
  static const Color grey800 = Color(0xFF343A40);
  static const Color grey900 = Color(0xFF212529);

  // ========================================
  // MATERIAL 3 COLOR SCHEMES
  // ========================================

  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: onSurface,
    surfaceContainerHighest: surfaceContainerHighest,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: surfaceDark,
    onInverseSurface: onSurfaceDark,
    inversePrimary: primaryDark,
    surfaceTint: primary,
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primaryDark,
    onPrimary: onPrimaryDark,
    primaryContainer: primaryContainerDark,
    onPrimaryContainer: onPrimaryContainerDark,
    secondary: secondaryDark,
    onSecondary: onSecondaryDark,
    secondaryContainer: secondaryContainerDark,
    onSecondaryContainer: onSecondaryContainerDark,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surfaceDark,
    onSurface: onSurfaceDark,
    surfaceContainerHighest: surfaceContainerDark,
    onSurfaceVariant: onSurfaceVariantDark,
    outline: Color(0xFF666666),
    outlineVariant: Color(0xFF444444),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: surface,
    onInverseSurface: onSurface,
    inversePrimary: primary,
    surfaceTint: primaryDark,
  );
}

/// App-specific color extensions for common use cases
extension HadhirColorsExtension on HadhirColors {
  /// Get text color that contrasts well with the given background color
  static Color getContrastingTextColor(Color backgroundColor) {
    // Calculate luminance to determine if background is light or dark
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? HadhirColors.textBlack : HadhirColors.textWhite;
  }

  /// Get appropriate color for transaction type
  static Color getTransactionColor(String transactionType) {
    switch (transactionType.toLowerCase()) {
      case 'credit':
      case 'deposit':
      case 'earning':
        return HadhirColors.success;
      case 'debit':
      case 'withdrawal':
      case 'payment':
        return HadhirColors.error;
      case 'pending':
        return HadhirColors.warning;
      default:
        return HadhirColors.textSecondary;
    }
  }
}
