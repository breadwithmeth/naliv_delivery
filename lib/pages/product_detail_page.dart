import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../globals.dart' as globals;
import '../model/item.dart' as item_model;
import '../models/cart_item.dart';
import '../shared/app_theme.dart';
import '../utils/api.dart';
import '../utils/bonus_rules.dart';
import '../utils/business_provider.dart';
import '../utils/cart_provider.dart';
import '../utils/item_name_presentation.dart';
import '../utils/liked_items_provider.dart';
import '../utils/liked_storage_service.dart';
import '../utils/responsive.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.item});

  final item_model.Item item;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  // ── state ─────────────────────────────────────────────────────
  late final item_model.ItemOption? _containerOption;
  late final List<item_model.ItemOptionItem> _bottleVariants;
  late final List<item_model.ItemOptionItem> _filteredBottles;
  late final List<item_model.ItemOption> _visibleOptions;
  late final ItemTitlePresentation _itemTitle;

  final Map<int, List<item_model.ItemOptionItem>> _selectedOptions = {};
  final Map<int, int> _bottleCounts = {};

  double _manualQuantity = 0;
  bool _submitting = false;

  // ── like state ──
  bool _likeInProgress = false;
  bool? _isLikedOverride;
  int? _businessId;
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
    final groupSize = promo.baseAmount + promo.addAmount;
    if (groupSize <= 0 || quantity < groupSize) return 0;
    final count = (quantity ~/ groupSize);
    return (count * promo.addAmount).toDouble();
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
    _manualQuantity = _initialQuantity();
    _primeDefaultSelections();
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

  int _calculateBonusPoints() {
    if (BonusRules.isBonusExcludedText(
      name: widget.item.name,
      description: widget.item.description,
      categoryName: widget.item.category?.name,
      code: widget.item.code,
    )) {
      return 0;
    }
    return BonusRules.calculateEarnedBonuses(_displayUnitPrice());
  }

  // ── business logic ────────────────────────────────────────────

  double _initialQuantity() {
    final step = widget.item.effectiveStepQuantity;
    if (widget.item.amount != null && widget.item.amount! > 0) {
      return math.min(step, widget.item.amount!.toDouble());
    }
    return step;
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
    final raw = item.item_name.toLowerCase().replaceAll(',', '.');
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

  double _displayUnitPrice() {
    final promo = _discountPromo;
    if (promo == null) {
      return widget.item.price;
    }
    return promo.calculateDiscountedPrice(widget.item.price);
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

  int _configuredBottleCount() {
    return _activeBottleCounts().values.fold<int>(0, (sum, count) => sum + count);
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
      'item_name': optionItem.item_name,
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

  double _applyPromotionsToBaseTotal(double baseTotal, double quantity) {
    double payableQuantity = quantity;
    double result = baseTotal;
    final promotions = _promotionMaps();

    for (final promo in promotions) {
      final type = (promo['type'] as String?) ?? (promo['discount_type'] as String?);
      if (type == 'SUBTRACT') {
        final base = ((promo['baseAmount'] as num?) ?? (promo['base_amount'] as num?) ?? 0).toInt();
        final add = ((promo['addAmount'] as num?) ?? (promo['add_amount'] as num?) ?? 0).toInt();
        final groupSize = base + add;
        if (groupSize > 0 && base > 0 && quantity >= groupSize) {
          final count = quantity ~/ groupSize;
          payableQuantity = quantity - (count * add);
          result = widget.item.price * payableQuantity;
        }
      }
    }

    for (final promo in promotions) {
      final type = (promo['type'] as String?) ?? (promo['discount_type'] as String?);
      if (type == 'FIXED') {
        final disc = ((promo['discount'] as num?) ?? (promo['discount_value'] as num?) ?? 0).toDouble();
        if (disc > 0) {
          result = (result - (disc * payableQuantity)).clamp(0, double.infinity).toDouble();
        }
      }
    }

    for (final promo in promotions) {
      final type = (promo['type'] as String?) ?? (promo['discount_type'] as String?);
      if (type == 'DISCOUNT' || type == 'PERCENT') {
        final disc = ((promo['discount'] as num?) ?? (promo['discount_value'] as num?) ?? 0).toDouble();
        result = result * (1 - disc / 100);
      }
    }

    return result;
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
      final promotedBase = includePromotions ? _applyPromotionsToBaseTotal(baseTotal, totalLiters) : baseTotal;
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
    final promotions = _promotionMaps();

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

        for (final entry in counts.entries) {
          if (entry.value <= 0) continue;
          final bottle = _filteredBottles.firstWhere((item) => item.relationId == entry.key);
          final ok = cart.addItemWithOptions(
            widget.item.itemId,
            _itemTitle.name,
            widget.item.image ?? '',
            widget.item.price,
            _volumeForBottle(bottle) * entry.value,
            _selectedVariantMaps(includeBottle: true, bottle: bottle),
            promotions,
            _itemTitle.type,
            _itemTitle.packagingType,
            widget.item.toJson(),
          );
          added = added || ok;
        }
      } else if (widget.item.hasOptions) {
        added = cart.addItemWithOptions(
          widget.item.itemId,
          _itemTitle.name,
          widget.item.image ?? '',
          widget.item.price,
          _manualQuantity,
          _selectedVariantMaps(),
          promotions,
          _itemTitle.type,
          _itemTitle.packagingType,
          widget.item.toJson(),
        );
      } else {
        added = cart.addItem(
          CartItem(
            itemId: widget.item.itemId,
            name: _itemTitle.name,
            price: widget.item.price,
            quantity: _manualQuantity,
            stepQuantity: widget.item.effectiveStepQuantity,
            image: widget.item.image,
            itemType: _itemTitle.type,
            packagingType: _itemTitle.packagingType,
            selectedVariants: const <Map<String, dynamic>>[],
            promotions: promotions,
            itemData: widget.item.toJson(),
            maxAmount: widget.item.amount?.toDouble(),
          ),
        );
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
    return bottle.item_name.trim().isNotEmpty ? bottle.item_name.trim() : _volumeLabel(volume);
  }

  // ════════════════════════════════════════════════════════════════
  //  UI
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final total = _previewTotal();
    final rawTotal = _previewTotal(includePromotions: false);
    final amount = _configuredAmount();
    final cart = context.watch<CartProvider>();
    final cartQuantity = cart.getTotalQuantityForItem(widget.item.itemId);

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
                      SizedBox(height: 18.s),
                      if (_subtractPromo != null) ...[
                        _subtractPromoBanner(),
                        SizedBox(height: 18.s),
                      ],
                      _thinDivider(),
                      SizedBox(height: 18.s),
                      if (_usesPourFlow) ...[
                        _pourControls(),
                        SizedBox(height: 18.s),
                      ],
                      if (!_usesPourFlow) ...[
                        _quantityControl(),
                        if (_subtractPromo != null) ...[
                          SizedBox(height: 14.s),
                          _subtractPromoInfo(),
                        ],
                        SizedBox(height: 18.s),
                      ],
                      if (_visibleOptions.isNotEmpty) ...[
                        _thinDivider(),
                        SizedBox(height: 18.s),
                        _optionsBlock(),
                        SizedBox(height: 18.s),
                      ],
                      if (_activePromotions.isNotEmpty) ...[
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
                      SizedBox(height: 72.s + pad.bottom),
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

          // ─ bottom bar ─
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _bottomBar(total, rawTotal, amount, cartQuantity, pad),
          ),
        ],
      ),
    );
  }

  // ── image area ────────────────────────────────────────────────

  Widget _imageArea(EdgeInsets pad) {
    final hasImage = (widget.item.image ?? '').trim().isNotEmpty;
    final promo = _subtractPromo;
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

        // Top-left badges column
        Positioned(
          top: pad.top + 10.s,
          left: 14.s,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (discount != null) ...[
                Container(
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
              ],
            ],
          ),
        ),

        // Bottom row: promo marker
        Positioned(
          bottom: 18.s,
          left: 18.s,
          right: 18.s,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (promo != null)
                _heroMarker(
                  icon: Icons.card_giftcard_rounded,
                  foreground: AppColors.orange,
                  background: AppColors.orange.withValues(alpha: 0.14),
                  borderColor: AppColors.orange.withValues(alpha: 0.16),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return const Icon(Icons.inventory_2_outlined, color: AppColors.textMute, size: 58);
  }

  // ── product info ──────────────────────────────────────────────

  Widget _productInfo() {
    final bonusPoints = _calculateBonusPoints();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Packaging + category/type on the left, country on the right.
        if (_itemTitle.packagingType != null || _itemTitle.type != null || _itemTitle.countryName != null) ...[
          Row(
            children: [
              if (_itemTitle.packagingType != null) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.s, vertical: 4.s),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(7.s),
                  ),
                  child: Text(
                    _itemTitle.packagingType!,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.orange,
                      height: 1.2,
                    ),
                  ),
                ),
                SizedBox(width: 8.s),
              ],
              if (_itemTitle.type != null)
                Expanded(
                  child: Text(
                    _itemTitle.type!,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMute,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              if (_itemTitle.countryName != null) ...[
                SizedBox(width: 10.s),
                Text(
                  _itemTitle.countryName!,
                  style: TextStyle(
                    color: AppColors.orange,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          SizedBox(height: 10.s),
        ],

        // Product name
        Text(
          _itemTitle.name,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 22.sp,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        SizedBox(height: 14.s),
        ..._priceDisplay(),
        SizedBox(height: 10.s),
        _supportingInfoRow(bonusPoints),
      ],
    );
  }

  Widget _supportingInfoRow(int bonusPoints) {
    final hasStock = widget.item.amount != null && widget.item.amount! > 0;
    final hasBonuses = bonusPoints > 0;

    if (!hasStock && !hasBonuses) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _favoriteAction(),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasStock) _stockIndicator(widget.item.amount!),
              if (hasBonuses) ...[
                if (hasStock) SizedBox(height: 8.s),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 15.s, color: AppColors.orange),
                    SizedBox(width: 5.s),
                    Text(
                      '+$bonusPoints бонусов',
                      style: TextStyle(
                        color: AppColors.textMute,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: 12.s),
        _favoriteAction(),
      ],
    );
  }

  Widget _favoriteAction() {
    return GestureDetector(
      onTap: _toggleLike,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 8.s),
        decoration: BoxDecoration(
          color: _isLiked ? AppColors.red : AppColors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10.s),
          border: Border.all(
            color: _isLiked ? AppColors.red : AppColors.red.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              size: 15.s,
              color: _isLiked ? Colors.white : AppColors.red,
            ),
            SizedBox(width: 6.s),
            Text(
              _isLiked ? 'В любимом' : 'В любимое',
              style: TextStyle(
                color: _isLiked ? Colors.white : AppColors.red,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── price display with discount ────────────────────────────

  List<Widget> _priceDisplay() {
    final promo = _discountPromo;
    final unitSuffix = _usesPourFlow ? ' / 1 л' : null;
    final facts = _itemTitle.pricingAttributes.take(2).toList(growable: false);

    if (promo != null) {
      final discounted = promo.calculateDiscountedPrice(widget.item.price);
      final savings = promo.calculateSavings(widget.item.price);
      return [
        Text(
          _money(widget.item.price),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _money(discounted),
                          style: TextStyle(
                            color: AppColors.orange,
                            fontSize: 25.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (unitSuffix != null)
                          TextSpan(
                            text: unitSuffix,
                            style: TextStyle(
                              color: AppColors.textMute,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.s),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7.s, vertical: 3.s),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(6.s),
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
            ),
            if (facts.isNotEmpty) ...[
              SizedBox(width: 12.s),
              _pricingFactsAccent(facts),
            ],
          ],
        ),
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
        if (_usesPourFlow) ...[
          SizedBox(height: 8.s),
          _pourPriceInfoHint(),
        ],
      ];
    }

    // SUBTRACT promo — shown as dedicated banner below, keep price clean
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _money(widget.item.price),
                    style: TextStyle(
                      color: AppColors.orange,
                      fontSize: 25.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (unitSuffix != null)
                    TextSpan(
                      text: unitSuffix,
                      style: TextStyle(
                        color: AppColors.textMute,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (facts.isNotEmpty) ...[
            SizedBox(width: 12.s),
            _pricingFactsAccent(facts),
          ],
        ],
      ),
      if (_usesPourFlow) ...[
        SizedBox(height: 8.s),
        _pourPriceInfoHint(),
      ],
    ];
  }

  Widget _pourPriceInfoHint() {
    return InkWell(
      borderRadius: BorderRadius.circular(8.s),
      onTap: _showPourPriceExplanation,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 2.s),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 14.s,
              color: AppColors.textMute,
            ),
            SizedBox(width: 6.s),
            Flexible(
              child: Text(
                'Почему цена отличается?',
                style: TextStyle(
                  color: AppColors.textMute,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textMute.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPourPriceExplanation() {
    return AppDialogs.showMessage(
      context,
      title: 'Почему цена отличается?',
      message:
          'Цена с пометкой / 1 л показывает стоимость самого напитка за литр. Итоговая сумма может быть выше, потому что при розливе отдельно добавляется стоимость выбранной бутылки или тары.',
    );
  }

  Widget _pricingFactsAccent(List<String> facts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: facts
          .map(
            (fact) => Padding(
              padding: EdgeInsets.only(bottom: 2.s),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _pricingFactLabel(fact),
                      style: TextStyle(
                        color: AppColors.textMute.withValues(alpha: 0.72),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.45,
                      ),
                    ),
                    TextSpan(
                      text: fact,
                      style: TextStyle(
                        color: AppColors.orange,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  String _pricingFactLabel(String fact) {
    return fact.contains('%') ? 'КРЕП. ' : 'ОБЪЕМ ';
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
    final bottles = _configuredBottleCount();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Объём'),
        SizedBox(height: 12.s),
        _stepper(
          value: _volumeLabel(liters),
          subtitle: '$bottles бут.',
          canDec: _canAdjustLiters(-1),
          canInc: _canAdjustLiters(1),
          onDec: () => _adjustLiters(-1),
          onInc: () => _adjustLiters(1),
        ),
        SizedBox(height: 10.s),
        _bottleSummaryBtn(),

        // ── Bottle breakdown text ──
        if (_activeBottleCounts().isNotEmpty) ...[
          SizedBox(height: 10.s),
          ..._activeBottleCounts().entries.map((entry) {
            final bottle = _filteredBottles.firstWhere((b) => b.relationId == entry.key);
            final vol = _volumeForBottle(bottle);
            final name = _shortBottleName(bottle);
            final quantity = vol * entry.value;
            final rawItem = _previewCartItem(quantity: quantity, bottle: bottle, includePromotions: false);
            final cost = rawItem.subtotalBeforePromotions;
            return Padding(
              padding: EdgeInsets.only(bottom: 4.s),
              child: Row(
                children: [
                  Icon(Icons.wine_bar_outlined, size: 13.s, color: AppColors.textMute),
                  SizedBox(width: 6.s),
                  Expanded(
                    child: Text(
                      '${entry.value}× $name (${_volumeLabel(vol)})',
                      style: TextStyle(color: AppColors.textMute, fontSize: 12.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _money(cost),
                        style: TextStyle(color: AppColors.text, fontSize: 12.sp, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],

        // ── Inline SUBTRACT promo info ──
        if (_subtractPromo != null) ...[
          SizedBox(height: 14.s),
          _subtractPromoInfo(),
        ],
      ],
    );
  }

  /// Inline free-amount indicator for SUBTRACT promo (inside pour/quantity controls).
  Widget _subtractPromoInfo() {
    final promo = _subtractPromo!;
    final amount = _configuredAmount();
    final free = _freeFromPromo(amount);
    final groupSize = promo.baseAmount + promo.addAmount;
    final nextThreshold = ((amount / groupSize).floor() + 1) * groupSize;
    final litersToNext = _normalizeDouble(nextThreshold - amount);

    if (free > 0) {
      return Row(
        children: [
          Icon(Icons.card_giftcard_rounded, size: 14.s, color: AppColors.orange),
          SizedBox(width: 6.s),
          Text(
            '${_volumeLabel(free)} бесплатно',
            style: TextStyle(color: AppColors.orange, fontSize: 12.sp, fontWeight: FontWeight.w700),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 14.s, color: AppColors.textMute),
        SizedBox(width: 6.s),
        Text(
          'Ещё ${_volumeLabel(litersToNext)} до ${promo.addAmount} л бесплатно',
          style: TextStyle(color: AppColors.textMute, fontSize: 12.sp, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// Full-width promo banner — shown between product info and controls.
  Widget _subtractPromoBanner() {
    final promo = _subtractPromo!;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 12.s),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.s),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.s),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.s),
            ),
            child: Icon(Icons.card_giftcard_rounded, size: 18.s, color: AppColors.orange),
          ),
          SizedBox(width: 12.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${promo.baseAmount}+${promo.addAmount}',
                  style: TextStyle(color: AppColors.orange, fontSize: 14.sp, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2.s),
                Text(
                  'Купите ${promo.baseAmount} — ${promo.addAmount} в подарок',
                  style: TextStyle(color: AppColors.textMute, fontSize: 12.sp, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottleSummaryBtn() {
    final active = _activeBottleCounts();
    final parts = <String>[];
    for (final entry in active.entries) {
      final bottle = _filteredBottles.firstWhere((b) => b.relationId == entry.key);
      parts.add('${entry.value}×${_volumeLabel(_volumeForBottle(bottle))}');
    }
    final detail = parts.isNotEmpty ? parts.join(' · ') : null;

    return GestureDetector(
      onTap: _openBottleSheet,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 12.s),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12.s),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(Icons.wine_bar_outlined, color: AppColors.textMute, size: 16.s),
            SizedBox(width: 9.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Настроить тару',
                    style: TextStyle(color: AppColors.text, fontSize: 13.sp, fontWeight: FontWeight.w600),
                  ),
                  if (detail != null) ...[
                    SizedBox(height: 2.s),
                    Text(
                      detail,
                      style: TextStyle(color: AppColors.textMute, fontSize: 11.sp, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMute, size: 18.s),
          ],
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
                    Flexible(
                      child: Text(
                        option.name,
                        style: TextStyle(color: AppColors.text, fontSize: 14.sp, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (option.required == 1) ...[
                      SizedBox(width: 7.s),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.s, vertical: 3.s),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5.s),
                        ),
                        child: Text(
                          'обяз.',
                          style: TextStyle(color: AppColors.orange, fontSize: 10.sp, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 9.s),
                Wrap(
                  spacing: 7.s,
                  runSpacing: 7.s,
                  children: option.optionItems.map((optionItem) {
                    final isActive = selected.any((s) => s.relationId == optionItem.relationId);
                    return _chip(
                      label: optionItem.item_name.isNotEmpty ? optionItem.item_name : 'Вариант',
                      subtitle: optionItem.price > 0 ? '+${_money(optionItem.price)}' : null,
                      active: isActive,
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
    var promotions = _activePromotions;
    // SUBTRACT promos shown near price + inline in pour controls — skip here
    promotions = promotions.where((p) => p.discountType != 'SUBTRACT').toList();
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
            padding: EdgeInsets.only(bottom: 7.s),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 10.s),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.s),
                border: Border.all(color: color.withValues(alpha: 0.14)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16.s, color: color),
                  SizedBox(width: 8.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(color: color, fontSize: 13.sp, fontWeight: FontWeight.w800),
                        ),
                        if (detail != null) ...[
                          SizedBox(height: 3.s),
                          Text(
                            detail,
                            style: TextStyle(color: AppColors.textMute, fontSize: 11.sp, height: 1.3),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
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
      return 'За каждые ${promo.baseAmount + promo.addAmount} л оплата только за ${promo.baseAmount} л';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Описание'),
        SizedBox(height: 10.s),
        Text(
          widget.item.description!,
          style: TextStyle(color: AppColors.textMute, fontSize: 13.sp, height: 1.6),
        ),
      ],
    );
  }

  // ── bottom bar ─────────────────────────────────────────────────

  Widget _bottomBar(double total, double rawTotal, double amount, double cartQuantity, EdgeInsets pad) {
    final ready = amount > 0;
    final free = _freeFromPromo(amount);
    final plannedTotal = _normalizeDouble(cartQuantity + amount);

    // Build subtitle
    String subtitle;
    if (_usesPourFlow) {
      final bottles = _configuredBottleCount();
      if (free > 0) {
        subtitle = '${_volumeLabel(amount)} · $bottles бут. (${_volumeLabel(free)} бесплатно)';
      } else {
        subtitle = '${_volumeLabel(amount)} · $bottles бут.';
      }
    } else {
      subtitle = _quantityLabel(amount);
    }

    final hasSavings = total < rawTotal - 1;

    return Container(
      padding: EdgeInsets.fromLTRB(18.s, 14.s, 18.s, 14.s + pad.bottom),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_subtractPromo != null) ...[
                  _subtractProgressBar(cartQuantity, plannedTotal),
                  SizedBox(height: 10.s),
                ],
                if (hasSavings)
                  Text(
                    _money(rawTotal),
                    style: TextStyle(
                      color: AppColors.textMute.withValues(alpha: 0.5),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: AppColors.textMute.withValues(alpha: 0.5),
                    ),
                  ),
                Text(
                  _money(total),
                  style: TextStyle(color: AppColors.text, fontSize: 20.sp, fontWeight: FontWeight.w900),
                ),
                if (hasSavings) ...[
                  SizedBox(height: 1.s),
                  Text(
                    'Выгода ${_money(rawTotal - total)}',
                    style: TextStyle(color: AppColors.orange, fontSize: 11.sp, fontWeight: FontWeight.w700),
                  ),
                ],
                SizedBox(height: 2.s),
                Text(
                  subtitle,
                  style: TextStyle(color: AppColors.textMute, fontSize: 12.sp, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          SizedBox(width: 14.s),
          SizedBox(
            height: 48.s,
            child: ElevatedButton(
              onPressed: !_submitting && ready ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AppColors.blue,
                disabledForegroundColor: AppColors.textMute,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.s)),
                padding: EdgeInsets.symmetric(horizontal: 24.s),
              ),
              child: _submitting
                  ? SizedBox(
                      width: 18.s,
                      height: 18.s,
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      'В корзину',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subtractProgressBar(double cartQuantity, double plannedQuantity) {
    final promo = _subtractPromo;
    if (promo == null) return const SizedBox.shrink();

    final base = promo.baseAmount.toDouble();
    final add = promo.addAmount.toDouble();
    final group = base + add;
    if (group <= 0) return const SizedBox.shrink();

    final total = _normalizeDouble(plannedQuantity);
    final remainderRaw = total <= 0 ? 0 : total % group;
    final remainder = remainderRaw == 0 && total > 0 ? group : remainderRaw;
    final progress = total <= 0 ? 0.0 : (remainder / group).clamp(0.0, 1.0);

    final claimLeft = math.max(0.0, group - remainder);
    final success = claimLeft <= 0.001;

    String label;
    Color barColor;

    if (total <= 0.001) {
      label = 'Доб. ${_promoAmountLabel(base)} для подарка';
      barColor = AppColors.orange;
    } else if (success) {
      label = '${_promoAmountLabel(add)} бесплатно ✔';
      barColor = const Color(0xFF3AC779);
    } else {
      label = 'Ещё ${_promoAmountLabel(claimLeft)} до подарка';
      barColor = AppColors.orange;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3.s),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4.s,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        SizedBox(height: 4.s),
        Text(
          label,
          style: TextStyle(color: AppColors.textMute, fontSize: 11.sp, fontWeight: FontWeight.w600),
        ),
      ],
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

  Widget _heroMarker({
    required IconData icon,
    required Color foreground,
    required Color background,
    required Color borderColor,
  }) {
    return Container(
      width: 34.s,
      height: 34.s,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10.s),
        border: Border.all(color: borderColor),
      ),
      child: Icon(icon, size: 17.s, color: foreground),
    );
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
    String? subtitle,
    required bool canDec,
    required bool canInc,
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) {
    return Container(
      padding: EdgeInsets.all(5.s),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14.s),
      ),
      child: Row(
        children: [
          _stepBtn(Icons.remove_rounded, canDec ? onDec : null),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(color: AppColors.text, fontSize: 22.sp, fontWeight: FontWeight.w900),
                ),
                if (subtitle != null)
                  Padding(
                    padding: EdgeInsets.only(top: 2.s),
                    child: Text(
                      subtitle,
                      style: TextStyle(color: AppColors.textMute, fontSize: 11.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
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
          width: 40.s,
          height: 40.s,
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
