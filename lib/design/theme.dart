/// Theme assembly: turns [AppPalette] + [AppTypography] into the two `ThemeData`s the app
/// ships (the design defines a full dark *and* light set, and the product follows the OS
/// setting).
library;

import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, AppPalette.light);

  static ThemeData dark() => _build(Brightness.dark, AppPalette.dark);

  static ThemeData _build(Brightness brightness, AppPalette palette) {
    final text = AppTypography.textTheme(palette);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: palette.accent,
      onPrimary: palette.textOnAccent,
      primaryContainer: palette.accentFaint,
      onPrimaryContainer: palette.textPrimary,
      secondary: palette.gold,
      onSecondary: palette.background,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      surfaceContainerHighest: palette.surfaceMuted,
      onSurfaceVariant: palette.textSecondary,
      error: palette.error,
      onError: palette.textOnAccent,
      outline: palette.divider,
      shadow: palette.shadow,
      inverseSurface: palette.surfaceInverse,
      onInverseSurface: palette.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      splashFactory: InkSparkle.splashFactory,
      extensions: [palette],
      textTheme: text,
      primaryTextTheme: text,
      dividerColor: palette.divider,
      dividerTheme:
          DividerThemeData(color: palette.divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle:
            AppTypography.title.copyWith(color: palette.textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.accent,
        unselectedItemColor: palette.textSecondary,
      ),
      // The design has no uppercase/tracking text anywhere: Material's defaults would
      // silently restyle buttons and labels, so they are neutralised here.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.textOnAccent,
          disabledBackgroundColor: palette.accentSoft,
          disabledForegroundColor: palette.textOnAccent,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
          textStyle: AppTypography.title,
          minimumSize: const Size(0, AppSpacing.touchTarget),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.textOnAccent,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
          textStyle: AppTypography.title,
          minimumSize: const Size(0, AppSpacing.touchTarget),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.divider),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
          textStyle: AppTypography.bodyMedium,
          minimumSize: const Size(0, AppSpacing.touchTarget),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          textStyle: AppTypography.bodyMedium,
        ),
      ),
      iconTheme: IconThemeData(color: palette.textPrimary, size: 24),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.xlAll),
        titleTextStyle:
            AppTypography.title.copyWith(color: palette.textPrimary),
        contentTextStyle:
            AppTypography.body.copyWith(color: palette.textPrimary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
        showDragHandle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        hintStyle:
            AppTypography.bodyLight.copyWith(color: palette.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xl,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadii.lgAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadii.lgAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadii.lgAll,
          borderSide: BorderSide.none,
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadii.lgAll,
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: palette.accent,
        labelStyle:
            AppTypography.bodySmallMedium.copyWith(color: palette.textPrimary),
        secondaryLabelStyle:
            AppTypography.bodySmallMedium.copyWith(color: palette.textOnAccent),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceInverse,
        contentTextStyle:
            AppTypography.bodyMedium.copyWith(color: palette.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.accent),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.textOnAccent
              : palette.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent
              : palette.surface,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textPrimary,
        textColor: palette.textPrimary,
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      ),
    );
  }
}

/// Convenience accessor: `context.palette.accent` instead of a `Theme.of` lookup chain.
extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;

  TextTheme get texts => Theme.of(this).textTheme;
}
