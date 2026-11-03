import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';

/// The design's switch (`Профиль - Переключение свитчей`): a 50 × 30 pill, orange when on,
/// grey when off, with a white 22.5 px knob inset 3.75 px.
///
/// The knob glides and the track cross-fades together; with reduced motion both snap. The
/// touch target is 50 × 48. A `null` [onChanged] disables the switch.
///
/// Set [excludeSemantics] when the surrounding row already exposes the toggle (a
/// `Semantics(toggled: …)` on the whole row), so assistive tech reads one control, not two.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    required this.value,
    required this.onChanged,
    this.label,
    this.excludeSemantics = false,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final bool excludeSemantics;

  static const double width = 50;
  static const double height = 30;
  static const double _knob = 22.5;
  static const double _inset = 3.75;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    // The off track must stay readable on both the page and a grouped surface.
    final off = dark ? const Color(0xFF3A3A3A) : const Color(0xFFD2D2D2);
    final enabled = onChanged != null;
    Widget control = SizedBox(
      width: width,
      height: 48,
      child: Center(
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: value ? palette.accent : off,
            borderRadius: AppRadii.pillAll,
          ),
          child: AnimatedAlign(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(_inset),
              child: Container(
                width: _knob,
                height: _knob,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      offset: const Offset(0, 1.5),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    control = Opacity(opacity: enabled ? 1 : 0.5, child: control);
    control = InkResponse(
      onTap: enabled ? () => onChanged!(!value) : null,
      radius: 28,
      containedInkWell: false,
      child: control,
    );
    if (excludeSemantics) return ExcludeSemantics(child: control);
    return Semantics(
      label: label,
      toggled: value,
      enabled: enabled,
      child: control,
    );
  }
}
