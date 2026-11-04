import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../core/money.dart';
import '../core/product_view.dart';
import '../core/like_action.dart';
import '../core/quantity.dart';
import '../model/item.dart' as item_model;
import '../model/cart_item.dart';
import '../ui/app_icon.dart';
import '../ui/app_icon_button.dart';
import '../ui/frosted_dock.dart';
import '../ui/motion_widgets.dart';
import '../ui/product_hero_header.dart';
import '../ui/promotion_nudge.dart';
import '../ui/surfaces.dart';
import '../utils/api.dart';
import '../services/auth_service.dart';
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
  final _scroll = ScrollController();
  late final SmartCartSelection _selection;
  late final ProductView _view;
  late final List<item_model.ItemOption> _options;
  late List<Map<String, dynamic>> _openedVariants;
  final Map<int, List<item_model.ItemOptionItem>> _selected = {};
  final Map<int, int> _bottleCounts = {};
  double _quantity = 0;
  bool _restored = false;
  bool _openedGroupExists = false;
  bool _expanded = false;
  bool _liked = false;
  bool _summaryMayAnimate = false;
  bool _liking = false;
  bool _saved = false;
  int? _businessId;
  String? _feedback;
  int _credentialRevision = AuthService.credentialRevision;
  double _footerHeight = 180;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Summary badges that appear after the screen's first frame animate in.
      _summaryMayAnimate = true;
    });
    AuthService.sessionRevision.addListener(_sessionChanged);
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
        _bottleCounts.addAll(group.bottleCounts);
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

  void _sessionChanged() {
    if (_credentialRevision != AuthService.credentialRevision) {
      _credentialRevision = AuthService.credentialRevision;
      setState(() {
        _liked = false;
        _liking = false;
      });
    }
    final businessId = _businessId;
    if (businessId != null) _loadLiked(businessId);
  }

  @override
  void dispose() {
    _scroll.dispose();
    AuthService.sessionRevision.removeListener(_sessionChanged);
    super.dispose();
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
    final session = await AuthService.captureSession();
    if (session == null) return;
    final known = provider?.confirmedLike(businessId, widget.item.itemId);
    final liked = known ??
        await LikedStorageService.isLiked(
            businessId: businessId, itemId: widget.item.itemId);
    if (!mounted || !session.isCurrent || businessId != _businessId) return;
    final resolved =
        provider?.confirmedLike(businessId, widget.item.itemId) ?? liked;
    setState(() => _liked = resolved);
    if (provider?.confirmedLike(businessId, widget.item.itemId) == null &&
        resolved) {
      provider?.updateLike(businessId, widget.item.itemId, true);
    }
  }

  Future<void> _toggleLike() async {
    if (_liking) return;
    setState(() => _liking = true);
    final provider = context.read<LikedItemsProvider?>();
    final session = await AuthService.captureSession();
    try {
      if (session == null || !mounted) return;
      final businessId = _businessId;
      final callback = widget.onLike;
      final bool? liked;
      if (callback == null && businessId != null) {
        liked = await toggleItemLike(
          context,
          businessId: businessId,
          itemId: widget.item.itemId,
        );
      } else {
        liked = await (callback ??
            (itemId) => ApiService.toggleLikeItem(
                  itemId,
                  credentialToken: session.token,
                ))(widget.item.itemId);
        if (!session.isCurrent) return;
        if (liked != null && businessId != null) {
          provider?.updateLike(businessId, widget.item.itemId, liked);
          try {
            await LikedStorageService.setLiked(
                businessId: businessId,
                itemId: widget.item.itemId,
                liked: liked);
          } catch (_) {
            if (mounted && session.isCurrent) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text('Избранное изменено, но не сохранено на устройстве'),
              ));
            }
          }
        }
      }
      if (!mounted || !session.isCurrent) return;
      if (liked == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Не удалось изменить избранное. Войдите в аккаунт или попробуйте ещё раз.')));
        return;
      }
      setState(() => _liked = liked!);
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

  /// The customer receives exactly what they picked, gift included.
  bool _fitsAvailable(double quantity, double available) =>
      quantity <= available + 0.0000001;

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
        selectedVariants: _selection.buildVariantMaps(
            bottle: bottle, baseVariants: _baseVariants()),
        promotions: _promotions,
        itemData: widget.item.toJson(),
      );

  List<CartItem> get _previewItems => _itemsForCounts(_bottleCounts);

  List<CartItem> _itemsForCounts(Map<int, int> counts) => !_pour
      ? [_previewItem(_quantity)]
      : [
          for (final bottle in _visibleBottles)
            if ((counts[bottle.relationId] ?? 0) > 0)
              _previewItem(
                  _selection.volumeForBottle(bottle) *
                      counts[bottle.relationId]!,
                  bottle: bottle),
        ];

  /// What one more [bottle] adds to the draft's total: the drink may be free
  /// by the promotion, its bottle never is. Null when it cannot be priced.
  double? _costWithExtraBottle(item_model.ItemOptionItem bottle) {
    final counts = {
      ..._bottleCounts,
      bottle.relationId: (_bottleCounts[bottle.relationId] ?? 0) + 1,
    };
    try {
      final group =
          CartEvaluation(CartDisplayGroup.groupItems(_itemsForCounts(counts)))
              .groups
              .firstOrNull;
      if (group == null || group.allocationIssue != null || _price == null) {
        return null;
      }
      return group.price.totalPrice - _total;
    } on StateError {
      return null;
    }
  }

  CartPriceBreakdown? _price;
  CartGroupEvaluation? _previewGroup;
  String? _allocationIssue;
  double get _total => _price?.totalPrice ?? 0;
  double get _subtotal => _price?.subtotalBeforePromotions ?? 0;
  PromotionEvaluation get _gift =>
      evaluatePromotion(quantity: _amount, promotions: _promotions);
  double get _free => _gift.giftQuantity;

  /// Containers this screen lists: the ones the shop offers plus any withdrawn container the
  /// opened cart already holds, so a legacy three-litre row can be reviewed and removed instead of
  /// silently stranded.
  List<item_model.ItemOptionItem> get _visibleBottles => [
        ..._selection.filteredBottles,
        for (final bottle in _selection.bottleVariants)
          if (!_selection.bottleRelationIds.contains(bottle.relationId) &&
              (_bottleCounts[bottle.relationId] ?? 0) > 0)
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
            (entry) => entry.value <= (opened.bottleCounts[entry.key] ?? 0));
  }

  bool _canIncreaseDraft(CartProvider cart) =>
      !cart.hasUnresolvedBusiness &&
      _selection.quantityIssue == null &&
      _selection.containerIssue == null &&
      _findGroup(cart, _openedVariants)?.hasWithdrawnBottles != true;

  String? _invalidReason(CartProvider cart,
      {CartGroupEvaluation? preview, double? available}) {
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
      final evaluated = preview ??
          CartEvaluation(CartDisplayGroup.groupItems(_previewItems))
              .groups
              .firstOrNull;
      final issue = evaluated?.allocationIssue;
      if (issue != null) return issue;
    }
    if (!_fitsAvailable(_amount, available ?? _availableAmount(cart))) {
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
    final liked = _businessId == null
        ? _liked
        : context.select<LikedItemsProvider?, bool?>((likes) =>
                likes?.confirmedLike(_businessId!, widget.item.itemId)) ??
            _liked;
    final cart = context.watch<CartProvider>();
    final available = _availableAmount(cart);
    _allocationIssue = null;
    _previewGroup = null;
    final previewItems = _previewItems;
    try {
      final preview = CartEvaluation(CartDisplayGroup.groupItems(previewItems));
      _previewGroup = preview.groups.firstOrNull;
      _allocationIssue = _previewGroup?.allocationIssue;
      _price = preview.price;
    } on StateError catch (error) {
      _price = null;
      _allocationIssue = error.message.toString();
    }
    final invalid =
        _invalidReason(cart, preview: _previewGroup, available: available);
    final description = widget.item.description?.trim() ?? '';
    final removal = _isRemoval(cart);
    final pageColor = Theme.of(context).brightness == Brightness.light
        ? palette.surface
        : palette.background;
    return Scaffold(
      backgroundColor: pageColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: FrostedDock(
            content: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scroll,
                  key: const ValueKey('configuration-scroll'),
                  padding: EdgeInsets.only(
                    bottom: _footerHeight +
                        MediaQuery.paddingOf(context).bottom +
                        AppSpacing.xl * 2,
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
                          padding:
                              EdgeInsets.fromLTRB(48, _pour ? 64 : 88, 48, 16),
                          child: widget.item.hasImage
                              ? Image.network(widget.item.image!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.inventory_2_outlined,
                                      color: Colors.black38,
                                      size: 56))
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
                                  _view.metadata
                                      .where((part) =>
                                          part.toLowerCase() !=
                                          _view.category?.toLowerCase())
                                      .join(' · '),
                                  style: AppTypography.bodySmall
                                      .copyWith(color: palette.textSecondary)),
                            ],
                            SizedBox(
                                height: _pour ? AppSpacing.xs : AppSpacing.xl),
                            _unitPrice(),
                            if (_pour && _gift.award != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '${_gift.award!.label} · '
                                '${promotionRuleText(_gift.award!, _selection.volumeLabel)}'
                                ', бутылки оплачиваются',
                                key: const ValueKey(
                                    'configuration-promotion-rule'),
                                style: AppTypography.bodySmallMedium
                                    .copyWith(color: palette.accent),
                              ),
                            ],
                            SizedBox(
                                height: _pour ? AppSpacing.xs : AppSpacing.md),
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
                            SizedBox(
                                height:
                                    _pour ? AppSpacing.md : AppSpacing.xxxl),
                            if (_pour)
                              ..._bottles(available)
                            else ...[
                              _heading('Количество'),
                              const SizedBox(height: AppSpacing.md),
                              _ConfigurationStepper(
                                label: _amountLabel(_quantity),
                                valueKey: 'configuration-quantity',
                                onMinus: _quantity >
                                        (_openedGroupExists ? 0 : _step)
                                    ? () => setState(() {
                                          _quantity =
                                              math.max(0, _quantity - _step);
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
                              _promotionInfo(cart, available),
                              const SizedBox(height: AppSpacing.huge),
                            ],
                            if (!_pour && _options.isNotEmpty)
                              _priceBreakdown(),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.huge),
                              _heading('Описание'),
                              const SizedBox(height: AppSpacing.md),
                              LayoutBuilder(builder: (context, constraints) {
                                final style = AppTypography.bodyMedium
                                    .copyWith(color: palette.textSecondary);
                                final painter = TextPainter(
                                  text:
                                      TextSpan(text: description, style: style),
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
                                        onPressed: () => setState(
                                            () => _expanded = !_expanded),
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
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ProductHeroHeader(
                    controller: _scroll,
                    heroHeight: _pour ? 144 : 320,
                    title: _view.title,
                    background: pageColor,
                    leading: AppIconButton(
                        key: const ValueKey('configuration-back'),
                        asset: AppIcons.back,
                        tooltip: 'Назад без сохранения',
                        onTap: () => Navigator.of(context).maybePop()),
                    trailing: AppIconButton(
                        key: const ValueKey('configuration-like'),
                        asset: liked ? AppIcons.heartFilled : AppIcons.heart,
                        tooltip: liked ? 'Убрать из избранного' : 'В избранное',
                        onTap: _liking ? null : _toggleLike,
                        fill: liked ? AppIconButton.likedFill(palette) : null,
                        color: liked ? Colors.white : palette.textPrimary),
                  ),
                ),
              ],
            ),
            dock: _footer(
              enabled: removal ||
                  (_allocationIssue == null &&
                      (_isReduction(cart) ||
                          (_inStock &&
                              !cart.hasUnresolvedBusiness &&
                              _selection.containerIssue == null &&
                              _selection.quantityIssue == null))),
              removal: removal,
              pourSummary: _pourSummary(cart, available),
            ),
            onDockHeightChanged: (height) {
              if ((height - _footerHeight).abs() > 0.5) {
                setState(() => _footerHeight = height);
              }
            },
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
    final paidLitres = _pour ? _gift.paidQuantity : _amount;
    final base = _pour && paidLitres > 0 && _price != null
        ? _price!.productSubtotal / paidLitres
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
    final cart = context.read<CartProvider>();
    final canAdd = _inStock && _canIncreaseDraft(cart);
    return [
      if (_selection.containerIssue != null) ...[
        Text(_selection.containerIssue!,
            style: AppTypography.body.copyWith(color: context.palette.error)),
        const SizedBox(height: AppSpacing.md),
      ],
      for (final bottle in _visibleBottles) ...[
        AppSurface(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LayoutBuilder(builder: (context, constraints) {
            final volume =
                _selection.volumeLabel(_selection.volumeForBottle(bottle));
            final name = bottle.itemName.trim();
            final namesVolume =
                RegExp(r'\d\s*(мл|ml|л|l)(?![a-zа-я])', caseSensitive: false)
                    .hasMatch(name);
            final replaced = bottle.priceType.toUpperCase() == 'REPLACE';
            final identity = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? volume : name,
                  style: AppTypography.bodyMedium
                      .copyWith(color: context.palette.textPrimary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  [
                    if (name.isNotEmpty && !namesVolume) volume,
                    '${replaced ? 'напиток по тарифу' : 'тара'} ${formatTenge(bottle.price)}',
                    if (!_isOfferedBottle(bottle)) 'снята с продажи',
                  ].join(' · '),
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
              onPlus: canAdd &&
                      _isOfferedBottle(bottle) &&
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
      if (_allocationIssue != null)
        Text(_allocationIssue!,
            style:
                AppTypography.bodySmall.copyWith(color: context.palette.error)),
    ];
  }

  static String _bottlesLabel(int count) {
    final tens = count % 100;
    final ones = count % 10;
    final word = tens >= 11 && tens <= 14
        ? 'бутылок'
        : ones == 1
            ? 'бутылка'
            : ones >= 2 && ones <= 4
                ? 'бутылки'
                : 'бутылок';
    return '$count $word';
  }

  /// The container that carries the bonus litres: the offered size matching them that the
  /// customer already picks most.
  item_model.ItemOptionItem? _bonusBottle(
      CartProvider cart, PromotionEvaluation gift, double available) {
    final extra = gift.bonusQuantity;
    if (extra == null ||
        !_inStock ||
        !_canIncreaseDraft(cart) ||
        !_fitsAvailable(_amount + extra, available)) {
      return null;
    }
    item_model.ItemOptionItem? best;
    for (final bottle in _selection.filteredBottles) {
      if ((_selection.volumeForBottle(bottle) - extra).abs() > 0.000001) {
        continue;
      }
      if (best == null ||
          (_bottleCounts[bottle.relationId] ?? 0) >
              (_bottleCounts[best.relationId] ?? 0)) {
        best = bottle;
      }
    }
    return best;
  }

  /// Litres and bottles above the total and, only at a promotion's threshold,
  /// the one nudge priced by what the extra bottle really costs. A gift that
  /// already exists is told by the struck-through price, nowhere else.
  Widget? _pourSummary(CartProvider cart, double available) {
    if (!_pour || _amount <= 0.0000001) return null;
    final palette = context.palette;
    final gift = _gift;
    final bottles =
        _bottleCounts.values.fold<int>(0, (sum, count) => sum + count);
    final bonus = _bonusBottle(cart, gift, available);
    final cost = bonus == null ? null : _costWithExtraBottle(bonus);
    final volume =
        '${_selection.volumeLabel(_amount)} · ${_bottlesLabel(bottles)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwap(
            stateKey: volume,
            duration: AppMotion.count,
            scale: 1,
            child: Text(
              volume,
              key: const ValueKey('configuration-volume'),
              style:
                  AppTypography.bodyMedium.copyWith(color: palette.textPrimary),
            ),
          ),
          if (bonus != null && cost != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppearIn(
              key: const ValueKey('configuration-bonus-appear'),
              animate: _summaryMayAnimate,
              child: PromotionNudge(
                key: const ValueKey('configuration-bonus'),
                actionKey: const ValueKey('configuration-bonus-add'),
                text: promotionNudgeText(
                  quantityLabel: _selection.volumeLabel(gift.bonusQuantity!),
                  cost: cost,
                  bottled: true,
                ),
                onAdd: () => setState(() {
                  _bottleCounts[bonus.relationId] =
                      (_bottleCounts[bonus.relationId] ?? 0) + 1;
                  _saved = false;
                  _feedback = null;
                }),
              ),
            ),
          ],
        ],
      ),
    );
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

  /// The rule, once, and at the exact threshold the priced nudge. No progress
  /// bar and no «до подарка» countdown: a gift that exists shows in the price.
  Widget _promotionInfo(CartProvider cart, double available) {
    final bonus = _gift.bonusQuantity;
    final canAddFree = bonus != null &&
        (bonus - _step).abs() <= 0.0000001 &&
        _inStock &&
        _canIncreaseDraft(cart) &&
        _fitsAvailable(_quantity + _step, available);
    double? cost;
    if (canAddFree && _price != null) {
      try {
        cost = CartEvaluation(CartDisplayGroup.groupItems(
                [_previewItem(_quantity + _step)])).price.totalPrice -
            _total;
      } on StateError {
        cost = null;
      }
    }
    return AppSurface(
      key: const ValueKey('configuration-promotion'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final promotion
            in widget.item.promotions ?? const <item_model.ItemPromotion>[])
          if (promotion.isActive) ...[
            Text(promotion.name,
                style:
                    AppTypography.title.copyWith(color: context.palette.gold)),
            if (promotion.discountType == 'SUBTRACT' &&
                promotion.baseAmount > 0 &&
                promotion.addAmount > 0)
              Text(
                  promotionRuleText(
                      PromotionAward(
                          promotion: promotion.toJson(),
                          baseAmount: promotion.baseAmount,
                          addAmount: promotion.addAmount),
                      _amountLabel),
                  style: AppTypography.body
                      .copyWith(color: context.palette.textSecondary)),
            if (promotion.description?.trim().isNotEmpty == true)
              Text(promotion.description!,
                  style: AppTypography.body
                      .copyWith(color: context.palette.textSecondary)),
          ],
        if (canAddFree && cost != null) ...[
          const SizedBox(height: AppSpacing.md),
          PromotionNudge(
            key: const ValueKey('configuration-promotion-state'),
            actionKey: const ValueKey('configuration-promotion-add'),
            text: promotionNudgeText(
              quantityLabel: _amountLabel(bonus),
              cost: cost,
              bottled: false,
            ),
            onAdd: () => setState(() {
              _quantity += _step;
              _saved = false;
              _feedback = null;
            }),
          ),
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
              _priceLine('Дополнения', _price!.optionsTotal),
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

  // The dock supplies the 16px sides and the safe-area inset below.
  Widget _footer(
          {required bool enabled,
          required bool removal,
          Widget? pourSummary}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
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
                          color: context.palette.textPrimary,
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
                minimumSize: const Size(154, 49), shape: const StadiumBorder()),
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
                if (!_saved && pourSummary != null) pourSummary,
                if (_saved)
                  AppSurface(
                    radius: AppRadii.pill,
                    fill: context.palette.success,
                    padding: const EdgeInsets.all(14),
                    child: Text('Сохранено в корзине',
                        textAlign: TextAlign.center,
                        style:
                            AppTypography.title.copyWith(color: Colors.black)),
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
          backgroundColor:
              callback == null ? palette.accentFaint : palette.accentSoft,
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
