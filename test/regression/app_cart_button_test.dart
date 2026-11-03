import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/money.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/ui/app_cart_button.dart';
import 'package:naliv_delivery/ui/frosted_dock.dart';

const _stamp = ValueKey('cart-stamp');
const _pill = ValueKey('cart-pill');
const _badge = ValueKey('cart-badge');

Future<void> _pump(
  WidgetTester tester, {
  required int items,
  num? total,
  Size size = const Size(375, 812),
  double textScale = 1,
  bool dark = true,
  bool disableAnimations = false,
  VoidCallback? onTap,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(top: 48, bottom: 34),
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: child!,
    ),
    home: Scaffold(
      body: FrostedDock(
        content: const SizedBox.expand(),
        dock: AppCartButton(itemCount: items, total: total, onTap: onTap),
      ),
    ),
  ));
}

void main() {
  testWidgets('empty cart is the 78 px stamp, 27 px above the bar, centred',
      (tester) async {
    await _pump(tester, items: 0);
    final box = tester.getRect(find.byType(AppCartButton));
    final stamp = tester.getRect(find.byKey(_stamp));
    expect(stamp.size, const Size.square(78));
    expect(stamp.center.dx, closeTo(187.5, .5));
    expect(box.height, 78);
    // The bar starts 27 px under the stamp's top and runs to the screen's end,
    // so the stamp's lower part sits on it.
    expect(812 - 34 - FrostedDock.basePadding - box.bottom, closeTo(0, .01));
    expect(find.byKey(_pill), findsNothing);
    expect(find.byKey(_badge), findsNothing);
    expect(AppCartButton.stampOverhang, 27);
  });

  testWidgets('filled cart opens a pill behind the stamp and stays centred',
      (tester) async {
    await _pump(tester, items: 3, total: 92190);
    final stamp = tester.getRect(find.byKey(_stamp));
    final pill = tester.getRect(find.byKey(_pill));
    final badge = tester.getRect(find.byKey(_badge));

    expect(pill.height, closeTo(34, .01));
    expect(pill.left, closeTo(stamp.left + 47, .01),
        reason: 'starts behind the stamp');
    expect(pill.right, greaterThan(stamp.right));
    expect((stamp.left + pill.right) / 2, closeTo(187.5, 1),
        reason: 'stamp and pill are centred together');
    expect(stamp.center.dx, lessThan(187.5));
    expect(pill.center.dy, closeTo(stamp.center.dy + 2, .5));

    expect(badge.size, const Size.square(32));
    expect(badge.topLeft, stamp.topLeft + const Offset(-4, -2));
    expect(find.descendant(of: find.byKey(_badge), matching: find.text('3')),
        findsOneWidget);
    expect(find.text(formatTenge(92190)), findsOneWidget);
    expect(find.text('Корзина'), findsNothing);
  });

  testWidgets('the pill hugs the total and opens and closes with the cart',
      (tester) async {
    await _pump(tester, items: 1, total: 900);
    final short = tester.getRect(find.byKey(_pill)).width;
    await _pump(tester, items: 1, total: 1234567);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_pill)).width, greaterThan(short));

    await _pump(tester, items: 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(_pill), findsOneWidget, reason: 'still closing');
    expect(find.text(formatTenge(1234567)), findsOneWidget,
        reason: 'the last total stays while the pill closes');
    await tester.pumpAndSettle();
    expect(find.byKey(_pill), findsNothing);
    expect(tester.getRect(find.byKey(_stamp)).center.dx, closeTo(187.5, .5));

    await _pump(tester, items: 2, total: 500);
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byKey(_pill), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion changes state at once', (tester) async {
    await _pump(tester, items: 0, disableAnimations: true);
    await _pump(tester, items: 4, total: 7000, disableAnimations: true);
    await tester.pump();
    final stamp = tester.getRect(find.byKey(_stamp));
    final pill = tester.getRect(find.byKey(_pill));
    expect((stamp.left + pill.right) / 2, closeTo(187.5, 1));
    await _pump(tester, items: 0, disableAnimations: true);
    await tester.pump();
    expect(find.byKey(_pill), findsNothing);
  });

  testWidgets('keeps its label, tap and 44 px target', (tester) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    await _pump(tester, items: 2, total: 4500, onTap: () => taps++);
    expect(
      find.bySemanticsLabel(
          'Открыть корзину, товаров: 2, ${formatTenge(4500)}'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(_pill));
    await tester.tap(find.byKey(_stamp));
    expect(taps, 2);
    expect(tester.getRect(find.byKey(_stamp)).shortestSide,
        greaterThanOrEqualTo(44));

    await _pump(tester, items: 0, onTap: () => taps++);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Открыть корзину'), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
      'large totals at 320 px and 2x text neither overflow nor leave '
      'the screen', (tester) async {
    for (final dark in [true, false]) {
      await _pump(
        tester,
        items: 120,
        total: 123456789,
        size: const Size(320, 640),
        textScale: 2,
        dark: dark,
      );
      await tester.pumpAndSettle();
      final stamp = tester.getRect(find.byKey(_stamp));
      final pill = tester.getRect(find.byKey(_pill));
      expect(stamp.left, greaterThanOrEqualTo(16));
      expect(pill.right, lessThanOrEqualTo(320 - 16));
      expect(pill.height, greaterThan(34), reason: 'the pill follows the text');
      expect(
          find.descendant(of: find.byKey(_badge), matching: find.text('99+')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
          AppCartButton.clearanceFor(
              tester.element(find.byType(AppCartButton))),
          greaterThanOrEqualTo(
              tester.getRect(find.byType(AppCartButton)).height));
    }
  });
}
