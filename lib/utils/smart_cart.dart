import 'dart:math' as math;

import '../model/item.dart' as item_model;
import '../model/cart_item.dart';
import 'subtract_promotion_math.dart';

class SmartCartSelection {
  SmartCartSelection(this.item)
      : containerOption = _resolveContainerOption(item),
        bottleVariants =
            _resolveBottleVariants(item, _resolveContainerOption(item)),
        visibleOptions =
            _resolveVisibleOptions(item, _resolveContainerOption(item)),
        defaultOptionSelections = _resolveDefaultOptionSelections(
            _resolveVisibleOptions(item, _resolveContainerOption(item)));

  final item_model.Item item;
  final item_model.ItemOption? containerOption;
  final List<item_model.ItemOptionItem> bottleVariants;
  final List<item_model.ItemOption> visibleOptions;
  final Map<int, List<item_model.ItemOptionItem>> defaultOptionSelections;

  static final RegExp _volumePattern = RegExp(
      r'(\d+(?:\.\d+)?)\s*(мл|ml|л|l)(?![a-zа-я])',
      caseSensitive: false);

  late final List<item_model.ItemOptionItem> filteredBottles =
      _filterAllowedBottles();
  late final List<int> bottleRelationIds = filteredBottles
      .map((bottle) => bottle.relationId)
      .toList(growable: false);
  late final bool usesPourFlow =
      containerOption != null && filteredBottles.isNotEmpty;
  late final String defaultDisplayKey =
      displayKeyForVariants(defaultNonBottleVariants);

