/// One promotion evaluator for the whole app.
///
/// The API describes a product promotion as `PERCENT`/`DISCOUNT` (price), `FIXED` (money off every
/// unit) or `SUBTRACT` (buy `base_amount` paid, get `add_amount` free). Everything that needs a
/// promotion answer — the cart, the product preview, repeat orders, checkout and the UI helpers —
/// resolves it here, so the forward rule, its inverse, the qualification progress and the choice
/// between several active promotions cannot drift apart.
///
/// One rule for every product, bottled draft beer included, as the FAQ states it ("for a 2+1
/// promotion put three bottles in the cart, the third is free"): the cart holds exactly what the
/// customer added, and `add` of every `base + add` units are free, i.e.
/// `gift = floor(quantity / (base + add)) * add`. Nothing is ever added on the customer's behalf:
/// three bottles of a `3+1` promotion cost three bottles, and the fourth is free only once the
/// customer adds it ([PromotionEvaluation.bonusQuantity] says when one more unit would be free).
library;

import 'package:flutter/foundation.dart';

/// A promotion's type as the API sends it, normalised to upper case; null when absent.
String? promotionType(Map<String, dynamic> promotion) =>
    (promotion['discount_type'] ?? promotion['type'])
        ?.toString()
        .trim()
        .toUpperCase();

