/// Унифицированная модель товара
///
/// Данная модель объединяет в себе все возможности товаров из различных частей приложения:
/// - Item из API (базовые свойства товара)
/// - CategoryItem (товары в категориях с промоакциями и расширенными опциями)
///
/// Поддерживает полный функционал: опции, промоакции, категории, изображения, видимость
class Item {
  // Основные поля товара
  final int itemId;
  final String name;
  final String? description;
  final double price;
  final String? image; // Унифицированное поле для img/image
  final String? code;
  final String? unit; // Единица измерения (шт, л, кг и т.д.)
  final double? quantity; // Базовое количество/вес одной порции

  // Категория
  final int? categoryId; // Простой ID категории
  final ItemCategory? category; // Расширенная информация о категории

  // Бизнес и видимость
  final int? businessId;
  final int? visible;
  final double? amount;

  // Шаг изменения количества (для товаров без опций)
  final double? stepQuantity;

  // Дополнительные функции
  final List<ItemOption>? options;
  final List<ItemPromotion>? promotions;

  Item({
    required this.itemId,
    required this.name,
    this.description,
    required this.price,
    this.image,
    this.code,
    this.unit,
    this.quantity,
    this.categoryId,
    this.category,
    this.businessId,
    this.visible,
    this.amount,
    this.stepQuantity,
    this.options,
    this.promotions,
  });

  /// Создание из JSON API
  factory Item.fromJson(Map<String, dynamic> json) {
    final stepQuantityValue = _parseDouble(json['step_quantity']) ?? _parseDouble(json['quantity_step']) ?? _parseDouble(json['parent_item_amount']);
    final quantityValue = _parseDouble(json['quantity']) ?? _parseDouble(json['parent_item_amount']);
    final categoryData = _asMap(json['category']);
    final options = _mapListFromDynamic(json['options']).map(ItemOption.fromJson).toList(growable: false);
    final promotions = _mapListFromDynamic(json['promotions']).map(ItemPromotion.fromJson).toList(growable: false);

    return Item(
      itemId: _parseInt(json['item_id'] ?? json['id']),
      name: _parseString(json['name']) ?? '',
      description: _parseString(json['description']),
      price: _parseDouble(json['price']) ?? 0.0,
      image: _parseString(json['image']) ?? _parseString(json['img']), // Поддержка обоих вариантов
      code: _parseString(json['code']),
      unit: _parseString(json['unit'] ?? json['unit_name'] ?? json['measure']),
      quantity: quantityValue,
      categoryId: _parseInt(json['category_id'] ?? json['categoryId']),
      category: categoryData != null ? ItemCategory.fromJson(categoryData) : null,
      businessId: _parseInt(json['business_id'] ?? json['businessId']),
      visible: json['visible'] != null ? _parseInt(json['visible']) : null,
      amount: _parseDouble(json['amount']),
      stepQuantity: stepQuantityValue,
      options: options.isEmpty ? null : options,
      promotions: promotions.isEmpty ? null : promotions,
    );
  }

  /// Создание из Map
  factory Item.fromMap(Map<String, dynamic> map) => Item.fromJson(map);

