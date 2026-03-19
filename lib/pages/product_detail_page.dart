import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/item.dart' as item_model;
import '../models/cart_item.dart';
import '../shared/app_theme.dart';
import '../utils/cart_provider.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.item});

  final item_model.Item item;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  // ── MainPage palette ──────────────────────────────────────────
  static const _bg = Color(0xFF121212);
  static const _surface = Color(0xFF1E1E1E);
  static const _surfDim = Color(0xFF181818);
  static const _accent = Color(0xFF242A32);
  static const _orange = Color(0xFFF6A10C);
  static const _red = Color(0xFFC23B30);
  static const _tx = Colors.white;
  static const _dim = Color(0xFF9FB0C8);

  // ── state ─────────────────────────────────────────────────────
  late final item_model.ItemOption? _containerOption;
  late final List<item_model.ItemOptionItem> _bottleVariants;
  late final List<item_model.ItemOptionItem> _filteredBottles;
  late final List<item_model.ItemOption> _visibleOptions;

  final Map<int, List<item_model.ItemOptionItem>> _selectedOptions = {};
  final Map<int, int> _bottleCounts = {};

  double _manualQuantity = 0;
  bool _submitting = false;

  bool get _usesPourFlow => _containerOption != null && _filteredBottles.isNotEmpty && _looksPourProduct();

  // ── lifecycle ─────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
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
      _bottleCounts[_filteredBottles.first.relationId] = 1;
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
    final isWhole = (quantity - quantity.roundToDouble()).abs() < 0.001;
    final base = isWhole ? quantity.toStringAsFixed(0) : quantity.toStringAsFixed(2);
    if (widget.item.effectiveStepQuantity < 1) {
      return '$base кг';
    }
    return '$base шт';
  }

  void _adjustLiters(int direction) {
    final current = _totalLitersFromBottles();
    final target = _normalizeDouble((current + direction).clamp(1.0, _maxAmount()));
    if ((target - current).abs() < 0.001) return;
    final breakdown = _autoBottleBreakdown(target);
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
    if (remaining > 0.001 && sorted.isNotEmpty) {
      final smallest = sorted.last;
      result[smallest.relationId] = (result[smallest.relationId] ?? 0) + 1;
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
    return (widget.item.promotions ?? const <item_model.ItemPromotion>[])
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

  double _previewTotal() {
    if (_usesPourFlow) {
      final counts = _activeBottleCounts();
      if (counts.isEmpty) {
        return widget.item.price;
      }

      var total = 0.0;
      for (final entry in counts.entries) {
        final bottle = _filteredBottles.firstWhere((item) => item.relationId == entry.key);
        final quantity = _volumeForBottle(bottle) * entry.value;
        total += CartItem(
          itemId: widget.item.itemId,
          name: widget.item.name,
          price: widget.item.price,
          quantity: quantity,
          stepQuantity: _volumeForBottle(bottle),
          image: widget.item.image,
          selectedVariants: _selectedVariantMaps(includeBottle: true, bottle: bottle),
          promotions: _promotionMaps(),
          maxAmount: widget.item.amount?.toDouble(),
        ).totalPrice;
      }
      return total;
    }

    return CartItem(
      itemId: widget.item.itemId,
      name: widget.item.name,
      price: widget.item.price,
      quantity: _manualQuantity,
      stepQuantity: widget.item.effectiveStepQuantity,
      image: widget.item.image,
      selectedVariants: _selectedVariantMaps(),
      promotions: _promotionMaps(),
      maxAmount: widget.item.amount?.toDouble(),
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
          if (entry.value <= 0) {
            continue;
          }
          final bottle = _filteredBottles.firstWhere((item) => item.relationId == entry.key);
          final ok = cart.addItemWithOptions(
            widget.item.itemId,
            widget.item.name,
            widget.item.image ?? '',
            widget.item.price,
            _volumeForBottle(bottle) * entry.value,
            _selectedVariantMaps(includeBottle: true, bottle: bottle),
            promotions,
          );
          added = added || ok;
        }
      } else if (widget.item.hasOptions) {
        added = cart.addItemWithOptions(
          widget.item.itemId,
          widget.item.name,
          widget.item.image ?? '',
          widget.item.price,
          _manualQuantity,
          _selectedVariantMaps(),
          promotions,
        );
      } else {
        added = cart.addItem(
          CartItem(
            itemId: widget.item.itemId,
            name: widget.item.name,
            price: widget.item.price,
            quantity: _manualQuantity,
            stepQuantity: widget.item.effectiveStepQuantity,
            image: widget.item.image,
            selectedVariants: const <Map<String, dynamic>>[],
            promotions: promotions,
            maxAmount: widget.item.amount?.toDouble(),
          ),
        );
      }

      if (!mounted) {
        return;
      }

      if (added) {
        Navigator.of(context).pop();
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
    final amount = _configuredAmount();

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ─ scrollable content ─
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _imageArea(pad)),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -24),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _productInfo(),
                        const SizedBox(height: 24),
                        _thinDivider(),
                        const SizedBox(height: 24),
                        if (_usesPourFlow) ...[
                          _pourControls(),
                          const SizedBox(height: 24),
                        ],
                        if (!_usesPourFlow) ...[
                          _quantityControl(),
                          const SizedBox(height: 24),
                        ],
                        if (_visibleOptions.isNotEmpty) ...[
                          _optionsBlock(),
                          const SizedBox(height: 24),
                        ],
                        if (widget.item.hasPromotions) ...[
                          _promoBlock(),
                          const SizedBox(height: 24),
                        ],
                        if ((widget.item.description ?? '').trim().isNotEmpty) ...[
                          _descriptionBlock(),
                          const SizedBox(height: 24),
                        ],
                        SizedBox(height: 80 + pad.bottom),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ─ back button ─
          Positioned(
            top: pad.top + 12,
            left: 16,
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
            child: _bottomBar(total, amount, pad),
          ),
        ],
      ),
    );
  }

  // ── image area ────────────────────────────────────────────────

  Widget _imageArea(EdgeInsets pad) {
    final hasImage = (widget.item.image ?? '').trim().isNotEmpty;
    return Container(
      height: 340 + pad.top,
      color: _surfDim,
      alignment: Alignment.center,
      padding: EdgeInsets.fromLTRB(40, pad.top + 48, 40, 48),
      child: hasImage
          ? Image.network(
              widget.item.image!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return const Icon(Icons.inventory_2_outlined, color: _dim, size: 64);
  }

  // ── product info ──────────────────────────────────────────────

  Widget _productInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((widget.item.category?.name ?? '').trim().isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.item.category!.name,
              style: const TextStyle(color: _dim, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          widget.item.name,
          style: const TextStyle(
            color: _tx,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        if ((widget.item.code ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Арт. ${widget.item.code}',
            style: const TextStyle(color: _dim, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          _money(widget.item.price),
          style: const TextStyle(
            color: _orange,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (widget.item.amount != null && widget.item.amount! > 0) ...[
          const SizedBox(height: 6),
          Text(
            'В наличии: ${widget.item.amount}',
            style: const TextStyle(color: _dim, fontSize: 13),
          ),
        ],
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
        const SizedBox(height: 14),
        _stepper(
          value: _volumeLabel(liters),
          subtitle: '$bottles бут.',
          canDec: liters > 1.0 + 0.001,
          canInc: liters + 1.0 <= _maxAmount() + 0.001,
          onDec: () => _adjustLiters(-1),
          onInc: () => _adjustLiters(1),
        ),
        const SizedBox(height: 12),
        _bottleSummaryBtn(),
      ],
    );
  }

  Widget _bottleSummaryBtn() {
    final active = _activeBottleCounts();
    final parts = <String>[];
    for (final entry in active.entries) {
      final bottle = _filteredBottles.firstWhere((b) => b.relationId == entry.key);
      parts.add('${entry.value}×${_volumeLabel(_volumeForBottle(bottle))}');
    }
    final summary = parts.isNotEmpty ? parts.join(' · ') : 'Выбрать тару';

    return GestureDetector(
      onTap: _openBottleSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surfDim,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wine_bar_outlined, color: _dim, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                summary,
                style: const TextStyle(color: _tx, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _dim, size: 20),
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
        const SizedBox(height: 14),
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
        const SizedBox(height: 14),
        ..._visibleOptions.map((option) {
          final selected = _selectedItemsFor(option);
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        option.name,
                        style: const TextStyle(color: _tx, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (option.required == 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'обяз.',
                          style: TextStyle(color: _orange, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
    final promotions = widget.item.promotions ?? const <item_model.ItemPromotion>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Акции'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: promotions
              .map(
                (promotion) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _red.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_offer_outlined, size: 14, color: _red),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          promotion.description?.trim().isNotEmpty == true ? promotion.description! : promotion.name,
                          style: const TextStyle(color: _red, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  // ── description ────────────────────────────────────────────────

  Widget _descriptionBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Описание'),
        const SizedBox(height: 12),
        Text(
          widget.item.description!,
          style: const TextStyle(color: _dim, fontSize: 14, height: 1.6),
        ),
      ],
    );
  }

  // ── bottom bar ─────────────────────────────────────────────────

  Widget _bottomBar(double total, double amount, EdgeInsets pad) {
    final ready = amount > 0;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + pad.bottom),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _money(total),
                  style: const TextStyle(color: _tx, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  _usesPourFlow ? '${_volumeLabel(amount)} · ${_configuredBottleCount()} бут.' : _quantityLabel(amount),
                  style: const TextStyle(color: _dim, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: !_submitting && ready ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.black,
                disabledBackgroundColor: _accent,
                disabledForegroundColor: _dim,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text(
                      'В корзину',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
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
      style: const TextStyle(
        color: _dim,
        fontSize: 13,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _orange : _surfDim,
          borderRadius: BorderRadius.circular(12),
          border: active ? null : Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.black : _tx,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: active ? Colors.black54 : _dim,
                  fontSize: 11,
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
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _surfDim,
        borderRadius: BorderRadius.circular(16),
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
                  style: const TextStyle(color: _tx, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: const TextStyle(color: _dim, fontSize: 12, fontWeight: FontWeight.w600),
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
      color: onTap != null ? _accent : _accent.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: onTap != null ? _tx : _dim.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _surface.withValues(alpha: 0.85),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _tx, size: 18),
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
  static const _bg = Color(0xFF121212);
  static const _surface = Color(0xFF1E1E1E);
  static const _surfDim = Color(0xFF181818);
  static const _accent = Color(0xFF242A32);
  static const _orange = Color(0xFFF6A10C);
  static const _tx = Colors.white;
  static const _dim = Color(0xFF9FB0C8);

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
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + pad.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // header
          Row(
            children: [
              const Text(
                'Тара',
                style: TextStyle(color: _tx, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${widget.volumeLabel(liters)} · $bottleCount бут.',
                style: const TextStyle(color: _dim, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // bottle rows — all types always visible
          ...widget.bottles.map((bottle) {
            final count = _counts[bottle.relationId] ?? 0;
            final vol = widget.volumeForBottle(bottle);
            final canAdd = liters + vol <= widget.maxAmount + 0.001;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: count > 0 ? _accent : _surfDim,
                  borderRadius: BorderRadius.circular(14),
                  border: count > 0 ? Border.all(color: _orange.withValues(alpha: 0.2)) : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.shortName(bottle),
                        style: const TextStyle(color: _tx, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    _sheetStepBtn(
                      Icons.remove_rounded,
                      count > 0 ? () => _change(bottle, -1) : null,
                    ),
                    SizedBox(
                      width: 40,
                      child: Center(
                        child: Text(
                          '$count',
                          style: const TextStyle(color: _tx, fontSize: 16, fontWeight: FontWeight.w900),
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
          const SizedBox(height: 12),
          // apply button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Готово',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetStepBtn(IconData icon, VoidCallback? onTap) {
    return Material(
      color: onTap != null ? _accent : _accent.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: onTap != null ? _tx : _dim.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
