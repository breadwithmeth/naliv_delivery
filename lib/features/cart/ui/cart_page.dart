import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/money.dart';
import '../../../core/product_view.dart';
import '../../../core/quantity.dart';
import '../../../design/theme.dart';
import '../../../ui/app_states.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../model/cart_item.dart';
import '../../../ui/promotion_nudge.dart';
import '../../../ui/app_top_bar.dart';
import '../../../ui/frosted_surface.dart';
import '../../../ui/frosted_dock.dart';
import '../../../ui/motion_widgets.dart';
import '../../../ui/product_card.dart';
import '../../../ui/product_grid.dart';
import '../../../ui/surfaces.dart';
import '../../../ui/text_width_cache.dart';
import '../../../utils/bonus_rules.dart';
import '../../../utils/cart_provider.dart';
import '../../../utils/smart_cart.dart';
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
  double _footerHeight = 148;
  CartProvider? _cart;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cart = context.read<CartProvider>();
    if (!identical(_cart, cart)) {
      _cart?.saveStatus.removeListener(_saveStatusChanged);
      _cart = cart;
      cart.saveStatus.addListener(_saveStatusChanged);
    }
    if (!_cartRestoreStarted) {
      _cartRestoreStarted = true;
      _restoreCart();
    } else if (!_loadingCart) {
      _cartReadFailed = context.read<CartProvider>().saveStatus.value ==
          CartSaveStatus.restoreFailed;
      if (!_cartReadFailed) _maybeLoadRecommendations();
    }
  }

  void _saveStatusChanged() {
    if (!mounted || _loadingCart) return;
    final failed = _cart?.saveStatus.value == CartSaveStatus.restoreFailed;
    if (failed == _cartReadFailed) return;
    setState(() => _cartReadFailed = failed);
    if (!failed) _maybeLoadRecommendations();
  }

  @override
  void dispose() {
    _cart?.saveStatus.removeListener(_saveStatusChanged);
    super.dispose();
  }

  Future<void> _restoreCart({bool retry = false}) async {
    final cart = context.read<CartProvider>();
    try {
      if (retry) {
        await cart.retryLoad();
      } else {
        await cart.ensureLoaded();
      }
      if (!mounted) return;
      setState(() {
        _loadingCart = false;
        _cartReadFailed = cart.saveStatus.value == CartSaveStatus.restoreFailed;
      });
      if (!_cartReadFailed) _maybeLoadRecommendations();
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
    if (categoryId == null ||
        businessId == null ||
        cart.hasUnresolvedBusiness) {
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

  /// Opens the product behind a cart row: an optioned or bottled item opens the
  /// configurator with this row's exact selection; anything else, its page. The
  /// product's cart button comes back here.
  void _openRow(CartDisplayGroup group) {
    final snapshot = group.itemSnapshot;
    if (snapshot == null) return;
    final businessId =
        context.read<CartProvider>().businessId ?? widget.businessId;
    if (snapshot.hasOptions) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          item: snapshot,
          initialBaseVariants: group.baseVariants,
          businessId: businessId,
          onCart: () => Navigator.of(context).maybePop(),
        ),
      ));
      return;
    }
    openProduct(
      context,
      ProductView.fromItem(snapshot),
      businessId: businessId,
      onCart: () => Navigator.of(context).maybePop(),
    );
  }

  /// The row removed last on this page, kept in place with «Вернуть» until
  /// the next removal or until the customer leaves the cart. One at a time: a
  /// trail of removed rows is clutter, and nothing else in the app keeps a
  /// removed item.
  final _removed = <String, _Removed>{};

  void _remove(CartProvider cart, CartDisplayGroup group) {
    final order = cart.displayOrderOf(group.key);
    final rows = [for (final row in group.items) row.copyWith()];
    cart.removeDisplayGroup(group);
    if (cart.displayGroups.any((entry) => entry.key == group.key)) return;
    setState(() => _removed
      ..clear()
      ..[group.key] = _Removed(
        rows: rows,
        order: order ?? 1 << 30,
        name: group.name,
        image: group.image,
      ));
  }

  void _undo(CartProvider cart, String key) {
    final removed = _removed[key];
    if (removed == null) return;
    if (cart.restoreDisplayGroupRows(removed.rows, order: removed.order)) {
      setState(() => _removed.remove(key));
    }
  }

  bool _canIncrement(CartEvaluation cart, CartGroupEvaluation evaluated) {
    if (!evaluated.canIncrease) return false;
    final group = evaluated.group;
    final stock = group.maxAmount;
    final reserved = cart.activeGroups
        .where((entry) =>
            entry.group.itemId == group.itemId && entry.group.key != group.key)
        .fold<double>(0, (sum, entry) => sum + entry.totalOrderQuantity);
    return stock == null ||
        reserved + evaluated.nextOrderQuantity <= stock + 0.0000001;
  }

  void _adjustGroup(CartProvider cart, CartDisplayGroup group, int direction) {
    if (direction < 0 && _lastBatch(group)) {
      _remove(cart, group);
      return;
    }
    if (direction > 0) {
      final evaluation = cart.evaluate();
      final current = evaluation.groups
          .where((entry) => entry.group.key == group.key)
          .firstOrNull;
      if (current == null || !_canIncrement(evaluation, current)) return;
    }
    final snapshot = group.itemSnapshot;
    if (snapshot == null) {
      direction > 0
          ? cart.incrementDisplayGroup(group)
          : cart.decrementDisplayGroup(group);
      return;
    }
    final counts = group.bottleCounts;
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

  Widget _recommendationSection(AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
          child: Text(
            key: const ValueKey('cart-recommendation-heading'),
            'Вам также может понравиться',
            style: AppTypography.headline.copyWith(color: palette.textPrimary),
          ),
        ),
        const SizedBox(height: 24),
        if (_recommendationsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
          ProductRail(
            key: const ValueKey('cart-recommendation-strip'),
            products: _recommendations,
            itemCount: _recommendations.length,
            itemBuilder: (context, index) {
              final item = _recommendations[index];
              // Each card follows only its own quantity instead of every cart change.
              return Selector<CartProvider, double>(
                selector: (_, cart) =>
                    cart.getCatalogQuantityForKey(item.catalogKey),
                builder: (context, quantity, _) => ProductCard.fromView(
                  item,
                  quantity: quantity,
                  onTap: () => openProduct(
                    context,
                    item,
                    businessId: context.read<CartProvider>().businessId ??
                        widget.businessId,
                    onCart: () => Navigator.of(context).maybePop(),
                  ),
                  onIncrement: item.available
                      ? () => context
                          .read<CartProvider>()
                          .incrementCatalogItem(item.source)
                      : null,
                  onDecrement: () => context
                      .read<CartProvider>()
                      .decrementCatalogItem(item.source),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cart = context.read<CartProvider>();
    // Every content change bumps contentRevision, and the page reads nothing else from
    // the cart, so it rebuilds exactly once per change and never for other notifies.
    context.select<CartProvider, int>((cart) => cart.contentRevision);
    final evaluated = cart.evaluate();
    final groups = cart.displayGroups;
    // A removed row that came back some other way (re-added) is no longer
    // removed.
    _removed.removeWhere((key, _) => groups.any((group) => group.key == key));
    final entries = <(int, int?, String?)>[
      for (final (index, group) in groups.indexed)
        (cart.displayOrderOf(group.key) ?? index, index, null),
      for (final entry in _removed.entries)
        (entry.value.order, null, entry.key),
    ]..sort((left, right) => left.$1.compareTo(right.$1));
    final allocationIssue =
        evaluated.groups.any((group) => group.allocationIssue != null);
    final bonuses = allocationIssue
        ? 0
        : BonusRules.calculateEarnedBonuses(
            BonusRules.calculateEligibleSubtotalForEvaluations(
                evaluated.activeGroups));
    final unresolvedBusiness = cart.hasUnresolvedBusiness;
    final issueCount = unresolvedBusiness ? 1 : 0;
    final showRecommendations = _recommendations.isNotEmpty ||
        _recommendationsLoading ||
        _recommendationsFailed;
    final matchingBusiness =
        cart.businessId == null || cart.businessId == widget.businessId;
    final footerSpace = _footerHeight +
        MediaQuery.paddingOf(context).bottom +
        AppSpacing.xl * 2;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: FrostedDock(
            onDockHeightChanged: (height) {
              if ((height - _footerHeight).abs() > 0.5) {
                setState(() => _footerHeight = height);
              }
            },
            content: FrostedHeaderLayout(
              estimatedHeaderHeight: 87,
              header: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxxl, 0, AppSpacing.xxxl, AppSpacing.md),
                child: AppTopBar(
                  title: 'Корзина',
                  subtitle: matchingBusiness ? widget.address : null,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
              body: (context, topInset) {
                if (_loadingCart) {
                  return Padding(
                    padding: EdgeInsets.only(top: topInset),
                    child: const AppLoading(key: ValueKey('cart-loading')),
                  );
                }
                if (_cartReadFailed) {
                  return Padding(
                    padding: EdgeInsets.only(top: topInset),
                    child: AppErrorState(
                      key: const ValueKey('cart-load-error'),
                      message: 'Не удалось восстановить корзину',
                      onRetry: _retryCart,
                    ),
                  );
                }
                if (groups.isEmpty && _removed.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.only(top: topInset),
                    child: AppEmptyState(
                      title: 'Корзина пуста',
                      subtitle:
                          'Добавьте товары из каталога, чтобы оформить заказ',
                      action: widget.onCatalog == null
                          ? null
                          : FilledButton(
                              onPressed: widget.onCatalog,
                              child: const Text('В каталог'),
                            ),
                    ),
                  );
                }
                return ListView.builder(
                  key: const ValueKey('cart-scroll'),
                  padding: EdgeInsets.only(
                    top: topInset + AppSpacing.md,
                    bottom: footerSpace,
                  ),
                  itemCount: issueCount +
                      entries.length +
                      (showRecommendations ? 1 : 0),
                  itemBuilder: (context, position) {
                    if (position < issueCount) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          'Магазин сохранённой корзины не определён. '
                          'Удалите её товары, чтобы начать заказ в выбранном магазине.',
                          key: const ValueKey('cart-business-issue'),
                          style:
                              AppTypography.body.copyWith(color: palette.error),
                        ),
                      );
                    }
                    final slot = position - issueCount;
                    if (slot == entries.length) {
                      return _recommendationSection(palette);
                    }
                    final (_, index, removedKey) = entries[slot];
                    final bottom =
                        slot == entries.length - 1 ? 0.0 : AppSpacing.xs;
                    if (removedKey != null) {
                      final removed = _removed[removedKey]!;
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                            AppSpacing.xxxl, 0, AppSpacing.xxxl, bottom),
                        child: _RemovedRow(
                          key: ValueKey('cart-removed-$removedKey'),
                          name: removed.name,
                          onUndo: unresolvedBusiness
                              ? null
                              : () => _undo(cart, removedKey),
                        ),
                      );
                    }
                    final group = groups[index!];
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                          AppSpacing.xxxl, 0, AppSpacing.xxxl, bottom),
                      child: _CartRow(
                        key: ValueKey('cart-row-$index'),
                        group: group,
                        evaluated: evaluated.groups[index],
                        lastBatch: _lastBatch(group),
                        onOpen: group.itemSnapshot == null
                            ? null
                            : () => _openRow(group),
                        onIncrement: !unresolvedBusiness &&
                                _canIncrement(
                                    evaluated, evaluated.groups[index])
                            ? () => _adjustGroup(cart, group, 1)
                            : null,
                        onDelete: () => _adjustGroup(cart, group, -1),
                      ),
                    );
                  },
                );
              },
            ),
            dock: !_loadingCart && !_cartReadFailed && groups.isNotEmpty
                ? _TotalsBar(
                    key: const ValueKey('cart-total-bar'),
                    total: allocationIssue ? null : evaluated.totalPrice,
                    bonuses: bonuses,
                    onCheckout: allocationIssue || unresolvedBusiness
                        ? null
                        : widget.onCheckout,
                  )
                : null,
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
  for (final count in group.bottleCounts.values) {
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
    required this.evaluated,
    required this.lastBatch,
    this.onIncrement,
    this.onDelete,
    this.onOpen,
    super.key,
  });

  final CartDisplayGroup group;
  final CartGroupEvaluation evaluated;
  final bool lastBatch;
  final VoidCallback? onIncrement;
  final VoidCallback? onDelete;

  /// Opens the product with this row's exact configuration.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final snapshot = group.itemSnapshot;
    final view = snapshot == null ? null : ProductView.fromItem(snapshot);
    final pour = group.selection?.usesPourFlow == true;
    final quantity = evaluated.totalOrderQuantity;
    final title = view?.title ?? group.name;
    final secondary = {
      if (view?.type ?? view?.category case final category?) category,
      if (view?.country case final country?) country,
      if (view == null && group.itemType != null) group.itemType!,
    }.where((part) => part.trim().isNotEmpty).join(' · ');
    final configuration = group.baseVariants
        .map((variant) => variant['item_name']?.toString() ?? '')
        .where((name) => name.trim().isNotEmpty)
        .join(', ');
    final allocationIssue = evaluated.allocationIssue;
    final bottles =
        allocationIssue == null ? evaluated.bottleBreakdownLabel : null;
    final unit = snapshot?.unit?.trim().isNotEmpty == true
        ? snapshot!.unit!.trim()
        : 'шт';
    // At the exact threshold the row offers the next step, priced by what it
    // really adds; it is never added on the customer's behalf. A gift that
    // already exists is told by the struck-through price only.
    final freeOffer = onIncrement != null && evaluated.offersFreeStep;
    final hasDetails = configuration.isNotEmpty ||
        bottles != null ||
        freeOffer ||
        allocationIssue != null;

    final priceLabel = allocationIssue == null
        ? formatTenge(evaluated.price.totalPrice)
        : 'Расчёт недоступен';
    final listPrice = allocationIssue == null &&
            evaluated.price.subtotalBeforePromotions >
                evaluated.price.totalPrice + 0.5
        ? formatTenge(evaluated.price.subtotalBeforePromotions)
        : null;
    final priceStyle = AppTypography.bodyBold.copyWith(color: palette.accent);
    final normalizedUnit = unit.toLowerCase().replaceAll('.', '');
    final unitPrice =
        view != null && !const ['шт', 'pcs', 'piece'].contains(normalizedUnit)
            ? view.unitPriceLabel
            : null;
    final price = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (listPrice != null)
          Text(listPrice,
              key: ValueKey('cart-list-price-${group.key}'),
              style: AppTypography.caption.copyWith(
                  color: palette.textSecondary,
                  decoration: TextDecoration.lineThrough)),
        Text(priceLabel, style: priceStyle),
        if (unitPrice != null)
          Text(unitPrice,
              style:
                  AppTypography.caption.copyWith(color: palette.textSecondary)),
      ],
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: [
            title,
            ...(view?.metadata ?? const <String>[]),
          ].join(' · '),
          child: ExcludeSemantics(
            child: Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmallMedium
                    .copyWith(color: palette.textPrimary)),
          ),
        ),
        if (secondary.isNotEmpty)
          Text(secondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTypography.caption.copyWith(color: palette.textSecondary)),
      ],
    );
    const imageSize = 56.0;
    final image = ClipRRect(
      borderRadius: AppRadii.mdAll,
      child: Container(
        width: imageSize,
        height: imageSize,
        color: Colors.white,
        child: group.image == null
            ? const Icon(Icons.inventory_2_outlined, color: Colors.black38)
            : Image.network(
                group.image!,
                cacheWidth:
                    (imageSize * MediaQuery.devicePixelRatioOf(context)).ceil(),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.black38),
              ),
      ),
    );
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: LayoutBuilder(builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final stepperWidth = (100 +
                _cartTextWidth(
                  context,
                  _cartQuantityLabel(quantity, unit),
                  AppTypography.bodyMedium,
                ))
            .clamp(100.0, constraints.maxWidth);
        final stepper = _CartStepper(
          width: stepperWidth,
          quantity: quantity,
          unit: unit,
          lastBatch: lastBatch,
          pour: pour,
          onIncrement: onIncrement,
          onDelete: onDelete,
        );
        final priceWidth = _cartTextWidth(context, priceLabel, priceStyle);
        // Price and stepper share the first line only when the name keeps a
        // readable column; otherwise they sit on their own line under the name.
        final compact = !hasDetails &&
            scale <= 1.2 &&
            constraints.maxWidth -
                    imageSize -
                    AppSpacing.md -
                    priceWidth -
                    stepperWidth -
                    AppSpacing.xl >=
                180;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Semantics(
                    button: onOpen != null,
                    hint: onOpen == null ? null : 'Открыть товар',
                    child: InkWell(
                      key: ValueKey('cart-open-${group.key}'),
                      onTap: onOpen,
                      borderRadius: AppRadii.mdAll,
                      child: Row(
                        children: [
                          image,
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: identity),
                          if (onOpen != null && !compact)
                            Icon(Icons.chevron_right_rounded,
                                size: 22, color: palette.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ),
                if (compact) ...[
                  const SizedBox(width: AppSpacing.md),
                  price,
                  const SizedBox(width: AppSpacing.xs),
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
                  runSpacing: AppSpacing.xs,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      child: price,
                    ),
                    stepper,
                  ],
                ),
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
            if (freeOffer)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs, AppSpacing.xs, AppSpacing.xs, 0),
                child: PromotionNudge(
                  key: ValueKey('cart-free-offer-${group.key}'),
                  actionKey: ValueKey('cart-free-offer-add-${group.key}'),
                  text: promotionNudgeText(
                    quantityLabel: formatQuantity(
                        evaluated.incrementStep,
                        pour
                            ? (quantityUnitLabel(snapshot?.unit) ?? unit)
                            : unit),
                    cost: evaluated.nextStepCost!,
                    bottled: pour,
                  ),
                  onAdd: onIncrement,
                ),
              ),
            if (allocationIssue != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(allocationIssue,
                    style:
                        AppTypography.bodySmall.copyWith(color: palette.error)),
              ),
          ],
        );
      }),
    );
  }
}

