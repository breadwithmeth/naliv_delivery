import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/money.dart';
import '../../../core/product_view.dart';
import '../../../design/theme.dart';
import '../../../ui/app_states.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_top_bar.dart';
import '../../../ui/product_card.dart';
import '../../../ui/surfaces.dart';
import '../../../utils/bonus_rules.dart';
import '../../../utils/item_name_presentation.dart';
import '../../../utils/cart_provider.dart';
import '../../../utils/smart_cart.dart';
import '../../catalog/catalog_data_source.dart';
import '../../product/product_navigation.dart';

/// The cart — the design's `Корзина` frame.
///
/// Geometry: a top bar carrying **two lines** (title 20/700 over the delivery address 14/300),
/// cart rows 343 × 60, r10, 4 px apart (pitch 64), a «Вам также может понравиться» strip of
/// 160 × 244 cards, and a 129 px glass bar with «Итого:», the 24/700 total, the accent bonus
/// line and a 179 × 49 «Оформить» pill.
///
/// **Delete rule (product requirement, not in the design):** decrementing the last unit must not
/// remove the line silently. At quantity 1 the minus slot becomes an explicit delete button, so
/// removing a line is always a deliberate tap. The design has no delete affordance anywhere —
/// neither the cart frames nor any other frame contains a trash glyph.
class CartPage extends StatefulWidget {
  const CartPage({
    this.businessId,
    this.address,
    this.onCheckout,
    this.onCatalog,
  });

  /// Store the cart is being ordered from; used for prices and recommendations.
  final int? businessId;

  /// Address shown under the title, e.g. «г. Темиртау, ул. Ленина, 16».
  final String? address;

