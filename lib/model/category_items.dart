import '../core/json_payload.dart';

/// Модель для ответа API товаров категории
class CategoryItemsResponse {
  final bool success;
  final CategoryItemsData data;
  final String? message;

  CategoryItemsResponse({
    required this.success,
    required this.data,
    this.message,
  });

  factory CategoryItemsResponse.fromJson(Map<String, dynamic> json) {
    return CategoryItemsResponse(
      success: payloadBool(json['success']),
      data: CategoryItemsData.fromJson(payloadMap(json['data'])),
      message: payloadString(json['message']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data.toJson(),
      if (message != null) 'message': message,
    };
  }

  @override
  String toString() {
    return 'CategoryItemsResponse(success: $success, items: ${data.items.length})';
  }
}

/// Модель для данных товаров категории
class CategoryItemsData {
  final CategoryInfo category;
  final BusinessInfo business;
  final List<CategoryItem> items;
  final PaginationInfo pagination;
  final List<int> categoriesIncluded;
  final int subcategoriesCount;

  CategoryItemsData({
    required this.category,
    required this.business,
    required this.items,
    required this.pagination,
    required this.categoriesIncluded,
    required this.subcategoriesCount,
  });

  factory CategoryItemsData.fromJson(Map<String, dynamic> json) {
    return CategoryItemsData(
      category: CategoryInfo.fromJson(payloadMap(json['category'])),
      business: BusinessInfo.fromJson(payloadMap(json['business'])),
      items: payloadMaps(json['items'])
          .map(CategoryItem.fromJson)
          .toList(growable: false),
      pagination: PaginationInfo.fromJson(payloadMap(json['pagination'])),
      categoriesIncluded: payloadInts(json['categories_included']),
      subcategoriesCount: payloadInt(json['subcategories_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category.toJson(),
      'business': business.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'pagination': pagination.toJson(),
      'categories_included': categoriesIncluded,
      'subcategories_count': subcategoriesCount,
    };
  }

  @override
  String toString() {
    return 'CategoryItemsData(category: ${category.name}, items: ${items.length}, subcategories: $subcategoriesCount)';
  }
}

/// Модель для информации о категории
class CategoryInfo {
  final int categoryId;
  final String name;
  final String? photo;
  final String? img;

  CategoryInfo({
    required this.categoryId,
    required this.name,
    this.photo,
    this.img,
  });

  factory CategoryInfo.fromJson(Map<String, dynamic> json) {
    return CategoryInfo(
      categoryId: payloadInt(json['category_id'] ?? json['id']),
      name: payloadString(json['name']) ?? '',
      photo: payloadString(json['photo']),
      img: payloadString(json['img']) ?? payloadString(json['image']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'name': name,
      if (photo != null) 'photo': photo,
      if (img != null) 'img': img,
    };
  }

  @override
  String toString() {
    return 'CategoryInfo(id: $categoryId, name: $name)';
  }
}

/// Модель для информации о бизнесе
class BusinessInfo {
  final int businessId;
  final String name;
  final String? address;

  BusinessInfo({
    required this.businessId,
    required this.name,
    this.address,
  });

  factory BusinessInfo.fromJson(Map<String, dynamic> json) {
    return BusinessInfo(
      businessId: payloadInt(json['business_id'] ?? json['id']),
      name: payloadString(json['name']) ?? '',
      address: payloadString(json['address']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'business_id': businessId,
      'name': name,
      if (address != null) 'address': address,
    };
  }

  @override
  String toString() {
    return 'BusinessInfo(id: $businessId, name: $name)';
  }
}

/// Модель для товара в категории
class CategoryItem {
  final int itemId;
  final String name;
  final String? description;
  final double price;
  final String? img;
  final String? code;
  final ItemCategory category;
  final int visible;
  final String? unit;
  final double? quantity;
  final double? stepQuantity;
  final List<CategoryItemOption>? options;
  final List<CategoryItemPromotion>? promotions;
  final double? amount;
  final Map<String, dynamic> identityData;

  CategoryItem({
    required this.itemId,
    required this.name,
    this.description,
    required this.price,
    this.img,
    this.code,
    required this.category,
    required this.visible,
    this.unit,
    this.quantity,
    this.stepQuantity,
    this.options,
    this.promotions,
    this.amount,
    this.identityData = const {},
  });

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    final categoryData = nullablePayloadMap(json['category']) ??
        <String, dynamic>{
          'category_id': json['category_id'] ?? json['categoryId'],
          'name':
              payloadString(json['category_name'] ?? json['category']) ?? '',
          'parent_category': json['parent_category'] ?? json['parent_id'],
        };
    final options = payloadMaps(json['options'])
        .map(CategoryItemOption.fromJson)
        .toList(growable: false);
    final promotions = payloadMaps(json['promotions'])
        .map(CategoryItemPromotion.fromJson)
        .toList(growable: false);

    return CategoryItem(
      itemId: payloadInt(json['item_id'] ?? json['id']),
      name: payloadString(json['name']) ?? '',
      description: payloadString(json['description']),
      price: payloadDouble(json['price']) ?? 0.0,
      img: payloadString(json['img']) ?? payloadString(json['image']),
      code: payloadString(json['code']),
      category: ItemCategory.fromJson(categoryData),
      visible: payloadInt(json['visible'], defaultValue: 1),
      unit: payloadString(json['unit'] ?? json['unit_name'] ?? json['measure']),
      quantity: payloadDouble(json['quantity']) ??
          payloadDouble(json['parent_item_amount']),
      stepQuantity: payloadDouble(json['quantity_step']) ??
          payloadDouble(json['step_quantity']) ??
          payloadDouble(json['parent_item_amount']),
      options: options.isEmpty ? null : options,
      promotions: promotions.isEmpty ? null : promotions,
      amount: payloadDouble(json['amount']),
      identityData: {
        for (final key in const [
          'item_type',
          'packaging_type',
          'material',
          'country_name',
          'volume_liters',
          'weight_kilograms',
          'alcohol_percent',
        ])
          if (json.containsKey(key)) key: json[key],
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'name': name,
      if (description != null) 'description': description,
      'price': price,
      if (img != null) 'img': img,
      if (code != null) 'code': code,
      'category': category.toJson(),
      'visible': visible,
      if (unit != null) 'unit': unit,
      if (quantity != null) 'quantity': quantity,
      if (stepQuantity != null) 'quantity_step': stepQuantity,
      if (amount != null) 'amount': amount,
      if (options != null)
        'options': options!.map((option) => option.toJson()).toList(),
      if (promotions != null)
        'promotions': promotions!.map((promo) => promo.toJson()).toList(),
      ...identityData,
    };
  }

  @override
  String toString() {
    return 'CategoryItem(id: $itemId, name: $name, price: $price)';
  }

  /// Проверяет, виден ли товар
  bool get isVisible => visible == 1;

  /// Проверяет, есть ли опции у товара
  bool get hasOptions => options != null && options!.isNotEmpty;

  /// Проверяет, есть ли акции на товар
  bool get hasPromotions => promotions != null && promotions!.isNotEmpty;
}

/// Модель для категории товара
class ItemCategory {
  final int categoryId;
  final String name;
  final int? parentCategory;

  ItemCategory({
    required this.categoryId,
    required this.name,
    this.parentCategory,
  });

  factory ItemCategory.fromJson(Map<String, dynamic> json) {
    return ItemCategory(
      categoryId: payloadInt(json['category_id'] ?? json['id']),
      name: payloadString(json['name']) ?? '',
      parentCategory:
          json['parent_category'] != null || json['parent_id'] != null
              ? payloadInt(json['parent_category'] ?? json['parent_id'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'name': name,
      if (parentCategory != null) 'parent_category': parentCategory,
    };
  }

  @override
  String toString() {
    return 'ItemCategory(id: $categoryId, name: $name)';
  }

  /// Проверяет, является ли категория подкатегорией
  bool get isSubcategory => parentCategory != null;
}

/// Модель для информации о пагинации
class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: payloadInt(json['page'], defaultValue: 1),
      limit: payloadInt(json['limit'], defaultValue: 20),
      total: payloadInt(json['total']),
      totalPages: payloadInt(
        json['totalPages'] ?? json['total_pages'],
        defaultValue: 1,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'limit': limit,
      'total': total,
      'totalPages': totalPages,
    };
  }

  @override
  String toString() {
    return 'PaginationInfo(page: $page/$totalPages, total: $total)';
  }

  /// Проверяет, есть ли следующая страница
  bool get hasNextPage => page < totalPages;

  /// Проверяет, есть ли предыдущая страница
  bool get hasPreviousPage => page > 1;

  /// Получает номер следующей страницы
  int? get nextPage => hasNextPage ? page + 1 : null;

  /// Получает номер предыдущей страницы
  int? get previousPage => hasPreviousPage ? page - 1 : null;
}

/// Модель для опции товара в категории
class CategoryItemOption {
  final int optionId;
  final String name;
  final bool required;
  final String selection; // "single" | "multiple"
  final List<CategoryItemVariant> variants;

  CategoryItemOption({
    required this.optionId,
    required this.name,
    required this.required,
    required this.selection,
    required this.variants,
  });

  factory CategoryItemOption.fromJson(Map<String, dynamic> json) {
    return CategoryItemOption(
      optionId: payloadInt(json['option_id']),
      name: payloadString(json['name']) ?? '',
      required: payloadBool(json['required']),
      selection: payloadString(json['selection']) ?? 'single',
      variants: payloadMaps(json['variants'])
          .map(CategoryItemVariant.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'option_id': optionId,
      'name': name,
      'required': required,
      'selection': selection,
      'variants': variants.map((variant) => variant.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'CategoryItemOption(id: $optionId, name: $name, required: $required, variants: ${variants.length})';
  }
}

/// Модель для варианта опции товара в категории
class CategoryItemVariant {
  final int relationId;
  final int itemId;
  final String priceType; // "add" | "replace"
  final String? itemName; // может быть null, если не указано
  final double price;
  final double parentItemAmount;

  CategoryItemVariant({
    required this.relationId,
    required this.itemId,
    required this.priceType,
    required this.itemName,
    required this.price,
    required this.parentItemAmount,
  });

  factory CategoryItemVariant.fromJson(Map<String, dynamic> json) {
    return CategoryItemVariant(
      relationId: payloadInt(json['relation_id']),
      itemId: payloadInt(json['item_id']),
      priceType: payloadString(json['price_type']) ?? 'add',
      itemName: payloadString(json['item_name'] ?? json['name']),
      price: payloadDouble(json['price']) ?? 0.0,
      parentItemAmount: payloadDouble(json['parent_item_amount']) ?? 0.0,
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
    return 'CategoryItemVariant(relationId: $relationId, itemId: $itemId, priceType: $priceType, price: $price)';
  }
}

/// Модель для акции товара в категории
class CategoryItemPromotion {
  final int detailId;
  final String type; // "SUBTRACT" | "DISCOUNT"
  final int? baseAmount;
  final int? addAmount;
  final double? discount;
  final String name;

  /// Validity window the server nests under `promotion`; without it a catalogue entry could keep
  /// advertising a promotion that already ended.
  final DateTime? startDate;
  final DateTime? endDate;

  CategoryItemPromotion({
    required this.detailId,
    required this.type,
    this.baseAmount,
    this.addAmount,
    this.discount,
    required this.name,
    this.startDate,
    this.endDate,
  });

  factory CategoryItemPromotion.fromJson(Map<String, dynamic> json) {
    final promotionMeta = payloadMap(json['promotion']);

    return CategoryItemPromotion(
      detailId: payloadInt(
        json['detail_id'] ?? json['promotion_id'] ?? promotionMeta['detail_id'],
      ),
      type: payloadString(json['type'] ?? promotionMeta['type']) ?? '',
      baseAmount: json['base_amount'] != null || json['baseAmount'] != null
          ? payloadInt(json['base_amount'] ?? json['baseAmount'])
          : null,
      addAmount: json['add_amount'] != null || json['addAmount'] != null
          ? payloadInt(json['add_amount'] ?? json['addAmount'])
          : null,
      discount: payloadDouble(json['discount'] ?? json['discount_value']),
      name: payloadString(json['name'] ?? promotionMeta['name']) ?? '',
      startDate: DateTime.tryParse(payloadString(
              json['start_date'] ?? promotionMeta['start_promotion_date']) ??
          ''),
      endDate: DateTime.tryParse(payloadString(
              json['end_date'] ?? promotionMeta['end_promotion_date']) ??
          ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'detail_id': detailId,
      'type': type,
      if (baseAmount != null) 'base_amount': baseAmount,
      if (addAmount != null) 'add_amount': addAmount,
      if (discount != null) 'discount': discount,
      'name': name,
      if (startDate != null) 'start_date': startDate!.toIso8601String(),
      if (endDate != null) 'end_date': endDate!.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'CategoryItemPromotion(id: $detailId, type: $type, name: $name)';
  }

  /// Форматированное описание акции
  String get formattedDescription {
    if (type == 'SUBTRACT' && baseAmount != null && addAmount != null) {
      return '$baseAmount+$addAmount';
    }
    return name;
  }
}
