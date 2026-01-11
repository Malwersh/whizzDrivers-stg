/// Design tokens for consistent spacing, sizing, and other design properties
class DesignTokens {
  // Spacing system (8px base)
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;
  static const double spacingXXLarge = 48.0;

  // Border radius system
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusCircular = 50.0;

  // Elevation system
  static const double elevationNone = 0.0;
  static const double elevationSmall = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationLarge = 8.0;
  static const double elevationXLarge = 12.0;

  // Icon sizes
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;

  // Typography sizes
  static const double fontSizeCaption = 12.0;
  static const double fontSizeBody = 14.0;
  static const double fontSizeButton = 16.0;
  static const double fontSizeHeading = 18.0;
  static const double fontSizeTitle = 20.0;
  static const double fontSizeDisplay = 24.0;

  // Animation durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Button heights
  static const double buttonHeightSmall = 36.0;
  static const double buttonHeightMedium = 48.0;
  static const double buttonHeightLarge = 56.0;

  // Container constraints
  static const double maxContentWidth = 440.0;
  static const double minTouchTarget = 44.0;

  // Map specific tokens
  static const double mapControlSize = 48.0;
  static const double mapMarkerSize = 32.0;
  static const double mapZoomLevel = 15.0;
  static const double mapCoverageRadius = 500.0;

  // Card specific tokens
  static const double cardPadding = 16.0;
  static const double cardMargin = 8.0;
  static const double cardElevation = 4.0;

  // Status indicator sizes
  static const double statusIndicatorSmall = 8.0;
  static const double statusIndicatorMedium = 12.0;
  static const double statusIndicatorLarge = 16.0;
}
