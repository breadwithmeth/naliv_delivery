import 'dart:math' as math;

import '../model/item.dart' as item_model;
import '../models/cart_item.dart';

class SmartCartSelection {
  SmartCartSelection(this.item)
      : containerOption = _resolveContainerOption(item),
        bottleVariants = _resolveBottleVariants(item, _resolveContainerOption(item)),
        visibleOptions = _resolveVisibleOptions(item, _resolveContainerOption(item)),
        defaultOptionSelections = _resolveDefaultOptionSelections(_resolveVisibleOptions(item, _resolveContainerOption(item)));

  final item_model.Item item;
  final item_model.ItemOption? containerOption;
  final List<item_model.ItemOptionItem> bottleVariants;
  final List<item_model.ItemOption> visibleOptions;
  final Map<int, List<item_model.ItemOptionItem>> defaultOptionSelections;

  static final RegExp _volumePattern = RegExp(r'(\d+(?:\.\d+)?)\s*(л|l|ml|мл)', caseSensitive: false);

  late final List<item_model.ItemOptionItem> filteredBottles = _filterAllowedBottles();
  late final List<int> bottleRelationIds = filteredBottles.map((bottle) => bottle.relationId).toList(growable: false);
  late final bool usesPourFlow = containerOption != null && filteredBottles.isNotEmpty && _looksPourProduct();
  late final String defaultDisplayKey = displayKeyForVariants(defaultNonBottleVariants);

  List<Map<String, dynamic>> get defaultNonBottleVariants {
    final result = <Map<String, dynamic>>[];
    for (final option in visibleOptions) {
      final items = defaultOptionSelections[option.optionId] ?? const <item_model.ItemOptionItem>[];
      for (final optionItem in items) {
        result.add(_variantMap(optionItem, required: option.required));
      }
    }
    return normalizeVariantMaps(result);
  }

  double get minBottleVolume {
    if (filteredBottles.isEmpty) {
      return 0;
    }
    return filteredBottles.map(volumeForBottle).reduce(math.min);
  }

  double get maxAmount {
    final amount = item.amount?.toDouble();
    if (amount == null || amount <= 0) {
      return double.infinity;
    }
    return amount;
  }

  double get defaultStepQuantity {
    if (usesPourFlow) {
      return 1.0;
    }

    var step = item.effectiveStepQuantity <= 0 ? 1.0 : item.effectiveStepQuantity;
    for (final variant in defaultNonBottleVariants) {
      final parentAmount = variantParentItemAmount(variant);
      if (parentAmount != null && parentAmount > 0) {
        step = parentAmount;
        break;
      }
    }
    return _normalizeDouble(step);
  }

  double volumeForBottle(item_model.ItemOptionItem bottle) {
    final parentAmount = bottle.parentItemAmount;
    if (parentAmount > 0 && parentAmount <= 20) {
      return parentAmount;
    }

    final parsed = _extractVolumeFromText(bottle.item_name);
    if (parsed > 0) {
      return parsed;
    }

    return item.effectiveStepQuantity > 0 ? item.effectiveStepQuantity : 1.0;
  }

  bool isBottleVariant(Map<String, dynamic> variant) {
    final relationId = variantRelationId(variant);
    if (relationId != null && bottleRelationIds.contains(relationId)) {
      return true;
    }
    return looksBottleLikeVariant(variant);
  }

  List<Map<String, dynamic>> stripBottleVariants(List<Map<String, dynamic>> variants) {
    return normalizeVariantMaps(
      variants.where((variant) => !isBottleVariant(variant)).toList(growable: false),
    );
  }

  String displayKeyForVariants(List<Map<String, dynamic>> variants) {
    final keys = stripBottleVariants(variants).map(variantStableKey).toList(growable: false)..sort();
    return '${item.itemId}|${keys.join(';')}';
  }

