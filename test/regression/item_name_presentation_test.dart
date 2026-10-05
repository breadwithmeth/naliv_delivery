import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/utils/item_name_presentation.dart';

void main() {
  group('presentItemName', () {
    test(
        'preserves a product name when a metadata marker only matches part of a word',
        () {
      expect(presentItemName(rawName: 'Разливное пиво').name, 'Разливное пиво');
      expect(presentItemName(rawName: 'Бутон').name, 'Бутон');
    });
    test('preserves three-decimal liters like 0.355', () {
      final result = presentItemName(
        rawName: 'Пиво Bud 0.355 4,8%',
        categoryName: 'Пиво',
      );

      expect(result.name, 'Bud');
      expect(result.type, 'Пиво');
      expect(result.volumeLiters, 0.355);
      expect(result.alcoholPercent, 4.8);
      expect(result.pricingAttributes, <String>['0,355 л', '4,8%']);
    });

    test(
        'does not treat brand ordinal as implicit volume before actual bottle size',
        () {
      final result = presentItemName(
        rawName: 'Пиво бут Балтика экспортное 7 0.475 5.4%',
        categoryName: 'Пиво',
      );

      expect(result.name, 'Балтика экспортное 7');
      expect(result.packagingType, 'Бутылка');
      expect(result.volumeLiters, 0.475);
      expect(result.alcoholPercent, 5.4);
      expect(result.pricingAttributes, <String>['0,475 л', '5,4%']);
    });
  });
}
