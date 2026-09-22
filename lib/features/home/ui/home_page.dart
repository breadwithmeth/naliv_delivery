library;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/surfaces.dart';
import '../home_view_data.dart';

/// The redesigned home screen.
///
/// Geometry below is taken from the design frame (375 × 812) rather than approximated: the
/// header block sits 24 px under the status bar, every section is separated by 24 px (the
/// address card and search field by 12 px), the promo carousel is 295 × 114 with a 10 px gap
/// and a 40 px lead-in so the first banner is centred with the next one peeking, the category
/// grid is 3 × 98 px tiles with 24.5 px gutters, and the bottom bar is a 375 × 88 glass panel
/// with an 78 px cart button floating over its top edge.
class HomePage extends StatelessWidget {
  const HomePage({
    required this.data,
    this.onSearch,
    this.onFavorites,
    this.onLiked,
    this.onNotifications,
    this.onProfile,
    this.onCallCenter,
    this.onStore,
    this.onCategory,
    this.onCart,
    this.onBonusHistory,
    this.onSignIn,
    this.sidebar,
    this.cartItemCount = 0,
    this.cartTotal,
    super.key,
  });

  final HomeViewData data;

  final VoidCallback? onSearch;
  final VoidCallback? onFavorites;
  final VoidCallback? onLiked;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;
  final VoidCallback? onCallCenter;
  final VoidCallback? onStore;
  final ValueChanged<HomeCategory>? onCategory;
  final VoidCallback? onCart;
  final VoidCallback? onBonusHistory;
  final VoidCallback? onSignIn;

  /// Navigation drawer. The design has none, so the shell supplies it.
  final Widget? sidebar;

  final int cartItemCount;
  final int? cartTotal;

  static const double _gutter = 16;
  static const double _sectionGap = 24;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      // The sidebar replaces the old tab bar; there is no bottom navigation at all.
      drawer: sidebar,
      drawerEdgeDragWidth: sidebar == null ? 0 : 40,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Builder(
              builder: (context) => Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + _sectionGap,
                  bottom: AppCartButton.clearance +
                      MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _gutter),
                      child: _Header(
                        data: data,
                        onCallCenter: onCallCenter,
                        onFavorites: onFavorites,
                        onLiked: onLiked,
                        onNotifications: onNotifications,
                        // The account action opens the sidebar, which is where Профиль and
                        // every other tool now live.
                        onProfile: onProfile ??
                            () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _gutter),
                      child: _AddressCard(data: data, onTap: onStore),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _gutter),
                      child: _SearchField(onTap: onSearch),
                    ),
                    const SizedBox(height: _sectionGap),
                    _BannerCarousel(banners: data.banners),
                    const SizedBox(height: _sectionGap),
                    if (data.promoCard != null)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: _gutter),
                        child: _PromoCard(
                            card: data.promoCard!,
                            onTap: onCategory == null
                                ? null
                                : () => onCategory!(HomeCategory(
                                    id: data.promoCard!.id,
                                    title: data.promoCard!.title))),
                      ),
                    if (data.promoCard != null)
                      const SizedBox(height: _sectionGap),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _gutter),
                      child: _CategoryGrid(
                          categories: data.categories, onTap: onCategory),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (data.bonusBalance != null)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: _gutter),
                        child: _BonusCard(
                          data: data,
                          onHistory: onBonusHistory,
                          onSignIn: onSignIn,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // The only floating control: the cart button, with the total when the cart is filled.
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
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
    );
  }
}

/// Header: badge logo, support phone block and the four account actions.
class _Header extends StatelessWidget {
  const _Header({
    required this.data,
    this.onCallCenter,
    this.onFavorites,
    this.onLiked,
    this.onNotifications,
    this.onProfile,
  });

