library;

import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../../core/product_view.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../bonuses/bonus_account.dart';
import '../../bonuses/ui/bonus_qr_page.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/frosted_dock.dart';
import '../../../ui/frosted_surface.dart';
import '../../../ui/motion_widgets.dart';
import '../../../ui/surfaces.dart';
import '../../../ui/text_width_cache.dart';
import '../../../ui/product_card.dart';
import '../../../ui/product_grid.dart';
import '../home_view_data.dart';

/// The public landing page measured from the 375 × 812 Figma home frames.
///
/// At 375 px, content keeps the full header/store/search/campaign/category rhythm.
/// Real names and metadata wrap at large text; wider windows cap the content.
class HomePage extends StatelessWidget {
  const HomePage({
    required this.data,
    this.cartItemCount = 0,
    this.cartTotal,
    this.onSearch,
    this.onCallCenter,
    this.onNotifications,
    this.onLiked,
    this.onProfile,
    this.onStore,
    this.onPromo,
    this.onActiveOrder,
    this.onCategory,
    this.onBonusHistory,
    this.onSignIn,
    this.productBuilder,
    this.cartDock,
    this.onCart,
    super.key,
  });

  final HomeViewData data;
  final int cartItemCount;
  final num? cartTotal;
  final VoidCallback? onSearch;
  final VoidCallback? onCallCenter;
  final VoidCallback? onNotifications;
  final VoidCallback? onLiked;
  final VoidCallback? onProfile;
  final VoidCallback? onStore;
  final ValueChanged<HomeBanner>? onPromo;
  final ValueChanged<HomeActiveOrder>? onActiveOrder;
  final ValueChanged<HomeCategory>? onCategory;
  final VoidCallback? onBonusHistory;
  final VoidCallback? onSignIn;
  final Widget Function(BuildContext context, ProductView product)?
      productBuilder;
  final Widget? cartDock;
  final VoidCallback? onCart;

  /// Gap between the pinned header and the first block of the scrolling body, so
  /// the header's own bottom padding does not change the resting rhythm.
  static const _headerBottom = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Only the side insets are handled here: the header layout owns the top
    // inset so the status bar can frost together with the header.
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: FrostedHeaderLayout(
          estimatedHeaderHeight: AppSpacing.huge + 48 + _headerBottom,
          header: Padding(
            padding: const EdgeInsets.only(
                top: AppSpacing.huge, bottom: _headerBottom),
            child: _ContentWidth(
              child: KeyedSubtree(
                key: const ValueKey('home-header'),
                child: _HomeHeader(
                  onNotifications: onNotifications,
                  onBonusHistory: onBonusHistory,
                  onCallCenter: onCallCenter,
                  onLiked: onLiked,
                  onProfile: onProfile,
                ),
              ),
            ),
          ),
          body: (context, topInset) => FrostedDock(
            content: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: topInset),
                      const SizedBox(height: AppSpacing.xl - _headerBottom),
                      _ContentWidth(
                        child: KeyedSubtree(
                          key: const ValueKey('home-store-card'),
                          child: _StoreCard(data: data, onTap: onStore),
                        ),
                      ),
                      if (data.activeOrder case final order?) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _ContentWidth(
                          child: KeyedSubtree(
                            key: const ValueKey('home-active-order'),
                            child: _ActiveOrderCard(
                              order: order,
                              onTap: onActiveOrder == null
                                  ? null
                                  : () => onActiveOrder!(order),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.huge),
                      _ContentWidth(
                        child: KeyedSubtree(
                          key: const ValueKey('home-search-field'),
                          child: _SearchField(onTap: onSearch),
                        ),
                      ),
                      if (data.banners.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        KeyedSubtree(
                          key: const ValueKey('home-banner-carousel'),
                          child: _BannerCarousel(
                            key: ValueKey(data.storeId),
                            banners: data.banners,
                            onTap: onPromo,
                          ),
                        ),
                      ],
                      if (data.promoCard case final promo?) ...[
                        const SizedBox(height: AppSpacing.huge),
                        _ContentWidth(
                          child: KeyedSubtree(
                            key: const ValueKey('home-promo-card'),
                            child: _PromoCard(
                              promo: promo,
                              onTap: onCategory == null
                                  ? null
                                  : () => onCategory!(
                                        HomeCategory(
                                          id: promo.id,
                                          title: promo.title,
                                          imageUrl: promo.imageUrl,
                                          fill: promo.fill,
                                        ),
                                      ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.huge),
                      _ContentWidth(
                        child: KeyedSubtree(
                          key: const ValueKey('home-category-grid'),
                          child: _CategoryGrid(
                            categories: data.categories,
                            onTap: onCategory,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.huge),
                      _ContentWidth(
                        child: KeyedSubtree(
                          key: const ValueKey('home-bonus-card'),
                          child: _BonusCard(
                            data: data,
                            onHistory: onBonusHistory,
                            onSignIn: onSignIn,
                          ),
                        ),
                      ),
                      SizedBox(height: data.signedIn ? 32 : 24),
                    ],
                  ),
                ),
                _ProductSections(
                  sections: data.productSections,
                  onCategory: onCategory,
                  productBuilder: productBuilder,
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: AppCartButton.clearanceFor(context) + bottomInset,
                  ),
                ),
              ],
            ),
            dock: cartDock ??
                AppCartButton(
                  itemCount: cartItemCount,
                  total: cartTotal,
                  onTap: onCart,
                ),
          ),
        ),
      ),
    );
  }
}

