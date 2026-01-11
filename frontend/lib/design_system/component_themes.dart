// Material Design 3 Component Themes for Hadhir Driver App
import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

/// Material Design 3 component themes following Material You guidelines
/// Compact, clear, and consistent component styling
class ComponentThemes {
  // App Bar Theme
  static AppBarTheme appBarTheme(ColorScheme colorScheme) {
    return AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: colorScheme.shadow,
      surfaceTintColor: colorScheme.surfaceTint,
      titleTextStyle: HadhirTypography.textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
      toolbarHeight: 56,
      centerTitle: true,
      iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
    );
  }

  // Elevated Button Theme
  static ElevatedButtonThemeData elevatedButtonTheme(ColorScheme colorScheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        disabledBackgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
        elevation: 1,
        shadowColor: colorScheme.shadow,
        surfaceTintColor: colorScheme.surfaceTint,
        minimumSize: const Size(64, 40),
        maximumSize: const Size.fromHeight(40),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: HadhirTypography.buttonText.copyWith(
          color: colorScheme.onPrimary,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  // Outlined Button Theme
  static OutlinedButtonThemeData outlinedButtonTheme(ColorScheme colorScheme) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
        minimumSize: const Size(64, 40),
        maximumSize: const Size.fromHeight(40),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: colorScheme.outline, width: 1),
        textStyle: HadhirTypography.buttonText.copyWith(
          color: colorScheme.primary,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  // Text Button Theme
  static TextButtonThemeData textButtonTheme(ColorScheme colorScheme) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: HadhirTypography.buttonText.copyWith(
          color: colorScheme.primary,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  // Floating Action Button Theme
  static FloatingActionButtonThemeData fabTheme(ColorScheme colorScheme) {
    return FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      elevation: 6,
      focusElevation: 6,
      hoverElevation: 8,
      highlightElevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      sizeConstraints: const BoxConstraints.tightFor(width: 56, height: 56),
    );
  }

  // Card Theme
  static CardTheme cardTheme(ColorScheme colorScheme) {
    return CardTheme(
      color: colorScheme.surfaceContainerLow,
      surfaceTintColor: colorScheme.surfaceTint,
      shadowColor: colorScheme.shadow,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(4),
      clipBehavior: Clip.antiAlias,
    );
  }

  // Input Decoration Theme
  static InputDecorationTheme inputDecorationTheme(ColorScheme colorScheme) {
    return InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.outline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.outline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: colorScheme.onSurface.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      labelStyle: HadhirTypography.inputLabel.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      hintStyle: HadhirTypography.inputText.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      errorStyle: HadhirTypography.captionText.copyWith(
        color: colorScheme.error,
      ),
      floatingLabelStyle: HadhirTypography.inputLabel.copyWith(
        color: colorScheme.primary,
      ),
    );
  }

  // Bottom Navigation Bar Theme (Legacy)
  static BottomNavigationBarThemeData bottomNavTheme(ColorScheme colorScheme) {
    return BottomNavigationBarThemeData(
      backgroundColor: HadhirColors.primary,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.black.withOpacity(0.6),
      selectedLabelStyle: HadhirTypography.textTheme.labelSmall,
      unselectedLabelStyle: HadhirTypography.textTheme.labelSmall,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    );
  }

  // Navigation Bar Theme (Material 3)
  static NavigationBarThemeData navigationBarTheme(ColorScheme colorScheme) {
    return NavigationBarThemeData(
      backgroundColor: HadhirColors.primary,
      surfaceTintColor: HadhirColors.primary,
      indicatorColor: Colors.white,
      height: 80,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return HadhirTypography.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface,
          );
        }
        return HadhirTypography.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(
            color: colorScheme.onSecondaryContainer,
            size: 24,
          );
        }
        return IconThemeData(color: colorScheme.onSurfaceVariant, size: 24);
      }),
    );
  }

  // Snack Bar Theme
  static SnackBarThemeData snackBarTheme(ColorScheme colorScheme) {
    return SnackBarThemeData(
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: HadhirTypography.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      actionTextColor: colorScheme.inversePrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      behavior: SnackBarBehavior.floating,
      elevation: 6,
    );
  }

  // Dialog Theme
  static DialogTheme dialogTheme(ColorScheme colorScheme) {
    return DialogTheme(
      backgroundColor: colorScheme.surfaceContainerHigh,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 6,
      shadowColor: colorScheme.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: HadhirTypography.textTheme.headlineSmall?.copyWith(
        color: colorScheme.onSurface,
      ),
      contentTextStyle: HadhirTypography.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  // Bottom Sheet Theme
  static BottomSheetThemeData bottomSheetTheme(ColorScheme colorScheme) {
    return BottomSheetThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 1,
      modalElevation: 1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxWidth: 640),
    );
  }

  // Chip Theme
  static ChipThemeData chipTheme(ColorScheme colorScheme) {
    return ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      deleteIconColor: colorScheme.onSurfaceVariant,
      disabledColor: colorScheme.onSurface.withValues(alpha: 0.12),
      selectedColor: colorScheme.secondaryContainer,
      secondarySelectedColor: colorScheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: HadhirTypography.textTheme.labelLarge?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      secondaryLabelStyle: HadhirTypography.textTheme.labelLarge?.copyWith(
        color: colorScheme.onSecondaryContainer,
      ),
      brightness: colorScheme.brightness,
    );
  }

  // Divider Theme
  static DividerThemeData dividerTheme(ColorScheme colorScheme) {
    return DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    );
  }
}
