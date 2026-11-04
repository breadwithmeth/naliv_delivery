import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/pages/checkout_address_sheet.dart';

void main() {
  test('an account address shows its street, not its default name', () {
    final address = {
      'name': 'Адрес доставки',
      'address': 'Караганда, улица Бухар-Жырау, 70',
      'street': 'улица Бухар-Жырау',
      'house': '70',
      'lat': 49.8,
      'lon': 73.1,
    };
    expect(checkoutAddressTitle(address), isNot('Адрес доставки'));
    expect(checkoutAddressTitle(address), contains('Бухар-Жырау'));
    expect(checkoutAddressTitle(address), contains('70'));
    expect(checkoutAddressName(address), isNull);
  });

  test('without street fields the stored address text is used', () {
    final address = {
      'name': 'Адрес доставки',
      'address': 'Темиртау, Мира 86а • Под. 2, Эт. 7',
    };
    expect(checkoutAddressTitle(address), 'Темиртау, Мира 86а');
  });

  test('a name the customer chose is kept as a hint', () {
    final address = {
      'name': 'Работа',
      'street': 'Мира',
      'house': '86а',
    };
    expect(checkoutAddressTitle(address), contains('Мира'));
    expect(checkoutAddressName(address), 'Работа');
  });
}
