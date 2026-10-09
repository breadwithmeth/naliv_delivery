import 'package:flutter/foundation.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/utils/address_storage_service.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/order_ui_helpers.dart' as order_ui;
import 'package:naliv_delivery/utils/smart_cart.dart';
import 'package:naliv_delivery/utils/promotion_engine.dart';

class RepeatOrderException implements Exception {
  const RepeatOrderException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RepeatOrderResult {
  const RepeatOrderResult({
    required this.order,
    required this.deliveryType,
    required this.business,
    required this.addedItemsCount,
    required this.skippedItems,
    this.restoredAddress,
  });

  final Map<String, dynamic> order;
  final String deliveryType;
  final Map<String, dynamic> business;
  final int addedItemsCount;
  final List<String> skippedItems;
  final Map<String, dynamic>? restoredAddress;

  bool get hasSkippedItems => skippedItems.isNotEmpty;
}

class RepeatOrderBuildResult {
  const RepeatOrderBuildResult({
    required this.items,
    required this.skippedItems,
  });

  final List<CartItem> items;
  final List<String> skippedItems;
}

class RepeatOrderService {
  static Future<RepeatOrderResult> repeatOrderIntoCart({
    required Map<String, dynamic> sourceOrder,
    required CartProvider cartProvider,
    required BusinessProvider businessProvider,
  }) async {
    await cartProvider.ensureLoaded();
    if (cartProvider.hasActiveItems && cartProvider.businessId == null) {
      throw const RepeatOrderException(
          'Магазин текущей корзины неизвестен. Корзина не изменена.');
    }
    await businessProvider.loadSavedBusiness();
    final previousBusiness = businessProvider.selectedBusiness;
    final order = await _resolveOrderForRepeat(sourceOrder);
    final business = extractBusiness(order);
    if (business == null) {
      throw const RepeatOrderException(
          'Не удалось определить магазин этого заказа.');
    }

    final deliveryType = resolveDeliveryType(order);
    final buildResult = buildCartItemsFromOrder(order);
    if (buildResult.items.isEmpty) {
      throw const RepeatOrderException(
          'Не удалось восстановить товары из этого заказа.');
    }

    if (!await businessProvider.setSelectedBusiness(business)) {
      throw const RepeatOrderException(
          'Не удалось сохранить магазин. Корзина не изменена.');
    }

    final businessId = _businessIdOf(business)!;
    if (!await cartProvider.replaceForBusiness(
        businessId, buildResult.items)) {
      final restored =
          await businessProvider.setSelectedBusiness(previousBusiness);
      throw RepeatOrderException(restored
          ? 'Не удалось восстановить товары. Исходная корзина не изменена.'
          : 'Исходная корзина не изменена, но не удалось восстановить выбранный магазин.');
    }

    final restoredAddress = extractDeliveryAddress(order);
    if (deliveryType == 'DELIVERY' && restoredAddress != null) {
      await AddressStorageService.saveSelectedAddress(restoredAddress);
    }

    return RepeatOrderResult(
      order: order,
      deliveryType: deliveryType,
      business: business,
      addedItemsCount: buildResult.items.length,
      skippedItems: buildResult.skippedItems,
      restoredAddress: restoredAddress,
    );
  }

  @visibleForTesting
  static Future<Map<String, dynamic>> resolveOrderForTesting(
      Map<String, dynamic> sourceOrder) {
    return _resolveOrderForRepeat(sourceOrder);
  }

  static Future<Map<String, dynamic>> _resolveOrderForRepeat(
      Map<String, dynamic> sourceOrder) async {
    final inlineItems = _asMapList(sourceOrder['items']);
    if (inlineItems.isNotEmpty) {
      return sourceOrder;
    }

    final orderId = _asInt(sourceOrder['order_id']);
    if (orderId == null) {
      return sourceOrder;
    }

    final details = await ApiService.getOrderDetails(orderId);
    if (details == null) {
      return sourceOrder;
    }

    return _deepMerge(sourceOrder, details);
  }

