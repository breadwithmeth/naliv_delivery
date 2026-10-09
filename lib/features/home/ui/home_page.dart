library;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../../core/product_view.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/surfaces.dart';
import '../../../ui/product_card.dart';
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
    this.productQuantity,
    this.onProductTap,
    this.onProductIncrement,
    this.onProductDecrement,
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
  final num Function(ProductView product)? productQuantity;
  final ValueChanged<ProductView>? onProductTap;
  final ValueChanged<ProductView>? onProductIncrement;
  final ValueChanged<ProductView>? onProductDecrement;
  final VoidCallback? onCart;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(
                top: AppSpacing.huge,
                bottom: AppCartButton.clearanceFor(context) + bottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  const SizedBox(height: AppSpacing.xl),
                  _ContentWidth(
                    child: KeyedSubtree(
                      key: const ValueKey('home-search-field'),
                      child: _SearchField(onTap: onSearch),
                    ),
                  ),
                  if (data.banners.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.huge),
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
                  _ProductSections(
                    sections: data.productSections,
                    onCategory: onCategory,
                    quantityOf: productQuantity,
                    onProductTap: onProductTap,
                    onIncrement: onProductIncrement,
                    onDecrement: onProductDecrement,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset + AppSpacing.xl,
              child: Center(
                child: AppCartButton(
                  itemCount: cartItemCount,
                  total: cartTotal,
                  onTap: onCart,
                ),
              ),
            ),
          ],
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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final phone = InkWell(
            onTap: onCallCenter,
            borderRadius: AppRadii.mdAll,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
              child: Row(
                children: [
                  AppIcon(AppIcons.phone, size: 18, color: context.palette.accent),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Поддержка',
                      style: AppTypography.label.copyWith(color: context.palette.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderAction(
                  icon: AppIcons.star, label: 'Бонусы', onTap: onBonusHistory),
              _HeaderAction(
                  icon: AppIcons.heart, label: 'Избранные товары', onTap: onLiked),
              _HeaderAction(
                  icon: AppIcons.bell,
                  label: 'Настройки уведомлений',
                  onTap: onNotifications),
              _HeaderAction(
                  icon: AppIcons.user, label: 'Профиль', onTap: onProfile),
            ],
          );
          if (constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(14) > 21) {
            return Column(
              children: [
                Row(
                  children: [
                    const _HomeBrandMark(),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(child: phone),
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
              Expanded(child: phone),
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
  const _StoreCard(
      {required this.data, required this.onProfile, this.onTap});

  final HomeViewData data;
  final VoidCallback? onTap;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final glyph = AppGlassPanel(
      radius: AppRadii.md,
      tint: palette.accentSoft,
      blur: 18,
      width: 32,
      height: 32,
      child: Center(
        child: data.signedIn
            ? const AppIcon(AppIcons.shop, size: 18, color: Colors.white)
            : const AppIcon(AppIcons.user, size: 18, color: Colors.white),
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
                            const AppIcon(AppIcons.store, size: 12),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                data.storeName,
                                style: AppTypography.bodySmallBold.copyWith(
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
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
                                style: AppTypography.bodySmall
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
                      style: AppTypography.body
                          .copyWith(color: palette.textSecondary))),
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
            final width =
                (constraints.maxWidth - 80).clamp(240.0, 420.0).toDouble();
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
                text: TextSpan(text: text,
                    style: defaultStyle.merge(style)),
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
                actionHeight ??= textHeight('Смотреть товары →',
                    AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600));
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
          : InkWell(
              onTap: onTap,
              child: card,
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
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.lgAll,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: ConstrainedBox(
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
                        Text(
                          promo.subtitle,
                          style: AppTypography.bodySmall
                              .copyWith(color: palette.textPrimary),
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
    );
  }
}

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
        // The frames fill the gutters with three 98 px columns at 375; larger text needs
        // wider columns, never narrower ones, and the artwork never outgrows its column.
        final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
        final minimumWidth = 98 * (1 + (scale - 1) * 0.34);
        final columns = ((constraints.maxWidth + AppSpacing.huge) /
                (minimumWidth + AppSpacing.huge))
            .floor()
            .clamp(1, 3);
        final tileWidth =
            (constraints.maxWidth - AppSpacing.huge * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.huge,
          runSpacing: AppSpacing.xl,
          children: [
            for (var index = 0; index < visible; index++)
              _CategoryTile(
                width: tileWidth,
                category: categories[index],
                onTap: onTap == null ? null : () => onTap!(categories[index]),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile(
      {required this.width, required this.category, this.onTap});

  final double width;
  final HomeCategory category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
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
            Text(category.title,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall
                    .copyWith(color: palette.textPrimary)),
          ],
        ),
      ),
    );
  }
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
                AppGlassChip(label: 'История', onTap: onHistory),
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
                  Text('Авторизируйтесь, чтобы видеть бонусы',
                      textAlign: TextAlign.center,
                      style: AppTypography.body
                          .copyWith(color: palette.textSecondary)),
                  const SizedBox(height: AppSpacing.xl),
                  Align(
                    child: AppGlassChip(label: 'Войти', onTap: onSignIn),
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
    this.quantityOf,
    this.onProductTap,
    this.onIncrement,
    this.onDecrement,
  });

  final List<HomeProductSection> sections;
  final ValueChanged<HomeCategory>? onCategory;
  final num Function(ProductView product)? quantityOf;
  final ValueChanged<ProductView>? onProductTap;
  final ValueChanged<ProductView>? onIncrement;
  final ValueChanged<ProductView>? onDecrement;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          _ProductSection(
            section: sections[index],
            onCategory: onCategory,
            quantityOf: quantityOf,
            onProductTap: onProductTap,
            onIncrement: onIncrement,
            onDecrement: onDecrement,
          ),
          if (index != sections.length - 1) const SizedBox(height: 32),
        ],
      ],
    );
  }
}

class _ProductSection extends StatelessWidget {
  const _ProductSection({
    required this.section,
    this.onCategory,
    this.quantityOf,
    this.onProductTap,
    this.onIncrement,
    this.onDecrement,
  });

  final HomeProductSection section;
  final ValueChanged<HomeCategory>? onCategory;
  final num Function(ProductView product)? quantityOf;
  final ValueChanged<ProductView>? onProductTap;
  final ValueChanged<ProductView>? onIncrement;
  final ValueChanged<ProductView>? onDecrement;

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
                    AppGlassChip(
                      label: 'Все',
                      onTap: onCategory == null
                          ? null
                          : () => onCategory!(section.category),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                height: ProductCard.heightFor(
                  context,
                  width: ProductCard.widthFor(context),
                  products: section.products,
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  itemCount: section.products.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.xl),
                  itemBuilder: (context, index) {
                    final product = section.products[index];
                    return ProductCard.fromView(
                      product,
                      quantity: quantityOf?.call(product),
                      onTap: onProductTap == null
                          ? null
                          : () => onProductTap!(product),
                      onIncrement: onIncrement == null
                          ? null
                          : () => onIncrement!(product),
                      onDecrement: onDecrement == null
                          ? null
                          : () => onDecrement!(product),
                    );
                  },
                ),
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
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ColoredBox(color: fallback),
    );
  }
}
