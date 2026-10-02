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
import '../../../utils/subtract_promotion_math.dart';
import '../../../pages/product_detail_page.dart';
import '../../catalog/catalog_data_source.dart';
import '../../product/product_navigation.dart';

/// The adaptive cart with exact configurations and an explicit final-batch delete.
class CartPage extends StatefulWidget {
  const CartPage({
    this.businessId,
    this.address,
    this.onCheckout,
    this.onCatalog,
    super.key,
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
    try {
      final items = await CatalogDataSource(businessId: widget.businessId!)
          .items(categoryId, limit: 24);
      if (!mounted) return;
      final inCart = {for (final group in groups) group.itemId};
      setState(() {
        _recommendations = items
            .where((item) => !inCart.contains(item.itemId))
            .take(6)
            .toList();
      });
    } catch (error) {
      // Recommendations are supplemental; a failed category read must not
      // prevent the cart from showing its lines and checkout action.
      debugPrint('Cart recommendations unavailable: $error');
      if (!mounted) return;
      setState(() => _recommendations = const []);
    }
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
      return excluded || group.allocationIssue != null
          ? sum
          : sum + group.totalPrice;
    });
    return BonusRules.calculateEarnedBonuses(eligible);
  }

  void _editConfiguration(CartDisplayGroup group) {
    final snapshot = group.itemSnapshot;
    if (snapshot == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductDetailPage(
        item: snapshot,
        initialBaseVariants: group.baseVariants,
        businessId: widget.businessId,
      ),
    ));
  }

  bool _canIncrement(CartProvider cart, CartDisplayGroup group) {
    final stock = group.maxAmount;
    if (stock != null && stock <= 0) return false;
    final step = _batchVolume(group);
    if (step <= 0) return false;
    final reserved = cart.activeDisplayGroups
        .where(
            (entry) => entry.itemId == group.itemId && entry.key != group.key)
        .fold<double>(0, (sum, entry) => sum + entry.totalOrderQuantity);
    final nextPaid = group.totalQuantity + step;
    final nextTotal =
        nextPaid + subtractPromotionFreeQuantity(nextPaid, group.promotions);
    if (group.selection?.usesPourFlow == true) {
      try {
        group.selection!.giftBottleBreakdown(nextPaid);
      } on StateError {
        return false;
      }
    }
    return stock == null || reserved + nextTotal <= stock + 0.0000001;
  }

  void _adjustGroup(CartProvider cart, CartDisplayGroup group, int direction) {
    if (direction < 0 && _lastBatch(group)) {
      cart.removeDisplayGroup(group);
      return;
    }
    if (direction > 0 && !_canIncrement(cart, group)) return;
    final snapshot = group.itemSnapshot;
    if (snapshot == null) {
      direction > 0
          ? cart.incrementDisplayGroup(group)
          : cart.decrementDisplayGroup(group);
      return;
    }
    final counts = group.paidBottleCounts;
    if (group.selection?.usesPourFlow == true) {
      final batches = _batches(group);
      if (batches == 0) return;
      // Repeat/remove the exact allocation, never silently replace its bottles.
      cart.syncItemBottleCounts(snapshot, group.baseVariants, {
        for (final entry in counts.entries)
          entry.key: entry.value ~/ batches * (batches + direction),
      });
    } else {
      cart.syncItemSelectionQuantity(
        snapshot,
        group.baseVariants,
        group.totalQuantity + _batchVolume(group) * direction,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cart = context.watch<CartProvider>();
    final groups = cart.displayGroups.where((g) => g.items.isNotEmpty).toList();
    final bonuses = _earnedBonuses(cart.activeDisplayGroups);
    final allocationIssue =
        groups.any((group) => group.allocationIssue != null);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Column(
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
                  const SizedBox(height: AppSpacing.xxxl),
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
                              bottom: AppSpacing.huge +
                                  MediaQuery.paddingOf(context).bottom,
                            ),
                            children: [
                              for (final (index, group) in groups.indexed)
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    AppSpacing.xxxl,
                                    0,
                                    AppSpacing.xxxl,
                                    index == groups.length - 1
                                        ? 0
                                        : AppSpacing.xs,
                                  ),
                                  child: _CartRow(
                                    key: ValueKey('cart-row-$index'),
                                    group: group,
                                    lastBatch: _lastBatch(group),
                                    onEdit:
                                        group.itemSnapshot?.hasOptions == true
                                            ? () => _editConfiguration(group)
                                            : null,
                                    onIncrement: _canIncrement(cart, group)
                                        ? () => _adjustGroup(cart, group, 1)
                                        : null,
                                    onDelete: () =>
                                        _adjustGroup(cart, group, -1),
                                  ),
                                ),
                              if (_recommendations.isNotEmpty) ...[
                                const SizedBox(height: 32),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xxxl),
                                  child: Text(
                                    key: const ValueKey(
                                        'cart-recommendation-heading'),
                                    'Вам также может понравиться',
                                    style: AppTypography.headline
                                        .copyWith(color: palette.textPrimary),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  key: const ValueKey(
                                      'cart-recommendation-strip'),
                                  height: ProductCard.heightFor(context,
                                      hasOldPrice: _recommendations.any(
                                          (item) => item.oldPrice != null)),
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.xxxl),
                                    itemCount: _recommendations.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: AppSpacing.md),
                                    itemBuilder: (context, index) {
                                      final item = _recommendations[index];
                                      final card = ProductCard.fromView(
                                        item,
                                        quantity: context
                                            .watch<CartProvider>()
                                            .getCatalogQuantity(item.source),
                                        onTap: () => openProduct(
                                          context,
                                          item,
                                          businessId: widget.businessId,
                                          onCart: () =>
                                              Navigator.of(context).maybePop(),
                                        ),
                                        onIncrement: () => context
                                            .read<CartProvider>()
                                            .incrementCatalogItem(item.source),
                                        onDecrement: () => context
                                            .read<CartProvider>()
                                            .decrementCatalogItem(item.source),
                                      );
                                      return SizedBox(
                                        width: ProductCard.widthFor(context),
                                        child: card,
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
            ),
            _TotalsBar(
              key: const ValueKey('cart-total-bar'),
              total: allocationIssue ? null : cart.getTotalPrice().round(),
              bonuses: bonuses,
              onCheckout: allocationIssue ? null : widget.onCheckout,
            ),
          ],
        ),
      ),
    );
  }
}