/// Quantity controls with explicit deletion of the last unit or bottle batch.
class _CartStepper extends StatelessWidget {
  const _CartStepper({
    required this.width,
    required this.quantity,
    required this.unit,
    required this.lastBatch,
    required this.pour,
    this.onIncrement,
    this.onDelete,
  });

  final double width;
  final num quantity;
  final String unit;
  final bool lastBatch;
  final bool pour;
  final VoidCallback? onIncrement;
  final VoidCallback? onDelete;

  static const double _height = 44;

  String get _label => _cartQuantityLabel(quantity, unit);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final last = lastBatch;
    final style = AppTypography.bodyMedium.copyWith(color: palette.textPrimary);
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
              child: AnimatedCount(
                text: _label,
                value: quantity,
                style: style,
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
                        : palette.accent,
                    borderRadius: BorderRadius.circular(8),
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

/// The totals bar: «Итого:», the total, the accent bonus line and «Оформить».
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
    return Padding(
      // The dock supplies the 16px sides and the safe-area inset below.
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xxxl, 0, AppSpacing.xl),
      child: LayoutBuilder(builder: (context, constraints) {
        final totalLabel =
            total == null ? 'Расчёт недоступен' : formatTenge(total!);
        final adaptive = constraints.maxWidth < 296 ||
            MediaQuery.textScalerOf(context).scale(16) > 20 ||
            _cartTextWidth(context, totalLabel, AppTypography.displayBold) >
                constraints.maxWidth - 160;
        final summary = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Итого:',
              style:
                  AppTypography.bodySmall.copyWith(color: palette.textPrimary),
            ),
            Text(
              totalLabel,
              style: AppTypography.displayBold
                  .copyWith(color: palette.textPrimary),
            ),
            if (bonuses > 0)
              Tooltip(
                message:
                    'Предварительная оценка. Начисление подтверждает магазин.',
                child: Text(
                  '+$bonuses бонусов',
                  style: AppTypography.bodySmallBold
                      .copyWith(color: palette.accent),
                ),
              ),
          ],
        );
        final checkout = FilledButton(
          key: const ValueKey('cart-checkout-button'),
          onPressed: onCheckout,
          style: FilledButton.styleFrom(
            minimumSize: const Size(148, 49),
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
                const SizedBox(width: AppSpacing.md),
                checkout,
              ]);
      }),
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

