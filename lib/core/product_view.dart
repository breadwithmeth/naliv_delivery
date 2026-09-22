/// A catalogue item reduced to exactly what a product card renders.
///
/// This is a **pure translation** of the rules the old `lib/shared/product_card.dart` applied
/// inline, extracted so the redesigned card (and the catalogue, search and favourites screens)
/// can share it. The arithmetic is deliberately identical — the data layer is frozen — and the
/// null behaviour is reproduced rather than cleaned up:
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
    this.oldPrice,
    this.saving,
    this.discount,
    this.bonus,
    this.imageUrl,
    this.quantity = 0,
    this.available = true,
    this.lowStock = false,
  });

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

  /// Price the customer pays — already discount-adjusted.
  final int price;

  /// Struck-through price; null without an active discount promotion.
  final int? oldPrice;

  /// «Выгода» amount; null when under 1 ₸ or without a promotion.
  final int? saving;

  /// `-10%` label; null when the promotion yields no whole percent.
  final String? discount;

  /// `+100` label; null when no bonus is earned or the item is excluded (tobacco).
  final String? bonus;

  final String? imageUrl;

  /// Units in the cart, for the stepper. A double: weight items are sold in fractions.
  final num quantity;

  /// `item.amount <= 0`.
  final bool available;

  /// `0 < item.amount <= 5`.
  final bool lowStock;

  /// Mirrors `shared/product_card.dart:157-177` and `:651-664`.
  factory ProductView.fromItem(Item item, {num quantity = 0}) {
    final promotion = _discountPromotion(item);
    final basePrice = item.price;
    final discounted =
        promotion?.calculateDiscountedPrice(basePrice) ?? basePrice;
    final hasDiscount = promotion != null;

    final presentation = presentItemName(
      rawName: item.name,
      categoryName: item.category?.name,
    );

    final amount = item.amount;
    final outOfStock = amount != null && amount <= 0;
    final points = outOfStock ? 0 : _bonusPoints(item, discounted);
    final savingAmount = hasDiscount ? basePrice - discounted : 0.0;
    final percent = hasDiscount
        ? promotion.calculateEffectiveDiscountPercent(basePrice)
        : 0;

    return ProductView(
      itemId: item.itemId,
      source: item,
      title: presentation.name,
      country: presentation.countryName,
      volume: presentation.volumeLabel,
      category: item.category?.name,
      unit: item.unit,
      price: discounted.round(),
      oldPrice: hasDiscount ? basePrice.round() : null,
      saving: hasDiscount && savingAmount >= 1 ? savingAmount.round() : null,
      discount: hasDiscount && percent > 0 ? '-$percent%' : null,
      bonus: points > 0 ? '+$points' : null,
      imageUrl: item.hasImage ? item.image : null,
      quantity: quantity,
      available: !outOfStock,
      lowStock: amount != null && amount > 0 && amount <= 5,
    );
  }

  /// First promotion that is active, is a percentage or fixed discount, and actually discounts.
  static ItemPromotion? _discountPromotion(Item item) {
    for (final promotion in item.promotions ?? const <ItemPromotion>[]) {
      if (!promotion.isActive) continue;
      if (promotion.discountType != 'PERCENT' &&
          promotion.discountType != 'FIXED') {
        continue;
      }
      if (promotion.discountValue <= 0) continue;
      return promotion;
    }
    return null;
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
