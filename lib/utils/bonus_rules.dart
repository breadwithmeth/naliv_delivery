import 'dart:math' as math;

import 'package:naliv_delivery/model/cart_item.dart';
import 'smart_cart.dart';

class BonusRules {
  static const double earnRate = 0.03;
  // Existing checkout API terms: docs/sms_verification_and_order_creation.md.
  // This is a client estimate, not a confirmed loyalty ledger entry.
  static const double redeemRate = 0.30;

  static bool isBonusExcludedText({
    required String name,
    String? description,
    String? categoryName,
    String? code,
  }) {
    final haystack = <String>[
      name,
      description ?? '',
      categoryName ?? '',
      code ?? '',
    ].join(' ').toLowerCase();

    const exclusionMarkers = <String>[
      'сигар',
      'сигарет',
      'табак',
      'табач',
      'курени',
      'стик',
      'sticks',
      'stick',
      'glo',
      'neo',
      'heets',
      'veo',
      'iqos',
    ];

    for (final marker in exclusionMarkers) {
      if (haystack.contains(marker)) {
        return true;
      }
    }

    return false;
  }

  static bool isBonusExcludedCartItem(CartItem item) {
    final snapshot = item.snapshotItem;
    return isBonusExcludedText(
      name: snapshot?.name ?? item.name,
      description: snapshot?.description,
      categoryName: snapshot?.category?.name,
      code: snapshot?.code,
    );
  }

  static int calculateEarnedBonuses(double amount) {
    if (!amount.isFinite || amount <= 0) return 0;
    final rawPoints = (amount * earnRate).round();
    return rawPoints > 0 ? rawPoints : 0;
  }

  static int calculateEarnedBonusesForCartItem(CartItem item) {
    if (isBonusExcludedCartItem(item)) return 0;
    return calculateEarnedBonuses(item.totalPrice);
  }

  static double calculateEligibleSubtotalForCartItems(
      Iterable<CartItem> items) {
    return calculateEligibleSubtotalForGroups(CartDisplayGroup.groupItems(items));
  }

  static int calculateEarnedBonusesForCartItems(Iterable<CartItem> items) {
    final eligibleSubtotal = calculateEligibleSubtotalForCartItems(items);
    return calculateEarnedBonuses(eligibleSubtotal);
  }

  static double calculateEligibleSubtotalForGroups(
      Iterable<CartDisplayGroup> groups) {
    var eligible = 0.0;
    for (final group in groups) {
      final item = group.itemSnapshot;
      if (isBonusExcludedText(
        name: item?.name ?? group.name,
        description: item?.description,
        categoryName: item?.category?.name,
        code: item?.code,
      )) {
        continue;
      }
      final amount = group.totalPrice;
      if (amount.isFinite && amount > 0) eligible += amount;
    }
    return eligible;
  }

  static int calculateEarnedBonusesForGroups(
      Iterable<CartDisplayGroup> groups) =>
      calculateEarnedBonuses(calculateEligibleSubtotalForGroups(groups));

  static int calculateRedeemableBonuses({
    required double balance,
    required double eligibleSubtotal,
  }) {
    if (!balance.isFinite ||
        !eligibleSubtotal.isFinite ||
        balance <= 0 ||
        eligibleSubtotal <= 0) {
      return 0;
    }
    // The existing order API sends whole bonus_amount values. Round down so a
    // fractional balance/base can never exceed either available limit.
    return math.min(balance, eligibleSubtotal * redeemRate).floor();
  }
}
