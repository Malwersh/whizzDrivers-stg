// Material Design 3 Color System for Hadhir Driver App - Arctic Cyan Theme
import 'package:flutter/material.dart';

/// Material Design 3 color tokens following the Material You color system
/// New color scheme with bright yellow primary and green secondary
class HadhirColors {
  // ========================================
  // MAIN COLOR SYSTEM - BRIGHT YELLOW & BLUE
  // ========================================

  // Primary: Bright Yellow - Main brand color
  static const Color primary = Color(0xFFFDC500);

  // Secondary: Blue - Complementary brand color
  static const Color secondary = Color(0xFF00509D);

  // Branding accent colors
  static const Color brandingYellow = Color(
    0xFFFDC500,
  ); // Original yellow for accents
  static const Color brandingGreen = Color(
    0xFF32C759,
  ); // Original green for accents
  static const Color brandingOrange = Color(
    0xFFFD5933,
  ); // Portland Orange for accents

  // Text colors - Monochrome system
  static const Color textPrimary = Color(0xFF000000); // Black text
  static const Color textSecondary = Color(
    0xFFFFFFFF,
  ); // White text (on dark surfaces)
  static const Color textOnBackground = Color(
    0xFF000000,
  ); // Black on white backgrounds

  // Background colors - Pure monochrome
  static const Color background = Color(0xFFFFFFFF); // Pure white background
  static const Color surface = Color(0xFFFFFFFF); // White surface for cards
  static const Color surfaceVariant = Color(
    0xFFFAFAFA,
  ); // Slightly off-white for subtle differentiation

  // Legacy colors for backward compatibility (updated to monochrome scheme)
  static const Color arcticCyan = Color(
    0xFF000000,
  ); // Map to black for monochrome
  static const Color ultravioletPulse = Color(
    0xFF000000,
  ); // Map to black for monochrome
  static const Color acidKiwi = Color(
    0xFF000000,
  ); // Map to black for monochrome

  // Background: Pure white for Instagram-like aesthetic
  static const Color moonstoneMist = Color(0xFFFFFFFF);

  // Text & Icons: Black for primary text
  static const Color obsidianCore = Color(0xFF000000);

  // Dark gray for sign out and destructive actions
  static const Color darkGray = Color(0xFF0D0D0D);

  // ========================================
  // MATERIAL 3 LIGHT THEME COLORS
  // ========================================

  // Primary colors based on White (monochrome)
  static const Color onPrimary = Color(0xFF000000); // Black text on white
  static const Color primaryContainer = Color(
    0xFFFAFAFA,
  ); // Very light gray container
  static const Color onPrimaryContainer = Color(
    0xFF000000,
  ); // Black on light container

  // Secondary colors based on Black (monochrome)
  static const Color onSecondary = Color(0xFFFFFFFF); // White text on black
  static const Color secondaryContainer = Color(
    0xFF1A1A1A,
  ); // Dark gray container
  static const Color onSecondaryContainer = Color(
    0xFFFFFFFF,
  ); // White on dark container

  // Tertiary colors based on monochrome system
  static const Color tertiary = Color(0xFF666666); // Medium gray for tertiary
  static const Color onTertiary = Color(0xFFFFFFFF); // White on gray
  static const Color tertiaryContainer = Color(
    0xFFF0F0F0,
  ); // Light gray container
  static const Color onTertiaryContainer = Color(
    0xFF000000,
  ); // Black on light gray

  // System colors - monochrome with subtle differentiation
  static const Color error = Color(0xFF000000); // Black for errors (monochrome)
  static const Color onError = Color(0xFFFFFFFF); // White on black
  static const Color errorContainer = Color(0xFFF5F5F5); // Light gray container
  static const Color onErrorContainer = Color(0xFF000000); // Black on light

  static const Color success = Color(
    0xFF000000,
  ); // Black for success (monochrome)
  static const Color onSuccess = Color(0xFFFFFFFF); // White on black
  static const Color successContainer = Color(
    0xFFF5F5F5,
  ); // Light gray container
  static const Color onSuccessContainer = Color(0xFF000000); // Black on light

  static const Color warning = Color(
    0xFF000000,
  ); // Black for warning (monochrome)
  static const Color onWarning = Color(0xFFFFFFFF); // White on black
  static const Color warningContainer = Color(
    0xFFF5F5F5,
  ); // Light gray container
  static const Color onWarningContainer = Color(0xFF000000); // Black on light

