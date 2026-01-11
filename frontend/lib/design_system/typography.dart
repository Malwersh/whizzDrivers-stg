// Material Design 3 Typography System for Hadhir Driver App
import 'package:flutter/material.dart';

/// Material Design 3 typography following the Material You type scale
/// Optimized for Arabic and English content with clear, compact design
class HadhirTypography {
  // Font families
  static const String primaryFont = 'Inter'; // Clean, modern, multilingual
  static const String arabicFont = 'Tajawal'; // Arabic-optimized

  // Material 3 Type Scale
  static const TextTheme textTheme = TextTheme(
    // Display styles (Large headlines, hero text)
    displayLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 57,
      height: 1.12,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
    ),
    displayMedium: TextStyle(
      fontFamily: primaryFont,
      fontSize: 45,
      height: 1.16,
      fontWeight: FontWeight.w400,
    ),
    displaySmall: TextStyle(
      fontFamily: primaryFont,
      fontSize: 36,
      height: 1.22,
      fontWeight: FontWeight.w400,
    ),

    // Headline styles (Section headers)
    headlineLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 32,
      height: 1.25,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: TextStyle(
      fontFamily: primaryFont,
      fontSize: 28,
      height: 1.29,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: TextStyle(
      fontFamily: primaryFont,
      fontSize: 24,
      height: 1.33,
      fontWeight: FontWeight.w600,
    ),

    // Title styles (Card headers, dialog titles)
    titleLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 22,
      height: 1.27,
      fontWeight: FontWeight.w500,
    ),
    titleMedium: TextStyle(
      fontFamily: primaryFont,
      fontSize: 16,
      height: 1.50,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
    ),
    titleSmall: TextStyle(
      fontFamily: primaryFont,
      fontSize: 14,
      height: 1.43,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),

    // Label styles (Buttons, tabs, chips)
    labelLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 14,
      height: 1.43,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontFamily: primaryFont,
      fontSize: 12,
      height: 1.33,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
    labelSmall: TextStyle(
      fontFamily: primaryFont,
      fontSize: 11,
      height: 1.45,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),

    // Body styles (Main content)
    bodyLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 16,
      height: 1.50,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
    ),
    bodyMedium: TextStyle(
      fontFamily: primaryFont,
      fontSize: 14,
      height: 1.43,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
    ),
    bodySmall: TextStyle(
      fontFamily: primaryFont,
      fontSize: 12,
      height: 1.33,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
    ),
  );

  // Arabic-specific text styles
  static const TextTheme arabicTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: arabicFont,
      fontSize: 57,
      height: 1.2,
      fontWeight: FontWeight.w400,
    ),
    displayMedium: TextStyle(
      fontFamily: arabicFont,
      fontSize: 45,
      height: 1.2,
      fontWeight: FontWeight.w400,
    ),
    displaySmall: TextStyle(
      fontFamily: arabicFont,
      fontSize: 36,
      height: 1.3,
      fontWeight: FontWeight.w400,
    ),
    headlineLarge: TextStyle(
      fontFamily: arabicFont,
      fontSize: 32,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: TextStyle(
      fontFamily: arabicFont,
      fontSize: 28,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: TextStyle(
      fontFamily: arabicFont,
      fontSize: 24,
      height: 1.4,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: TextStyle(
      fontFamily: arabicFont,
      fontSize: 22,
      height: 1.3,
      fontWeight: FontWeight.w500,
    ),
    titleMedium: TextStyle(
      fontFamily: arabicFont,
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(
      fontFamily: arabicFont,
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w600,
    ),
    labelLarge: TextStyle(
      fontFamily: arabicFont,
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: TextStyle(
      fontFamily: arabicFont,
      fontSize: 12,
      height: 1.4,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: TextStyle(
      fontFamily: arabicFont,
      fontSize: 11,
      height: 1.5,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      fontFamily: arabicFont,
      fontSize: 16,
      height: 1.6,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: TextStyle(
      fontFamily: arabicFont,
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: TextStyle(
      fontFamily: arabicFont,
      fontSize: 12,
      height: 1.4,
      fontWeight: FontWeight.w400,
    ),
  );

  // Custom semantic styles for specific use cases
  static const TextStyle cardTitle = TextStyle(
    fontFamily: primaryFont,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontFamily: primaryFont,
    fontSize: 14,
    height: 1.43,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle buttonText = TextStyle(
    fontFamily: primaryFont,
    fontSize: 14,
    height: 1.43,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const TextStyle inputLabel = TextStyle(
    fontFamily: primaryFont,
    fontSize: 12,
    height: 1.33,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );

  static const TextStyle inputText = TextStyle(
    fontFamily: primaryFont,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
  );

  static const TextStyle statusText = TextStyle(
    fontFamily: primaryFont,
    fontSize: 12,
    height: 1.33,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );

  static const TextStyle captionText = TextStyle(
    fontFamily: primaryFont,
    fontSize: 11,
    height: 1.45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
  );
}