  @visibleForTesting
  static RepeatOrderBuildResult buildCartItemsFromOrder(
      Map<String, dynamic> order) {
    final businessId = _businessIdOf(extractBusiness(order));
    final orderItems = _asMapList(order['items']);
    final builtItems = <CartItem>[];
    final skippedItems = <String>[];

    for (final orderItem in orderItems) {
      final cartItem =
          _cartItemFromOrderItem(orderItem, businessId: businessId);
      if (cartItem == null) {
        final skippedName = _firstNonEmptyString([
          orderItem['name'],
          orderItem['item_name'],
          orderItem['title'],
        ]);
        skippedItems.add(skippedName ?? 'Товар');
        continue;
      }
      builtItems.add(cartItem);
    }

    final recovered = <CartItem>[];
    for (final group in CartDisplayGroup.groupItems(builtItems)) {
      final selection = group.selection;
      if (group.hasWithdrawnBottles || selection?.containerIssue != null) {
        skippedItems.add('${group.name}: выбранная тара больше не продаётся');
        continue;
      }
      if (selectSubtractPromotion(group.promotions,
              paidQuantity: group.totalQuantity) ==
          null) {
        recovered.addAll(group.items);
        continue;
      }
      if (selection?.usesPourFlow != true) {
        if (group.items.any((item) => item.selectedVariants
            .any(SmartCartSelection.looksBottleLikeVariant))) {
          skippedItems.add('${group.name}: магазин не передал данные тары');
          continue;
        }
        final paid = subtractPromotionPaidQuantityForPhysicalQuantity(
            group.totalQuantity, group.promotions);
        final step = group.items.first.stepQuantity;
        if (paid == null ||
            !step.isFinite ||
            step <= 0 ||
            (paid / step - (paid / step).round()).abs() > 0.0000001) {
          skippedItems.add('${group.name}: нельзя точно восстановить количество');
          continue;
        }
        var remaining = paid;
        for (final row in group.items) {
          final quantity = remaining < row.quantity ? remaining : row.quantity;
          if (quantity > 0) recovered.add(row.copyWith(quantity: quantity));
          remaining -= quantity;
        }
        continue;
      }
      final paid = subtractPromotionPaidQuantityForPhysicalQuantity(
          group.totalQuantity, group.promotions);
      if (paid == null || group.paidBottleCounts.isEmpty) {
        skippedItems
            .add('${group.name}: нельзя точно восстановить объём и тару');
        continue;
      }
      try {
        final gifts = group.selection!
            .giftBottleBreakdown(paid, availableCounts: group.paidBottleCounts);
        final giftRows = Map<int, int>.from(gifts);
        final paidRows = <CartItem>[];
        for (final row in group.items) {
          final bottle = group.selection!.filteredBottles.singleWhere(
              (bottle) => row.selectedVariants.any((variant) =>
                  SmartCartSelection.variantRelationId(variant) ==
                  bottle.relationId));
          final volume = group.selection!.volumeForBottle(bottle);
          final count = (row.quantity / volume).round();
          final giftCount = (giftRows[bottle.relationId] ?? 0).clamp(0, count);
          giftRows[bottle.relationId] =
              (giftRows[bottle.relationId] ?? 0) - giftCount;
          final paidQuantity = row.quantity - giftCount * volume;
          if (paidQuantity > 0) {
            paidRows.add(
                row.copyWith(quantity: paidQuantity, giftBottleCounts: gifts));
          }
        }
        recovered.addAll(paidRows);
      } on StateError {
        skippedItems
            .add('${group.name}: нельзя точно восстановить объём и тару');
      }
    }
    return RepeatOrderBuildResult(
      items: recovered,
      skippedItems: skippedItems,
    );
  }

  @visibleForTesting
  static String resolveDeliveryType(Map<String, dynamic> order) {
    final explicit = order['delivery_type']?.toString().trim().toUpperCase();
    if (explicit == 'PICKUP' || explicit == 'DELIVERY') {
      return explicit!;
    }
    return order_ui.isPickupOrder(order) ? 'PICKUP' : 'DELIVERY';
  }

  static Map<String, dynamic>? resolveBusiness(Map<String, dynamic> order) {
    return extractBusiness(order);
  }

  @visibleForTesting
  static Map<String, dynamic>? extractBusiness(Map<String, dynamic> order) {
    final business = _asMap(order['business']);
    if (business != null && _businessIdOf(business) != null) {
      return business;
    }

    final businessId = _asInt(order['business_id'] ?? order['businessId']);
    if (businessId == null) {
      return null;
    }

    final result = <String, dynamic>{
      'id': businessId,
    };

    final businessName = _firstNonEmptyString([
      order['business_name'],
      business?['name'],
    ]);
    final businessAddress = _firstNonEmptyString([
      order['business_address'],
      business?['address'],
    ]);

    if (businessName != null) {
      result['name'] = businessName;
    }
    if (businessAddress != null) {
      result['address'] = businessAddress;
    }

    return result;
  }