  // Surface colors based on pure white (monochrome system)
  static const Color onSurface = obsidianCore; // Black on white surfaces
  static const Color surfaceContainer = Color(
    0xFFFAFAFA,
  ); // Very light gray for containers
  static const Color onSurfaceVariant = Color(
    0xFF666666,
  ); // Medium gray for muted text

  // Outline colors - subtle grays for monochrome system
  static const Color outline = Color(0xFFE0E0E0); // Light gray outline
  static const Color outlineVariant = Color(
    0xFFF5F5F5,
  ); // Very light gray outline

  // ========================================
  // MATERIAL 3 DARK THEME COLORS - MONOCHROME SYSTEM
  // ========================================

  // Primary colors for dark theme (inverted monochrome)
  static const Color primaryDark = Color(
    0xFF000000,
  ); // Black primary for dark theme
  static const Color onPrimaryDark = Color(0xFFFFFFFF); // White text on black
  static const Color primaryContainerDark = Color(
    0xFF1A1A1A,
  ); // Dark gray container
  static const Color onPrimaryContainerDark = Color(
    0xFFFFFFFF,
  ); // White on dark

  // Secondary colors for dark theme (inverted monochrome)
  static const Color secondaryDark = Color(
    0xFFFFFFFF,
  ); // White secondary for dark theme
  static const Color onSecondaryDark = Color(0xFF000000); // Black text on white
  static const Color secondaryContainerDark = Color(
    0xFFF5F5F5,
  ); // Light gray container
  static const Color onSecondaryContainerDark = Color(
    0xFF000000,
  ); // Black on light

  // Tertiary colors for dark theme
  static const Color tertiaryDark = Color(0xFFD4E600); // Bright acid kiwi
  static const Color onTertiaryDark = Color(0xFF1A2200); // Very dark green
  static const Color tertiaryContainerDark = Color(
    0xFF334400,
  ); // Dark green container
  static const Color onTertiaryContainerDark = Color(0xFFE8F5CC);

  // System colors for dark theme
  static const Color errorDark = Color(0xFFFF6B85); // Softer red for dark
  static const Color onErrorDark = Color(0xFF220002);
  static const Color errorContainerDark = Color(0xFF680003);
  static const Color onErrorContainerDark = Color(0xFFFFE6EA);

  static const Color successDark = acidKiwi; // Keep acid kiwi for success
  static const Color onSuccessDark = Color(0xFF1A2200);
  static const Color successContainerDark = Color(0xFF334400);
  static const Color onSuccessContainerDark = Color(0xFFE8F5CC);

  static const Color warningDark = Color(0xFFFFCC80); // Soft orange for dark
  static const Color onWarningDark = Color(0xFF1A0D00);
  static const Color warningContainerDark = Color(0xFF4D2600);
  static const Color onWarningContainerDark = Color(0xFFFFE0B3);

  // Surface colors for dark theme - monochrome system
  static const Color surfaceDark = Color(0xFF000000); // Pure black surface
  static const Color onSurfaceDark = Color(0xFFFFFFFF); // White text on black
  static const Color surfaceContainerDark = Color(
    0xFF1A1A1A,
  ); // Dark gray container
  static const Color onSurfaceVariantDark = Color(
    0xFF999999,
  ); // Medium gray text

  // Outline colors for dark theme - monochrome
  static const Color outlineDark = Color(0xFF333333); // Dark gray outline
  static const Color outlineVariantDark = Color(
    0xFF1A1A1A,
  ); // Very dark gray outline

  // ========================================
  // FUNCTIONAL COLORS - ARCTIC CYAN SYSTEM
  // ========================================

  // Business logic colors - monochrome system
  static const Color delivery = Color(0xFF000000); // Black for delivery
  static const Color pickup = Color(0xFF000000); // Black for pickup
  static const Color restaurant = Color(0xFF000000); // Black for restaurant
  static const Color customer = Color(0xFF000000); // Black for customer

  // Status colors - monochrome with subtle differentiation through opacity/containers
  static const Color pending = Color(0xFF666666); // Medium gray for waiting
  static const Color accepted = Color(0xFF000000); // Black for accepted
  static const Color inProgress = Color(
    0xFF333333,
  ); // Dark gray for in progress
  static const Color completed = Color(0xFF000000); // Black for completed
  static const Color cancelled = Color(0xFF000000); // Black for cancelled