// One batch is the smallest repeat of the existing bottle mix. Its last minus
// is always explicit deletion, even when the batch contains several litres.
int _batches(CartDisplayGroup group) {
  var batches = 0;
  for (final count in group.paidBottleCounts.values) {
    if (count > 0) batches = batches == 0 ? count : batches.gcd(count);
  }
  return batches;
}

double _batchVolume(CartDisplayGroup group) {
  if (group.selection?.usesPourFlow == true) {
    final batches = _batches(group);
    return batches == 0 ? 0 : group.totalQuantity / batches;
  }
  final step = group.items.first.stepQuantity;
  return step > 0 ? step : 1;
}

bool _lastBatch(CartDisplayGroup group) => group.selection?.usesPourFlow == true
    ? _batches(group) <= 1
    : group.totalQuantity <= _batchVolume(group) + 0.001;

/// A readable cart line preserving its selected options and physical bottle mix.
class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.group,
    required this.lastBatch,
    this.onIncrement,
    this.onDelete,
    this.onEdit,
    super.key,
  });

  final CartDisplayGroup group;
  final bool lastBatch;
  final VoidCallback? onIncrement;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final snapshot = group.itemSnapshot;
    final quantity = group.selection?.usesPourFlow == true
        ? group.totalOrderQuantity
        : group.totalQuantity;
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
    final configuration = group.baseVariants
        .map((variant) => variant['item_name']?.toString() ?? '')
        .where((name) => name.trim().isNotEmpty)
        .join(', ');
    final allocationIssue = group.allocationIssue;
    final bottles = allocationIssue == null ? group.bottleBreakdownLabel : null;

    final price = Text(
      allocationIssue == null
          ? formatTenge(group.totalPrice.round())
          : 'Расчёт недоступен',
      style: AppTypography.title.copyWith(color: palette.accent),
    );
    final stepper = _CartStepper(
      quantity: quantity,
      lastBatch: lastBatch,
      pour: group.selection?.usesPourFlow == true,
      onIncrement: onIncrement,
      onDelete: onDelete,
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium
                      .copyWith(color: palette.textPrimary),
                ),
                if (secondary.isNotEmpty)
                  Text(
                    secondary,
                    style: AppTypography.bodySmall
                        .copyWith(color: palette.textSecondary),
                  ),
                if (configuration.isNotEmpty)
                  Text(configuration,
                      key: ValueKey('cart-configuration-${group.key}'),
                      style: AppTypography.bodySmall
                          .copyWith(color: palette.textSecondary)),
                if (bottles != null)
                  Text(bottles,
                      key: ValueKey('cart-bottles-${group.key}'),
                      style: AppTypography.bodySmall
                          .copyWith(color: palette.textSecondary)),
                if (group.freeQuantity > 0)
                  Text(
                      '${group.selection?.volumeLabel(group.totalOrderQuantity) ?? group.totalOrderQuantity} всего · ${group.freeQuantity} в подарок',
                      style: AppTypography.bodySmall
                          .copyWith(color: palette.accent)),
                if (allocationIssue != null)
                  Text(allocationIssue,
                      style: AppTypography.bodySmall
                          .copyWith(color: palette.error)),
                if (onEdit != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: ValueKey('cart-edit-${group.key}'),
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Изменить параметры'),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [price, stepper],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Quantity controls with explicit deletion of the last unit or bottle batch.
class _CartStepper extends StatelessWidget {
  const _CartStepper({
    required this.quantity,
    required this.lastBatch,
    required this.pour,
    this.onIncrement,
    this.onDelete,
  });

  final num quantity;
  final bool lastBatch;
  final bool pour;
  final VoidCallback? onIncrement;
  final VoidCallback? onDelete;

  static const double _height = 44;

  String get _label =>
      quantity.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final last = lastBatch;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final width = 96.0 + _label.length * 10 * (scale < 1 ? 1.0 : scale);
    const height = _height;
    return SizedBox(
      width: width,
      child: Row(
        children: [
          _SemanticTap(
            label: last
                ? 'Удалить товар'
                : (pour
                    ? 'Убрать выбранный набор бутылок'
                    : 'Убрать одну штуку'),
            onTap: onDelete,
            child: SizedBox(
              width: 44,
              height: height,
              child: Center(
                child: Icon(
                    last ? Icons.delete_outline_rounded : Icons.remove_rounded,
                    size: 20,
                    color: palette.textPrimary),
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
            label: pour
                ? 'Добавить выбранный набор бутылок'
                : 'Добавить одну штуку',
            onTap: onIncrement,
            child: SizedBox(
              width: 44,
              height: height,
              child: Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Center(
                      child: Icon(Icons.add_rounded,
                          color: Colors.white, size: 20)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Glass totals bar: «Итого:», the total, the accent bonus line and «Оформить».
class _TotalsBar extends StatelessWidget {
  const _TotalsBar({
    required this.total,
    required this.bonuses,
    this.onCheckout,
    super.key,
  });

  final int? total;
  final int bonuses;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(builder: (context, constraints) {
      final adaptive = constraints.maxWidth < 520 ||
          MediaQuery.textScalerOf(context).scale(16) > 20;
      final summary = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Итого:',
            style:
                AppTypography.bodySmall.copyWith(color: palette.textSecondary),
          ),
          Text(
            total == null ? 'Расчёт недоступен' : formatTenge(total!),
            style:
                AppTypography.displayBold.copyWith(color: palette.textPrimary),
          ),
          if (bonuses > 0)
            Text(
              '+$bonuses бонусов',
              style: AppTypography.bodyBold.copyWith(color: palette.accent),
            ),
        ],
      );
      final checkout = InkWell(
        onTap: onCheckout,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          key: const ValueKey('cart-checkout-button'),
          width: adaptive ? double.infinity : 154,
          constraints: const BoxConstraints(minHeight: 49),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: palette.accentSoft,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            'Оформить',
            style: AppTypography.title.copyWith(color: Colors.white),
          ),
        ),
      );
      return AppGlassPanel(
        radius: 0,
        tint: Colors.black.withValues(alpha: 0.2),
        blur: 12,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xxxl,
            AppSpacing.xl,
            AppSpacing.xxxl,
            AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
          ),
          child: adaptive
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    summary,
                    const SizedBox(height: AppSpacing.xl),
                    checkout,
                  ],
                )
              : Row(children: [
                  Expanded(child: summary),
                  const SizedBox(width: AppSpacing.xl),
                  checkout,
                ]),
        ),
      );
    });
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
        enabled: onTap != null,
        child: InkWell(
          onTap: onTap,
          child: child,
        ),
      );
}
