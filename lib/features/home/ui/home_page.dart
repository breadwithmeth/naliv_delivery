library;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../../core/product_view.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/product_card.dart';
import '../home_view_data.dart';

/// The public landing page measured from the 375 × 812 Figma home frames.
///
/// The first viewport uses a 343 px content column with 16 px gutters. The campaign strip is the
/// sole full-bleed section. Product data and navigation remain live; absent artwork uses the same
/// flat fills as the design instead of inventing gradients or copy.
class HomePage extends StatelessWidget {
  const HomePage({
    required this.data,
    this.cartItemCount = 0,
    this.cartTotal,
    this.onSearch,
    this.onCallCenter,
    this.onFavorites,
    this.onLiked,
    this.onNotifications,
    this.onProfile,
    this.onStore,
    this.onPromo,
    this.onCategory,
    this.onBonusHistory,
    this.onSignIn,
    this.productQuantity,
    this.onProductTap,
    this.onProductIncrement,
    this.onProductDecrement,
    this.onCart,
    this.sidebar,
    super.key,
  });

  final HomeViewData data;
  final int cartItemCount;
  final int? cartTotal;
  final VoidCallback? onSearch;
  final VoidCallback? onCallCenter;
  final VoidCallback? onFavorites;
  final VoidCallback? onLiked;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;
  final VoidCallback? onStore;
  final ValueChanged<HomeBanner>? onPromo;
  final ValueChanged<HomeCategory>? onCategory;
  final VoidCallback? onBonusHistory;
  final VoidCallback? onSignIn;
  final num Function(ProductView product)? productQuantity;
  final ValueChanged<ProductView>? onProductTap;
  final ValueChanged<ProductView>? onProductIncrement;
  final ValueChanged<ProductView>? onProductDecrement;
  final VoidCallback? onCart;
  final Widget? sidebar;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      drawer: sidebar,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(
                top: AppSpacing.huge,
                bottom: AppCartButton.clearance + bottomInset + AppSpacing.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ContentWidth(
                    child: KeyedSubtree(
                      key: const ValueKey('home-header'),
                      child: _HomeHeader(
                        data: data,
                        onMenu: sidebar == null
                            ? null
                            : () => Scaffold.of(context).openDrawer(),
                        onCallCenter: onCallCenter,
                        onFavorites: onFavorites,
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
                  const SizedBox(height: AppSpacing.xl),
                  _ContentWidth(
                    child: KeyedSubtree(
                      key: const ValueKey('home-search-field'),
                      child: _SearchField(onTap: onSearch),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.huge),
                  KeyedSubtree(
                    key: const ValueKey('home-banner-carousel'),
                    child: _BannerCarousel(
                      banners: data.banners,
                      onTap: onPromo,
                    ),
                  ),
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
          constraints: const BoxConstraints(maxWidth: 343),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

/// y = 72, h = 57 in the reference viewport.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.data,
    this.onMenu,
    this.onCallCenter,
    this.onFavorites,
    this.onLiked,
    this.onNotifications,
    this.onProfile,
  });

  final HomeViewData data;
  final VoidCallback? onMenu;
  final VoidCallback? onCallCenter;
  final VoidCallback? onFavorites;
  final VoidCallback? onLiked;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 57,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 4,
            child: GestureDetector(
              onTap: onMenu,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 52,
                height: 49,
                child: AppIcon(AppIcons.logo, width: 52, height: 49),
              ),
            ),
          ),
          Positioned(
            left: 64,
            top: 14,
            width: 128,
            height: 29,
            child: GestureDetector(
              onTap: onCallCenter,
              behavior: HitTestBehavior.opaque,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const AppIcon(AppIcons.phone, size: 16),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.phone,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: AppTypography.bodySmall.copyWith(
                            color: palette.textSecondary,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          data.callCenterLabel,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: AppTypography.label.copyWith(
                            color: palette.textSecondary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 16,
            child: Row(
              children: [
                _HeaderAction(icon: AppIcons.star, onTap: onFavorites),
                const SizedBox(width: 10),
                _HeaderAction(icon: AppIcons.heart, onTap: onLiked),
                const SizedBox(width: 10),
                _NotificationAction(
                  count: data.notificationCount,
                  onTap: onNotifications,
                ),
                const SizedBox(width: 10),
                _HeaderAction(
                  icon: AppIcons.user,
                  onTap: onProfile ?? onMenu,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, this.onTap});

  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: AppIcon(
            icon,
            size: 24,
            color: context.palette.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _NotificationAction extends StatelessWidget {
  const _NotificationAction({required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 24,
        height: 24,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const AppIcon(AppIcons.bell, size: 24),
            if (count > 0)
              Positioned(
                right: -3,
                top: -5,
                child: Container(
                  width: 14,
                  height: 14,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.brandRed,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: AppTypography.base(size: 8, weight: 600).copyWith(
                      color: Colors.white,
                      height: 1,
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

/// y = 141, 343 × 57.
class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.data, this.onTap});

  final HomeViewData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 57,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

/// y = 210, 343 × 38.
class _SearchField extends StatelessWidget {
  const _SearchField({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 38,
        padding: const EdgeInsets.only(left: 14, right: 4),
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          children: [
            AppIcon(
              AppIcons.search,
              size: 16,
              color: palette.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Найти любимый напиток...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
              ),
              child: BarcodeWidget(
                barcode: Barcode.code128(),
                data: '24682468',
                drawText: false,
                color: Colors.white,
                width: 18,
                height: 16,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-bleed y = 272, h = 114. At 375 px the selected card is 295 px wide at x = 40.
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners, this.onTap});

  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner>? onTap;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  static const _itemWidth = 295.0;
  static const _gap = 10.0;
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(initialScrollOffset: _itemWidth + _gap);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<HomeBanner> get _banners {
    if (widget.banners.isEmpty) {
      return const [
        HomeBanner(title: ''),
        HomeBanner(title: ''),
        HomeBanner(title: ''),
      ];
    }
    if (widget.banners.length == 1) {
      return [widget.banners.first, widget.banners.first, widget.banners.first];
    }
    if (widget.banners.length == 2) {
      return [widget.banners.first, ...widget.banners, widget.banners.last];
    }
    return widget.banners;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final banners = _banners;
    return SizedBox(
      height: 114,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        itemCount: banners.length,
        separatorBuilder: (_, __) => const SizedBox(width: _gap),
        itemBuilder: (context, index) {
          final banner = banners[index];
          return GestureDetector(
            onTap: widget.onTap == null ? null : () => widget.onTap!(banner),
            behavior: HitTestBehavior.opaque,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: SizedBox(
                width: _itemWidth,
                child: _NetworkFill(
                  imageUrl: banner.imageUrl,
                  fallback: banner.fill ?? palette.brandRed,
                ),
              ),
            ),
          );
        },
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: SizedBox(
          height: 160,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headline.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (promo.subtitle.isNotEmpty)
                      SizedBox(
                        width: 112,
                        child: Text(
                          promo.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: palette.textPrimary,
                            height: 1.05,
                          ),
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

/// Six 98 px tiles in a 3-up wrap. The natural two-row height is 296 px.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories, this.onTap});

  final List<HomeCategory> categories;
  final ValueChanged<HomeCategory>? onTap;

  @override
  Widget build(BuildContext context) {
    final visible = categories.take(6).toList(growable: false);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: AppSpacing.md,
      children: [
        for (final category in visible)
          _CategoryTile(
            category: category,
            onTap: onTap == null ? null : () => onTap!(category),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, this.onTap});

  final HomeCategory category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 98,
        height: 144,
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
            Expanded(
              child: Text(
                category.title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: palette.textPrimary,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BonusCard extends StatelessWidget {
  const _BonusCard({
    required this.data,
    this.onHistory,
    this.onSignIn,
  });

  final HomeViewData data;
  final VoidCallback? onHistory;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final signedIn = data.signedIn && data.bonusBalance != null;
    return Container(
      height: signedIn ? 248 : 199,
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 12,
            child: Row(
              children: [
                const AppIcon(AppIcons.bonusStar, size: 19),
                const SizedBox(width: 2),
                Text(
                  'Бонусная карта',
                  style: AppTypography.title.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (signedIn) ...[
            Positioned(
              left: 12,
              top: 35,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${data.bonusBalance}',
                    style:
                        AppTypography.display.copyWith(color: palette.accent),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      data.bonusCaption,
                      style: AppTypography.bodySmallSemibold.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 13,
              top: 12,
              child: _BonusAction(
                label: 'История',
                icon: AppIcons.repeat,
                onTap: onHistory,
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 71,
              height: 165,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BarcodeWidget(
                      barcode: Barcode.qrCode(),
                      data: data.bonusCardCode ?? '${data.bonusBalance}',
                      drawText: false,
                      color: palette.textPrimary,
                      backgroundColor: Colors.transparent,
                      width: 110,
                      height: 110,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.qrCaption,
                      style: AppTypography.label.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Positioned(
              left: 12,
              right: 14,
              top: 40,
              height: 147,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: 12,
                      child: AppIcon(
                        AppIcons.avatar,
                        size: 40,
                        color: palette.textSecondary,
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      top: 60,
                      child: Text(
                        'Авторизируйтесь, чтобы видеть бонусы',
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 102,
                      child: _BonusAction(label: 'Войти', onTap: onSignIn),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BonusAction extends StatelessWidget {
  const _BonusAction({required this.label, this.icon, this.onTap});

  final String label;
  final String? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 122,
        height: 33,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.palette.accentSoft,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              AppIcon(icon!, size: 16, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              label,
              style: AppTypography.bodySmallSemibold.copyWith(
                color: Colors.white,
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
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 296,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
            child: SizedBox(
              height: 28,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      section.category.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headline.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onCategory == null
                        ? null
                        : () => onCategory!(section.category),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 46,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.accentSoft,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        'Все',
                        style: AppTypography.bodySmallMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.huge),
          SizedBox(
            height: ProductCardWide.height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
              itemCount: section.products.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xl),
              itemBuilder: (context, index) {
                final product = section.products[index];
                return ProductCardWide.fromView(
                  product,
                  quantity: quantityOf?.call(product),
                  onTap: onProductTap == null
                      ? null
                      : () => onProductTap!(product),
                  onIncrement:
                      onIncrement == null ? null : () => onIncrement!(product),
                  onDecrement:
                      onDecrement == null ? null : () => onDecrement!(product),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
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
