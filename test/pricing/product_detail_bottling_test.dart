import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradusy24/model/item.dart';
import 'package:gradusy24/pages/product_detail_page.dart';
import 'package:gradusy24/utils/business_provider.dart';
import 'package:gradusy24/utils/cart_provider.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/pages/product_detail_page.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';

void main() {
  group('ProductDetailPage self-bottling', () {
    testWidgets('uses explicit item unit for non-pour quantity labels',
        (tester) async {
      final item = Item(
        itemId: 99,
        name: 'Fresh lemonade',
        price: 1200,
        amount: 5,
        quantity: 1,
        unit: 'л.',
      );

      await tester.pumpWidget(_wrap(item));
      await tester.pumpAndSettle();

      expect(find.text('1 л.'), findsWidgets);
      expect(find.text('1 шт.'), findsNothing);
    });

    testWidgets('keeps pour flow for promotion payloads that use variants', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = Item.fromJson(<String, dynamic>{
        'item_id': 30318,
        'name': 'Пиво розлив Kronenbourg Blanc 1664 1л 4.8%',
        'price': 2600,
        'amount': 24,
        'quantity': 1,
        'unit': 'л.',
        'category': <String, dynamic>{
          'category_id': 53,
          'name': 'Разливное пиво',
          'parent_category': 36,
        },
        'options': <Map<String, dynamic>>[
          <String, dynamic>{
            'option_id': 579,
            'name': 'Литраж',
            'required': 1,
            'selection': 'SINGLE',
            'variants': <Map<String, dynamic>>[
              <String, dynamic>{
                'relation_id': 2710,
                'item_id': 1091,
                'price_type': 'ADD',
                'price': 110,
                'parent_item_amount': 1,
              },
              <String, dynamic>{
                'relation_id': 2711,
                'item_id': 1092,
                'price_type': 'ADD',
                'price': 100,
                'parent_item_amount': 2,
              },
              <String, dynamic>{
                'relation_id': 2713,
                'item_id': 1154,
                'price_type': 'ADD',
                'price': 150,
                'parent_item_amount': 3,
              },
            ],
          },
        ],
        'promotions': <Map<String, dynamic>>[
          <String, dynamic>{
            'detail_id': 2755,
            'type': 'SUBTRACT',
            'base_amount': 2,
            'add_amount': 1,
            'name': '2+1',
            'promotion': <String, dynamic>{
              'marketing_promotion_id': 50,
              'name': 'Специальное предложение +1',
              'start_promotion_date': '2025-07-31T12:00:00.000Z',
              'end_promotion_date': '2026-09-30T00:00:00.000Z',
            },
          },
        ],
      });

      expect(item.options, isNotNull);
      expect(item.options!.single.optionItems, hasLength(3));

      await tester.pumpWidget(_wrap(item));
      await tester.pumpAndSettle();

      expect(find.text('ОБЪЁМ'), findsOneWidget);
      expect(find.text('КОЛИЧЕСТВО'), findsNothing);
      expect(find.textContaining('2600 ₸'), findsWidgets);
      expect(find.text('1 л'), findsWidgets);
      expect(find.textContaining('4,8'), findsWidgets);
      expect(find.textContaining('бут.'), findsNothing);
      expect(find.textContaining('автоподарок'), findsNothing);
      expect(find.textContaining('Порог'), findsNothing);
      expect(find.textContaining('Прогресс считается'), findsNothing);
      expect(find.text('2+1'), findsOneWidget);
      expect(find.text('Добавьте ещё 1 л для подарка'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('+1 л в подарок'), findsOneWidget);
      expect(find.text('Подарок открыт!'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Разбор цены'), findsOneWidget);
      expect(find.text('2 л напитка'), findsOneWidget);
      expect(find.text('1 л в подарок'), findsOneWidget);
      expect(find.text('1×2 л'), findsOneWidget);
    });

    testWidgets(
        'shows bottle-aware promo totals without discounting bottle price',
        (tester) async {
      final item = _buildPourItem(
        amount: 5,
        bottles: <ItemOptionItem>[
          ItemOptionItem(
            relationId: 1,
            itemId: 101,
            priceType: 'FIXED',
            item_name: '1 л бутылка',
            price: 50,
            parentItemAmount: 1,
          ),
          ItemOptionItem(
            relationId: 2,
            itemId: 102,
            priceType: 'FIXED',
            item_name: '2 л бутылка',
            price: 120,
            parentItemAmount: 2,
          ),
        ],
        promotions: <ItemPromotion>[
          ItemPromotion(
            promotionId: 1,
            name: 'Ten percent',
            discountType: 'PERCENT',
            discountValue: 10,
          ),
        ],
      );

      await tester.pumpWidget(_wrap(item));
      await tester.pumpAndSettle();

      expect(find.text('950 ₸'), findsWidgets);
      expect(find.text('1050 ₸'), findsWidgets);
      expect(find.text('945 ₸'), findsNothing);
    });

    testWidgets('loops promo progress and shows reward multiplier after repeated gifts', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = _buildPourItem(
        amount: 10,
        bottles: <ItemOptionItem>[
          ItemOptionItem(
            relationId: 1,
            itemId: 101,
            priceType: 'FIXED',
            item_name: '1 л бутылка',
            price: 50,
            parentItemAmount: 1,
          ),
          ItemOptionItem(
            relationId: 2,
            itemId: 102,
            priceType: 'FIXED',
            item_name: '2 л бутылка',
            price: 100,
            parentItemAmount: 2,
          ),
        ],
        promotions: <ItemPromotion>[
          ItemPromotion(
            promotionId: 1,
            name: '2+1',
            discountType: 'SUBTRACT',
            discountValue: 0,
            baseAmount: 2,
            addAmount: 1,
          ),
        ],
      );

      await tester.pumpWidget(_wrap(item));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('+2 л в подарок'), findsOneWidget);
      expect(find.text('Добавьте ещё 2 л для следующего подарка'), findsOneWidget);
      expect(find.text('x2'), findsOneWidget);
    });

    testWidgets('does not overfill when max amount has no exact bottle combination', (tester) async {
      final item = _buildPourItem(
        amount: 2.5,
        bottles: <ItemOptionItem>[
          ItemOptionItem(
            relationId: 2,
            itemId: 102,
            priceType: 'FIXED',
            item_name: '2 л бутылка',
            price: 100,
            parentItemAmount: 2,
          ),
        ],
      );

      await tester.pumpWidget(_wrap(item));
      await tester.pumpAndSettle();

      expect(find.text('2100 ₸'), findsWidgets);

      expect(find.byIcon(Icons.add_rounded).hitTestable(), findsNothing);
      expect(find.text('2100 ₸'), findsWidgets);
      expect(find.text('4200 ₸'), findsNothing);
    });
  });
}

Widget _wrap(Item item) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
      ChangeNotifierProvider<BusinessProvider>(create: (_) => BusinessProvider()),
    ],
    child: MaterialApp(
      home: ProductDetailPage(item: item),
    ),
  );
}

Item _buildPourItem({
  required double amount,
  required List<ItemOptionItem> bottles,
  List<ItemPromotion> promotions = const <ItemPromotion>[],
}) {
  return Item(
    itemId: 1,
    name: 'Beer from tap',
    price: 1000,
    image: '',
    amount: amount,
    category: ItemCategory(categoryId: 1, name: 'Beer'),
    options: <ItemOption>[
      ItemOption(
        optionId: 1,
        name: 'Bottle',
        required: 1,
        selection: 'SINGLE',
        optionItems: bottles,
      ),
    ],
    promotions: promotions,
  );
}