String _cartQuantityLabel(num quantity, String unit) {
  final normalized = unit.toLowerCase().replaceAll('.', '');
  return formatQuantity(quantity.toDouble(),
      const ['шт', 'pcs', 'piece'].contains(normalized) ? '' : unit);
}

double _cartTextWidth(BuildContext context, String text, TextStyle style) =>
    TextWidthCache.of(
      text,
      style,
      MediaQuery.textScalerOf(context),
      Directionality.of(context),
    );

/// A group the customer removed on the cart page: its exact rows (bottle mix
/// included) and list position, so «Вернуть» restores it as it was.
class _Removed {
  const _Removed({
    required this.rows,
    required this.order,
    required this.name,
    this.image,
  });

  final List<CartItem> rows;
  final int order;
  final String name;
  final String? image;
}

/// The removed row in place: what was removed, and one action to bring it back.
class _RemovedRow extends StatelessWidget {
  const _RemovedRow({required this.name, this.onUndo, super.key});

  final String name;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppSurface(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.delete_outline_rounded,
              size: 20, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Удалено · '),
                TextSpan(
                    text: name, style: TextStyle(color: palette.textSecondary)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmallMedium
                  .copyWith(color: palette.textPrimary),
            ),
          ),
          TextButton(
            key: const ValueKey('cart-undo'),
            onPressed: onUndo,
            style: TextButton.styleFrom(
              minimumSize:
                  const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
              foregroundColor: palette.accent,
              textStyle: AppTypography.bodySmallBold,
            ),
            child: const Text('Вернуть'),
          ),
        ],
      ),
    );
  }
}
