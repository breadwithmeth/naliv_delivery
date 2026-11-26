import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:naliv_delivery/core/money.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/ui/app_cart_button.dart';
import 'package:naliv_delivery/ui/app_icon.dart';
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
  double bottomInset = 34,
  bool dark = true,
  bool visible = true,
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
        padding: EdgeInsets.only(top: 48, bottom: bottomInset),
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: child!,
    ),
    home: Scaffold(
      body: FrostedDock(
        content: const SizedBox.expand(),
        dock: AppCartButton(
          itemCount: items,
          total: total,
          onTap: onTap,
          visible: visible,
        ),
      ),
    ),
  ));
}

void _expectDockGeometry(
  WidgetTester tester, {
  required double height,
  required double bottomInset,
}) {
  final stamp = tester.getRect(find.byKey(_stamp));
  final glass = tester.getRect(find.byType(AdaptiveGlass));
  expect(glass.top - stamp.top, closeTo(27, .01));
  expect(glass.bottom, closeTo(height, .01));
  expect(
    AppCartButton.clearanceFor(tester.element(find.byType(AppCartButton))),
    closeTo(height - bottomInset - stamp.top + 12, .01),
    reason: 'scroll clearance leaves a 12 px gutter above the stamp',
  );
}

void main() {
  testWidgets('filled cart paints one opaque orange across the join',
      (tester) async {
    // SVG parsing uses an isolate; prime the asset cache outside fake async
    // so the first painted frame can contain the artwork, not placeholders.
    await tester.runAsync(() async {
      await Future.wait([
        for (final asset in [AppIcons.cartFab, AppIcons.cart])
          SvgAssetLoader(asset).loadBytes(null),
      ]);
    });

    const dpr = 3.0;
    const orange = Color(0xFFF16800);
    const boundaryKey = ValueKey('cart-pixel-boundary');
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = const Size(375, 812) * dpr;
    tester.view.padding = const FakeViewPadding(top: 144, bottom: 102);
    addTearDown(tester.view.reset);

    for (final backdrop in const {
      'light': Colors.white,
      'dark': Color(0xFF101B45),
    }.entries) {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: RepaintBoundary(
            key: boundaryKey,
            child: FrostedDock(
              content: ColoredBox(color: backdrop.value),
              dock: const AppCartButton(itemCount: 3, total: 92190),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      final stamp = tester.getRect(find.byKey(_stamp));
      final pill = tester.getRect(find.byKey(_pill));
      final points = {
        // Above the cart glyph and to the right of the count badge.
        'stamp alone': Offset(stamp.center.dx, stamp.top + 14),
        // To the right of the cart glyph, still well inside the scallops.
        'stamp over pill': Offset(stamp.right - 15, pill.center.dy),
        // Below the stamp's widest scallop and left of the amount text.
        'pill beside join': Offset(stamp.right + 1, pill.bottom - 6),
        'pill beyond amount': Offset(pill.right - 8, pill.center.dy),
      };

      final pixels = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: dpr);
        try {
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          Color sample(Offset local) {
            final x = (local.dx * dpr).floor();
            final y = (local.dy * dpr).floor();
            final index = 4 * (y * image.width + x);
            return Color.fromARGB(
              data.getUint8(index + 3),
              data.getUint8(index),
              data.getUint8(index + 1),
              data.getUint8(index + 2),
            );
          }

          return {
            'page': sample(const Offset(8, 8)),
            for (final point in points.entries)
              point.key: sample(boundary.globalToLocal(point.value)),
          };
        } finally {
          image.dispose();
        }
      });

      expect(
        pixels,
        {
          'page': backdrop.value,
          for (final point in points.keys) point: orange,
        },
        reason: '${backdrop.key} page must not change the cart fill',
      );
    }
  });

  testWidgets('cart and skirt keep their overhang just above the safe area',
      (tester) async {
    for (final bottomInset in [0.0, 34.0]) {
      await _pump(tester, items: 0, bottomInset: bottomInset);
      final stamp = tester.getRect(find.byKey(_stamp));
      expect(stamp.size, const Size.square(78));
      expect(stamp.center.dx, closeTo(187.5, .5));
      expect(
        stamp.bottom,
        closeTo(812 - bottomInset - FrostedDock.basePadding, .01),
      );
      _expectDockGeometry(tester, height: 812, bottomInset: bottomInset);
      expect(find.byKey(_pill), findsNothing);
      expect(find.byKey(_badge), findsNothing);
    }
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
    final stamp = tester.getRect(find.byKey(_stamp));
    await tester.tapAt(stamp.topCenter + const Offset(0, 8));
    expect(taps, 3, reason: 'the part above the glass is still tappable');
    await tester.tapAt(stamp.bottomCenter + const Offset(0, 3));
    expect(taps, 3, reason: 'the new bottom spacing is not a tap target');
    expect(tester.getRect(find.byKey(_stamp)).shortestSide,
        greaterThanOrEqualTo(44));

    await _pump(tester, items: 0, onTap: () => taps++);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Открыть корзину'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('hidden cart leaves no glass or tap target', (tester) async {
    var taps = 0;
    await _pump(tester, items: 0, onTap: () => taps++);
    final previousCenter = tester.getCenter(find.byKey(_stamp));
    await _pump(tester, items: 0, visible: false, onTap: () => taps++);
    expect(find.byKey(_stamp), findsNothing);
    expect(tester.getSize(find.byType(AdaptiveGlass)), Size.zero);
    await tester.tapAt(previousCenter);
    expect(taps, 0);
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
      _expectDockGeometry(tester, height: 640, bottomInset: 34);
    }
  });
}
