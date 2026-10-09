import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naliv_delivery/ui/app_cart_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/design_surfaces.dart';

void main() {
  testWidgets(
      'home keeps its floating control and category grid inside the gutters',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(surfaceFixturePreferences);
    SurfaceFixtureClient.resetUnexpectedRequests();
    await http.runWithClient(() async {
      await tester.pumpWidget(const DesignSurfaceApp(
        surface: 'active_route',
        brightness: Brightness.light,
      ));
      await tester.pumpAndSettle();

      // Frames draw three 98 px category columns across the 343 px content width.
      final grid = find.byKey(const ValueKey('home-category-grid'));
      final tiles = find
          .descendant(of: grid, matching: find.byType(InkWell))
          .evaluate()
          .map((element) => tester.getRect(find.byWidget(element.widget)))
          .toList();
      expect(tiles.length, 6);
      expect(tiles[2].top, tiles[0].top);
      expect(tiles[3].top, greaterThan(tiles[0].top));
      expect(grid, findsOneWidget);
      for (final tile in tiles) {
        expect(tile.left, greaterThanOrEqualTo(16));
        expect(tile.right, lessThanOrEqualTo(375 - 16));
      }

      final control = tester.getRect(find.byType(AppCartButton));
      expect(control.width, lessThanOrEqualTo(375 - 32));
      expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
    }, () => SurfaceFixtureClient());
  });
  testWidgets('narrow large-text campaign keeps its action inside the card',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(surfaceFixturePreferences);
    SurfaceFixtureClient.resetUnexpectedRequests();
    await http.runWithClient(() async {
      await tester.pumpWidget(const DesignSurfaceApp(
        surface: 'home',
        size: Size(320, 812),
        brightness: Brightness.light,
        textScaler: TextScaler.linear(2),
      ));
      await tester.pumpAndSettle();
      final banner = find.byKey(const ValueKey('home-banner-0'));
      final action = find.descendant(
        of: banner,
        matching: find.text('Смотреть товары →'),
      );
      await Scrollable.ensureVisible(tester.element(action), alignment: .3);
      await tester.pumpAndSettle();
      final card = tester.getRect(banner);
      final label = tester.getRect(action);
      expect(label.top, greaterThanOrEqualTo(card.top));
      expect(label.bottom, lessThanOrEqualTo(card.bottom));
      expect(label.bottom, lessThanOrEqualTo(
          tester.getRect(find.byType(AppCartButton)).top));
      expect(tester.takeException(), isNull);
      expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => SurfaceFixtureClient());
  });
}
