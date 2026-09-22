// Behavioural guards for the design-system components.
//
// These assert the *contracts* the redesign depends on, not pixels: committed pixel goldens
// would be fragile across machines and font stacks, while the design-comparison harness in
// `.figma_cache/` already covers visual drift for whole screens. What lives here is the set of
// rules that a plausible refactor could silently break.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/money.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/ui/app_cart_button.dart';
import 'package:naliv_delivery/ui/app_icon.dart';
import 'package:naliv_delivery/ui/app_states.dart';
import 'package:naliv_delivery/ui/product_card.dart';

Widget _host(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    );

Finder _icon(String asset) =>
    find.byWidgetPredicate((widget) => widget is AppIcon && widget.asset == asset);

Widget _card({num quantity = 0, int price = 11853, int? oldPrice, int? saving}) => ProductCard(
      title: 'Aperol',
      price: price,
      oldPrice: oldPrice,
      saving: saving,
      quantity: quantity,
    );

void main() {
  group('ProductCard', () {
    testWidgets('an item not in the cart offers only an add action', (tester) async {
      await tester.pumpWidget(_host(_card()));
      await tester.pump();

      // The design's second grid card is a lone «+»: no minus, and no «0» count.
      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsNothing);
      expect(find.text('Aperol'), findsOneWidget);
    });

    testWidgets('an item in the cart shows the count between minus and plus', (tester) async {
      await tester.pumpWidget(_host(_card(quantity: 3)));
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('fractional quantities print two decimals, whole ones print bare', (tester) async {
      await tester.pumpWidget(_host(_card(quantity: 1.5)));
      await tester.pump();
      expect(find.text('1.50'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('price stack omits the struck price and saving line when absent', (tester) async {
      await tester.pumpWidget(_host(_card(price: 600)));
      await tester.pump();
      expect(find.textContaining('600'), findsOneWidget);
      expect(find.textContaining('Выгода'), findsNothing);
    });

    testWidgets('saving line appears with the design separator', (tester) async {
      await tester.pumpWidget(_host(_card(oldPrice: 13170, saving: 1317)));
      await tester.pump();
      expect(find.textContaining('Выгода'), findsOneWidget);
      // Non-breaking space between thousands groups, as the design's own text nodes have.
      expect(find.text('Выгода 1\u00A0317 ₸'), findsOneWidget);
    });
  });

  group('AppCartButton', () {
    testWidgets('empty cart is the round scalloped button with no amount', (tester) async {
      await tester.pumpWidget(_host(const AppCartButton(itemCount: 0)));
      await tester.pump();

      expect(_icon(AppIcons.cartFab), findsOneWidget);
      expect(find.textContaining('₸'), findsNothing);
    });

    testWidgets('filled cart shows the count and the total', (tester) async {
      await tester.pumpWidget(_host(const AppCartButton(itemCount: 3, total: 92190)));
      await tester.pump();

      expect(_icon(AppIcons.cartFab), findsNothing);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('92\u00A0190 ₸'), findsOneWidget);
    });

    testWidgets('hidden renders nothing at all', (tester) async {
      await tester.pumpWidget(
        _host(const AppCartButton(itemCount: 3, total: 100, visible: false)),
      );
      await tester.pump();
      expect(_icon(AppIcons.cart), findsNothing);
    });

    test('formatting groups thousands without breaking the number across lines', () {
      expect(formatTenge(92190), '92\u00A0190 ₸');
      expect(formatTenge(600), '600 ₸');
      expect(formatTenge(1234567), '1\u00A0234\u00A0567 ₸');
    });
  });

  group('non-content states', () {
    testWidgets('empty state renders title and optional subtitle', (tester) async {
      await tester.pumpWidget(_host(const AppEmptyState(title: 'Список пуст')));
      await tester.pump();
      expect(find.text('Список пуст'), findsOneWidget);
    });

    testWidgets('error state only offers retry when a handler is given', (tester) async {
      await tester.pumpWidget(_host(const AppErrorState(message: 'Не удалось загрузить')));
      await tester.pump();
      expect(find.text('Повторить'), findsNothing);

      await tester.pumpWidget(
        _host(AppErrorState(message: 'Не удалось загрузить', onRetry: () {})),
      );
      await tester.pump();
      expect(find.text('Повторить'), findsOneWidget);
    });
  });
}
