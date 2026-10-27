import 'package:flutter/material.dart';

/// The palette of the web app (Ant Design defaults with a #1677ff primary).
class AppColors {
  const AppColors._();

  static const primary = Color(0xFF1677FF);
  static const background = Color(0xFFF5F5F5);
  static const surface = Colors.white;
  static const border = Color(0xFFF0F0F0);
  static const rowBorder = Color(0xFFE8E8E8);
  static const dashedBorder = Color(0xFFD9D9D9);
  static const selectedBackground = Color(0xFFF0F7FF);
  static const secondaryText = Color(0xFF8C8C8C);
  static const disabledText = Color(0xFFBFBFBF);
  static const danger = Color(0xFFFF4D4F);
  static const success = Color(0xFF52C41A);
  static const warning = Color(0xFFFAAD14);
}

const double kRadius = 8;

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    surface: AppColors.surface,
  ).copyWith(primary: AppColors.primary, error: AppColors.danger, surfaceContainerLowest: AppColors.background);
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(kRadius),
    borderSide: const BorderSide(color: AppColors.dashedBorder),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: outline,
      enabledBorder: outline,
      focusedBorder: outline.copyWith(borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: outline.copyWith(borderSide: const BorderSide(color: AppColors.danger)),
      focusedErrorBorder: outline.copyWith(borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius))),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        side: const BorderSide(color: AppColors.dashedBorder),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.selectedBackground,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
    ),
  );
}

/// Text styles that mirror Ant Design's `Typography.Text type="secondary"`.
class AppText {
  const AppText._();

  static const secondary = TextStyle(color: AppColors.secondaryText);
  static const secondarySmall = TextStyle(color: AppColors.secondaryText, fontSize: 12);
}
