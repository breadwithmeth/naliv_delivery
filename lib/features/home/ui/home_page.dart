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
/// At 375 px, content uses 16 px gutters; wider windows cap the column at 520 px.
/// Campaigns and product strips adapt separately. Readable type deliberately
/// departs from tiny reference metadata while preserving real data and actions.
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
  final int? cartTotal;
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
                      child: _HomeHeader(
                        onCallCenter: onCallCenter,
                        onBonusHistory: onBonusHistory,
                        onLiked: onLiked,
                        onNotifications: onNotifications,
                        onProfile: onProfile,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
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
                          onTap: () => onCategory?.call(
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
                  if (!data.signedIn || data.bonusBalance != null) ...[
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
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 57),
        child: Row(
          children: [
            const AppIcon(AppIcons.logo, width: 52, height: 50),
            const Spacer(),
            _HeaderAction(
                icon: AppIcons.phone, label: 'Поддержка', onTap: onCallCenter),
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
        ),
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
  const _StoreCard({required this.data, this.onTap});

  final HomeViewData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.lgAll,
      child: Container(
        constraints: const BoxConstraints(minHeight: 57),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                              ? 'Укажите адрес'
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
            const SizedBox(width: AppSpacing.md),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: const AppIcon(
                AppIcons.shop,
                size: 18,
                color: Colors.white,
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
        constraints: const BoxConstraints(minHeight: 57),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                    style: AppTypography.bodySmallBold
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
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AppIcon(AppIcons.cartFab, size: 40),
                  AppIcon(AppIcons.orders, size: 20, color: Colors.white),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            final scale = MediaQuery.textScalerOf(context).scale(20) / 20;
            return SizedBox(
              height: 114.0 * (scale < 1 ? 1.0 : scale),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headline
                      .copyWith(color: palette.textOnAccent),
                ),
              if (title.isNotEmpty && subtitle.isNotEmpty)
                const SizedBox(height: AppSpacing.xs),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
        child: SizedBox(
          height: 160 +
              (MediaQuery.textScalerOf(context).scale(20) - 20)
                      .clamp(0, double.infinity)
                      .toDouble() *
                  4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _NetworkFill(
                imageUrl: promo.imageUrl,
                fallback: promo.fill ?? palette.surface,
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promo.title,
                      style: AppTypography.headline.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (promo.subtitle.isNotEmpty)
                      SizedBox(
                        width: 180,
                        child: Text(
                          promo.subtitle,
                          style: AppTypography.bodySmall
                              .copyWith(color: palette.textPrimary),
                        ),
                      ),
                  ],
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
    final visible = categories.length < 6 ? categories.length : 6;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final minimumWidth = 140 * (scale < 1 ? 1.0 : scale);
        final columns = ((constraints.maxWidth + AppSpacing.xl) /
                (minimumWidth + AppSpacing.xl))
            .floor()
            .clamp(1, 3);
        final tileWidth =
            (constraints.maxWidth - AppSpacing.xl * (columns - 1)) / columns;
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: AppSpacing.md,
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
                width: 98,
                height: 98,
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
                TextButton(onPressed: onHistory, child: const Text('История')),
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
                  FilledButton(onPressed: onSignIn, child: const Text('Войти')),
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
                    TextButton(
                      onPressed: onCategory == null
                          ? null
                          : () => onCategory!(section.category),
                      child: const Text('Все'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                height: ProductCard.heightFor(context,
                    hasOldPrice:
                        section.products.any((item) => item.oldPrice != null)),
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
