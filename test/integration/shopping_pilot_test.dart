import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naliv_delivery/features/checkout/ui/payment_success_page.dart';
import 'package:naliv_delivery/ui/app_cart_button.dart';
import 'package:naliv_delivery/ui/product_card.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/liked_storage_service.dart';
import 'package:provider/provider.dart';

import '../../tool/design/shopping_pilot.dart';
import '../support/design_surfaces.dart';
import '../support/remaining_milestone_fixture.dart';
import '../support/haptic_calls.dart';

Future<void> _activate(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scroller = find.byWidgetPredicate((w) =>
        w is Scrollable && w.axisDirection == AxisDirection.down).first;
    await tester.scrollUntilVisible(target, 180, scrollable: scroller);
  }
  await Scrollable.ensureVisible(tester.element(target), alignment: .35);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('one offline trip carries the selected shop through to confirmed payment',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SurfaceFixtureClient.resetUnexpectedRequests();
    final calls = recordHapticCalls(tester);
    await http.runWithClient(() async {
      await tester.pumpWidget(const ShoppingPilot());
      Finder key(String name) => find.byKey(ValueKey(name));
      Future<void> tap(Finder f) => _activate(tester, f);
      await tap(find.text('Пройти покупку'));
      await tap(key('home-store-card'));
      await tap(key('home-store-2'));
      await tap(find.bySemanticsLabel('Слабоалкогольные напитки').first);
      await tap(key('catalog-open-2'));
      await tap(find.descendant(of: find.byType(ProductCard).first,
          matching: find.byType(InkWell)).first);
      await tap(find.widgetWithText(FilledButton, 'В корзину'));
      await tap(find.byTooltip('Назад'));
      await tap(find.byType(AppCartButton));
      await tap(find.text('Оформить'));
      await tap(key('checkout-mode-pickup'));
      await tap(key('checkout-submit'));
      final order = RemainingMilestoneFixture.orders.single;
      expect(order['business_id'], 2);
      expect(order['delivery_type'], 'PICKUP');
      await tap(key('payment-card-fixture-card-1'));
      final beforePay = List.of(calls);
      await tap(key('pay-order-button'));
      expect(find.byType(PaymentSuccessPage), findsOneWidget);
      expect(order['payment_status'], 'completed');
      expect(calls, beforePay, reason: 'No success haptic for money movement');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, SurfaceFixtureClient.new);
    expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the bundled trial confirms first add and later quantity changes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    enableQuantityClicks(tester);
    final impacts = recordHapticCalls(tester);
    SurfaceFixtureClient.resetUnexpectedRequests();
    await http.runWithClient(() async {
      await tester.pumpWidget(const ShoppingPilot());
        await tester.tap(find.text('Карточка товара'));
        await tester.pumpAndSettle();
        final add = find.widgetWithText(FilledButton, 'В корзину');
        expect(add, findsOneWidget);
        await tester.tap(add);
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();
        expect(find.textContaining('В корзине'), findsWidgets);
        expect(impacts, [lightImpact]);
        final plus = find.byTooltip('Увеличить');
        await Scrollable.ensureVisible(tester.element(plus), alignment: .4);
        await tester.pumpAndSettle();
        await tester.tap(plus);
        await tester.pumpAndSettle();
        expect(find.text('В корзине: 2 шт'), findsOneWidget);
        expect(impacts, [lightImpact, selectionClick]);
        await tester.tap(find.text('К выбору'));
        await tester.pumpAndSettle();
    }, SurfaceFixtureClient.new);
    expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the heart trial persists both confirmed states for its fixture account', (tester) async {
    SurfaceFixtureClient.resetUnexpectedRequests();
    await http.runWithClient(() async {
      await tester.pumpWidget(const ShoppingPilot());
      await tester.tap(find.text('Карточка товара'));
      await tester.pumpAndSettle();
      for (final expected in [true, false]) {
        await tester.tap(find.byTooltip('В избранное'));
        await tester.pumpAndSettle();
        expect(await LikedStorageService.isLiked(businessId: 1, itemId: 100), expected);
      }
    }, SurfaceFixtureClient.new);
    expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
  });

  testWidgets('ten different first adds remain ten after a delete and undo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SurfaceFixtureClient.resetUnexpectedRequests();
    await http.runWithClient(() async {
      await tester.pumpWidget(const ShoppingPilot());
      await tester.tap(find.text('Каталог'));
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('category-product-0'));
      final cart = tester.element(first).read<CartProvider>();
      for (var i = 0; i < 10; i++) {
        final add = find.descendant(
          of: find.byKey(ValueKey('category-product-$i')),
          matching: find.byWidgetPredicate((w) => w is StepTap && w.label == 'Добавить'),
        );
        await tester.scrollUntilVisible(add, 180, scrollable: find.byType(Scrollable).first);
        await Scrollable.ensureVisible(tester.element(add), alignment: .45);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(cart.activeDisplayGroups.length, i + 1);
      }
      final contents = cart.toJsonForOrder();
      await tester.tap(find.byKey(const ValueKey('cart-stamp')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Удалить товар').first);
      await tester.pump();
      expect(cart.activeDisplayGroups, hasLength(9));
      await tester.tap(find.byKey(const ValueKey('cart-undo')));
      await tester.pumpAndSettle();
      expect(cart.toJsonForOrder(), unorderedEquals(contents));
      await tester.pumpWidget(const SizedBox.shrink());
    }, SurfaceFixtureClient.new);
    expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
  });
}
