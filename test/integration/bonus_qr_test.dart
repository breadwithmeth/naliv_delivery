import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/bonuses/bonus_account.dart';
import 'package:naliv_delivery/features/bonuses/ui/bonus_qr_page.dart';
import 'package:naliv_delivery/features/home/home_view_data.dart';
import 'package:naliv_delivery/features/home/ui/home_page.dart';

const _code = 'a3f1c9e2-5b7d-4c21-9f0e-0123456789ab';

const _data = HomeViewData(
  storeName: 'Градусы24 — Бухар Жырау 70',
  storeAddress: 'Караганда, проспект Нуркена Абдирова, 17/2',
  banners: [],
  promoCard: null,
  categories: [
    HomeCategory(id: 1, title: 'Слабоалкогольные', fill: Color(0xFFF16800)),
  ],
  bonusBalance: 3951,
  bonusCardCode: _code,
);

Future<void> _pumpHome(
  WidgetTester tester, {
  HomeViewData data = _data,
  bool reduceMotion = false,
  Brightness brightness = Brightness.dark,
  Size size = const Size(375, 812),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(top: 48, bottom: 34),
        disableAnimations: reduceMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: HomePage(data: data),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Centres the card's QR tile in the viewport (clear of the floating header and
/// the cart dock) and taps it.
Future<void> _openFromCard(WidgetTester tester) async {
  final tile = find.byKey(const ValueKey('home-bonus-qr'));
  final scroll = tester.state<ScrollableState>(find
      .descendant(
          of: find.byType(CustomScrollView), matching: find.byType(Scrollable))
      .first);
  final viewport = tester.getSize(find.byType(CustomScrollView));
  final target =
      scroll.position.pixels + tester.getCenter(tile).dy - viewport.height / 2;
  scroll.position
      .jumpTo(target.clamp(0.0, scroll.position.maxScrollExtent).toDouble());
  await tester.pump();
  await tester.tap(tile);
}

final _page = find.byKey(const ValueKey('bonus-qr-page'));

void main() {
  group('bonus QR on the home card', () {
    testWidgets('shows a white scannable tile with an expand affordance',
        (tester) async {
      for (final brightness in Brightness.values) {
        await _pumpHome(tester, brightness: brightness);
        final tile = find.byKey(const ValueKey('home-bonus-qr'));
        expect(tile, findsOneWidget);
        // Black on white in both themes: inverted codes fail on many scanners.
        final code = tester.widget<BarcodeWidget>(find.descendant(
            of: tile, matching: find.byKey(const ValueKey('bonus-qr-code'))));
        expect(code.color, Colors.black);
        expect(code.backgroundColor, Colors.white);
        expect(
            find.descendant(
                of: tile, matching: find.byIcon(Icons.open_in_full_rounded)),
            findsOneWidget);
        expect(find.descendant(of: tile, matching: find.text(_data.qrCaption)),
            findsOneWidget);
        expect(tester.getSize(tile).width, greaterThan(200));
      }
    });

    testWidgets('announces itself as a button that opens full screen',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpHome(tester);
      final node = tester
          .getSemantics(find.bySemanticsLabel('QR бонусной карты'))
          .getSemanticsData();
      expect(node.hint, 'Открыть QR на весь экран');
      expect(node.hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('without a card code there is no QR to open', (tester) async {
      await _pumpHome(
        tester,
        data: const HomeViewData(
          storeName: 'Магазин',
          storeAddress: 'Адрес',
          banners: [],
          promoCard: null,
          categories: [],
          bonusBalance: 10,
        ),
      );
      expect(find.byKey(const ValueKey('home-bonus-qr')), findsNothing);
      expect(find.text('QR-код бонусной карты недоступен'), findsOneWidget);
    });
  });

  group('full-screen bonus QR', () {
    testWidgets('opens with a hero, the balance and the card code as text',
        (tester) async {
      await _pumpHome(tester);
      await _openFromCard(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      // Mid-flight the QR is a hero in transit, not a second copy popping in.
      expect(_page, findsOneWidget);
      expect(find.byType(Hero), findsWidgets);
      await tester.pumpAndSettle();

      expect(
          find.descendant(
              of: _page,
              matching: find.byKey(const ValueKey('bonus-qr-balance')),
              matchRoot: true),
          findsOneWidget);
      expect(
        find.text('${bonusNumberLabel(3951)} бонусов', findRichText: true),
        findsWidgets,
      );
      expect(find.descendant(of: _page, matching: find.text(_data.qrCaption)),
          findsOneWidget);
      expect(find.byKey(const ValueKey('bonus-qr-card-code')), findsOneWidget);
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('bonus-qr-card-code')))
              .data,
          _code);

      // As large as the width allows (327 px on a 375 px screen), square, on
      // pure white.
      final plate =
          find.descendant(of: _page, matching: find.byType(BonusQrPlate));
      final size = tester.getSize(plate);
      expect(size.width, size.height);
      expect(size.width, inInclusiveRange(300, 440));
      final decoration = tester
          .widget<DecoratedBox>(find
              .descendant(of: plate, matching: find.byType(DecoratedBox))
              .first)
          .decoration as BoxDecoration;
      expect(decoration.color, Colors.white);
      final qr = tester.widget<BarcodeWidget>(find.descendant(
          of: plate, matching: find.byKey(const ValueKey('bonus-qr-code'))));
      expect(String.fromCharCodes(qr.data as List<int>), _code);
      expect(qr.color, Colors.black);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the close button closes it', (tester) async {
      await _pumpHome(tester);
      await _openFromCard(tester);
      await tester.pumpAndSettle();
      expect(_page, findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bonus-qr-close')));
      await tester.pumpAndSettle();
      expect(_page, findsNothing);
      expect(find.byKey(const ValueKey('home-bonus-qr')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping outside the plate closes it', (tester) async {
      await _pumpHome(tester);
      await _openFromCard(tester);
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(8, 400));
      await tester.pumpAndSettle();
      expect(_page, findsNothing);
    });

    testWidgets('tapping the plate closes it too', (tester) async {
      await _pumpHome(tester);
      await _openFromCard(tester);
      await tester.pumpAndSettle();

      await tester
          .tap(find.descendant(of: _page, matching: find.byType(BonusQrPlate)));
      await tester.pumpAndSettle();
      expect(_page, findsNothing);
    });

    testWidgets('a long swipe down closes it, a short one springs back',
        (tester) async {
      await _pumpHome(tester);
      await _openFromCard(tester);
      await tester.pumpAndSettle();

      final plate =
          find.descendant(of: _page, matching: find.byType(BonusQrPlate));
      final rest = tester.getTopLeft(plate);
      final gesture = await tester.startGesture(tester.getCenter(plate));
      // The first move only crosses the touch slop; the drag follows after.
      await gesture.moveBy(const Offset(0, 30));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(tester.getTopLeft(plate).dy, greaterThan(rest.dy));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_page, findsOneWidget);
      expect(tester.getTopLeft(plate), rest);

      await tester.fling(plate, const Offset(0, 320), 1800);
      await tester.pumpAndSettle();
      expect(_page, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Escape closes it', (tester) async {
      await _pumpHome(tester);
      await _openFromCard(tester);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_page, findsNothing);
    });

    testWidgets('reduced motion shows and removes it without a transition',
        (tester) async {
      await _pumpHome(tester, reduceMotion: true);
      await _openFromCard(tester);
      await tester.pump();
      expect(_page, findsOneWidget);
      // Already fully revealed on the very first frame.
      final balance = tester
          .widgetList<Opacity>(
              find.descendant(of: _page, matching: find.byType(Opacity)))
          .map((o) => o.opacity);
      expect(balance, everyElement(1.0));

      await tester.tap(find.byKey(const ValueKey('bonus-qr-close')));
      await tester.pump();
      await tester.pump();
      expect(_page, findsNothing);
    });

    testWidgets('stays usable at 320 px, 2x text, in both themes',
        (tester) async {
      for (final brightness in Brightness.values) {
        await _pumpHome(
          tester,
          size: const Size(320, 568),
          textScale: 2,
          brightness: brightness,
        );
        await _openFromCard(tester);
        await tester.pumpAndSettle();
        expect(_page, findsOneWidget);
        final plate = tester.getSize(
            find.descendant(of: _page, matching: find.byType(BonusQrPlate)));
        expect(plate.width, greaterThanOrEqualTo(160));
        expect(plate.width, lessThanOrEqualTo(320 - 48));
        // The close control keeps a full touch target.
        final close =
            tester.getSize(find.byKey(const ValueKey('bonus-qr-close')));
        expect(close.shortestSide, greaterThanOrEqualTo(44));
        await tester.tap(find.byKey(const ValueKey('bonus-qr-close')));
        await tester.pumpAndSettle();
        expect(_page, findsNothing);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