  List<Map<String, dynamic>> buildVariantMaps({
    item_model.ItemOptionItem? bottle,
    List<Map<String, dynamic>>? baseVariants,
  }) {
    final result = <Map<String, dynamic>>[];
    if (bottle != null) {
      result.add(_variantMap(bottle, required: containerOption?.required ?? 0));
    }
    if (baseVariants != null) {
      result.addAll(baseVariants.map((variant) => Map<String, dynamic>.from(variant)));
    } else {
      result.addAll(defaultNonBottleVariants.map((variant) => Map<String, dynamic>.from(variant)));
    }
    return normalizeVariantMaps(result);
  }

  Map<int, int> autoBottleBreakdown(double targetLiters) {
    final target = (targetLiters * 100).round();
    if (target <= 0 || filteredBottles.isEmpty) {
      return const <int, int>{};
    }

    final volumes = filteredBottles.map((item) => (volumeForBottle(item) * 100).round()).toList(growable: false);
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
      final bottle = filteredBottles[index];
      result[bottle.relationId] = (result[bottle.relationId] ?? 0) + 1;
      cursor = prevAmount[cursor];
    }
    return result;
  }

  double clampQuantity(double quantity) {
    final normalized = _normalizeDouble(quantity);
    if (maxAmount.isFinite) {
      return normalized.clamp(0, maxAmount).toDouble();
    }
    return math.max(0, normalized);
  }

  String volumeLabel(double value) {
    if ((value - value.roundToDouble()).abs() < 0.001) {
      return '${value.toStringAsFixed(0)} л';
    }
    if ((value * 10 - (value * 10).roundToDouble()).abs() < 0.001) {
      return '${value.toStringAsFixed(1)} л';
    }
    return '${value.toStringAsFixed(2)} л';
  }

  static List<Map<String, dynamic>> normalizeVariantMaps(List<Map<String, dynamic>> variants) {
    final normalized = variants.map((variant) => Map<String, dynamic>.from(variant)).toList(growable: false);
    normalized.sort((left, right) => variantStableKey(left).compareTo(variantStableKey(right)));
    return normalized;
  }

  static int? variantRelationId(Map<String, dynamic> variant) {
    final direct = variant['relation_id'] ?? variant['variant_id'];
    if (direct is int) {
      return direct;
    }
    final parsedDirect = int.tryParse(direct?.toString() ?? '');
    if (parsedDirect != null) {
      return parsedDirect;
    }

    final nested = variant['variant'];
    if (nested is Map) {
      final nestedValue = nested['relation_id'] ?? nested['variant_id'];
      if (nestedValue is int) {
        return nestedValue;
      }
      return int.tryParse(nestedValue?.toString() ?? '');
    }

    return null;
  }

  static double? variantParentItemAmount(Map<String, dynamic> variant) {
    final direct = variant['parent_item_amount'];
    if (direct is num) {
      return direct.toDouble();
    }

    final nested = variant['variant'];
    if (nested is Map && nested['parent_item_amount'] is num) {
      return (nested['parent_item_amount'] as num).toDouble();
    }

    return double.tryParse(direct?.toString() ?? '');
  }

  static String variantStableKey(Map<String, dynamic> variant) {
    final relationId = variantRelationId(variant);
    if (relationId != null) {
      return relationId.toString();
    }

    final itemId = variant['item_id']?.toString() ?? '';
    final itemName = (variant['item_name']?.toString() ?? '').trim().toLowerCase();
    final amount = variantParentItemAmount(variant)?.toStringAsFixed(2) ?? '';
    return '$itemId|$itemName|$amount';
  }

  static bool looksBottleLikeVariant(Map<String, dynamic> variant) {
    final itemName = (variant['item_name']?.toString() ?? variant['name']?.toString() ?? '').trim().toLowerCase();
    if (_volumePattern.hasMatch(itemName)) {
      return true;
    }

    final amount = variantParentItemAmount(variant);
    return amount != null && amount > 0 && amount <= 5 && itemName.contains('л');
  }

  static item_model.Item? itemSnapshotFromCartItem(CartItem item) {
    final raw = item.itemData;
    if (raw == null) {
      return null;
    }

    try {
      return item_model.Item.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  static item_model.ItemOption? _resolveContainerOption(item_model.Item item) {
    for (final option in item.options ?? const <item_model.ItemOption>[]) {
      if (option.optionItems.isEmpty) {
        continue;
      }
      final matched = option.optionItems.where((optionItem) {
        final parsed = _extractVolumeFromText(optionItem.item_name);
        return parsed > 0 || optionItem.parentItemAmount > 0;
      }).length;
      if (matched == option.optionItems.length) {
        return option;
      }
    }
    return null;
  }

  static List<item_model.ItemOptionItem> _resolveBottleVariants(
    item_model.Item item,
    item_model.ItemOption? containerOption,
  ) {
    if (containerOption == null) {
      return const <item_model.ItemOptionItem>[];
    }

    final items = containerOption.optionItems.where((optionItem) {
      final parentAmount = optionItem.parentItemAmount;
      if (parentAmount > 0) {
        return true;
      }
      return _extractVolumeFromText(optionItem.item_name) > 0;
    }).toList(growable: true);
    items.sort((left, right) {
      final leftVolume = left.parentItemAmount > 0 ? left.parentItemAmount : _extractVolumeFromText(left.item_name);
      final rightVolume = right.parentItemAmount > 0 ? right.parentItemAmount : _extractVolumeFromText(right.item_name);
      return leftVolume.compareTo(rightVolume);
    });
    return items;
  }

  static List<item_model.ItemOption> _resolveVisibleOptions(
    item_model.Item item,
    item_model.ItemOption? containerOption,
  ) {
    return (item.options ?? const <item_model.ItemOption>[]).where((option) => option.optionId != containerOption?.optionId).toList(growable: false);
  }

  static Map<int, List<item_model.ItemOptionItem>> _resolveDefaultOptionSelections(List<item_model.ItemOption> options) {
    final selections = <int, List<item_model.ItemOptionItem>>{};
    for (final option in options) {
      if (option.optionItems.isEmpty) {
        continue;
      }

      if (option.required == 1 || option.optionItems.length == 1) {
        selections[option.optionId] = <item_model.ItemOptionItem>[option.optionItems.first];
      }
    }
    return selections;
  }

  static double _extractVolumeFromText(String rawLabel) {
    final match = _volumePattern.firstMatch(rawLabel.replaceAll(',', '.'));
    if (match == null) {
      return 0;
    }

    final value = double.tryParse(match.group(1) ?? '');
    if (value == null || value <= 0) {
      return 0;
    }

    final unit = (match.group(2) ?? '').toLowerCase();
    if (unit == 'ml' || unit == 'мл') {
      return value / 1000;
    }

    return value;
  }

  List<item_model.ItemOptionItem> _filterAllowedBottles() {
    const allowedVolumes = <double>[1.0, 2.0, 3.0];
    return bottleVariants.where((bottle) {
      final volume = volumeForBottle(bottle);
      return allowedVolumes.any((allowed) => (allowed - volume).abs() < 0.05);
    }).toList(growable: false);
  }

  bool _looksPourProduct() {
    final haystack = '${item.name} ${item.category?.name ?? ''}'.toLowerCase();
    const keywords = <String>['пиво', 'beer', 'разлив', 'lager', 'ipa', 'stout', 'эль', 'сидр'];
    if (keywords.any(haystack.contains)) {
      return true;
    }
    return bottleVariants.length >= 2;
  }

  Map<String, dynamic> _variantMap(item_model.ItemOptionItem optionItem, {required int required}) {
    return <String, dynamic>{
      'variant_id': optionItem.relationId,
      'relation_id': optionItem.relationId,
      'item_id': optionItem.itemId,
      'item_name': optionItem.item_name,
      'price_type': optionItem.priceType,
      'price': optionItem.price,
      'parent_item_amount': optionItem.parentItemAmount > 0 ? optionItem.parentItemAmount : volumeForBottle(optionItem),
      'required': required,
    };
  }

  Map<int, int> _greedyBottleBreakdown(double targetLiters) {
    var remaining = targetLiters;
    final result = <int, int>{};
    final sorted = filteredBottles.toList()..sort((left, right) => volumeForBottle(right).compareTo(volumeForBottle(left)));

    for (final bottle in sorted) {
      final volume = volumeForBottle(bottle);
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
      if (volumeForBottle(smallest) <= maxAmount + 0.001) {
        result[smallest.relationId] = 1;
      }
    }

    return result;
  }

  double _normalizeDouble(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}

class CartDisplayGroup {
  CartDisplayGroup._({
    required this.key,
    required this.items,
    required this.itemSnapshot,
    required this.baseVariants,
  });

  final String key;
  final List<CartItem> items;
  final item_model.Item? itemSnapshot;
  final List<Map<String, dynamic>> baseVariants;

  SmartCartSelection? get selection => itemSnapshot == null ? null : SmartCartSelection(itemSnapshot!);

  int get itemId => items.first.itemId;
  String get name => items.first.name;
  String? get image => items.first.image;
  String? get itemType => items.first.itemType;
  String? get packagingType => items.first.packagingType;
  double get price => items.first.price;
  double? get maxAmount => itemSnapshot?.amount?.toDouble() ?? items.first.maxAmount;
  List<Map<String, dynamic>> get promotions => items.first.promotions;

  double get totalQuantity => items.fold<double>(0, (sum, item) => sum + item.quantity);
  double get optionsTotal => items.fold<double>(0, (sum, item) => sum + item.optionsTotal);
  double get subtotalBeforePromotions => (price * totalQuantity) + optionsTotal;

  double get totalPrice {
    final promotedBase = _applyPromotionsToBaseTotal(price * totalQuantity, totalQuantity, promotions, price);
    return promotedBase + optionsTotal;
  }

  double get freeQuantity => _freeAmount(totalQuantity, promotions);

  Map<int, int> get bottleCounts {
    final currentSelection = selection;
    if (currentSelection == null || !currentSelection.usesPourFlow) {
      return const <int, int>{};
    }

    final counts = <int, int>{};
    for (final item in items) {
      int? bottleId;
      for (final variant in item.selectedVariants) {
        if (!currentSelection.isBottleVariant(variant)) {
          continue;
        }
        bottleId = SmartCartSelection.variantRelationId(variant);
        if (bottleId != null) {
          break;
        }
      }

      if (bottleId == null) {
        continue;
      }

      final volume = _bottleVolumeForCartItem(item, currentSelection);
      if (volume <= 0) {
        continue;
      }

      final count = (item.quantity / volume).round();
      if (count <= 0) {
        continue;
      }

      counts[bottleId] = (counts[bottleId] ?? 0) + count;
    }

    return counts;
  }

  String? get bottleBreakdownLabel {
    final currentSelection = selection;
    if (currentSelection == null || !currentSelection.usesPourFlow) {
      return null;
    }

    final parts = <String>[];
    final sortedItems = items.toList()
      ..sort((left, right) {
        final leftVolume = _bottleVolumeForCartItem(left, currentSelection);
        final rightVolume = _bottleVolumeForCartItem(right, currentSelection);
        return rightVolume.compareTo(leftVolume);
      });

    for (final item in sortedItems) {
      final volume = _bottleVolumeForCartItem(item, currentSelection);
      if (volume <= 0) {
        continue;
      }
      final count = (item.quantity / volume).round();
      if (count <= 0) {
        continue;
      }
      parts.add('$count× ${currentSelection.volumeLabel(volume)}');
    }

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(' • ');
  }

  static List<CartDisplayGroup> groupItems(Iterable<CartItem> items) {
    final grouped = <String, List<CartItem>>{};
    for (final item in items) {
      final key = displayKeyForCartItem(item);
      grouped.putIfAbsent(key, () => <CartItem>[]).add(item);
    }

    final result = grouped.entries.map((entry) {
      final groupItems = entry.value.toList(growable: false);
      final snapshot = _resolveItemSnapshot(groupItems);
      final currentSelection = snapshot == null ? null : SmartCartSelection(snapshot);
      final baseVariants = currentSelection == null
          ? SmartCartSelection.normalizeVariantMaps(
              groupItems.first.selectedVariants.where((variant) => !SmartCartSelection.looksBottleLikeVariant(variant)).toList())
          : currentSelection.stripBottleVariants(groupItems.first.selectedVariants);

      return CartDisplayGroup._(
        key: entry.key,
        items: groupItems,
        itemSnapshot: snapshot,
        baseVariants: baseVariants,
      );
    }).toList(growable: false);

    return result;
  }

  static String displayKeyForCartItem(CartItem item) {
    final snapshot = SmartCartSelection.itemSnapshotFromCartItem(item);
    final selection = snapshot == null ? null : SmartCartSelection(snapshot);
    final baseVariants = selection == null
        ? item.selectedVariants.where((variant) => !SmartCartSelection.looksBottleLikeVariant(variant)).toList(growable: false)
        : selection.stripBottleVariants(item.selectedVariants);
    final keys = baseVariants.map(SmartCartSelection.variantStableKey).toList(growable: false)..sort();
    return '${item.itemId}|${keys.join(';')}';
  }

  static item_model.Item? _resolveItemSnapshot(List<CartItem> items) {
    for (final item in items) {
      final snapshot = SmartCartSelection.itemSnapshotFromCartItem(item);
      if (snapshot != null) {
        return snapshot;
      }
    }
    return null;
  }

  static double _bottleVolumeForCartItem(CartItem item, SmartCartSelection selection) {
    for (final bottle in selection.filteredBottles) {
      if (item.selectedVariants.any((variant) => SmartCartSelection.variantRelationId(variant) == bottle.relationId)) {
        return selection.volumeForBottle(bottle);
      }
    }
    return 0;
  }

  static double _freeAmount(double quantity, List<Map<String, dynamic>> promotions) {
    for (final promo in promotions) {
      final type = (promo['type'] as String?) ?? (promo['discount_type'] as String?);
      if (type == 'SUBTRACT') {
        final base = ((promo['baseAmount'] as num?) ?? (promo['base_amount'] as num?) ?? 0).toInt();
        final add = ((promo['addAmount'] as num?) ?? (promo['add_amount'] as num?) ?? 0).toInt();
        final groupSize = base + add;
        if (groupSize > 0 && base > 0 && quantity >= groupSize) {
          final count = quantity ~/ groupSize;
          return (count * add).toDouble();
        }
      }
    }
    return 0;
  }

  static double _applyPromotionsToBaseTotal(
    double baseTotal,
    double quantity,
    List<Map<String, dynamic>> promotions,
    double unitPrice,
  ) {
    var payableQuantity = quantity;
    var result = baseTotal;

    for (final promo in promotions) {
      final type = (promo['type'] as String?) ?? (promo['discount_type'] as String?);
      if (type == 'SUBTRACT') {
        final base = ((promo['baseAmount'] as num?) ?? (promo['base_amount'] as num?) ?? 0).toInt();
        final add = ((promo['addAmount'] as num?) ?? (promo['add_amount'] as num?) ?? 0).toInt();
        final groupSize = base + add;
        if (groupSize > 0 && base > 0 && quantity >= groupSize) {
          final count = quantity ~/ groupSize;
          payableQuantity = quantity - (count * add);
          result = unitPrice * payableQuantity;
        }
      }
    }

    for (final promo in promotions) {
      final type = (promo['type'] as String?) ?? (promo['discount_type'] as String?);
      if (type == 'FIXED') {
        final discount = ((promo['discount'] as num?) ?? (promo['discount_value'] as num?) ?? 0).toDouble();
        if (discount > 0) {
          result = (result - (discount * payableQuantity)).clamp(0, double.infinity).toDouble();
        }
      }
    }

    for (final promo in promotions) {
      final type = (promo['type'] as String?) ?? (promo['discount_type'] as String?);
      if (type == 'DISCOUNT' || type == 'PERCENT') {
        final discount = ((promo['discount'] as num?) ?? (promo['discount_value'] as num?) ?? 0).toDouble();
        result = result * (1 - discount / 100);
      }
    }

    return result;
  }
}
