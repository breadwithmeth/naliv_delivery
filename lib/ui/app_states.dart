import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The app's three non-content states, in one place.
///
/// Every rebuilt screen had grown its own private copy of these (six near-identical
/// `_Centered`/`_Message` widgets), which is exactly the drift the redesign is supposed to
/// remove. The design's own conventions are encoded here:
///
/// * **empty** — centred text: a 20/700 title over an optional 14/400 muted subtitle, either in
///   `textPrimary` («Заказов пока нет», «Сертификатов нет») or `textSecondary` («Товары не
///   найдены», «История пуста»);
/// * **error** — the same shape with a retry action. The FAQ frame is the one place the design
///   shows an error and it has *no* button, so the action stays optional;
/// * **loading** — a bare centred indicator; the frames only ever show branded loaders on first
///   launch, not inside a screen.
///
/// [topOffset] exists because the frames place these blocks at measured positions rather than at
/// the optical centre (the favourites empty state sits 218 px below the list's top).
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    this.subtitle,
    this.action,
    this.muted = false,
    this.topOffset = 0,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  /// Draws the title in `textSecondary` instead of `textPrimary`.
  final bool muted;

  final double topOffset;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(AppSpacing.xxxl, topOffset, AppSpacing.xxxl, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headline.copyWith(
                color: muted ? palette.textSecondary : palette.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style:
                    AppTypography.body.copyWith(color: palette.textSecondary),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xxxl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A failure with an optional retry. Most screens in the design have no error frame at all, so
/// the copy stays plain.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    required this.message,
    this.onRetry,
    this.topOffset = 0,
    this.retryLabel = 'Повторить',
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;
  final double topOffset;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: message,
      topOffset: topOffset,
      action: onRetry == null
          ? null
          : FilledButton(onPressed: onRetry, child: Text(retryLabel)),
    );
  }
}

class AppLoading extends StatelessWidget {
  const AppLoading({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
