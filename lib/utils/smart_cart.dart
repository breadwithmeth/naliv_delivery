import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../model/item.dart' as item_model;
import '../model/cart_item.dart';
import 'promotion_engine.dart';
import 'bottle_allocation.dart';
import '../core/quantity.dart';

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

  /// Container volume the shop withdrew from the range.
  ///
  /// Three-litre bottles are never allocated for a new selection. Persisted rows
  /// retain their relation, litres and tariff, but can only be reduced or removed.
  static const double withdrawnBottleVolume = 3;

  late final List<item_model.ItemOptionItem> filteredBottles =
      _filterAllowedBottles();

  /// Every relation the store identifies as a container, including volumes this client no longer
  /// offers.
  late final List<int> knownBottleRelationIds =
      bottleVariants.map((bottle) => bottle.relationId).toList(growable: false);
  late final List<int> bottleRelationIds = filteredBottles
      .map((bottle) => bottle.relationId)
      .toList(growable: false);
  late final bool usesPourFlow = containerOption != null;
  late final String defaultDisplayKey =
      displayKeyForVariants(defaultNonBottleVariants);

  /// Litres a bottle-count map represents, for both offered and withdrawn containers.
  double litersForCounts(Map<int, int> counts) {
    final volumes = {
      for (final bottle in bottleVariants)
        bottle.relationId: volumeForBottle(bottle),
    };
    return counts.entries.fold<double>(
        0, (sum, entry) => sum + (volumes[entry.key] ?? 0) * entry.value);
  }

  String? get quantityIssue {
    if (quantityUnitLabel(item.unit) == 'кг' &&
        (item.stepQuantity == null ||
            !item.stepQuantity!.isFinite ||
            item.stepQuantity! <= 0)) {
      return 'Магазин не передал шаг продажи весового товара.';
    }
    return null;
  }

  bool isWithdrawnBottleRelation(int relationId) =>
      bottleVariants.any((bottle) =>
          bottle.relationId == relationId &&
          volumeForBottle(bottle) == withdrawnBottleVolume);

  bool isWithdrawnBottleVariant(Map<String, dynamic> variant) {
    if (!isBottleVariant(variant)) return false;
    final relationId = variantRelationId(variant);
    if (relationId != null && knownBottleRelationIds.contains(relationId)) {
      return isWithdrawnBottleRelation(relationId);
    }
    return isExplicitWithdrawnBottleVariant(variant);
  }

  static bool isExplicitWithdrawnBottleVariant(Map<String, dynamic> variant) {
    final nested = variant['variant'];
    final data = nested is Map ? Map<String, dynamic>.from(nested) : variant;
    if (!looksBottleLikeVariant(data)) return false;
    final amount = variantParentItemAmount(variant) ??
        _extractVolumeFromText(
            data['item_name']?.toString() ?? data['name']?.toString() ?? '');
    return amount == withdrawnBottleVolume;
  }

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
    if (containerOption != null && filteredBottles.isEmpty) {
      return 'Тара объёмом 3 л больше не продаётся.';
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
    if (relationId != null && knownBottleRelationIds.contains(relationId)) {
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

  /// The fewest physical bottles that hold exactly [targetLiters]. The litres are what the
  /// customer picks, gift included, so the only limit besides the container set is the stock.
  Map<int, int> autoBottleBreakdown(double targetLiters) {
    if (!targetLiters.isFinite || targetLiters < 0) {
      throw ArgumentError.value(targetLiters, 'targetLiters');
    }
    if (targetLiters == 0) return const <int, int>{};
    if (targetLiters > maxAmount + 0.0000001) {
      throw StateError('Выбранный объём превышает остаток');
    }
    return _exactBottleBreakdown(targetLiters);
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

  Map<int, int> _exactBottleBreakdown(double targetLiters) {
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
    final counts = minimumBottleCounts(target, volumes);
    if (counts == null) {
      throw StateError('Нельзя точно распределить выбранный объём по таре');
    }
    final result = <int, int>{};
    for (var index = 0; index < counts.length; index++) {
      if (counts[index] > 0) {
        result[filteredBottles[index].relationId] = counts[index];
      }
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
          volumeForBottle(bottle).isFinite &&
          volumeForBottle(bottle) > 0 &&
          volumeForBottle(bottle) != withdrawnBottleVolume)
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
    required this.selection,
  });

  final String key;
  final List<CartItem> items;
  final item_model.Item? itemSnapshot;
  final List<Map<String, dynamic>> baseVariants;

  final SmartCartSelection? selection;

  CartGroupEvaluation evaluate({DateTime? now}) =>
      CartGroupEvaluation._(this, now ?? DateTime.now());

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
  double get optionsTotal => evaluate().price.optionsTotal;
  double get subtotalBeforePromotions =>
      evaluate().price.subtotalBeforePromotions;
  double get totalPrice => evaluate().price.totalPrice;
  double get freeQuantity => evaluate().freeQuantity;
  double get totalOrderQuantity => evaluate().totalOrderQuantity;
  bool get hasWithdrawnBottles {
    final currentSelection = selection;
    return items.any((item) => item.selectedVariants.any((variant) =>
        currentSelection?.isWithdrawnBottleVariant(variant) ??
        SmartCartSelection.isExplicitWithdrawnBottleVariant(variant)));
  }

  bool get canIncrease => evaluate().canIncrease;

  List<CartItem> get physicalItems => evaluate().physicalItems;

  String? get allocationIssue => evaluate().allocationIssue;

  List<Map<String, dynamic>> toJsonForOrder() => evaluate().toJsonForOrder();

  /// Physical bottles of a pour group, by container relation.
  Map<int, int> get bottleCounts => _bottleCounts(items);

  Map<int, int> _bottleCounts(Iterable<CartItem> rows) {
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

      final ratio = item.physicalQuantity / volume;
      if ((ratio - ratio.round()).abs() > 0.0000001) return const <int, int>{};
      final count = ratio.round();
      if (count <= 0) {
        continue;
      }

      counts[bottleId] = (counts[bottleId] ?? 0) + count;
    }

    return counts;
  }

  String? get bottleBreakdownLabel => evaluate().bottleBreakdownLabel;

  static List<CartDisplayGroup> groupItems(Iterable<CartItem> items) {
    final grouped = <String, List<CartItem>>{};
    final selections = <String, SmartCartSelection>{};
    for (final item in items) {
      final snapshot = SmartCartSelection.itemSnapshotFromCartItem(item);
      final selection = snapshot == null ? null : SmartCartSelection(snapshot);
      final key = _displayKeyForSelection(item, selection);
      grouped.putIfAbsent(key, () => <CartItem>[]).add(item);
      if (selection != null) selections.putIfAbsent(key, () => selection);
    }

    final result = grouped.entries.map((entry) {
      final groupItems = entry.value.toList(growable: false);
      final currentSelection = selections[entry.key];
      final snapshot = currentSelection?.item;
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
        items: List<CartItem>.unmodifiable(groupItems),
        itemSnapshot: snapshot,
        baseVariants: baseVariants,
        selection: currentSelection,
      );
    }).toList(growable: false);

    return result;
  }

  static String displayKeyForCartItem(CartItem item) {
    final snapshot = SmartCartSelection.itemSnapshotFromCartItem(item);
    final selection = snapshot == null ? null : SmartCartSelection(snapshot);
    return _displayKeyForSelection(item, selection);
  }

  static String _displayKeyForSelection(
      CartItem item, SmartCartSelection? selection) {
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

  static double _bottleVolumeForCartItem(
      CartItem item, SmartCartSelection selection) {
    // Every container the store recognises, so a row holding a withdrawn volume still resolves
    // instead of silently losing its litres.
    for (final bottle in selection.bottleVariants) {
      if (item.selectedVariants.any((variant) =>
          SmartCartSelection.variantRelationId(variant) == bottle.relationId)) {
        return selection.volumeForBottle(bottle);
      }
    }
    return 0;
  }

  /// Carts saved before pour rows held physical litres stored only the paid litres plus the
  /// retained gift bottles. Each such group becomes the bottles it represented: the gift bottles
  /// are added to the physical rows, so the customer keeps the same bottles and the same total.
  ///
  /// [legacyGifts] holds each row's old `giftBottleCounts`. A group without a usable record is
  /// given the gift the old rule derived from its paid litres, with the fewest bottles.
  static List<CartItem> migrateLegacyPourRows(
    Iterable<CartItem> rows, {
    Map<CartItem, Map<int, int>> legacyGifts = const {},
    DateTime? now,
  }) {
    final source = rows.toList(growable: false);
    final replacements = Map<CartItem, CartItem>.identity();
    final appended = Map<CartItem, List<CartItem>>.identity();
    for (final group in groupItems(source)) {
      final selection = group.selection;
      if (selection == null || !selection.usesPourFlow) continue;
      final free = subtractPromotionFreeQuantity(
          group.totalQuantity, group.promotions,
          now: now);
      if (free <= 0.0000001) continue;
      Map<int, int>? gifts;
      for (final row in group.items) {
        final retained = legacyGifts[row];
        if (retained == null) continue;
        final valid = retained.entries.every((entry) =>
                entry.value >= 0 &&
                selection.knownBottleRelationIds.contains(entry.key)) &&
            (selection.litersForCounts(retained) - free).abs() <= 0.0000001;
        if (valid) gifts = retained;
        break;
      }
      if (gifts == null) {
        try {
          gifts = selection._exactBottleBreakdown(free);
        } on StateError {
          continue;
        }
      }
      final current = {for (final row in group.items) row: row};
      for (final entry in gifts.entries) {
        if (entry.value <= 0) continue;
        final bottle = selection.bottleVariants
            .firstWhereOrNull((candidate) => candidate.relationId == entry.key);
        if (bottle == null) continue;
        final volume = selection.volumeForBottle(bottle) * entry.value;
        final holder = group.items.firstWhereOrNull((row) =>
            row.selectedVariants.any((variant) =>
                SmartCartSelection.variantRelationId(variant) == entry.key));
        if (holder != null) {
          final updated = current[holder]!;
          current[holder] =
              updated.copyWith(quantity: updated.quantity + volume);
        } else {
          appended
              .putIfAbsent(group.items.last, () => <CartItem>[])
              .add(group.items.first.copyWith(
                quantity: volume,
                stepQuantity: selection.volumeForBottle(bottle),
                selectedVariants: selection.buildVariantMaps(
                    bottle: bottle, baseVariants: group.baseVariants),
              ));
        }
      }
      replacements.addAll(current);
    }
    return [
      for (final row in source) ...[
        replacements[row] ?? row,
        ...?appended[row],
      ],
    ];
  }
}

