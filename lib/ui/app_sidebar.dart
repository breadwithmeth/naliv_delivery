import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_icon.dart';
import 'surfaces.dart';

/// One row in the sidebar.
@immutable
class AppSidebarItem {
  const AppSidebarItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.badgeCount = 0,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;
  final int badgeCount;
}

/// The app's navigation, as a left sidebar.
///
/// **Not taken from the design** — verified absent: across all 106 frames there is no panel
/// anchored to the left edge, no drawer, and no tab bar. The redesigned product therefore had
/// no way to reach the catalogue, favourites, orders or profile at all, so this sidebar is
/// created on request and built from the file's own vocabulary: the GLASS chrome of the
/// floating bars, the profile screen's row recipe (24 px icon, 16/700 title, 10/400 subtitle,
/// chevron, 1 px `divider` between rows), and the theme toggle that already exists on
/// `Профиль - Переключение свитчей`.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    required this.items,
    this.userName,
    this.userSubtitle,
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
    this.onLogout,
    this.width = 300,
    super.key,
  });

  final List<AppSidebarItem> items;
  final String? userName;
  final String? userSubtitle;

  /// Mirrors the design's "Тема оформления" switch: system by default, overridable.
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final VoidCallback? onLogout;
  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      width: width,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AppRadii.xxl),
          bottomRight: Radius.circular(AppRadii.xxl),
        ),
        child: AppGlassPanel(
          radius: 0,
          tint: palette.background.withValues(alpha: 0.92),
          blur: 24,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UserHeader(name: userName, subtitle: userSubtitle),
                Expanded(
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(
                      color: palette.divider,
                      height: 1,
                      thickness: 1,
                    ),
                    itemBuilder: (context, index) =>
                        _SidebarRow(item: items[index]),
                  ),
                ),
                Divider(color: palette.divider, height: 1, thickness: 1),
                _ThemeRow(
                  isDark: isDark,
                  mode: themeMode,
                  onChanged: onThemeModeChanged,
                ),
                if (onLogout != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.lg,
                    ),
                    child: GestureDetector(
                      onTap: onLogout,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          const AppIcon(AppIcons.logout,
                              size: 20, color: Color(0xFFC23B30)),
                          const SizedBox(width: AppSpacing.xl),
                          Text('Выйти',
                              style: AppTypography.bodyMedium
                                  .copyWith(color: palette.error)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  const _UserHeader({this.name, this.subtitle});

  final String? name;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xxxl,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration:
                BoxDecoration(color: palette.accent, shape: BoxShape.circle),
            child: const Center(
                child: AppIcon(AppIcons.avatar, size: 32, color: Colors.white)),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name ?? 'Гость',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTypography.title.copyWith(color: palette.textPrimary),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label
                        .copyWith(color: palette.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The profile screen's row recipe, reused so the sidebar and profile read as one system.
class _SidebarRow extends StatelessWidget {
  const _SidebarRow({required this.item});

  final AppSidebarItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            AppIcon(item.icon, size: 24, color: palette.accent),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMedium
                    .copyWith(color: palette.textPrimary),
              ),
            ),
            if (item.badgeCount > 0)
              Container(
                margin: const EdgeInsets.only(right: AppSpacing.md),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 1),
                decoration: BoxDecoration(
                  color: palette.brandRed,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  '${item.badgeCount}',
                  style: AppTypography.base(size: 10, weight: 500)
                      .copyWith(color: Colors.white, height: 1),
                ),
              ),
            Icon(Icons.chevron_right, size: 20, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.isDark, required this.mode, this.onChanged});

  final bool isDark;
  final ThemeMode mode;
  final ValueChanged<ThemeMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.theme, size: 24, color: palette.accent),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Тема оформления',
                    style: AppTypography.titleMedium
                        .copyWith(color: palette.textPrimary)),
                Text('Переключение светлой и тёмной темы',
                    style: AppTypography.label
                        .copyWith(color: palette.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: isDark,
            onChanged: onChanged == null
                ? null
                : (value) =>
                    onChanged!(value ? ThemeMode.dark : ThemeMode.light),
          ),
        ],
      ),
    );
  }
}
