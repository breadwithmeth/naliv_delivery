library;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../../core/product_view.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/frosted_dock.dart';
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
    this.onLiked,
    this.onNotifications,
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
  final VoidCallback? onLiked;
  final VoidCallback? onNotifications;
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FrostedDock(
          content: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.huge),
                    _ContentWidth(
                      child: KeyedSubtree(
                        key: const ValueKey('home-header'),
                        child: data.signedIn
                            ? _HomeHeader(
                                onCallCenter: onCallCenter,
                                onBonusHistory: onBonusHistory,
                                onLiked: onLiked,
                                onNotifications: onNotifications,
                                onProfile: onProfile,
                              )
                            : Row(
                                children: [
                                  const _HomeBrandMark(),
                                  const SizedBox(width: AppSpacing.xl),
                                  Expanded(
                                    child: KeyedSubtree(
                                      key: const ValueKey('home-store-card'),
                                      child: _StoreCard(
                                          data: data,
                                          onTap: onStore,
                                          onProfile: onProfile),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (data.signedIn) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _ContentWidth(
                        child: KeyedSubtree(
                          key: const ValueKey('home-store-card'),
                          child: _StoreCard(
                              data: data, onTap: onStore, onProfile: onProfile),
                        ),
                      ),
                    ],
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
    this.onCallCenter,
    this.onBonusHistory,
    this.onLiked,
    this.onNotifications,
    this.onProfile,
  });

  final VoidCallback? onCallCenter;
  final VoidCallback? onBonusHistory;
  final VoidCallback? onLiked;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;

  static const _supportLabel = 'Поддержка';
  static const _brandWidth = 48.0;
  static const _actionCount = 4;

  /// The support entry keeps its label only when it fits on one line beside the
  /// four actions. Squeezed into a 360 px phone it used to break mid-word
  /// ("Поддержк/а"); the phone glyph, tooltip and semantics stay either way.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(
              text: _supportLabel,
              style:
                  DefaultTextStyle.of(context).style.merge(AppTypography.label),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final labelledWidth =
              18 + AppSpacing.xs + painter.width.ceilToDouble();
          painter.dispose();

          Widget support(bool showLabel) => Tooltip(
                message: _supportLabel,
                child: Semantics(
                  button: true,
                  child: InkWell(
                    onTap: onCallCenter,
                    borderRadius: AppRadii.mdAll,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: AppSpacing.touchTarget,
                        minHeight: AppSpacing.touchTarget,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIcon(AppIcons.phone,
                              size: showLabel ? 18 : 22,
                              color: context.palette.accent),
                          if (showLabel) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              _supportLabel,
                              maxLines: 1,
                              softWrap: false,
                              style: AppTypography.label.copyWith(
                                  color: context.palette.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderAction(
                  icon: AppIcons.star, label: 'Бонусы', onTap: onBonusHistory),
              _HeaderAction(
                  icon: AppIcons.heart,
                  label: 'Избранные товары',
                  onTap: onLiked),
              _HeaderAction(
                  icon: AppIcons.bell,
                  label: 'Настройки уведомлений',
                  onTap: onNotifications),
              _HeaderAction(
                  icon: AppIcons.user, label: 'Профиль', onTap: onProfile),
            ],
          );
          final inlineSupportWidth = constraints.maxWidth -
              _brandWidth -
              AppSpacing.md -
              AppSpacing.xs -
              AppSpacing.touchTarget * _actionCount;
          if (inlineSupportWidth < AppSpacing.touchTarget) {
            // Not even the bare phone button fits beside the actions.
            final stackedSupportWidth =
                constraints.maxWidth - _brandWidth - AppSpacing.xl;
            return Column(
              children: [
                Row(
                  children: [
                    const _HomeBrandMark(),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: support(stackedSupportWidth >= labelledWidth),
                      ),
                    ),
                  ],
                ),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: [
              const _HomeBrandMark(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: support(inlineSupportWidth >= labelledWidth),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              actions,
            ],
          );
        },
      );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.label, this.onTap});

  final String icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: AppSpacing.touchTarget,
            height: AppSpacing.touchTarget,
            child: Center(
              child: AppIcon(
                icon,
                size: 24,
                color: context.palette.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// y = 141, 343 × 57.
class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.data, required this.onProfile, this.onTap});

  final HomeViewData data;
  final VoidCallback? onTap;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final glyph = AppSurface(
      radius: AppRadii.md,
      fill: Color.alphaBlend(palette.accentSoft, palette.surface),
      width: 32,
      height: 32,
      child: Center(
        child: data.signedIn
            ? const AppIcon(AppIcons.shopGlyph, size: 24, color: Colors.white)
            : const AppIcon(AppIcons.user, size: 24, color: Colors.white),
      ),
    );
    return InkWell(
      onTap: data.signedIn ? onTap : null,
      borderRadius: AppRadii.lgAll,
      child: Container(
        constraints: const BoxConstraints(minHeight: 57),
        padding: data.signedIn
            ? const EdgeInsets.fromLTRB(12, 8, 12, 8)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: !data.signedIn,
                enabled: onTap != null,
                child: InkWell(
                  onTap: data.signedIn ? null : onTap,
                  child: ConstrainedBox(
                    constraints: data.signedIn
                        ? const BoxConstraints()
                        : const BoxConstraints(
                            minHeight: AppSpacing.touchTarget),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppIcon(AppIcons.shopGlyph,
                                size: 16, color: palette.accent),
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
                                style: AppTypography.label
                                    .copyWith(color: palette.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            if (data.signedIn)
              glyph
            else
              Tooltip(
                message: 'Профиль',
                child: Semantics(
                  button: true,
                  enabled: onProfile != null,
                  child: InkWell(
                    onTap: onProfile,
                    child: SizedBox(
                      width: AppSpacing.touchTarget,
                      height: AppSpacing.touchTarget,
                      child: Center(child: glyph),
                    ),
                  ),
                ),
              ),
          ],
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
                  AppIcon(AppIcons.cartFab, size: 56),
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

/// Full-bleed y = 272, h = 114. At 375 px the selected card is 295 px wide at x = 40.
///
/// One card per supplied campaign, without repeats. Entries without a promotion ID
/// display their campaign copy but have no navigation destination.
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners, this.onTap});

  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner>? onTap;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  static const _gap = 10.0;
  final _controller = ScrollController();
  double? _step;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 552),
          child: LayoutBuilder(builder: (context, constraints) {
            // A lone campaign sits on the same gutters as every other block; several
            // campaigns peek from either side so the row reads as a carousel.
            final width = widget.banners.length == 1
                ? (constraints.maxWidth - AppSpacing.gutter * 2)
                    .clamp(240.0, 520.0)
                    .toDouble()
                : (constraints.maxWidth - 80).clamp(240.0, 420.0).toDouble();
            final step = width + _gap;
            if (_step != step) {
              final index = _step != null && _controller.hasClients
                  ? _controller.offset / _step!
                  : widget.banners.length >= 3
                      ? 1.0
                      : 0.0;
              _step = step;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _controller.hasClients && _step == step) {
                  _controller.jumpTo((index * step)
                      .clamp(0.0, _controller.position.maxScrollExtent)
                      .toDouble());
                }
              });
            }
            final textScaler = MediaQuery.textScalerOf(context);
            final scale = textScaler.scale(20) / 20;
            final textWidth = width - AppSpacing.md * 2;
            final defaultStyle = DefaultTextStyle.of(context).style;
            final textDirection = Directionality.of(context);
            final locale = Localizations.maybeLocaleOf(context);
            double textHeight(String text, TextStyle style) {
              final painter = TextPainter(
                text: TextSpan(text: text, style: defaultStyle.merge(style)),
                textDirection: textDirection,
                locale: locale,
                textScaler: textScaler,
              )..layout(maxWidth: textWidth);
              final height = painter.height.ceilToDouble();
              painter.dispose();
              return height;
            }

            var height = 114.0 * (scale < 1 ? 1.0 : scale);
            double? actionHeight;
            for (final banner in widget.banners) {
              final title = banner.title.trim();
              final subtitle = banner.subtitle?.trim() ?? '';
              var contentHeight = AppSpacing.md * 2;
              if (title.isNotEmpty) {
                contentHeight += textHeight(title, AppTypography.headline);
              }
              if (title.isNotEmpty && subtitle.isNotEmpty) {
                contentHeight += AppSpacing.xs;
              }
              if (subtitle.isNotEmpty) {
                contentHeight += textHeight(subtitle, AppTypography.bodySmall);
              }
              if (banner.promotionId != null && widget.onTap != null) {
                actionHeight ??= textHeight(
                    'Смотреть товары →',
                    AppTypography.bodySmall
                        .copyWith(fontWeight: FontWeight.w600));
                contentHeight += AppSpacing.sm + actionHeight;
              }
              if (contentHeight > height) height = contentHeight;
            }
            return SizedBox(
              height: height,
              child: ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                    horizontal: (constraints.maxWidth - width) / 2),
                itemCount: widget.banners.length,
                separatorBuilder: (_, __) => const SizedBox(width: _gap),
                itemBuilder: (context, index) {
                  final banner = widget.banners[index];
                  return _BannerCard(
                    key: ValueKey('home-banner-$index'),
                    banner: banner,
                    width: width,
                    onTap: banner.promotionId == null || widget.onTap == null
                        ? null
                        : () => widget.onTap!(banner),
                  );
                },
              ),
            );
          }),
        ),
      );
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
  final double width;

  final HomeBanner banner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = banner.title.trim();
    final subtitle = banner.subtitle?.trim() ?? '';
    final label = [title, subtitle].where((part) => part.isNotEmpty).join('\n');
    final hasArtwork = (banner.imageUrl?.trim() ?? '').isNotEmpty;
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: SizedBox(
        width: width,
        child: hasArtwork
            ? Image.network(
                banner.imageUrl!,
                fit: BoxFit.cover,
                cacheWidth:
                    (width * MediaQuery.devicePixelRatioOf(context)).ceil(),
                frameBuilder: fadeInImageFrame,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : _fallback(context, title, subtitle),
                errorBuilder: (context, _, __) =>
                    _fallback(context, title, subtitle),
              )
            : _fallback(context, title, subtitle),
      ),
    );
    return Semantics(
      button: onTap != null,
      label: label.isEmpty ? null : label,
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
              if (title.isNotEmpty)
                Text(
                  title,
                  softWrap: true,
                  style: AppTypography.headline
                      .copyWith(color: palette.textOnAccent),
                ),
              if (title.isNotEmpty && subtitle.isNotEmpty)
                const SizedBox(height: AppSpacing.xs),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  softWrap: true,
                  style: AppTypography.bodySmall
                      .copyWith(color: palette.textOnAccent),
                ),
              if (onTap != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Смотреть товары →',
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
                  Text('${data.bonusBalance}',
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
            AppSurface(
              fill: palette.surfaceMuted,
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                children: [
                  if (data.bonusCardCode case final code?
                      when code.isNotEmpty) ...[
                    BarcodeWidget(
                      barcode: Barcode.qrCode(),
                      data: code,
                      drawText: false,
                      color: palette.textPrimary,
                      backgroundColor: Colors.transparent,
                      width: 110,
                      height: 110,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(data.qrCaption,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall
                            .copyWith(color: palette.textPrimary)),
                  ] else
                    Text('QR-код бонусной карты недоступен',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall
                            .copyWith(color: palette.textSecondary)),
                ],
              ),
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
