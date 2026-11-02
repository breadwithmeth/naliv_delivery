import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/widgets/cart_persistence_notice.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/preferences_store.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('TikTokSans')
          ..addFont(rootBundle
              .load('assets/fonts/TikTokSans/TikTokSans-Variable.ttf')))
        .load();
  });

  testWidgets(
      'failed cart save stays recoverable until a durable retry succeeds',
      (tester) async {
    final store = OnboardingPreferences({})..install();
    final cart = CartProvider();
    final navigatorKey = GlobalKey<NavigatorState>();
    await cart.ensureLoaded();
    store.rejectedKeys.add('cart_items');
    cart.addItem(CartItem(
      itemId: 8101,
      name: 'Тоник',
      price: 100,
      quantity: 1,
      stepQuantity: 1,
      selectedVariants: const [],
      promotions: const [],
    ));
    expect(await cart.ensureSaved(), isFalse);
    await tester.binding.setSurfaceSize(const Size(320, 812));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      cart.dispose();
      await tester.binding.setSurfaceSize(null);
      SharedPreferences.setMockInitialValues({});
    });
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: cart,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child:
              CartPersistenceNotice(navigatorKey: navigatorKey, child: child!),
        ),
        home: const Scaffold(body: TextField()),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'Незавершённый поиск');
    expect(find.text('Не удалось сохранить корзину'), findsOneWidget);
    await tester.tap(find.text('Повторить сохранение'));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось сохранить корзину'), findsOneWidget);
    expect(find.text('Незавершённый поиск'), findsOneWidget);
    expect(cart.getTotalQuantityForItem(8101), 1);
    store.rejectedKeys.remove('cart_items');
    await tester.tap(find.text('Повторить сохранение'));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось сохранить корзину'), findsNothing);
    final restored = CartProvider();
    addTearDown(restored.dispose);
    await restored.ensureLoaded();
    expect(find.text('Незавершённый поиск'), findsOneWidget);
    expect(restored.getTotalQuantityForItem(8101), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'restore failure preserves stored data and offers an explicit retry',
      (tester) async {
    final store = OnboardingPreferences({'cart_items': '{broken'})..install();
    final cart = CartProvider();
    final navigatorKey = GlobalKey<NavigatorState>();
    await cart.ensureLoaded();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      cart.dispose();
      SharedPreferences.setMockInitialValues({});
    });
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: cart,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.light(),
        builder: (context, child) =>
            CartPersistenceNotice(navigatorKey: navigatorKey, child: child!),
        home: const Scaffold(body: TextField()),
      ),
    ));
    expect(find.text('Не удалось восстановить корзину'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Сохранить мой ввод');
    await tester.tap(find.text('Повторить загрузку'));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось восстановить корзину'), findsOneWidget);
    expect((await store.getAll())['flutter.cart_items'], '{broken');
    final repaired = jsonEncode({
      'business_id': 1,
      'items': [
        CartItem(
          itemId: 8102,
          name: 'Минеральная вода',
          price: 200,
          quantity: 2,
          stepQuantity: 1,
          selectedVariants: const [],
          promotions: const [],
        ).toJson(),
      ],
    });
    await store.setValue('String', 'flutter.cart_items', repaired);
    await tester.tap(find.text('Повторить загрузку'));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось восстановить корзину'), findsNothing);
    expect(find.text('Сохранить мой ввод'), findsOneWidget);
    expect(cart.getTotalQuantityForItem(8102), 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unreadable cart reset requires consent and durable persistence',
      (tester) async {
    final store = OnboardingPreferences({'cart_items': '{broken'})..install();
    final cart = CartProvider();
    final navigatorKey = GlobalKey<NavigatorState>();
    await cart.ensureLoaded();
    store.rejectedKeys.add('cart_items');
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      cart.dispose();
      SharedPreferences.setMockInitialValues({});
    });
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: cart,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.light(),
        builder: (context, child) =>
            CartPersistenceNotice(navigatorKey: navigatorKey, child: child!),
        home: const Scaffold(body: TextField()),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'Незавершённый ввод');
    final reset = find.byKey(const ValueKey('cart-discard-unreadable'));
    final semantics = tester.ensureSemantics();
    try {
      await tester.pump();
      final reachable = <SemanticsNode>[];
      void collect(SemanticsNode node) {
        reachable.add(node);
        node.visitChildren((child) {
          collect(child);
          return true;
        });
      }

      collect(tester.binding.renderViews.single.owner!.semanticsOwner!
          .rootSemanticsNode!);
      final accessibleReset = reachable
          .where((node) => node.getSemanticsData().label == 'Очистить корзину');
      expect(accessibleReset, hasLength(1),
          reason: 'Navigator routes must not prune global recovery controls');
      final resetNode = accessibleReset.single;
      expect(resetNode.flagsCollection.isHidden, isFalse);
      expect(
          resetNode.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      resetNode.owner!.performAction(resetNode.id, SemanticsAction.tap);
    } finally {
      semantics.dispose();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect((await store.getAll())['flutter.cart_items'], '{broken');
    expect(find.text('Незавершённый ввод'), findsOneWidget);

    await tester.tap(reset);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cart-confirm-discard')));
    await tester.pumpAndSettle();
    expect((await store.getAll())['flutter.cart_items'], '{broken');
    expect(cart.saveStatus.value, CartSaveStatus.restoreFailed);
    expect(find.text('Незавершённый ввод'), findsOneWidget);

    store.rejectedKeys.remove('cart_items');
    await tester.tap(reset);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cart-confirm-discard')));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось восстановить корзину'), findsNothing);
    expect(find.text('Незавершённый ввод'), findsOneWidget);
    final restored = CartProvider();
    addTearDown(restored.dispose);
    await restored.ensureLoaded();
    expect(restored.saveStatus.value, CartSaveStatus.saved);
    expect(restored.items, isEmpty);
    expect(await restored.bindBusiness(7), isTrue);
    expect(restored.businessId, 7);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact recovery keeps the focused form and confirmation usable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = OnboardingPreferences({'cart_items': '{broken'})..install();
    final cart = CartProvider();
    await cart.ensureLoaded();
    final navigatorKey = GlobalKey<NavigatorState>();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      cart.dispose();
      SharedPreferences.setMockInitialValues({});
    });
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: cart,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            viewInsets: const EdgeInsets.only(bottom: 300),
            viewPadding: const EdgeInsets.only(top: 48, bottom: 34),
            padding: const EdgeInsets.only(top: 48),
          ),
          child:
              CartPersistenceNotice(navigatorKey: navigatorKey, child: child!),
        ),
        home: const Scaffold(body: TextField()),
      ),
    ));
    final field = tester.getRect(find.byType(TextField));
    expect(field.height, greaterThanOrEqualTo(44));
    expect(field.bottom, lessThanOrEqualTo(512));
    await tester.tap(find.byType(TextField).hitTestable());
    await tester.enterText(find.byType(TextField), 'Сохранить ввод');
    final reset = find.byKey(const ValueKey('cart-discard-unreadable'));
    await tester.ensureVisible(reset);
    await tester.tap(reset.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Отмена').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Сохранить ввод'), findsOneWidget);
    expect((await store.getAll())['flutter.cart_items'], '{broken');
    expect(tester.takeException(), isNull);
  });
}
