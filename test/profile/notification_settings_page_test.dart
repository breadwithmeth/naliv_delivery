import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/pages/notification_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('unsupported desktop keeps saved topic choices read-only',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'notification_topic_orders': true,
      'notification_topic_promotions': false,
    });
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget page(ThemeData theme) => MaterialApp(
          theme: theme,
          home: const NotificationSettingsPage(),
        );

    await tester.pumpWidget(page(AppTheme.dark()));
    await tester.pumpAndSettle();

    Finder toggle(String title) => find.ancestor(
          of: find.text(title),
          matching: find.byType(SwitchListTile),
        );

    final orders = tester.widget<SwitchListTile>(toggle('Заказы'));
    final promotions =
        tester.widget<SwitchListTile>(toggle('Акции и предложения'));
    expect(orders.value, isTrue);
    expect(promotions.value, isFalse);
    expect(orders.onChanged, isNull);
    expect(promotions.onChanged, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(page(AppTheme.light()));
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(toggle('Заказы')).value, isTrue);
    expect(tester.widget<SwitchListTile>(toggle('Акции и предложения')).value,
        isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('notification_topic_orders'), isTrue);
    expect(preferences.getBool('notification_topic_promotions'), isFalse);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