  // Map colors - monochrome navigation
  static const Color mapPrimary = Color(0xFF000000); // Black for map elements
  static const Color mapRoute = Color(0xFF333333); // Dark gray for routes
  static const Color mapMarker = Color(0xFF000000); // Black for markers
  static const Color mapArea = Color(0x1A000000); // Translucent black area

  // ========================================
  // BACKWARDS COMPATIBILITY & UTILITY COLORS
  // ========================================

  // Basic colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black =
      obsidianCore; // Use obsidian core instead of pure black

  // Legacy text colors - using existing definitions above
  static const Color backgroundGrey = surfaceContainer; // Slightly darker mist

  // Border colors
  static const Color border = outline; // Soft gray-blue
  static const Color borderLight = outlineVariant; // Lighter outline

  // Gray scale - Pure monochrome system (Instagram-like)
  static const Color grey100 = Color(0xFFFFFFFF); // Pure white
  static const Color grey200 = Color(0xFFFAFAFA); // Very light gray
  static const Color grey300 = Color(0xFFF5F5F5); // Light gray
  static const Color grey400 = Color(0xFFE0E0E0); // Medium-light gray
  static const Color grey500 = Color(0xFF999999); // Medium gray
  static const Color grey600 = Color(0xFF666666); // Dark gray

  // Surface variants
  static const Color surfaceGrey =
      surfaceContainer; // Use consistent surface container

  // Accent and info colors - monochrome with branding accents
  static const Color accent = Color(0xFF000000); // Black as primary accent
  static const Color info = Color(0xFF000000); // Black for info elements

  // Branding border colors - ONLY for card borders and profile picture borders
  static const Color cardBorderYellow = brandingYellow; // Yellow border accent
  static const Color cardBorderGreen = brandingGreen; // Green border accent
  static const Color profileBorderYellow =
      brandingYellow; // Yellow profile border
  static const Color profileBorderGreen = brandingGreen; // Green profile border

  // Material 3 Color Schemes
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
    surfaceContainerHighest: surfaceContainer,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF1A2026), // Dark blue-gray inverse
    onInverseSurface: Color(0xFFE8F0F7), // Light blue-gray on inverse
    inversePrimary: Color(0xFF66D9FF), // Light arctic cyan inverse
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
    tertiary: tertiaryDark,
    onTertiary: onTertiaryDark,
    tertiaryContainer: tertiaryContainerDark,
    onTertiaryContainer: onTertiaryContainerDark,
    error: errorDark,
    onError: onErrorDark,
    errorContainer: errorContainerDark,
    onErrorContainer: onErrorContainerDark,
    surface: surfaceDark,
    onSurface: onSurfaceDark,
    surfaceContainerHighest: surfaceContainerDark,
    onSurfaceVariant: onSurfaceVariantDark,
    outline: outlineDark,
    outlineVariant: outlineVariantDark,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE8F0F7), // Light blue-gray inverse surface
    onInverseSurface: Color(0xFF1A2026), // Dark blue-gray on inverse
    inversePrimary: arcticCyan, // Arctic cyan inverse primary
    surfaceTint: primaryDark,
  );

  // ========================================
  // HELPER METHODS & COLOR SYSTEM UTILITIES
  // ========================================

  /// Get status color based on order/task status
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'waiting':
        return pending;
      case 'accepted':
      case 'confirmed':
        return accepted;
      case 'in_progress':
      case 'active':
      case 'ongoing':
        return inProgress;
      case 'completed':
      case 'delivered':
      case 'finished':
        return completed;
      case 'cancelled':
      case 'rejected':
      case 'failed':
        return cancelled;
      default:
        return onSurfaceVariant;
    }
  }

  /// Get functional color based on role/type
  static Color getFunctionalColor(String type) {
    switch (type.toLowerCase()) {
      case 'delivery':
      case 'driver':
        return delivery;
      case 'pickup':
      case 'collection':
        return pickup;
      case 'restaurant':
      case 'merchant':
      case 'vendor':
        return restaurant;
      case 'customer':
      case 'client':
      case 'user':
        return customer;
      default:
        return primary;
    }
  }

  /// Get semantic color with opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }

  /// Color system validation - ensures proper contrast ratios
  static bool validateContrast(Color foreground, Color background) {
    // Simple luminance-based contrast check
    final fgLuminance = foreground.computeLuminance();
    final bgLuminance = background.computeLuminance();
    final contrast = (fgLuminance + 0.05) / (bgLuminance + 0.05);
    return contrast >= 4.5; // WCAG AA standard
  }
}
