import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/product_view.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/model/item.dart' as item_model;
import 'package:naliv_delivery/utils/api.dart';
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

    test('Garage packaging and ABV survive typed catalogue and cart snapshots',
        () {
      ProductView view(int id, String marker) {
        final item = CategoryItem.fromJson({
          'item_id': id,
          'name': 'Пиво $marker Garage Hard Lemon 0.44 л 4,6%',
          'price': 650,
          'unit': 'шт',
          'category': {'category_id': 12, 'name': 'Пиво'},
          'amount': 5,
        });
        final source = item_model.Item.fromCategoryItem(item);
        final persisted = CartItem(
          itemId: source.itemId,
          name: source.name,
          price: source.price,
          quantity: 1,
          stepQuantity: source.effectiveStepQuantity,
          selectedVariants: const [],
          promotions: const [],
          itemData: source.toJson(),
        ).toJson();
        final restored = CartItem.fromJson(persisted);
        return ProductView.fromItem(restored.snapshotItem!);
      }

      final bottle = view(801, 'бут');
      final can = view(802, 'жб');
      expect(bottle.title, 'Garage Hard Lemon');
      expect(can.title, bottle.title);
      expect(bottle.itemId, 801);
      expect(can.itemId, 802);
      expect(bottle.packagingType, 'Бутылка');
      expect(can.packagingType, 'Ж/Б');
      expect(bottle.volume, '0,44 л');
      expect(bottle.alcoholLabel, '4,6%');
      expect(bottle.metadata,
          ['Пиво', 'Бутылка', '0,44 л', '4,6%']);
      expect(can.metadata, ['Пиво', 'Ж/Б', '0,44 л', '4,6%']);
      expect(bottle.material, isNull);
      expect(bottle.source.name, 'Пиво бут Garage Hard Lemon 0.44 л 4,6%');
      final unspecified = ProductView.fromItem(item_model.Item(
          itemId: 803, name: 'бут Garage Hard Lemon', price: 650, unit: 'шт'));
      expect(unspecified.material, isNull);
      expect(unspecified.alcoholPercent, isNull);
    });

    test('structured identity takes precedence and history keeps its snapshot',
        () {
      final typed = CategoryItem.fromJson({
        'item_id': 804,
        'name': 'Пиво бут Garage Hard Lemon 0.44 л 4,6%',
        'price': 650,
        'unit': 'шт',
        'item_type': 'Слабоалкогольный напиток',
        'packaging_type': 'Бутылка',
        'material': 'ПЭТ',
        'volume_liters': 0.5,
        'alcohol_percent': 4.5,
        'category': {'category_id': 12, 'name': 'Пиво'},
      });
      final snapshot = item_model.Item.fromCategoryItem(typed).toJson();
      final history = presentOrderItem({
        'item_id': 804,
        'amount': 2,
        'item_data': snapshot,
      });
      expect(history.name, 'Garage Hard Lemon');
      expect(history.type, 'Слабоалкогольный напиток');
      expect(history.volumeLabel, '0,5 л');
      expect(history.alcoholLabel, '4,5%');
      expect(history.material, 'ПЭТ');
      expect(history.attributes, [
        'Слабоалкогольный напиток',
        'Бутылка',
        'ПЭТ',
        '0,5 л',
        '4,5%',
      ]);
      final weight = presentItem(item_model.Item(
          itemId: 805, name: 'Сыр 250 г', price: 1000, unit: 'кг'));
      expect(weight.weightLabel, '0,25 кг');
      expect(weight.volumeLabel, isNull);
    });
  });
}
