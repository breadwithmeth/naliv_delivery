/// A catalogue item reduced to exactly what a product card renders.
///
/// * `oldPrice`, `discount` and `saving` are **null** when no discount promotion is active.
///   There is no "old price" field on the API; the struck price is simply `item.price`.
/// * `saving` is null (not 0) when the computed saving is under 1 ₸.
/// * `bonus` is computed from the *discounted* price at 3 %, and is null for tobacco.
/// * `country`/`volume` are null when the name carries no such token — never empty strings.
library;

import 'package:flutter/foundation.dart';

import '../model/item.dart';
import '../utils/bonus_rules.dart';
import '../utils/item_name_presentation.dart';
import '../utils/promotion_engine.dart';
import '../utils/smart_cart.dart';
import 'money.dart';
import 'quantity.dart';

@immutable
class ProductView {
  const ProductView({
    required this.itemId,
    required this.source,
    required this.title,
    required this.price,
    this.country,
    this.volume,
    this.category,
    this.unit,
    this.type,
    this.packagingType,
    this.material,
    this.alcoholPercent,
    this.alcoholLabel,
    this.weightLabel,
    this.metadata = const [],
    double? discountedUnitPrice,
    this.bonusEligible = true,
    this.oldPrice,
    this.saving,
    this.discount,
    this.promo,
    this.bonus,
    this.imageUrl,
    this.quantity = 0,
    this.available = true,
    this.lowStock = false,
  }) : _discountedUnitPrice = discountedUnitPrice;

  final int itemId;

  /// The model the cart API operates on (`incrementCatalogItem`, `getCatalogQuantity`, …).
  /// Carried so a card can act without re-parsing the item.
  final Item source;

  /// Display title: the raw name with type/packaging/country/volume tokens stripped.
  final String title;
  final String? country;
  final String? volume;

  /// Grouping label the API returns for the item, e.g. «Аперитив» — shown above the title on
  /// list rows.
  final String? category;

  /// Measurement unit («шт», «кг»), appended to the quantity in the product page's stepper.
  final String? unit;

  final String? type;
  final String? packagingType;
  final String? material;
  final double? alcoholPercent;
  final String? alcoholLabel;
  final String? weightLabel;
  final List<String> metadata;
  final double? _discountedUnitPrice;
  final bool bonusEligible;

  double get discountedUnitPrice => _discountedUnitPrice ?? price.toDouble();
  String? get unitPriceUnit => quantityUnitLabel(unit);
  String get unitPriceLabel {
    final value = formatTenge(discountedUnitPrice);
    final basis = unitPriceUnit;
    return basis == null ? value : '$value/$basis';
  }

  /// Price the customer pays — already discount-adjusted.
  final num price;

  /// Struck-through price; null without an active discount promotion.
  final num? oldPrice;

  /// «Выгода» amount; null when under 1 ₸ or without a promotion.
  final num? saving;

  /// `-10%` label; null when the promotion yields no whole percent.
  final String? discount;

  /// `2+1` label of the active `N+M` (SUBTRACT) promotion; null without one.
  ///
  /// The card only advertises the promotion; the gift maths and the progress towards the next gift
  /// come from `promotion_engine.dart`.
  final String? promo;

  /// `+100` label; null when no bonus is earned or the item is excluded (tobacco).
  final String? bonus;

  final String? imageUrl;

  /// Units in the cart, for the stepper. A double: weight items are sold in fractions.
  final num quantity;

  /// `item.amount <= 0`.
  final bool available;

  /// `0 < item.amount <= 5`.
  final bool lowStock;

  /// Builds display prices, promotion metadata and name attributes for [item].
  factory ProductView.fromItem(Item item, {num quantity = 0}) {
    final basePrice = item.price;
    final promotions = [
      for (final promotion in item.promotions ?? const <ItemPromotion>[])
        if (promotion.isActive) promotion.toJson(),
    ];
    final discounted = applyPromotionsToPaidBaseTotal(
      unitPrice: basePrice,
      quantity: 1,
      promotions: promotions,
    );
    final hasDiscount = discounted < basePrice;
    final promo = evaluatePromotion(
      paidQuantity: quantity.toDouble(),
      promotions: promotions,
    ).label;

    final presentation = presentItem(item);

    final amount = item.amount;
    final outOfStock = amount != null && amount <= 0;
    final selection = SmartCartSelection(item);
    final sellable = !outOfStock &&
        selection.containerIssue == null &&
        selection.quantityIssue == null;
    final points = outOfStock ? 0 : _bonusPoints(item, discounted);
    final savingAmount = hasDiscount ? basePrice - discounted : 0.0;
    final percent = hasDiscount && basePrice > 0
        ? ((basePrice - discounted) / basePrice * 100).round()
        : 0;

    return ProductView(
      itemId: item.itemId,
      source: item,
      title: presentation.name,
      country: presentation.countryName,
      volume: presentation.volumeLabel,
      category: item.category?.name,
      unit: item.unit,
      type: presentation.type,
      packagingType: presentation.packagingType,
      material: presentation.material,
      alcoholPercent: presentation.alcoholPercent,
      alcoholLabel: presentation.alcoholLabel,
      weightLabel: presentation.weightLabel,
      metadata: presentation.attributes,
      discountedUnitPrice: discounted,
      bonusEligible: !BonusRules.isBonusExcludedText(
        name: item.name,
        description: item.description,
        categoryName: item.category?.name,
        code: item.code,
      ),
      price: discounted,
      oldPrice: hasDiscount ? basePrice : null,
      saving: hasDiscount && savingAmount >= 1 ? savingAmount : null,
      discount: hasDiscount && percent > 0 ? '-$percent%' : null,
      promo: promo,
      bonus: points > 0 ? '+$points' : null,
      imageUrl: item.hasImage ? item.image : null,
      quantity: quantity,
      available: sellable,
      lowStock: amount != null && amount > 0 && amount <= 5,
    );
  }

  /// 3 % of the discounted price, zero for tobacco (`BonusRules`).
  static int _bonusPoints(Item item, double discountedPrice) {
    if (BonusRules.isBonusExcludedText(
      name: item.name,
      description: item.description,
      categoryName: item.category?.name,
      code: item.code,
    )) {
      return 0;
    }
    return BonusRules.calculateEarnedBonuses(discountedPrice);
  }
}
