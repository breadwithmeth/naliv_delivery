import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/model/item.dart' as item_model;
import 'package:naliv_delivery/utils/api.dart';

void main() {
  group('server payload normalization', () {
    test('CategoryItemsResponse tolerates mixed scalar types and singleton maps', () {
      final response = CategoryItemsResponse.fromJson(<String, dynamic>{
        'success': 'true',
        'data': <String, dynamic>{
          'category': <String, dynamic>{
            'id': '12',
            'name': 'Пиво',
          },
          'business': <String, dynamic>{
            'id': '5',
            'name': 'Тестовый магазин',
          },
          'items': <dynamic>[
            <String, dynamic>{
              'id': '101',
              'name': 'Жигули',
              'price': '950,5',
              'visible': null,
              'amount': '7',
              'measure': 'шт.',
              'category': <String, dynamic>{
                'id': '12',
                'name': 'Пиво',
              },
              'options': <String, dynamic>{
                'option_id': '3',
                'name': 'Тара',
                'required': '1',
                'selection': 'SINGLE',
                'variants': <String, dynamic>{
                  'relation_id': '9',
                  'item_id': '91',
                  'price_type': 'FIXED',
                  'name': '1 л',
                  'price': 30,
                  'parent_item_amount': '1.5',
                },
              },
              'promotions': <String, dynamic>{
                'detail_id': '4',
                'type': 'DISCOUNT',
                'discount': '10',
                'name': 'Скидка',
              },
            },
            null,
            <String, dynamic>{
              'item_id': 102,
              'name': 'Fallback item',
              'price': 100,
              'category_id': '12',
              'category': 'Пиво',
            },
          ],
          'pagination': <String, dynamic>{
            'page': '1',
            'limit': '20',
            'total': '2',
            'total_pages': '3',
          },
          'categories_included': <dynamic>['12', 13.0, null, 'bad'],
          'subcategories_count': '1',
        },
      });

      expect(response.success, isTrue);
      expect(response.data.items, hasLength(2));
      expect(response.data.items.first.itemId, 101);
      expect(response.data.items.first.price, 950.5);
      expect(response.data.items.first.visible, 1);
      expect(response.data.items.first.options, isNotNull);
      expect(response.data.items.first.options!.single.variants.single.parentItemAmount, 1.5);
      expect(response.data.items.first.promotions, isNotNull);
      expect(response.data.items.first.promotions!.single.type, 'DISCOUNT');
      expect(response.data.items.last.category.name, 'Пиво');
      expect(response.data.pagination.totalPages, 3);
      expect(response.data.categoriesIncluded, <int>[12, 13]);
    });

    test('Promotion tolerates invalid dates and singleton detail payloads', () {
      final promotion = Promotion.fromJson(<String, dynamic>{
        'id': '40',
        'name': 'Promo',
        'start_promotion_date': 'not-a-date',
        'end_promotion_date': null,
        'businessId': '5',
        'visible': '1',
        'is_active': 'true',
        'details': <String, dynamic>{
          'detail_id': '4',
          'type': 'DISCOUNT',
          'discount': '5',
          'item_id': '101',
          'name': 'Item',
        },
        'stories': <String, dynamic>{
          'story_id': '1',
          'cover': 'https://example.com/story.jpg',
          'marketing_promotion_id': '40',
          'promo': 'Story',
        },
      });

      expect(promotion.marketingPromotionId, 40);
      expect(promotion.startPromotionDate.year, 1970);
      expect(promotion.endPromotionDate.year, 1970);
      expect(promotion.businessId, 5);
      expect(promotion.isActive, isTrue);
      expect(promotion.details, hasLength(1));
      expect(promotion.stories, isNotNull);
      expect(promotion.stories, hasLength(1));
    });

    test('raw item model normalizes mixed scalar values and singleton nested maps', () {
      final item = item_model.Item.fromJson(<String, dynamic>{
        'id': '301',
        'name': 'Пиво IPA',
        'description': 404,
        'price': '1230,5',
        'img': 'https://example.com/item.png',
        'code': 9001,
        'measure': 'л',
        'quantity': '0.5',
        'categoryId': '12',
        'businessId': '3',
        'amount': '15',
        'category': <String, dynamic>{
          'id': '12',
          'name': 'Разливное пиво',
          'subcategories': <String, dynamic>{
            'id': '77',
            'name': 'IPA',
          },
        },
        'options': <String, dynamic>{
          'option_id': '1',
          'name': 'Тара',
          'required': '1',
          'selection': 'SINGLE',
          'variants': <String, dynamic>{
            'relation_id': '2',
            'item_id': '22',
            'price_type': 'FIXED',
            'name': '1.25 л',
            'price': '60',
            'parent_item_amount': '1.25',
          },
        },
        'promotions': <String, dynamic>{
          'detail_id': '7',
          'type': 'DISCOUNT',
          'discount': '15',
          'name': 'Минус 15%',
          'start_date': '2025-01-01T00:00:00.000Z',
          'end_date': '2027-01-01T00:00:00.000Z',
        },
      });

      expect(item.itemId, 301);
      expect(item.description, '404');
      expect(item.price, 1230.5);
      expect(item.quantity, 0.5);
      expect(item.category?.categoryId, 12);
      expect(item.category?.subcategories, hasLength(1));
      expect(item.options, isNotNull);
      expect(item.options!.single.optionItems.single.parentItemAmount, 1.25);
      expect(item.promotions, isNotNull);
      expect(item.promotions!.single.discountType, 'PERCENT');
    });
  });
}
