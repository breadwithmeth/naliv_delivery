import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/quantity.dart';

void main() {
  test('fractional measures retain supported capacity precision', () {
    expect(formatQuantity(0.475, 'л'), '0.475 л');
    expect(formatQuantity(1.25, 'кг'), '1.25 кг');
    expect(formatQuantity(0.001, ''), '0.001');
  });

  test('whole counts have no spurious fractional suffix', () {
    expect(formatQuantity(12, 'шт'), '12 шт');
    expect(formatQuantity(3, ''), '3');
  });
}
