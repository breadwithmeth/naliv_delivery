/// Typography for the Градусы24 redesign.
///
/// The design uses one family — TikTok Sans, weights 300–900, sizes 6–32, line height
/// ×1.3 almost everywhere. Roles below mirror the styles that actually dominate the 212
/// frames (counts in comments), so a screen can always pick an existing role instead of
/// inventing a size.
///
/// The family ships as a **variable** font. The optical-size axis matters: measured against
/// the file's own text boxes, the 16pt static instances drift −6% wide at 8px and +1.7% at
/// 20px, while `opsz = fontSize` reproduces the design within 1%. [AppTypography.base]
/// therefore always sets both `wght` and `opsz`.
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class AppTypography {
  /// Family name registered in `pubspec.yaml`.
  static const String family = 'TikTokSans';

  /// The single place a TikTok Sans style is constructed.
  ///
  /// [size] drives both the font size and the `opsz` axis (clamped to the font's 12–52
  /// range). [weight] drives the `wght` axis, and is also reported through `fontWeight` so
  /// layout, semantics and fallbacks behave sensibly.
  static TextStyle base({
    required double size,
    int weight = 400,
    double height = 1.3,
    double? letterSpacing,
    Color? color,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      decoration: decoration,
      fontVariations: [
        FontVariation('wght', weight.toDouble()),
        FontVariation('opsz', size.clamp(12, 52)),
      ],
    );
  }

  // --- Roles ---------------------------------------------------------------------------
  // name                          size/weight  design evidence
  /// "Италия", "0,5 л" — the smallest secondary line.
  static TextStyle get caption => base(size: 8);

  /// Discount / bonus badges.
  static TextStyle get captionMedium => base(size: 8, weight: 500);

  /// The workhorse secondary text (596 uses).
  static TextStyle get label => base(size: 10);

  static TextStyle get labelMedium => base(size: 10, weight: 500);
  static TextStyle get labelSemibold => base(size: 10, weight: 600);

  /// Pill and badge labels ("История").
  static TextStyle get labelBold => base(size: 10.8, weight: 700);

  /// Old price, struck through (230 uses).
  static TextStyle get strikethrough =>
      base(size: 8, decoration: TextDecoration.lineThrough);

  static TextStyle get bodySmall => base(size: 12);

  static TextStyle get bodySmallSemibold => base(size: 12, weight: 600);

  /// Store name and other emphasised 12px labels (72 uses).
  static TextStyle get bodySmallBold => base(size: 12, weight: 700);

  /// Tab labels, section "Все" pills (230 uses).
  static TextStyle get bodySmallMedium => base(size: 12, weight: 500);

  /// Tight single-line labels (numbers in steppers, 276 uses of lh×1.0 at 12px).
  static TextStyle get bodySmallTight => base(size: 12, height: 1);

  static TextStyle get body => base(size: 14);

  /// Buttons, list rows (370 uses).
  static TextStyle get bodyMedium => base(size: 14, weight: 500);

  static TextStyle get bodyBold => base(size: 14, weight: 700);

  /// Search placeholder ("Найти любимый напиток…").
  static TextStyle get bodyLight => base(size: 14, weight: 300);

  static TextStyle get titleRegular => base(size: 16);
  static TextStyle get titleMedium => base(size: 16, weight: 500);

  /// Card and list titles (449 uses — the most common heading).
  static TextStyle get title => base(size: 16, weight: 700);

  /// Section headers ("Вам также может понравиться").
  static TextStyle get headline => base(size: 20, weight: 700);
  static TextStyle get headlineMedium => base(size: 20, weight: 500);

  /// Screen titles and hero prices.
  static TextStyle get display => base(size: 24, weight: 900);
  static TextStyle get displayBold => base(size: 24, weight: 700);

  /// Onboarding and empty-state headlines.
  static TextStyle get displayLarge => base(size: 32, weight: 900);
  static TextStyle get displayLargeRegular => base(size: 32, weight: 700);

  /// Material text theme wired from the roles above, coloured for [palette].
  static TextTheme textTheme(AppPalette palette) {
    final primary = palette.textPrimary;
    final secondary = palette.textSecondary;
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: primary),
      displayMedium: display.copyWith(color: primary),
      displaySmall: displayBold.copyWith(color: primary),
      headlineLarge: headline.copyWith(color: primary),
      headlineMedium: headline.copyWith(color: primary),
      headlineSmall: headlineMedium.copyWith(color: primary),
      titleLarge: title.copyWith(color: primary),
      titleMedium: titleMedium.copyWith(color: primary),
      titleSmall: titleRegular.copyWith(color: primary),
      bodyLarge: body.copyWith(color: primary),
      bodyMedium: bodyMedium.copyWith(color: primary),
      bodySmall: bodySmall.copyWith(color: secondary),
      labelLarge: bodyMedium.copyWith(color: primary),
      labelMedium: label.copyWith(color: secondary),
      labelSmall: caption.copyWith(color: secondary),
    );
  }
}