class _ContentWidth extends StatelessWidget {
  const _ContentWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

class _HomeBrandMark extends StatelessWidget {
  const _HomeBrandMark();

  @override
  Widget build(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const AppIcon(AppIcons.logoDark,
              key: ValueKey('home-brand-mark'), width: 48, height: 48)
          : const AppIcon(AppIcons.logo,
              key: ValueKey('home-brand-mark'), width: 48, height: 48);
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    this.onNotifications,
    this.onBonusHistory,
    this.onCallCenter,
    this.onLiked,
    this.onProfile,
  });

  final VoidCallback? onNotifications;
  final VoidCallback? onBonusHistory;
  final VoidCallback? onCallCenter;
  final VoidCallback? onLiked;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HomeBrandMark(),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _HeaderAction(
                    icon: AppIcons.phone,
                    label: 'Связаться',
                    showLabel: true,
                    accent: true,
                    onTap: onCallCenter,
                  ),
                  _HeaderAction(
                    icon: AppIcons.star,
                    label: 'Бонусы',
                    onTap: onBonusHistory,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeaderAction(
                        icon: AppIcons.heart,
                        label: 'Избранные товары',
                        onTap: onLiked,
                      ),
                      _HeaderAction(
                        icon: AppIcons.bell,
                        label: 'Уведомления',
                        onTap: onNotifications,
                        accent: true,
                      ),
                      _HeaderAction(
                        icon: AppIcons.user,
                        label: 'Профиль',
                        onTap: onProfile,
                      ),
                    ],
                  ),
                ],
            ),
          ),
        ),
      ],
    );
  }

}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.showLabel = false,
    this.accent = false,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;
  final bool showLabel;
  final bool accent;

  static const _captionPadding = AppSpacing.sm;
  static const _labelledIconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final glyph = AppIcon(
      icon,
      size: showLabel ? _labelledIconSize : 24,
      color: accent ? palette.accent : palette.textPrimary,
    );
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        container: true,
        label: label,
        button: true,
        enabled: onTap != null,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.mdAll,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: AppSpacing.touchTarget,
                minHeight: AppSpacing.touchTarget,
              ),
              child: showLabel
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _captionPadding,
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          glyph,
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              label,
                              style: AppTypography.labelMedium.copyWith(
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      width: AppSpacing.touchTarget,
                      height: AppSpacing.touchTarget,
                      child: Center(child: glyph),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.data, this.onTap});

  final HomeViewData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.lgAll,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: AppRadii.lgAll,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 41),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppIcon(
                            AppIcons.shopGlyph,
                            size: 16,
                            color: palette.accent,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              data.storeName,
                              style: AppTypography.labelBold.copyWith(
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          AppIcon(
                            AppIcons.location,
                            size: 12,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              data.storeAddress.isEmpty
                                  ? 'Выберите магазин'
                                  : data.storeAddress,
                              style: AppTypography.label.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                AppSurface(
                  radius: AppRadii.md,
                  fill: Color.alphaBlend(palette.accentSoft, palette.surface),
                  width: 32,
                  height: 32,
                  child: const Center(
                    child: AppIcon(
                      AppIcons.shopGlyph,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order, this.onTap});

  final HomeActiveOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.lgAll,
      child: Container(
        constraints: const BoxConstraints(minHeight: 80),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.status,
                    style: AppTypography.headline
                        .copyWith(color: palette.textPrimary),
                  ),
                  Text(
                    'Заказ ${order.id}',
                    style: AppTypography.bodySmall
                        .copyWith(color: palette.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AppIcon(AppIcons.cartFab, size: 56, color: Color(0xBFFF6800)),
                  AppIcon(AppIcons.orders, size: 24, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: 'Поиск товаров',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: 0.75),
            borderRadius: AppRadii.pillAll,
          ),
          child: Row(
            children: [
              AppIcon(AppIcons.search, size: 18, color: palette.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: Text('Найти любимый напиток...',
                      style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w300,
                          color: palette.textSecondary))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-bleed y = 272, h = 114. At 375 px the centered card is 295 px wide.
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners, this.onTap, super.key});

  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner>? onTap;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  static const _forwardKey = ValueKey('home-banner-forward');
  final _controller = ScrollController(keepScrollOffset: false);
  Key _sequenceKey = UniqueKey();
  double? _step;
  late bool _hasSubtitle = _containsSubtitle(widget.banners);

  static bool _containsSubtitle(List<HomeBanner> banners) =>
      banners.any((banner) => banner.subtitle?.trim().isNotEmpty ?? false);

  @override
  void didUpdateWidget(covariant _BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.banners;
    final banners = widget.banners;
    if (identical(previous, banners)) return;
    _hasSubtitle = _containsSubtitle(banners);
    if (_sameSequence(previous, banners)) return;
    // A changed sequence starts at its first campaign; a content-only refresh
    // keeps the same spot (and swaps in the latest artwork, copy and actions).
    _sequenceKey = UniqueKey();
    _step = null;
  }

  bool _sameSequence(List<HomeBanner> previous, List<HomeBanner> banners) {
    if (previous.length != banners.length) return false;
    for (var i = 0; i < banners.length; i++) {
      final old = previous[i];
      final current = banners[i];
      if (old.promotionId != current.promotionId ||
          (current.promotionId == null && old.title != current.title)) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 552),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewport = constraints.maxWidth;
              if (viewport <= 0) return const SizedBox.shrink();
              if (widget.banners.length == 1) {
                final width = (viewport - AppSpacing.gutter * 2)
                    .clamp(viewport * .75, 520.0);
                return Center(
                  child: SizedBox(
                    width: width,
                    height: _heightFor(context, width),
                    child: _cardAt(0, width),
                  ),
                );
              }

              final width = (viewport - 80).clamp(viewport * .75, 420.0);
              final gap = math.min(AppSpacing.lg, viewport / 32);
              final step = width + gap;
              _resizeStep(step);
              final behavior = ScrollConfiguration.of(context);
              return SizedBox(
                height: _heightFor(context, width),
                child: CustomScrollView(
                  key: _sequenceKey,
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  scrollBehavior: behavior.copyWith(
                    scrollbars: false,
                    dragDevices: {
                      ...behavior.dragDevices,
                      PointerDeviceKind.mouse,
                    },
                  ),
                  center: _forwardKey,
                  anchor: (viewport - step) / (2 * viewport),
                  scrollCacheExtent: const ScrollCacheExtent.pixels(0),
                  // These two lazy slivers grow in opposite directions from
                  // campaign zero. Neither direction has an edge to hide or
                  // recenter, and no virtual index is exposed to assistive tech.
                  slivers: [
                    _half(step, gap, width, backwards: true),
                    _half(step, gap, width, backwards: false),
                  ],
                ),
              );
            },
          ),
        ),
      );

  void _resizeStep(double step) {
    final previous = _step;
    if (previous == step) return;
    _step = step;
    if (previous == null || !_controller.hasClients) return;
    final position = _controller.position;
    final itemOffset = position.pixels / previous;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _step == step &&
          _controller.hasClients &&
          identical(_controller.position, position)) {
        position.jumpTo(itemOffset * step);
      }
    });
  }

  Widget _half(double step, double gap, double width, {required bool backwards}) {
    return SliverFixedExtentList.builder(
      key: backwards ? null : _forwardKey,
      itemExtent: step,
      addAutomaticKeepAlives: false,
      addSemanticIndexes: false,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.symmetric(horizontal: gap / 2),
        child: _cardAt(backwards ? -index - 1 : index, width),
      ),
    );
  }

  Widget _cardAt(int index, double width) {
    final banner = widget.banners[index % widget.banners.length];
    final onTap = widget.onTap;
    return _BannerCard(
      key: ValueKey('home-banner-$index'),
      banner: banner,
      width: width,
      onTap: banner.promotionId == null || onTap == null
          ? null
          : () => onTap(banner),
    );
  }

  double _heightFor(BuildContext context, double width) {
    final textScaler = MediaQuery.textScalerOf(context);
    final defaultStyle = DefaultTextStyle.of(context).style;
    final textDirection = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final textWidth = math.max(0.0, width - AppSpacing.md * 2);
    double measure(String text, TextStyle style, int lines) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: defaultStyle.merge(style)),
        textDirection: textDirection,
        locale: locale,
        textScaler: textScaler,
        maxLines: lines,
        ellipsis: '…',
      )..layout(maxWidth: textWidth);
      final height = painter.height.ceilToDouble();
      painter.dispose();
      return height;
    }

    // Reserve the same space for every card without shaping every campaign
    // title. Fallbacks clamp to these line counts and semantics retain full copy.
    var height = AppSpacing.md * 2 +
        measure('А\nА', AppTypography.headline, _BannerCard._titleLines);
    if (_hasSubtitle) {
      height += AppSpacing.xs + measure('А', AppTypography.bodySmall, 1);
    }
    if (widget.onTap != null) {
      height += AppSpacing.sm +
          measure(_BannerCard._actionLabel, AppTypography.bodySmall,
              _BannerCard._actionLines);
    }
    return math.max(height, 114.0 * math.max(1.0, textScaler.scale(20) / 20));
  }
}

