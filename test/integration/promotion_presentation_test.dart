import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/core/money.dart';
import 'package:naliv_delivery/core/product_view.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/cart/ui/cart_page.dart';
import 'package:naliv_delivery/model/item.dart';
import 'package:naliv_delivery/pages/promotion_items_page.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Item _item({List<Map<String, dynamic>> promotions = const []}) =>
    Item.fromJson({
      'item_id': 91,
      'name': 'Aperol',
      'price': 13170,
      'unit': 'л',
      'amount': 50,
      'promotions': promotions,
    });

const _giftPromotion = {
  'detail_id': 8692,
  'type': 'SUBTRACT',
  'base_amount': 2,
  'add_amount': 1,
  'name': '2+1',
  'promotion': {
    'marketing_promotion_id': 355,
    'name': 'Выгодный розлив',
    'end_promotion_date': '2999-01-01T00:00:00.000Z',
  },
};

Future<void> _pumpCampaign(
  WidgetTester tester, {
  required Item item,
  required CartProvider cart,
  required Brightness brightness,
  required double scale,
}) async {
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: cart),
      ChangeNotifierProvider(create: (_) => LikedItemsProvider()),
    ],
    child: MaterialApp(
      theme:
          brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: PromotionItemsPage(
        promotionId: 44,
        businessId: 1,
        initialItems: [
          item,
          Item(
            itemId: 92,
            name: 'Второй товар',
            price: 1000,
            unit: 'шт',
            amount: 20,
          ),
        ],
        onCart: () {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final (width, scale) in [(375.0, 1.0), (320.0, 2.0)]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          'complete offer and quantity controls remain visible at '
          '$width/$scale/${brightness.name}', (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(Size(width, 812));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final semantics = tester.ensureSemantics();
        final item = Item.fromJson({
          'item_id': 91,
          'name': 'Aperol Riserva с длинным названием специальной коллекции',
          'price': 13170,
          'unit': 'шт',
          'amount': 20,
          'item_type': 'Аперитив',
          'country_name': 'Италия',
          'volume_liters': .5,
          'weight_kilograms': .75,
          'alcohol_percent': 11,
          'packaging_type': 'Бутылка',
          'material': 'Стекло',
          'promotions': [
            {
              'detail_id': 1,
              'type': 'DISCOUNT',
              'discount': 10,
              'name': '-10%',
            },
            _giftPromotion,
          ],
        });
        final view = ProductView.fromItem(item);
        final cart = CartProvider();
        await cart.bindBusiness(1);
        cart.incrementCatalogItem(item);
        final unexpected = <String>[];
        await http.runWithClient(() async {
          await _pumpCampaign(
            tester,
            item: item,
            cart: cart,
            brightness: brightness,
            scale: scale,
          );
          final card = find.byKey(const ValueKey('promotion-product-0'));
          final cardRect = tester.getRect(card);
          if (width == 375) {
            final second = tester.getRect(
              find.byKey(const ValueKey('promotion-product-1')),
            );
            expect(second.top, cardRect.top);
            expect(second.left, greaterThan(cardRect.right));
          } else {
            expect(cardRect.width, greaterThan(width / 2));
          }
          final facts = [
            view.title,
            ...view.metadata,
            view.unitPriceLabel,
            formatTenge(view.oldPrice!),
            formatTenge(view.saving!),
            view.discount!,
            view.promo!,
            view.bonus!,
          ];
          for (final fact in facts) {
            final visibleFact = find.descendant(
              of: card,
              matching: find.textContaining(fact),
            );
            expect(visibleFact, findsOneWidget);
            await Scrollable.ensureVisible(
              tester.element(visibleFact),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            final textRect = tester.getRect(visibleFact);
            final currentCard = tester.getRect(card);
            expect(textRect.left, greaterThanOrEqualTo(currentCard.left));
            expect(textRect.right, lessThanOrEqualTo(currentCard.right));
            expect(textRect.top, greaterThanOrEqualTo(currentCard.top));
            expect(textRect.bottom, lessThanOrEqualTo(currentCard.bottom));
          }
          final art = tester.getRect(find.descendant(
            of: card,
            matching: find.byIcon(Icons.image_outlined),
          ));
          for (final fact in [view.discount!, view.promo!, view.bonus!]) {
            final rect = tester.getRect(find.descendant(
              of: card,
              matching: find.textContaining(fact),
            ));
            expect(rect.top, greaterThan(art.bottom));
          }
          for (final label in [
            'Увеличить количество',
            'Уменьшить количество',
          ]) {
            final action = find.descendant(
              of: card,
              matching: find.bySemanticsLabel(label),
            );
            await Scrollable.ensureVisible(
              tester.element(action),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            expect(tester.getSize(action).width, greaterThanOrEqualTo(44));
            expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
            await tester.tap(action);
            await tester.pumpAndSettle();
            expect(
              cart.getCatalogQuantity(item),
              label == 'Увеличить количество' ? 2 : 1,
            );
          }
          expect(unexpected, isEmpty);
          expect(tester.takeException(), isNull);
        },
            () => MockClient((request) async {
                  unexpected.add('$request');
                  throw StateError('Unexpected request: $request');
                })).whenComplete(semantics.dispose);
      });
    }
  }

  group('cart gift line', () {
    testWidgets('free units appear as their own 0 ₸ line with the rule',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final item = _item(promotions: [_giftPromotion]);
      final cart = CartProvider();
      await cart.bindBusiness(1);
      cart.incrementCatalogItem(item);
      cart.incrementCatalogItem(item);
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ChangeNotifierProvider<CartProvider>.value(
        value: cart,
        child: MaterialApp(theme: AppTheme.light(), home: const CartPage()),
      ));
      await tester.pumpAndSettle();

      final group = cart.activeDisplayGroups.single;
      expect(group.freeQuantity, 1);
      expect(find.byKey(ValueKey('cart-gift-${group.key}')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('cart-gift-${group.key}')),
          matching: find.text('0 ₸'),
        ),
        findsOneWidget,
      );
      // The gift is not charged: two paid litres at 13 170 ₸.
      expect(cart.getTotalPrice(), 26340);
    });

    testWidgets('a cart without gifts shows no gift line', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final cart = CartProvider();
      await cart.bindBusiness(1);
      cart.incrementCatalogItem(_item());
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ChangeNotifierProvider<CartProvider>.value(
        value: cart,
        child: MaterialApp(theme: AppTheme.light(), home: const CartPage()),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cart-gift-label')), findsNothing);
    });
  });
}
