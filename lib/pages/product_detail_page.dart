import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../globals.dart' as globals;
import '../model/item.dart' as item_model;
import '../models/cart_item.dart';
import '../shared/app_theme.dart';
import '../utils/api.dart';
import '../utils/business_provider.dart';
import '../utils/cart_provider.dart';
import '../utils/item_name_presentation.dart';
import '../utils/liked_items_provider.dart';
import '../utils/liked_storage_service.dart';
import '../utils/responsive.dart';
import '../utils/smart_cart.dart';
import '../utils/subtract_promotion_math.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.item,
    this.initialBaseVariants,
  });

  final item_model.Item item;
  final List<Map<String, dynamic>>? initialBaseVariants;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _SubtractPromoUiState {
  const _SubtractPromoUiState({
    required this.promo,
    required this.amount,
    required this.free,
    required this.toNextGift,
    required this.progress,
    required this.unlocked,
  });

  final item_model.ItemPromotion promo;
  final double amount;
  final double free;
  final double toNextGift;
  final double progress;
  final bool unlocked;
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  static const double _headerWeightPriceQuantityKg = 0.1;

  // ── state ─────────────────────────────────────────────────────
  late final item_model.ItemOption? _containerOption;
  late final List<item_model.ItemOptionItem> _bottleVariants;
  late final List<item_model.ItemOptionItem> _filteredBottles;
  late final List<item_model.ItemOption> _visibleOptions;
  late final ItemTitlePresentation _itemTitle;
  late final List<Map<String, dynamic>> _openedBaseVariants;

  final Map<int, List<item_model.ItemOptionItem>> _selectedOptions = {};
  final Map<int, int> _bottleCounts = {};

  double _manualQuantity = 0;
  bool _descriptionExpanded = false;
  bool _submitting = false;

  // ── like state ──
  bool _likeInProgress = false;
  bool? _isLikedOverride;
  int? _businessId;
  bool _didRestoreCartState = false;
  bool _openedCartSelectionExists = false;
  bool get _isLiked => _isLikedOverride ?? false;

  double get _minBottleVolume {
    if (_filteredBottles.isEmpty) {
      return 0;
    }
    return _filteredBottles.map(_volumeForBottle).reduce(math.min);
  }

  bool get _usesPourFlow => _containerOption != null && _filteredBottles.isNotEmpty && _looksPourProduct();

  // ── promotion helpers ─────────────────────────────────────────

  List<item_model.ItemPromotion> get _activePromotions {
    return (widget.item.promotions ?? const <item_model.ItemPromotion>[]).where((promotion) => promotion.isActive).toList(growable: false);
  }

  List<item_model.ItemPromotion> get _detailPromotions {
    return _activePromotions.where((promotion) => promotion.discountType != 'SUBTRACT').toList(growable: false);
  }

  item_model.ItemPromotion? get _subtractPromo {
    final promos = _activePromotions;
    for (final p in promos) {
      if (p.discountType == 'SUBTRACT' && p.baseAmount > 0 && p.addAmount > 0) {
        return p;
      }
    }
    return null;
  }

  item_model.ItemPromotion? get _discountPromo {
    final promos = _activePromotions;
    for (final p in promos) {
      if (p.discountType == 'PERCENT' && p.discountValue > 0) return p;
      if (p.discountType == 'FIXED' && p.discountValue > 0) return p;
    }
    return null;
  }

  /// How many liters are free thanks to SUBTRACT promo.
  double _freeFromPromo(double quantity) {
    final promo = _subtractPromo;
    if (promo == null) return 0;
    return subtractPromotionFreeQuantityForConfig(
      quantity,
      baseAmount: promo.baseAmount,
      addAmount: promo.addAmount,
    );
  }

  _SubtractPromoUiState? _subtractUiState(double quantity) {
    final promo = _subtractPromo;
    if (promo == null) {
      return null;
    }

    final amount = _normalizeDouble(quantity);
    final free = _normalizeDouble(_freeFromPromo(amount));
    final toNextGift = _normalizeDouble(
      subtractPromotionAmountToNextGift(
        amount,
        baseAmount: promo.baseAmount,
      ),
    );
    final progress = subtractPromotionProgress(
      amount,
      baseAmount: promo.baseAmount,
    );
    final unlocked = subtractPromotionUnlocked(
      amount,
      baseAmount: promo.baseAmount,
    );

    return _SubtractPromoUiState(
      promo: promo,
      amount: amount,
      free: free,
      toNextGift: toNextGift,
      progress: progress,
      unlocked: unlocked,
    );
  }

  int _subtractRewardCount(_SubtractPromoUiState state) {
    final baseAmount = state.promo.baseAmount;
    if (baseAmount <= 0) {
      return 0;
    }
    return (state.amount / baseAmount).floor();
  }

  bool _subtractAtRewardBoundary(_SubtractPromoUiState state) {
    return state.amount > subtractPromotionEpsilon && state.toNextGift <= subtractPromotionEpsilon;
  }

  bool _subtractShowSuccessState(_SubtractPromoUiState state) {
    return _subtractAtRewardBoundary(state) && _subtractRewardCount(state) == 1;
  }

  String? _subtractRewardMultiplierLabel(_SubtractPromoUiState state) {
    final rewardCount = _subtractRewardCount(state);
    if (rewardCount <= 1) {
      return null;
    }
    return 'x$rewardCount';
  }

  double _subtractDisplayProgress(_SubtractPromoUiState state, int segmentCount) {
    if (_subtractAtRewardBoundary(state)) {
      return 0;
    }
    return _subtractCycleProgress(state) * segmentCount;
  }

  String _subtractPromoStatusText(_SubtractPromoUiState state) {
    final baseLabel = _promoAmountLabel(state.promo.baseAmount.toDouble());
    final addLabel = _promoAmountLabel(state.promo.addAmount.toDouble());
    final nextLabel = _subtractNextRewardLabel(state);
    final rewardCount = _subtractRewardCount(state);

    if (state.amount <= subtractPromotionEpsilon) {
      return 'Добавьте $baseLabel и получите +$addLabel';
    }
    if (_subtractAtRewardBoundary(state)) {
      if (rewardCount == 1) {
        return 'Подарок открыт!';
      }
      return 'Добавьте ещё $baseLabel для следующего подарка';
    }
    if (rewardCount > 0) {
      return 'Добавьте ещё $nextLabel для следующего подарка';
    }
    return 'Добавьте ещё $nextLabel для подарка';
  }

  double _subtractCycleProgress(_SubtractPromoUiState state) {
    final baseAmount = state.promo.baseAmount;
    if (baseAmount <= 0 || state.amount <= subtractPromotionEpsilon) {
      return 0;
    }

    final remainder = state.amount % baseAmount;
    if (remainder.abs() <= subtractPromotionEpsilon) {
      return 0;
    }

    return (remainder / baseAmount).clamp(0.0, 1.0);
  }

  String _subtractNextRewardLabel(_SubtractPromoUiState state) {
    final remaining = state.toNextGift <= subtractPromotionEpsilon ? state.promo.baseAmount.toDouble() : state.toNextGift;
    return _promoAmountLabel(remaining);
  }

  // ── lifecycle ─────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _itemTitle = presentItemName(
      rawName: widget.item.name,
      categoryName: widget.item.category?.name,
    );
    _containerOption = _resolveContainerOption();
    _bottleVariants = _resolveBottleVariants();
    _filteredBottles = _filterAllowedBottles();
    _visibleOptions = (widget.item.options ?? const <item_model.ItemOption>[])
        .where((option) => option.optionId != _containerOption?.optionId)
        .toList(growable: false);
    _primeDefaultSelections();
    _openedBaseVariants =
        widget.initialBaseVariants == null ? _currentBaseVariants() : SmartCartSelection.normalizeVariantMaps(widget.initialBaseVariants!);
    _manualQuantity = _initialQuantity();
    for (final bottle in _filteredBottles) {
      _bottleCounts[bottle.relationId] = 0;
    }
    if (_filteredBottles.isNotEmpty) {
      final initial = _defaultBottleCounts();
      for (final bottle in _filteredBottles) {
        _bottleCounts[bottle.relationId] = initial[bottle.relationId] ?? 0;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didRestoreCartState) {
      _didRestoreCartState = true;
      _restoreCartState(context.read<CartProvider>());
    }
    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final bid = businessProvider.selectedBusinessId;
    if (bid != null && bid != _businessId) {
      _businessId = bid;
      _initLikeState(bid);
    }
  }

  Future<void> _initLikeState(int businessId) async {
    final likedProvider = Provider.of<LikedItemsProvider>(context, listen: false);
    final providerLiked = likedProvider.isLiked(businessId, widget.item.itemId);
    if (providerLiked) {
      _isLikedOverride = true;
      if (mounted) setState(() {});
      return;
    }
    final liked = await LikedStorageService.isLiked(
      businessId: businessId,
      itemId: widget.item.itemId,
    );
    if (mounted) {
      setState(() => _isLikedOverride = liked);
      if (liked) {
        likedProvider.updateLike(businessId, widget.item.itemId, true);
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_likeInProgress) return;
    setState(() => _likeInProgress = true);
    final likedProvider = Provider.of<LikedItemsProvider>(context, listen: false);
    try {
      final newValue = await ApiService.toggleLikeItem(widget.item.itemId);
      if (newValue != null && mounted) {
        setState(() => _isLikedOverride = newValue);
        if (_businessId != null) {
          LikedStorageService.setLiked(
            businessId: _businessId!,
            itemId: widget.item.itemId,
            liked: newValue,
          );
          likedProvider.updateLike(_businessId!, widget.item.itemId, newValue);
        }
      }
    } finally {
      if (mounted) setState(() => _likeInProgress = false);
    }
  }

  // ── business logic ────────────────────────────────────────────

  double _initialQuantity() {
    final step = widget.item.effectiveStepQuantity;
    if (widget.item.amount != null && widget.item.amount! > 0) {
      return math.min(step, widget.item.amount!.toDouble());
    }
    return step;
  }

  void _restoreCartState(CartProvider cart) {
    final group = _findCartGroup(cart, _openedBaseVariants);
    if (group == null) {
      return;
    }

    _openedCartSelectionExists = true;
    _applyBaseVariants(group.baseVariants);

    if (_usesPourFlow) {
      final restoredCounts = group.bottleCounts.isNotEmpty ? group.bottleCounts : _autoBottleBreakdown(group.totalQuantity);
      for (final bottle in _filteredBottles) {
        _bottleCounts[bottle.relationId] = restoredCounts[bottle.relationId] ?? 0;
      }
      return;
    }

    _manualQuantity = _normalizeDouble(group.totalQuantity);
  }

  void _applyBaseVariants(List<Map<String, dynamic>> baseVariants) {
    final relationIds = baseVariants.map(SmartCartSelection.variantRelationId).whereType<int>().toSet();

    _selectedOptions.clear();
    for (final option in _visibleOptions) {
      if (option.optionItems.isEmpty) {
        continue;
      }
      final matches = option.optionItems.where((optionItem) => relationIds.contains(optionItem.relationId)).toList(growable: false);
      if (matches.isNotEmpty) {
        _selectedOptions[option.optionId] = matches;
        continue;
      }
      if (option.required == 1 || option.optionItems.length == 1) {
        _selectedOptions[option.optionId] = <item_model.ItemOptionItem>[
          option.optionItems.first,
        ];
      }
    }
  }

  CartDisplayGroup? _findCartGroup(
    CartProvider cart,
    List<Map<String, dynamic>> baseVariants,
  ) {
    final displayKey = _displayKeyForBaseVariants(baseVariants);
    for (final group in cart.displayGroups) {
      if (group.key == displayKey) {
        return group;
      }
    }
    return null;
  }

  String _displayKeyForBaseVariants(List<Map<String, dynamic>> baseVariants) {
    final normalized = SmartCartSelection.normalizeVariantMaps(baseVariants);
    final keys = normalized.map(SmartCartSelection.variantStableKey).toList(growable: false)..sort();
    return '${widget.item.itemId}|${keys.join(';')}';
  }

  List<Map<String, dynamic>> _currentBaseVariants() {
    return SmartCartSelection.normalizeVariantMaps(_selectedVariantMaps());
  }

  bool _sameBaseVariants(
    List<Map<String, dynamic>> left,
    List<Map<String, dynamic>> right,
  ) {
    return _displayKeyForBaseVariants(left) == _displayKeyForBaseVariants(right);
  }

  List<item_model.ItemOptionItem> _filterAllowedBottles() {
    const allowed = <double>[1.0, 2.0, 3.0];
    return _bottleVariants.where((bottle) {
      final v = _volumeForBottle(bottle);
      return allowed.any((a) => (v - a).abs() < 0.05);
    }).toList();
  }

  double _totalLitersFromBottles() {
    var total = 0.0;
    for (final bottle in _filteredBottles) {
      final count = _bottleCounts[bottle.relationId] ?? 0;
      if (count > 0) {
        total += _volumeForBottle(bottle) * count;
      }
    }
    return _normalizeDouble(total);
  }

  void _primeDefaultSelections() {
    for (final option in _visibleOptions) {
      if (option.optionItems.isEmpty) {
        continue;
      }
      if (option.required == 1 || option.optionItems.length == 1) {
        _selectedOptions[option.optionId] = <item_model.ItemOptionItem>[
          option.optionItems.first,
        ];
      }
    }
  }

  item_model.ItemOption? _resolveContainerOption() {
    for (final option in widget.item.options ?? const <item_model.ItemOption>[]) {
      if (option.optionItems.isEmpty) {
        continue;
      }
      final matched = option.optionItems.where((item) => _extractVolumeFromText(item) > 0 || item.parentItemAmount > 0).length;
      if (matched == option.optionItems.length) {
        return option;
      }
    }
    return null;
  }

  List<item_model.ItemOptionItem> _resolveBottleVariants() {
    final option = _containerOption;
    if (option == null) {
      return const <item_model.ItemOptionItem>[];
    }
    final items = option.optionItems.where((item) => _volumeForBottle(item) > 0).toList();
    items.sort((left, right) => _volumeForBottle(left).compareTo(_volumeForBottle(right)));
    return items;
  }

  bool _looksPourProduct() {
    final haystack = '${widget.item.name} ${widget.item.category?.name ?? ''}'.toLowerCase();
    const keywords = <String>[
      'пиво',
      'beer',
      'разлив',
      'lager',
      'ipa',
      'stout',
      'эль',
      'сидр',
    ];
    if (keywords.any(haystack.contains)) {
      return true;
    }
    if (_bottleVariants.length >= 2) {
      return true;
    }
    return false;
  }

  double _extractVolumeFromText(item_model.ItemOptionItem item) {
    final raw = item.itemName.toLowerCase().replaceAll(',', '.');
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*(л|l|ml|мл)').firstMatch(raw);
    if (match == null) {
      return 0;
    }
    final value = double.tryParse(match.group(1) ?? '');
    if (value == null || value <= 0) {
      return 0;
    }
    final unit = match.group(2);
    if (unit == 'ml' || unit == 'мл') {
      return value / 1000;
    }
    return value;
  }

  double _volumeForBottle(item_model.ItemOptionItem item) {
    final parentAmount = item.parentItemAmount;
    if (parentAmount > 0 && parentAmount <= 20) {
      return parentAmount;
    }
    final parsed = _extractVolumeFromText(item);
    if (parsed > 0) {
      return parsed;
    }
    return widget.item.effectiveStepQuantity > 0 ? widget.item.effectiveStepQuantity : 1.0;
  }

  double _maxAmount() {
    final amount = widget.item.amount?.toDouble();
    if (amount == null || amount <= 0) {
      return double.infinity;
    }
    return amount;
  }

  String _money(double value) {
    final rounded = value.roundToDouble();
    final text = rounded == value ? rounded.toStringAsFixed(0) : value.toStringAsFixed(2);
    return '$text ₸';
  }

  bool _shouldShowFixedWeightPriceUnderImage() {
    if (_usesPourFlow) {
      return false;
    }

    final normalizedUnit = widget.item.unit?.toLowerCase().replaceAll('.', '').trim();
    if (normalizedUnit != null && normalizedUnit.isNotEmpty) {
      if (normalizedUnit.contains('кг') || normalizedUnit.contains('kg')) {
        return true;
      }
      if (normalizedUnit.contains('шт') ||
          normalizedUnit.contains('pcs') ||
          normalizedUnit.contains('л') ||
          normalizedUnit.contains('ml') ||
          normalizedUnit.contains('мл')) {
        return false;
      }
    }

    final quantity = widget.item.quantity;
    if (quantity != null && quantity > 0 && quantity < 1 && (quantity - 1).abs() > 0.001) {
      return true;
    }

    final step = widget.item.effectiveStepQuantity;
    return step > 0 && step < 1 && _quantityUnit().toLowerCase().contains('кг');
  }

  double _priceUnderImage(double price) {
    if (!_shouldShowFixedWeightPriceUnderImage()) {
      return price;
    }
    return _normalizeDouble(price * _headerWeightPriceQuantityKg);
  }

  String _volumeLabel(double value) {
    if ((value - value.roundToDouble()).abs() < 0.001) {
      return '${value.toStringAsFixed(0)} л';
    }
    if ((value * 10 - (value * 10).roundToDouble()).abs() < 0.001) {
      return '${value.toStringAsFixed(1)} л';
    }
    return '${value.toStringAsFixed(2)} л';
  }

  String _quantityLabel(double quantity) {
    return globals.formatQuantity(quantity, _quantityUnit());
  }

  String _quantityUnit() {
    final itemUnit = widget.item.unit?.trim();
    if (itemUnit != null && itemUnit.isNotEmpty) {
      return itemUnit;
    }
    if (widget.item.effectiveStepQuantity < 1) {
      return 'кг';
    }
    return 'шт.';
  }

  void _adjustQuantity(int direction) {
    final step = widget.item.effectiveStepQuantity <= 0 ? 1.0 : widget.item.effectiveStepQuantity;
    final next = (_manualQuantity + step * direction).clamp(step, _maxAmount());
    setState(() {
      _manualQuantity = _normalizeDouble(next);
    });
  }

  double _normalizeDouble(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  Map<int, int> _defaultBottleCounts() {
    final maxAmount = _maxAmount();
    for (final bottle in _filteredBottles) {
      final volume = _volumeForBottle(bottle);
      if (volume <= maxAmount + 0.001) {
        return <int, int>{bottle.relationId: 1};
      }
    }
    return const <int, int>{};
  }

  double _litersForCounts(Map<int, int> counts) {
    var total = 0.0;
    for (final bottle in _filteredBottles) {
      final count = counts[bottle.relationId] ?? 0;
      if (count > 0) {
        total += _volumeForBottle(bottle) * count;
      }
    }
    return _normalizeDouble(total);
  }

  void _adjustLiters(int direction) {
    final current = _totalLitersFromBottles();
    final breakdown = _nextBottleBreakdown(direction);
    final next = _litersForCounts(breakdown);
    if ((next - current).abs() < 0.001) return;
    setState(() {
      for (final bottle in _filteredBottles) {
        _bottleCounts[bottle.relationId] = breakdown[bottle.relationId] ?? 0;
      }
    });
  }

  Map<int, int> _nextBottleBreakdown(int direction) {
    if (_filteredBottles.isEmpty) {
      return const <int, int>{};
    }

    final current = _totalLitersFromBottles();
    final maxAmount = _maxAmount();
    if (maxAmount < _minBottleVolume - 0.001) {
      return const <int, int>{};
    }

    if (current <= 0.001 && direction > 0) {
      return _defaultBottleCounts();
    }

    final lowerBound = current > 0.001 ? _minBottleVolume : 0.0;
    final target = _normalizeDouble((current + direction).clamp(lowerBound, maxAmount));
    return _autoBottleBreakdown(target);
  }

  bool _canAdjustLiters(int direction) {
    final current = _totalLitersFromBottles();
    final next = _litersForCounts(_nextBottleBreakdown(direction));
    if (direction > 0) {
      return next > current + 0.001;
    }
    return next < current - 0.001;
  }

  String _discountBadgeLabel(item_model.ItemPromotion promo) {
    final percent = promo.calculateEffectiveDiscountPercent(widget.item.price);
    if (percent > 0) {
      return '-$percent%';
    }
    return '-${_money(promo.discountValue)}';
  }

  Map<int, int> _autoBottleBreakdown(double targetLiters) {
    final target = (targetLiters * 100).round();
    if (target <= 0 || _filteredBottles.isEmpty) {
      return const <int, int>{};
    }

    final volumes = _filteredBottles.map((item) => (_volumeForBottle(item) * 100).round()).toList(growable: false);
    final best = List<int>.filled(target + 1, 1 << 30);
    final prevAmount = List<int>.filled(target + 1, -1);
    final prevIndex = List<int>.filled(target + 1, -1);
    best[0] = 0;

    for (var amount = 1; amount <= target; amount++) {
      for (var index = 0; index < volumes.length; index++) {
        final volume = volumes[index];
        if (amount >= volume && best[amount - volume] + 1 < best[amount]) {
          best[amount] = best[amount - volume] + 1;
          prevAmount[amount] = amount - volume;
          prevIndex[amount] = index;
        }
      }
    }

    if (prevIndex[target] == -1) {
      return _greedyBottleBreakdown(targetLiters);
    }

    final result = <int, int>{};
    var cursor = target;
    while (cursor > 0 && prevIndex[cursor] != -1) {
      final index = prevIndex[cursor];
      final bottle = _filteredBottles[index];
      result[bottle.relationId] = (result[bottle.relationId] ?? 0) + 1;
      cursor = prevAmount[cursor];
    }
    return result;
  }

  Map<int, int> _greedyBottleBreakdown(double targetLiters) {
    var remaining = targetLiters;
    final result = <int, int>{};
    final sorted = _filteredBottles.toList()..sort((left, right) => _volumeForBottle(right).compareTo(_volumeForBottle(left)));
    for (final bottle in sorted) {
      final volume = _volumeForBottle(bottle);
      if (volume <= 0) {
        continue;
      }
      final count = (remaining / volume).floor();
      if (count > 0) {
        result[bottle.relationId] = count;
        remaining = _normalizeDouble(remaining - volume * count);
      }
    }
    if (result.isEmpty && sorted.isNotEmpty) {
      final smallest = sorted.last;
      if (_volumeForBottle(smallest) <= _maxAmount() + 0.001) {
        result[smallest.relationId] = 1;
      }
    }
    return result;
  }

  Map<int, int> _activeBottleCounts() {
    return Map<int, int>.fromEntries(
      _bottleCounts.entries.where((entry) => entry.value > 0),
    );
  }

  double _configuredAmount() {
    if (_usesPourFlow) {
      return _totalLitersFromBottles();
    }
    return _manualQuantity;
  }

  String _activeBottleDetailLabel() {
    return _activeBottleCounts().entries.map((entry) {
      final bottle = _filteredBottles.firstWhere((item) => item.relationId == entry.key);
      return '${entry.value}×${_volumeLabel(_volumeForBottle(bottle))}';
    }).join(' · ');
  }

  String _priceBreakdownBaseLabel(double amount) {
    if (_usesPourFlow) {
      return '${_volumeLabel(amount)} напитка';
    }
    return _quantityLabel(amount);
  }

  List<item_model.ItemOptionItem> _selectedItemsFor(item_model.ItemOption option) {
    return _selectedOptions[option.optionId] ?? const <item_model.ItemOptionItem>[];
  }

  void _toggleOption(item_model.ItemOption option, item_model.ItemOptionItem optionItem) {
    final current = List<item_model.ItemOptionItem>.from(_selectedOptions[option.optionId] ?? const <item_model.ItemOptionItem>[]);
    final isSelected = current.any((item) => item.relationId == optionItem.relationId);

    setState(() {
      if (option.selection.toUpperCase() == 'MULTIPLE') {
        if (isSelected) {
          current.removeWhere((item) => item.relationId == optionItem.relationId);
        } else {
          current.add(optionItem);
        }
      } else {
        current
          ..clear()
          ..add(optionItem);
      }

      if (current.isEmpty) {
        _selectedOptions.remove(option.optionId);
      } else {
        _selectedOptions[option.optionId] = current;
      }
    });
  }

  List<item_model.ItemOption> _missingRequiredOptions() {
    return _visibleOptions.where((option) => option.required == 1 && (_selectedOptions[option.optionId]?.isNotEmpty != true)).toList(growable: false);
  }

  List<Map<String, dynamic>> _selectedVariantMaps({
    bool includeBottle = false,
    item_model.ItemOptionItem? bottle,
  }) {
    final result = <Map<String, dynamic>>[];
    if (includeBottle && bottle != null) {
      result.add(_variantMap(bottle, required: _containerOption?.required ?? 0));
    }
    for (final option in _visibleOptions) {
      final items = _selectedOptions[option.optionId] ?? const <item_model.ItemOptionItem>[];
      for (final optionItem in items) {
        result.add(_variantMap(optionItem, required: option.required));
      }
    }
    return result;
  }

  Map<String, dynamic> _variantMap(item_model.ItemOptionItem optionItem, {required int required}) {
    return <String, dynamic>{
      'variant_id': optionItem.relationId,
      'relation_id': optionItem.relationId,
      'item_id': optionItem.itemId,
      'item_name': optionItem.itemName,
      'price_type': optionItem.priceType,
      'price': optionItem.price,
      'parent_item_amount': optionItem.parentItemAmount > 0 ? optionItem.parentItemAmount : _volumeForBottle(optionItem),
      'required': required,
    };
  }

  List<Map<String, dynamic>> _promotionMaps() {
    return _activePromotions
        .map(
          (promotion) => <String, dynamic>{
            'promotion_id': promotion.promotionId,
            'name': promotion.name,
            'description': promotion.description,
            'discount_type': promotion.discountType,
            'discount_value': promotion.discountValue,
            'base_amount': promotion.baseAmount,
            'add_amount': promotion.addAmount,
          },
        )
        .toList(growable: false);
  }

  CartItem _previewCartItem({
    required double quantity,
    item_model.ItemOptionItem? bottle,
    bool includePromotions = true,
  }) {
    return CartItem(
      itemId: widget.item.itemId,
      name: _itemTitle.name,
      price: widget.item.price,
      quantity: quantity,
      stepQuantity: bottle != null ? _volumeForBottle(bottle) : widget.item.effectiveStepQuantity,
      image: widget.item.image,
      itemType: _itemTitle.type,
      packagingType: _itemTitle.packagingType,
      selectedVariants: _selectedVariantMaps(includeBottle: bottle != null, bottle: bottle),
      promotions: includePromotions ? _promotionMaps() : const <Map<String, dynamic>>[],
      itemData: widget.item.toJson(),
      maxAmount: widget.item.amount?.toDouble(),
    );
  }

  double _pourFlowOptionsTotal() {
    final counts = _activeBottleCounts();
    if (counts.isEmpty) {
      return 0;
    }

    var total = 0.0;
    for (final entry in counts.entries) {
      if (entry.value <= 0) continue;
      final bottle = _filteredBottles.firstWhere((item) => item.relationId == entry.key);
      final quantity = _volumeForBottle(bottle) * entry.value;
      total += _previewCartItem(
        quantity: quantity,
        bottle: bottle,
        includePromotions: false,
      ).optionsTotal;
    }

    return total;
  }

  double _applyPromotionsToBaseTotal(double quantity) {
    return applyPromotionsToPaidBaseTotal(
      unitPrice: widget.item.price,
      quantity: quantity,
      promotions: _promotionMaps(),
    );
  }

  double _previewSubtotalBeforePromotions() {
    if (_usesPourFlow) {
      final totalLiters = _totalLitersFromBottles();
      final optionsTotal = _pourFlowOptionsTotal();
      final rawBase = subtractPromotionDisplayBaseTotal(widget.item.price, totalLiters, _promotionMaps());
      return rawBase + optionsTotal;
    }

    return _previewCartItem(
      quantity: _manualQuantity,
      includePromotions: true,
    ).subtotalBeforePromotions;
  }

  double _previewTotal({bool includePromotions = true}) {
    if (_usesPourFlow) {
      final counts = _activeBottleCounts();
      if (counts.isEmpty) {
        return 0;
      }

      final totalLiters = _totalLitersFromBottles();
      final optionsTotal = _pourFlowOptionsTotal();
      final baseTotal = widget.item.price * totalLiters;
      final promotedBase = includePromotions ? _applyPromotionsToBaseTotal(totalLiters) : baseTotal;
      return promotedBase + optionsTotal;
    }

    return _previewCartItem(
      quantity: _manualQuantity,
      includePromotions: includePromotions,
    ).totalPrice;
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final missing = _missingRequiredOptions();
    if (missing.isNotEmpty) {
      await AppDialogs.showMessage(
        context,
        title: 'Еще немного',
        message: missing.map((option) => option.name).join(', '),
      );
      return;
    }

    final cart = context.read<CartProvider>();
    final currentBaseVariants = _currentBaseVariants();
    final currentSelectionExists = _findCartGroup(cart, currentBaseVariants) != null;
    final shouldReplaceSelection = _openedCartSelectionExists || currentSelectionExists;

    setState(() {
      _submitting = true;
    });

    try {
      var added = false;

      if (_usesPourFlow) {
        final counts = _activeBottleCounts();
        if (counts.isEmpty) {
          await AppDialogs.showMessage(
            context,
            title: 'Выберите объем',
            message: 'Добавьте нужный объем перед заказом.',
          );
          return;
        }

        if (shouldReplaceSelection && !_sameBaseVariants(_openedBaseVariants, currentBaseVariants)) {
          cart.syncItemBottleCounts(
            widget.item,
            _openedBaseVariants,
            const <int, int>{},
          );
        }

        cart.syncItemBottleCounts(widget.item, currentBaseVariants, counts);
        added = counts.values.any((count) => count > 0);
      } else if (widget.item.hasOptions) {
        if (shouldReplaceSelection && !_sameBaseVariants(_openedBaseVariants, currentBaseVariants)) {
          cart.syncItemSelectionQuantity(
            widget.item,
            _openedBaseVariants,
            0,
          );
        }
        cart.syncItemSelectionQuantity(
          widget.item,
          currentBaseVariants,
          _manualQuantity,
        );
        added = _manualQuantity > 0;
      } else {
        cart.syncItemSelectionQuantity(
          widget.item,
          const <Map<String, dynamic>>[],
          _manualQuantity,
        );
        added = _manualQuantity > 0;
      }

      if (!mounted) {
        return;
      }

      if (added) {
        setState(() => _submitting = false);
        // Brief success flash before popping
        final overlay = Overlay.of(context);
        final entry = OverlayEntry(
          builder: (_) => Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 80.s,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 12.s),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A8C3E),
                    borderRadius: BorderRadius.circular(12.s),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 18.s),
                      SizedBox(width: 8.s),
                      Text(
                        'Добавлено в корзину',
                        style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        overlay.insert(entry);
        await Future<void>.delayed(const Duration(milliseconds: 600));
        entry.remove();
        if (mounted) Navigator.of(context).pop();
        return;
      }

      await AppDialogs.showMessage(context, title: 'Не получилось', message: 'Попробуйте еще раз.');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _shortBottleName(item_model.ItemOptionItem bottle) {
    final volume = _volumeForBottle(bottle);
    return bottle.itemName.trim().isNotEmpty ? bottle.itemName.trim() : _volumeLabel(volume);
  }

  // ════════════════════════════════════════════════════════════════
  //  UI
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final total = _previewTotal();
    final rawTotal = _previewSubtotalBeforePromotions();
    final amount = _configuredAmount();
    final subtractState = _subtractUiState(amount);
    final footerHeight = 96.s + pad.bottom;
    final footerReserve = 116.s + pad.bottom;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          // ─ scrollable content ─
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _imageArea(pad)),
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.bgDeep,
                  padding: EdgeInsets.fromLTRB(18.s, 20.s, 18.s, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _productInfo(),
                      if (subtractState != null) ...[
                        SizedBox(height: 14.s),
                        _subtractPriceSignalCard(subtractState),
                      ],
                      SizedBox(height: 18.s),
                      _thinDivider(),
                      SizedBox(height: 18.s),
                      if (_usesPourFlow) ...[
                        _pourControls(),
                        SizedBox(height: 18.s),
                      ],
                      if (!_usesPourFlow) ...[
                        _quantityControl(),
                        SizedBox(height: 18.s),
                      ],
                      if (_visibleOptions.isNotEmpty) ...[
                        _thinDivider(),
                        SizedBox(height: 18.s),
                        _optionsBlock(),
                        SizedBox(height: 18.s),
                      ],
                      if (_detailPromotions.isNotEmpty) ...[
                        _thinDivider(),
                        SizedBox(height: 18.s),
                        _promoBlock(),
                        SizedBox(height: 18.s),
                      ],
                      if ((widget.item.description ?? '').trim().isNotEmpty) ...[
                        _thinDivider(),
                        SizedBox(height: 18.s),
                        _descriptionBlock(),
                        SizedBox(height: 18.s),
                      ],
                      SizedBox(height: footerReserve),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ─ back button ─
          Positioned(
            top: pad.top + 10.s,
            left: 14.s,
            child: _circleBtn(
              Icons.arrow_back_ios_new_rounded,
              () => Navigator.maybePop(context),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: footerHeight - 1.s,
            child: IgnorePointer(
              child: SizedBox(
                height: 30.s,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF1A1A1A).withValues(alpha: 0),
                        const Color(0xFF1A1A1A).withValues(alpha: 0.92),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─ bottom bar ─
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _bottomBar(total, rawTotal, amount, pad),
          ),
        ],
      ),
    );
  }

  // ── image area ────────────────────────────────────────────────

  Widget _imageArea(EdgeInsets pad) {
    final hasImage = (widget.item.image ?? '').trim().isNotEmpty;
    final discount = _discountPromo;

    return Stack(
      children: [
        SizedBox(
          height: 304.s + pad.top,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: hasImage ? Colors.white : AppColors.cardDark,
            ),
            child: Stack(
              children: [
                if (!hasImage)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.08),
                          radius: 0.92,
                          colors: [
                            AppColors.blue.withValues(alpha: 0.34),
                            AppColors.cardDark,
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(18.s, pad.top + 22.s, 18.s, 18.s),
                    child: hasImage
                        ? ClipRect(
                            child: Transform.scale(
                              scale: 1.08,
                              child: Image.network(
                                widget.item.image!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (_, __, ___) => _placeholder(),
                              ),
                            ),
                          )
                        : _placeholder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (discount != null)
          Positioned(
            top: pad.top + 58.s,
            left: 18.s,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 6.s),
              decoration: BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.circular(10.s),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department_rounded, size: 13.s, color: Colors.white),
                  SizedBox(width: 5.s),
                  Text(
                    _discountBadgeLabel(discount),
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          top: pad.top + 10.s,
          right: 14.s,
          child: _favoriteAction(),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return const Icon(Icons.inventory_2_outlined, color: AppColors.textMute, size: 58);
  }

  // ── product info ──────────────────────────────────────────────
  Widget _productInfo() {
    final identityColor = Color.lerp(AppColors.textMute, AppColors.text, 0.12)!;
    final identityParts = <String>[
      if (_itemTitle.type != null && _itemTitle.type!.trim().isNotEmpty) _itemTitle.type!,
      if (_itemTitle.packagingType != null && _itemTitle.packagingType!.trim().isNotEmpty) _itemTitle.packagingType!,
      if (_itemTitle.countryName != null && _itemTitle.countryName!.trim().isNotEmpty) _itemTitle.countryName!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (identityParts.isNotEmpty) ...[
          Text(
            identityParts.join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: identityColor,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              height: 1.2,
            ),
          ),
          SizedBox(height: 8.s),
        ],
        Text(
          _itemTitle.name,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        SizedBox(height: 12.s),
        ..._priceDisplay(),
        SizedBox(height: 10.s),
        _supportingInfoRow(),
      ],
    );
  }

  Widget _supportingInfoRow() {
    final hasStock = widget.item.amount != null && widget.item.amount! > 0;

    if (!hasStock) {
      return const SizedBox.shrink();
    }

    return _stockIndicator(widget.item.amount!);
  }

  Widget _favoriteAction() {
    return GestureDetector(
      onTap: _toggleLike,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 42.s,
        height: 42.s,
        decoration: BoxDecoration(
          color: _isLiked ? AppColors.red : AppColors.card.withValues(alpha: 0.88),
          shape: BoxShape.circle,
          border: Border.all(
            color: _isLiked ? AppColors.red : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _likeInProgress
            ? Padding(
                padding: EdgeInsets.all(12.s),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _isLiked ? Colors.white : AppColors.red,
                ),
              )
            : Icon(
                _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 18.s,
                color: _isLiked ? Colors.white : AppColors.red,
              ),
      ),
    );
  }

  Widget _priceMetaRow(List<String> facts) {
    if (facts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 14.s,
      runSpacing: 6.s,
      children: facts
          .map(
            (fact) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _pricingFactIcon(fact),
                  size: 13.s,
                  color: AppColors.textMute,
                ),
                SizedBox(width: 6.s),
                Text(
                  fact,
                  style: TextStyle(
                    color: AppColors.textMute,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )
          .toList(growable: false),
    );
  }

  IconData _pricingFactIcon(String fact) {
    if (fact.contains('%')) {
      return Icons.bolt_rounded;
    }
    return Icons.local_drink_outlined;
  }

  Widget _primaryPriceText(double price) {
    return Text(
      _money(price),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.orange,
        fontSize: 25.sp,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  List<String> _priceFacts() {
    final facts = <String>[];
    final volume = _itemTitle.volumeLabel ?? _fallbackVolumeLabel();
    final alcohol = _itemTitle.alcoholLabel ?? _fallbackAlcoholLabel();

    if (volume != null) {
      facts.add(volume);
    }
    if (alcohol != null) {
      facts.add(alcohol);
    }

    return facts;
  }

  String? _fallbackVolumeLabel() {
    if (_usesPourFlow && widget.item.effectiveStepQuantity > 0) {
      return _volumeLabel(widget.item.effectiveStepQuantity);
    }
    return null;
  }

  String? _fallbackAlcoholLabel() {
    final normalizedName = widget.item.name.replaceAll(',', '.');
    final match = RegExp(r'(\d{1,2}(?:\.\d{1,2})?)\s*%').firstMatch(normalizedName);
    final raw = match?.group(1);
    final value = raw == null ? null : double.tryParse(raw);
    if (value == null) {
      return null;
    }
    return '${_compactMetricLabel(value)}%';
  }

  String _compactMetricLabel(double value) {
    if ((value - value.roundToDouble()).abs() < 0.001) {
      return value.toStringAsFixed(0);
    }
    if ((value * 10 - (value * 10).roundToDouble()).abs() < 0.001) {
      return value.toStringAsFixed(1);
    }
    return value.toStringAsFixed(2);
  }

  // ── price display with discount ────────────────────────────

  List<Widget> _priceDisplay() {
    final promo = _discountPromo;
    final facts = _priceFacts();
    final basePrice = _priceUnderImage(widget.item.price);

    if (promo != null) {
      final discounted = _priceUnderImage(promo.calculateDiscountedPrice(widget.item.price));
      final savings = _priceUnderImage(promo.calculateSavings(widget.item.price));
      return [
        Text(
          _money(basePrice),
          style: TextStyle(
            color: AppColors.textMute.withValues(alpha: 0.5),
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.lineThrough,
            decorationColor: AppColors.textMute.withValues(alpha: 0.5),
          ),
        ),
        SizedBox(height: 4.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _primaryPriceText(discounted),
            ),
            SizedBox(width: 12.s),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9.s, vertical: 5.s),
              decoration: BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.circular(999.s),
              ),
              child: Text(
                _discountBadgeLabel(promo),
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (facts.isNotEmpty) ...[
          SizedBox(height: 10.s),
          _priceMetaRow(facts),
        ],
        if (savings >= 1) ...[
          SizedBox(height: 4.s),
          Text(
            'Выгода ${_money(savings)}',
            style: TextStyle(
              color: AppColors.orange,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ];
    }

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _primaryPriceText(basePrice),
          ),
        ],
      ),
      if (facts.isNotEmpty) ...[
        SizedBox(height: 10.s),
        _priceMetaRow(facts),
      ],
    ];
  }

  Widget _subtractPriceSignalCard(_SubtractPromoUiState state) {
    final rewardCount = _subtractRewardCount(state);
    final segmentCount = math.max(1, math.min(state.promo.baseAmount, 6));
    final segmentFill = _subtractDisplayProgress(state, segmentCount);
    final statusText = _subtractPromoStatusText(state);
    final rewardUnlocked = rewardCount > 0;
    final showSuccessState = _subtractShowSuccessState(state);
    final rewardMultiplier = _subtractRewardMultiplierLabel(state);
    const progressFill = Color(0xFF5E8A76);
    const rewardAccent = AppColors.orange;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 12.s),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14.s),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${state.promo.baseAmount}+${state.promo.addAmount}',
                style: TextStyle(color: AppColors.orange, fontSize: 15.sp, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 30.s,
                    height: 30.s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: rewardUnlocked ? rewardAccent.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: rewardUnlocked ? rewardAccent.withValues(alpha: 0.24) : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Icon(
                      Icons.card_giftcard_rounded,
                      size: 16.s,
                      color: rewardUnlocked ? rewardAccent : AppColors.textMute,
                    ),
                  ),
                  if (rewardMultiplier != null)
                    Positioned(
                      right: -8.s,
                      top: -5.s,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 5.s, vertical: 2.s),
                        decoration: BoxDecoration(
                          color: rewardAccent,
                          borderRadius: BorderRadius.circular(999.s),
                        ),
                        child: Text(
                          rewardMultiplier,
                          style: TextStyle(color: Colors.black, fontSize: 8.sp, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.s),
          Text(
            statusText,
            style: TextStyle(
              color: showSuccessState ? rewardAccent : AppColors.text,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10.s),
          Row(
            children: List.generate(segmentCount, (index) {
              final fill = (segmentFill - index).clamp(0.0, 1.0).toDouble();
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == segmentCount - 1 ? 0 : 6.s),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999.s),
                    child: Stack(
                      children: [
                        Container(
                          height: 8.s,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: fill,
                          child: Container(
                            height: 8.s,
                            color: progressFill,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── stock indicator ────────────────────────────────────────

  Widget _stockIndicator(num amount) {
    final String label;
    final Color color;
    final bool urgent;

    if (amount <= 2) {
      label = 'Заканчивается';
      color = AppColors.red;
      urgent = true;
    } else if (amount <= 5) {
      label = 'Мало';
      color = const Color(0xFFE8913A);
      urgent = false;
    } else if (amount <= 15) {
      label = 'В наличии';
      color = AppColors.textMute;
      urgent = false;
    } else {
      label = 'Много';
      color = const Color(0xFF5BAE6E);
      urgent = false;
    }

    if (urgent) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8.s, vertical: 3.s),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6.s),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6.s,
              height: 6.s,
              decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
            ),
            SizedBox(width: 5.s),
            Text(
              label,
              style: TextStyle(color: AppColors.red, fontSize: 11.sp, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7.s,
          height: 7.s,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6.s),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 12.sp, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ── pour controls (compact + bottom sheet) ───────────────────

  Widget _pourControls() {
    final liters = _totalLitersFromBottles();
    final free = _freeFromPromo(liters);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionLabel('Объём'),
            const Spacer(),
            _bottleSummaryBtn(),
          ],
        ),
        SizedBox(height: 10.s),
        _stepper(
          value: _volumeLabel(liters),
          canDec: _canAdjustLiters(-1),
          canInc: _canAdjustLiters(1),
          onDec: () => _adjustLiters(-1),
          onInc: () => _adjustLiters(1),
        ),
        if (free > 0) ...[
          SizedBox(height: 8.s),
          Row(
            children: [
              Icon(Icons.card_giftcard_rounded, size: 15.s, color: AppColors.orange),
              SizedBox(width: 6.s),
              Text(
                '+${_volumeLabel(free)} в подарок',
                style: TextStyle(
                  color: AppColors.orange,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _bottleSummaryBtn() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999.s),
        onTap: _openBottleSheet,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.s, vertical: 4.s),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings_outlined, color: AppColors.orange, size: 15.s),
              SizedBox(width: 6.s),
              Text(
                'Тара',
                style: TextStyle(color: AppColors.orange, fontSize: 12.sp, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openBottleSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BottleSheet(
        bottles: _filteredBottles,
        counts: Map<int, int>.of(_bottleCounts),
        volumeForBottle: _volumeForBottle,
        volumeLabel: _volumeLabel,
        shortName: _shortBottleName,
        maxAmount: _maxAmount(),
        onApply: (newCounts) {
          setState(() {
            for (final bottle in _filteredBottles) {
              _bottleCounts[bottle.relationId] = newCounts[bottle.relationId] ?? 0;
            }
          });
        },
      ),
    );
  }

  // ── quantity ───────────────────────────────────────────────────

  Widget _quantityControl() {
    final step = widget.item.effectiveStepQuantity <= 0 ? 1.0 : widget.item.effectiveStepQuantity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Количество'),
        SizedBox(height: 12.s),
        _stepper(
          value: _quantityLabel(_manualQuantity),
          canDec: _manualQuantity > step + 0.001,
          canInc: _manualQuantity + step <= _maxAmount() + 0.001,
          onDec: () => _adjustQuantity(-1),
          onInc: () => _adjustQuantity(1),
        ),
      ],
    );
  }

  // ── options ────────────────────────────────────────────────────

  Widget _optionsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Опции'),
        SizedBox(height: 12.s),
        ..._visibleOptions.map((option) {
          final selected = _selectedItemsFor(option);
          return Padding(
            padding: EdgeInsets.only(bottom: 14.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.name,
                        style: TextStyle(color: AppColors.text, fontSize: 14.sp, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (option.required == 1)
                      Text(
                        'обязательно',
                        style: TextStyle(color: AppColors.orange, fontSize: 11.sp, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
                SizedBox(height: 10.s),
                Wrap(
                  spacing: 8.s,
                  runSpacing: 8.s,
                  children: option.optionItems.map((optionItem) {
                    final active = selected.any((selectedItem) => selectedItem.relationId == optionItem.relationId);
                    final subtitle = optionItem.price > 0 ? '+${_money(optionItem.price)}' : null;
                    return _chip(
                      label: optionItem.itemName,
                      subtitle: subtitle,
                      active: active,
                      onTap: () => _toggleOption(option, optionItem),
                    );
                  }).toList(growable: false),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── promotions ─────────────────────────────────────────────────

  Widget _promoBlock() {
    final promotions = _detailPromotions.where((promotion) => promotion.discountType != 'SUBTRACT').toList(growable: false);
    if (promotions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Акции'),
        SizedBox(height: 10.s),
        ...promotions.map((promotion) {
          final icon = promotion.discountType == 'SUBTRACT' ? Icons.card_giftcard_rounded : Icons.local_offer_outlined;
          final color = promotion.discountType == 'SUBTRACT' ? AppColors.orange : AppColors.red;
          final label = _promoLabel(promotion);
          final detail = _promoDetail(promotion);

          return Padding(
            padding: EdgeInsets.only(bottom: 9.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28.s,
                  height: 28.s,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 15.s, color: color),
                ),
                SizedBox(width: 10.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8.s,
                        runSpacing: 6.s,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.s, vertical: 4.s),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999.s),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(color: color, fontSize: 11.sp, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            promotion.name,
                            style: TextStyle(color: AppColors.text, fontSize: 12.sp, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      if (detail != null) ...[
                        SizedBox(height: 4.s),
                        Text(
                          detail,
                          style: TextStyle(color: AppColors.textMute, fontSize: 11.sp, height: 1.35),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _promoLabel(item_model.ItemPromotion promo) {
    if (promo.discountType == 'SUBTRACT') {
      return '${promo.baseAmount}+${promo.addAmount}';
    }
    if (promo.discountType == 'PERCENT') {
      return '-${promo.discountValue.round()}%';
    }
    if (promo.discountType == 'FIXED') {
      return '-${_money(promo.discountValue)}';
    }
    return promo.name;
  }

  String? _promoDetail(item_model.ItemPromotion promo) {
    if (promo.discountType == 'SUBTRACT') {
      return 'Добавьте ${_promoAmountLabel(promo.baseAmount.toDouble())} в корзину и получите +${_promoAmountLabel(promo.addAmount.toDouble())} подарком.';
    }
    if (promo.discountType == 'PERCENT') {
      return 'Скидка ${promo.discountValue.round()}% от цены';
    }
    if (promo.discountType == 'FIXED') {
      return 'Скидка ${_money(promo.discountValue)} от цены';
    }
    return promo.description;
  }

  // ── description ────────────────────────────────────────────────

  Widget _descriptionBlock() {
    final description = widget.item.description?.trim() ?? '';
    const previewLimit = 190;
    final canExpand = description.length > previewLimit;
    final displayText = !canExpand || _descriptionExpanded ? description : '${description.substring(0, previewLimit).trimRight()}...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Описание'),
        SizedBox(height: 10.s),
        Text(
          displayText,
          style: TextStyle(color: AppColors.textMute, fontSize: 13.sp, height: 1.6),
        ),
        if (canExpand) ...[
          SizedBox(height: 10.s),
          GestureDetector(
            onTap: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
            child: Text(
              _descriptionExpanded ? 'Свернуть' : 'Читать далее',
              style: TextStyle(
                color: AppColors.orange,
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.orange.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ],
    );
  }

  double _previewOptionsTotal() {
    if (_usesPourFlow) {
      return _pourFlowOptionsTotal();
    }
    return _previewCartItem(
      quantity: _manualQuantity,
      includePromotions: false,
    ).optionsTotal;
  }

  Future<void> _showPriceBreakdownSheet(double total, double rawTotal, double amount) {
    final baseTotal = widget.item.price * amount;
    final extrasTotal = _previewOptionsTotal();
    final savings = math.max(0.0, rawTotal - total);
    final free = _freeFromPromo(amount);
    final labelBase = _priceBreakdownBaseLabel(amount);
    final giftLabel = free > 0.001 ? '${_promoAmountLabel(free)} в подарок' : null;
    final bottleDetail = _usesPourFlow ? _activeBottleDetailLabel() : null;

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          margin: EdgeInsets.fromLTRB(12.s, 0, 12.s, 12.s),
          padding: EdgeInsets.fromLTRB(18.s, 16.s, 18.s, 18.s),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16.s),
            border: Border.all(color: const Color(0xFF333333)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Разбор цены',
                style: TextStyle(color: AppColors.text, fontSize: 16.sp, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 14.s),
              if (savings > 0.001) ...[
                _breakdownRow('Без акции', _money(rawTotal), valueColor: AppColors.textMute),
                SizedBox(height: 10.s),
              ],
              _breakdownRow(
                labelBase,
                _money(baseTotal),
                note: _usesPourFlow ? _money(widget.item.price) : null,
              ),
              if (free > 0.001) ...[
                SizedBox(height: 10.s),
                _breakdownRow(
                  giftLabel!,
                  _money(0),
                  valueColor: AppColors.orange,
                ),
              ],
              if (extrasTotal > 0.001) ...[
                SizedBox(height: 10.s),
                _breakdownRow(
                  _usesPourFlow ? 'Тара' : 'Опции',
                  _money(extrasTotal),
                  note: _usesPourFlow ? bottleDetail : null,
                ),
              ],
              Padding(
                padding: EdgeInsets.symmetric(vertical: 14.s),
                child: Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
              ),
              _breakdownRow('Итого', _money(total), valueColor: AppColors.text),
            ],
          ),
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, String value, {String? note, Color valueColor = AppColors.text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: AppColors.textMute, fontSize: 12.sp)),
              if (note != null) ...[
                SizedBox(height: 2.s),
                Text(
                  note,
                  style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.72), fontSize: 11.sp, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: 12.s),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13.sp, fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ── bottom bar ─────────────────────────────────────────────────

  Widget _bottomBar(double total, double rawTotal, double amount, EdgeInsets pad) {
    final ready = amount > 0;
    final hasSavings = total < rawTotal - 1;
    final actionEnabled = !_submitting && ready;
    final controlHeight = hasSavings ? 72.s : 68.s;

    return Container(
      padding: EdgeInsets.fromLTRB(18.s, 14.s, 18.s, 14.s + pad.bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: const Border(top: BorderSide(color: Color(0xFF333333), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SizedBox(
        height: controlHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Material(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(18.s),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18.s),
                  onTap: () => _showPriceBreakdownSheet(total, rawTotal, amount),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.s, 10.s, 22.s, 10.s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasSavings)
                          Text(
                            _money(rawTotal),
                            style: TextStyle(
                              color: AppColors.textMute.withValues(alpha: 0.62),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: AppColors.textMute.withValues(alpha: 0.5),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _money(total),
                                style: TextStyle(color: AppColors.text, fontSize: 20.sp, fontWeight: FontWeight.w900),
                              ),
                            ),
                            SizedBox(width: 8.s),
                            Icon(Icons.info_outline_rounded, size: 16.s, color: AppColors.textMute),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.s),
            SizedBox(
              width: 128.s,
              child: Material(
                color: actionEnabled ? AppColors.orange : AppColors.blue,
                borderRadius: BorderRadius.circular(18.s),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18.s),
                  onTap: actionEnabled ? _submit : null,
                  child: Center(
                    child: _submitting
                        ? SizedBox(
                            width: 18.s,
                            height: 18.s,
                            child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Text(
                            'В корзину',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: actionEnabled ? Colors.black : AppColors.textMute,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _promoAmountLabel(double value) {
    return _usesPourFlow ? _volumeLabel(value) : _quantityLabel(value);
  }

  // ════════════════════════════════════════════════════════════════
  //  Reusable parts
  // ════════════════════════════════════════════════════════════════

  Widget _thinDivider() {
    return Container(height: 1, color: Colors.white.withValues(alpha: 0.06));
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: AppColors.textMute,
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _chip({
    required String label,
    String? subtitle,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 9.s),
        decoration: BoxDecoration(
          color: active ? AppColors.orange : AppColors.cardDark,
          borderRadius: BorderRadius.circular(11.s),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.black : AppColors.text,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 2.s),
              Text(
                subtitle,
                style: TextStyle(
                  color: active ? Colors.black54 : AppColors.textMute,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepper({
    required String value,
    required bool canDec,
    required bool canInc,
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) {
    return Container(
      padding: EdgeInsets.all(4.s),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12.s),
      ),
      child: Row(
        children: [
          _stepBtn(Icons.remove_rounded, canDec ? onDec : null),
          Expanded(
            child: Center(
              child: Text(
                value,
                style: TextStyle(color: AppColors.text, fontSize: 17.sp, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          _stepBtn(Icons.add_rounded, canInc ? onInc : null),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    return Material(
      color: onTap != null ? AppColors.blue : AppColors.blue.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(11.s),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11.s),
        child: SizedBox(
          width: 44.s,
          height: 44.s,
          child: Icon(
            icon,
            color: onTap != null ? AppColors.text : AppColors.textMute.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38.s,
        height: 38.s,
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.text, size: 17.s),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Bottle editor bottom sheet
// ══════════════════════════════════════════════════════════════════

class _BottleSheet extends StatefulWidget {
  const _BottleSheet({
    required this.bottles,
    required this.counts,
    required this.volumeForBottle,
    required this.volumeLabel,
    required this.shortName,
    required this.maxAmount,
    required this.onApply,
  });

  final List<item_model.ItemOptionItem> bottles;
  final Map<int, int> counts;
  final double Function(item_model.ItemOptionItem) volumeForBottle;
  final String Function(double) volumeLabel;
  final String Function(item_model.ItemOptionItem) shortName;
  final double maxAmount;
  final void Function(Map<int, int>) onApply;

  @override
  State<_BottleSheet> createState() => _BottleSheetState();
}

class _BottleSheetState extends State<_BottleSheet> {
  late final Map<int, int> _counts;

  @override
  void initState() {
    super.initState();
    _counts = Map<int, int>.of(widget.counts);
  }

  double _totalLiters() {
    var total = 0.0;
    for (final bottle in widget.bottles) {
      final c = _counts[bottle.relationId] ?? 0;
      if (c > 0) total += widget.volumeForBottle(bottle) * c;
    }
    return total;
  }

  int _totalBottles() {
    return _counts.values.fold<int>(0, (s, c) => s + c);
  }

  void _change(item_model.ItemOptionItem bottle, int delta) {
    setState(() {
      final next = ((_counts[bottle.relationId] ?? 0) + delta).clamp(0, 999);
      _counts[bottle.relationId] = next;
    });
  }

  void _apply() {
    widget.onApply(_counts);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final liters = _totalLiters();
    final bottleCount = _totalBottles();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(18.s, 10.s, 18.s, 14.s + pad.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            width: 32.s,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 18.s),
          // header
          Row(
            children: [
              Text(
                'Тара',
                style: TextStyle(color: AppColors.text, fontSize: 16.sp, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${widget.volumeLabel(liters)} · $bottleCount бут.',
                style: TextStyle(color: AppColors.textMute, fontSize: 12.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 18.s),
          // bottle rows — all types always visible
          ...widget.bottles.map((bottle) {
            final count = _counts[bottle.relationId] ?? 0;
            final vol = widget.volumeForBottle(bottle);
            final canAdd = liters + vol <= widget.maxAmount + 0.001;
            return Padding(
              padding: EdgeInsets.only(bottom: 9.s),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 10.s),
                decoration: BoxDecoration(
                  color: count > 0 ? AppColors.blue : AppColors.cardDark,
                  borderRadius: BorderRadius.circular(12.s),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.shortName(bottle),
                        style: TextStyle(color: AppColors.text, fontSize: 14.sp, fontWeight: FontWeight.w700),
                      ),
                    ),
                    _sheetStepBtn(
                      Icons.remove_rounded,
                      count > 0 ? () => _change(bottle, -1) : null,
                    ),
                    SizedBox(
                      width: 36.s,
                      child: Center(
                        child: Text(
                          '$count',
                          style: TextStyle(color: AppColors.text, fontSize: 15.sp, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    _sheetStepBtn(
                      Icons.add_rounded,
                      canAdd ? () => _change(bottle, 1) : null,
                    ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: 10.s),
          // apply button
          SizedBox(
            width: double.infinity,
            height: 48.s,
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.s)),
              ),
              child: Text(
                'Готово',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetStepBtn(IconData icon, VoidCallback? onTap) {
    return Material(
      color: onTap != null ? AppColors.blue : AppColors.blue.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(11.s),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11.s),
        child: SizedBox(
          width: 36.s,
          height: 36.s,
          child: Icon(
            icon,
            size: 18.s,
            color: onTap != null ? AppColors.text : AppColors.textMute.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
