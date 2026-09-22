import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/money.dart';
import '../../../core/product_view.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/app_icon_button.dart';
import '../../../ui/surfaces.dart';
import '../../../utils/cart_provider.dart';

/// Product detail — the design's `Описание товара` frames.
///
/// Measured from the frame (375 × 812, content 985 tall):
///
/// * full-bleed hero image 375 × 320, starting at y = 0 so it runs under the status bar;
/// * a **fixed** header at y = 70 that does not scroll with the content;
/// * category + origin at y = 336, title 24/700 beneath it, badges (62 × 23.4, r5, 14/500)
///   right-aligned on the same line;
/// * price stack at y = 411 — struck 16/400, price **32/700 in the accent** (not white as on
///   the cards), «Выгода» 16/500 gold;
/// * «Количество» at y = 519 with a 343 × 54 r18 control (38 px accent squares, «1 шт» 20/500);
/// * «Описание» at y = 626 with a 14/500 body and a 14/700 accent «Читать далее» toggle;
/// * a 129 px glass action bar: total 24/700 plus a 175 × 49 accent «В корзину» pill, which
///   becomes a full-width 343 × 54 success-coloured «Добавлено в корзину» pill after adding.
///
/// The design shows **no option or portion UI**; this page therefore drives the existing cart
/// API through the quantity control only. Items that carry options are a known gap — see the
/// class doc in the handoff notes.
class ProductPage extends StatefulWidget {
  const ProductPage({
    required this.view,
    this.liked = false,
    this.onLike,
    this.onCart,
    super.key,
  });

  final ProductView view;
  final bool liked;

  /// Toggles the favourite flag; the caller owns the API call.
  final VoidCallback? onLike;

  /// Opens the cart; null hides the action bar's cart affordance.
  final VoidCallback? onCart;

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  bool _added = false;
  bool _expanded = false;

  static const double _heroHeight = 320;
  static const double _actionBarHeight = 129;

  Future<void> _addToCart() async {
    context.read<CartProvider>().incrementCatalogItem(widget.view.source);
    setState(() => _added = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _added = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cart = context.watch<CartProvider>();
    final quantity = cart.getCatalogQuantity(widget.view.source);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(
                bottom: _actionBarHeight + AppSpacing.huge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Hero(imageUrl: widget.view.imageUrl, height: _heroHeight),
                const SizedBox(height: AppSpacing.xxxl),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _TitleBlock(view: widget.view)),
                      if (widget.view.discount != null ||
                          widget.view.bonus != null)
                        _Badges(
                          discount: widget.view.discount,
                          bonus: widget.view.bonus,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: _PriceStack(view: widget.view),
                ),
                const SizedBox(height: AppSpacing.huge),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: _QuantityControl(
                    quantity: quantity,
                    unit: widget.view.unit,
                    onIncrement: () => context
                        .read<CartProvider>()
                        .incrementCatalogItem(widget.view.source),
                    onDecrement: () => context
                        .read<CartProvider>()
                        .decrementCatalogItem(widget.view.source),
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: _Description(
                    text: widget.view.source.description ?? '',
                    expanded: _expanded,
                    onToggle: () => setState(() => _expanded = !_expanded),
                  ),
                ),
              ],
            ),
          ),
          // Fixed header: the frames keep it at y = 70 while the hero scrolls away.
          Positioned(
            left: AppSpacing.xxxl,
            right: AppSpacing.xxxl,
            top: topInset + 22,
            child: SizedBox(
              height: 57,
              child: Row(
                children: [
                  AppIconButton(
                    asset: AppIcons.back,
                    onTap: () => Navigator.of(context).maybePop(),
                    tooltip: 'Назад',
                  ),
                  const Spacer(),
                  AppIconButton(
                    // The design keeps the outline heart in both states and only tints the
                    // disc, so no filled glyph is needed here.
                    asset: AppIcons.heart,
                    onTap: widget.onLike,
                    tooltip: 'В избранное',
                    size: 40,
                    glyphSize: 24,
                    fill: widget.liked
                        ? palette.brandRed.withValues(alpha: 0.5)
                        : palette.surface.withValues(alpha: 0.75),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ActionBar(
              height: _actionBarHeight,
              total: widget.view.price * (quantity <= 0 ? 1 : quantity).toInt(),
              added: _added,
              onAdd: _addToCart,
              onCart: widget.onCart,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.imageUrl, required this.height});

  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      // The design's hero is `#FFFFFF` + image, filling the full width under the status bar.
      child: imageUrl == null
          ? const ColoredBox(color: Colors.white)
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: Colors.white),
            ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.view});

  final ProductView view;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (view.category != null)
              Text(
                view.category!,
                style: AppTypography.base(size: 12, height: 1.3)
                    .copyWith(color: palette.textSecondary),
              ),
            if (view.category != null && view.country != null)
              const SizedBox(width: AppSpacing.md),
            if (view.country != null)
              Text(
                view.country!,
                style: AppTypography.base(size: 12, height: 1.3)
                    .copyWith(color: palette.gold),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          view.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.displayBold.copyWith(color: palette.textPrimary),
        ),
      ],
    );
  }
}

/// Product-page badges: 62 × 23.4, r5, 14/500 — larger than the card's 8/500 chips.
class _Badges extends StatelessWidget {
  const _Badges({this.discount, this.bonus});

