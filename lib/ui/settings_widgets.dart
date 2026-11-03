import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';
import 'app_switch.dart';

/// A titled group of settings rows on one rounded surface.
///
/// The design's rows (58 px, 24 px orange icon, Medium 16 title, 12 px muted subtitle) are
/// kept; the group adds what the flat list lacked: a heading that says what the rows are
/// for, one container that holds them together, and hairlines inset past the icon. An
/// optional [footer] explains a setting that needs more than a subtitle.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.children,
    this.title,
    this.footer,
    super.key,
  });

  final String? title;
  final String? footer;
  final List<Widget> children;

  /// Distance from the group's left edge to the text column: padding + icon + gap.
  static const double dividerInset = AppSpacing.xxxl + 24 + AppSpacing.xxxl;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final separator = Divider(
      height: 1,
      thickness: 0.5,
      indent: dividerInset,
      color: palette.textSecondary.withValues(alpha: 0.22),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxxl, 0, AppSpacing.xxxl, AppSpacing.md),
            child: Semantics(
              header: true,
              child: Text(
                title!,
                style: AppTypography.bodySmallSemibold
                    .copyWith(color: palette.textSecondary),
              ),
            ),
          ),
        Material(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.xxl),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) separator,
                children[i],
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxxl, AppSpacing.md, AppSpacing.xxxl, 0),
            child: Text(
              footer!,
              style: AppTypography.label.copyWith(color: palette.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// One settings row: icon, title, optional subtitle and a trailing control.
///
/// A row is exactly one of: a navigation row ([chevron] with [onTap]), a toggle
/// ([switchValue] + [onSwitch], the whole row toggles), or a plain action ([onTap]).
/// [below] adds a full-width control under the heading line (the theme picker).
/// The widget's own key is the tap target tests use.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.title,
    this.subtitle,
    this.subtitleSemantics,
    this.iconAsset,
    this.icon,
    this.onTap,
    this.chevron = false,
    this.switchValue,
    this.onSwitch,
    this.switchKey,
    this.destructive = false,
    this.trailing,
    this.below,
    super.key,
  }) : assert(iconAsset != null || icon != null);

  final String title;
  final String? subtitle;

  /// Spoken replacement for [subtitle] (a private address read in full).
  final String? subtitleSemantics;
  final String? iconAsset;
  final IconData? icon;

  /// Tap action. For a toggle it overrides the default "flip the switch", which lets a
  /// failed load turn the row into «повторить».
  final VoidCallback? onTap;
  final bool chevron;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitch;
  final Key? switchKey;
  final bool destructive;
  final Widget? trailing;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = destructive ? palette.error : palette.accent;
    final toggle = switchValue;
    final tap = onTap ??
        (toggle != null && onSwitch != null ? () => onSwitch!(!toggle) : null);
    final leading = iconAsset != null
        ? AppIcon(iconAsset!, size: 24, color: tint)
        : Icon(icon, size: 24, color: tint);
    final heading = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl, vertical: AppSpacing.md),
        child: Row(
          children: [
            SizedBox(width: 24, height: 24, child: Center(child: leading)),
            const SizedBox(width: AppSpacing.xxxl),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium.copyWith(
                        color:
                            destructive ? palette.error : palette.textPrimary),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      semanticsLabel: subtitleSemantics,
                      style: AppTypography.label
                          .copyWith(color: palette.textSecondary),
                    ),
                ],
              ),
            ),
            if (toggle != null) ...[
              const SizedBox(width: AppSpacing.md),
              AppSwitch(
                key: switchKey,
                value: toggle,
                onChanged: onSwitch,
                excludeSemantics: true,
              ),
            ] else if (trailing != null) ...[
              const SizedBox(width: AppSpacing.md),
              trailing!,
            ] else if (chevron) ...[
              const SizedBox(width: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: Transform.flip(
                      flipX: Directionality.of(context) == TextDirection.ltr,
                      child: AppIcon(
                        AppIcons.back,
                        width: 6,
                        height: 13,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    final interactive = Semantics(
      button: tap != null && toggle == null,
      toggled: toggle,
      enabled: tap != null,
      child: InkWell(onTap: tap, child: heading),
    );
    if (below == null) return interactive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        interactive,
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxxl, 0, AppSpacing.xxxl, AppSpacing.xxxl),
          child: below,
        ),
      ],
    );
  }
}