  /// Создание из CategoryItem (для миграции существующего кода)
  factory Item.fromCategoryItem(dynamic categoryItem) {
    if (categoryItem is Map<String, dynamic>) {
      return Item.fromJson(categoryItem);
    }

    // Если это объект CategoryItem, конвертируем его поля
    // Сначала пробуем взять stepQuantity из CategoryItem
    double? stepQuantity = categoryItem.stepQuantity;

    // Если stepQuantity нет, пробуем извлечь из опций
    if (stepQuantity == null && categoryItem.options != null && categoryItem.options!.isNotEmpty) {
      final firstOption = categoryItem.options!.first;
      if (firstOption.variants != null && firstOption.variants!.isNotEmpty) {
        stepQuantity = _parseDouble(firstOption.variants!.first.parentItemAmount);
      }
    }

    return Item(
      itemId: categoryItem.itemId ?? 0,
      name: categoryItem.name ?? '',
      description: categoryItem.description,
      price: _parseDouble(categoryItem.price) ?? 0.0,
      image: categoryItem.img ?? categoryItem.img,
      code: categoryItem.code,
      amount: _parseDouble(categoryItem.amount),
      categoryId: categoryItem.category?.categoryId,
      category: categoryItem.category != null ? ItemCategory.fromApiCategory(categoryItem.category) : null,
      visible: categoryItem.visible,
      unit: categoryItem.unit,
      quantity: _parseDouble(categoryItem.quantity) ?? stepQuantity,
      stepQuantity: stepQuantity,
      options: categoryItem.options != null ? (categoryItem.options as List?)?.map((opt) => ItemOption.fromCategoryItemOption(opt)).toList() : null,
      promotions: categoryItem.promotions != null
          ? (categoryItem.promotions as List?)?.map((promo) => ItemPromotion.fromCategoryItemPromotion(promo)).toList()
          : null,
    );
  }

  /// Конвертация в JSON
  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'name': name,
      if (description != null) 'description': description,
      'price': price,
      if (image != null) 'image': image,
      if (code != null) 'code': code,
      if (unit != null) 'unit': unit,
      if (quantity != null) 'quantity': quantity,
      if (categoryId != null) 'category_id': categoryId,
      if (category != null) 'category': category!.toJson(),
      if (businessId != null) 'business_id': businessId,
      if (visible != null) 'visible': visible,
      if (amount != null) 'amount': amount,
      if (stepQuantity != null) 'step_quantity': stepQuantity,
      if (options != null) 'options': options!.map((option) => option.toJson()).toList(),
      if (promotions != null) 'promotions': promotions!.map((promo) => promo.toJson()).toList(),
    };
  }

  /// Копирование с изменениями
  Item copyWith({
    int? itemId,
    String? name,
    String? description,
    double? price,
    String? image,
    String? code,
    String? unit,
    double? quantity,
    int? categoryId,
    ItemCategory? category,
    int? businessId,
    int? visible,
    double? amount,
    List<ItemOption>? options,
    List<ItemPromotion>? promotions,
  }) {
    return Item(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      image: image ?? this.image,
      code: code ?? this.code,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      businessId: businessId ?? this.businessId,
      visible: visible ?? this.visible,
      amount: amount ?? this.amount,
      options: options ?? this.options,
      promotions: promotions ?? this.promotions,
    );
  }

  /// Проверяет, виден ли товар
  bool get isVisible => visible == 1;

  /// Проверяет, есть ли изображение
  bool get hasImage => image != null && image!.isNotEmpty;

  /// Проверяет, есть ли промоакции
  bool get hasPromotions => promotions != null && promotions!.isNotEmpty;

  /// Проверяет, есть ли опции
  bool get hasOptions => options != null && options!.isNotEmpty;

  /// Получает эффективный stepQuantity
  /// Если у товара нет опций и задан stepQuantity, используем его
  /// Если есть опции, используем parent_item_amount из первой опции
  /// По умолчанию возвращает 1.0
  double get effectiveStepQuantity {
    if (quantity != null && quantity! > 0) {
      return quantity!;
    }
    // Если у товара есть опции, используем parent_item_amount из первой опции
    if (hasOptions) {
      final firstOption = options!.first;
      if (firstOption.optionItems.isNotEmpty) {
        return firstOption.optionItems.first.parentItemAmount.toDouble();
      }
    }

    // Если нет опций, используем stepQuantity из товара или 1.0 по умолчанию
    return stepQuantity ?? 1.0;
  }

  @override
  String toString() {
    return 'Item(id: $itemId, name: $name, price: $price)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Item && other.itemId == itemId;
  }

  @override
  int get hashCode => itemId.hashCode;

  // Utility functions
  static int _parseInt(dynamic value) {
    if (value is bool) return value ? 1 : 0;
    if (value is num) return value.toInt();

    final normalized = _parseString(value);
    if (normalized == null) return 0;

    final compact = normalized.replaceAll(' ', '').replaceAll(',', '.');
    return int.tryParse(compact) ?? double.tryParse(compact)?.toInt() ?? 0;
  }

  static String? _parseString(dynamic value, {bool allowEmpty = false}) {
    if (value == null) return null;

    final normalized = value.toString().trim();
    if (!allowEmpty && (normalized.isEmpty || normalized.toLowerCase() == 'null')) {
      return null;
    }

    return normalized;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, entryValue) => MapEntry(key.toString(), entryValue),
      );
    }
    return null;
  }

  static List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    if (value is Map) return <dynamic>[value];
    return const <dynamic>[];
  }

  static List<Map<String, dynamic>> _mapListFromDynamic(dynamic value) {
    return _asList(value).map(_asMap).whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();

    final normalized = _parseString(value);
    if (normalized == null) return null;

    return double.tryParse(
      normalized.replaceAll(' ', '').replaceAll(',', '.'),
    );
  }
}

