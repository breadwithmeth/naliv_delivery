import 'dart:convert';

import 'package:http/http.dart' as http;

/// Synthetic complete category. Same SKU IDs in two stores expose scope leaks.
class CategoryMerchandisingFixture {
  static const priorities = <int, Map<int, List<int>>>{
    1: {
      2: [104, 105, 104, 999999, 107, 108],
    },
    2: {},
  };

  static List<Map<String, Object?>> rows(int businessId) => [
        for (var id = 100; id < 115; id++)
          {
            'item_id': id,
            'business_id': businessId,
            'name': switch (id) {
              102 => 'Действующая акция, Напиток, 0,5 л',
              104 => 'Приоритет категории, Напиток, 0,5 л',
              105 => 'Приоритет и акция, Напиток, 0,5 л',
              106 => 'Истёкшая акция, Напиток, 0,5 л',
              107 => 'Нет в наличии, Напиток, 0,5 л',
              108 => 'Скрытая позиция, Напиток, 0,5 л',
              _ => 'Обычный товар $id, Напиток, 0,5 л',
            },
            'price': 1000 + id,
            'amount': id == 107 ? 0 : 20,
            'visible': id == 108 ? 0 : 1,
            'measure': 'шт.',
            'category': {'category_id': 2, 'name': 'Вино'},
            if ({102, 105, 106, 107, 108}.contains(id))
              'promotions': [
                {
                  'detail_id': id,
                  'name': 'Синтетическая акция',
                  'type': 'DISCOUNT',
                  'discount': 10,
                  'start_date': '2020-01-01',
                  'end_date': id == 106 ? '2021-01-01' : '2099-01-01',
                },
              ],
          },
      ];

  static http.Response? respond(http.Request request) {
    final query = request.url.queryParameters;
    final store = int.tryParse(query['business_id'] ?? '');
    if (request.method != 'GET' ||
        request.url.path != '/api/categories/2/items' ||
        !{1, 2}.contains(store) ||
        query['page'] != '1' ||
        query['limit'] != '60' ||
        query.length != 3) {
      return null;
    }
    final items = rows(store!);
    return http.Response(
      jsonEncode({
        'success': true,
        'data': {
          'items': items,
          'pagination': {'page': 1, 'total_pages': 1, 'total': items.length},
        },
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
