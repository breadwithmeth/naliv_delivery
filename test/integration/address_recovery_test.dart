import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/pages/map_address_page.dart';
import 'package:naliv_delivery/pages/profile_addresses_page.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/ui/app_states.dart';
import 'package:naliv_delivery/utils/address_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../support/fixture_map_tiles.dart';
import '../support/preferences_store.dart';

const _address = <String, dynamic>{
  'id': 501,
  'address': 'Тестовый адрес, 16',
  'lat': 49.8047,
  'lon': 73.1094,
  'entrance': '2',
  'floor': '7',
  'apartment': '45',
  'comment': 'Код домофона 128',
};

Map<String, dynamic> _feature(String street) => {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [73.1094, 49.8047],
      },
      'properties': {
        'geocoding': {
          'country': 'Казахстан',
          'city': 'Караганда',
          'street': street,
          'housenumber': '16',
        },
      },
    };

http.Response _response(Object data) => http.Response(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {'content-type': 'application/json'},
    );

Future<void> _pump(WidgetTester tester, Widget page) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: page));
  await tester.pumpAndSettle();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.binding.setSurfaceSize(null);
}

Future<void> _edit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('address_menu_501')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Изменить адрес'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        'onboarding_selected_city': 'Караганда',
      }));

  for (final scenario in ['edit', 'add', 'retry', 'discard']) {
    final editing = scenario == 'edit';
    testWidgets(
        scenario == 'retry'
            ? 'explicit retry saves the rejected draft without another picker'
            : scenario == 'discard'
                ? 'only explicit discard removes a rejected address draft'
                : 'rejected $scenario keeps the same draft for resubmission',
        (tester) async {
      final priorStore = SharedPreferencesStorePlatform.instance;
      final store = OnboardingPreferences({
        'auth_token': 'fixture-only',
        'onboarding_selected_city': 'Караганда',
        if (editing) 'selected_address': jsonEncode(_address),
      });
      store.install();
      final unexpected = <String>[];
      var reverseReads = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/auth/full-info' &&
            request.headers['authorization'] == 'Bearer fixture-only') {
          return _response({
            'addresses': editing ? [_address] : <Map<String, dynamic>>[],
          });
        }
        if (!editing &&
            request.method == 'GET' &&
            request.url.path == '/api/addresses/reverse' &&
            request.url.queryParameters['lat'] != null &&
            request.url.queryParameters['lon'] != null) {
          reverseReads++;
          return _response([_feature('Тестовый адрес')]);
        }
        unexpected.add('${request.method} ${request.url}');
        throw StateError('Unexpected address recovery request');
      });
      try {
        await http.runWithClient(() async {
          await _pump(tester,
              ProfileAddressesPage(tileProvider: FixtureTileProvider()));
          if (editing) {
            await _edit(tester);
          } else {
            await tester.tap(find.byKey(const Key('address_book_add')));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('address_map_confirm')));
            await tester.pumpAndSettle();
          }
          await tester.enterText(
              find.byKey(const Key('address_entrance')), '2А');
          await tester.enterText(find.byKey(const Key('address_floor')), '');
          await tester.enterText(
              find.byKey(const Key('address_apartment')), '46Б');
          FocusManager.instance.primaryFocus?.unfocus();
          store.rejectedKeys.add('profile_local_addresses');
          await tester.tap(find.byKey(const Key('address_details_confirm')));
          await tester.pumpAndSettle();

          expect(find.textContaining('Не удалось сохранить'), findsOneWidget);
          expect(find.text('Адрес сохранён на этом устройстве'), findsNothing);
          expect((await AddressStorageService.getBookSnapshot()).localAddresses,
              isEmpty);
          expect(await AddressStorageService.getSelectedAddress(),
              editing ? _address : isNull);

          if (scenario == 'discard') {
            await tester.tap(find.byKey(const Key('address_draft_discard')));
            await tester.pumpAndSettle();
            expect(find.textContaining('Не удалось сохранить'), findsNothing);
            expect(find.byKey(const Key('address_draft_retry')), findsNothing);
            expect(
                (await AddressStorageService.getBookSnapshot()).localAddresses,
                isEmpty);
            await tester.tap(find.byKey(const Key('address_book_add')));
            await tester.pumpAndSettle();
            expect(find.byType(MapAddressPage), findsOneWidget);
            expect(find.byType(AddressDetailsPage), findsNothing);
            expect(reverseReads, 2);
            return;
          }
          if (scenario == 'retry') {
            await tester.tap(find.byKey(const Key('address_draft_retry')));
            await tester.pumpAndSettle();
            expect(find.byType(MapAddressPage), findsNothing);
            expect(find.byType(AddressDetailsPage), findsNothing);
            expect(find.textContaining('Не удалось сохранить'), findsOneWidget);
            expect(
                (await AddressStorageService.getBookSnapshot()).localAddresses,
                isEmpty);
            store.rejectedKeys.clear();
            await tester.tap(find.byKey(const Key('address_draft_retry')));
            await tester.pumpAndSettle();
          } else {
            if (editing) {
              await _edit(tester);
            } else {
              await tester.tap(find.byKey(const Key('address_book_add')));
              await tester.pumpAndSettle();
            }
            expect(find.byType(AddressDetailsPage), findsOneWidget);
            for (final entry in {
              'entrance': '2А',
              'floor': '',
              'apartment': '46Б'
            }.entries) {
              expect(
                tester
                    .widget<TextField>(find.byKey(Key('address_${entry.key}')))
                    .controller!
                    .text,
                entry.value,
              );
            }
            store.rejectedKeys.clear();
            await tester.tap(find.byKey(const Key('address_details_confirm')));
            await tester.pumpAndSettle();
          }

          final saved = (await AddressStorageService.getBookSnapshot())
              .localAddresses
              .single;
          expect(saved['address'], 'Тестовый адрес, 16');
          expect(saved['point'], {'lat': 49.8047, 'lon': 73.1094});
          expect(saved['entrance'], '2А');
          expect(saved['floor'], '');
          expect(saved['apartment'], '46Б');
          if (editing) expect(saved['comment'], 'Код домофона 128');
          expect(reverseReads, editing ? 0 : 1);
          expect(
              find.text('Адрес сохранён на этом устройстве'), findsOneWidget);
        }, () => client);
      } finally {
        await _dispose(tester);
        SharedPreferencesStorePlatform.instance = priorStore;
        SharedPreferences.resetStatic();
        client.close();
        expect(unexpected, isEmpty);
      }
    });
  }

  testWidgets(
      'hung address search becomes retryable without automatic requests',
      (tester) async {
    final pending = Completer<http.Response>();
    final unexpected = <String>[];
    var requests = 0;
    final client = MockClient((request) {
      if (request.method != 'GET' ||
          request.url.path != '/api/addresses/search' ||
          !(request.url.queryParameters['query']?.contains('Тестовая') ??
              false)) {
        unexpected.add('${request.method} ${request.url}');
        throw StateError('Unexpected search timeout request');
      }
      requests++;
      return requests == 1
          ? pending.future
          : Future.value(_response({
              'features': [_feature('Новый адрес')],
            }));
    });
    try {
      await http.runWithClient(() async {
        await _pump(tester, const AddressSearchPage(selectedCity: 'Караганда'));
        await tester.enterText(
            find.byKey(const Key('address_search_field')), 'Тестовая');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(seconds: 11));
        await tester.pump();

        expect(requests, 1);
        expect(find.byType(AppLoading), findsNothing);
        expect(find.byType(AppErrorState), findsOneWidget);
        await tester.tap(find.descendant(
            of: find.byType(AppErrorState),
            matching: find.byType(FilledButton)));
        await tester.pump();
        await tester.pump();
        expect(requests, 2);
        expect(find.text('Новый адрес, 16'), findsOneWidget);
        pending.complete(_response({
          'features': [_feature('Устаревший адрес')],
        }));
        await tester.pump();
        expect(find.text('Новый адрес, 16'), findsOneWidget);
        expect(find.text('Устаревший адрес, 16'), findsNothing);
      }, () => client);
    } finally {
      if (!pending.isCompleted) pending.complete(_response({'features': []}));
      await _dispose(tester);
      client.close();
      expect(unexpected, isEmpty);
    }
  });

  testWidgets('hung reverse lookup becomes retryable without losing manual map',
      (tester) async {
    final pending = Completer<http.Response>();
    final unexpected = <String>[];
    var requests = 0;
    final client = MockClient((request) {
      if (request.method != 'GET' ||
          request.url.path != '/api/addresses/reverse' ||
          request.url.queryParameters['lat'] != '49.8047' ||
          request.url.queryParameters['lon'] != '73.1094') {
        unexpected.add('${request.method} ${request.url}');
        throw StateError('Unexpected reverse timeout request');
      }
      requests++;
      return requests == 1
          ? pending.future
          : Future.value(_response([_feature('Новый адрес')]));
    });
    try {
      await http.runWithClient(() async {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.dark(),
          home: MapAddressPage(
            initialLat: 49.8047,
            initialLon: 73.1094,
            tileProvider: FixtureTileProvider(),
          ),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 11));
        await tester.pump();

        final confirm = find.byKey(const Key('address_map_confirm'));
        expect(requests, 1);
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
        expect(find.text('Определяем адрес…'), findsNothing);
        expect(find.text('Повторить определение адреса'), findsOneWidget);
        expect(find.byKey(const Key('address_map_search')), findsOneWidget);
        await tester.tap(find.text('Повторить определение адреса'));
        await tester.pump();
        await tester.pump();
        expect(requests, 2);
        expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
        expect(find.text('Новый адрес, 16'), findsOneWidget);
        pending.complete(_response([_feature('Устаревший адрес')]));
        await tester.pump();
        expect(find.text('Новый адрес, 16'), findsOneWidget);
        expect(find.text('Устаревший адрес, 16'), findsNothing);
      }, () => client);
    } finally {
      if (!pending.isCompleted) pending.complete(_response([]));
      await _dispose(tester);
      client.close();
      expect(unexpected, isEmpty);
    }
  });

  testWidgets(
      'credential change clears cached server addresses even when new read fails',
      (tester) async {
    final local = {
      ..._address,
      'id': 'device_shared',
      'address': 'На устройстве, 30',
      'device_local': true,
    };
    SharedPreferences.setMockInitialValues({
      'profile_local_addresses': <String>[jsonEncode(local)],
    });
    await AuthService.saveToken('address-session-a');
    final unexpected = <String>[];
    final reads = <String>[];
    final client = MockClient((request) async {
      final authorization = request.headers['authorization'];
      if (request.method == 'GET' &&
          request.url.path == '/api/auth/full-info' &&
          (authorization == 'Bearer address-session-a' ||
              authorization == 'Bearer address-session-b')) {
        reads.add(authorization!);
        return authorization == 'Bearer address-session-a'
            ? _response({
                'addresses': [_address]
              })
            : http.Response('Fixture account B unavailable', 503);
      }
      unexpected.add('${request.method} ${request.url}');
      throw StateError('Unexpected address account transition request');
    });
    try {
      await http.runWithClient(() async {
        await _pump(
            tester, ProfileAddressesPage(tileProvider: FixtureTileProvider()));
        expect(find.text('Тестовый адрес, 16'), findsOneWidget);
        expect(find.text('На устройстве, 30'), findsOneWidget);

        await AuthService.saveToken('address-session-b');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Тестовый адрес, 16'), findsNothing);
        expect(find.text('На устройстве, 30'), findsOneWidget);
        expect(find.byType(AppErrorState), findsOneWidget);
        expect(reads, ['Bearer address-session-a', 'Bearer address-session-b']);
        expect(
            (await AddressStorageService.getBookSnapshot())
                .localAddresses
                .single['address'],
            'На устройстве, 30');
        expect(
            (await SharedPreferences.getInstance())
                .getStringList('profile_local_addresses'),
            <String>[jsonEncode(local)]);
      }, () => client);
    } finally {
      await _dispose(tester);
      client.close();
      expect(unexpected, isEmpty);
    }
  });

  testWidgets('late server addresses cannot republish after credential change',
      (tester) async {
    final local = {
      ..._address,
      'id': 'device_shared',
      'address': 'На устройстве, 30',
      'device_local': true,
    };
    final accountB = {
      ..._address,
      'id': 502,
      'address': 'Новый аккаунт, 22',
    };
    SharedPreferences.setMockInitialValues({
      'profile_local_addresses': <String>[jsonEncode(local)],
    });
    await AuthService.saveToken('address-session-a');
    final pending = Completer<http.Response>();
    final unexpected = <String>[];
    final reads = <String>[];
    final client = MockClient((request) {
      final authorization = request.headers['authorization'];
      if (request.method == 'GET' &&
          request.url.path == '/api/auth/full-info' &&
          (authorization == 'Bearer address-session-a' ||
              authorization == 'Bearer address-session-b')) {
        reads.add(authorization!);
        return authorization == 'Bearer address-session-a'
            ? pending.future
            : Future.value(_response({
                'addresses': [accountB]
              }));
      }
      unexpected.add('${request.method} ${request.url}');
      throw StateError('Unexpected delayed account address request');
    });
    try {
      await http.runWithClient(() async {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.dark(),
          home: ProfileAddressesPage(tileProvider: FixtureTileProvider()),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('На устройстве, 30'), findsOneWidget);
        expect(reads, ['Bearer address-session-a']);

        await AuthService.saveToken('address-session-b');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        pending.complete(_response({
          'addresses': [_address]
        }));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Тестовый адрес, 16'), findsNothing);
        expect(find.text('Новый аккаунт, 22'), findsOneWidget);
        expect(find.text('На устройстве, 30'), findsOneWidget);
        expect(reads, ['Bearer address-session-a', 'Bearer address-session-b']);
        expect(
            (await SharedPreferences.getInstance())
                .getStringList('profile_local_addresses'),
            <String>[jsonEncode(local)]);
      }, () => client);
    } finally {
      if (!pending.isCompleted) {
        pending.complete(_response({'addresses': <Map<String, dynamic>>[]}));
      }
      await _dispose(tester);
      client.close();
      expect(unexpected, isEmpty);
    }
  });
}
