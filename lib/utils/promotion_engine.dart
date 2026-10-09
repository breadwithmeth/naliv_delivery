/// One promotion evaluator for the whole app.
///
/// The API describes a product promotion as `PERCENT`/`DISCOUNT` (price), `FIXED` (money off every
/// unit) or `SUBTRACT` (buy `base_amount` paid, get `add_amount` free). Everything that needs a
/// promotion answer — the cart, the product preview, repeat orders, checkout and the UI helpers —
/// resolves it here, so the forward rule, its inverse, the qualification progress and the choice
/// between several active promotions cannot drift apart.
///
/// The rule in force is pinned by `test/regression/bottling_contract_test.dart` and stated to
/// customers in the FAQ ("for a 2+1 promotion put three bottles in the cart, the third is free"):
/// **buy `base_amount` paid units → `add_amount` free**, i.e. `free = floor(paid / base) * add`.
library;

import 'package:flutter/foundation.dart';

const double subtractPromotionEpsilon = 0.001;

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


/// The best `SUBTRACT` award the customer gets from [promotions] at [paidQuantity].
PromotionAward? selectSubtractPromotion(
  List<Map<String, dynamic>> promotions, {
  double paidQuantity = 0,
}) {
  Map<String, dynamic>? winner;
  var bestFree = -1.0;
  var bestBase = 0;
  var bestAdd = 0;
  var bestId = 0;
  final now = DateTime.now();
  for (final promotion in promotions) {
    if (promotionType(promotion) != 'SUBTRACT' ||
        !isPromotionActive(promotion, now: now)) {
      continue;
    }
    final base = _promotionInt(promotion, 'baseAmount', 'base_amount');
    final add = _promotionInt(promotion, 'addAmount', 'add_amount');
    if (base <= 0 || add <= 0) continue;
    final free = subtractPromotionFreeQuantityForConfig(paidQuantity,
        baseAmount: base, addAmount: add);
    final id = _promotionInt(promotion, 'promotionId', 'detail_id');
    final better = winner == null ||
        free > bestFree ||
        (free == bestFree &&
            (add > bestAdd ||
                (add == bestAdd &&
                    (base < bestBase ||
                        (base == bestBase && id < bestId)))));
    if (!better) continue;
    winner = promotion;
    bestFree = free;
    bestBase = base;
    bestAdd = add;
    bestId = id;
  }
  return winner == null
      ? null
      : PromotionAward(
          promotion: winner, baseAmount: bestBase, addAmount: bestAdd);
}

/// Everything a surface needs to describe the active `N+M` promotion at a paid quantity.
@immutable
class PromotionEvaluation {
  const PromotionEvaluation({this.award, required this.paidQuantity});

  final PromotionAward? award;
  final double paidQuantity;

  /// Free units the customer receives at this quantity.
  double get freeQuantity => award == null
      ? 0
      : subtractPromotionFreeQuantityForConfig(
          paidQuantity,
          baseAmount: award!.baseAmount,
          addAmount: award!.addAmount,
        );

  /// Units the customer takes home, gifts included.
  double get physicalQuantity => paidQuantity + freeQuantity;

  /// True when the current quantity completes a gift set (`0` step to the next gift).
  bool get unlocked =>
      award != null &&
      subtractPromotionUnlocked(paidQuantity, baseAmount: award!.baseAmount);

  /// Paid units still needed for the next gift; `base_amount` when none are earned yet.
  double get nextGiftIn => award == null
      ? 0
      : subtractPromotionAmountToNextGift(paidQuantity,
          baseAmount: award!.baseAmount);

  /// Progress towards the next gift in `0…1`; `1` when the quantity is unlocked.
  double get progress => award == null
      ? 0
      : subtractPromotionProgress(paidQuantity, baseAmount: award!.baseAmount);

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
      'PromotionEvaluation(${label ?? 'none'}, paid=$paidQuantity, free=$freeQuantity)';
}

PromotionEvaluation evaluatePromotion({
  required double paidQuantity,
  required List<Map<String, dynamic>> promotions,
}) =>
    PromotionEvaluation(
      award: selectSubtractPromotion(promotions, paidQuantity: paidQuantity),
      paidQuantity: paidQuantity,
    );

/// Free units for [quantity] paid units. Zero without a usable `SUBTRACT` promotion.
double subtractPromotionFreeQuantity(
  double quantity,
  List<Map<String, dynamic>> promotions,
) {
  var freeQuantity = 0.0;
  final now = DateTime.now();
  for (final promotion in promotions) {
    if (promotionType(promotion) != 'SUBTRACT' ||
        !isPromotionActive(promotion, now: now)) {
      continue;
    }
    final base = _promotionInt(promotion, 'baseAmount', 'base_amount');
    final add = _promotionInt(promotion, 'addAmount', 'add_amount');
    final candidate = subtractPromotionFreeQuantityForConfig(quantity,
        baseAmount: base, addAmount: add);
    if (candidate > freeQuantity) freeQuantity = candidate;
  }
  return freeQuantity;
}

double subtractPromotionFreeQuantityForConfig(
  double quantity, {
  required int baseAmount,
  required int addAmount,
}) {
  if (baseAmount <= 0 ||
      addAmount <= 0 ||
      quantity + subtractPromotionEpsilon < baseAmount) {
    return 0;
  }

  final claimCount = ((quantity + 0.0000001) / baseAmount).floor();
  return (claimCount * addAmount).toDouble();
}

