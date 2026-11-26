import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/notifications/notification_history.dart';
import 'package:naliv_delivery/features/notifications/ui/notification_history_page.dart';
import 'package:naliv_delivery/pages/notification_settings_page.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/ui/settings_widgets.dart';

import '../support/haptic_calls.dart';
import '../support/preferences_store.dart';

const _accountA = 'inbox-fixture-a';
const _accountB = 'inbox-fixture-b';
const _settingsLabel = 'Настройки уведомлений';
const _emptyLabel = 'Уведомлений нет';

class _HistoryPreferences extends OnboardingPreferences {
  Completer<bool>? nextRead;

  @override
  Future<Map<String, Object>> getAll() async {
    final gate = nextRead;
    nextRead = null;
    final snapshot = await super.getAll();
    if (gate != null && !await gate.future) {
      throw StateError('Notification preferences unavailable');
    }
    return snapshot;
  }
}

Future<void> _append(
  String identity,
  String title,
  DateTime receivedAt, {
  String body = 'Подробности уведомления',
}) async {
  expect(
    await NotificationHistory.instance.append(
      identity,
      HistoryNotification(
        id: title,
        title: title,
        body: body,
        receivedAt: receivedAt,
      ),
    ),
    isTrue,
  );
}

Widget _app({double textScale = 1, bool dark = false}) => MaterialApp(
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          padding: const EdgeInsets.only(top: 48, bottom: 34),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => NotificationHistoryPage(
          onSettings: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const NotificationSettingsPage()),
          ),
        ),
      ),
    );

void main() {
  late _HistoryPreferences store;

  setUp(() async {
    store = _HistoryPreferences()..install();
    await AuthService.notifySessionChanged();
    await AuthService.bindAuthenticatedIdentity(_accountA);
  });

  tearDown(() => AuthService.bindAuthenticatedIdentity(null));

  testWidgets('empty history offers settings through keyboard and semantics',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_app(textScale: 2, dark: true));
      await tester.pumpAndSettle();

      expect(find.text(_emptyLabel), findsOneWidget);
      expect(find.bySemanticsLabel('Настройки'), findsOneWidget);
      expect(
        tester.getSize(find.byType(SettingsRow)).height,
        greaterThanOrEqualTo(44),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Back.
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Settings.
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(NotificationSettingsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('storage failure is not empty and retry reads persisted history',
      (tester) async {
    final calls = recordHapticCalls(tester);
    final received = DateTime(DateTime.now().year, 6, 10, 12);
    await _append(_accountA, 'Заказ собран', received);
    final read = Completer<bool>();
    store.nextRead = read;
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(_settingsLabel), findsOneWidget);
    expect(find.text(_emptyLabel), findsNothing);
    expect(store.nextRead, isNull);

    read.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить уведомления'), findsOneWidget);
    expect(find.text(_emptyLabel), findsNothing);
    expect(find.text(_settingsLabel), findsOneWidget);
    final retry = find.widgetWithText(OutlinedButton, 'Повторить');
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(44));

    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('Заказ собран'), findsOneWidget);
    expect(find.text('10 июня'), findsOneWidget);
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('live entries sort by receipt time and long text scrolls safely',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final year = DateTime.now().year;
    final longBody = List.filled(14, 'Заказ можно забрать после подтверждения.')
        .join(' ');
    await _append(_accountA, 'Заказ собран', DateTime(year, 6, 10, 12));
    await _append(_accountA, 'Подтверждение заказа', DateTime(year, 6, 8, 12),
        body: longBody);
    await tester.pumpWidget(_app(textScale: 2));
    await tester.pumpAndSettle();

    await _append(_accountA, 'Заказ выдан', DateTime(year, 6, 10, 18));
    await tester.pumpAndSettle();
    final latest = find.text('Заказ выдан');
    final previous = find.text('Заказ собран');
    expect(latest, findsOneWidget);
    expect(latest.hitTestable(), findsOneWidget);
    await tester.scrollUntilVisible(previous, 140,
        scrollable: find.byType(Scrollable));
    expect(previous.hitTestable(), findsOneWidget);

    final lastDate = find.text('8 июня');
    await tester.dragUntilVisible(
      lastDate.hitTestable(), find.byType(Scrollable), const Offset(0, -220),
    );
    expect(find.text(longBody), findsOneWidget);
    expect(tester.getBottomLeft(lastDate).dy, lessThanOrEqualTo(650 - 34));
    expect(find.text('Настройки').hitTestable(), findsOneWidget);
    expect(find.text('Прочитать все'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account changes hide the old inbox before the next read returns',
      (tester) async {
    final received = DateTime(DateTime.now().year, 6, 10, 12);
    await _append(_accountA, 'Личное сообщение A', received);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Личное сообщение A'), findsOneWidget);

    await AuthService.bindAuthenticatedIdentity(_accountB, verified: false);
    await tester.pumpAndSettle();
    expect(find.text('Личное сообщение A'), findsNothing);
    expect(find.text(_emptyLabel), findsNothing);
    expect(find.text(_settingsLabel), findsOneWidget);

    final readB = Completer<bool>();
    store.nextRead = readB;
    await AuthService.bindAuthenticatedIdentity(_accountB);
    await tester.pump();
    expect(find.text('Личное сообщение A'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    readB.complete(true);
    await tester.pumpAndSettle();
    expect(find.text(_emptyLabel), findsOneWidget);
    await _append(_accountB, 'Личное сообщение B', received);
    await tester.pumpAndSettle();
    expect(find.text('Личное сообщение B'), findsOneWidget);

    await AuthService.bindAuthenticatedIdentity(null);
    await tester.pumpAndSettle();
    expect(find.text('Личное сообщение A'), findsNothing);
    expect(find.text('Личное сообщение B'), findsNothing);
    expect(find.text(_emptyLabel), findsNothing);
    expect(find.text(_settingsLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a late read from the previous account cannot populate the inbox',
      (tester) async {
    final received = DateTime(DateTime.now().year, 6, 10, 12);
    await _append(_accountA, 'Запись прежнего аккаунта', received);
    final readA = Completer<bool>();
    store.nextRead = readA;
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(store.nextRead, isNull);

    await AuthService.bindAuthenticatedIdentity(_accountB);
    readA.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Запись прежнего аккаунта'), findsNothing);
    expect(find.text(_emptyLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