int _promotionInt(
    Map<String, dynamic> promotion, String camelKey, String snakeKey) {
  final value = promotion[camelKey] ?? promotion[snakeKey];
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// Whether a promotion map is valid right now. Missing dates mean unbounded.
///
/// Rows restored from storage carry the validity window the payload had, so a promotion that ended
/// while the cart was idle stops gifting as soon as the cart is read again.
bool isPromotionActive(Map<String, dynamic> promotion, {DateTime? now}) {
  final moment = now ?? DateTime.now();
  final start = _promotionDate(
      promotion, 'start_date', 'startDate', 'start_promotion_date');
  if (start != null && moment.isBefore(start)) return false;
  final end =
      _promotionDate(promotion, 'end_date', 'endDate', 'end_promotion_date');
  if (end != null && moment.isAfter(end)) return false;
  return true;
}

DateTime? _promotionDate(Map<String, dynamic> promotion, String flatKey,
    String camelKey, String nestedKey) {
  final nested = promotion['promotion'];
  final raw = promotion[flatKey] ??
      promotion[camelKey] ??
      (nested is Map ? nested[nestedKey] : null);
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return DateTime.tryParse(text);
}

/// An `N+M` award drawn from one of an item's promotions.
@immutable
class PromotionAward {
  const PromotionAward({
    required this.promotion,
    required this.baseAmount,
    required this.addAmount,
  });

  final Map<String, dynamic> promotion;
  final int baseAmount;
  final int addAmount;

  /// Units in one complete set: `base` paid plus `add` free.
  int get setSize => baseAmount + addAmount;

  /// Display labels such as `2+1`; the API's own `name` when it is present and non-empty.
  String get label {
    final name = promotion['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return '$baseAmount+$addAmount';
  }

  String? get description {
    final value = promotion['description']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  String toString() => 'PromotionAward($label)';
}

/// The `N+M` promotion for the units a customer put in the cart.
@immutable
class PromotionEvaluation {
  const PromotionEvaluation({
    required this.quantity,
    required this.giftQuantity,
    this.award,
    this.nextGiftIn,
    this.bonusQuantity,
  });

  /// Units the customer added, gift included.
  final double quantity;

  /// Units of [quantity] that are free.
  final double giftQuantity;

  /// The winning promotion at [quantity]; null without an active `SUBTRACT` promotion.
  final PromotionAward? award;

  /// Units to add before the gift grows; null without a promotion.
  final double? nextGiftIn;

  /// Units that, if the customer adds them, are entirely free; null when no such offer exists.
  final double? bonusQuantity;

  double get paidQuantity => quantity - giftQuantity;
  bool get hasPromotion => award != null;

  /// `2+1`-style label, or null without an award.
  String? get label => award?.label;

  /// The marketing name (`Выгодный розлив`), falling back to the detail's own name, or null.
  ///
  /// The API nests the campaign under `promotion`; its name is what a customer should read, while
  /// [PromotionAward.label] stays the short `2+1` for chips.
  String? get name {
    final marketing = award?.promotion['promotion'];
    if (marketing is Map) {
      final nested = marketing['name']?.toString().trim();
      if (nested != null && nested.isNotEmpty) return nested;
    }
    final value = award?.promotion['name']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  String toString() =>
      'PromotionEvaluation(${label ?? 'none'}, quantity=$quantity, gift=$giftQuantity)';
}

PromotionEvaluation evaluatePromotion({
  required double quantity,
  required List<Map<String, dynamic>> promotions,
  DateTime? now,
}) {
  now ??= DateTime.now();
  final awards = <PromotionAward>[
    for (final promotion in promotions)
      if (promotionType(promotion) == 'SUBTRACT' &&
          isPromotionActive(promotion, now: now) &&
          _promotionInt(promotion, 'baseAmount', 'base_amount') > 0 &&
          _promotionInt(promotion, 'addAmount', 'add_amount') > 0)
        PromotionAward(
          promotion: promotion,
          baseAmount: _promotionInt(promotion, 'baseAmount', 'base_amount'),
          addAmount: _promotionInt(promotion, 'addAmount', 'add_amount'),
        ),
  ];
  if (!quantity.isFinite || quantity < 0 || awards.isEmpty) {
    return PromotionEvaluation(quantity: quantity, giftQuantity: 0);
  }
  int claims(PromotionAward award, double units) =>
      ((units + 0.0000001) / award.setSize).floor();
  double giftOf(PromotionAward award, double units) =>
      (claims(award, units) * award.addAmount).toDouble();
  double bestGift(double units) {
    var best = 0.0;
    for (final award in awards) {
      final gift = giftOf(award, units);
      if (gift > best) best = gift;
    }
    return best;
  }

  int promotionId(PromotionAward award) =>
      _promotionInt(award.promotion, 'promotionId', 'detail_id');
  var winner = awards.first;
  var winnerGift = giftOf(winner, quantity);
  for (final award in awards.skip(1)) {
    final gift = giftOf(award, quantity);
    final better = gift > winnerGift ||
        (gift == winnerGift &&
            (award.addAmount > winner.addAmount ||
                (award.addAmount == winner.addAmount &&
                    (award.baseAmount < winner.baseAmount ||
                        (award.baseAmount == winner.baseAmount &&
                            promotionId(award) < promotionId(winner))))));
    if (!better) continue;
    winner = award;
    winnerGift = gift;
  }

  final gift = bestGift(quantity);
  double? nextGiftIn;
  double? bonus;
  for (final award in awards) {
    final needed = double.parse(
        ((claims(award, quantity) + 1) * award.setSize - quantity)
            .toStringAsFixed(6));
    final grown = bestGift(quantity + needed) - gift;
    if (grown <= 0.0000001) continue;
    if (nextGiftIn == null || needed < nextGiftIn) nextGiftIn = needed;
    // The added units cost nothing when the gift grows by at least as much as they add.
    if (grown + 0.0000001 >= needed && (bonus == null || needed < bonus)) {
      bonus = needed;
    }
  }
  return PromotionEvaluation(
    quantity: quantity,
    giftQuantity: gift,
    award: winner,
    nextGiftIn: nextGiftIn,
    bonusQuantity: bonus,
  );
}

/// Free units inside [quantity] units the customer added.
double promotionGiftQuantity(
  double quantity,
  List<Map<String, dynamic>> promotions, {
  DateTime? now,
}) =>
    evaluatePromotion(quantity: quantity, promotions: promotions, now: now)
        .giftQuantity;

/// Price of [quantity] paid units after the price promotions: `FIXED` money off each unit first,
/// then `DISCOUNT`/`PERCENT` off the remainder.
double applyPromotionsToPaidBaseTotal({
  required double unitPrice,
  required double quantity,
  required List<Map<String, dynamic>> promotions,
  DateTime? now,
}) {
  final payableQuantity = quantity;
  now ??= DateTime.now();
  var result = unitPrice * payableQuantity;

  for (final promotion in promotions) {
    if (promotionType(promotion) != 'FIXED') {
      continue;
    }
    if (!isPromotionActive(promotion, now: now)) {
      continue;
    }
    final discount = ((promotion['discount'] as num?) ??
            (promotion['discount_value'] as num?) ??
            0)
        .toDouble();
    if (discount > 0) {
      result = (result - (discount * payableQuantity))
          .clamp(0, double.infinity)
          .toDouble();
    }
  }

  for (final promotion in promotions) {
    final type = promotionType(promotion);
    if (type == 'DISCOUNT' || type == 'PERCENT') {
      if (!isPromotionActive(promotion, now: now)) {
        continue;
      }
      final discount = ((promotion['discount'] as num?) ??
              (promotion['discount_value'] as num?) ??
              0)
          .toDouble();
      result = result * (1 - discount / 100);
    }
  }

  return result;
}

/// The rule as the customer acts on it: «Возьмите 4 шт — платите за 3 шт». The gift is never added
/// for them, so the sentence names the quantity they put in the cart.
String promotionRuleText(
        PromotionAward award, String Function(double quantity) format) =>
    'Возьмите ${format(award.setSize.toDouble())} — платите за '
    '${format(award.baseAmount.toDouble())}';