class CartGroupEvaluation {
  CartGroupEvaluation._(this.group, this.now)
      : rows = List<CartItem>.unmodifiable(
            group.items.map((item) => item.copyWith()));

  final CartDisplayGroup group;
  final DateTime now;

  /// The persisted rows: paid units for an ordinary item, physical litres (gift included) for a
  /// pour group, whose gift is derived by [evaluatePhysicalGift] and never stored.
  final List<CartItem> rows;
  bool get _pour => group.selection?.usesPourFlow == true;
  late final double _rowsTotal =
      rows.fold<double>(0, (sum, item) => sum + item.quantity);
  late final PhysicalGiftEvaluation? _physicalGift = _pour
      ? evaluatePhysicalGift(
          physicalQuantity: _rowsTotal, promotions: group.promotions, now: now)
      : null;

  /// Paid units; for a pour group the picked litres minus the gift.
  late final double totalQuantity = _physicalGift?.paidQuantity ?? _rowsTotal;
  late final PromotionEvaluation promotion = evaluatePromotion(
      paidQuantity: totalQuantity, promotions: group.promotions, now: now);

  /// The promotion in force for this group, by the rule that applies to it.
  PromotionAward? get award => _physicalGift?.award ?? promotion.award;
  double get freeQuantity =>
      _physicalGift?.giftQuantity ?? promotion.freeQuantity;

