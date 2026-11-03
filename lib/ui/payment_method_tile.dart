import 'package:flutter/material.dart';

import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';

/// One row of the payment-method list.
///
/// Every method — Kaspi.kz, a saved card — is drawn with this anatomy, so the list reads as
/// one list: a [title] line that starts at the row's left edge (the method's own mark, with
/// an optional [leading] glyph before a plain-text title), a muted [subtitle] under it, and
/// the selection mark on the trailing edge. Kaspi's rules ask for exactly this: its logo and
/// Gold take the place the other methods' logos take, with the same alignment.
///
/// The row is at least 64 high, [AppRadii.xl] round and selected rows get an accent outline
/// and a faint accent fill that animate with [AppMotion.state].
class PaymentMethodTile extends StatelessWidget {
  const PaymentMethodTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.selected = false,
    this.onTap,
    this.showSelection = true,
    this.inkKey,
    this.semanticLabel,
    super.key,
  });

  /// The method's identity: a text or a logo. Laid out beside [leading].
  final Widget title;

  final String? subtitle;

  /// A glyph before a text [title] (the card icon).
  final Widget? leading;

  final bool selected;

  /// Selects the method; null makes the row inert (busy, or the method is unavailable).
  final VoidCallback? onTap;

  /// Whether the trailing selection mark is drawn. It stays visible, dimmed, while the
  /// row is only temporarily inert, so the list does not change shape while paying.
  final bool showSelection;

  /// Key of the tappable region.
  final Key? inkKey;

  /// Replaces the text semantics of the row.
  final String? semanticLabel;

  /// Height of the identity line: the Kaspi logo's own height.
  static const double identityHeight = 28;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onTap != null;
    final shape = RoundedRectangleBorder(
      borderRadius: AppRadii.xlAll,
      side: BorderSide(
        color: selected ? palette.accent : Colors.transparent,
        width: 1.5,
      ),
    );
    return Semantics(
      button: showSelection,
      selected: selected,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        color: selected ? palette.accentFaint : palette.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        animationDuration: AppMotion.of(context, AppMotion.state),
        child: InkWell(
          key: inkKey,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxxl, vertical: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints:
                              const BoxConstraints(minHeight: identityHeight),
                          child: Row(
                            children: [
                              if (leading != null) ...[
                                leading!,
                                const SizedBox(width: AppSpacing.xl),
                              ],
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: title,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              subtitle!,
                              style: AppTypography.bodySmall
                                  .copyWith(color: palette.textSecondary),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (showSelection) ...[
                    const SizedBox(width: AppSpacing.xl),
                    Opacity(
                      opacity: enabled || selected ? 1 : .4,
                      child: _SelectionMark(selected: selected),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The trailing radio: an outline that fills with the accent and a check when chosen.
class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final duration = AppMotion.of(context, AppMotion.state);
    return AnimatedContainer(
      duration: duration,
      curve: AppMotion.out,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? palette.accent : Colors.transparent,
        border: Border.all(
          color: selected
              ? palette.accent
              : palette.textSecondary.withValues(alpha: .7),
          width: 1.5,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : .4,
        duration: duration,
        curve: AppMotion.overshoot,
        child: AnimatedOpacity(
          opacity: selected ? 1 : 0,
          duration: duration,
          child: Center(
            child:
                AppIcon(AppIcons.check, size: 14, color: palette.textOnAccent),
          ),
        ),
      ),
    );
  }
}
