library;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/typography.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_icon.dart';
import '../home_view_data.dart';

/// The public landing page. Backend data remains authoritative; missing campaign
/// artwork gets an intentional visual treatment instead of an empty colour block.
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
  final Widget? sidebar;
  final int cartItemCount;
  final int? cartTotal;

  static const double _gutter = 16;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      drawer: sidebar,
      drawerEdgeDragWidth: sidebar == null ? 0 : 40,
      body: Stack(
        children: [
          Positioned(
            top: -130,
            right: -120,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [palette.accentFaint, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Builder(
              builder: (scaffoldContext) => CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            _gutter,
                            14,
                            _gutter,
                            AppCartButton.clearance +
                                MediaQuery.paddingOf(context).bottom +
                                24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Header(
                                data: data,
                                onCallCenter: onCallCenter,
                                onFavorites: onFavorites,
                                onLiked: onLiked,
                                onNotifications: onNotifications,
                                onMenu: onProfile ??
                                    () => Scaffold.of(scaffoldContext)
                                        .openDrawer(),
                              ),
                              const SizedBox(height: 22),
                              _StoreCard(
                                data: data,
                                onStore: onStore,
                                onCallCenter: onCallCenter,
                              ),
                              const SizedBox(height: 14),
                              _SearchField(onTap: onSearch),
                              const SizedBox(height: 28),
                              const _SectionHeader(
                                eyebrow: 'ДЛЯ ВАС',
                                title: 'Актуальные предложения',
                              ),
                              const SizedBox(height: 14),
                              _BannerCarousel(banners: data.banners),
                              if (data.promoCard != null) ...[
                                const SizedBox(height: 30),
                                _FeatureCard(
                                  card: data.promoCard!,
                                  onTap: onCategory == null
                                      ? null
                                      : () => onCategory!(HomeCategory(
                                            id: data.promoCard!.id,
                                            title: data.promoCard!.title,
                                          )),
                                ),
                              ],
                              const SizedBox(height: 30),
                              const _SectionHeader(
                                eyebrow: 'КАТАЛОГ',
                                title: 'Выберите категорию',
                              ),
                              const SizedBox(height: 14),
                              _CategoryGrid(
                                categories: data.categories,
                                onTap: onCategory,
                              ),
                              if (!data.signedIn ||
                                  data.bonusBalance != null) ...[
                                const SizedBox(height: 30),
                                _BonusCard(
                                  data: data,
                                  onHistory: onBonusHistory,
                                  onSignIn: onSignIn,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 12,
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

class _Header extends StatelessWidget {
  const _Header({
    required this.data,
    this.onCallCenter,
    this.onFavorites,
    this.onLiked,
    this.onNotifications,
    this.onMenu,
  });

  final HomeViewData data;
  final VoidCallback? onCallCenter;
  final VoidCallback? onFavorites;
  final VoidCallback? onLiked;
  final VoidCallback? onNotifications;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: palette.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: palette.accent.withValues(alpha: .16),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const AppIcon(AppIcons.logo, width: 46, height: 46),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCallCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Градусы24',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title.copyWith(
                    color: palette.textPrimary,
                    letterSpacing: -.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.callCenterLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        _HeaderAction(
          asset: AppIcons.heart,
          label: 'Избранное',
          onTap: onLiked ?? onFavorites,
        ),
        const SizedBox(width: 7),
        _HeaderAction(
          asset: AppIcons.bell,
          label: 'Уведомления',
          onTap: onNotifications,
          badgeCount: data.notificationCount,
        ),
        const SizedBox(width: 7),
        _HeaderAction(
          asset: AppIcons.user,
          label: 'Меню',
          onTap: onMenu,
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.asset,
    required this.label,
    this.onTap,
    this.badgeCount = 0,
  });

  final String asset;
  final String label;
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AppIcon(
                  asset,
                  size: 20,
                  color: asset == AppIcons.bell ? null : palette.textPrimary,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -3,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 17, minHeight: 17),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: palette.brandRed,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: palette.background, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$badgeCount',
                        style:
                            AppTypography.base(size: 8, weight: 700).copyWith(
                          color: Colors.white,
                          height: 1,
                        ),
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

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.data, this.onStore, this.onCallCenter});

  final HomeViewData data;
  final VoidCallback? onStore;
  final VoidCallback? onCallCenter;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.accent,
            const Color(0xFFE34A00),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: .22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -34,
            top: -48,
            child: _DecorativeOrb(size: 142, opacity: .11),
          ),
          const Positioned(
            right: 62,
            bottom: -54,
            child: _DecorativeOrb(size: 94, opacity: .08),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .18),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const AppIcon(
                        AppIcons.shop,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ваш магазин',
                            style: AppTypography.labelSemibold.copyWith(
                              color: Colors.white.withValues(alpha: .72),
                              letterSpacing: .55,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            data.storeName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.title.copyWith(
                              color: Colors.white,
                              height: 1.12,
                            ),
                          ),
                          if (data.storeAddress.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const AppIcon(
                                  AppIcons.location,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    data.storeAddress,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodySmall.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: .82),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _GlassButton(
                      label: 'Сменить',
                      icon: Icons.arrow_forward_rounded,
                      onTap: onStore,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: .16),
                ),
                const SizedBox(height: 11),
                InkWell(
                  onTap: onCallCenter,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      const AppIcon(AppIcons.phone,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data.phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmallSemibold.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Поддержка',
                        style: AppTypography.labelMedium.copyWith(
                          color: Colors.white.withValues(alpha: .7),
                        ),
                      ),
                    ],
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

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.label, required this.icon, this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style:
                    AppTypography.labelSemibold.copyWith(color: Colors.white),
              ),
              const SizedBox(width: 5),
              Icon(icon, size: 14, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _DecorativeOrb extends StatelessWidget {
  const _DecorativeOrb({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
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
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          height: 54,
          padding: const EdgeInsets.fromLTRB(15, 7, 7, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: palette.divider.withValues(alpha: .8)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.accentFaint,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child:
                    AppIcon(AppIcons.search, size: 18, color: palette.accent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Найти любимый напиток',
                  style:
                      AppTypography.body.copyWith(color: palette.textSecondary),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: const _BarcodeGlyph(width: 18, height: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarcodeGlyph extends StatelessWidget {
  const _BarcodeGlyph({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(width, height),
        painter: _BarcodePainter(context.palette.textOnAccent),
      );
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;
    const weights = [1.0, 1.7, .8, 1.7, 1.0];
    const gap = 1.25;
    final total = weights.reduce((a, b) => a + b) + gap * (weights.length - 1);
    final scale = size.width / total;
    var x = 0.0;
    for (final width in weights) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0, width * scale, size.height),
          const Radius.circular(1),
        ),
        paint,
      );
      x += (width + gap) * scale;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter oldDelegate) => oldDelegate.color != color;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: AppTypography.labelSemibold.copyWith(
            color: palette.accent,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: AppTypography.headline.copyWith(
            color: palette.textPrimary,
            letterSpacing: -.35,
          ),
        ),
      ],
    );
  }
}

class _BannerCarousel extends StatelessWidget {
  const _BannerCarousel({required this.banners});

  final List<HomeBanner> banners;

  static const _gradients = <List<Color>>[
    [Color(0xFF98142A), Color(0xFF5D0715)],
    [Color(0xFF643979), Color(0xFF321340)],
    [Color(0xFFF16800), Color(0xFFB93A00)],
  ];

  @override
  Widget build(BuildContext context) {
    final items = banners.isEmpty
        ? const [HomeBanner(title: 'Специальные предложения')]
        : banners;
    return SizedBox(
      height: 156,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth * .88).clamp(280.0, 430.0);
          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 11),
            itemBuilder: (context, index) => SizedBox(
              width: cardWidth,
              child: _BannerCard(
                banner: items[index],
                colors: _gradients[index % _gradients.length],
                index: index,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.banner,
    required this.colors,
    required this.index,
  });

  final HomeBanner banner;
  final List<Color> colors;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: .28),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (banner.imageUrl != null)
            _NetworkArtwork(url: banner.imageUrl!, fit: BoxFit.cover),
          if (banner.imageUrl != null)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xCC000000), Color(0x12000000)],
                ),
              ),
            )
          else ...[
            Positioned(
              right: -18,
              top: -28,
              child: _PromoMedallion(index: index),
            ),
            Positioned(
              right: 74,
              bottom: -42,
              child: Container(
                width: 105,
                height: 105,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .06),
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 19, 106, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ВЫГОДНО',
                    style: AppTypography.captionMedium.copyWith(
                      color: Colors.white,
                      letterSpacing: .8,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  banner.title.isEmpty ? 'Акции' : banner.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.displayBold.copyWith(
                    color: Colors.white,
                    height: 1.05,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  banner.subtitle ?? 'Актуальные предложения уже в каталоге',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    color: Colors.white.withValues(alpha: .78),
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

class _PromoMedallion extends StatelessWidget {
  const _PromoMedallion({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.percent_rounded,
      Icons.local_fire_department_rounded,
      Icons.star_rounded
    ];
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .09),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .12),
        ),
        alignment: Alignment.center,
        child: Icon(icons[index % icons.length], color: Colors.white, size: 38),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.card, this.onTap});

  final HomePromoCard card;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          height: 190,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.surface,
                Color.lerp(palette.surface, palette.accent, .14)!,
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (card.imageUrl != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 220,
                    height: 190,
                    child:
                        _NetworkArtwork(url: card.imageUrl!, fit: BoxFit.cover),
                  ),
                )
              else
                const Positioned(
                  right: 18,
                  bottom: 5,
                  child: _KitchenIllustration(),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      palette.surface,
                      palette.surface.withValues(alpha: .94),
                      palette.surface.withValues(alpha: .08),
                    ],
                    stops: const [0, .46, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      card.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display.copyWith(
                        color: palette.textPrimary,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      width: 150,
                      child: Text(
                        card.subtitle.isEmpty
                            ? 'Всё необходимое для отличного вечера'
                            : card.subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: palette.textSecondary,
                          height: 1.22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Открыть',
                          style: AppTypography.bodySmallSemibold.copyWith(
                            color: palette.accent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 16, color: palette.accent),
                      ],
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

class _KitchenIllustration extends StatelessWidget {
  const _KitchenIllustration();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: 158,
      height: 158,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 136,
            height: 136,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.accentFaint,
            ),
          ),
          Transform.rotate(
            angle: -.08,
            child: Container(
              width: 92,
              height: 112,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.accent, const Color(0xFFE34A00)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: palette.accent.withValues(alpha: .28),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.restaurant_rounded,
                  color: Colors.white, size: 46),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories, this.onTap});

  final List<HomeCategory> categories;
  final ValueChanged<HomeCategory>? onTap;

  static const _colors = <List<Color>>[
    [Color(0xFFF16800), Color(0xFFD54A00)],
    [Color(0xFF7E3EA1), Color(0xFF4D2161)],
    [Color(0xFFB0172F), Color(0xFF720917)],
    [Color(0xFF2A7B71), Color(0xFF174B45)],
    [Color(0xFFB47B29), Color(0xFF704711)],
    [Color(0xFF3F5E93), Color(0xFF253A5F)],
  ];

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final tileWidth = (constraints.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: 14,
          children: [
            for (var index = 0; index < categories.length; index++)
              SizedBox(
                width: tileWidth,
                child: _CategoryTile(
                  category: categories[index],
                  colors: _colors[index % _colors.length],
                  index: index,
                  onTap: onTap == null ? null : () => onTap!(categories[index]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.colors,
    required this.index,
    this.onTap,
  });

  final HomeCategory category;
  final List<Color> colors;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: category.title,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              Ink(
                height: 108,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (category.imageUrl != null)
                      _NetworkArtwork(
                          url: category.imageUrl!, fit: BoxFit.cover)
                    else
                      _CategoryFallback(index: index),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: .12)
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .16),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.arrow_outward_rounded,
                            color: Colors.white, size: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: Text(
                  category.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmallSemibold.copyWith(
                    color: palette.textPrimary,
                    height: 1.15,
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

class _CategoryFallback extends StatelessWidget {
  const _CategoryFallback({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.local_bar_rounded,
      Icons.tapas_rounded,
      Icons.liquor_rounded,
      Icons.local_drink_rounded,
      Icons.smoking_rooms_rounded,
      Icons.auto_awesome_rounded,
    ];
    return Stack(
      children: [
        Positioned(
          right: -16,
          bottom: -18,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .1),
            ),
          ),
        ),
        Center(
          child: Icon(
            icons[index % icons.length],
            color: Colors.white,
            size: 40,
          ),
        ),
      ],
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
    final signedIn = data.signedIn && data.bonusBalance != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(palette.surface, palette.gold, .10)!,
            palette.surface,
          ],
        ),
        border: Border.all(color: palette.gold.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.gold.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: const AppIcon(AppIcons.bonusStar, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Бонусная карта',
                      style: AppTypography.title
                          .copyWith(color: palette.textPrimary),
                    ),
                    Text(
                      signedIn
                          ? 'Ваш баланс'
                          : 'Копите бонусы с каждой покупкой',
                      style: AppTypography.label
                          .copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              if (signedIn)
                TextButton(
                  onPressed: onHistory,
                  style: TextButton.styleFrom(foregroundColor: palette.accent),
                  child: const Text('История'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (signedIn)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data.bonusBalance}',
                        style: AppTypography.displayLarge.copyWith(
                          color: palette.gold,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        data.bonusCaption,
                        style: AppTypography.bodySmall
                            .copyWith(color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 94,
                  height: 94,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: BarcodeWidget(
                    barcode: Barcode.qrCode(),
                    data: data.bonusCardCode ?? '',
                  ),
                ),
              ],
            )
          else
            Material(
              color: palette.accent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onSignIn,
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Center(
                    child: Text(
                      'Войти или зарегистрироваться',
                      style:
                          AppTypography.bodyBold.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NetworkArtwork extends StatelessWidget {
  const _NetworkArtwork({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return const SizedBox.shrink();
      },
    );
  }
}
