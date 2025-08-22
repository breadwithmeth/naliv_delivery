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

  // Категория
  final int? categoryId; // Простой ID категории
  final ItemCategory? category; // Расширенная информация о категории

  // Бизнес и видимость
  final int? businessId;
  final int? visible;
  final int? amount;

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
    final stepQuantityValue = _parseDouble(json['step_quantity']) ??
        _parseDouble(json['quantity_step']) ??
        _parseDouble(json['parent_item_amount']);

    // Debug вывод для отладки
    print('=== Item.fromJson DEBUG ===');
    print('Item ID: ${json['item_id']}');
    print('Name: ${json['name']}');
    print('step_quantity: ${json['step_quantity']}');
    print('quantity_step: ${json['quantity_step']}');
    print('parent_item_amount: ${json['parent_item_amount']}');
    print('Parsed stepQuantity: $stepQuantityValue');
    print('===========================');

    return Item(
      itemId: _parseInt(json['item_id']),
      name: json['name'] ?? '',
      description: json['description'],
      price: _parseDouble(json['price']) ?? 0.0,
      image: json['image'] ?? json['img'], // Поддержка обоих вариантов
      code: json['code'],
      categoryId: _parseInt(json['category_id']),
      category: json['category'] != null
          ? ItemCategory.fromJson(json['category'])
          : null,
      businessId: _parseInt(json['business_id']),
      visible: _parseInt(json['visible']),
      amount: _parseInt(json['amount']),
      stepQuantity: stepQuantityValue,
      options: json['options'] != null
          ? (json['options'] as List)
              .map((option) => ItemOption.fromJson(option))
              .toList()
          : null,
      promotions: json['promotions'] != null
          ? (json['promotions'] as List)
              .map((promotion) => ItemPromotion.fromJson(promotion))
              .toList()
          : null,
    );
  }

  /// Создание из Map
  factory Item.fromMap(Map<String, dynamic> map) => Item.fromJson(map);

  /// Создание из CategoryItem (для миграции существующего кода)
  factory Item.fromCategoryItem(dynamic categoryItem) {
    if (categoryItem is Map<String, dynamic>) {
      print('=== Item.fromCategoryItem (Map) DEBUG ===');
      print('Item ID: ${categoryItem['item_id']}');
      print('Name: ${categoryItem['name']}');
      print('step_quantity: ${categoryItem['step_quantity']}');
      print('quantity_step: ${categoryItem['quantity_step']}');
      print('parent_item_amount: ${categoryItem['parent_item_amount']}');
      print('amount: ${categoryItem['amount']}');
      print('==========================================');
      return Item.fromJson(categoryItem);
    }

    print('=== Item.fromCategoryItem (Object) DEBUG ===');
    print('Item ID: ${categoryItem.itemId}');
    print('Name: ${categoryItem.name}');
    print('CategoryItem stepQuantity: ${categoryItem.stepQuantity}');
    print('amount: ${categoryItem.amount}');
    print(
        'Has options: ${categoryItem.options != null && categoryItem.options!.isNotEmpty}');
    print('=============================================');

    // Если это объект CategoryItem, конвертируем его поля
    // Сначала пробуем взять stepQuantity из CategoryItem
    double? stepQuantity = categoryItem.stepQuantity;

    // Если stepQuantity нет, пробуем извлечь из опций
    if (stepQuantity == null &&
        categoryItem.options != null &&
        categoryItem.options!.isNotEmpty) {
      final firstOption = categoryItem.options!.first;
      if (firstOption.variants != null && firstOption.variants!.isNotEmpty) {
        stepQuantity = firstOption.variants!.first.parentItemAmount.toDouble();
        print('Found stepQuantity from options: $stepQuantity');
      }
    }

    print('Final stepQuantity: $stepQuantity');

    return Item(
      itemId: categoryItem.itemId ?? 0,
      name: categoryItem.name ?? '',
      description: categoryItem.description,
      price: categoryItem.price ?? 0.0,
      image: categoryItem.img ?? categoryItem.img,
      code: categoryItem.code,
      amount: categoryItem.amount,
      categoryId: categoryItem.category?.categoryId,
      category: categoryItem.category != null
          ? ItemCategory.fromApiCategory(categoryItem.category)
          : null,
      visible: categoryItem.visible,
      stepQuantity: stepQuantity,
      options: categoryItem.options != null
          ? (categoryItem.options as List?)
              ?.map((opt) => ItemOption.fromCategoryItemOption(opt))
              .toList()
          : null,
      promotions: categoryItem.promotions != null
          ? (categoryItem.promotions as List?)
              ?.map((promo) => ItemPromotion.fromCategoryItemPromotion(promo))
              .toList()
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
      if (categoryId != null) 'category_id': categoryId,
      if (category != null) 'category': category!.toJson(),
      if (businessId != null) 'business_id': businessId,
      if (visible != null) 'visible': visible,
      if (amount != null) 'amount': amount,
      if (stepQuantity != null) 'step_quantity': stepQuantity,
      if (options != null)
        'options': options!.map((option) => option.toJson()).toList(),
      if (promotions != null)
        'promotions': promotions!.map((promo) => promo.toJson()).toList(),
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
    int? categoryId,
    ItemCategory? category,
    int? businessId,
    int? visible,
    int? amount,
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
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
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
    return ItemCategory(
      categoryId: Item._parseInt(json['category_id']),
      name: json['name'] ?? '',
      parentId: Item._parseInt(json['parent_id']),
      itemsCount: Item._parseInt(json['items_count']),
      subcategories: json['subcategories'] != null
          ? (json['subcategories'] as List)
              .map((cat) => ItemCategory.fromJson(cat))
              .toList()
          : null,
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
      if (subcategories != null)
        'subcategories': subcategories!.map((cat) => cat.toJson()).toList(),
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
    return ItemOption(
      optionId: Item._parseInt(json['option_id']),
      name: json['name'] ?? '',
      required: Item._parseInt(json['required']),
      selection: json['selection'] ?? '',
      optionItems: (json['option_items'] as List? ?? [])
          .map((item) => ItemOptionItem.fromJson(item))
          .toList(),
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
          ? (categoryOption.variants as List?)
                  ?.map(
                      (item) => ItemOptionItem.fromCategoryItemOptionItem(item))
                  .toList() ??
              []
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
  final String item_name; // Добавлено поле для имени товара
  final double price;
  final int parentItemAmount;

  ItemOptionItem({
    required this.relationId,
    required this.itemId,
    required this.priceType,
    required this.item_name,
    required this.price,
    required this.parentItemAmount,
  });

  factory ItemOptionItem.fromJson(Map<String, dynamic> json) {
    return ItemOptionItem(
      relationId: Item._parseInt(json['relation_id']),
      itemId: Item._parseInt(json['item_id']),
      priceType: json['price_type'] ?? '',
      item_name: json['item_name'] ?? '', // Добавлено поле для имени товара
      price: Item._parseDouble(json['price']) ?? 0.0,
      parentItemAmount: Item._parseInt(json['parent_item_amount']),
    );
  }

  /// Создание из CategoryItemOptionItem для совместимости
  factory ItemOptionItem.fromCategoryItemOptionItem(
      dynamic categoryOptionItem) {
    if (categoryOptionItem is Map<String, dynamic>) {
      return ItemOptionItem.fromJson(categoryOptionItem);
    }

    return ItemOptionItem(
      relationId: categoryOptionItem.relationId,
      itemId: categoryOptionItem.itemId,
      priceType: categoryOptionItem.priceType,
      item_name:
          categoryOptionItem.item_name ?? '', // Добавлено поле для имени товара
      price: categoryOptionItem.price,
      parentItemAmount: categoryOptionItem.parentItemAmount,
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
    return ItemPromotion(
      promotionId: Item._parseInt(json['promotion_id']),
      name: json['name'] ?? '',
      description: json['description'],
      discountType: json['discount_type'] ?? '',
      discountValue: Item._parseDouble(json['discount_value']) ?? 0.0,
      baseAmount: Item._parseInt(json['base_amount'] ?? json['baseAmount']),
      addAmount: Item._parseInt(json['add_amount'] ?? json['addAmount']),
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'])
          : null,
      endDate:
          json['end_date'] != null ? DateTime.tryParse(json['end_date']) : null,
    );
  }

  /// Создание из CategoryItemPromotion для совместимости
  factory ItemPromotion.fromCategoryItemPromotion(dynamic categoryPromotion) {
    if (categoryPromotion is Map<String, dynamic>) {
      return ItemPromotion.fromJson(categoryPromotion);
    }

    return ItemPromotion(
      promotionId: categoryPromotion.detailId ?? 0,
      name: categoryPromotion.name ?? '',
      description:
          categoryPromotion.formattedDescription ?? categoryPromotion.name,
      discountType: categoryPromotion.type ?? '',
      discountValue: 0.0, // CategoryItemPromotion не имеет discountValue
      startDate: null, // CategoryItemPromotion не имеет дат
      endDate: null, // CategoryItemPromotion не имеет дат
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
      name: json['name'] ?? '',
      priceModifier: Item._parseDouble(json['price_modifier']),
      image: json['image'],
      attributes: json['attributes'],
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
