import 'package:naliv_delivery/models/cart_item.dart';

class BonusRules {
  static const double earnRate = 0.03;

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
    return isBonusExcludedText(name: item.name);
  }

  static int calculateEarnedBonuses(double amount) {
    if (amount <= 0) return 0;
    final rawPoints = (amount * earnRate).round();
    return rawPoints > 0 ? rawPoints : 0;
  }

  static int calculateEarnedBonusesForCartItem(CartItem item) {
    if (isBonusExcludedCartItem(item)) return 0;
    return calculateEarnedBonuses(item.totalPrice);
  }

  static double calculateEligibleSubtotalForCartItems(
      Iterable<CartItem> items) {
    return items.fold<double>(0, (sum, item) {
      if (isBonusExcludedCartItem(item)) {
        return sum;
      }

      return sum + item.totalPrice;
    });
  }

  static int calculateEarnedBonusesForCartItems(Iterable<CartItem> items) {
    final eligibleSubtotal = calculateEligibleSubtotalForCartItems(items);
    return calculateEarnedBonuses(eligibleSubtotal);
  }
}