  String? get containerIssue {
    final unit = item.unit?.trim().toLowerCase().replaceAll('.', '');
    if (unit == null || unit.isEmpty) {
      if ((item.options ?? const <item_model.ItemOption>[]).any((option) =>
          RegExp(r'литраж|тара|бутыл|bottle|container')
              .hasMatch(option.name.toLowerCase()))) {
        return 'Магазин не передал единицу объёма товара. Выбор тары недоступен.';
      }
      return null;
    }
    if (!const ['л', 'l', 'литр', 'литры'].contains(unit)) return null;
    for (final option in item.options ?? const <item_model.ItemOption>[]) {
      if (RegExp(r'литраж|тара|бутыл|bottle|container')
              .hasMatch(option.name.toLowerCase()) &&
          (option.optionItems.isEmpty ||
              option.optionItems
                  .any((variant) => _containerVolume(variant) <= 0))) {
        return 'Магазин не передал объём доступной тары. Выбор недоступен.';
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get defaultNonBottleVariants {
    final result = <Map<String, dynamic>>[];
    for (final option in visibleOptions) {
      final items = defaultOptionSelections[option.optionId] ??
          const <item_model.ItemOptionItem>[];
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

  double get maxAmount => item.amount?.toDouble() ?? double.infinity;

  double get defaultStepQuantity => item.effectiveStepQuantity;

  double volumeForBottle(item_model.ItemOptionItem bottle) =>
      _containerVolume(bottle);

  bool isBottleVariant(Map<String, dynamic> variant) {
    final relationId = variantRelationId(variant);
    if (relationId != null && bottleRelationIds.contains(relationId)) {
      return true;
    }
    if (relationId != null) {
      for (final option in item.options ?? const <item_model.ItemOption>[]) {
        for (final optionItem in option.optionItems) {
          if (optionItem.relationId == relationId) {
            // Snapshot identities distinguish parameters from containers even
            // when a parameter's label happens to resemble a volume or unit.
            return option.optionId == containerOption?.optionId;
          }
        }
      }
    }
    return containerOption != null && looksBottleLikeVariant(variant);
  }

  List<Map<String, dynamic>> stripBottleVariants(
      List<Map<String, dynamic>> variants) {
    return normalizeVariantMaps(
      variants
          .where((variant) => !isBottleVariant(variant))
          .toList(growable: false),
    );
  }

  String displayKeyForVariants(List<Map<String, dynamic>> variants) {
    final keys = stripBottleVariants(variants)
        .map(variantStableKey)
        .toList(growable: false)
      ..sort();
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
      result.addAll(
          baseVariants.map((variant) => Map<String, dynamic>.from(variant)));
    } else {
      result.addAll(defaultNonBottleVariants
          .map((variant) => Map<String, dynamic>.from(variant)));
    }
    return normalizeVariantMaps(result);
  }

  Map<int, int> autoBottleBreakdown(double targetLiters) {
    if (!targetLiters.isFinite || targetLiters < 0) {
      throw ArgumentError.value(targetLiters, 'targetLiters');
    }
    if (targetLiters == 0) return const <int, int>{};
    final promotions = (item.promotions ?? const <item_model.ItemPromotion>[])
        .where((promotion) => promotion.isActive)
        .map((promotion) => promotion.toJson())
        .toList(growable: false);
    if (targetLiters + subtractPromotionFreeQuantity(targetLiters, promotions) >
        maxAmount + 0.0000001) {
      throw StateError('Выбранный объём с подарком превышает остаток');
    }
    giftBottleBreakdown(targetLiters);
    return _exactBottleBreakdown(targetLiters);
  }

  Map<int, int> giftBottleBreakdown(double paidLiters,
      {Map<int, int>? retainedCounts, Map<int, int>? availableCounts}) {
    final promotions = [
      for (final promotion
          in item.promotions ?? const <item_model.ItemPromotion>[])
        if (promotion.isActive) promotion.toJson(),
    ];
    final gift = subtractPromotionFreeQuantity(paidLiters, promotions);
    if (retainedCounts != null) {
      final volume = filteredBottles.fold<double>(
          0,
          (sum, bottle) =>
              sum +
              volumeForBottle(bottle) *
                  (retainedCounts[bottle.relationId] ?? 0));
      if (retainedCounts.entries.any((entry) =>
              entry.value < 0 || !bottleRelationIds.contains(entry.key)) ||
          (volume - gift).abs() > 0.0000001) {
        throw StateError('Подарочный объём не совпадает с выбранной тарой.');
      }
      return retainedCounts;
    }
    try {
      return _exactBottleBreakdown(gift, availableCounts: availableCounts);
    } on StateError {
      throw StateError(
          'Нельзя точно разлить подарочный объём по доступной таре. Измените оплаченный объём.');
    }
  }

  static Map<int, int>? scaledBottleCounts(
      Map<int, int>? counts, double multiplier) {
    if (counts == null || !multiplier.isFinite || multiplier < 0) return null;
    final result = <int, int>{};
    for (final entry in counts.entries) {
      final scaled = entry.value * multiplier;
      if ((scaled - scaled.round()).abs() > 0.0000001) return null;
      if (scaled > 0) result[entry.key] = scaled.round();
    }
    return result;
  }

  Map<int, int> _exactBottleBreakdown(double targetLiters,
      {Map<int, int>? availableCounts}) {
    if (targetLiters == 0) return const <int, int>{};
    const precision = 1000000;
    final rawTarget = (targetLiters * precision).round();
    final rawVolumes = filteredBottles
        .map((bottle) => (volumeForBottle(bottle) * precision).round())
        .toList(growable: false);
    if ((rawTarget / precision - targetLiters).abs() > 0.0000001 ||
        rawVolumes.isEmpty ||
        rawVolumes.any((volume) => volume <= 0)) {
      throw StateError('Нельзя точно распределить выбранный объём по таре');
    }
    var divisor = rawVolumes.first;
    for (final volume in rawVolumes.skip(1)) {
      divisor = divisor.gcd(volume);
    }
    if (rawTarget % divisor != 0) {
      throw StateError('Нельзя точно распределить выбранный объём по таре');
    }
    final target = rawTarget ~/ divisor;
    final volumes = rawVolumes.map((volume) => volume ~/ divisor).toList();
    if (availableCounts != null) {
      final result = <int, int>{};
      final failed = <(int, int)>{};
      bool find(int index, int remaining) {
        if (remaining == 0) return true;
        if (index == volumes.length || failed.contains((index, remaining))) {
          return false;
        }
        final bottleId = filteredBottles[index].relationId;
        final limit = math.min(
            availableCounts[bottleId] ?? 0, remaining ~/ volumes[index]);
        for (var count = 0; count <= limit; count++) {
          if (count > 0) result[bottleId] = count;
          if (find(index + 1, remaining - count * volumes[index])) return true;
          result.remove(bottleId);
        }
        failed.add((index, remaining));
        return false;
      }

      if (find(0, target)) return result;
      throw StateError('Нельзя точно распределить выбранный объём по таре');
    }
    final best = List<int>.filled(target + 1, target + 1);
    final previous = List<int>.filled(target + 1, -1);
    best[0] = 0;
    // Preserve the existing fewest-bottles policy, not a new cheapest-tariff rule.
    for (var amount = 1; amount <= target; amount++) {
      for (var index = 0; index < volumes.length; index++) {
        final volume = volumes[index];
        if (amount >= volume && best[amount - volume] + 1 < best[amount]) {
          best[amount] = best[amount - volume] + 1;
          previous[amount] = index;
        }
      }
    }
    if (previous[target] < 0) {
      throw StateError('Нельзя точно распределить выбранный объём по таре');
    }
    final result = <int, int>{};
    for (var cursor = target; cursor > 0;) {
      final index = previous[cursor];
      final bottle = filteredBottles[index];
      result[bottle.relationId] = (result[bottle.relationId] ?? 0) + 1;
      cursor -= volumes[index];
    }
    return result;
  }

  static List<CartItem> withGiftContainers(Iterable<CartItem> paidItems) {
    final result = <CartItem>[];
    for (final group in CartDisplayGroup.groupItems(paidItems)) {
      final selection = group.selection;
      final issue = group._paidAllocationIssue;
      if (issue != null) {
        throw StateError(issue);
      }
      final rows = [
        for (final item in group.items)
          if (item.quantity > 0) item,
      ];
      if (selection != null && selection.usesPourFlow && rows.isNotEmpty) {
        final gifts = selection.giftBottleBreakdown(group.totalQuantity,
            retainedCounts: group.retainedGiftBottleCounts);
        for (final bottle in selection.filteredBottles) {
          final count = gifts[bottle.relationId] ?? 0;
          if (count == 0) continue;
          final volume = selection.volumeForBottle(bottle) * count;
          final index = rows.indexWhere((row) => row.selectedVariants.any(
              (variant) => variantRelationId(variant) == bottle.relationId));
          if (index >= 0) {
            rows[index] = rows[index].copyWith(bottledGiftQuantity: volume);
          } else {
            rows.add(rows.first.copyWith(
              quantity: 0,
              bottledGiftQuantity: volume,
              stepQuantity: selection.volumeForBottle(bottle),
              selectedVariants: selection.buildVariantMaps(
                  bottle: bottle, baseVariants: group.baseVariants),
            ));
          }
        }
      }
      result.addAll(rows);
    }
    return result;
  }

  String volumeLabel(double value) =>
      '${value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '')} л';

  static List<Map<String, dynamic>> normalizeVariantMaps(
      List<Map<String, dynamic>> variants) {
    final normalized = variants
        .map((variant) => Map<String, dynamic>.from(variant))
        .toList(growable: false);
    normalized.sort((left, right) =>
        variantStableKey(left).compareTo(variantStableKey(right)));
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
    final itemName =
        (variant['item_name']?.toString() ?? '').trim().toLowerCase();
    final amount = variantParentItemAmount(variant)?.toStringAsFixed(2) ?? '';
    return '$itemId|$itemName|$amount';
  }

  static bool looksBottleLikeVariant(Map<String, dynamic> variant) {
    final itemName =
        (variant['item_name']?.toString() ?? variant['name']?.toString() ?? '')
            .trim()
            .toLowerCase();
    return RegExp(r'бутыл|тара|bottle|container').hasMatch(itemName) &&
        _volumePattern.hasMatch(itemName.replaceAll(',', '.'));
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
    final unit = item.unit?.trim().toLowerCase().replaceAll('.', '');
    if (!const ['л', 'l', 'литр', 'литры'].contains(unit)) return null;
    for (final option in item.options ?? const <item_model.ItemOption>[]) {
      if (!RegExp(r'литраж|тара|бутыл|bottle|container')
          .hasMatch(option.name.toLowerCase())) {
        continue;
      }
      if (option.optionItems.isNotEmpty &&
          option.optionItems
              .every((variant) => _containerVolume(variant) > 0)) {
        return option;
      }
    }
    return null;
  }

  static double _containerVolume(item_model.ItemOptionItem bottle) {
    final label = bottle.itemName.replaceAll(',', '.');
    final parsed = _extractVolumeFromText(label);
    final parent = bottle.parentItemAmount;
    // parent_item_amount is expressed in the base product's litres. An explicit
    // millilitre label is the only evidence allowing a millilitre conversion.
    final match = _volumePattern.firstMatch(label);
    if (match != null &&
        const ['мл', 'ml'].contains(match.group(2)?.toLowerCase()) &&
        parent == double.tryParse(match.group(1)!)) {
      return parsed;
    }
    if (parent.isFinite && parent > 0) return parent;
    return parsed;
  }

  static List<item_model.ItemOptionItem> _resolveBottleVariants(
    item_model.Item item,
    item_model.ItemOption? containerOption,
  ) {
    if (containerOption == null) {
      return const <item_model.ItemOptionItem>[];
    }

    final items = containerOption.optionItems
        .where((optionItem) => _containerVolume(optionItem) > 0)
        .toList(growable: true);
    items.sort((left, right) =>
        _containerVolume(left).compareTo(_containerVolume(right)));
    return items;
  }

  static List<item_model.ItemOption> _resolveVisibleOptions(
    item_model.Item item,
    item_model.ItemOption? containerOption,
  ) {
    return (item.options ?? const <item_model.ItemOption>[])
        .where((option) => option.optionId != containerOption?.optionId)
        .toList(growable: false);
  }

  static Map<int, List<item_model.ItemOptionItem>>
      _resolveDefaultOptionSelections(List<item_model.ItemOption> options) {
    final selections = <int, List<item_model.ItemOptionItem>>{};
    for (final option in options) {
      if (option.optionItems.isEmpty) {
        continue;
      }

      if (option.required == 1 || option.optionItems.length == 1) {
        selections[option.optionId] = <item_model.ItemOptionItem>[
          option.optionItems.first
        ];
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

  List<item_model.ItemOptionItem> _filterAllowedBottles() => bottleVariants
      .where((bottle) =>
          volumeForBottle(bottle).isFinite && volumeForBottle(bottle) > 0)
      .toList(growable: false);

  Map<String, dynamic> _variantMap(item_model.ItemOptionItem optionItem,
      {required int required}) {
    return <String, dynamic>{
      'variant_id': optionItem.relationId,
      'relation_id': optionItem.relationId,
      'item_id': optionItem.itemId,
      'item_name': optionItem.itemName,
      'price_type': optionItem.priceType,
      'price': optionItem.price,
      'parent_item_amount': containerOption?.optionItems
                  .any((value) => value.relationId == optionItem.relationId) ==
              true
          ? volumeForBottle(optionItem)
          : (optionItem.parentItemAmount > 0
              ? optionItem.parentItemAmount
              : item.effectiveStepQuantity),
      'required': required,
    };
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

  SmartCartSelection? get selection =>
      itemSnapshot == null ? null : SmartCartSelection(itemSnapshot!);

  int get itemId => items.first.itemId;
  String get name => items.first.name;
  String? get image => items.first.image;
  String? get itemType => items.first.itemType;
  String? get packagingType => items.first.packagingType;
  double get price => items.first.price;
  double? get maxAmount =>
      itemSnapshot?.amount?.toDouble() ?? items.first.maxAmount;
  List<Map<String, dynamic>> get promotions => items.first.promotions;

  double get totalQuantity =>
      items.fold<double>(0, (sum, item) => sum + item.quantity);
  double get optionsTotal => CartItem.calculatePrice(items).optionsTotal;
  double get subtotalBeforePromotions =>
      CartItem.calculatePrice(items).subtotalBeforePromotions;
  double get totalPrice => CartItem.calculatePrice(items).totalPrice;
  double get freeQuantity =>
      subtractPromotionFreeQuantity(totalQuantity, promotions);
  double get totalOrderQuantity => totalQuantity + freeQuantity;
  Map<int, int>? get retainedGiftBottleCounts {
    for (final item in items) {
      if (item.giftBottleCounts != null) return item.giftBottleCounts;
    }
    return null;
  }

  List<CartItem> get physicalItems =>
      SmartCartSelection.withGiftContainers(items);
  String? get _paidAllocationIssue {
    if (itemSnapshot == null &&
        freeQuantity > 0 &&
        items.any((item) => item.selectedVariants
            .any(SmartCartSelection.looksBottleLikeVariant))) {
      return 'Магазин не передал данные тары для подарочного объёма.';
    }
    if (selection?.usesPourFlow == true &&
        totalQuantity > 0 &&
        paidBottleCounts.isEmpty) {
      return 'Объём напитка должен совпадать с целыми бутылками.';
    }
    return null;
  }

  String? get allocationIssue {
    final issue = _paidAllocationIssue;
    if (issue != null) return issue;
    try {
      if (selection?.usesPourFlow == true) {
        selection!.giftBottleBreakdown(totalQuantity,
            retainedCounts: retainedGiftBottleCounts);
      }
      return null;
    } on StateError catch (error) {
      return error.message.toString();
    }
  }

  List<Map<String, dynamic>> toJsonForOrder() {
    final issue = _paidAllocationIssue;
    if (issue != null) throw StateError(issue);
    if (selection?.usesPourFlow == true) {
      return [
        for (final item in physicalItems) item.toJsonForOrder(freeQuantity: 0),
      ];
    }
    var paid = 0.0;
    var allocatedFree = 0.0;
    final result = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item.quantity <= 0) continue;
      paid += item.quantity;
      final free = subtractPromotionFreeQuantity(paid, promotions);
      result.add(item.toJsonForOrder(freeQuantity: free - allocatedFree));
      allocatedFree = free;
    }
    return result;
  }

  Map<int, int> get bottleCounts =>
      _bottleCounts(physicalItems, physical: true);
  Map<int, int> get paidBottleCounts => _bottleCounts(items, physical: false);

  Map<int, int> _bottleCounts(Iterable<CartItem> rows,
      {required bool physical}) {
    final currentSelection = selection;
    if (currentSelection == null || !currentSelection.usesPourFlow) {
      return const <int, int>{};
    }

    final counts = <int, int>{};
    for (final item in rows) {
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

      final ratio = (physical ? item.physicalQuantity : item.quantity) / volume;
      if ((ratio - ratio.round()).abs() > 0.0000001) return const <int, int>{};
      final count = ratio.round();
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
    final sortedItems = physicalItems.toList()
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
      final ratio = item.physicalQuantity / volume;
      if ((ratio - ratio.round()).abs() > 0.0000001) return 'Некорректная тара';
      final count = ratio.round();
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
      final currentSelection =
          snapshot == null ? null : SmartCartSelection(snapshot);
      final baseVariants = currentSelection == null
          ? SmartCartSelection.normalizeVariantMaps(groupItems
              .first.selectedVariants
              .where((variant) =>
                  !SmartCartSelection.looksBottleLikeVariant(variant))
              .toList())
          : currentSelection
              .stripBottleVariants(groupItems.first.selectedVariants);

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
        ? item.selectedVariants
            .where((variant) =>
                !SmartCartSelection.looksBottleLikeVariant(variant))
            .toList(growable: false)
        : selection.stripBottleVariants(item.selectedVariants);
    final keys = baseVariants
        .map(SmartCartSelection.variantStableKey)
        .toList(growable: false)
      ..sort();
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

  static double _bottleVolumeForCartItem(
      CartItem item, SmartCartSelection selection) {
    for (final bottle in selection.filteredBottles) {
      if (item.selectedVariants.any((variant) =>
          SmartCartSelection.variantRelationId(variant) == bottle.relationId)) {
        return selection.volumeForBottle(bottle);
      }
    }
    return 0;
  }
}
