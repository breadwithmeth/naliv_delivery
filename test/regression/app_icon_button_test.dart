import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/design/tokens.dart';
import 'package:naliv_delivery/ui/app_icon.dart';
import 'package:naliv_delivery/ui/app_icon_button.dart';
import 'package:naliv_delivery/ui/frosted_surface.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget button, {
  bool dark = true,
  Color page = Colors.white,
}) async {
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    home: Scaffold(
      backgroundColor: page,
      body: Center(child: button),
    ),
  ));
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final dark in [true, false]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('$theme disc is the cart material: frosted, no hairline',
        (tester) async {
      await _pump(
        tester,
        const AppIconButton(asset: AppIcons.back, tooltip: 'Назад'),
        dark: dark,
      );
      final surface = tester.widget<FrostedSurface>(find.descendant(
          of: find.byType(AppIconButton),
          matching: find.byType(FrostedSurface)));
      expect(surface.edge, isFalse);
      expect(surface.shadow, isTrue);
      expect(
        find.descendant(
          of: find.byType(AppIconButton),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
    });

    testWidgets('$theme liked disc is red frosted glass', (tester) async {
      final palette = dark ? AppPalette.dark : AppPalette.light;
      await _pump(
        tester,
        AppIconButton(
          asset: AppIcons.heartFilled,
          fill: AppIconButton.likedFill(palette),
          color: Colors.white,
        ),
        dark: dark,
      );
      final surface =
          tester.widget<FrostedSurface>(find.byType(FrostedSurface));
      expect(surface.tint, AppIconButton.likedFill(palette));
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  }

  testWidgets('inside an already frosted region the disc does not blur again',
      (tester) async {
    await _pump(
      tester,
      const FrostedScope(child: AppIconButton(asset: AppIcons.back)),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('opaque fill stays a flat cheap disc', (tester) async {
    final fill = AppPalette.dark.surfaceMuted;
    await _pump(tester, AppIconButton(asset: AppIcons.heart, fill: fill));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppIconButton),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == fill,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('liked red keeps a white glyph at 4.5:1 over a white photo card',
      (tester) async {
    for (final palette in [AppPalette.dark, AppPalette.light]) {
      final tint = AppIconButton.likedFill(palette);
      expect(tint.r, greaterThan(tint.g));
      expect(tint.r, greaterThan(tint.b));
      final overWhite = Color.alphaBlend(tint, Colors.white);
      expect(_contrast(Colors.white, overWhite), greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('40 px disc keeps a 44 px target, taps and tooltip',
      (tester) async {
    var taps = 0;
    await _pump(
      tester,
      AppIconButton(
        asset: AppIcons.back,
        tooltip: 'Назад',
        onTap: () => taps++,
      ),
    );
    final target = tester.getSize(find.byType(AppIconButton));
    expect(target.width, greaterThanOrEqualTo(AppSpacing.touchTarget));
    expect(target.height, greaterThanOrEqualTo(AppSpacing.touchTarget));
    expect(find.byTooltip('Назад'), findsOneWidget);
    // A tap on the 2 px margin outside the 40 px disc still lands.
    final rect = tester.getRect(find.byType(AppIconButton));
    await tester.tapAt(rect.topLeft + const Offset(1, 22));
    expect(taps, 1);
  });

  testWidgets('a button without onTap does not react', (tester) async {
    await _pump(
      tester,
      const AppIconButton(asset: AppIcons.back, tooltip: 'Назад'),
    );
    final ink = tester.widget<InkWell>(find.byType(InkWell));
    expect(ink.onTap, isNull);
  });
}
