import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/utils/certificate_checkout_math.dart';

void main() {
  group('certificate checkout math', () {
    test('limits certificate by item subtotal after bonuses', () {
      expect(
        certificateAppliedAmount(
          itemsTotal: 12000,
          bonusAmount: 3000,
          maxAvailableAmount: 10000,
        ),
        9000,
      );
    });

    test('does not cover delivery or service fee', () {
      expect(
        checkoutTotalWithCertificate(
          itemsTotal: 12000,
          bonusAmount: 2000,
          certificateAmount: 10000,
          deliveryPrice: 900,
          serviceFee: 150,
        ),
        1050,
      );
    });
  });
}