  @visibleForTesting
  static Map<String, dynamic>? extractDeliveryAddress(
      Map<String, dynamic> order) {
    if (resolveDeliveryType(order) != 'DELIVERY') {
      return null;
    }

    final address = _asMap(order['delivery_address']);
    if (address == null) {
      return null;
    }

    final lat = _asDouble(address['lat'] ?? _asMap(address['point'])?['lat']);
    final lon = _asDouble(address['lon'] ?? _asMap(address['point'])?['lon']);
    final addressText = _firstNonEmptyString([
      address['address'],
      address['name'],
    ]);

    if ((addressText == null || addressText.isEmpty) &&
        lat == null &&
        lon == null) {
      return null;
    }

    final result = <String, dynamic>{
      if (addressText != null) 'address': addressText,
      'street': _firstNonEmptyString([address['street']]) ?? '',
      'house': _firstNonEmptyString([address['house']]) ?? '',
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      'entrance': _firstNonEmptyString([address['entrance']]) ?? '',
      'floor': _firstNonEmptyString([address['floor']]) ?? '',
      'apartment': _firstNonEmptyString([address['apartment']]) ?? '',
      'comment': _firstNonEmptyString([
            address['comment'],
            address['other'],
            address['extra'],
            order['extra'],
          ]) ??
          '',
      if (_firstNonEmptyString([address['city']]) != null)
        'city': _firstNonEmptyString([address['city']]),
      if (_firstNonEmptyString([address['country']]) != null)
        'country': _firstNonEmptyString([address['country']]),
      if (lat != null || lon != null)
        'point': <String, dynamic>{
          if (lat != null) 'lat': lat,
          if (lon != null) 'lon': lon,
        },
      'source': 'repeat_order',
      'timestamp': DateTime.now().toIso8601String(),
    };

    return result;
  }

  static CartItem? _cartItemFromOrderItem(
    Map<String, dynamic> orderItem, {
    required int? businessId,
  }) {
    final itemId = _asInt(orderItem['item_id'] ?? orderItem['id']);
    final quantity = _resolveQuantity(orderItem);
    if (itemId == null || quantity <= 0) {
      return null;
    }

    final selectedVariants = _extractSelectedVariants(orderItem);
    final snapshot = _resolveSnapshot(orderItem,
        businessId: businessId, selectedVariants: selectedVariants);
    final promotions = _extractPromotions(orderItem, snapshot);
    final stepQuantity =
        _resolveStepQuantity(orderItem, snapshot, selectedVariants);
    final itemName = _firstNonEmptyString([
          orderItem['name'],
          orderItem['item_name'],
          snapshot?['name'],
        ]) ??
        'Товар';
    final image = _firstNonEmptyString([
      orderItem['img'],
      orderItem['image'],
      orderItem['item_img'],
      snapshot?['image'],
      snapshot?['img'],
    ]);
    var unitPrice = _resolveUnitPrice(orderItem, snapshot, quantity);
    var resolvedVariants = selectedVariants;
    final draft = CartItem(
        itemId: itemId,
        name: itemName,
        price: unitPrice,
        quantity: quantity,
        stepQuantity: stepQuantity,
        selectedVariants: selectedVariants,
        promotions: promotions,
        itemData: snapshot);
    final catalog = draft.snapshotItem;
    if (selectedVariants.any((variant) =>
        catalog == null
            ? SmartCartSelection.isExplicitWithdrawnBottleVariant(variant)
            : SmartCartSelection(catalog).isWithdrawnBottleVariant(variant))) {
      return null;
    }
    if (catalog != null && SmartCartSelection(catalog).usesPourFlow) {
      unitPrice = catalog.price;
      final selection = SmartCartSelection(catalog);
      resolvedVariants = [
        for (final selected in selectedVariants)
          for (final option in catalog.options!)
            for (final variant in option.optionItems)
              if (variant.relationId ==
                  SmartCartSelection.variantRelationId(selected))
                {
                  ...selected,
                  'price': variant.price,
                  'price_type': variant.priceType,
                  'item_name': variant.itemName,
                  'parent_item_amount': selection.knownBottleRelationIds
                          .contains(variant.relationId)
                      ? selection.volumeForBottle(variant)
                      : variant.parentItemAmount,
                  'required': option.required,
                },
      ];
      if (resolvedVariants.length != selectedVariants.length) return null;
      final selectedBottles = selection.filteredBottles.where((bottle) =>
          resolvedVariants.any((variant) =>
              SmartCartSelection.variantRelationId(variant) ==
              bottle.relationId));
      if (selectedBottles.length != 1) return null;
      final volume = selection.volumeForBottle(selectedBottles.single);
      if ((quantity / volume - (quantity / volume).round()).abs() > 0.0000001) {
        return null;
      }
    }

    return CartItem(
      itemId: itemId,
      name: itemName,
      price: unitPrice,
      quantity: quantity,
      stepQuantity: stepQuantity,
      image: image,
      itemType: _firstNonEmptyString([orderItem['item_type']]),
      packagingType: _firstNonEmptyString([orderItem['packaging_type']]),
      selectedVariants: resolvedVariants,
      promotions: promotions,
      itemData: snapshot,
      maxAmount: _resolveMaxAmount(orderItem, snapshot),
    );
  }

