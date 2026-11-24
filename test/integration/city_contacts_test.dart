import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/destinations.dart';
import 'package:naliv_delivery/core/theme_controller.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/faq/data/faq_repository.dart';
import 'package:naliv_delivery/features/profile/ui/profile_page.dart';
import 'package:naliv_delivery/features/support/city_contacts.dart';
import 'package:naliv_delivery/features/support/ui/city_contacts_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cities = [
  (id: 1, name: 'Павлодар', phone: '+77719290003'),
  (id: 2, name: 'Караганда', phone: '+77719290005'),
  (id: 3, name: 'Астана', phone: '+77719291001'),
  (id: 4, name: 'Темиртау', phone: '+77719290005'),
];

const _directory = 'Все города и телефоны';
const _chat = 'Написать в чат';
const _chatDestination = 'Открыт чат поддержки';
const _whatsApp = 'WhatsApp';
const _whatsAppNumber = '+77025834895';

Future<void> _openSheet(
  WidgetTester tester, {
  int? cityId,
  bool dark = false,
  double textScale = 1,
  double keyboard = 0,
  required Future<bool> Function(Uri) launch,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(
          textScaler: TextScaler.linear(textScale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showCityContactsSheet(
              context,
              cityId: cityId,
              launch: launch,
              onChat: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text(_chatDestination)),
                  ),
                ),
              ),
            ),
            child: const Text('Связаться'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Связаться'));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'only known IDs and exact saved city names resolve a recommendation',
    () {
      for (final city in _cities) {
        final byId = cityContactById(city.id);
        final byName = cityContactByName(city.name);
        expect(byId?.name, city.name);
        expect(byId?.phone, city.phone);
        expect(byName?.id, city.id);
        expect(byName?.phone, city.phone);
      }
      expect(cityContactById(null), isNull);
      expect(cityContactById(99), isNull);
      expect(cityContactByName(null), isNull);
      expect(cityContactByName(' астана '), isNull);
      expect(cityContactByName('Караганда, проспект'), isNull);
    },
  );

  test('FAQ question 49 lists all three hotlines and the WhatsApp number', () {
    final answer = FaqRepository.sections
        .expand((section) => section.entries)
        .singleWhere((entry) => entry.number == 49)
        .answer;
    expect(answer, contains('+77719290003(для Павлодара)'));
    expect(answer, contains('+77719290005(для Караганды и Темиртау)'));
    expect(answer, contains('+77719291001(для Астаны)'));
    expect(answer, contains('WhatsApp +77025834895'));
  });

  for (final city in _cities) {
    testWidgets('${city.name} only opens its dialer on explicit tap', (
      tester,
    ) async {
      final launched = <String>[];
      await _openSheet(
        tester,
        cityId: city.id,
        launch: (uri) async {
          launched.add(uri.toString());
          return true;
        },
      );

      final dial = find.text('Позвонить · ${city.name}');
      expect(dial, findsOneWidget);
      expect(find.text(city.phone), findsOneWidget);
      expect(find.text(_whatsApp), findsNothing);
      expect(launched, isEmpty);

      await tester.tap(dial);
      await tester.pumpAndSettle();
      expect(launched, ['tel:${city.phone}']);
    });
  }

  testWidgets('the directory expands into four separate city actions', (
    tester,
  ) async {
    final launched = <String>[];
    await _openSheet(
      tester,
      cityId: 1,
      launch: (uri) async {
        launched.add(uri.toString());
        return true;
      },
    );

    expect(find.text('Темиртау'), findsNothing);
    await tester.tap(find.text(_directory));
    await tester.pumpAndSettle();
    for (final city in _cities) {
      expect(find.text(city.name), findsOneWidget);
    }
    expect(find.text('+77719290005'), findsNWidgets(2));
    expect(launched, isEmpty);

    for (final city in ['Караганда', 'Темиртау']) {
      final action = find.text(city);
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text(_whatsApp));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_whatsApp));
    await tester.pumpAndSettle();
    expect(launched, [
      'tel:+77719290005',
      'tel:+77719290005',
      'https://wa.me/77025834895',
    ]);

    await tester.ensureVisible(find.text(_directory));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_directory));
    await tester.pumpAndSettle();
    expect(find.text(_whatsApp), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets('unknown city starts expanded at 320 px/2× (dark: $dark)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final launched = <String>[];
      await _openSheet(
        tester,
        cityId: 99,
        dark: dark,
        textScale: 2,
        launch: (uri) async {
          launched.add(uri.toString());
          return true;
        },
      );

      expect(find.textContaining('Позвонить ·'), findsNothing);
      expect(find.text(_chat).hitTestable(), findsOneWidget);
      expect(launched, isEmpty);
      final whatsapp = find.text(_whatsApp);
      await tester.ensureVisible(whatsapp);
      await tester.pumpAndSettle();
      expect(whatsapp.hitTestable(), findsOneWidget);
      await tester.tap(whatsapp);
      await tester.pumpAndSettle();
      expect(launched, ['https://wa.me/77025834895']);
      expect(tester.takeException(), isNull);
    });
  }

  for (final throws in [false, true]) {
    testWidgets(
      'failed external launch (throws: $throws) offers copy and chat',
      (tester) async {
        final clipboard = <Object?>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard.add(call.arguments);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final launched = <String>[];
        await _openSheet(
          tester,
          cityId: throws ? null : 3,
          launch: (uri) async {
            launched.add(uri.toString());
            if (throws) throw PlatformException(code: 'no-handler');
            return false;
          },
        );

        final action = find.text(throws ? _whatsApp : 'Позвонить · Астана');
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(launched, [
          throws ? 'https://wa.me/77025834895' : 'tel:+77719291001',
        ]);
        final dialog = find.byType(AlertDialog);
        final number = throws ? _whatsAppNumber : '+77719291001';
        expect(dialog, findsOneWidget);
        expect(
          find.descendant(of: dialog, matching: find.text(number)),
          findsOneWidget,
        );
        expect(clipboard, isEmpty);
        await tester.tap(find.text('Скопировать'));
        await tester.pumpAndSettle();
        expect(clipboard, [
          <String, Object?>{'text': number},
        ]);
        expect(find.text('Номер скопирован'), findsOneWidget);

        await tester.tap(
          find.descendant(of: dialog, matching: find.text(_chat)),
        );
        await tester.pumpAndSettle();
        expect(find.text(_chatDestination), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Связаться'), findsOneWidget);
        expect(find.text('Контакты'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dark in [false, true]) {
    testWidgets('chat remains usable above 300px keyboard at 320px and 2x ($dark)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _openSheet(tester, cityId: 2, dark: dark, textScale: 2, keyboard: 300,
          launch: (_) async => throw StateError('No contact action expected'));
      await tester.ensureVisible(find.text(_chat));
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(find.text(_chat)).dy, lessThanOrEqualTo(512));
      await tester.tap(find.text(_chat));
      await tester.pumpAndSettle();
      expect(find.text(_chatDestination), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('guest profile opens Contacts separately from direct Support', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final destinations = <AppDestination>[];
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeController(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => ProfilePage(
              onContacts: () => showCityContactsSheet(
                context,
                cityId: 2,
                onChat: () => destinations.add(AppDestination.support),
                launch: (_) async => throw StateError('unexpected launch'),
              ),
              onNavigate: (destination) => destinations.add(destination),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Контакты'));
    await tester.pumpAndSettle();
    expect(find.text('Позвонить · Караганда'), findsOneWidget);
    expect(destinations, isEmpty);
    await tester.tap(find.text(_chat));
    await tester.pumpAndSettle();
    expect(find.text('Позвонить · Караганда'), findsNothing);
    expect(destinations, [AppDestination.support]);

    await tester.tap(find.text('Поддержка'));
    await tester.pumpAndSettle();
    expect(find.text(_directory), findsNothing);
    expect(destinations, [AppDestination.support, AppDestination.support]);
    expect(tester.takeException(), isNull);
  });
}
