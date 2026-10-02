import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/theme_controller.dart';
import 'package:naliv_delivery/core/destinations.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/profile/profile_account.dart';
import 'package:naliv_delivery/features/profile/ui/profile_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _account = ProfileAccount(
  name: 'Айжан',
  phone: '+7 000 000 00 00',
  addressSummary: '1 адрес · Тестовая, 16',
  cardsSummary: '1 карта · 4400••••1234',
);

Widget _host(ProfilePage page, {TextScaler scaler = TextScaler.noScaling}) =>
    ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child!,
        ),
        home: page,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('guest sign-in reveals actual account instead of empty summaries',
      (tester) async {
    ProfileAccount? current;
    await tester.pumpWidget(_host(ProfilePage(
      loadAccount: () async => current,
      onSignIn: () async => current = _account,
      onLogout: () async {},
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-sign-in')), findsOneWidget);
    expect(find.text('Нет сохранённых адресов'), findsNothing);
    expect(find.byKey(const ValueKey('profile-logout')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('profile-sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('Айжан'), findsOneWidget);
    expect(find.text('+7 000 000 00 00'), findsOneWidget);
    await tester.ensureVisible(find.text('1 адрес · Тестовая, 16'));
    expect(find.text('1 адрес · Тестовая, 16'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-sign-in')), findsNothing);
  });

  testWidgets('failed account refresh is retryable and does not imply no cards',
      (tester) async {
    var fail = true;
    await tester.pumpWidget(_host(ProfilePage(
      loadAccount: () async {
        if (fail) throw StateError('offline');
        return _account;
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('Добавленных карт нет'), findsNothing);
    expect(find.text('Не удалось обновить · повторить'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Не удалось обновить · повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Айжан'), findsOneWidget);
    expect(find.text('Не удалось обновить · повторить'), findsNothing);
  });

  testWidgets('returning from addresses refreshes summary at narrow large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var current = _account;
    await tester.pumpWidget(_host(
        ProfilePage(
          account: current,
          loadAccount: () async => current,
          onNavigate: (destination) async {
            if (destination == AppDestination.addresses) {
              current = const ProfileAccount(
                  name: 'Айжан', addressSummary: '2 адреса · Новая улица, 22');
            }
          },
        ),
        scaler: const TextScaler.linear(1.6)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Адреса'), 300);
    await tester.tap(find.text('Адреса'));
    await tester.pumpAndSettle();
    expect(find.text('2 адреса · Новая улица, 22'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Тема оформления'), 300);
    await tester.tap(find.text('Тема оформления'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('logout requires confirmation and preserves cancel',
      (tester) async {
    var logouts = 0;
    await tester.pumpWidget(_host(ProfilePage(
      account: _account,
      onLogout: () async {
        logouts++;
      },
    )));
    await tester.pumpAndSettle();
    final logout = find.byKey(const ValueKey('profile-logout'));
    await tester.scrollUntilVisible(logout, 300);
    await tester.tap(logout);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Остаться'));
    await tester.pumpAndSettle();
    expect(logouts, 0);
    await tester.tap(logout);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, 'Выйти'),
    ));
    await tester.pumpAndSettle();
    expect(logouts, 1);
  });
}
