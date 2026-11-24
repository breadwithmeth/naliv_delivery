import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/widgets/app_loading_screen.dart';

void main() {
  testWidgets('carries seal speed through the waypoint', (tester) async {
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
        final action = find.text('Войти');
        expect(action, findsOneWidget);
        if (!reduced) {
          await tester.tap(action, warnIfMissed: false);
          expect(
            taps,
            0,
            reason: 'Do not activate the route through an opaque splash',
          );
          await tester.pump(const Duration(seconds: 2));
        }
        await tester.tap(action);
        expect(
          taps,
          1,
          reason: 'The remaining decorative motion must not block the route',
        );
        // Nothing should still be ticking past the last seal's 3250 ms flight.
        await tester.pump(const Duration(milliseconds: 1400));
        expect(tester.hasRunningAnimations, isFalse);
        await tester.tap(action);
        expect(taps, 2);
      },
    );
  }
}
