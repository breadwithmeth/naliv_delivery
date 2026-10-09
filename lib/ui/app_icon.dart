import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icons exported from the redesign itself (`assets/icons/design`), so shapes match the
/// design exactly instead of being approximated with a third-party icon font.
///
/// Regenerate the theme-specific brand glyphs with:
///   dart run tool/figma_spec.dart svg --map .figma_cache/issue_brand_assets.json
///
/// `store` and `scan` are PNG exports: Figma's SVG renderer returns an empty image for those
/// two nodes, so they are rasterised at 4× instead.
abstract final class AppIcons {
  static const String root = 'assets/icons/design';

  static const String logo = '$root/logo.svg';
  static const String logoDark = '$root/logo_dark.svg';

  /// Horizontal «градусы 24» lockup — the intro slides and the splash, not the round badge.
  static const String wordmark = '$root/wordmark.svg';
  static const String phone = '$root/phone.svg';

  /// The store glyph: the design's own `Store_Icon_UIA` node cannot be rendered by Figma's
  /// image API (it returns an empty image for it), so the same-family shop glyph is used at
  /// 12 px instead.
  static const String store = '$root/shop.svg';
  static const String location = '$root/location.svg';
  static const String shop = '$root/shop.svg';
  static const String star = '$root/star.svg';
  static const String heart = '$root/heart.svg';
  static const String bell = '$root/bell.svg';
  static const String user = '$root/user.svg';
  static const String search = '$root/search.svg';
  static const String repeat = '$root/repeat.svg';

  /// Badge glyphs: discount and bonus markers used on product cards.
  static const String fire = '$root/fire.svg';
  static const String bonusStar = '$root/bonus_star.svg';

  /// Chevron used by every secondary screen's back disc.
  static const String back = '$root/back.svg';

  /// Confirmation glyph in the product page's "added to cart" pill.
  static const String check = '$root/check.svg';

  // Intro slide glyphs (`Регистрация и логин - Слайд 1…4`). The layers all carry the name
  // `vuesax/bold/discount-shape` in the file, but the exported files are genuinely different
  // shapes — the designer kept the layer name while swapping the component.
  static const String discountShape = '$root/discount_shape.svg';
  static const String bagHappy = '$root/bag_happy.svg';
  static const String bagTimer = '$root/bag_timer.svg';
  static const String cart = '$root/cart.svg';
  static const String cartFab = '$root/cart_fab.svg';

  // Profile / sidebar tool glyphs, exported from the design's Профиль screen.
  static const String orders = '$root/orders.svg';
  static const String certificates = '$root/certificates.svg';
  static const String support = '$root/support.svg';
  static const String faq = '$root/faq.svg';
  static const String addresses = '$root/addresses.svg';
  static const String cards = '$root/cards.svg';
  static const String analytics = '$root/analytics.svg';
  static const String theme = '$root/theme.svg';
  static const String logout = '$root/logout.svg';
  static const String avatar = '$root/avatar.svg';
}

/// Draws a design icon at an explicit size.
///
/// [color] tints single-colour icons (`BlendMode.srcIn`); leave it null for icons that carry
/// their own colours, such as the logo and the bell with its badge.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.asset, {
    this.size = 24,
    this.width,
    this.height,
    this.color,
    super.key,
  });

  final String asset;
  final double size;
  final double? width;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    if (asset.endsWith('.svg')) {
      return SvgPicture.asset(
        asset,
        width: w,
        height: h,
        colorFilter:
            color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      );
    }
    return Image.asset(
      asset,
      width: w,
      height: h,
      color: color,
      filterQuality: FilterQuality.high,
    );
  }
}
