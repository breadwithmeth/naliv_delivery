import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/pages/map_address_page.dart';
import 'package:naliv_delivery/pages/profile_addresses_page.dart';
import 'package:naliv_delivery/ui/app_states.dart';
import 'package:naliv_delivery/utils/address_storage_service.dart';
import 'package:naliv_delivery/widgets/address_selection_modal_material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _feature(String street, {String city = 'Караганда'}) => {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [73.1094, 49.8047]
      },
      'properties': {
        'geocoding': {
          'country': 'Казахстан',
          'city': city,
          'street': street,
          'housenumber': '16',
        }
      },
    };

http.Response _searchResponse(List<Map<String, dynamic>> features) =>
    http.Response(
        jsonEncode({
          'success': true,
          'data': {'features': features}
        }),
        200,
        headers: {'content-type': 'application/json'});

class _RasterTiles extends TileProvider {
  final MemoryImage _image = MemoryImage(TileProvider.transparentImage);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _image;
}

Future<void> _pumpSearch(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: const AddressSearchPage(selectedCity: 'Караганда')));
  await tester.pump();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.binding.setSurfaceSize(null);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        'onboarding_selected_city': 'Караганда',
      }));

  testWidgets('shortening query invalidates an in-flight search response',
      (tester) async {
    final pending = Completer<http.Response>();
    final client = MockClient((request) {
      if (request.url.path != '/api/addresses/search') {
        throw StateError('Unexpected request: ${request.url}');
      }
      return pending.future;
    });
    await http.runWithClient(() async {
      await _pumpSearch(tester);
      final input = find.byKey(const Key('address_search_field'));
      await tester.enterText(input, 'Тестовая');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.enterText(input, 'Т');
      pending.complete(_searchResponse([_feature('Тестовая')]));
      await tester.pump();
      await tester.pump();

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('Тестовая, 16'), findsNothing);
      expect(find.byType(AppLoading), findsNothing);
      await _dispose(tester);
    }, () => client);
  });

  testWidgets('late failed request cannot replace a newer successful search',
      (tester) async {
    final pending = Completer<http.Response>();
    var requests = 0;
    final client = MockClient((request) {
      if (request.url.path != '/api/addresses/search') {
        throw StateError('Unexpected request: ${request.url}');
      }
      if (++requests == 1) return pending.future;
      return Future.value(_searchResponse([_feature('Новая улица')]));
    });
    await http.runWithClient(() async {
      await _pumpSearch(tester);
      final input = find.byKey(const Key('address_search_field'));
      await tester.enterText(input, 'Старая');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.enterText(input, 'Новая');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      pending.complete(http.Response('{}', 500));
      await tester.pump();
      await tester.pump();

      expect(find.text('Новая улица, 16'), findsOneWidget);
      expect(find.byType(AppErrorState), findsNothing);
      await _dispose(tester);
    }, () => client);
  });

  testWidgets(
      'search failure is retryable and distinct from a successful empty result',
      (tester) async {
    var fail = true;
    final client = MockClient((request) async {
      if (request.url.path != '/api/addresses/search') {
        throw StateError('Unexpected request: ${request.url}');
      }
      return fail ? http.Response('{}', 503) : _searchResponse([]);
    });
    await http.runWithClient(() async {
      await _pumpSearch(tester);
      await tester.enterText(
          find.byKey(const Key('address_search_field')), 'Тестовая');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.byType(AppErrorState), findsOneWidget);
      fail = false;
      await tester.tap(find.descendant(
          of: find.byType(AppErrorState), matching: find.byType(FilledButton)));
      await tester.pump();
      await tester.pump();
      expect(find.byType(AppErrorState), findsNothing);
      expect(find.byType(AppEmptyState), findsOneWidget);
      await _dispose(tester);
    }, () => client);
  });

  testWidgets(
      'coordinates without a resolved address cannot advance to details',
      (tester) async {
    var resolved = false;
    final client = MockClient((request) async {
      if (request.url.path != '/api/addresses/reverse') {
        throw StateError('Unexpected request: ${request.url}');
      }
      return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              resolved
                  ? _feature('Тестовый адрес')
                  : {
                      'country': 'Казахстан',
                      'city': 'Караганда',
                      'point': {'lat': 49.8047, 'lon': 73.1094},
                    },
            ]
          }),
          200,
          headers: {'content-type': 'application/json'});
    });
    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          home: MapAddressPage(
            initialLat: 49.8047,
            initialLon: 73.1094,
            tileProvider: _RasterTiles(),
          )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final confirm = find.byKey(const Key('address_map_confirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(find.byType(AddressDetailsPage), findsNothing);

      resolved = true;
      await tester.tap(find.text('Повторить определение адреса'));
      await tester.pump();
      await tester.pump();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      await tester.tap(confirm);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AddressDetailsPage), findsOneWidget);
      await _dispose(tester);
    }, () => client);
  });

  testWidgets(
      'changing map point retains typed optional delivery fields until confirmation',
      (tester) async {
    Map<String, dynamic>? result;
    await tester.binding.setSurfaceSize(const Size(375, 812));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () async {
                      result = await Navigator.of(context)
                          .push<Map<String, dynamic>>(
                        MaterialPageRoute(
                            builder: (_) => AddressDetailsPage(
                                  address: 'Первый адрес, 16',
                                  initialEntrance: '2',
                                  initialFloor: '7',
                                  initialApartment: '45',
                                  onChangeAddress: (_) async => {
                                    'address': 'Новый адрес, 22',
                                    'lat': 49.81,
                                    'lon': 73.12,
                                    'entrance': '2',
                                    'floor': '7',
                                    'apartment': '45',
                                  },
                                )),
                      );
                    },
                    child: const Text('Открыть детали'),
                  ))),
    ));
    await tester.tap(find.text('Открыть детали'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('address_entrance')), '2А');
    await tester.enterText(find.byKey(const Key('address_floor')), '');
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    expect(find.byType(AddressDetailsPage), findsOneWidget);
    expect(find.text('Новый адрес, 22'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('address_entrance')))
            .controller!
            .text,
        '2А');
    await tester.tap(find.byKey(const Key('address_details_confirm')));
    await tester.pumpAndSettle();

    final selected = result!['_selectedAddress'] as Map;
    expect(selected['address'], 'Новый адрес, 22');
    expect(selected['point'], {'lat': 49.81, 'lon': 73.12});
    expect(selected['entrance'], '2А');
    expect(selected['floor'], '');
    expect(selected['apartment'], '45');
    await _dispose(tester);
  });
  testWidgets(
      'accessible address selection preserves delivery coordinates and details',
      (tester) async {
    SharedPreferences.setMockInitialValues({'auth_token': 'fixture-only'});
    const address = {
      'id': 501,
      'address': 'Тестовый адрес, 16',
      'lat': 49.8047,
      'lon': 73.1094,
      'entrance': '2А',
      'apartment': '45',
    };
    final client = MockClient((request) async {
      if (request.method != 'GET' ||
          request.url.path != '/api/auth/full-info') {
        throw StateError(
            'Unexpected request: ${request.method} ${request.url}');
      }
      return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'addresses': [address]
            },
          }),
          200,
          headers: {'content-type': 'application/json'});
    });
    final semantics = tester.ensureSemantics();
    try {
      await http.runWithClient(() async {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.dark(),
          home: ProfileAddressesPage(tileProvider: _RasterTiles()),
        ));
        await tester.pumpAndSettle();
        final node =
            tester.getSemantics(find.byKey(const Key('address_select_501')));
        expect(node.flagsCollection.isButton, isTrue);
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pumpAndSettle();
        final selected = await AddressStorageService.getSelectedAddress();
        expect(selected?['point'], {'lat': 49.8047, 'lon': 73.1094});
        expect(selected?['entrance'], '2А');
        expect(selected?['apartment'], '45');
      }, () => client);
    } finally {
      semantics.dispose();
      client.close();
      await _dispose(tester);
    }
  });

  group('city scoped to the selected store', () {
    const temirtau = (lat: 50.0549, lon: 72.9590);

    Future<void> pumpHelperEntry(
      WidgetTester tester,
      Future<void> Function(BuildContext) open,
    ) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
                onPressed: () => open(context), child: const Text('Открыть')),
          ),
        ),
      ));
      await tester.tap(find.text('Открыть'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    MockClient strictAddressApi(
      List<Uri> seen,
      http.Response Function(Uri uri) answer,
    ) =>
        MockClient((request) async {
          if (request.method != 'GET' ||
              (request.url.path != '/api/addresses/reverse' &&
                  request.url.path != '/api/addresses/search')) {
            throw StateError(
                'Unexpected request: ${request.method} ${request.url}');
          }
          seen.add(request.url);
          return answer(request.url);
        });

    http.Response reverseOf(List<Map<String, dynamic>> features) =>
        http.Response(jsonEncode({'success': true, 'data': features}), 200,
            headers: {'content-type': 'application/json'});

    testWidgets('text search uses the given city, not the onboarding city',
        (tester) async {
      final seen = <Uri>[];
      final client = strictAddressApi(
          seen,
          (uri) => uri.path == '/api/addresses/search'
              ? _searchResponse([_feature('Тестовая', city: 'Темиртау')])
              : throw StateError('Unexpected reverse lookup'));
      await http.runWithClient(() async {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.dark(),
            home: const AddressSearchPage(selectedCity: 'Темиртау')));
        await tester.pump();
        expect(find.text('Ищем адреса в г. Темиртау'), findsOneWidget);
        await tester.enterText(
            find.byKey(const Key('address_search_field')), 'Тестовая');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
        expect(seen, hasLength(1));
        final query = seen.single.queryParameters['query']!;
        expect(query, contains('Темиртау'));
        expect(query, isNot(contains('Караганда')));
        expect(find.text('Тестовая, 16'), findsOneWidget);
        expect(find.text('г. Темиртау'), findsOneWidget);
        await _dispose(tester);
      }, () => client);
    });

    testWidgets(
        'map reverse lookup resolves inside the given city and passes it to search',
        (tester) async {
      final seen = <Uri>[];
      final client = strictAddressApi(
          seen,
          (uri) => uri.path == '/api/addresses/reverse'
              ? reverseOf([
                  _feature('Чужая улица'),
                  _feature('Местная улица', city: 'Темиртау'),
                ])
              : throw StateError('Unexpected search'));
      await http.runWithClient(() async {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.light(),
            home: MapAddressPage(
              initialLat: temirtau.lat,
              initialLon: temirtau.lon,
              city: 'Темиртау',
              tileProvider: _RasterTiles(),
            )));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Местная улица, 16'), findsOneWidget);
        expect(find.text('Чужая улица, 16'), findsNothing);
        expect(find.text('Адрес в г. Темиртау'), findsOneWidget);
        expect(find.text('г. Темиртау'), findsOneWidget);
        expect(
            tester
                .widget<FilledButton>(
                    find.byKey(const Key('address_map_confirm')))
                .onPressed,
            isNotNull);

        await tester.tap(find.byKey(const Key('address_map_search')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
            tester
                .widget<AddressSearchPage>(find.byType(AddressSearchPage))
                .selectedCity,
            'Темиртау');
        await _dispose(tester);
      }, () => client);
    });

    testWidgets(
        'device location outside the given city explains it and keeps manual selection usable',
        (tester) async {
      final seen = <Uri>[];
      final client = strictAddressApi(seen, (uri) {
        if (uri.path != '/api/addresses/reverse') {
          throw StateError('Unexpected search');
        }
        final lat = double.parse(uri.queryParameters['lat']!);
        return reverseOf([
          lat > 50
              ? _feature('Местная улица', city: 'Темиртау')
              : _feature('Чужая улица'),
        ]);
      });
      await http.runWithClient(() async {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.dark(),
            home: MapAddressPage(
              initialLat: temirtau.lat,
              initialLon: temirtau.lon,
              city: 'Темиртау',
              tileProvider: _RasterTiles(),
              locate: () async =>
                  const AddressLocateResult.found(LatLng(49.8047, 73.1094)),
            )));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Местная улица, 16'), findsOneWidget);
        expect(seen, hasLength(1));

        await tester.tap(find.byKey(const Key('address_locate')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(
            find.text(
                'Вы сейчас не в г. Темиртау. Магазин доставляет только по г. Темиртау — найдите адрес поиском или передвиньте карту.'),
            findsOneWidget);
        expect(find.text('Чужая улица, 16'), findsNothing);
        expect(
            tester
                .widget<FilledButton>(
                    find.byKey(const Key('address_map_confirm')))
                .onPressed,
            isNull);
        expect(find.byKey(const Key('address_map_search')), findsOneWidget);
        expect(
            tester
                .widget<IconButton>(find.byKey(const Key('address_locate')))
                .onPressed,
            isNotNull);
        await _dispose(tester);
      }, () => client);
    });

    testWidgets(
        'map opens on the fallback centre when the saved address is in another city',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_selected_city': 'Караганда',
        'selected_address': jsonEncode({
          'address': 'Старый адрес, 1',
          'city': 'Караганда',
          'lat': 49.8047,
          'lon': 73.1094,
        }),
      });
      final client = strictAddressApi(
          <Uri>[],
          (uri) => uri.path == '/api/addresses/reverse'
              ? reverseOf([_feature('Местная улица', city: 'Темиртау')])
              : throw StateError('Unexpected search'));
      await http.runWithClient(() async {
        await pumpHelperEntry(
            tester,
            (context) => AddressSelectionModalHelper.show(context,
                city: ' Темиртау ',
                fallbackCenter: temirtau,
                tileProvider: _RasterTiles()));
        final page = tester.widget<MapAddressPage>(find.byType(MapAddressPage));
        expect(page.initialLat, temirtau.lat);
        expect(page.initialLon, temirtau.lon);
        expect(page.city, 'Темиртау');
        expect(page.initialAddress, isNull);
        await _dispose(tester);
      }, () => client);
    });

    testWidgets('a saved address in the given city still centres the map',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_selected_city': 'Караганда',
        'selected_address': jsonEncode({
          'address': 'Местный адрес, 1',
          'city': 'Темиртау',
          'lat': 50.06,
          'lon': 72.97,
        }),
      });
      final client = strictAddressApi(
          <Uri>[],
          (uri) => uri.path == '/api/addresses/reverse'
              ? reverseOf([_feature('Местная улица', city: 'Темиртау')])
              : throw StateError('Unexpected search'));
      await http.runWithClient(() async {
        await pumpHelperEntry(
            tester,
            (context) => AddressSelectionModalHelper.show(context,
                city: 'Темиртау',
                fallbackCenter: temirtau,
                tileProvider: _RasterTiles()));
        final page = tester.widget<MapAddressPage>(find.byType(MapAddressPage));
        expect(page.initialLat, 50.06);
        expect(page.initialLon, 72.97);
        await _dispose(tester);
      }, () => client);
    });

    testWidgets(
        'without a city the onboarding flow keeps the saved address centre',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_selected_city': 'Темиртау',
        'selected_address': jsonEncode({
          'address': 'Старый адрес, 1',
          'city': 'Караганда',
          'lat': 49.8047,
          'lon': 73.1094,
        }),
      });
      final client = strictAddressApi(
          <Uri>[],
          (uri) => uri.path == '/api/addresses/reverse'
              ? reverseOf([_feature('Тестовый адрес', city: 'Темиртау')])
              : throw StateError('Unexpected search'));
      await http.runWithClient(() async {
        await pumpHelperEntry(
            tester,
            (context) => AddressSelectionModalHelper.show(context,
                fallbackCenter: temirtau, tileProvider: _RasterTiles()));
        final page = tester.widget<MapAddressPage>(find.byType(MapAddressPage));
        expect(page.initialLat, 49.8047);
        expect(page.initialLon, 73.1094);
        expect(page.city, isNull);
        await _dispose(tester);
      }, () => client);
    });

    testWidgets('without any address the given city centres the map',
        (tester) async {
      final client = strictAddressApi(
          <Uri>[],
          (uri) => uri.path == '/api/addresses/reverse'
              ? reverseOf([_feature('Местная улица', city: 'Темиртау')])
              : throw StateError('Unexpected search'));
      await http.runWithClient(() async {
        await pumpHelperEntry(
            tester,
            (context) => AddressSelectionModalHelper.show(context,
                city: 'Темиртау', tileProvider: _RasterTiles()));
        final page = tester.widget<MapAddressPage>(find.byType(MapAddressPage));
        expect(page.initialLat, 50.0549);
        expect(page.initialLon, 72.9590);
        await _dispose(tester);
      }, () => client);
    });
  });
}
