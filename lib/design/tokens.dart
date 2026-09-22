/// Design tokens for the Градусы24 redesign.
///
/// Every value here was measured from the design file (`Design System (Dark)` +
/// `Design System (Light)`, 212 frames, 375 × 812) with `tool/design_report.dart`; the
/// frequency of each value is what decided whether it earned a token. Nothing is invented,
/// and nothing that appears once became part of the scale.
///
/// Regenerate the source data with:
///   dart run tool/figma_spec.dart spec && dart run tool/design_report.dart
library;

import 'package:flutter/material.dart';

/// Layout rhythm. The design's auto-layout gaps cluster on this scale
/// (12 × 791, 2 × 778, 10 × 711, 6 × 546, 8 × 447, 16 × 415, 4 × 351, 14 × 171, 24 × 117).
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double xxl = 14;
  static const double xxxl = 16;
  static const double huge = 24;

  /// Horizontal page gutter, measured from the frames' content edges.
  static const double gutter = 12;

  /// Minimum touch target. The design's own controls are not smaller than this.
  static const double touchTarget = 44;
}

/// Corner radii. The design uses 10 for its standard card (1837 nodes), 100 for pills
/// (896), then 4 / 6 / 8 for inputs, chips and badges.
abstract final class AppRadii {
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double xxl = 16;
  static const double pill = 100;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Semantic colours, resolved per brightness.
///
/// Palette evidence (dark / light occurrence counts):
///   #F16800 × 1688 / 1774   accent
///   #FFFFFF × 4945 / 3086   (text on dark, background on light)
///   #000000 × 1184 / 3046   (background on dark, text on light)
///   #676767 × 1152 / 1118   secondary text
///   #141414 ×  354 /   36   dark surface          #F2F2F2 × 390 light surface
///   #E0AB62 ×  383 /  371   gold (bonus)
///   #880514 ×  229 /  227   brand red (promo)
///   #4D2161 ×  212 /  212   purple (promo)
///   #FF3636 ×   40 /    4   error
///   #7EF34B / #64DC30       success / order-status green
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceInverse,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnAccent,
    required this.accent,
    required this.accentSoft,
    required this.accentFaint,
    required this.gold,
    required this.brandRed,
    required this.purple,
    required this.success,
    required this.error,
    required this.divider,
    required this.glassTint,
    required this.shadow,
  });

  /// Scaffold background.
  final Color background;

  /// Cards, sheets, rows that need containment.
  final Color surface;

  /// One step away from [surface] (nested rows, inactive chips).
  final Color surfaceMuted;

  /// Inverted container (e.g. a chip that must stand out on [surface]).
  final Color surfaceInverse;

  final Color textPrimary;
  final Color textSecondary;

  /// Text/icons drawn on top of [accent].
  final Color textOnAccent;

  final Color accent;

  /// Accent at the design's 75% opacity — used for disabled-by-default actions.
  final Color accentSoft;

  /// Accent at 15–25% — selected chips, subtle fills.
  final Color accentFaint;

  /// Bonuses.
  final Color gold;

  /// Promotion banners.
  final Color brandRed;
  final Color purple;

  final Color success;
  final Color error;

  /// 1px separators.
  final Color divider;

  /// Tint layered over blurred content in glass panels (`#EDEDED @ 17%` on dark).
  final Color glassTint;

  /// Shadow colour for [AppShadows].
  final Color shadow;

  static const AppPalette dark = AppPalette(
    background: Color(0xFF000000),
    surface: Color(0xFF141414),
    surfaceMuted: Color(0xFF1E1E1E),
    surfaceInverse: Color(0xFF0F0F0F),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF676767),
    textOnAccent: Color(0xFFFFFFFF),
    accent: Color(0xFFF16800),
    accentSoft: Color(0xBFF16800),
    accentFaint: Color(0x26F16800),
    gold: Color(0xFFE0AB62),
    brandRed: Color(0xFF880514),
    purple: Color(0xFF4D2161),
    success: Color(0xFF7EF34B),
    error: Color(0xFFFF3636),
    divider: Color(0xFF1E1E1E),
    glassTint: Color(0x2BEDEDED),
    shadow: Color(0x29000000),
  );

  static const AppPalette light = AppPalette(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF2F2F2),
    surfaceMuted: Color(0xFFF9F9F9),
    surfaceInverse: Color(0xFF191919),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF676767),
    textOnAccent: Color(0xFFFFFFFF),
    accent: Color(0xFFF16800),
    accentSoft: Color(0xBFF16800),
    accentFaint: Color(0x26F16800),
    gold: Color(0xFFE0AB62),
    brandRed: Color(0xFF880514),
    purple: Color(0xFF4D2161),
    success: Color(0xFF64DC30),
    error: Color(0xFFFF3636),
    divider: Color(0xFFEDEDED),
    glassTint: Color(0x29FFFFFF),
    shadow: Color(0x29000000),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceInverse,
    Color? textPrimary,
    Color? textSecondary,
    Color? textOnAccent,
    Color? accent,
    Color? accentSoft,
    Color? accentFaint,
    Color? gold,
    Color? brandRed,
    Color? purple,
    Color? success,
    Color? error,
    Color? divider,
    Color? glassTint,
    Color? shadow,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceInverse: surfaceInverse ?? this.surfaceInverse,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentFaint: accentFaint ?? this.accentFaint,
      gold: gold ?? this.gold,
      brandRed: brandRed ?? this.brandRed,
      purple: purple ?? this.purple,
      success: success ?? this.success,
      error: error ?? this.error,
      divider: divider ?? this.divider,
      glassTint: glassTint ?? this.glassTint,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      surfaceInverse: mix(surfaceInverse, other.surfaceInverse),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textOnAccent: mix(textOnAccent, other.textOnAccent),
      accent: mix(accent, other.accent),
      accentSoft: mix(accentSoft, other.accentSoft),
      accentFaint: mix(accentFaint, other.accentFaint),
      gold: mix(gold, other.gold),
      brandRed: mix(brandRed, other.brandRed),
      purple: mix(purple, other.purple),
      success: mix(success, other.success),
      error: mix(error, other.error),
      divider: mix(divider, other.divider),
      glassTint: mix(glassTint, other.glassTint),
      shadow: mix(shadow, other.shadow),
    );
  }
}

/// Elevation. The design's shadows are almost all one recipe — `radius 8, offset (0, 4)`
/// (1417 of 1706 drop shadows); the rest are one-off illustration effects and stay inline.
abstract final class AppShadows {
  /// The design's single shadow recipe: `#000000 @ 16 %`, blur 8, offset (0, 4). It is what
  /// separates a floating control from the page — in the light theme the 40 px discs are
  /// `#FFFFFF @ 75 %` on a white background and are legible only because of this shadow.
  ///
  /// The frames give it to the discs and to the round cart button; the pill-shaped CTAs carry
  /// none, so it is applied per widget rather than globally.
  static List<BoxShadow> control(AppPalette palette) => [
        BoxShadow(
          color: palette.shadow,
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];
}
