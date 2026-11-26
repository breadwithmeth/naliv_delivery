import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/widgets/app_loading_screen.dart';

Future<void> _warmArtwork(WidgetTester tester) async {
  final key = GlobalKey();
  await tester.pumpWidget(MediaQuery(
    data: const MediaQueryData(),
    child: SizedBox(key: key),
  ));
  await tester.runAsync(() => Future.wait([
    for (final name in ['launch-word', 'launch-cap', '1', '2', '3', '1-echo', '2-echo', '3-echo'])
      precacheImage(AssetImage('assets/startup/$name.png'), key.currentContext!),
  ]));
}

void main() {
  testWidgets('the imprint opens once and clears before the seals cross', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.reset);
    await _warmArtwork(tester);
    final window = Completer<void>();
    final key = GlobalKey();
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(375, 812)),
      child: RepaintBoundary(
        key: key,
        child: AppLaunchIntro(
          visibleWindow: window.future,
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    ));
    await tester.pump();

    // Only the wordmark contains white ink; the flying caps are tinted.
    Future<int> inkWidth() async => (await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage();
      try {
        final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        var left = image.width;
        var right = -1;
        for (var y = 306; y < 506; y++) {
          for (var x = 0; x < image.width; x++) {
            final offset = 4 * (y * image.width + x);
            if (data.getUint8(offset + 2) < 250 || data.getUint8(offset + 1) < 250) continue;
            if (x < left) left = x;
            if (x > right) right = x;
          }
        }
        return right < left ? 0 : right - left + 1;
      } finally {
        image.dispose();
      }
    }))!;

    final initialWidth = await inkWidth();
    expect(initialWidth, inInclusiveRange(80, 92));
    // The OS owns the window longer than the entire intro. Hidden time
    // must not count towards the cap's first visible movement.
    await tester.pump(const Duration(seconds: 3));
    expect(await inkWidth(), initialWidth);
    window.complete();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(await inkWidth(), inInclusiveRange(50, 70)); // Only the landed cap.
    await tester.pump(const Duration(milliseconds: 180));
    expect(await inkWidth(), inExclusiveRange(70, 275)); // Still rolling.
    await tester.pump(const Duration(milliseconds: 420));
    expect(await inkWidth(), greaterThan(275)); // The complete lockup.
    await tester.pump(const Duration(milliseconds: 700));
    expect(await inkWidth(), 0); // No letters above the first crossing.
    await tester.pump(const Duration(milliseconds: 390));
    expect(await inkWidth(), 0); // No flash through the following seal.
  });

  testWidgets('carries seal speed through the waypoint', (tester) async {
    await _warmArtwork(tester);
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(),
        child: AppLaunchIntro(child: SizedBox.expand()),
      ),
    );
    final seal = find
        .byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == 'assets/startup/3.png',
        )
        .last;

    // The front seal crosses its 52% waypoint at 1430 ms.
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1414));
    final before = tester.getCenter(seal).dy;
    await tester.pump(const Duration(milliseconds: 16));
    final waypoint = tester.getCenter(seal).dy;
    await tester.pump(const Duration(milliseconds: 16));
    final after = tester.getCenter(seal).dy;

    expect(before - waypoint, greaterThan(10));
    expect(waypoint - after, greaterThan(10));
    expect(((before - waypoint) - (waypoint - after)).abs(), lessThan(2));
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'launch reveals the already mounted route (reduce motion: $reduced)',
      (tester) async {
        var taps = 0;
        if (!reduced) await _warmArtwork(tester);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: AppLaunchIntro(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Center(
                  child: GestureDetector(
                    onTap: () => taps++,
                    child: const Text('Войти'),
                  ),
                ),
              ),
            ),
          ),
        );
        final action = find.text('Войти', skipOffstage: false);
        expect(action, findsOneWidget);
        if (!reduced) {
          await tester.tap(action, warnIfMissed: false);
          expect(
            taps,
            0,
            reason: 'Do not activate the route through an opaque splash',
          );
          await tester.pump();
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
        }
        await tester.tap(action);
        expect(
          taps,
          1,
          reason: 'The remaining decorative motion must not block the route',
        );
        // The last faint silhouettes have cleared the interactive route.
        await tester.pump(const Duration(milliseconds: 450));
        expect(tester.hasRunningAnimations, isFalse);
        expect(find.byType(Image), findsNothing);
        await tester.tap(action);
        expect(taps, 2);
      },
    );
  }
  testWidgets('reducing motion while the OS covers the app never replays the intro', (
    tester,
  ) async {
    await _warmArtwork(tester);
    final window = Completer<void>();
    Widget app(bool reduced) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: AppLaunchIntro(
        visibleWindow: window.future,
        child: const SizedBox.expand(),
      ),
    );
    await tester.pumpWidget(app(false));
    await tester.pumpWidget(app(true));
    expect(find.byType(Image), findsNothing);
    window.complete();
    await tester.pumpWidget(app(false));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Image), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
