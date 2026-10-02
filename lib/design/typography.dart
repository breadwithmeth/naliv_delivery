/// Readable typography for the Градусы24 design system.
///
/// Consumer text deliberately uses 12–16 px roles instead of the reference's
/// 6–10 px metadata. Layouts retain the OS text scaler rather than shrink text.
/// The bundled variable font uses both weight and optical-size axes.
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

  /// Auxiliary metadata that is not a primary action or product name.
  static final TextStyle caption = base(size: 12);
  static final TextStyle captionMedium = base(size: 12, weight: 500);
  static final TextStyle label = base(size: 12);
  static final TextStyle labelMedium = base(size: 12, weight: 500);
  static final TextStyle labelSemibold = base(size: 12, weight: 600);
  static final TextStyle labelBold = base(size: 12, weight: 700);

  /// Readable previous price.
  static final TextStyle strikethrough =
      base(size: 12, decoration: TextDecoration.lineThrough);

  /// Secondary content, including store details and product names.
  static final TextStyle bodySmall = base(size: 14);
  static final TextStyle bodySmallSemibold = base(size: 14, weight: 600);
  static final TextStyle bodySmallBold = base(size: 14, weight: 700);
  static final TextStyle bodySmallMedium = base(size: 14, weight: 500);
  static final TextStyle bodySmallTight = base(size: 14, height: 1);

  /// Primary body text and action labels.
  static final TextStyle body = base(size: 16);
  static final TextStyle bodyMedium = base(size: 16, weight: 500);
  static final TextStyle bodyBold = base(size: 16, weight: 700);
  static final TextStyle bodyLight = base(size: 16, weight: 300);

  static final TextStyle titleRegular = base(size: 16);
  static final TextStyle titleMedium = base(size: 16, weight: 500);
  static final TextStyle title = base(size: 16, weight: 700);
  static final TextStyle headline = base(size: 20, weight: 700);
  static final TextStyle headlineMedium = base(size: 20, weight: 500);
  static final TextStyle display = base(size: 24, weight: 900);
  static final TextStyle displayBold = base(size: 24, weight: 700);
  static final TextStyle displayLarge = base(size: 32, weight: 900);
  static final TextStyle displayLargeRegular = base(size: 32, weight: 700);

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