  final String? discount;
  final String? bonus;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (discount != null) _pill(palette, discount!, palette.brandRed),
        if (discount != null && bonus != null) const SizedBox(height: 8),
        if (bonus != null) _pill(palette, bonus!, palette.gold),
      ],
    );
  }

  Widget _pill(AppPalette palette, String label, Color fill) {
    return Container(
      width: 62,
      height: 23.4,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: AppTypography.body.copyWith(color: Colors.white, height: 1),
      ),
    );
  }
}

class _PriceStack extends StatelessWidget {
  const _PriceStack({required this.view});

  final ProductView view;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (view.oldPrice != null)
          Text(
            formatTenge(view.oldPrice!),
            style: AppTypography.titleRegular.copyWith(
              color: palette.textSecondary,
              decoration: TextDecoration.lineThrough,
              height: 1.3,
            ),
          ),
        Text(
          formatTenge(view.price),
          style: AppTypography.base(size: 32, weight: 700)
              .copyWith(color: palette.accent),
        ),
        if (view.saving != null)
          Text(
            'Выгода ${formatTenge(view.saving!)}',
            style: AppTypography.titleMedium.copyWith(color: palette.gold),
          ),
      ],
    );
  }
}

/// «Количество» plus the 343 × 54 control: 38 px accent squares inset 8.5, count at 20/500.
class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.quantity,
    this.unit,
    this.onIncrement,
    this.onDecrement,
  });

  final num quantity;
  final String? unit;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  static const double _button = 38;
  static const double _inset = 8.5;

  String get _label {
    final value = quantity <= 0 ? 0 : quantity;
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return unit == null ? text : '$text $unit';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Количество',
          style:
              AppTypography.titleRegular.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const SizedBox(width: _inset),
              _square(palette, onDecrement, const _MinusGlyph()),
              Expanded(
                child: Center(
                  child: Text(
                    _label,
                    style: AppTypography.base(size: 20, weight: 500)
                        .copyWith(color: palette.textPrimary),
                  ),
                ),
              ),
              _square(palette, onIncrement, const _PlusGlyph()),
              const SizedBox(width: _inset),
            ],
          ),
        ),
      ],
    );
  }

  Widget _square(AppPalette palette, VoidCallback? onTap, Widget glyph) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: _button,
        height: _button,
        decoration: BoxDecoration(
          color: palette.accentSoft,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Center(child: glyph),
      ),
    );
  }
}

class _MinusGlyph extends StatelessWidget {
  const _MinusGlyph();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 12,
        height: 1.6,
        child: ColoredBox(color: Colors.white),
      );
}

class _PlusGlyph extends StatelessWidget {
  const _PlusGlyph();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 12,
        height: 12,
        child: Stack(
          children: [
            Center(
              child: SizedBox(
                width: 12,
                height: 1.6,
                child: ColoredBox(color: Colors.white),
              ),
            ),
            Center(
              child: SizedBox(
                width: 1.6,
                height: 12,
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ],
        ),
      );
}

/// «Описание» with the frame's clamp-and-toggle behaviour.
class _Description extends StatelessWidget {
  const _Description({
    required this.text,
    required this.expanded,
    this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback? onToggle;

  static const int _clampLines = 6;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Описание',
          style: AppTypography.title.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxl),
        LayoutBuilder(
          builder: (context, constraints) {
            final style = AppTypography.bodyMedium
                .copyWith(color: palette.textSecondary, height: 1.3);
            final painter = TextPainter(
              text: TextSpan(text: text, style: style),
              maxLines: _clampLines,
              textDirection: Directionality.of(context),
            )..layout(maxWidth: constraints.maxWidth);
            final overflows = painter.didExceedMaxLines;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: style,
                  maxLines: expanded ? null : _clampLines,
                  overflow: expanded ? TextOverflow.visible : TextOverflow.clip,
                ),
                if (overflows) ...[
                  const SizedBox(height: AppSpacing.lg),
                  GestureDetector(
                    onTap: onToggle,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      expanded ? 'Свернуть' : 'Читать далее',
                      style: AppTypography.bodyBold
                          .copyWith(color: palette.accent),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Glass action bar: total plus «В корзину», switching to the success pill once added.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.height,
    required this.total,
    required this.added,
    this.onAdd,
    this.onCart,
  });

  final double height;
  final int total;
  final bool added;
  final VoidCallback? onAdd;
  final VoidCallback? onCart;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: height,
      child: AppGlassPanel(
        radius: 0,
        tint: Colors.black.withValues(alpha: 0.2),
        blur: 12,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.huge,
            AppSpacing.xxxl,
            AppSpacing.xxxl,
            0,
          ),
          child: added
              ? GestureDetector(
                  onTap: onCart,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      color: palette.success.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppIcon(AppIcons.check,
                            size: 26, color: Colors.white),
                        const SizedBox(width: AppSpacing.xl),
                        Text(
                          'Добавлено в корзину',
                          style:
                              AppTypography.title.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
              : Row(
                  children: [
                    Text(
                      formatTenge(total),
                      style: AppTypography.base(size: 24, weight: 700)
                          .copyWith(color: palette.textPrimary),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onAdd,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 175,
                        height: 49,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: palette.accentSoft,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          'В корзину',
                          style:
                              AppTypography.title.copyWith(color: Colors.white),
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
