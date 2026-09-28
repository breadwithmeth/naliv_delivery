import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/theme_controller.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/profile/ui/profile_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('375px profile keeps the measured row rhythm and switch size',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeController();
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: theme,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: const ProfilePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    Rect rect(String key) => tester.getRect(find.byKey(ValueKey(key)));

    expect(rect('profile-avatar'), const Rect.fromLTWH(147.5, 91, 80, 80));
    for (var index = 0; index < 8; index++) {
      final y = index == 7 ? 615.0 : 183.0 + index * 62;
      expect(
        rect('profile-row-$index'),
        Rect.fromLTWH(16, y, 343, 58),
      );
    }
    expect(
      rect('profile-telemetry-switch'),
      const Rect.fromLTWH(297, 569, 50, 30),
    );
    expect(
      rect('profile-theme-switch'),
      const Rect.fromLTWH(297, 629, 50, 30),
    );
    expect(rect('profile-logout'), const Rect.fromLTWH(140.5, 685, 94, 40));

    await tester.tap(find.byKey(const ValueKey('profile-theme-switch')));
    await tester.pumpAndSettle();
    expect(theme.mode, ThemeMode.light);
  });
}