/// One option of a [SettingsChoice].
class SettingsChoiceOption<T> {
  const SettingsChoiceOption({
    required this.value,
    required this.label,
    required this.icon,
    this.key,
  });

  final T value;
  final String label;
  final IconData icon;
  final Key? key;
}

/// A segmented picker that shows every choice at once, for a setting whose options are
/// better seen than hidden behind a switch (light / dark / system).
///
/// The selected segment is an orange thumb that slides between segments. When the segments
/// would be too narrow for their labels (320 px, or large text) the options stack as a
/// vertical list instead of shrinking the text.
class SettingsChoice<T> extends StatelessWidget {
  const SettingsChoice({
    required this.options,
    required this.value,
    required this.onChanged,
    this.groupLabel,
    super.key,
  });

  final List<SettingsChoiceOption<T>> options;
  final T value;

  /// `null` disables every option.
  final ValueChanged<T>? onChanged;
  final String? groupLabel;

  static const double _segmentHeight = 56;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduced ? Duration.zero : const Duration(milliseconds: 240);
    final track = dark ? palette.background : Colors.white;
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      container: true,
      label: groupLabel,
      child: LayoutBuilder(builder: (context, constraints) {
        final perSegment = constraints.maxWidth / options.length;
        final stacked = scaler.scale(12) > 15 || perSegment < 84;
        final index = options.indexWhere((o) => o.value == value);
        if (stacked) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: Material(
                type: MaterialType.transparency,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Column(
                    children: [
                      for (final option in options)
                        _stackedOption(
                            context, option, option.value == value, duration),
                    ],
                  ),
                )),
          );
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: track,
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: SizedBox(
                  height: _segmentHeight,
                  child: Stack(
                    children: [
                      if (index >= 0)
                        AnimatedAlign(
                          duration: duration,
                          curve: Curves.easeOutCubic,
                          alignment: Alignment(
                            options.length == 1
                                ? 0
                                : -1 + 2 * index / (options.length - 1),
                            0,
                          ),
                          child: FractionallySizedBox(
                            widthFactor: 1 / options.length,
                            heightFactor: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: palette.accent,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.lg),
                              ),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          for (final option in options)
                            Expanded(
                              child: _segment(context, option,
                                  option.value == value, duration),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        );
      }),
    );
  }

  Widget _segment(BuildContext context, SettingsChoiceOption<T> option,
      bool selected, Duration duration) {
    final palette = context.palette;
    final color = selected ? palette.textOnAccent : palette.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onChanged != null,
      label: option.label,
      excludeSemantics: true,
      onTap: onChanged == null ? null : () => onChanged!(option.value),
      child: InkWell(
        key: option.key,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onChanged == null ? null : () => onChanged!(option.value),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: color),
                duration: duration,
                builder: (context, color, _) =>
                    Icon(option.icon, size: 22, color: color),
              ),
              const SizedBox(height: AppSpacing.xxs),
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: color),
                duration: duration,
                builder: (context, color, _) => Text(
                  option.label,
                  maxLines: 1,
                  style: AppTypography.captionMedium.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stackedOption(BuildContext context, SettingsChoiceOption<T> option,
      bool selected, Duration duration) {
    final palette = context.palette;
    final color = selected ? palette.textOnAccent : palette.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onChanged != null,
      label: option.label,
      excludeSemantics: true,
      onTap: onChanged == null ? null : () => onChanged!(option.value),
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? palette.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: InkWell(
          key: option.key,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: onChanged == null ? null : () => onChanged!(option.value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxxl, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Icon(option.icon, size: 22, color: color),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    child: Text(
                      option.label,
                      style: AppTypography.bodyMedium.copyWith(color: color),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_rounded, size: 20, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
