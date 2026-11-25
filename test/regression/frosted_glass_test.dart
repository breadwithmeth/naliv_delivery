import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:naliv_delivery/design/theme.dart';
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

  Future<Color> renderCenterPixel(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(300, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        backgroundColor: const Color(0xFF3366CC),
        body: RepaintBoundary(
          key: boundaryKey,
          child: Center(child: child),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final boundary = boundaryKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    image.dispose();
    return Color.fromARGB(255, bytes[0], bytes[1], bytes[2]);
  }

  testWidgets('the frosted surface renders the design tint over the blur',
      (tester) async {
    final pixel = await renderCenterPixel(
      tester,
      const SizedBox(
        width: 200,
        height: 80,
        child: FrostedSurface(child: SizedBox.expand()),
      ),
    );
    // Frost.tint in light mode is white at 0.78; over the solid blue page the
    // blurred backdrop is the page colour itself, so the centre must be the
    // exact alpha blend and not the package fallback (~0.15 alpha).
    expect(pixel.r, inInclusiveRange(200, 255));
    expect(pixel.g, inInclusiveRange(210, 255));
    expect(pixel.b, inInclusiveRange(230, 255));
  });

  testWidgets('a custom tint composites exactly, keeping the token colour',
      (tester) async {
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
    final expected =
        Color.alphaBlend(const Color(0xC850A0E8), const Color(0xFF3366CC));
    // bodyMode clear composites the tint's own colour: the rendered centre
    // matches the plain alpha blend of the tint over the (flat) backdrop.
    expect((pixel.r - expected.r).abs(), lessThan(6));
    expect((pixel.g - expected.g).abs(), lessThan(6));
    expect((pixel.b - expected.b).abs(), lessThan(6));
  });

  testWidgets('high contrast keeps the opaque fill', (tester) async {
    tester.view.physicalSize = const Size(300, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
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
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AdaptiveGlass), findsNothing);
  });
}