  static double _resolveQuantity(Map<String, dynamic> orderItem) {
    return _asDouble(orderItem['amount'] ??
            orderItem['quantity'] ??
            orderItem['count']) ??
        0;
  }

  static double _resolveUnitPrice(
    Map<String, dynamic> orderItem,
    Map<String, dynamic>? snapshot,
    double quantity,
  ) {
    final directPrice = _asDouble(
        orderItem['price'] ?? orderItem['unit_price'] ?? snapshot?['price']);
    if (directPrice != null && directPrice > 0) {
      return directPrice;
    }

    final lineTotal = _asDouble(
        orderItem['total_cost'] ?? orderItem['total'] ?? orderItem['sum']);
    if (lineTotal != null && lineTotal > 0 && quantity > 0) {
      return lineTotal / quantity;
    }

    return 0;
  }

  static double _resolveStepQuantity(
    Map<String, dynamic> orderItem,
    Map<String, dynamic>? snapshot,
    List<Map<String, dynamic>> selectedVariants,
  ) {
    if (snapshot != null) {
      final item = Item.fromJson(snapshot);
      final selection = SmartCartSelection(item);
      if (selection.usesPourFlow) {
        for (final bottle in selection.bottleVariants) {
          if (selectedVariants.any((variant) =>
              SmartCartSelection.variantRelationId(variant) ==
              bottle.relationId)) {
            return selection.volumeForBottle(bottle);
          }
        }
      }
    }
    final explicitStep = _asDouble(orderItem['step_quantity'] ??
        orderItem['quantity_step'] ??
        snapshot?['step_quantity'] ??
        snapshot?['quantity_step']);
    if (explicitStep != null && explicitStep.isFinite && explicitStep > 0) {
      return explicitStep;
    }
    for (final variant in selectedVariants) {
      if (!SmartCartSelection.looksBottleLikeVariant(variant)) continue;
      final parent = SmartCartSelection.variantParentItemAmount(variant);
      if (parent != null && parent.isFinite && parent > 0) return parent;
    }
    return 1.0;
  }

  static double? _resolveMaxAmount(
    Map<String, dynamic> orderItem,
    Map<String, dynamic>? snapshot,
  ) {
    final raw = _asDouble(snapshot?['amount'] ??
        orderItem['available_amount'] ??
        orderItem['max_amount']);
    if (raw == null || raw <= 0) {
      return null;
    }
    return raw;
  }

  static List<Map<String, dynamic>> _extractPromotions(
    Map<String, dynamic> orderItem,
    Map<String, dynamic>? snapshot,
  ) {
    final direct = _asMapList(orderItem['promotions']);
    if (direct.isNotEmpty) {
      return direct;
    }
    return _asMapList(snapshot?['promotions']);
  }

  static List<Map<String, dynamic>> _extractSelectedVariants(
      Map<String, dynamic> orderItem) {
    final variants = <Map<String, dynamic>>[];
    final candidates = <List<Map<String, dynamic>>>[
      _asMapList(orderItem['options']),
      _asMapList(orderItem['selected_variants']),
      _asMapList(orderItem['variants']),
      _asMapList(orderItem['selected_options']),
    ];

    for (final candidateList in candidates) {
      for (final candidate in candidateList) {
        final variant = _normalizeVariant(candidate);
        if (variant == null) {
          continue;
        }
        variants.add(variant);
      }

      if (variants.isNotEmpty) {
        break;
      }
    }

    variants.sort((left, right) =>
        _variantStableKey(left).compareTo(_variantStableKey(right)));
    return variants;
  }