  /// Units the customer takes home, gift included.
  double get totalOrderQuantity =>
      _pour ? _rowsTotal : totalQuantity + freeQuantity;
  late final Map<int, int> bottleCounts =
      Map<int, int>.unmodifiable(group._bottleCounts(rows));
  late final (List<CartItem>, String?) _projection = _project();
  String? get allocationIssue => _projection.$2;

  late final double incrementStep = _incrementStep();
  double _incrementStep() {
    if (!_pour) {
      return group.selection?.defaultStepQuantity ?? rows.first.stepQuantity;
    }
    var batches = 0;
    for (final count in bottleCounts.values) {
      if (count > 0) batches = batches == 0 ? count : batches.gcd(count);
    }
    return batches == 0 ? 0 : _rowsTotal / batches;
  }

  late final double nextOrderQuantity = _pour
      ? _rowsTotal + incrementStep
      : totalQuantity +
          incrementStep +
          subtractPromotionFreeQuantity(
              totalQuantity + incrementStep, group.promotions,
              now: now);

  late final bool canIncrease = _canIncrease();
  bool _canIncrease() {
    final selection = group.selection;
    return !(group.hasWithdrawnBottles ||
        allocationIssue != null ||
        selection?.containerIssue != null ||
        selection?.quantityIssue != null ||
        !incrementStep.isFinite ||
        incrementStep <= 0 ||
        (group.maxAmount != null &&
            nextOrderQuantity > group.maxAmount! + 0.0000001));
  }