  final VoidCallback? onCheckout;
  final VoidCallback? onCatalog;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<ProductView> _recommendations = const [];
  int? _recommendedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoadRecommendations();
  }

  /// «Вам также может понравиться» has no endpoint of its own. The strip is filled from the
  /// first cart line's category, minus what is already in the cart — the only defensible source
  /// available on a frozen backend. Flagged in `docs/redesign/STATUS.md`.
  Future<void> _maybeLoadRecommendations() async {
    final cart = context.read<CartProvider>();
    final groups = cart.displayGroups.where((g) => g.items.isNotEmpty).toList();
    if (groups.isEmpty || widget.businessId == null) return;
    final categoryId = groups.first.itemSnapshot?.category?.categoryId;
    if (categoryId == null || categoryId == _recommendedFor) return;
    _recommendedFor = categoryId;
    await Future<void>.delayed(Duration.zero);
    final items = await CatalogDataSource(businessId: widget.businessId!)
        .items(categoryId, limit: 24);
    if (!mounted) return;
    final inCart = {for (final group in groups) group.itemId};
    setState(() {
      _recommendations =
          items.where((item) => !inCart.contains(item.itemId)).take(6).toList();
    });
  }

  int _earnedBonuses(List<CartDisplayGroup> groups) {
    final eligible = groups.fold<double>(0, (sum, group) {
      final snapshot = group.itemSnapshot;
      final excluded = BonusRules.isBonusExcludedText(
        name: snapshot?.name ?? group.name,
        description: snapshot?.description,
        categoryName: snapshot?.category?.name,
        code: snapshot?.code,
      );
      return excluded ? sum : sum + group.totalPrice;
    });
    return BonusRules.calculateEarnedBonuses(eligible);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cart = context.watch<CartProvider>();
    final groups = cart.displayGroups.where((g) => g.items.isNotEmpty).toList();
    final bonuses = _earnedBonuses(cart.activeDisplayGroups);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: AppTopBar(
                    title: 'Корзина',
                    subtitle: widget.address,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
                Expanded(
                  child: groups.isEmpty
                      ? AppEmptyState(
                          title: 'Корзина пуста',
                          subtitle:
                              'Добавьте товары из каталога, чтобы оформить заказ',
                          action: widget.onCatalog == null
                              ? null
                              : FilledButton(
                                  onPressed: widget.onCatalog,
                                  child: const Text('В каталог'),
                                ),
                        )
                      : ListView(
                          padding: EdgeInsets.only(
                            bottom: 129 +
                                AppSpacing.huge +
                                MediaQuery.paddingOf(context).bottom,
                          ),
                          children: [
                            for (final group in groups)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.xxxl,
                                  0,
                                  AppSpacing.xxxl,
                                  AppSpacing.xs,
                                ),
                                child: _CartRow(
                                  group: group,
                                  onIncrement: () =>
                                      cart.incrementDisplayGroup(group),
                                  // At quantity 1 this is the delete action, surfaced as such.
                                  onDelete: () =>
                                      cart.decrementDisplayGroup(group),
                                ),
                              ),
                            if (_recommendations.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.huge),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xxxl),
                                child: Text(
                                  'Вам также может понравиться',
                                  style: AppTypography.headline
                                      .copyWith(color: palette.textPrimary),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.huge),
                              SizedBox(
                                height: ProductCardWide.height,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xxxl),
                                  itemCount: _recommendations.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: AppSpacing.md),
                                  itemBuilder: (context, index) {
                                    final item = _recommendations[index];
                                    return ProductCardWide.fromView(
                                      item,
                                      quantity: context
                                          .watch<CartProvider>()
                                          .getCatalogQuantity(item.source),
                                      onTap: () => openProduct(context, item),
                                      onIncrement: () => context
                                          .read<CartProvider>()
                                          .incrementCatalogItem(item.source),
                                      onDecrement: () => context
                                          .read<CartProvider>()
                                          .decrementCatalogItem(item.source),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _TotalsBar(
                total: cart.getTotalPrice().round(),
                bonuses: bonuses,
                onCheckout: widget.onCheckout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A cart line: 343 × 60, r10 — 52 px artwork, title 16/500, origin line 10/400 muted,
/// accent line total 16/700, and the step control whose minus becomes a delete at one unit.
class _CartRow extends StatelessWidget {
  const _CartRow({required this.group, this.onIncrement, this.onDelete});

  final CartDisplayGroup group;
  final VoidCallback? onIncrement;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final snapshot = group.itemSnapshot;
    final quantity = group.totalQuantity;
    final title = snapshot == null
        ? group.name
        : presentItemName(
            rawName: snapshot.name,
            categoryName: snapshot.category?.name,
          ).name;
    final secondary = [
      snapshot?.category?.name,
      snapshot?.quantity != null ? null : group.itemType,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');

    return Container(
      height: 60,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: SizedBox(
              width: 52,
              height: 52,
              child: group.image == null
                  ? const ColoredBox(color: Colors.white)
                  : Image.network(
                      group.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const ColoredBox(color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium
                      .copyWith(color: palette.textPrimary),
                ),
                if (secondary.isNotEmpty)
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label
                        .copyWith(color: palette.textSecondary),
                  ),
              ],
            ),
          ),
          Text(
            formatTenge(group.totalPrice.round()),
            style: AppTypography.title.copyWith(color: palette.accent),
          ),
          const SizedBox(width: AppSpacing.xxxl),
          _CartStepper(
            quantity: quantity,
            onIncrement: onIncrement,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

/// 77 × 33 step control: the minus is bare, the plus sits in an accent pill. At one unit the
/// minus is replaced by a delete glyph — the explicit "delete before removing" requirement.
class _CartStepper extends StatelessWidget {
  const _CartStepper({required this.quantity, this.onIncrement, this.onDelete});

  final num quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDelete;

  static const double _width = 77;
  static const double _height = 33;

  String get _label => quantity == quantity.roundToDouble()
      ? quantity.toStringAsFixed(0)
      : quantity.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final last = quantity <= 1;
    return SizedBox(
      width: _width,
      height: _height,
      child: Row(
        children: [
          _SemanticTap(
            label: last ? 'Удалить товар' : 'Убрать одну штуку',
            onTap: onDelete,
            child: SizedBox(
              width: 21,
              height: _height,
              child: Center(
                child: last
                    // Material's delete glyph: the design contains no trash icon anywhere, so
                    // there is nothing to export for this state.
                    ? Icon(Icons.delete_outline,
                        size: 20, color: palette.textPrimary)
                    : const _MinusGlyph(),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                _label,
                style: AppTypography.bodyMedium
                    .copyWith(color: palette.textPrimary),
              ),
            ),
          ),
          _SemanticTap(
            label: 'Добавить одну штуку',
            onTap: onIncrement,
            child: Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Center(child: _PlusGlyph()),
            ),
          ),
        ],
      ),
    );
  }
}

class _MinusGlyph extends StatelessWidget {
  const _MinusGlyph();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 9.2,
        height: 1.5,
        child: ColoredBox(color: Colors.white),
      );
}

class _PlusGlyph extends StatelessWidget {
  const _PlusGlyph();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 10.2,
        height: 10.2,
        child: Stack(
          children: [
            Center(
              child: SizedBox(
                width: 10.2,
                height: 1.5,
                child: ColoredBox(color: Colors.white),
              ),
            ),
            Center(
              child: SizedBox(
                width: 1.5,
                height: 10.2,
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ],
        ),
      );
}

/// Glass totals bar: «Итого:», the total, the accent bonus line and «Оформить».
class _TotalsBar extends StatelessWidget {
  const _TotalsBar(
      {required this.total, required this.bonuses, this.onCheckout});

  final int total;
  final int bonuses;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 129,
      child: AppGlassPanel(
        radius: 0,
        tint: Colors.black.withValues(alpha: 0.2),
        blur: 12,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.huge, AppSpacing.xxl, AppSpacing.xxxl, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Итого:',
                      style: AppTypography.base(size: 12, weight: 400)
                          .copyWith(color: palette.textSecondary, height: 1.3),
                    ),
                    Text(
                      formatTenge(total),
                      style: AppTypography.base(size: 24, weight: 700)
                          .copyWith(color: palette.textPrimary),
                    ),
                    if (bonuses > 0)
                      Row(
                        children: [
                          Text(
                            '+$bonuses бонусов',
                            style: AppTypography.bodyBold
                                .copyWith(color: palette.accent),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: palette.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onCheckout,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 179,
                  height: 49,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    'Оформить',
                    style: AppTypography.title.copyWith(color: Colors.white),
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

/// Tap target with an accessibility label; the cart's step control is glyph-only otherwise.
class _SemanticTap extends StatelessWidget {
  const _SemanticTap({
    required this.label,
    required this.child,
    this.onTap,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: child,
        ),
      );
}