/// Paid units that produce exactly [physicalQuantity] units in the cart, or null when no paid
/// quantity can (for example three physical units of a `3+1` promotion).
///
/// A candidate is accepted only when the customer-best forward rule over the
/// complete active promotion set reproduces the original physical quantity.
/// Unrepresentable history is reported, never rounded into an extra gift.
double? subtractPromotionPaidQuantityForPhysicalQuantity(
    double physicalQuantity, List<Map<String, dynamic>> promotions) {
  if (!physicalQuantity.isFinite || physicalQuantity < 0) return null;
  var hasAward = false;
  final now = DateTime.now();
  for (final promotion in promotions) {
    if (promotionType(promotion) != 'SUBTRACT' ||
        !isPromotionActive(promotion, now: now)) {
      continue;
    }
    final base = _promotionInt(promotion, 'baseAmount', 'base_amount');
    final add = _promotionInt(promotion, 'addAmount', 'add_amount');
    if (base <= 0 || add <= 0) continue;
    hasAward = true;
    final claims = ((physicalQuantity + 0.0000001) / (base + add)).floor();
    final paid = physicalQuantity - claims * add;
    if (paid < 0) continue;
    if ((paid + subtractPromotionFreeQuantity(paid, promotions) -
                physicalQuantity).abs() <= 0.0000001) {
      return paid;
    }
  }
  if (!hasAward) return physicalQuantity;
  return null;
}

/// What the customer would pay without the gift: the paid units plus the gift at list price.
double subtractPromotionDisplayBaseTotal(
  double unitPrice,
  double quantity,
  List<Map<String, dynamic>> promotions,
) {
  final freeQuantity = subtractPromotionFreeQuantity(quantity, promotions);
  return unitPrice * (quantity + freeQuantity);
}

/// Price of [quantity] paid units after the price promotions: `FIXED` money off each unit first,
/// then `DISCOUNT`/`PERCENT` off the remainder.
double applyPromotionsToPaidBaseTotal({
  required double unitPrice,
  required double quantity,
  required List<Map<String, dynamic>> promotions,
}) {
  final payableQuantity = quantity;
  var result = unitPrice * payableQuantity;

  for (final promotion in promotions) {
    if (promotionType(promotion) != 'FIXED') {
      continue;
    }
    if (!isPromotionActive(promotion)) {
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
      if (!isPromotionActive(promotion)) {
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

/// Progress towards the next gift in `0…1` for a paid quantity, using one promotion's `base_amount`.
double subtractPromotionProgress(
  double quantity, {
  required int baseAmount,
}) {
  if (baseAmount <= 0 || quantity <= subtractPromotionEpsilon) {
    return 0;
  }

  final remainder = quantity % baseAmount;
  if (remainder.abs() <= subtractPromotionEpsilon) {
    return 1.0;
  }

  return (remainder / baseAmount).clamp(0.0, 1.0);
}

/// Paid units still needed to reach the next gift; `0` when the quantity already qualifies.
double subtractPromotionAmountToNextGift(
  double quantity, {
  required int baseAmount,
}) {
  if (baseAmount <= 0) {
    return 0;
  }

  final remainder = quantity % baseAmount;
  if (quantity > subtractPromotionEpsilon &&
      remainder.abs() <= subtractPromotionEpsilon) {
    return 0;
  }
  if (remainder.abs() <= subtractPromotionEpsilon) {
    return baseAmount.toDouble();
  }

  return (baseAmount - remainder).toDouble();
}

/// The quantity a plus/minus step should land on so it stays on a gift threshold.
double? subtractPromotionBundleTargetQuantity(
  double currentQuantity,
  List<Map<String, dynamic>> promotions, {
  required int direction,
}) {
  final award =
      selectSubtractPromotion(promotions, paidQuantity: currentQuantity);
  if (award == null || direction == 0) {
    return null;
  }

  final baseAmount = award.baseAmount;
  if (baseAmount <= 0) {
    return null;
  }

  final normalizedCurrent = currentQuantity <= subtractPromotionEpsilon
      ? 0.0
      : currentQuantity;
  if (direction > 0) {
    final distanceToNextGift = subtractPromotionAmountToNextGift(
      normalizedCurrent,
      baseAmount: baseAmount,
    );
    final step = distanceToNextGift <= subtractPromotionEpsilon
        ? baseAmount.toDouble()
        : distanceToNextGift;
    return normalizedCurrent + step;
  }

  if (normalizedCurrent <= subtractPromotionEpsilon) {
    return 0;
  }

  final remainder = normalizedCurrent % baseAmount;
  final stepDown = remainder.abs() <= subtractPromotionEpsilon
      ? baseAmount.toDouble()
      : remainder;
  final nextQuantity = normalizedCurrent - stepDown;
  if (nextQuantity <= subtractPromotionEpsilon) {
    return 0;
  }

  return nextQuantity;
}

/// `2+1` label for a quantity: the paid label, plus `+free` when a gift is earned.
String subtractPromotionBundleLabel(
  double quantity,
  List<Map<String, dynamic>> promotions, {
  required String Function(double quantity) formatQuantity,
}) {
  final paidLabel = formatQuantity(quantity);
  final freeQuantity = subtractPromotionFreeQuantity(quantity, promotions);
  if (freeQuantity <= subtractPromotionEpsilon) {
    return paidLabel;
  }

  return '$paidLabel+${formatQuantity(freeQuantity)}';
}

/// True when [quantity] completes a gift set for one promotion's `base_amount`.
bool subtractPromotionUnlocked(
  double quantity, {
  required int baseAmount,
}) {
  if (baseAmount <= 0 || quantity + subtractPromotionEpsilon < baseAmount) {
    return false;
  }

  final remainder = quantity % baseAmount;
  return remainder.abs() <= subtractPromotionEpsilon;
}