  List<CartItem> get physicalItems {
    final issue = allocationIssue;
    if (issue != null) throw StateError(issue);
    return _projection.$1;
  }

  (List<CartItem>, String?) _project() {
    final selection = group.selection;
    if (group.itemSnapshot == null &&
        freeQuantity > 0 &&
        rows.any((item) => item.selectedVariants
            .any(SmartCartSelection.looksBottleLikeVariant))) {
      return (
        const [],
        'Магазин не передал данные тары для подарочного объёма.'
      );
    }
    if (_pour && _rowsTotal > 0 && bottleCounts.isEmpty) {
      return (const [], 'Объём напитка должен совпадать с целыми бутылками.');
    }
    final live = [
      for (final item in rows)
        if (item.quantity > 0) item,
    ];
    if (!_pour || freeQuantity <= 0) {
      return (List<CartItem>.unmodifiable(live), null);
    }
    // Which bottle carries the free drink is presentation only. The gift goes to the dearest
    // litres first (then the largest bottle), so a tariff that replaces the drink price never
    // costs the customer more than the single rule says.
    final order = [for (var index = 0; index < live.length; index++) index]
      ..sort((left, right) {
        final byPrice =
            live[right].paidUnitPrice.compareTo(live[left].paidUnitPrice);
        if (byPrice != 0) return byPrice;
        final byVolume =
            CartDisplayGroup._bottleVolumeForCartItem(live[right], selection!)
                .compareTo(CartDisplayGroup._bottleVolumeForCartItem(
                    live[left], selection));
        return byVolume != 0 ? byVolume : left.compareTo(right);
      });
    final projected = List<CartItem>.of(live);
    var remaining = freeQuantity;
    for (final index in order) {
      if (remaining <= 0.0000001) break;
      final take = math.min(live[index].quantity, remaining);
      final paid = live[index].quantity - take;
      projected[index] = live[index].copyWith(
          quantity: paid.abs() <= 0.0000001 ? 0 : paid,
          bottledGiftQuantity: take);
      remaining -= take;
    }
    return (List<CartItem>.unmodifiable(projected), null);
  }

  late final CartPriceBreakdown price = _calculatePrice();

