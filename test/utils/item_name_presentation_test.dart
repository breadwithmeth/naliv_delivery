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
