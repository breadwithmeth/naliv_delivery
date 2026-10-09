import 'package:naliv_delivery/model/item.dart';

// Frozen anonymous category215 captures; provenance is in public_bottling_catalog.json.
// Artwork is deliberately omitted to keep fixture transport deterministic.
const _capturedPour = {
  "item_id": 30318,
  "name": "Пиво розлив Kronenbourg Blanc 1664 1л 4.8% светлое нефильтрованное",
  "description":
      "Светлое нефильтрованное пиво Kronenbourg 1664 Blanc — европейский пшеничный (witbier) вариант с мягкой, слегка мутной внешностью и тонкой газированностью. Отличается свежим ароматом и деликатной текстурой.\n\nВо вкусе выражены цитрусовые оттенки апельсиновой цедры, легкая пряность кориандра и цветочные ноты, поддержанные мягким хлебным характером пшеничного солода. Нефильтрованный профиль придаёт более насыщенный аромат и округлость послевкусия.\n\nОбъём: 1 л; Алкоголь: 4.8% об.; Тип: светлое нефильтрованное пшеничное (witbier); Страна происхождения: Франция.",
  "price": 2600,
  "wholesale_price": null,
  "wholesale_min_amount": null,
  "amount": 20,
  "quantity_step": 1,
  "unit": "л.",
  "img":
      "https://i.ibb.co.com/k2YCYqPW/Gemini-Generated-Image-gb3dzgb3dzgb3dzg.png",
  "code": "KR-00000624",
  "category": {"category_id": 221, "name": "Светлое", "parent_category": 215},
  "visible": 1,
  "options": [
    {
      "option_id": 579,
      "name": "Литраж",
      "required": 1,
      "selection": "SINGLE",
      "variants": [
        {
          "item_name": "Пластиковая бутылка 1л",
          "relation_id": 2710,
          "item_id": 1091,
          "price_type": "ADD",
          "price": 110,
          "parent_item_amount": 1
        },
        {
          "item_name": "Пластиковая бутылка 2л",
          "relation_id": 2711,
          "item_id": 1092,
          "price_type": "ADD",
          "price": 100,
          "parent_item_amount": 2
        },
        {
          "item_name": "Пластиковая бутылка 3л + ручка",
          "relation_id": 2713,
          "item_id": 1154,
          "price_type": "ADD",
          "price": 150,
          "parent_item_amount": 3
        }
      ]
    }
  ],
  "promotions": [],
  "is_liked": false
};
const _capturedGift = {
  "item_id": 1186,
  "name": "Пиво розлив Бархатное Павлодар 1л 4.3% темное",
  "description":
      "Тёмное разливное пиво «Бархатное» из Павлодара — напиток с мягкой, бархатистой текстурой и умеренной плотностью. Отличается свежестью разливного продукта и комфортным ощущением во рту.\n\nВо вкусе доминируют ноты жареного солода, карамели и тёмного шоколада с лёгкой кофейной горчинкой; аромат смещён в сторону обжаренных и карамельных оттенков. Умеренная горечь и сбалансированная сладость создают плавный профиль.\n\nОбъём: 1 л. Крепость: 4,3% об. Тип: тёмное разливное пиво. Производство: Павлодар, Казахстан.",
  "price": 890,
  "wholesale_price": null,
  "wholesale_min_amount": null,
  "amount": 77.72,
  "quantity_step": 1,
  "unit": "л.",
  "img":
      "https://i.ibb.co.com/rRybgG17/Gemini-Generated-Image-v6qx1ev6qx1ev6qx.png",
  "code": "AB-00000374",
  "category": {"category_id": 220, "name": "Темное", "parent_category": 215},
  "visible": 1,
  "options": [
    {
      "option_id": 675,
      "name": "Литраж",
      "required": 1,
      "selection": "SINGLE",
      "variants": [
        {
          "item_name": "Пластиковая бутылка 1л",
          "relation_id": 3094,
          "item_id": 1091,
          "price_type": "ADD",
          "price": 110,
          "parent_item_amount": 1
        },
        {
          "item_name": "Пластиковая бутылка 2л",
          "relation_id": 3095,
          "item_id": 1092,
          "price_type": "ADD",
          "price": 100,
          "parent_item_amount": 2
        },
        {
          "item_name": "Пластиковая бутылка 3л + ручка",
          "relation_id": 3097,
          "item_id": 1154,
          "price_type": "ADD",
          "price": 150,
          "parent_item_amount": 3
        }
      ]
    }
  ],
  "promotions": [
    {
      "detail_id": 8692,
      "type": "SUBTRACT",
      "base_amount": 2,
      "add_amount": 1,
      "discount": null,
      "name": "2+1",
      "promotion": {
        "marketing_promotion_id": 355,
        "name": "Выгодный розлив",
        "start_promotion_date": "2026-06-01T00:00:00.000Z",
        "end_promotion_date": "2027-08-05T00:00:00.000Z"
      }
    }
  ],
  "is_liked": false
};

