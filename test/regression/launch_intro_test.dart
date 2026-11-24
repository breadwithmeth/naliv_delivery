import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/widgets/app_loading_screen.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'launch reveals the already mounted route (reduce motion: $reduced)',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: AppLaunchIntro(
              child: MaterialApp(
                home: Center(
                  child: TextButton(
                    onPressed: () => taps++,
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
        await tester.pumpAndSettle();
        await tester.tap(action);
        expect(taps, 2);
      },
    );
  }
}