/// Модель для категории товара
/// Унифицированная модель категории товаров
/// Совместима с API CategoryItem и другими источниками данных
class ItemCategory {
  final int categoryId;
  final String name;
  final int? parentId;
  final int? itemsCount;
  final List<ItemCategory>? subcategories;

  ItemCategory({
    required this.categoryId,
    required this.name,
    this.parentId,
    this.itemsCount,
    this.subcategories,
  });

  factory ItemCategory.fromJson(Map<String, dynamic> json) {
    final subcategories = Item._mapListFromDynamic(json['subcategories']).map(ItemCategory.fromJson).toList(growable: false);

    return ItemCategory(
      categoryId: Item._parseInt(json['category_id'] ?? json['id']),
      name: Item._parseString(json['name']) ?? '',
      parentId: json['parent_id'] != null || json['parent_category'] != null ? Item._parseInt(json['parent_id'] ?? json['parent_category']) : null,
      itemsCount: Item._parseInt(json['items_count']),
      subcategories: subcategories.isEmpty ? null : subcategories,
    );
  }

  /// Создание из API ItemCategory для совместимости
  factory ItemCategory.fromApiCategory(dynamic apiCategory) {
    if (apiCategory is Map<String, dynamic>) {
      return ItemCategory.fromJson(apiCategory);
    }

    return ItemCategory(
      categoryId: apiCategory.categoryId,
      name: apiCategory.name,
      parentId: apiCategory.parentCategory,
      itemsCount: null,
      subcategories: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (itemsCount != null) 'items_count': itemsCount,
      if (subcategories != null) 'subcategories': subcategories!.map((cat) => cat.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'ItemCategory(id: $categoryId, name: $name)';
  }
}

/// Модель для опции товара
class ItemOption {
  final int optionId;
  final String name;
  final int required;
  final String selection; // "SINGLE" | "MULTIPLE"
  final List<ItemOptionItem> optionItems;

  ItemOption({
    required this.optionId,
    required this.name,
    required this.required,
    required this.selection,
    required this.optionItems,
  });

  factory ItemOption.fromJson(Map<String, dynamic> json) {
    final optionItemsJson = Item._mapListFromDynamic(
      json['option_items'] ?? json['variants'],
    );

    return ItemOption(
      optionId: Item._parseInt(json['option_id']),
      name: Item._parseString(json['name']) ?? '',
      required: Item._parseInt(json['required']),
      selection: Item._parseString(json['selection']) ?? '',
      optionItems: optionItemsJson.map(ItemOptionItem.fromJson).toList(growable: false),
    );
  }

  /// Создание из CategoryItemOption для совместимости
  factory ItemOption.fromCategoryItemOption(dynamic categoryOption) {
    if (categoryOption is Map<String, dynamic>) {
      return ItemOption.fromJson(categoryOption);
    }

    return ItemOption(
      optionId: categoryOption.optionId ?? 0,
      name: categoryOption.name ?? '',
      required: categoryOption.required ? 1 : 0,
      selection: categoryOption.selection ?? '',
      optionItems: categoryOption.variants != null
          ? (categoryOption.variants as List?)?.map((item) => ItemOptionItem.fromCategoryItemOptionItem(item)).toList() ?? []
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'option_id': optionId,
      'name': name,
      'required': required,
      'selection': selection,
      'option_items': optionItems.map((item) => item.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'ItemOption(id: $optionId, name: $name, selection: $selection)';
  }
}

/// Модель для элемента опции товара
class ItemOptionItem {
  final int relationId;
  final int itemId;
  final String priceType;
  final String itemName; // Добавлено поле для имени товара
  final double price;
  final double parentItemAmount;

  ItemOptionItem({
    required this.relationId,
    required this.itemId,
    required this.priceType,
    required this.itemName,
    required this.price,
    required this.parentItemAmount,
  });

  factory ItemOptionItem.fromJson(Map<String, dynamic> json) {
    return ItemOptionItem(
      relationId: Item._parseInt(json['relation_id']),
      itemId: Item._parseInt(json['item_id']),
      priceType: Item._parseString(json['price_type']) ?? '',
      itemName: Item._parseString(json['item_name'] ?? json['name']) ?? '', // Добавлено поле для имени товара
      price: Item._parseDouble(json['price']) ?? 0.0,
      parentItemAmount: Item._parseDouble(json['parent_item_amount']) ?? 0.0,
    );
  }

  /// Создание из CategoryItemOptionItem для совместимости
  factory ItemOptionItem.fromCategoryItemOptionItem(dynamic categoryOptionItem) {
    if (categoryOptionItem is Map<String, dynamic>) {
      return ItemOptionItem.fromJson(categoryOptionItem);
    }

    return ItemOptionItem(
      relationId: categoryOptionItem.relationId,
      itemId: categoryOptionItem.itemId,
      priceType: categoryOptionItem.priceType,
      itemName: categoryOptionItem.itemName ?? '', // Добавлено поле для имени товара
      price: categoryOptionItem.price,
      parentItemAmount: (categoryOptionItem.parentItemAmount as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'relation_id': relationId,
      'item_id': itemId,
      'price_type': priceType,
      'price': price,
      'parent_item_amount': parentItemAmount,
    };
  }

  @override
  String toString() {
    return 'ItemOptionItem(relationId: $relationId, itemId: $itemId, priceType: $priceType, price: $price)';
  }
}

/// Модель для промоакции товара
class ItemPromotion {
  final int promotionId;
  final String name;
  final String? description;
  final String discountType; // "PERCENT" | "FIXED" | "SUBTRACT"
  final double discountValue;
  final int baseAmount;
  final int addAmount;
  final DateTime? startDate;
  final DateTime? endDate;

  ItemPromotion({
    required this.promotionId,
    required this.name,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.baseAmount = 0,
    this.addAmount = 0,
    this.startDate,
    this.endDate,
  });

  factory ItemPromotion.fromJson(Map<String, dynamic> json) {
    final rawType = Item._parseString(json['discount_type'] ?? json['type']) ?? '';
    final rawValue = Item._parseDouble(json['discount_value']) ?? Item._parseDouble(json['discount']) ?? 0.0;
    // Map API "DISCOUNT" type to internal "PERCENT"
    final mappedType = rawType == 'DISCOUNT' ? 'PERCENT' : rawType;

    return ItemPromotion(
      promotionId: Item._parseInt(json['promotion_id'] ?? json['detail_id']),
      name: Item._parseString(json['name']) ?? '',
      description: Item._parseString(json['description']),
      discountType: mappedType,
      discountValue: rawValue,
      baseAmount: Item._parseInt(json['base_amount'] ?? json['baseAmount']),
      addAmount: Item._parseInt(json['add_amount'] ?? json['addAmount']),
      startDate: DateTime.tryParse(Item._parseString(json['start_date']) ?? ''),
      endDate: DateTime.tryParse(Item._parseString(json['end_date']) ?? ''),
    );
  }

  /// Создание из CategoryItemPromotion для совместимости2
  factory ItemPromotion.fromCategoryItemPromotion(dynamic categoryPromotion) {
    if (categoryPromotion is Map<String, dynamic>) {
      return ItemPromotion.fromJson(categoryPromotion);
    }

    final rawType = categoryPromotion.type ?? '';
    // Map API "DISCOUNT" type to internal "PERCENT"
    final mappedType = rawType == 'DISCOUNT' ? 'PERCENT' : rawType;

    return ItemPromotion(
      promotionId: categoryPromotion.detailId ?? 0,
      name: categoryPromotion.name ?? '',
      description: categoryPromotion.formattedDescription ?? categoryPromotion.name,
      discountType: mappedType,
      discountValue: categoryPromotion.discount ?? 0.0,
      baseAmount: categoryPromotion.baseAmount ?? 0,
      addAmount: categoryPromotion.addAmount ?? 0,
      startDate: null,
      endDate: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'promotion_id': promotionId,
      'name': name,
      if (description != null) 'description': description,
      'discount_type': discountType,
      'discount_value': discountValue,
      'base_amount': baseAmount,
      'add_amount': addAmount,
      if (startDate != null) 'start_date': startDate!.toIso8601String(),
      if (endDate != null) 'end_date': endDate!.toIso8601String(),
    };
  }

  /// Проверяет, активна ли промоакция сейчас
  bool get isActive {
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  /// Вычисляет цену с учетом промоакции
  double calculateDiscountedPrice(double originalPrice) {
    if (!isActive) return originalPrice;

    switch (discountType) {
      case 'PERCENT':
        return originalPrice * (1 - discountValue / 100);
      case 'FIXED':
        return (originalPrice - discountValue).clamp(0, double.infinity);
      default:
        return originalPrice;
    }
  }

  double calculateSavings(double originalPrice) {
    final savings = originalPrice - calculateDiscountedPrice(originalPrice);
    return savings.clamp(0, originalPrice).toDouble();
  }

  int calculateEffectiveDiscountPercent(double originalPrice) {
    if (!isActive || originalPrice <= 0) return 0;

    switch (discountType) {
      case 'PERCENT':
        return discountValue.round();
      case 'FIXED':
        final discountedPrice = calculateDiscountedPrice(originalPrice);
        return ((1 - discountedPrice / originalPrice) * 100).round();
      default:
        return 0;
    }
  }

  @override
  String toString() {
    return 'ItemPromotion(id: $promotionId, name: $name, discount: $discountValue $discountType)';
  }
}

/// Модель для варианта товара (для будущего использования)
class ItemVariant {
  final int variantId;
  final String name;
  final double? priceModifier;
  final String? image;
  final Map<String, dynamic>? attributes;

  ItemVariant({
    required this.variantId,
    required this.name,
    this.priceModifier,
    this.image,
    this.attributes,
  });

  factory ItemVariant.fromJson(Map<String, dynamic> json) {
    return ItemVariant(
      variantId: Item._parseInt(json['variant_id']),
      name: Item._parseString(json['name']) ?? '',
      priceModifier: Item._parseDouble(json['price_modifier']),
      image: Item._parseString(json['image']),
      attributes: Item._asMap(json['attributes']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'variant_id': variantId,
      'name': name,
      if (priceModifier != null) 'price_modifier': priceModifier,
      if (image != null) 'image': image,
      if (attributes != null) 'attributes': attributes,
    };
  }

  @override
  String toString() {
    return 'ItemVariant(id: $variantId, name: $name)';
  }
}