  final HomeViewData data;
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AppIcon(AppIcons.logo, width: 52, height: 49),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: InkWell(
              onTap: onCallCenter,
              child: Row(
                children: [
                  const AppIcon(AppIcons.phone, size: 16),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.phone,
                        style: AppTypography.bodySmall
                            .copyWith(color: palette.textSecondary),
                      ),
                      Text(
                        data.callCenterLabel,
                        style: AppTypography.label
                            .copyWith(color: palette.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _HeaderAction(AppIcons.star, onTap: onFavorites),
          const SizedBox(width: AppSpacing.lg),
          _HeaderAction(AppIcons.heart, onTap: onLiked),
          const SizedBox(width: AppSpacing.lg),
          _HeaderAction(
            AppIcons.bell,
            onTap: onNotifications,
            badgeCount: data.notificationCount,
          ),
          const SizedBox(width: AppSpacing.lg),
          _HeaderAction(AppIcons.user, onTap: onProfile),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction(this.asset, {this.onTap, this.badgeCount = 0});

  final String asset;
  final VoidCallback? onTap;
  final int badgeCount;

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
          children: [
            AppIcon(
              asset,
              size: 24,
              color: asset == AppIcons.bell ? null : palette.textPrimary,
            ),
            if (badgeCount > 0)
              Positioned(
                top: -2,
                right: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  constraints:
                      const BoxConstraints(minWidth: 14, minHeight: 14),
                  decoration: BoxDecoration(
                    color: palette.brandRed,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Center(
                    child: Text(
                      '$badgeCount',
                      style: AppTypography.base(size: 8, weight: 700).copyWith(
                        color: Colors.white,
                        height: 1,
                      ),
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

/// Store name + address, with the "change store" action on the right.
class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.data, this.onTap});

  final HomeViewData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppSurface(
      fill: palette.surface.withValues(alpha: 0.75),
      radius: AppRadii.lg,
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 9, AppSpacing.md, 10),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    AppIcon(AppIcons.store,
                        width: 12, height: 12, color: palette.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        data.storeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmallBold
                            .copyWith(color: palette.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    AppIcon(AppIcons.location,
                        width: 12, height: 12, color: palette.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        data.storeAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall
                            .copyWith(color: palette.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AppSurface(
            fill: palette.accentSoft,
            radius: AppRadii.md,
            width: 32,
            height: 32,
            child: const Center(child: AppIcon(AppIcons.shop, size: 20)),
          ),
        ],
      ),
    );
  }
}

/// Pill search field: 38 px tall, radius 30, with the scan action pinned right.
class _SearchField extends StatelessWidget {
  const _SearchField({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppSurface(
      fill: palette.surface.withValues(alpha: 0.75),
      radius: 30,
      height: 38,
      // Asymmetric padding, as in the frame: the icon sits 14 px in, the scan button 4 px.
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
      onTap: onTap,
      child: Row(
        children: [
          AppIcon(AppIcons.search, size: 16, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Найти любимый напиток...',
              style: AppTypography.bodyLight
                  .copyWith(color: palette.textSecondary),
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration:
                BoxDecoration(color: palette.accent, shape: BoxShape.circle),
            child: const Center(child: _BarcodeGlyph(width: 16, height: 10)),
          ),
        ],
      ),
    );
  }
}

/// The scan action inside the search field.
///
/// Figma's image API returns an empty render for this node, so the glyph is drawn here to
/// match the frame: five bars of alternating width inside the accent circle.
class _BarcodeGlyph extends StatelessWidget {
  const _BarcodeGlyph({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _BarcodePainter(context.palette.textOnAccent),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const weights = [1.0, 1.6, 0.8, 1.6, 1.0];
    const gap = 1.2;
    final total = weights.reduce((a, b) => a + b) + gap * (weights.length - 1);
    final scale = size.width / total;
    var x = 0.0;
    for (final w in weights) {
      canvas.drawRect(Rect.fromLTWH(x, 0, w * scale, size.height), paint);
      x += (w + gap) * scale;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter oldDelegate) => oldDelegate.color != color;
}

/// Horizontally scrolling promo banners. The 40 px lead-in centres the first card, matching
/// the frame, where the neighbouring card peeks in from the right.
class _BannerCarousel extends StatelessWidget {
  const _BannerCarousel({required this.banners});

  final List<HomeBanner> banners;

  static const double _cardWidth = 295;
  static const double _cardHeight = 114;
  static const double _gap = AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: _cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: (375 - _cardWidth) / 2),
        itemCount: banners.length,
        separatorBuilder: (_, __) => const SizedBox(width: _gap),
        itemBuilder: (context, index) {
          final banner = banners[index];
          return AppSurface(
            width: _cardWidth,
            radius: AppRadii.lg,
            fill: banner.fill ?? palette.brandRed,
            clip: true,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (banner.imageUrl != null)
                  Image.network(banner.imageUrl!, fit: BoxFit.cover),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (banner.title.isNotEmpty)
                        Text(
                          banner.title,
                          style: AppTypography.headline
                              .copyWith(color: Colors.white),
                        ),
                      if (banner.subtitle != null)
                        Text(
                          banner.subtitle!,
                          style:
                              AppTypography.label.copyWith(color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Full-width promo card ("Кухня").
class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.card, this.onTap});

  final HomePromoCard card;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppSurface(
      width: double.infinity,
      height: 160,
      radius: AppRadii.lg,
      fill: card.fill ?? palette.surface,
      clip: true,
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (card.imageUrl != null)
            Image.network(card.imageUrl!, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xxxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.title,
                    style: AppTypography.headline
                        .copyWith(color: palette.textPrimary)),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: 131,
                  child: Text(
                    card.subtitle,
                    style: AppTypography.label.copyWith(
                      color: palette.textPrimary,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 3-column category grid: 98 px tiles, 24.5 px gutters, 12 px label under each tile.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories, this.onTap});

  final List<HomeCategory> categories;
  final ValueChanged<HomeCategory>? onTap;

  static const double _tile = 98;
  static const double _tileGap = 24.5;
  static const double _rowGap = 6.4;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      spacing: _tileGap,
      runSpacing: _rowGap,
      children: [
        for (final category in categories)
          GestureDetector(
            onTap: onTap == null ? null : () => onTap!(category),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: _tile,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSurface(
                    width: _tile,
                    height: _tile,
                    radius: AppRadii.lg,
                    fill: category.fill ?? palette.accent,
                    clip: true,
                    child: category.imageUrl == null
                        ? const SizedBox.shrink()
                        : Image.network(category.imageUrl!, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    height: 24,
                    width: _tile,
                    child: Text(
                      category.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: AppTypography.bodySmall.copyWith(
                        color: palette.textPrimary,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Bonus balance and the QR the customer shows at the till.
class _BonusCard extends StatelessWidget {
  const _BonusCard({required this.data, this.onHistory, this.onSignIn});

  final HomeViewData data;
  final VoidCallback? onHistory;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final signedIn = data.signedIn && data.bonusBalance != null;
    return AppSurface(
      width: double.infinity,
      radius: AppRadii.lg,
      fill: palette.surface.withValues(alpha: 0.75),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(AppIcons.bonusStar, size: 19),
              const SizedBox(width: AppSpacing.md),
              Text('Бонусная карта',
                  style:
                      AppTypography.title.copyWith(color: palette.textPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data.bonusBalance ?? 0}',
                style: AppTypography.display.copyWith(color: palette.accent),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(data.bonusCaption,
                    style: AppTypography.bodySmallSemibold
                        .copyWith(color: palette.textSecondary)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onHistory,
                child: AppSurface(
                  fill: palette.accentSoft,
                  radius: 68,
                  height: 32.9,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIcon(AppIcons.repeat,
                          size: 15.6, color: Colors.white),
                      const SizedBox(width: AppSpacing.md),
                      Text('История',
                          style: AppTypography.labelBold
                              .copyWith(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (signedIn)
            AppSurface(
              fill: palette.surfaceMuted,
              radius: AppRadii.lg,
              height: 165,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.xs),
                    ),
                    child: BarcodeWidget(
                      barcode: Barcode.qrCode(),
                      // The raw card UUID is what the till scans (same payload the existing
                      // main page sends).
                      data: data.bonusCardCode ?? '',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(data.qrCaption,
                      style: AppTypography.label
                          .copyWith(color: palette.surfaceMuted)),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: onSignIn,
              child: AppSurface(
                fill: palette.surfaceMuted,
                radius: AppRadii.lg,
                height: 165,
                child: Center(
                  child: Text('Войдите, чтобы копить бонусы',
                      style: AppTypography.bodyMedium
                          .copyWith(color: palette.textPrimary)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
