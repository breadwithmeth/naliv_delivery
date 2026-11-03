import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/motion.dart';
import 'package:naliv_delivery/ui/motion_widgets.dart';

Widget _app({
  required bool disableAnimations,
  required Widget Function(BuildContext context) builder,
}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: builder),
      ),
    );

void main() {
  testWidgets('disabled animations make every motion instant', (tester) async {
    Duration? bump;
    Widget count(bool disabled, String text, num value) => _app(
          disableAnimations: disabled,
          builder: (context) {
            bump = AppMotion.of(context, AppMotion.bump);
            return AnimatedCount(text: text, value: value);
          },
        );

    await tester.pumpWidget(count(true, '1', 1));
    expect(bump, Duration.zero);
    await tester.pumpWidget(count(true, '2', 2));
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsOneWidget);

    await tester.pumpWidget(count(false, '1', 1));
    expect(bump, AppMotion.bump);
    await tester.pumpWidget(count(false, '2', 2));
    await tester.pump();
    expect(find.text('1'), findsOneWidget, reason: 'the old number is leaving');
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsOneWidget);

    Widget press(bool disabled) => _app(
          disableAnimations: disabled,
          builder: (context) => const PressScale(
            child: SizedBox.square(dimension: 100),
          ),
        );
    for (final disabled in [true, false]) {
      await tester.pumpWidget(press(disabled));
      final gesture = await tester.startGesture(const Offset(50, 50));
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        disabled ? 1 : lessThan(1),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    }
  });
}
