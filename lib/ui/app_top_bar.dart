import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/typography.dart';
import 'app_icon.dart';
import 'app_icon_button.dart';

/// The secondary screens' header: a back disc, a centred 20/700 title and a trailing action.
///
/// Measured from `Каталог - Все товары` and `Каталог`: a 343 × 57 block starting at y = 70
/// (24 px under the status bar), 40 × 40 discs flush with its edges at y + 8, and a title that
/// stays centred between them and may wrap to two lines («Слабоалкогольные напитки»).
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    required this.title,
    this.onBack,
    this.onSearch,
    this.trailing,
    this.subtitle,
    this.showBack = true,
    this.backEnabled = true,
    super.key,
  });

  final String title;

  /// Second line under the title — the cart puts the delivery address here (14/300 muted).
  final String? subtitle;

  final VoidCallback? onBack;
  final VoidCallback? onSearch;

  /// Replaces the search action when a screen needs something else.
  final Widget? trailing;
  final bool showBack;
  final bool backEnabled;

  static const double height = 57;

  /// Distance from the top of the safe area to the bar: the design places every secondary
  /// screen's header at y = 70, i.e. 22 px under a 48 px status bar.
  static const double _topGap = 22;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: _topGap),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: height),
        child: Row(
          children: [
            if (showBack)
              AppIconButton(
                asset: AppIcons.back,
                onTap: backEnabled
                    ? onBack ?? () => Navigator.of(context).maybePop()
                    : null,
                tooltip: 'Назад',
              )
            else
              const SizedBox(width: 40),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: subtitle == null ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headline
                          .copyWith(color: palette.textPrimary),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppTypography.base(size: 14, weight: 300).copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            trailing ??
                (onSearch == null
                    ? const SizedBox(width: 40)
                    : AppIconButton(
                        asset: AppIcons.search,
                        onTap: onSearch,
                        tooltip: 'Поиск',
                      )),
          ],
        ),
      ),
    );
  }
}