  CartPriceBreakdown _calculatePrice() {
    var productSubtotal = 0.0;
    var options = 0.0;
    var paid = 0.0;
    for (final item in physicalItems) {
      final rate = item.paidUnitPrice;
      productSubtotal += rate * item.quantity;
      paid += applyPromotionsToPaidBaseTotal(
          unitPrice: rate,
          quantity: item.quantity,
          promotions: group.promotions,
          now: now);
      options += item.optionsTotalForSelection(group.selection);
    }
    final unitPrice = totalQuantity > 0 ? productSubtotal / totalQuantity : 0.0;
    return (
      productSubtotal: productSubtotal,
      optionsTotal: options,
      discount: productSubtotal - paid,
      freeQuantity: freeQuantity,
      subtotalBeforePromotions:
          productSubtotal + unitPrice * freeQuantity + options,
      totalPrice: paid + options,
    );
  }

  late final String? bottleBreakdownLabel = _bottleBreakdownLabel();

  String? _bottleBreakdownLabel() {
    final selection = group.selection;
    if (selection == null || !selection.usesPourFlow) return null;
    final rows = physicalItems.toList()
      ..sort((left, right) =>
          CartDisplayGroup._bottleVolumeForCartItem(right, selection).compareTo(
              CartDisplayGroup._bottleVolumeForCartItem(left, selection)));
    final parts = <String>[];
    for (final row in rows) {
      final volume = CartDisplayGroup._bottleVolumeForCartItem(row, selection);
      if (volume <= 0) continue;
      final ratio = row.physicalQuantity / volume;
      if ((ratio - ratio.round()).abs() > 0.0000001) return 'Некорректная тара';
      if (ratio.round() > 0) {
        parts.add('${ratio.round()}× ${selection.volumeLabel(volume)}');
      }
    }
    return parts.isEmpty ? null : parts.join(' • ');
  }

  List<Map<String, dynamic>> toJsonForOrder() {
    final issue = allocationIssue;
    if (issue != null) throw StateError(issue);
    if (group.selection?.usesPourFlow == true) {
      return [
        for (final item in physicalItems) item.toJsonForOrder(freeQuantity: 0),
      ];
    }
    var paid = 0.0;
    var allocatedFree = 0.0;
    final result = <Map<String, dynamic>>[];
    for (final item in rows) {
      if (item.quantity <= 0) continue;
      paid += item.quantity;
      final free =
          subtractPromotionFreeQuantity(paid, group.promotions, now: now);
      result.add(item.toJsonForOrder(freeQuantity: free - allocatedFree));
      allocatedFree = free;
    }
    return result;
  }
}

class CartEvaluation {
  CartEvaluation(Iterable<CartDisplayGroup> source, {DateTime? now})
      : now = now ?? DateTime.now() {
    groups = List<CartGroupEvaluation>.unmodifiable(
        source.map((group) => group.evaluate(now: this.now)));
    activeGroups = List<CartGroupEvaluation>.unmodifiable(
        groups.where((group) => group.totalOrderQuantity > 0.0000001));
  }

  final DateTime now;
  late final List<CartGroupEvaluation> groups;
  late final List<CartGroupEvaluation> activeGroups;
  late final CartPriceBreakdown price = _calculatePrice();
  double get totalPrice => price.totalPrice;

  CartPriceBreakdown _calculatePrice() {
    var productSubtotal = 0.0;
    var optionsTotal = 0.0;
    var discount = 0.0;
    var freeQuantity = 0.0;
    var subtotalBeforePromotions = 0.0;
    var total = 0.0;
    for (final group in groups) {
      final current = group.price;
      productSubtotal += current.productSubtotal;
      optionsTotal += current.optionsTotal;
      discount += current.discount;
      freeQuantity += current.freeQuantity;
      subtotalBeforePromotions += current.subtotalBeforePromotions;
      total += current.totalPrice;
    }
    return (
      productSubtotal: productSubtotal,
      optionsTotal: optionsTotal,
      discount: discount,
      freeQuantity: freeQuantity,
      subtotalBeforePromotions: subtotalBeforePromotions,
      totalPrice: total,
    );
  }

  List<Map<String, dynamic>> toJsonForOrder() => [
        for (final group in activeGroups) ...group.toJsonForOrder(),
      ];
}
