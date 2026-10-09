import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/money.dart';
import '../../../core/product_view.dart';
import '../../../core/quantity.dart';
import '../../../design/theme.dart';
import '../../../ui/app_states.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/app_top_bar.dart';
import '../../../ui/product_card.dart';
import '../../../ui/surfaces.dart';
import '../../../utils/bonus_rules.dart';
import '../../../utils/cart_provider.dart';
import '../../../utils/smart_cart.dart';
import '../../../utils/promotion_engine.dart';
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
  int? _recommendationBusinessId;
  int _recommendationRequest = 0;
  bool _recommendationsLoading = false;
  bool _recommendationsFailed = false;
  bool _cartRestoreStarted = false;
  bool _loadingCart = true;
  bool _cartReadFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cartRestoreStarted) {
      _cartRestoreStarted = true;
      _restoreCart();
    } else if (!_loadingCart && !_cartReadFailed) {
      _maybeLoadRecommendations();
    }
  }

  Future<void> _restoreCart({bool retry = false}) async {
    final cart = context.read<CartProvider>();
    try {
      await (retry ? cart.loadCart() : cart.ensureLoaded());
      if (!mounted) return;
      setState(() {
        _loadingCart = false;
        _cartReadFailed = false;
      });
      _maybeLoadRecommendations();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCart = false;
        _cartReadFailed = true;
      });
    }
  }

  void _retryCart() {
    setState(() {
      _loadingCart = true;
      _cartReadFailed = false;
    });
    _restoreCart(retry: true);
  }

  /// «Вам также может понравиться» has no endpoint of its own. The strip is filled from the
  /// first cart line's category, minus what is already in the cart — the only defensible source
  /// available on a frozen backend. Flagged in `docs/redesign/STATUS.md`.
  Future<void> _maybeLoadRecommendations() async {
    final cart = context.read<CartProvider>();
    final groups = cart.displayGroups.where((g) => g.items.isNotEmpty).toList();
    final businessId =
        widget.businessId == null ? null : cart.businessId ?? widget.businessId;
    final categoryId = groups.firstOrNull?.itemSnapshot?.category?.categoryId;
    if (categoryId == null || businessId == null || cart.hasUnresolvedBusiness) {
      _recommendationRequest++;
      _recommendedFor = null;
      _recommendations = const [];
      _recommendationsLoading = false;
      _recommendationsFailed = false;
      return;
    }
    if (categoryId == _recommendedFor &&
        businessId == _recommendationBusinessId) {
      return;
    }
    _recommendedFor = categoryId;
    _recommendationBusinessId = businessId;
    final request = ++_recommendationRequest;
    _recommendationsLoading = true;
    _recommendationsFailed = false;
    await Future<void>.delayed(Duration.zero);
    try {
      final items = await CatalogDataSource(businessId: businessId)
          .items(categoryId, limit: 24);
      if (!mounted || request != _recommendationRequest) return;
      final inCart = {
        for (final group in context.read<CartProvider>().displayGroups)
          group.itemId,
      };
      setState(() {
        _recommendationsLoading = false;
        _recommendations = items
            .where((item) => !inCart.contains(item.itemId))
            .take(6)
            .toList();
      });
    } catch (_) {
      if (!mounted || request != _recommendationRequest) return;
      setState(() {
        _recommendations = const [];
        _recommendationsLoading = false;
        _recommendationsFailed = true;
      });
    }
  }

  void _retryRecommendations() {
    _recommendedFor = null;
    _maybeLoadRecommendations();
    setState(() {});
  }

  void _editConfiguration(CartDisplayGroup group) {
    final snapshot = group.itemSnapshot;
    if (snapshot == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductDetailPage(
        item: snapshot,
        initialBaseVariants: group.baseVariants,
        businessId: context.read<CartProvider>().businessId ?? widget.businessId,
      ),
    ));
  }

  bool _canIncrement(CartProvider cart, CartDisplayGroup group) {
    if (!group.canIncrease) return false;
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
    final bonuses = BonusRules.calculateEarnedBonusesForGroups(
        cart.activeDisplayGroups);
    final allocationIssue =
        groups.any((group) => group.allocationIssue != null);
    final unresolvedBusiness = cart.hasUnresolvedBusiness;
    final matchingBusiness =
        cart.businessId == null || cart.businessId == widget.businessId;
    final footerSpace = 148 +
        MediaQuery.paddingOf(context).bottom +
        (MediaQuery.textScalerOf(context).scale(16) > 20 ||
                MediaQuery.sizeOf(context).width < 352
            ? 120
            : 0);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                    child: AppTopBar(
                      title: 'Корзина',
                      subtitle: matchingBusiness ? widget.address : null,
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  Expanded(
                    child: _loadingCart
                        ? const AppLoading(key: ValueKey('cart-loading'))
                        : _cartReadFailed
                            ? AppErrorState(
                                key: const ValueKey('cart-load-error'),
                                message: 'Не удалось восстановить корзину',
                                onRetry: _retryCart,
                              )
                            : groups.isEmpty
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
                            key: const ValueKey('cart-scroll'),
                            padding: EdgeInsets.only(bottom: footerSpace),
                            children: [
                              if (unresolvedBusiness)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Text(
                                    'Магазин сохранённой корзины не определён. '
                                    'Удалите её товары, чтобы начать заказ в выбранном магазине.',
                                    key: const ValueKey('cart-business-issue'),
                                    style: AppTypography.body
                                        .copyWith(color: palette.error),
                                  ),
                                ),
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
                                    onIncrement: !unresolvedBusiness &&
                                            _canIncrement(cart, group)
                                        ? () => _adjustGroup(cart, group, 1)
                                        : null,
                                    onDelete: () =>
                                        _adjustGroup(cart, group, -1),
                                  ),
                                ),
                              if (_recommendations.isNotEmpty ||
                                  _recommendationsLoading ||
                                  _recommendationsFailed) ...[
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
                                if (_recommendationsLoading)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 24),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        key: ValueKey('cart-recommendation-loading'),
                                      ),
                                    ),
                                  )
                                else if (_recommendationsFailed)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: AppSurface(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Не удалось загрузить товары',
                                              style: AppTypography.body
                                                  .copyWith(color: palette.textSecondary)),
                                          TextButton(
                                            key: const ValueKey('cart-recommendation-retry'),
                                            onPressed: _retryRecommendations,
                                            child: const Text('Повторить'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                SizedBox(
                                  key: const ValueKey(
                                      'cart-recommendation-strip'),
                                  height: ProductCard.heightFor(
                                    context,
                                    width: ProductCard.widthFor(context),
                                    products: _recommendations,
                                    hasOldPrice: _recommendations.any(
                                        (item) => item.oldPrice != null),
                                  ),
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
                                          businessId: cart.businessId ?? widget.businessId,
                                          onCart: () =>
                                              Navigator.of(context).maybePop(),
                                        ),
                                        onIncrement: item.available
                                            ? () => context
                                                .read<CartProvider>()
                                                .incrementCatalogItem(item.source)
                                            : null,
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
              if (!_loadingCart && !_cartReadFailed && groups.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _TotalsBar(
                    key: const ValueKey('cart-total-bar'),
                    total: allocationIssue ? null : cart.getTotalPrice(),
                    bonuses: bonuses,
                    onCheckout: allocationIssue || unresolvedBusiness
                        ? null
                        : widget.onCheckout,
                  ),
                ),
            ],
          ),
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
    final view = snapshot == null ? null : ProductView.fromItem(snapshot);
    final pour = group.selection?.usesPourFlow == true;
    final quantity = pour ? group.totalOrderQuantity : group.totalQuantity;
    final title = view?.title ?? group.name;
    final secondary = {
      if (view?.category case final category?) category,
      ...(view?.metadata ?? const <String>[]).where((part) =>
          part.toLowerCase() != view?.category?.toLowerCase()),
      if (view == null && group.itemType != null) group.itemType!,
    }.where((part) => part.trim().isNotEmpty).join(' · ');
    final configuration = group.baseVariants
        .map((variant) => variant['item_name']?.toString() ?? '')
        .where((name) => name.trim().isNotEmpty)
        .join(', ');
    final allocationIssue = group.allocationIssue;
    final bottles = allocationIssue == null ? group.bottleBreakdownLabel : null;
    final hasDetails = configuration.isNotEmpty ||
        bottles != null ||
        group.freeQuantity > 0 ||
        allocationIssue != null ||
        onEdit != null;
    final unit = snapshot?.unit?.trim().isNotEmpty == true
        ? snapshot!.unit!.trim()
        : 'шт';
    final evaluation = evaluatePromotion(
      paidQuantity: group.totalQuantity,
      promotions: group.promotions,
    );
    final award = evaluation.award;
    final giftCaption = award == null
        ? null
        : 'За каждые ${formatQuantity(award.baseAmount.toDouble(), unit)} '
            '— ${formatQuantity(award.addAmount.toDouble(), unit)} этого товара в подарок';

    final price = Text(
      allocationIssue == null
          ? formatTenge(group.totalPrice)
          : 'Расчёт недоступен',
      style: AppTypography.bodyBold.copyWith(color: palette.accent),
    );
    final stepper = _CartStepper(
      quantity: quantity,
      unit: unit,
      lastBatch: lastBatch,
      pour: group.selection?.usesPourFlow == true,
      onIncrement: onIncrement,
      onDelete: onDelete,
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            style: AppTypography.bodyMedium
                .copyWith(color: palette.textPrimary)),
        if (secondary.isNotEmpty)
          Text(secondary,
              style: AppTypography.caption
                  .copyWith(color: palette.textSecondary)),
      ],
    );
    final image = ClipRRect(
      borderRadius: AppRadii.smAll,
      child: Container(
        width: 52,
        height: 52,
        color: Colors.white,
        child: group.image == null
            ? const Icon(Icons.inventory_2_outlined, color: Colors.black38)
            : Image.network(
                group.image!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.inventory_2_outlined, color: Colors.black38),
              ),
      ),
    );
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = !hasDetails &&
            (unit == 'шт' || unit == 'шт.') &&
            quantity < 100 &&
            constraints.maxWidth >= 335 &&
            MediaQuery.textScalerOf(context).scale(14) <= 16 &&
            title.length <= 18 &&
            secondary.length <= 36 &&
            formatTenge(group.totalPrice).length <= 9;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                image,
                const SizedBox(width: AppSpacing.md),
                Expanded(child: identity),
                if (compact) ...[
                  const SizedBox(width: AppSpacing.xs),
                  price,
                  stepper,
                ],
              ],
            ),
            if (!compact)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [price, stepper],
                ),
              ),
            if (view != null && !hasDetails)
              Padding(
                padding: const EdgeInsets.fromLTRB(60, 0, 4, 2),
                child: Text(view.unitPriceLabel,
                    style: AppTypography.caption
                        .copyWith(color: palette.textSecondary)),
              ),
            if (configuration.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(configuration,
                    key: ValueKey('cart-configuration-${group.key}'),
                    style: AppTypography.bodySmall
                        .copyWith(color: palette.textSecondary)),
              ),
            if (bottles != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(bottles,
                    key: ValueKey('cart-bottles-${group.key}'),
                    style: AppTypography.bodySmall
                        .copyWith(color: palette.textSecondary)),
              ),
            if (group.freeQuantity > 0)
              _GiftLine(
                key: ValueKey('cart-gift-${group.key}'),
                quantityLabel: formatQuantity(group.freeQuantity, unit),
                caption: pour
                    ? '${giftCaption ?? 'Напиток в подарок'}. Тара для подарка оплачивается обычно.'
                    : giftCaption,
              ),
            if (allocationIssue != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(allocationIssue,
                    style: AppTypography.bodySmall
                        .copyWith(color: palette.error)),
              ),
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
          ],
        );
      }),
    );
  }
}

