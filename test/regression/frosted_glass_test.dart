import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/ui/frosted_dock.dart';
import 'package:naliv_delivery/ui/frosted_surface.dart';

/// Regression guards for the liquid-glass material that replaced the app's
/// BackdropFilter frost: the package's shader must load (otherwise every
/// surface silently renders the package's near-transparent fallback tint) and
/// the design's tint must composite exactly over the blurred backdrop.
void main() {
  setUpAll(() async {
    // Inside the per-test fake async zone the shader's lazy load never lands,
    // so the program has to be compiled before the first widget mounts.
    await LightweightLiquidGlass.preWarm();
  });

  Future<Color> renderCenterPixel(
    WidgetTester tester,
    Widget child, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(300, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: Scaffold(
          backgroundColor: const Color(0xFF3366CC),
          body: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: const Color(0xFF3366CC),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    return (await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final offset =
            4 * ((image.height ~/ 2) * image.width + image.width ~/ 2);
        return Color.fromARGB(
          255,
          data!.getUint8(offset),
          data.getUint8(offset + 1),
          data.getUint8(offset + 2),
        );
      } finally {
        image.dispose();
      }
    }))!;
  }

  for (final dark in [false, true]) {
    testWidgets(
      'glass masks a saturated backdrop in ${dark ? "dark" : "light"} mode',
      (tester) async {
        final pixel = await renderCenterPixel(
          tester,
          const SizedBox(
            width: 200,
            height: 80,
            child: FrostedSurface(child: SizedBox.expand()),
          ),
          dark: dark,
        );
        // Blue should still show through the neutral material, but contribute
        // no more than 7% of the centre colour.
        final red = (pixel.toARGB32() >> 16) & 255;
        final blue = pixel.toARGB32() & 255;
        expect(
          red,
          dark ? inInclusiveRange(25, 30) : inInclusiveRange(241, 253),
        );
        expect(
          blue,
          dark ? inInclusiveRange(25, 36) : inInclusiveRange(246, 250),
        );
      },
    );
  }

  testWidgets('a custom tint composites exactly, keeping the token colour', (
    tester,
  ) async {
    final pixel = await renderCenterPixel(
      tester,
      const SizedBox(
        width: 200,
        height: 80,
        child: FrostedSurface(
          tint: Color(0xC850A0E8),
          child: SizedBox.expand(),
        ),
      ),
    );
    final expected = Color.alphaBlend(
      const Color(0xC850A0E8),
      const Color(0xFF3366CC),
    );
    // bodyMode clear composites the tint's own colour: the rendered centre
    // matches the plain alpha blend of the tint over the (flat) backdrop.
    expect((pixel.r - expected.r).abs(), lessThan(6 / 255));
    expect((pixel.g - expected.g).abs(), lessThan(6 / 255));
    expect((pixel.b - expected.b).abs(), lessThan(6 / 255));
  });

  testWidgets('high contrast keeps the opaque fill', (tester) async {
    tester.view.physicalSize = const Size(300, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          backgroundColor: Color(0xFF3366CC),
          body: MediaQuery(
            data: MediaQueryData(highContrast: true),
            child: Center(
              child: SizedBox(
                width: 200,
                height: 80,
                child: FrostedSurface(child: SizedBox.expand()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdaptiveGlass), findsNothing);
  });

  for (final dark in [false, true]) {
    final background = dark ? _nearBlack : Colors.white;
    testWidgets(
      dark
          ? 'dock rim is lighter than its interior over near-black'
          : 'dock rim is darker than its interior over white',
      (tester) async {
        _setDockViewport(tester);
        final pixels = await _renderDockPixels(
          tester,
          background: background,
          dark: dark,
        );
        expect(pixels.backdrop, background);
        expect(
          [
            for (final shift in [16, 8, 0])
              _rimContrast(pixels, shift, dark: dark),
          ],
          anyElement(greaterThanOrEqualTo(8)),
          reason: 'At least one RGB channel must show a visible rim.',
        );
      },
    );
  }

  testWidgets('high-contrast dock center ignores the page background', (
    tester,
  ) async {
    _setDockViewport(tester);
    final onWhite = await _renderDockPixels(
      tester,
      background: Colors.white,
      highContrast: true,
    );
    final onNearBlack = await _renderDockPixels(
      tester,
      background: _nearBlack,
      highContrast: true,
    );
    expect(onWhite.backdrop, Colors.white);
    expect(onNearBlack.backdrop, _nearBlack);
    expect(onNearBlack.center, onWhite.center);
  });
}

const _dockDpr = 3;
const _nearBlack = Color(0xFF101010);

typedef _DockPixels = ({
  Color backdrop,
  List<Color> edge,
  List<Color> interior,
  Color center,
});

void _setDockViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = _dockDpr.toDouble();
  tester.view.physicalSize = const Size(375, 812) * _dockDpr.toDouble();
  addTearDown(tester.view.reset);
}

Future<_DockPixels> _renderDockPixels(
  WidgetTester tester, {
  required Color background,
  bool dark = false,
  bool highContrast = false,
}) async {
  final boundaryKey = GlobalKey();
  const foregroundKey = ValueKey('empty dock foreground');
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          highContrast: highContrast,
          // Exercise the standard renderer, not native shader refraction.
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: RepaintBoundary(
        key: boundaryKey,
        child: FrostedDock(
          content: ColoredBox(color: background),
          dock: const SizedBox(key: foregroundKey, height: 64),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary =
      boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  // With no overhang, the empty foreground starts at the bar's top edge.
  final foregroundTop = tester.getTopLeft(find.byKey(foregroundKey));
  final top = (boundary.globalToLocal(foregroundTop).dy * _dockDpr).round();
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _dockDpr.toDouble());
    try {
      final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final x = image.width ~/ 2;
      Color sample(int row) {
        final offset = 4 * (row * image.width + x);
        return Color.fromARGB(
          data.getUint8(offset + 3),
          data.getUint8(offset),
          data.getUint8(offset + 1),
          data.getUint8(offset + 2),
        );
      }

      return (
        backdrop: sample(top - 4 * _dockDpr),
        edge: List.generate(3 * _dockDpr, (row) => sample(top + row)),
        interior: List.generate(
          4 * _dockDpr,
          (row) => sample(top + 8 * _dockDpr + row),
        ),
        center: sample((top + image.height) ~/ 2),
      );
    } finally {
      image.dispose();
    }
  }))!;
}

double _rimContrast(_DockPixels pixels, int shift, {required bool dark}) {
  int channel(Color color) => (color.toARGB32() >> shift) & 0xFF;

  final edge = pixels.edge.map(channel).reduce(dark ? math.max : math.min);
  final interior = pixels.interior.map(channel).toList()..sort();
  final middle = interior.length ~/ 2;
  final median = (interior[middle - 1] + interior[middle]) / 2;
  return dark ? edge - median : median - edge;
}
