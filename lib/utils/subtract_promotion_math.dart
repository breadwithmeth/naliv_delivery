const double subtractPromotionEpsilon = 0.001;

String? promotionType(Map<String, dynamic> promotion) {
  return (promotion['type'] as String?) ?? (promotion['discount_type'] as String?);
}

int _promotionInt(Map<String, dynamic> promotion, String camelKey, String snakeKey) {
  final raw = promotion[camelKey] ?? promotion[snakeKey];
  if (raw is num) {
    return raw.toInt();
  }
  if (raw is String) {
    return int.tryParse(raw) ?? double.tryParse(raw)?.toInt() ?? 0;
  }
  return 0;
}

Map<String, dynamic>? firstSubtractPromotion(List<Map<String, dynamic>> promotions) {
  for (final promotion in promotions) {
    if (promotionType(promotion) != 'SUBTRACT') {
      continue;
    }
    final baseAmount = _promotionInt(promotion, 'baseAmount', 'base_amount');
    final addAmount = _promotionInt(promotion, 'addAmount', 'add_amount');
    if (baseAmount > 0 && addAmount > 0) {
      return promotion;
    }
  }
  return null;
}

double subtractPromotionFreeQuantity(
  double quantity,
  List<Map<String, dynamic>> promotions,
) {
  final promotion = firstSubtractPromotion(promotions);
  if (promotion == null) {
    return 0;
  }

  return subtractPromotionFreeQuantityForConfig(
    quantity,
    baseAmount: _promotionInt(promotion, 'baseAmount', 'base_amount'),
    addAmount: _promotionInt(promotion, 'addAmount', 'add_amount'),
  );
}

double subtractPromotionFreeQuantityForConfig(
  double quantity, {
  required int baseAmount,
  required int addAmount,
}) {
  if (baseAmount <= 0 || addAmount <= 0 || quantity + subtractPromotionEpsilon < baseAmount) {
    return 0;
  }

  final claimCount = quantity ~/ baseAmount;
  return (claimCount * addAmount).toDouble();
}

double subtractPromotionDisplayBaseTotal(
  double unitPrice,
  double quantity,
  List<Map<String, dynamic>> promotions,
) {
  final freeQuantity = subtractPromotionFreeQuantity(quantity, promotions);
  return unitPrice * (quantity + freeQuantity);
}

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
    final discount = ((promotion['discount'] as num?) ?? (promotion['discount_value'] as num?) ?? 0).toDouble();
    if (discount > 0) {
      result = (result - (discount * payableQuantity)).clamp(0, double.infinity).toDouble();
    }
  }

  for (final promotion in promotions) {
    final type = promotionType(promotion);
    if (type == 'DISCOUNT' || type == 'PERCENT') {
      final discount = ((promotion['discount'] as num?) ?? (promotion['discount_value'] as num?) ?? 0).toDouble();
      result = result * (1 - discount / 100);
    }
  }

  return result;
}

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

double subtractPromotionAmountToNextGift(
  double quantity, {
  required int baseAmount,
}) {
  if (baseAmount <= 0) {
    return 0;
  }

  final remainder = quantity % baseAmount;
  if (quantity > subtractPromotionEpsilon && remainder.abs() <= subtractPromotionEpsilon) {
    return 0;
  }
  if (remainder.abs() <= subtractPromotionEpsilon) {
    return baseAmount.toDouble();
  }

  return (baseAmount - remainder).toDouble();
}

double? subtractPromotionBundleTargetQuantity(
  double currentQuantity,
  List<Map<String, dynamic>> promotions, {
  required int direction,
}) {
  final promotion = firstSubtractPromotion(promotions);
  if (promotion == null || direction == 0) {
    return null;
  }

  final baseAmount = _promotionInt(promotion, 'baseAmount', 'base_amount');
  if (baseAmount <= 0) {
    return null;
  }

  final normalizedCurrent = currentQuantity <= subtractPromotionEpsilon ? 0.0 : _normalizePromotionQuantity(currentQuantity);
  if (direction > 0) {
    final distanceToNextGift = subtractPromotionAmountToNextGift(
      normalizedCurrent,
      baseAmount: baseAmount,
    );
    final step = distanceToNextGift <= subtractPromotionEpsilon ? baseAmount.toDouble() : distanceToNextGift;
    return _normalizePromotionQuantity(normalizedCurrent + step);
  }

  if (normalizedCurrent <= subtractPromotionEpsilon) {
    return 0;
  }

  final remainder = normalizedCurrent % baseAmount;
  final stepDown = remainder.abs() <= subtractPromotionEpsilon ? baseAmount.toDouble() : remainder;
  final nextQuantity = normalizedCurrent - stepDown;
  if (nextQuantity <= subtractPromotionEpsilon) {
    return 0;
  }

  return _normalizePromotionQuantity(nextQuantity);
}

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

double _normalizePromotionQuantity(double value) {
  return double.parse(value.toStringAsFixed(2));
}
