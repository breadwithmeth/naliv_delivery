import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:naliv_delivery/features/catalog/ui/supercategory_page.dart';
import 'package:naliv_delivery/features/checkout/ui/payment_success_page.dart';
import 'package:naliv_delivery/features/orders/ui/orders_page.dart';
import 'package:naliv_delivery/pages/checkout_page.dart';
import 'package:naliv_delivery/pages/payment_method_page.dart';
import 'package:naliv_delivery/features/product/ui/product_page.dart';
import 'package:naliv_delivery/ui/app_cart_button.dart';
import 'package:naliv_delivery/ui/product_card.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/design_surfaces.dart';
import '../test/support/remaining_milestone_fixture.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find.byWidgetPredicate((widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down).first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(finder, 200, scrollable: scrollable);
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: .3);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _RejectNativeNetwork extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Native e2e HTTP escaped the strict fixture client');
  }
}

void main() {
  final network = _RejectNativeNetwork();
  HttpOverrides.global = network;
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('catalog purchase reaches paid order history', (tester) async {
    SharedPreferences.setMockInitialValues({
      ...surfaceFixturePreferences,
    }..removeWhere((key, _) =>
        key == 'selected_business' ||
        key == 'selected_business_id' ||
        key == 'auth_token'));
    SurfaceFixtureClient.resetUnexpectedRequests();
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await http.runWithClient(() async {
      // The native runner registers engine callbacks before the fixture zone.
      // Re-register the existing handlers here so every frame uses this client.
      final dispatcher = tester.binding.platformDispatcher;
      dispatcher.onBeginFrame = dispatcher.onBeginFrame;
      dispatcher.onDrawFrame = dispatcher.onDrawFrame;
      await tester.pumpWidget(const DesignSurfaceApp(
        surface: 'active_route',
        brightness: Brightness.light,
      ));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Слабоалкогольные напитки').first);
      expect(find.byType(SupercategoryPage), findsOneWidget);
      await _tap(tester, find.text('Все').first);
      await _tap(
          tester,
          find
              .descendant(
                  of: find.byType(ProductCard).first,
                  matching: find.byType(InkWell))
              .first);
      expect(find.byType(ProductPage), findsOneWidget);
      await _tap(tester, find.text('В корзину'));
      final cart =
          tester.element(find.byType(ProductPage)).read<CartProvider>();
      await _tap(tester, find.byTooltip('Назад'));
      await _tap(tester, find.bySemanticsLabel('Увеличить количество').first);
      expect(cart.activeDisplayGroups.single.totalQuantity, 2);
      expect(cart.getTotalPrice(), 26340);
      await _tap(tester, find.byType(AppCartButton));
      await _tap(tester, find.text('Оформить'));
      await _tap(tester, find.byKey(const ValueKey('checkout-mode-pickup')));
      await _tap(tester, find.byKey(const ValueKey('checkout-sign-in')));
      await tester.enterText(
          find.byKey(const ValueKey('auth-phone-input')), '0000000000');
      await _tap(tester, find.byKey(const ValueKey('request-code-button')));
      await tester.enterText(
          find.byKey(const ValueKey('auth-code-input')), '123456');
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutPage), findsOneWidget);
      expect(
          Provider.of<CartProvider>(
                  tester.element(find.byType(CheckoutPage)), listen: false)
              .activeDisplayGroups.single.totalQuantity,
          2);
      // The shared send-code toast must expire before tapping the checkout footer.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('checkout-submit')));

      expect(find.byType(PaymentMethodPage), findsOneWidget);
      final order = RemainingMilestoneFixture.orders.single;
      expect(order['delivery_type'], 'PICKUP');
      expect(order['total_amount'], 26370);
      final lines = (order['items'] as List).cast<Map<String, dynamic>>();
      expect(lines.singleWhere((line) => line['item_id'] == 100)['amount'], 2);
      expect(
          lines.singleWhere((line) => line['item_id'] == 48044)['amount'], 1);
      expect(cart.hasActiveItems, isFalse);

      await _tap(
          tester, find.byKey(const ValueKey('payment-card-fixture-card-1')));
      await _tap(tester, find.byKey(const ValueKey('pay-order-button')));
      expect(find.byType(PaymentSuccessPage), findsOneWidget);
      expect(order['payment_status'], 'completed');
      await _tap(tester, find.byKey(const ValueKey('payment-success-orders')));
      expect(find.byType(OrdersPage), findsOneWidget);
      expect(find.text('№${order['order_id']}'), findsOneWidget);
      expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
      expect(network.attempts, 0,
          reason: 'No native HTTP client may bypass the strict fixture');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => SurfaceFixtureClient());
  });
}
