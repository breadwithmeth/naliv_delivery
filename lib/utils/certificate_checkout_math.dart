import 'dart:math' as math;

double certificateEligibleAfterBonuses({
  required double itemsTotal,
  required double bonusAmount,
}) {
  return math.max(0, itemsTotal - bonusAmount);
}

double certificateAppliedAmount({
  required double itemsTotal,
  required double bonusAmount,
  required double maxAvailableAmount,
}) {
  if (maxAvailableAmount <= 0) return 0;
  final eligible = certificateEligibleAfterBonuses(
    itemsTotal: itemsTotal,
    bonusAmount: bonusAmount,
  );
  return math.min(eligible, maxAvailableAmount);
}

double checkoutTotalWithCertificate({
  required double itemsTotal,
  required double bonusAmount,
  required double certificateAmount,
  required double deliveryPrice,
  double serviceFee = 0,
}) {
  final itemsPayable =
      math.max(0, itemsTotal - bonusAmount - certificateAmount);
  return itemsPayable + deliveryPrice + serviceFee;
}