Item capturedPourSurfaceItem({bool gift = false}) =>
    Item.fromJson({...gift ? _capturedGift : _capturedPour, 'img': ''});

// Capacity and REPLACE alterations are synthetic boundaries, not production claims.
Item fractionalPourSurfaceItem({bool replacement = false}) => Item.fromJson({
      ..._capturedPour,
      'item_id': replacement ? 9202 : 9201,
      'name':
          replacement ? 'Фикстура · замена цены' : 'Фикстура · дробный объём',
      'img': '',
      'options': [
        {
          'option_id': 579,
          'name': 'Литраж',
          'required': 1,
          'selection': 'SINGLE',
          'variants': [
            if (!replacement)
              {
                'relation_id': 2710,
                'item_id': 1091,
                'item_name': 'Бутылка 0.5 л',
                'parent_item_amount': 0.5,
                'price_type': 'ADD',
                'price': 100
              },
            {
              'relation_id': 2711,
              'item_id': 1092,
              'item_name': 'Бутылка 1.25 л',
              'parent_item_amount': 1.25,
              'price_type': replacement ? 'REPLACE' : 'ADD',
              'price': replacement ? 500 : 100
            },
          ],
        },
      ],
    });

Item syntheticThreePlusOneSurfaceItem(
        {bool onlyOneLitre = false, double stock = 24}) =>
    Item.fromJson({
      ..._capturedGift,
      'item_id': 9301,
      'name': 'Фикстура · розлив 3+1',
      'description':
          'Синтетический пример: напиток 1000 ₸/л, вся тара платная.',
      'price': 1000,
      'amount': stock,
      'img': '',
      'options': [
        {
          'option_id': 930,
          'name': 'Литраж',
          'required': 1,
          'selection': 'SINGLE',
          'variants': [
            {
              'relation_id': 93101,
              'item_id': 1091,
              'item_name': 'Бутылка 1 л',
              'parent_item_amount': 1,
              'price_type': 'ADD',
              'price': 100,
            },
            if (!onlyOneLitre)
              {
                // 1.5 l keeps the mixed-container boundary the tests need without relying on the
                // withdrawn three-litre bottles.
                'relation_id': 93103,
                'item_id': 1154,
                'item_name': 'Бутылка 1,5 л',
                'parent_item_amount': 1.5,
                'price_type': 'ADD',
                'price': 120,
              },
          ],
        },
      ],
      'promotions': [
        {
          'type': 'SUBTRACT',
          'base_amount': 3,
          'add_amount': 1,
          'name': '3+1',
          'promotion': {
            'marketing_promotion_id': 930,
            'name': 'Фикстура 3+1',
            'start_promotion_date': '2026-01-01T00:00:00.000Z',
            'end_promotion_date': '2030-01-01T00:00:00.000Z',
          },
        },
      ],
    });
