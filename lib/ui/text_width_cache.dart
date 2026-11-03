import 'package:flutter/widgets.dart';

/// Single-line text widths memoised by text, style and effective font size.
///
/// Layout code that only needs to know whether a short, fixed-style label fits (a button
/// caption, a quantity, a price) would otherwise run a [TextPainter] layout for every card
/// or row on every rebuild. The same label at the same scaled size always measures the
/// same, so each distinct combination is laid out once.
abstract final class TextWidthCache {
  static const int _maxEntries = 512;
  static final Map<(String, TextStyle, double), double> _widths = {};

  /// The unwrapped width of [text] in [style] under [scaler].
  static double of(
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final scaled = scaler.scale(style.fontSize ?? 14);
    final key = (text, style, scaled);
    final cached = _widths[key];
    if (cached != null) return cached;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    if (_widths.length >= _maxEntries) _widths.clear();
    return _widths[key] = width;
  }
}