class _GiftLine extends StatelessWidget {
  const _GiftLine({
    required this.quantityLabel,
    this.caption,
    super.key,
  });

  final String quantityLabel;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.brandRed,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(AppIcons.bonusStar, size: 16, color: palette.gold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Подарок · $quantityLabel',
                    key: const ValueKey('cart-gift-label'),
                    style: AppTypography.bodySmallMedium
                        .copyWith(color: Colors.white)),
                if (caption != null)
                  Text(caption!,
                      style: AppTypography.caption
                          .copyWith(color: Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text('0 ₸',
              key: const ValueKey('cart-gift-price'),
              style:
                  AppTypography.bodySmallBold.copyWith(color: palette.gold)),
        ],
      ),
    );
  }
}

/// Quantity controls with explicit deletion of the last unit or bottle batch.
class _CartStepper extends StatelessWidget {
  const _CartStepper({
    required this.quantity,
    required this.unit,
    required this.lastBatch,
    required this.pour,
    this.onIncrement,
    this.onDelete,
  });

  final num quantity;
  final String unit;
  final bool lastBatch;
  final bool pour;
  final VoidCallback? onIncrement;
  final VoidCallback? onDelete;

  static const double _height = 44;

  String get _label {
    final normalized = unit.toLowerCase().replaceAll('.', '');
    return formatQuantity(quantity.toDouble(),
        const ['шт', 'pcs', 'piece'].contains(normalized) ? '' : unit);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final last = lastBatch;
    final style = AppTypography.bodyMedium
        .copyWith(color: palette.textPrimary);
    final painter = TextPainter(
      text: TextSpan(text: _label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = (96 + painter.width)
        .clamp(100.0, MediaQuery.sizeOf(context).width - 48);
    painter.dispose();
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
                    color: onIncrement == null
                        ? palette.accentFaint
                        : palette.accentSoft,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                      child: Icon(Icons.add_rounded,
                          color: palette.textOnAccent, size: 20)),
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

  final num? total;
  final int bonuses;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppGlassPanel(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, constraints) {
      final adaptive = constraints.maxWidth < 320 ||
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
            Tooltip(
              message: 'Предварительная оценка. Начисление подтверждает магазин.',
              child: Text(
                '+$bonuses бонусов',
                style: AppTypography.bodyBold.copyWith(color: palette.accent),
              ),
            ),
        ],
      );
      final checkout = FilledButton(
        key: const ValueKey('cart-checkout-button'),
        onPressed: onCheckout,
        style: FilledButton.styleFrom(
          minimumSize: const Size(154, 49),
          shape: const StadiumBorder(),
        ),
        child: const Text('Оформить'),
      );
      return adaptive
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
                ]);
        }),
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
        enabled: onTap != null,
        child: InkWell(
          onTap: onTap,
          child: child,
        ),
      );
}
