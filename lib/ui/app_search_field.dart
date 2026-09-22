import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The search input: a 343 × 46 pill (`r30`, surface @75 %) with a 16 px glyph 14 px in,
/// the query at 16/300, and the 30 px accent scan disc pinned 4 px from the right edge.
///
/// Measured from `Поиск - Удачный поиск`; the home screen's search entry uses the shorter
/// 38 px variant, which is a tap target rather than an input.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    this.controller,
    this.focusNode,
    this.hint = 'Найти любимый напиток...',
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.onScan,
    super.key,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onScan;

  static const double height = 46;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              cursorColor: palette.accent,
              cursorWidth: 1.5,
              style: AppTypography.base(size: 16, weight: 300)
                  .copyWith(color: palette.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: AppTypography.base(size: 16, weight: 300)
                    .copyWith(color: palette.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          GestureDetector(
            onTap: onScan,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 30,
              height: 30,
              decoration:
                  BoxDecoration(color: palette.accent, shape: BoxShape.circle),
              child: const Center(child: _BarcodeGlyph()),
            ),
          ),
        ],
      ),
    );
  }
}

/// The scan action's glyph — five bars, drawn rather than exported: Figma's image API returns
/// an empty render for that node (same limitation as the home search field).
class _BarcodeGlyph extends StatelessWidget {
  const _BarcodeGlyph();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 10),
      painter: _BarcodePainter(context.palette.textOnAccent),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const weights = [1.0, 1.6, 0.8, 1.6, 1.0];
    const gap = 1.2;
    final total = weights.reduce((a, b) => a + b) + gap * (weights.length - 1);
    final scale = size.width / total;
    var x = 0.0;
    for (final w in weights) {
      canvas.drawRect(Rect.fromLTWH(x, 0, w * scale, size.height), paint);
      x += (w + gap) * scale;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter oldDelegate) => oldDelegate.color != color;
}
