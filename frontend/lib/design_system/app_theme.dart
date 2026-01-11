import 'package:flutter/material.dart';
import 'package:wizz_driver/design_system/colors.dart';
import 'package:wizz_driver/design_system/design_tokens.dart';
import 'package:wizz_driver/design_system/theme_extensions.dart';

/// Arctic Cyan Material 3 Theme System
/// Elegant, unified, and future-ready theme implementation
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: HadhirColors.lightColorScheme,
      fontFamily: 'Tajawal',
      
      // Monochrome theme extensions
      extensions: const <ThemeExtension<dynamic>>[ArcticCyanColors.light],

      // Scaffold Theme - Pure white monochrome background
      scaffoldBackgroundColor: Colors.white,

      // App Bar Theme - Monochrome system
      appBarTheme: AppBarTheme(
        backgroundColor: HadhirColors.lightColorScheme.surface,
        foregroundColor: HadhirColors.lightColorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: true,
        surfaceTintColor: HadhirColors.primary,
        iconTheme: IconThemeData(
          color: HadhirColors.lightColorScheme.onSurface,
          size: DesignTokens.iconSizeMedium,
        ),
      ),

      // Button Themes - Elegant Arctic Cyan styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HadhirColors.lightColorScheme.primary,
          foregroundColor: HadhirColors.lightColorScheme.onPrimary,
          elevation: 2,
          shadowColor: HadhirColors.arcticCyan.withOpacity(0.3),
          minimumSize: const Size(64, DesignTokens.buttonHeightMedium),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HadhirColors.lightColorScheme.primary,
          foregroundColor: HadhirColors.lightColorScheme.onPrimary,
          minimumSize: const Size(64, DesignTokens.buttonHeightMedium),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          ),
        ),
      ),

      // Input Theme - New color system focus styling
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          borderSide: BorderSide(color: HadhirColors.lightColorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          borderSide: const BorderSide(
            color: HadhirColors.primary,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: HadhirColors.lightColorScheme.surfaceContainerHighest,
      ),

      // Card Theme - Monochrome cards with subtle shadows
      cardTheme: CardThemeData(
        elevation: 0, // Remove elevation for clean look
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          side: BorderSide(
            color: HadhirColors.brandingYellow.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: HadhirColors.secondary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: HadhirColors.darkColorScheme,
      fontFamily: 'Tajawal',
      
      // Arctic Cyan theme extensions
      extensions: const <ThemeExtension<dynamic>>[ArcticCyanColors.dark],

      // Scaffold Theme - Moonstone Mist background
      scaffoldBackgroundColor: HadhirColors.background,

      // App Bar Theme - Arctic Cyan styled
      appBarTheme: AppBarTheme(
        backgroundColor: HadhirColors.darkColorScheme.surface,
        foregroundColor: HadhirColors.darkColorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: true,
        surfaceTintColor: HadhirColors.arcticCyan,
        iconTheme: IconThemeData(
          color: HadhirColors.darkColorScheme.onSurface,
          size: DesignTokens.iconSizeMedium,
        ),
      ),

      // Button Themes - Elegant Arctic Cyan styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HadhirColors.darkColorScheme.primary,
          foregroundColor: HadhirColors.darkColorScheme.onPrimary,
          elevation: 2,
          shadowColor: HadhirColors.arcticCyan.withOpacity(0.3),
          minimumSize: const Size(64, DesignTokens.buttonHeightMedium),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HadhirColors.darkColorScheme.primary,
          foregroundColor: HadhirColors.darkColorScheme.onPrimary,
          minimumSize: const Size(64, DesignTokens.buttonHeightMedium),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          ),
        ),
      ),

      // Input Theme - Arctic Cyan focus styling
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          borderSide: BorderSide(color: HadhirColors.darkColorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          borderSide: const BorderSide(
            color: HadhirColors.arcticCyan,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: HadhirColors.darkColorScheme.surfaceContainerHighest,
      ),

      // Card Theme - Elevated surfaces
      cardTheme: CardThemeData(
        elevation: DesignTokens.elevationMedium,
        surfaceTintColor: HadhirColors.arcticCyan,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        ),
      ),
      
      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: HadhirColors.arcticCyan,
        foregroundColor: HadhirColors.obsidianCore,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        ),
      ),
    );
  }
}