  static Map<String, dynamic>? _normalizeVariant(Map<String, dynamic> raw) {
    final nestedVariant = _asMap(raw['variant']);
    final relationId = _asInt(
      raw['option_item_relation_id'] ??
          raw['relation_id'] ??
          raw['variant_id'] ??
          nestedVariant?['relation_id'] ??
          nestedVariant?['variant_id'],
    );
    final itemId = _asInt(
      raw['item_id'] ??
          raw['option_item_id'] ??
          raw['variant_item_id'] ??
          nestedVariant?['item_id'],
    );
    final itemName = _firstNonEmptyString([
      raw['item_name'],
      raw['name'],
      nestedVariant?['item_name'],
      nestedVariant?['name'],
    ]);
    final price = _asDouble(
        raw['price'] ?? raw['option_price'] ?? nestedVariant?['price']);
    final parentItemAmount = _asDouble(
      raw['parent_item_amount'] ??
          raw['variant_parent_item_amount'] ??
          nestedVariant?['parent_item_amount'],
    );

    if (relationId == null && itemId == null && itemName == null) {
      return null;
    }

    return <String, dynamic>{
      if (relationId != null) 'variant_id': relationId,
      if (relationId != null) 'relation_id': relationId,
      if (itemId != null) 'item_id': itemId,
      if (itemName != null) 'item_name': itemName,
      if (_firstNonEmptyString(
              [raw['price_type'], nestedVariant?['price_type']]) !=
          null)
        'price_type': _firstNonEmptyString(
            [raw['price_type'], nestedVariant?['price_type']]),
      if (price != null) 'price': price,
      if (parentItemAmount != null) 'parent_item_amount': parentItemAmount,
      'required': _asInt(raw['required']) ?? 0,
    };
  }

  static Map<String, dynamic>? _resolveSnapshot(
    Map<String, dynamic> orderItem, {
    required int? businessId,
    required List<Map<String, dynamic>> selectedVariants,
  }) {
    final explicitCandidates = <Map<String, dynamic>>[
      ...[
        orderItem['item_data'],
        orderItem['item'],
        orderItem['catalog_item'],
        orderItem['product'],
      ].map(_asMap).whereType<Map<String, dynamic>>(),
    ];

    for (final candidate in explicitCandidates) {
      if (_asInt(candidate['item_id'] ?? candidate['id']) == null) {
        continue;
      }
      return candidate;
    }

    final itemId = _asInt(orderItem['item_id'] ?? orderItem['id']);
    if (itemId == null) {
      return null;
    }

    final price =
        _resolveUnitPrice(orderItem, null, _resolveQuantity(orderItem));
    final stepQuantity =
        _resolveStepQuantity(orderItem, null, selectedVariants);
    final image = _firstNonEmptyString([
      orderItem['image'],
      orderItem['img'],
      orderItem['item_img'],
    ]);

    return <String, dynamic>{
      'item_id': itemId,
      'name':
          _firstNonEmptyString([orderItem['name'], orderItem['item_name']]) ??
              'Товар',
      'price': price,
      if (image != null) 'image': image,
      if (image != null) 'img': image,
      'quantity': stepQuantity,
      'step_quantity': stepQuantity,
      if (businessId != null) 'business_id': businessId,
      for (final key in const [
        'unit',
        'unit_name',
        'measure',
        'item_type',
        'packaging_type',
        'material',
        'country_name',
        'volume_liters',
        'weight_kilograms',
        'alcohol_percent',
      ])
        if (orderItem[key] != null) key: orderItem[key],
      if (_asMap(orderItem['category']) != null)
        'category': _asMap(orderItem['category']),
      if (_extractPromotions(orderItem, null).isNotEmpty)
        'promotions': _extractPromotions(orderItem, null),
    };
  }

  static Map<String, dynamic> _deepMerge(
    Map<String, dynamic> base,
    Map<String, dynamic> overlay,
  ) {
    final result = <String, dynamic>{...base};
    for (final entry in overlay.entries) {
      final existingMap = _asMap(result[entry.key]);
      final incomingMap = _asMap(entry.value);
      if (existingMap != null && incomingMap != null) {
        result[entry.key] = _deepMerge(existingMap, incomingMap);
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  static int? _businessIdOf(Map<String, dynamic>? business) {
    return _asInt(
        business?['id'] ?? business?['business_id'] ?? business?['businessId']);
  }

  static String _variantStableKey(Map<String, dynamic> variant) {
    final relationId = _asInt(variant['relation_id'] ?? variant['variant_id']);
    if (relationId != null) {
      return relationId.toString();
    }
    return '${variant['item_id'] ?? ''}|${variant['item_name'] ?? ''}|${variant['parent_item_amount'] ?? ''}';
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value
          .map((key, entryValue) => MapEntry(key.toString(), entryValue));
    }
    return null;
  }

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is List) {
      return value
          .map(_asMap)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }
    final single = _asMap(value);
    if (single != null) {
      return <Map<String, dynamic>>[single];
    }
    return const <Map<String, dynamic>>[];
  }

  static int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  static double? _asDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }

  static String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final normalized = value?.toString().trim();
      if (normalized != null &&
          normalized.isNotEmpty &&
          normalized.toLowerCase() != 'null') {
        return normalized;
      }
    }
    return null;
  }
}
