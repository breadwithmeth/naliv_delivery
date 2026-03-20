import 'package:flutter/widgets.dart';

/// Lightweight responsive scaling utility.
///
/// All hard-coded dimensions in the app were authored for a **375 pt** design
/// width.  [Responsive] maps those values to the actual screen width so that
/// the UI looks proportionally the same on every device.
///
/// **Design width 410** is used intentionally: it is slightly wider than the
/// original 375-based values, which makes every element ~5-9 % *smaller* on
/// most phones — producing a more compact, modern feel and directly addressing
/// the "too big on S25 Ultra" feedback.
///
/// ### Usage
///
/// Call [Responsive.init] once near the top of the widget tree (e.g.
/// `MaterialApp.builder`).  Then use the [num] extensions everywhere:
///
/// ```dart
/// fontSize: 16.sp,
/// padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 8.s),
/// borderRadius: BorderRadius.circular(12.s),
/// SizedBox(height: 10.s),
/// ```
class Responsive {
  Responsive._();

  static const double _designWidth = 410.0;

  static double _scale = 1.0;
  static double _fontScale = 1.0;

  /// Must be called once with a [BuildContext] that has a valid [MediaQuery].
  static void init(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    _scale = (width / _designWidth).clamp(0.78, 1.12);
    _fontScale = (width / _designWidth).clamp(0.82, 1.06);
  }

  /// Scale a layout dimension (padding, margin, width, height, icon size).
  static double s(double value) => value * _scale;

  /// Scale a font size — slightly less aggressive clamping to keep text
  /// readable on small screens while still shrinking on larger ones.
  static double sp(double value) {
    final scaled = value * _fontScale;
    // Never let any font go below 9 logical pixels.
    return scaled < 9.0 ? 9.0 : scaled;
  }
}

/// Convenience extensions so you can write `16.s` / `14.sp` directly on
/// numeric literals.
extension ResponsiveNum on num {
  /// Scaled layout dimension.
  double get s => Responsive.s(toDouble());

  /// Scaled font size.
  double get sp => Responsive.sp(toDouble());
}
