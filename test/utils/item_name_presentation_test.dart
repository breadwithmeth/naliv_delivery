import 'package:flutter_test/flutter_test.dart';
import 'package:gradusy24/utils/item_name_presentation.dart';

void main() {
  group('presentItemName', () {
    test('keeps original name when no known prefix', () {
      final result = presentItemName(
        rawName: 'Крушовице светлое',
        categoryName: 'Пиво',
      );

      expect(result.name, 'Крушовице светлое');
      expect(result.type, 'Пиво');
    });

    test('removes known category prefix from start', () {
      final result = presentItemName(
        rawName: 'Пиво розлив Жигулевское',
        categoryName: 'Разливное пиво',
      );

      expect(result.name, 'Жигулевское');
      expect(result.type, 'Разливное пиво');
    });

    test('does not wipe item when name equals prefix', () {
      final result = presentItemName(
        rawName: 'Пиво',
        categoryName: 'Пиво',
      );

      expect(result.name, 'Пиво');
      expect(result.type, 'Пиво');
    });

    test('uses stored type when category missing', () {
      final result = presentItemName(
        rawName: 'IPA',
        storedType: 'Разливное пиво',
      );

      expect(result.name, 'IPA');
      expect(result.type, 'Разливное пиво');
    });

    test('extracts packaging prefix and keeps it as attribute', () {
      final result = presentItemName(
        rawName: 'жб Miller',
        categoryName: 'Пиво',
      );

      expect(result.name, 'Miller');
      expect(result.type, 'Пиво');
      expect(result.packagingType, 'Ж/Б');
      expect(result.attributes, <String>['Пиво', 'Ж/Б']);
    });

    test('extracts parenthesized country and strips it from the name', () {
      final result = presentItemName(
        rawName: 'Bulleit Bourbon (США) 0.7 45%',
        categoryName: 'Виски',
      );

      expect(result.name, 'Bulleit Bourbon');
      expect(result.type, 'Виски');
      expect(result.countryName, 'США');
      expect(result.countryFlag, '🇺🇸');
      expect(result.volumeLiters, 0.7);
      expect(result.alcoholPercent, 45);
    });

    test('extracts parenthesized european country in russian', () {
      final result = presentItemName(
        rawName: 'Cava Rose (Испания) 0,75 11,5%',
        categoryName: 'Игристое вино',
      );

      expect(result.name, 'Cava Rose');
      expect(result.countryName, 'Испания');
      expect(result.countryFlag, '🇪🇸');
      expect(result.volumeLiters, 0.75);
      expect(result.alcoholPercent, 11.5);
    });

    test('extracts implicit bottle volume and alcohol percent', () {
      final result = presentItemName(
        rawName: 'ЖБ Miller 0.5 4,7%',
        categoryName: 'Пиво',
      );

      expect(result.name, 'Miller');
      expect(result.packagingType, 'Ж/Б');
      expect(result.volumeLiters, 0.5);
      expect(result.alcoholPercent, 4.7);
      expect(result.pricingAttributes, <String>['0,5 л', '4,7%']);
      expect(result.attributes, <String>['Пиво', 'Ж/Б', '0,5 л', '4,7%']);
    });

    test('normalizes implicit 4.5 volume to 0.45 liters', () {
      final result = presentItemName(
        rawName: 'Бут Corona Extra 4.5 4.5%',
        categoryName: 'Пиво',
      );

      expect(result.name, 'Corona Extra');
      expect(result.packagingType, 'Бутылка');
      expect(result.volumeLiters, 0.45);
      expect(result.alcoholPercent, 4.5);
      expect(result.pricingAttributes, <String>['0,45 л', '4,5%']);
    });

    test('extracts explicit volume and later alcohol percent for spirits', () {
      final result = presentItemName(
        rawName: 'Виски Jameson Black Barrel 0,7л 40%',
        categoryName: 'Виски',
      );

      expect(result.name, 'Jameson Black Barrel');
      expect(result.type, 'Виски');
      expect(result.volumeLiters, 0.7);
      expect(result.alcoholPercent, 40);
      expect(result.pricingAttributes, <String>['0,7 л', '40%']);
    });

    test('extracts miniature bottle volume like 0.05', () {
      final result = presentItemName(
        rawName: 'Текила Patron Silver 0.05 40%',
        categoryName: 'Текила',
      );

      expect(result.name, 'Patron Silver');
      expect(result.type, 'Текила');
      expect(result.volumeLiters, 0.05);
      expect(result.alcoholPercent, 40);
      expect(result.pricingAttributes, <String>['0,05 л', '40%']);
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

    test('does not treat brand ordinal as implicit volume before actual bottle size', () {
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

    test('extracts zero alcohol percent', () {
      final result = presentItemName(
        rawName: 'Пиво Clausthaler Original 0.5 0%',
        categoryName: 'Безалкогольное пиво',
      );

      expect(result.name, 'Clausthaler Original');
      expect(result.type, 'Безалкогольное пиво');
      expect(result.volumeLiters, 0.5);
      expect(result.alcoholPercent, 0);
      expect(result.pricingAttributes, <String>['0,5 л', '0%']);
    });

    test('removes packaging token when it is not leading', () {
      final result = presentItemName(
        rawName: 'Miller ж/б 0,45 4,7%',
        categoryName: 'Пиво',
      );

      expect(result.name, 'Miller');
      expect(result.packagingType, 'Ж/Б');
      expect(result.volumeLiters, 0.45);
      expect(result.alcoholPercent, 4.7);
    });

    test('keeps original when only packaging token is present', () {
      final result = presentItemName(
        rawName: 'бут',
        categoryName: 'Пиво',
      );

      expect(result.name, 'бут');
      expect(result.type, 'Пиво');
      expect(result.packagingType, null);
    });

    test('uses stored packaging when name has no packaging marker', () {
      final result = presentItemName(
        rawName: 'Крушовице светлое',
        storedType: 'Пиво',
        storedPackagingType: 'Ж/Б',
      );

      expect(result.name, 'Крушовице светлое');
      expect(result.type, 'Пиво');
      expect(result.packagingType, 'Ж/Б');
      expect(result.attributes, <String>['Пиво', 'Ж/Б']);
    });
  });
}