/// A single campaign card.
///
/// Live promotions frequently arrive without a cover, and then the card falls back to the design's
/// flat fill. Because the artwork that would have carried the copy is missing, the campaign's own
/// title is drawn on the fill instead, so an empty-cover promotion is never a bare panel. With
/// artwork present the image carries the copy and is left alone.
class _BannerCard extends StatelessWidget {
  const _BannerCard(
      {required this.banner, required this.width, this.onTap, super.key});
  static const _titleLines = 2;
  static const _actionLines = 2;
  static const _actionLabel = 'Смотреть товары →';

  final double width;

  final HomeBanner banner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rawTitle = banner.title.trim();
    final title = rawTitle.isEmpty ? 'Акция' : rawTitle;
    final subtitle = banner.subtitle?.trim() ?? '';
    final imageUrl = banner.imageUrl?.trim();
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: SizedBox(
        width: width,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                cacheWidth:
                    (width * MediaQuery.devicePixelRatioOf(context)).ceil(),
                excludeFromSemantics: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                    frame == null
                        ? _fallback(context, title, subtitle)
                        : fadeInImageFrame(
                            context, child, frame, wasSynchronouslyLoaded),
                errorBuilder: (context, _, __) =>
                    _fallback(context, title, subtitle),
              )
            : _fallback(context, title, subtitle),
      ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      label: subtitle.isEmpty ? title : '$title\n$subtitle',
      child: onTap == null
          ? card
          : PressScale(
              child: InkWell(
                onTap: onTap,
                child: card,
              ),
            ),
    );
  }

  Widget _fallback(BuildContext context, String title, String subtitle) {
    final palette = context.palette;
    return ColoredBox(
      color: banner.fill ?? palette.brandRed,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: _titleLines,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headline
                    .copyWith(color: palette.textOnAccent),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall
                      .copyWith(color: palette.textOnAccent),
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _actionLabel,
                  maxLines: _actionLines,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall
                      .copyWith(color: palette.textOnAccent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// y = 410, 343 × 160.
class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promo, this.onTap});

  final HomePromoCard promo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PressScale(
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.lgAll,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: ConstrainedBox(
            // The kitchen panel keeps the reference composition even when its
            // optional artwork has not been supplied by the selected store.
            constraints: const BoxConstraints(minHeight: 160),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _NetworkFill(
                    imageUrl: promo.imageUrl,
                    fallback: promo.fill ?? palette.surface,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxxl),
                  child: AppSurface(
                    fill: promo.imageUrl?.isNotEmpty == true
                        ? palette.surface.withValues(alpha: .9)
                        : Colors.transparent,
                    padding: promo.imageUrl?.isNotEmpty == true
                        ? const EdgeInsets.all(AppSpacing.md)
                        : EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          promo.title,
                          style: AppTypography.headline
                              .copyWith(color: palette.textPrimary),
                        ),
                        if (promo.subtitle.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              promo.subtitle,
                              style: AppTypography.label
                                  .copyWith(color: palette.textPrimary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How far a caption may spill past its tile on each side. The 24 px gutter minus this on
/// both neighbours still leaves 8 px between captions.
const _captionOverhang = AppSpacing.md;

final _whitespace = RegExp(r'\s+');

// Category artwork retains its reference size; readable captions set the height.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories, this.onTap});

  final List<HomeCategory> categories;
  final ValueChanged<HomeCategory>? onTap;

  @override
  Widget build(BuildContext context) {
    final visible = categories.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Three columns need 88 px tiles. That keeps the frames' three columns on 360 px
        // phones (93 px tiles) instead of dropping to two 152 px ones; larger text still
        // needs wider columns, never narrower ones, and the artwork never outgrows its column.
        final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
        final minimumWidth = 88 * (1 + (scale - 1) * 0.34);
        final columns = ((constraints.maxWidth + AppSpacing.huge) /
                (minimumWidth + AppSpacing.huge))
            .floor()
            .clamp(1, 3);
        final tileWidth =
            (constraints.maxWidth - AppSpacing.huge * (columns - 1)) / columns;
        final captionScale =
            _captionScale(context, tileWidth + _captionOverhang * 2);
        return Wrap(
          spacing: AppSpacing.huge,
          runSpacing: AppSpacing.xl,
          children: [
            for (var index = 0; index < visible; index++)
              _CategoryTile(
                width: tileWidth,
                captionScale: captionScale,
                category: categories[index],
                onTap: onTap == null ? null : () => onTap!(categories[index]),
              ),
          ],
        );
      },
    );
  }

  /// One caption size for the whole grid. Long live titles ("Слабоалкогольные
  /// напитки") shrink every caption a little (never below 85%) instead of leaving a
  /// single caption visibly smaller than its neighbours.
  double _captionScale(BuildContext context, double columnWidth) {
    final style =
        DefaultTextStyle.of(context).style.merge(AppTypography.bodySmall);
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final category in categories) {
      for (final word in category.title.split(_whitespace)) {
        if (word.isEmpty) continue;
        final width = TextWidthCache.of(word, style, textScaler, textDirection);
        if (width > widest) widest = width;
      }
    }
    return widest <= columnWidth ? 1.0 : (columnWidth / widest).clamp(.85, 1.0);
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.width,
    required this.category,
    required this.captionScale,
    this.onTap,
  });

  final double width;
  final HomeCategory category;
  final double captionScale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PressScale(
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.lgAll,
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                child: SizedBox(
                  width: width,
                  height: width,
                  child: _NetworkFill(
                    imageUrl: category.imageUrl,
                    fallback: category.fill ?? palette.accent,
                  ),
                ),
              ),
              const SizedBox(height: 9),
              _CategoryCaption(
                title: category.title,
                style: AppTypography.label.copyWith(
                  color: palette.textPrimary,
                  fontSize: AppTypography.label.fontSize! * captionScale,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps between words only, on a line up to [_captionOverhang] wider than the tile on each
/// side. A word that still does not fit (the live catalogue has "Слабоалкогольные" and
/// "Безалкогольные") scales down instead of breaking mid-word ("Слабоалкого/льное") the
/// way a plain [Text] does.
class _CategoryCaption extends StatelessWidget {
  const _CategoryCaption({required this.title, required this.style});

  final String title;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Semantics(
        label: title,
        excludeSemantics: true,
        child: LayoutBuilder(
          builder: (context, constraints) => FractionallySizedBox(
            widthFactor: (constraints.maxWidth + _captionOverhang * 2) /
                constraints.maxWidth,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              children: [
                for (final word in title.split(_whitespace))
                  if (word.isNotEmpty)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(word,
                          maxLines: 1, softWrap: false, style: style),
                    ),
              ],
            ),
          ),
        ),
      );
}

class _BonusCard extends StatelessWidget {
  const _BonusCard({required this.data, this.onHistory, this.onSignIn});

  final HomeViewData data;
  final VoidCallback? onHistory;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIcon(AppIcons.bonusStar, size: 20, color: palette.textPrimary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: Text('Бонусная карта',
                      style: AppTypography.title
                          .copyWith(color: palette.textPrimary))),
              if (data.signedIn)
                AppSectionAction(label: 'История', onTap: onHistory),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (data.signedIn) ...[
            if (data.bonusBalance != null)
              Wrap(
                spacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(bonusNumberLabel(data.bonusBalance!),
                      style: AppTypography.displayBold
                          .copyWith(color: palette.accent)),
                  Text(data.bonusCaption,
                      style: AppTypography.bodySmall
                          .copyWith(color: palette.textSecondary)),
                ],
              )
            else
              Text('Баланс бонусов недоступен',
                  style: AppTypography.bodySmall
                      .copyWith(color: palette.textSecondary)),
            const SizedBox(height: AppSpacing.xl),
            if (data.bonusCardCode case final code? when code.isNotEmpty)
              _BonusQrTile(data: data, code: code)
            else
              AppSurface(
                fill: palette.surfaceMuted,
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                child: Text('QR-код бонусной карты недоступен',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall
                        .copyWith(color: palette.textSecondary)),
              ),
          ] else
            AppSurface(
              fill: palette.surfaceMuted,
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                children: [
                  AppIcon(AppIcons.avatar,
                      size: 40, color: palette.textSecondary),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Авторизуйтесь, чтобы видеть бонусы',
                      textAlign: TextAlign.center,
                      style: AppTypography.body
                          .copyWith(color: palette.textSecondary)),
                  const SizedBox(height: AppSpacing.xl),
                  Align(
                    child: AppSectionAction(label: 'Войти', onTap: onSignIn),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The card's QR: a white scannable tile with the caption under it, and a quiet
/// expand badge hinting that it opens full screen. The tile is the [Hero] that
/// grows into [BonusQrPage].
class _BonusQrTile extends StatelessWidget {
  const _BonusQrTile({required this.data, required this.code});

  static const heroTag = 'home-bonus-qr';
  static const _tile = 132.0;

  final HomeViewData data;
  final String code;

  void _open(BuildContext context) => showBonusQr(
        context,
        code: code,
        heroTag: heroTag,
        balance: data.bonusBalance,
        balanceCaption: data.bonusCaption,
        caption: data.qrCaption,
      );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: 'QR бонусной карты',
      hint: 'Открыть QR на весь экран',
      onTap: () => _open(context),
      excludeSemantics: true,
      child: AppSurface(
        key: const ValueKey('home-bonus-qr'),
        fill: palette.surfaceMuted,
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        onTap: () => _open(context),
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  SizedBox.square(
                    dimension: _tile,
                    child: Hero(tag: heroTag, child: BonusQrPlate(code: code)),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(data.qrCaption,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall
                          .copyWith(color: palette.textPrimary)),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.accentFaint,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 30,
                  child: Icon(Icons.open_in_full_rounded,
                      size: 15, color: palette.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductSections extends StatelessWidget {
  const _ProductSections({
    required this.sections,
    this.onCategory,
    this.productBuilder,
  });

  final List<HomeProductSection> sections;
  final ValueChanged<HomeCategory>? onCategory;
  final Widget Function(BuildContext context, ProductView product)?
      productBuilder;

  /// Sections are built as they scroll into view, so the long tail of product rails
  /// (and their images) costs nothing until the user reaches it.
  @override
  Widget build(BuildContext context) => SliverList.separated(
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 32),
        itemBuilder: (context, index) => _ProductSection(
          section: sections[index],
          onCategory: onCategory,
          productBuilder: productBuilder,
        ),
      );
}

class _ProductSection extends StatelessWidget {
  const _ProductSection({
    required this.section,
    this.onCategory,
    this.productBuilder,
  });

  final HomeProductSection section;
  final ValueChanged<HomeCategory>? onCategory;
  final Widget Function(BuildContext context, ProductView product)?
      productBuilder;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 552),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(section.category.title,
                            style: AppTypography.headline
                                .copyWith(color: context.palette.textPrimary))),
                    AppSectionAction(
                      label: 'Все',
                      onTap: onCategory == null
                          ? null
                          : () => onCategory!(section.category),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              ProductRail(
                spacing: AppSpacing.md,
                products: section.products,
                itemCount: section.products.length,
                itemBuilder: (context, index) {
                  final product = section.products[index];
                  return productBuilder?.call(context, product) ??
                      ProductCard.fromView(product);
                },
              ),
            ],
          ),
        ),
      );
}

class _NetworkFill extends StatelessWidget {
  const _NetworkFill({required this.imageUrl, required this.fallback});

  final String? imageUrl;
  final Color fallback;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return ColoredBox(color: fallback);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: constraints.hasBoundedWidth
            ? (constraints.maxWidth * pixelRatio).ceil()
            : null,
        frameBuilder: fadeInImageFrame,
        errorBuilder: (_, __, ___) => ColoredBox(color: fallback),
      ),
    );
  }
}
