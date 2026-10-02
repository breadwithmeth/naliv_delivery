import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/money.dart';

void main() {
  test('currency grouping handles ungrouped and multiple-thousand boundaries',
      () {
    expect(formatTenge(600), '600 ₸');
    expect(formatTenge(92190), '92\u00A0190 ₸');
    expect(formatTenge(1234567), '1\u00A0234\u00A0567 ₸');
  });
}
