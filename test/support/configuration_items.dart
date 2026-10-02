import 'package:naliv_delivery/model/item.dart';

Map<String, dynamic> _variant(int relation, String name, num price,
        {num volume = 0}) =>
    {
      'relation_id': relation,
      'item_id': 1000 + relation,
      'item_name': name,
      'price_type': 'ADD',
      'price': price,
      'parent_item_amount': volume,
    };

Item fixtureOptionItem() => Item.fromJson({
      'item_id': 502,
      'name': 'Лимонад',
      'description': 'Лимонад с выбранными дополнениями.',
      'price': 900,
      'amount': 10,
      'quantity': 1,
      'unit': 'шт.',
      'business_id': 1,
      'options': [
        {
          'option_id': 7,
          'name': 'Сахар',
          'required': 1,
          'selection': 'SINGLE',
          'option_items': [
            _variant(41, 'Без сахара', 0),
            _variant(42, 'С сахаром', 0),
          ]
        },
        {
          'option_id': 8,
          'name': 'Добавки',
          'required': 1,
          'selection': 'MULTIPLE',
          'option_items': [
            _variant(51, 'Мята', 100),
            _variant(52, 'Лайм', 150),
          ]
        },
        {
          'option_id': 9,
          'name': 'Упаковка',
          'required': 0,
          'selection': 'SINGLE',
          'option_items': [
            _variant(61, 'Подарочная упаковка', 50),
          ]
        },
      ],
    });

Item fixturePourItem() => Item.fromJson({
      'item_id': 1,
      'name': 'Разливное пиво',
      'description': 'Напиток с доступной тарой.',
      'price': 1000,
      'amount': 12,
      'quantity': 1,
      'unit': 'л.',
      'business_id': 1,
      'options': [
        {
          'option_id': 1,
          'name': 'Тара',
          'required': 1,
          'selection': 'SINGLE',
          'option_items': [
            _variant(1, 'Бутылка 1 л', 50, volume: 1),
            _variant(2, 'Бутылка 2 л', 120, volume: 2),
          ]
        },
        {
          'option_id': 7,
          'name': 'Вкус',
          'required': 1,
          'selection': 'SINGLE',
          'option_items': [
            _variant(41, 'Классический', 0),
            _variant(42, 'Ягодный', 0),
          ]
        },
      ],
    });
