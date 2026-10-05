import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../core/quantity.dart';
import '../model/item.dart' as item_model;
import '../model/cart_item.dart';
import '../ui/app_icon.dart';
import '../ui/app_icon_button.dart';
import '../ui/surfaces.dart';
import '../utils/api.dart';
import '../utils/business_provider.dart';
import '../utils/cart_provider.dart';
import '../utils/item_name_presentation.dart';
import '../utils/liked_items_provider.dart';
import '../utils/liked_storage_service.dart';
import '../utils/smart_cart.dart';
import '../utils/subtract_promotion_math.dart';

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
  late final ItemTitlePresentation _title;
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
      : 'ед.';
  double get _amount => _pour ? _bottleAmount(_bottleCounts) : _quantity;

  @override
  void initState() {
    super.initState();
    _selection = SmartCartSelection(widget.item);
    _title = presentItemName(
        rawName: widget.item.name, categoryName: widget.item.category?.name);
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
          for (final bottle in _selection.filteredBottles)
            if ((_bottleCounts[bottle.relationId] ?? 0) > 0)
              _previewItem(
                  _selection.volumeForBottle(bottle) *
                      _bottleCounts[bottle.relationId]!,
                  bottle: bottle),
        ];

  CartPriceBreakdown? _price;
  String? _allocationIssue;
  double get _total => _price?.totalPrice ?? 0;
  double get _subtotal => _price?.subtotalBeforePromotions ?? 0;
  double get _free => subtractPromotionFreeQuantity(_amount, _promotions);
  double _bottleAmount(Map<int, int> counts) =>
      _selection.filteredBottles.fold<double>(
          0,
          (sum, bottle) =>
              sum +
              _selection.volumeForBottle(bottle) *
                  (counts[bottle.relationId] ?? 0));
  String _money(double value) =>
      '${value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2)} ₸';
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

  String? _invalidReason(CartProvider cart) {
    if (_selection.containerIssue != null) return _selection.containerIssue;
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
        _selection.giftBottleBreakdown(_amount);
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
    try {
      _price = CartItem.calculatePrice(_previewItems);
    } on StateError catch (error) {
      _price = null;
      _allocationIssue = error.message.toString();
    }
    final description = widget.item.description?.trim() ?? '';
    return Scaffold(
      bottomNavigationBar: _footer(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Stack(
            children: [
              SingleChildScrollView(
                key: const ValueKey('configuration-scroll'),
                padding: const EdgeInsets.only(bottom: AppSpacing.huge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: math.min(
                          MediaQuery.sizeOf(context).width * 0.85, 320),
                      child: ColoredBox(
                        color: palette.surface,
                        child: widget.item.hasImage
                            ? Image.network(widget.item.image!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Center(
                                    child: Icon(Icons.inventory_2_outlined,
                                        color: palette.textSecondary,
                                        size: 56)))
                            : Center(
                                child: Icon(Icons.inventory_2_outlined,
                                    color: palette.textSecondary, size: 56)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                              [
                                widget.item.category?.name,
                                _title.countryName,
                              ]
                                  .whereType<String>()
                                  .where((part) => part.isNotEmpty)
                                  .join(' · '),
                              style: AppTypography.bodySmall
                                  .copyWith(color: palette.textSecondary)),
                          const SizedBox(height: AppSpacing.xs),
                          Text(_title.name,
                              style: AppTypography.displayBold
                                  .copyWith(color: palette.textPrimary)),
                          const SizedBox(height: AppSpacing.huge),
                          _unitPrice(),
                          const SizedBox(height: AppSpacing.md),
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
                          const SizedBox(height: AppSpacing.huge),
                          if (_pour)
                            ..._bottles(available)
                          else ...[
                            _heading('Количество'),
                            const SizedBox(height: AppSpacing.md),
                            _ConfigurationStepper(
                              label: _amountLabel(_quantity),
                              valueKey: 'configuration-quantity',
                              onMinus: _inStock && _quantity > _step + 0.001
                                  ? () => setState(() {
                                        _quantity -= _step;
                                        _saved = false;
                                      })
                                  : null,
                              onPlus: _inStock &&
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
                          if (_promotions.isNotEmpty) ...[
                            _promotionInfo(),
                            const SizedBox(height: AppSpacing.huge),
                          ],
                          _priceBreakdown(),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.huge),
                            _heading('Описание'),
                            const SizedBox(height: AppSpacing.md),
                            Text(description,
                                maxLines: _expanded ? null : 6,
                                overflow:
                                    _expanded ? null : TextOverflow.ellipsis,
                                style: AppTypography.bodyMedium
                                    .copyWith(color: palette.textSecondary)),
                            if (description.length > 190)
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    key: const ValueKey(
                                        'configuration-description-toggle'),
                                    onPressed: () =>
                                        setState(() => _expanded = !_expanded),
                                    child: Text(_expanded
                                        ? 'Свернуть'
                                        : 'Читать далее'),
                                  )),
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
    final unit = _unit.toLowerCase();
    final weight = !_pour && (unit.contains('кг') || unit.contains('kg'));
    final amount = weight ? 0.1 : 1.0;
    final row = _previewItem(amount);
    final productSubtotal = row.paidUnitPrice * amount;
    final price = applyPromotionsToPaidBaseTotal(
        unitPrice: row.paidUnitPrice,
        quantity: amount,
        promotions: _promotions);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (price < productSubtotal)
        Text(_money(productSubtotal),
            style: AppTypography.titleRegular.copyWith(
                color: context.palette.textSecondary,
                decoration: TextDecoration.lineThrough)),
      Text(_money(price),
          style: AppTypography.displayLargeRegular
              .copyWith(color: context.palette.accent)),
      Text(
          _pour
              ? 'Базовая цена · за ${_amountLabel(1)}'
              : (weight ? 'за 100 г' : 'за ${_amountLabel(1)}'),
          style: AppTypography.body
              .copyWith(color: context.palette.textSecondary)),
    ]);
  }

  List<Widget> _bottles(double available) => [
        _heading('Объём и тара'),
        const SizedBox(height: AppSpacing.md),
        Text(
            'Выберите тару для оплаченного напитка. Тара для подарка добавляется отдельно и оплачивается по обычному тарифу.',
            style: AppTypography.body
                .copyWith(color: context.palette.textSecondary)),
        const SizedBox(height: AppSpacing.xl),
        for (final bottle in _selection.filteredBottles) ...[
          AppSurface(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      bottle.itemName.trim().isEmpty
                          ? _selection
                              .volumeLabel(_selection.volumeForBottle(bottle))
                          : bottle.itemName,
                      style: AppTypography.titleMedium
                          .copyWith(color: context.palette.textPrimary)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                      '${_selection.volumeLabel(_selection.volumeForBottle(bottle))} · ${bottle.priceType.toUpperCase() == 'REPLACE' ? 'вместо базовой цены' : 'тара +'} ${_money(bottle.price)}',
                      style: AppTypography.body
                          .copyWith(color: context.palette.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  _ConfigurationStepper(
                    valueKey: 'configuration-bottle-${bottle.relationId}',
                    label: '${_bottleCounts[bottle.relationId] ?? 0}',
                    onMinus: _inStock &&
                            (_bottleCounts[bottle.relationId] ?? 0) > 0
                        ? () => setState(() {
                              _bottleCounts[bottle.relationId] =
                                  (_bottleCounts[bottle.relationId] ?? 0) - 1;
                              _saved = false;
                              _feedback = null;
                            })
                        : null,
                    onPlus: _inStock &&
                            _fitsAvailable(
                                _amount + _selection.volumeForBottle(bottle),
                                available)
                        ? () => setState(() {
                              _bottleCounts[bottle.relationId] =
                                  (_bottleCounts[bottle.relationId] ?? 0) + 1;
                              _saved = false;
                              _feedback = null;
                            })
                        : null,
                  ),
                ]),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(_amountLabel(_amount + _free),
            key: const ValueKey('configuration-volume'),
            style: AppTypography.headlineMedium
                .copyWith(color: context.palette.textPrimary)),
        const SizedBox(height: AppSpacing.huge),
      ];

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
                      '${value.priceType.toUpperCase() == 'REPLACE' ? 'Вместо базовой цены: ' : '+ '}${_money(value.price)} за ${_amountLabel(value.parentItemAmount > 0 ? value.parentItemAmount : _step)}',
                      style: AppTypography.body
                          .copyWith(color: context.palette.textSecondary)),
                ),
              ),
            ),
        ],
      );

  Widget _promotionInfo() => AppSurface(
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
                    'За каждые ${_amountLabel(promotion.baseAmount.toDouble())} +${_amountLabel(promotion.addAmount.toDouble())} в подарок',
                    style: AppTypography.body
                        .copyWith(color: context.palette.textSecondary)),
              if (promotion.description?.trim().isNotEmpty == true)
                Text(promotion.description!,
                    style: AppTypography.body
                        .copyWith(color: context.palette.textSecondary)),
            ],
          if (_free > 0)
            Text('+${_amountLabel(_free)} в подарок',
                style: AppTypography.bodyBold
                    .copyWith(color: context.palette.gold)),
        ]),
      );

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
              _priceLine(_pour ? 'Тара и дополнения' : 'Дополнения',
                  _price!.optionsTotal),
            if (_price!.discount > 0) _priceLine('Скидка', -_price!.discount),
            if (_free > 0) ...[
              Text('Подарок: ${_amountLabel(_free)}',
                  style: AppTypography.bodyBold
                      .copyWith(color: context.palette.gold)),
              if (_pour) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                    'Всего напитка: ${_amountLabel(_amount + _free)}. '
                    'Вся тара, включая тару для подарка, оплачивается по обычному тарифу.',
                    style: AppTypography.bodySmall
                        .copyWith(color: context.palette.textSecondary)),
                Text(
                    CartDisplayGroup.groupItems(_previewItems)
                            .single
                            .bottleBreakdownLabel ??
                        '',
                    key: const ValueKey('configuration-physical-bottles'),
                    style: AppTypography.bodySmall
                        .copyWith(color: context.palette.textSecondary)),
              ],
            ],
            const Divider(),
            _priceLine('Итого', _total),
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
              Text(_money(value),
                  style: AppTypography.bodyMedium
                      .copyWith(color: context.palette.textPrimary)),
            ]),
      );

  Widget _footer() => AppGlassPanel(
        radius: 0,
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xxxl,
                    AppSpacing.xxxl, AppSpacing.xxxl, AppSpacing.xxxl),
                child: LayoutBuilder(builder: (context, constraints) {
                  final adaptive = constraints.maxWidth < 343 ||
                      MediaQuery.textScalerOf(context).scale(16) > 20;
                  final summary = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_saved ? 'Сохранено в корзине' : 'Итого',
                            style: AppTypography.body.copyWith(
                                color: context.palette.textSecondary)),
                        if (_subtotal > _total)
                          Text(_money(_subtotal),
                              style: AppTypography.body.copyWith(
                                  color: context.palette.textSecondary,
                                  decoration: TextDecoration.lineThrough)),
                        Text(
                            _allocationIssue == null
                                ? _money(_total)
                                : 'Расчёт недоступен',
                            key: const ValueKey('configuration-total'),
                            style: AppTypography.displayBold
                                .copyWith(color: context.palette.textPrimary)),
                      ]);
                  final action = FilledButton(
                    key: const ValueKey('configuration-save'),
                    onPressed:
                        !_inStock || _allocationIssue != null ? null : _save,
                    child: Text(!_inStock
                        ? 'Нет в наличии'
                        : (_openedGroupExists ? 'Сохранить' : 'В корзину')),
                  );
                  return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (adaptive) ...[
                          summary,
                          const SizedBox(height: AppSpacing.md),
                          action,
                        ] else
                          Row(children: [
                            Expanded(child: summary),
                            const SizedBox(width: AppSpacing.xl),
                            Flexible(child: action)
                          ]),
                        if (widget.onCart != null)
                          TextButton(
                              key: const ValueKey('configuration-cart'),
                              onPressed: widget.onCart,
                              child: const Text('Открыть корзину')),
                      ]);
                }),
              ),
            ),
          ),
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
  Widget build(BuildContext context) => AppSurface(
        radius: AppRadii.xl,
        child: Row(children: [
          IconButton(
              key: ValueKey('$valueKey-minus'),
              tooltip: 'Уменьшить',
              onPressed: onMinus,
              icon: const Icon(Icons.remove_rounded)),
          Expanded(
              child: Text(label,
                  key: ValueKey(valueKey),
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineMedium
                      .copyWith(color: context.palette.textPrimary))),
          IconButton(
              key: ValueKey('$valueKey-plus'),
              tooltip: 'Увеличить',
              onPressed: onPlus,
              icon: const Icon(Icons.add_rounded)),
        ]),
      );
}
