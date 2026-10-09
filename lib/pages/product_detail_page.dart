import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../core/money.dart';
import '../core/product_view.dart';
import '../core/quantity.dart';
import '../model/item.dart' as item_model;
import '../model/cart_item.dart';
import '../ui/app_icon.dart';
import '../ui/app_icon_button.dart';
import '../ui/surfaces.dart';
import '../utils/api.dart';
import '../utils/business_provider.dart';
import '../utils/cart_provider.dart';
import '../utils/liked_items_provider.dart';
import '../utils/liked_storage_service.dart';
import '../utils/smart_cart.dart';
import '../utils/promotion_engine.dart';

// The hero, title and price use the Описание товара geometry. Configuration
// controls have no matching Figma frame; they expose the supported cart model.
class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.item,
    this.initialBaseVariants,
    this.businessId,
    this.onLike,
    this.onCart,
  });

  final item_model.Item item;
  final List<Map<String, dynamic>>? initialBaseVariants;
  final int? businessId;
  final Future<bool?> Function(int itemId)? onLike;
  final VoidCallback? onCart;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late final SmartCartSelection _selection;
  late final ProductView _view;
  late final List<item_model.ItemOption> _options;
  late List<Map<String, dynamic>> _openedVariants;
  final Map<int, List<item_model.ItemOptionItem>> _selected = {};
  final Map<int, int> _bottleCounts = {};
  Map<int, int>? _retainedGiftCounts;
  double _retainedGiftQuantity = 0;
  double _quantity = 0;
  bool _restored = false;
  bool _openedGroupExists = false;
  bool _expanded = false;
  bool _liked = false;
  bool _liking = false;
  bool _saved = false;
  int? _businessId;
  String? _feedback;

  bool get _pour => _selection.usesPourFlow;
  bool get _inStock => widget.item.amount == null || widget.item.amount! > 0;
  double get _step => widget.item.effectiveStepQuantity;

  String get _unit => widget.item.unit?.trim().isNotEmpty == true
      ? widget.item.unit!.trim()
      : 'шт';
  double get _amount => _pour ? _bottleAmount(_bottleCounts) : _quantity;

  @override
  void initState() {
    super.initState();
    _selection = SmartCartSelection(widget.item);
    _view = ProductView.fromItem(widget.item);
    _options = _pour
        ? _selection.visibleOptions
        : widget.item.options ?? const <item_model.ItemOption>[];
    for (final option in _options) {
      if (option.required == 1 && option.optionItems.isNotEmpty) {
        _selected[option.optionId] = [option.optionItems.first];
      }
    }
    _openedVariants = SmartCartSelection.normalizeVariantMaps(
        widget.initialBaseVariants ?? _baseVariants());
    if (widget.initialBaseVariants != null) _restoreVariants(_openedVariants);
    _quantity = _inStock ? _step : 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cart = context.read<CartProvider>();
    if (!_restored) {
      _restored = true;
      final group = _findGroup(cart, _openedVariants);
      _openedGroupExists = group != null;
      if (group != null) {
        _restoreVariants(group.baseVariants);
        _quantity = group.totalQuantity;
        // Do not infer or rebalance bottles when reopening an exact allocation.
        _bottleCounts.addAll(group.paidBottleCounts);
        _retainedGiftCounts = group.selection?.usesPourFlow == true &&
                group.allocationIssue == null
            ? group.selection!.giftBottleBreakdown(group.totalQuantity,
                retainedCounts: group.retainedGiftBottleCounts)
            : null;
        _retainedGiftQuantity = group.freeQuantity;
      } else if (_pour) {
        for (final bottle in _selection.filteredBottles) {
          if (_fitsAvailable(
              _selection.volumeForBottle(bottle), _availableAmount(cart))) {
            _bottleCounts[bottle.relationId] = 1;
            break;
          }
        }
      } else {
        if (!_fitsAvailable(_quantity, _availableAmount(cart))) _quantity = 0;
      }
    }
    final businessId = widget.businessId ??
        widget.item.businessId ??
        context.read<BusinessProvider?>()?.selectedBusinessId;
    if (businessId != null && businessId != _businessId) {
      _businessId = businessId;
      _loadLiked(businessId);
    }
  }

  void _restoreVariants(List<Map<String, dynamic>> variants) {
    final ids = variants
        .map(SmartCartSelection.variantRelationId)
        .whereType<int>()
        .toSet();
    _selected.clear();
    for (final option in _options) {
      final matches = option.optionItems
          .where((variant) => ids.contains(variant.relationId))
          .toList();
      if (matches.isNotEmpty) _selected[option.optionId] = matches;
    }
  }

  Future<void> _loadLiked(int businessId) async {
    final provider = context.read<LikedItemsProvider?>();
    final liked = provider?.isLiked(businessId, widget.item.itemId) == true ||
        await LikedStorageService.isLiked(
            businessId: businessId, itemId: widget.item.itemId);
    if (!mounted || businessId != _businessId) return;
    setState(() => _liked = liked);
    if (liked) provider?.updateLike(businessId, widget.item.itemId, true);
  }

  Future<void> _toggleLike() async {
    if (_liking) return;
    setState(() => _liking = true);
    final provider = context.read<LikedItemsProvider?>();
    try {
      final liked = await (widget.onLike ??
          ApiService.toggleLikeItem)(widget.item.itemId);
      if (!mounted) return;
      if (liked == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Не удалось изменить избранное. Войдите в аккаунт или попробуйте ещё раз.')));
        return;
      }
      setState(() => _liked = liked);
      final businessId = _businessId;
      if (businessId != null) {
        await LikedStorageService.setLiked(
            businessId: businessId, itemId: widget.item.itemId, liked: liked);
        provider?.updateLike(businessId, widget.item.itemId, liked);
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  CartDisplayGroup? _findGroup(
      CartProvider cart, List<Map<String, dynamic>> variants) {
    final key = _selection.displayKeyForVariants(variants);
    for (final group in cart.displayGroups) {
      if (group.key == key) return group;
    }
    return null;
  }

  double _availableAmount(CartProvider cart) {
    final stock = widget.item.amount;
    if (stock == null) return double.infinity;
    final openedKey = _selection.displayKeyForVariants(_openedVariants);
    final reserved = cart.activeDisplayGroups
        .where((group) =>
            group.itemId == widget.item.itemId && group.key != openedKey)
        .fold<double>(0, (sum, group) => sum + group.totalOrderQuantity);
    return math.max(0, stock - reserved);
  }

  bool _fitsAvailable(double paid, double available) =>
      paid + subtractPromotionFreeQuantity(paid, _promotions) <=
      available + 0.0000001;

  Map<String, dynamic> _variant(
          item_model.ItemOptionItem value, int required) =>
      {
        'variant_id': value.relationId,
        'relation_id': value.relationId,
        'item_id': value.itemId,
        'item_name': value.itemName,
        'price_type': value.priceType,
        'price': value.price,
        'parent_item_amount':
            value.parentItemAmount > 0 ? value.parentItemAmount : _step,
        'required': required,
      };

  List<Map<String, dynamic>> _baseVariants() =>
      SmartCartSelection.normalizeVariantMaps([
        for (final option in _options)
          for (final value in _selected[option.optionId] ??
              const <item_model.ItemOptionItem>[])
            _variant(value, option.required),
      ]);

  List<Map<String, dynamic>> get _promotions => [
        for (final promotion
            in widget.item.promotions ?? const <item_model.ItemPromotion>[])
          if (promotion.isActive) promotion.toJson(),
      ];

  CartItem _previewItem(double quantity, {item_model.ItemOptionItem? bottle}) =>
      CartItem(
        itemId: widget.item.itemId,
        name: widget.item.name,
        price: widget.item.price,
        quantity: quantity,
        stepQuantity:
            bottle == null ? _step : _selection.volumeForBottle(bottle),
        giftBottleCounts: bottle != null && _retainedGiftQuantity > 0
            ? SmartCartSelection.scaledBottleCounts(
                _retainedGiftCounts, _free / _retainedGiftQuantity)
            : null,
        selectedVariants: _selection.buildVariantMaps(
            bottle: bottle, baseVariants: _baseVariants()),
        promotions: _promotions,
        itemData: widget.item.toJson(),
      );

  List<CartItem> get _previewItems => !_pour
      ? [_previewItem(_quantity)]
      : [
          for (final bottle in _visibleBottles)
            if ((_bottleCounts[bottle.relationId] ?? 0) > 0)
              _previewItem(
                  _selection.volumeForBottle(bottle) *
                      _bottleCounts[bottle.relationId]!,
                  bottle: bottle),
        ];

  CartPriceBreakdown? _price;
  CartDisplayGroup? _previewGroup;
  String? _allocationIssue;
  double get _total => _price?.totalPrice ?? 0;
  double get _subtotal => _price?.subtotalBeforePromotions ?? 0;
  double get _free => subtractPromotionFreeQuantity(_amount, _promotions);

  /// Containers this screen lists: the ones the shop offers plus any withdrawn container the
  /// opened cart already holds, so a legacy three-litre row can be reviewed and removed instead of
  /// silently stranded.
  List<item_model.ItemOptionItem> get _visibleBottles => [
        ..._selection.filteredBottles,
        for (final bottle in _selection.bottleVariants)
          if (!_selection.bottleRelationIds.contains(bottle.relationId) &&
              ((_bottleCounts[bottle.relationId] ?? 0) > 0 ||
                  (_retainedGiftCounts?[bottle.relationId] ?? 0) > 0))
            bottle,
      ];

  bool _isOfferedBottle(item_model.ItemOptionItem bottle) =>
      _selection.bottleRelationIds.contains(bottle.relationId);

  double _bottleAmount(Map<int, int> counts) =>
      _selection.litersForCounts(counts);
  String _amountLabel(double amount) =>
      _pour ? _selection.volumeLabel(amount) : formatQuantity(amount, _unit);

  void _toggleOption(
      item_model.ItemOption option, item_model.ItemOptionItem value) {
    final selected =
        List<item_model.ItemOptionItem>.of(_selected[option.optionId] ?? []);
    final exists = selected.any((item) => item.relationId == value.relationId);
    setState(() {
      if (option.selection.toUpperCase() == 'MULTIPLE') {
        if (exists) {
          selected.removeWhere((item) => item.relationId == value.relationId);
        } else {
          selected.add(value);
        }
      } else {
        selected.clear();
        if (!exists || option.required == 1) selected.add(value);
      }
      _selected[option.optionId] = selected;
      _saved = false;
      _feedback = null;
    });
  }

  bool _isRemoval(CartProvider cart) =>
      _openedGroupExists &&
      _amount <= 0 &&
      _findGroup(cart, _openedVariants) != null;

  bool _isReduction(CartProvider cart) {
    final opened = _findGroup(cart, _openedVariants);
    if (!_openedGroupExists || opened == null) return false;
    if (_selection.displayKeyForVariants(_baseVariants()) != opened.key ||
        _amount >= opened.totalQuantity - 0.0000001) {
      return false;
    }
    return !_pour ||
        _bottleCounts.entries.every(
            (entry) => entry.value <= (opened.paidBottleCounts[entry.key] ?? 0));
  }

  bool _canIncreaseDraft(CartProvider cart) =>
      !cart.hasUnresolvedBusiness &&
      _selection.quantityIssue == null &&
      _selection.containerIssue == null &&
      _findGroup(cart, _openedVariants)?.hasWithdrawnBottles != true;

  String? _invalidReason(CartProvider cart) {
    if (_isRemoval(cart) || _isReduction(cart)) return null;
    if (cart.hasUnresolvedBusiness) {
      return 'Магазин сохранённой корзины не определён. Можно уменьшить или удалить её товары.';
    }
    if (_selection.containerIssue != null) return _selection.containerIssue;
    if (_selection.quantityIssue != null) return _selection.quantityIssue;
    if (!_inStock) return 'Нет в наличии';
    final missing = _options.where((option) =>
        option.required == 1 && (_selected[option.optionId]?.isEmpty ?? true));
    if (missing.isNotEmpty) {
      return 'Выберите обязательные параметры: ${missing.map((option) => option.name).join(', ')}';
    }
    if (_amount <= 0) {
      return _pour ? 'Выберите хотя бы одну бутылку' : 'Выберите количество';
    }
    if (_pour) {
      try {
        _selection.giftBottleBreakdown(_amount,
            retainedCounts: _retainedGiftQuantity > 0
                ? SmartCartSelection.scaledBottleCounts(
                    _retainedGiftCounts, _free / _retainedGiftQuantity)
                : null);
      } on StateError catch (error) {
        return error.message.toString();
      }
    }
    if (!_fitsAvailable(_amount, _availableAmount(cart))) {
      return 'Выбранное количество превышает доступный остаток';
    }
    if (!_pour &&
        (_quantity / _step - (_quantity / _step).round()).abs() > 0.001) {
      return 'Количество должно быть кратно ${_amountLabel(_step)}';
    }
    final openedKey = _selection.displayKeyForVariants(_openedVariants);
    final currentKey = _selection.displayKeyForVariants(_baseVariants());
    if (currentKey != openedKey && _findGroup(cart, _baseVariants()) != null) {
      return 'Такая конфигурация уже есть в корзине. Измените её отдельно.';
    }
    if (_openedGroupExists && _findGroup(cart, _openedVariants) == null) {
      return 'Эта позиция уже удалена из корзины. Откройте товар заново.';
    }
    return null;
  }

  void _save() {
    final cart = context.read<CartProvider>();
    final invalid = _invalidReason(cart);
    if (invalid != null) {
      setState(() => _feedback = invalid);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(invalid)));
      return;
    }
    final variants = _baseVariants();
    if (_isRemoval(cart)) {
      cart.removeDisplayGroup(_findGroup(cart, _openedVariants)!);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _openedGroupExists = false;
          _saved = true;
          _feedback = null;
        });
      }
      return;
    }
    final saved = _pour
        ? cart.syncItemBottleCounts(
            widget.item, variants, Map<int, int>.of(_bottleCounts),
            previousBaseVariants: _openedVariants)
        : cart.syncItemSelectionQuantity(widget.item, variants, _quantity,
            previousBaseVariants: _openedVariants);
    if (!saved) {
      setState(() => _feedback =
          'Не удалось сохранить: проверьте объём, тару и доступный остаток.');
      return;
    }
    _openedVariants = variants;
    _openedGroupExists = true;
    final savedGroup = _findGroup(cart, variants);
    _retainedGiftQuantity = savedGroup?.freeQuantity ?? 0;
    _retainedGiftCounts = savedGroup?.selection?.usesPourFlow == true
        ? savedGroup!.selection!.giftBottleBreakdown(savedGroup.totalQuantity,
            retainedCounts: savedGroup.retainedGiftBottleCounts)
        : null;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saved = true;
        _feedback = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cart = context.watch<CartProvider>();
    final available = _availableAmount(cart);
    final invalid = _invalidReason(cart);
    _allocationIssue = null;
    _previewGroup = null;
    final previewItems = _previewItems;
    try {
      _price = CartItem.calculatePrice(previewItems);
      if (previewItems.isNotEmpty) {
        final previewGroups = CartDisplayGroup.groupItems(previewItems);
        if (previewGroups.isNotEmpty) _previewGroup = previewGroups.single;
      }
    } on StateError catch (error) {
      _price = null;
      _allocationIssue = error.message.toString();
    }
    final description = widget.item.description?.trim() ?? '';
    final removal = _isRemoval(cart);
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? palette.surface
          : palette.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Stack(
            children: [
              SingleChildScrollView(
                key: const ValueKey('configuration-scroll'),
                padding: EdgeInsets.only(
                  bottom: 180 +
                      MediaQuery.paddingOf(context).bottom +
                      (MediaQuery.textScalerOf(context).scale(16) > 20 ? 120 : 0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16)),
                      child: Container(
                        height: _pour ? 144 : 320,
                        color: Colors.white,
                        padding: EdgeInsets.fromLTRB(
                            48, _pour ? 64 : 88, 48, 16),
                        child: widget.item.hasImage
                            ? Image.network(widget.item.image!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.inventory_2_outlined,
                                    color: Colors.black38, size: 56))
                            : const Icon(Icons.inventory_2_outlined,
                                color: Colors.black38, size: 56),
                      ),
                    ),
                    Padding(
                      padding: _pour
                          ? const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xxxl,
                              vertical: AppSpacing.md)
                          : const EdgeInsets.all(AppSpacing.xxxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_view.category != null)
                            Text(_view.category!,
                                style: AppTypography.bodySmall
                                    .copyWith(color: palette.textSecondary)),
                          const SizedBox(height: AppSpacing.xs),
                          Text(_view.title,
                              style: AppTypography.displayBold
                                  .copyWith(color: palette.textPrimary)),
                          if (_view.metadata.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                                _view.metadata.where((part) =>
                                    part.toLowerCase() != _view.category?.toLowerCase()).join(' · '),
                                style: AppTypography.bodySmall
                                    .copyWith(color: palette.textSecondary)),
                          ],
                          SizedBox(height: _pour ? AppSpacing.xs : AppSpacing.xl),
                          _unitPrice(),
                          SizedBox(height: _pour ? AppSpacing.xs : AppSpacing.md),
                          Text(
                            key: const ValueKey('configuration-stock'),
                            !_inStock
                                ? 'Нет в наличии'
                                : (available.isFinite
                                    ? 'Доступно: ${_amountLabel(available)}'
                                    : 'В наличии'),
                            style: AppTypography.body.copyWith(
                                color: _inStock
                                    ? palette.textSecondary
                                    : palette.error),
                          ),
                          SizedBox(height: _pour ? AppSpacing.md : AppSpacing.xxxl),
                          if (_pour)
                            ..._bottles(available)
                          else ...[
                            _heading('Количество'),
                            const SizedBox(height: AppSpacing.md),
                            _ConfigurationStepper(
                              label: _amountLabel(_quantity),
                              valueKey: 'configuration-quantity',
                              onMinus: _quantity > (_openedGroupExists ? 0 : _step)
                                  ? () => setState(() {
                                        _quantity = math.max(0, _quantity - _step);
                                        _saved = false;
                                        _feedback = null;
                                      })
                                  : null,
                              onPlus: _inStock &&
                                      _canIncreaseDraft(cart) &&
                                      _fitsAvailable(
                                          _quantity + _step, available)
                                  ? () => setState(() {
                                        _quantity += _step;
                                        _saved = false;
                                      })
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.huge),
                          ],
                          for (final option in _options) ...[
                            _option(option),
                            const SizedBox(height: AppSpacing.huge),
                          ],
                          if (!_pour && _promotions.isNotEmpty) ...[
                            _promotionInfo(),
                            const SizedBox(height: AppSpacing.huge),
                          ],
                          if (!_pour && _options.isNotEmpty) _priceBreakdown(),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.huge),
                            _heading('Описание'),
                            const SizedBox(height: AppSpacing.md),
                            LayoutBuilder(builder: (context, constraints) {
                              final style = AppTypography.bodyMedium
                                  .copyWith(color: palette.textSecondary);
                              final painter = TextPainter(
                                text: TextSpan(text: description, style: style),
                                maxLines: 6,
                                textDirection: Directionality.of(context),
                                textScaler: MediaQuery.textScalerOf(context),
                              )..layout(maxWidth: constraints.maxWidth);
                              final overflows = painter.didExceedMaxLines;
                              painter.dispose();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(description,
                                      maxLines: _expanded ? null : 6,
                                      overflow: _expanded
                                          ? null
                                          : TextOverflow.ellipsis,
                                      style: style),
                                  if (overflows)
                                    TextButton(
                                      key: const ValueKey(
                                          'configuration-description-toggle'),
                                      onPressed: () =>
                                          setState(() => _expanded = !_expanded),
                                      child: Text(_expanded
                                          ? 'Свернуть'
                                          : 'Читать далее'),
                                    ),
                                ],
                              );
                            }),
                          ],
                          if (invalid != null || _feedback != null) ...[
                            const SizedBox(height: AppSpacing.xxxl),
                            Semantics(
                                liveRegion: true,
                                child: Text(_feedback ?? invalid!,
                                    key: const ValueKey(
                                        'configuration-feedback'),
                                    style: AppTypography.bodyMedium
                                        .copyWith(color: palette.error))),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 22,
                left: AppSpacing.xxxl,
                right: AppSpacing.xxxl,
                child: Row(
                  children: [
                    AppIconButton(
                        key: const ValueKey('configuration-back'),
                        asset: AppIcons.back,
                        tooltip: 'Назад без сохранения',
                        onTap: () => Navigator.of(context).maybePop()),
                    const Spacer(),
                    AppIconButton(
                        key: const ValueKey('configuration-like'),
                        asset: AppIcons.heart,
                        tooltip:
                            _liked ? 'Убрать из избранного' : 'В избранное',
                        onTap: _liking ? null : _toggleLike,
                        fill: _liked
                            ? palette.brandRed
                            : palette.surface.withValues(alpha: 0.75),
                        color: _liked ? Colors.white : palette.textPrimary),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _footer(
                  enabled: removal ||
                      (_allocationIssue == null &&
                          (_isReduction(cart) ||
                              (_inStock &&
                                  !cart.hasUnresolvedBusiness &&
                                  _selection.containerIssue == null &&
                                  _selection.quantityIssue == null))),
                  removal: removal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String text) => Text(text,
      style:
          AppTypography.headline.copyWith(color: context.palette.textPrimary));

  Widget _unitPrice() {
    final row = _previewItem(1);
    final base = _pour && _amount > 0 && _price != null
        ? _price!.productSubtotal / _amount
        : row.paidUnitPrice;
    final price = applyPromotionsToPaidBaseTotal(
        unitPrice: base, quantity: 1, promotions: _promotions);
    final unit = _view.unitPriceUnit;
    final suffix = unit == null ? '' : '/$unit';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (price < base)
        Text('${formatTenge(base)}$suffix',
            style: AppTypography.titleRegular.copyWith(
                color: context.palette.textSecondary,
                decoration: TextDecoration.lineThrough)),
      Text('${formatTenge(price)}$suffix',
          style: AppTypography.base(size: 32, weight: 700)
              .copyWith(color: context.palette.accent)),
    ]);
  }

  List<Widget> _bottles(double available) {
    final bottles = _visibleBottles;
    final physicalCounts = _allocationIssue == null
        ? (_previewGroup?.bottleCounts ?? _bottleCounts)
        : _bottleCounts;
    final mixParts = <String>[];
    var replacementTariff = false;
    for (final bottle in bottles) {
      final count = physicalCounts[bottle.relationId] ?? 0;
      if (count <= 0) continue;
      mixParts.add(
          '$count× ${_selection.volumeLabel(_selection.volumeForBottle(bottle))}');
      replacementTariff |= bottle.priceType.toUpperCase() == 'REPLACE';
    }
    final mix = mixParts.join(' • ');
    final promotion = evaluatePromotion(
        paidQuantity: _amount, promotions: _promotions);
    return [
      _heading('Объём и тара'),
      const SizedBox(height: AppSpacing.md),
      AppSurface(
        key: const ValueKey('configuration-price-breakdown'),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(_selection.volumeLabel(_amount + _free),
                    key: const ValueKey('configuration-volume'),
                    style: AppTypography.title),
                Text(
                    'Оплачено: ${_selection.volumeLabel(_amount)} · подарок: ${_selection.volumeLabel(_free)}',
                    key: const ValueKey('configuration-paid-gift'),
                    style: AppTypography.bodySmall
                        .copyWith(color: context.palette.textSecondary)),
              ],
            ),
            if (mix.isNotEmpty)
              Text(mix,
                  key: const ValueKey('configuration-physical-bottles'),
                  style: AppTypography.bodySmall
                      .copyWith(color: context.palette.textSecondary)),
            if (_allocationIssue != null)
              Text(_allocationIssue!,
                  style: AppTypography.bodySmall
                      .copyWith(color: context.palette.error))
            else if (_price != null)
              Text(
                  '${replacementTariff ? 'Напиток и тара по тарифам' : 'Напиток'} ${formatTenge(_price!.productSubtotal - _price!.discount)} · '
                  '${replacementTariff ? 'доплаты' : 'вся тара и дополнения'} ${formatTenge(_price!.optionsTotal)}',
                  style: AppTypography.bodySmall
                      .copyWith(color: context.palette.textSecondary)),
            if (promotion.award != null) ...[
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: AppRadii.pillAll,
                child: LinearProgressIndicator(
                  key: const ValueKey('configuration-promotion-progress'),
                  value: promotion.progress,
                  minHeight: 4,
                  color: context.palette.accent,
                  backgroundColor: context.palette.surfaceMuted,
                ),
              ),
              Text(
                  _free > 0
                      ? 'Напиток в подарок — 0 ₸; тара включена в расчёт'
                      : 'До подарка: ${_amountLabel(promotion.nextGiftIn)} оплаченного напитка',
                  style: AppTypography.bodySmall
                      .copyWith(color: context.palette.textSecondary)),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      if (_selection.containerIssue != null)
        Text(_selection.containerIssue!,
            style: AppTypography.body
                .copyWith(color: context.palette.error)),
      for (final bottle in bottles) ...[
        AppSurface(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LayoutBuilder(builder: (context, constraints) {
            final identity = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bottle.itemName.trim().isEmpty
                      ? _selection.volumeLabel(_selection.volumeForBottle(bottle))
                      : bottle.itemName,
                  style: AppTypography.bodyMedium
                      .copyWith(color: context.palette.textPrimary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${_selection.volumeLabel(_selection.volumeForBottle(bottle))} · '
                  '${bottle.priceType.toUpperCase() == 'REPLACE' ? 'напиток по тарифу' : 'тара +'} '
                  '${formatTenge(bottle.price)}'
                  '${_isOfferedBottle(bottle) ? '' : ' · снята с продажи'}',
                  style: AppTypography.bodySmall
                      .copyWith(color: context.palette.textSecondary),
                ),
                if ((physicalCounts[bottle.relationId] ?? 0) >
                    (_bottleCounts[bottle.relationId] ?? 0))
                  Text(
                    'Напиток: ${_bottleCounts[bottle.relationId] ?? 0} оплачено · ${(physicalCounts[bottle.relationId] ?? 0) - (_bottleCounts[bottle.relationId] ?? 0)} подарок',
                    key: ValueKey(
                        'configuration-bottle-allocation-${bottle.relationId}'),
                    style: AppTypography.bodySmall
                        .copyWith(color: context.palette.textSecondary),
                  ),
              ],
            );
            final stepper = _ConfigurationStepper(
              valueKey: 'configuration-bottle-${bottle.relationId}',
              label: '${_bottleCounts[bottle.relationId] ?? 0}',
              onMinus: (_bottleCounts[bottle.relationId] ?? 0) > 0
                  ? () => setState(() {
                        _bottleCounts[bottle.relationId] =
                            (_bottleCounts[bottle.relationId] ?? 0) - 1;
                        _saved = false;
                        _feedback = null;
                      })
                  : null,
              onPlus: _inStock &&
                      _canIncreaseDraft(context.read<CartProvider>()) &&
                      _isOfferedBottle(bottle) &&
                      _fitsAvailable(
                          _amount + _selection.volumeForBottle(bottle), available)
                  ? () => setState(() {
                        _bottleCounts[bottle.relationId] =
                            (_bottleCounts[bottle.relationId] ?? 0) + 1;
                        _saved = false;
                        _feedback = null;
                      })
                  : null,
            );
            if (constraints.maxWidth < 280 ||
                MediaQuery.textScalerOf(context).scale(14) > 18) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const SizedBox(height: AppSpacing.md),
                  stepper,
                ],
              );
            }
            return Row(children: [
              Expanded(child: identity),
              const SizedBox(width: AppSpacing.md),
              SizedBox(width: 132, child: stepper),
            ]);
          }),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    ];
  }

  Widget _option(item_model.ItemOption option) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(option.name),
          const SizedBox(height: AppSpacing.xs),
          Text(
              '${option.required == 1 ? 'Обязательно' : 'Необязательно'} · ${option.selection.toUpperCase() == 'MULTIPLE' ? 'Можно выбрать несколько' : 'Один вариант'}',
              style: AppTypography.body
                  .copyWith(color: context.palette.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          if (option.optionItems.isEmpty)
            Text('Варианты недоступны',
                style:
                    AppTypography.body.copyWith(color: context.palette.error)),
          for (final value in option.optionItems)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Material(
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                clipBehavior: Clip.antiAlias,
                child: CheckboxListTile(
                  key: ValueKey(
                      'configuration-option-${option.optionId}-${value.relationId}'),
                  value: _selected[option.optionId]?.any((selected) =>
                          selected.relationId == value.relationId) ==
                      true,
                  onChanged:
                      _inStock ? (_) => _toggleOption(option, value) : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                      value.itemName.isEmpty
                          ? 'Вариант ${value.relationId}'
                          : value.itemName,
                      style: AppTypography.titleMedium
                          .copyWith(color: context.palette.textPrimary)),
                  subtitle: Text(
                      '${value.priceType.toUpperCase() == 'REPLACE' ? 'Вместо базовой цены: ' : '+ '}${formatTenge(value.price)} за ${_amountLabel(value.parentItemAmount > 0 ? value.parentItemAmount : _step)}',
                      style: AppTypography.body
                          .copyWith(color: context.palette.textSecondary)),
                ),
              ),
            ),
        ],
      );

  Widget _promotionInfo() {
    final evaluation = evaluatePromotion(
        paidQuantity: _amount, promotions: _promotions);
    return AppSurface(
      key: const ValueKey('configuration-promotion'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final promotion
            in widget.item.promotions ?? const <item_model.ItemPromotion>[])
          if (promotion.isActive) ...[
            Text(promotion.name,
                style: AppTypography.title
                    .copyWith(color: context.palette.gold)),
            if (promotion.discountType == 'SUBTRACT' &&
                promotion.baseAmount > 0 &&
                promotion.addAmount > 0)
              Text(
                  'За каждые ${_amountLabel(promotion.baseAmount.toDouble())} — ${_amountLabel(promotion.addAmount.toDouble())} этого напитка в подарок',
                  style: AppTypography.body
                      .copyWith(color: context.palette.textSecondary)),
            if (promotion.description?.trim().isNotEmpty == true)
              Text(promotion.description!,
                  style: AppTypography.body
                      .copyWith(color: context.palette.textSecondary)),
          ],
        if (evaluation.award != null) ...[
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadii.pillAll,
            child: LinearProgressIndicator(
              key: const ValueKey('configuration-promotion-progress'),
              value: evaluation.progress,
              minHeight: 6,
              color: context.palette.accent,
              backgroundColor: context.palette.surfaceMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
              _free > 0
                  ? 'Подарок: ${_amountLabel(_free)} · напиток 0 ₸'
                  : 'До подарка: ${_amountLabel(evaluation.nextGiftIn)} оплаченного напитка',
              style: AppTypography.bodySmall
                  .copyWith(color: context.palette.textSecondary)),
        ],
      ]),
    );
  }

  Widget _priceBreakdown() => AppSurface(
        key: const ValueKey('configuration-price-breakdown'),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heading('Состав цены'),
          const SizedBox(height: AppSpacing.md),
          if (_allocationIssue != null)
            Text(_allocationIssue!,
                style:
                    AppTypography.body.copyWith(color: context.palette.error))
          else ...[
            _priceLine(
                'Товар · ${_amountLabel(_amount)}', _price!.productSubtotal),
            if (_price!.optionsTotal != 0)
              _priceLine('Дополнения',
                  _price!.optionsTotal),
            if (_price!.discount > 0) _priceLine('Скидка', -_price!.discount),
            if (_free > 0)
              _priceLine('Напиток в подарок · ${_amountLabel(_free)}', 0),
          ],
        ]),
      );

  Widget _priceLine(String label, double value) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              Text(label,
                  style: AppTypography.body
                      .copyWith(color: context.palette.textSecondary)),
              Text(formatTenge(value),
                  style: AppTypography.bodyMedium
                      .copyWith(color: context.palette.textPrimary)),
            ]),
      );

  Widget _footer({required bool enabled, required bool removal}) =>
      AppGlassPanel(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(builder: (context, constraints) {
            final adaptive = constraints.maxWidth < 320 ||
                MediaQuery.textScalerOf(context).scale(16) > 20;
            final summary = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_subtotal > _total)
                    Text(formatTenge(_subtotal),
                        style: AppTypography.bodySmall.copyWith(
                            color: context.palette.textSecondary,
                            decoration: TextDecoration.lineThrough)),
                  Text(
                      removal
                          ? formatTenge(0)
                          : (_allocationIssue == null
                              ? formatTenge(_total)
                              : 'Расчёт недоступен'),
                      key: const ValueKey('configuration-total'),
                      style: AppTypography.displayBold
                          .copyWith(color: context.palette.textPrimary)),
                ]);
            final action = FilledButton(
              key: const ValueKey('configuration-save'),
              onPressed: enabled ? _save : null,
              style: FilledButton.styleFrom(
                  minimumSize: const Size(154, 49),
                  shape: const StadiumBorder()),
              child: Text(removal
                  ? 'Удалить'
                  : (!_inStock && !enabled
                      ? 'Нет в наличии'
                      : (_openedGroupExists ? 'Сохранить' : 'В корзину'))),
            );
            return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_saved)
                    AppGlassPanel(
                      radius: AppRadii.pill,
                      tint: context.palette.success.withValues(alpha: 0.75),
                      padding: const EdgeInsets.all(14),
                      child: Text('Сохранено в корзине',
                          textAlign: TextAlign.center,
                          style: AppTypography.title
                              .copyWith(color: Colors.white)),
                    )
                  else if (adaptive) ...[
                    summary,
                    const SizedBox(height: AppSpacing.md),
                    action,
                  ] else
                    Row(children: [
                      Expanded(child: summary),
                      const SizedBox(width: AppSpacing.md),
                      action,
                    ]),
                  if (widget.onCart != null)
                    TextButton(
                        key: const ValueKey('configuration-cart'),
                        onPressed: widget.onCart,
                        child: const Text('Открыть корзину')),
                ]);
          }),
        ),
      );
}

class _ConfigurationStepper extends StatelessWidget {
  const _ConfigurationStepper(
      {required this.label, required this.valueKey, this.onMinus, this.onPlus});
  final String label;
  final String valueKey;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    ButtonStyle style(VoidCallback? callback) => IconButton.styleFrom(
      minimumSize: const Size.square(AppSpacing.touchTarget),
      backgroundColor: callback == null ? palette.accentFaint : palette.accentSoft,
      foregroundColor: palette.textOnAccent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg)),
    );
    return AppSurface(
      radius: 18,
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Row(children: [
        IconButton(
            key: ValueKey('$valueKey-minus'),
            tooltip: 'Уменьшить',
            onPressed: onMinus,
            style: style(onMinus),
            icon: const Icon(Icons.remove_rounded)),
        Expanded(
            child: Text(label,
                key: ValueKey(valueKey),
                textAlign: TextAlign.center,
                style: AppTypography.headlineMedium
                    .copyWith(color: palette.textPrimary))),
        IconButton(
            key: ValueKey('$valueKey-plus'),
            tooltip: 'Увеличить',
            onPressed: onPlus,
            style: style(onPlus),
            icon: const Icon(Icons.add_rounded)),
      ]),
    );
  }
}
