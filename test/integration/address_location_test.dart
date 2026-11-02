import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/pages/map_address_page.dart';
import 'package:naliv_delivery/pages/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fixture_map_tiles.dart';

Map<String, dynamic> _feature(String street, double lat, double lon) => {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [lon, lat],
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

class _AddressReads {
  final unexpected = <String>[];
  final reversePoints = <LatLng>[];
  late final client = MockClient((request) async {
    if (request.method == 'GET' &&
        request.url.path == '/api/addresses/reverse' &&
        request.url.queryParameters.keys.toSet().containsAll({'lat', 'lon'})) {
      final point = LatLng(
        double.parse(request.url.queryParameters['lat']!),
        double.parse(request.url.queryParameters['lon']!),
      );
      reversePoints.add(point);
      return _response([
        _feature(
          reversePoints.length == 1 ? 'Начальный адрес' : 'Выбранный адрес',
          point.latitude,
          point.longitude,
        ),
      ]);
    }
    if (request.method == 'GET' &&
        request.url.path == '/api/addresses/search' &&
        (request.url.queryParameters['query']?.contains('Выбранный') ??
            false)) {
      return _response({
        'features': [_feature('Выбранный адрес', 49.82, 73.13)],
      });
    }
    unexpected.add('${request.method} ${request.url}');
    throw StateError('Unexpected address fixture request');
  });
}

class _LocationPlatform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  bool failPosition = false;
  int enabledReads = 0;
  int permissionReads = 0;
  int permissionRequests = 0;
  int positionReads = 0;

  @override
  Future<bool> isLocationServiceEnabled() async {
    enabledReads++;
    return enabled;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    permissionReads++;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    positionReads++;
    if (failPosition) throw StateError('Fixture position unavailable');
    return Position(
      latitude: 49.83,
      longitude: 73.14,
      timestamp: DateTime.utc(2026, 1, 1),
      accuracy: 20,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

Future<void> _pumpMap(
  WidgetTester tester, {
  Future<AddressLocateResult> Function()? locate,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark(),
    home: MapAddressPage(
      initialLat: 49.8047,
      initialLon: 73.1094,
      tileProvider: FixtureTileProvider(),
      locate: locate,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
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

  for (final intent in ['map', 'search']) {
    for (final outcome in ['success', 'unavailable', 'error']) {
      testWidgets('late location $outcome cannot replace newer $intent intent',
          (tester) async {
        final pending = Completer<AddressLocateResult>();
        final reads = _AddressReads();
        try {
          await http.runWithClient(() async {
            await _pumpMap(tester, locate: () => pending.future);
            expect(find.text('Начальный адрес, 16'), findsOneWidget);
            await tester.tap(find.byKey(const Key('address_locate')));
            await tester.pump();
            if (intent == 'map') {
              final mapBounds = tester.getRect(find.byType(FlutterMap));
              await tester.tapAt(Offset(
                  mapBounds.left + 8, mapBounds.top + mapBounds.height / 2));
              await tester.pump(kDoubleTapTimeout);
              await tester.pump(const Duration(milliseconds: 350));
              await tester.pump();
              expect(reads.reversePoints, hasLength(2));
            } else {
              await tester.tap(find.byKey(const Key('address_map_search')));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));
              await tester.enterText(
                  find.byKey(const Key('address_search_field')), 'Выбранный');
              await tester.pump(const Duration(milliseconds: 350));
              await tester.pump();
              final result = find.descendant(
                of: find.descendant(
                    of: find.byType(AddressSearchPage),
                    matching: find.byType(ListView)),
                matching: find.text('Выбранный адрес, 16'),
              );
              expect(result, findsOneWidget);
              await tester.tap(result);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));
              await tester.pump();
            }
            final chosenLabel = find.descendant(
                of: find.byType(MapAddressPage),
                matching: find.text('Выбранный адрес, 16'));
            expect(chosenLabel, findsOneWidget);
            final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
            final chosenPoint = map.mapController!.camera.center;
            final reverseCount = reads.reversePoints.length;

            switch (outcome) {
              case 'success':
                pending.complete(
                    const AddressLocateResult.found(LatLng(49.83, 73.14)));
              case 'unavailable':
                pending.complete(const AddressLocateResult.unavailable(
                    message: 'Устаревший отказ разрешения'));
              case 'error':
                pending.completeError(StateError('Old location failure'));
            }
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));

            expect(map.mapController!.camera.center, chosenPoint);
            expect(reads.reversePoints, hasLength(reverseCount));
            expect(chosenLabel, findsOneWidget);
            expect(find.byType(AlertDialog), findsNothing);
            expect(find.byType(SnackBar), findsNothing);
            expect(
              tester
                  .widget<IconButton>(find.byKey(const Key('address_locate')))
                  .onPressed,
              isNotNull,
            );
          }, () => reads.client);
        } finally {
          if (!pending.isCompleted) {
            pending.complete(const AddressLocateResult.unavailable(
                message: 'Fixture cleanup'));
            await tester.pump();
          }
          await _dispose(tester);
          reads.client.close();
          expect(reads.unexpected, isEmpty);
        }
      });
    }
  }

  testWidgets(
      'map location performs one provider and permission read per intent',
      (tester) async {
    final priorPlatform = GeolocatorPlatform.instance;
    final platform = _LocationPlatform();
    final reads = _AddressReads();
    GeolocatorPlatform.instance = platform;
    try {
      await http.runWithClient(() async {
        await _pumpMap(tester);
        await tester.tap(find.byKey(const Key('address_locate')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(platform.positionReads, 1);
        expect(reads.reversePoints.last, const LatLng(49.83, 73.14));
        expect(platform.enabledReads, 1);
        expect(platform.permissionReads, 1);
        expect(platform.permissionRequests, 0);
      }, () => reads.client);
    } finally {
      await _dispose(tester);
      GeolocatorPlatform.instance = priorPlatform;
      reads.client.close();
      expect(reads.unexpected, isEmpty);
    }
  });

  testWidgets(
      'onboarding reuses permission result for the same location intent',
      (tester) async {
    final priorPlatform = GeolocatorPlatform.instance;
    final platform = _LocationPlatform();
    final unexpected = <String>[];
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/users/cities') {
        return _response({
          'cities': [
            {'city_id': 7, 'name': 'Караганда', 'delivery_type': 'DISTANCE'},
          ],
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/addresses/reverse' &&
          request.url.queryParameters['lat'] == '49.83' &&
          request.url.queryParameters['lon'] == '73.14') {
        return _response([_feature('Выбранный адрес', 49.83, 73.14)]);
      }
      unexpected.add('${request.method} ${request.url}');
      throw StateError('Unexpected onboarding location request');
    });
    GeolocatorPlatform.instance = platform;
    try {
      await http.runWithClient(() async {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.dark(),
          home: OnboardingPage(
            onCompleted: () => fail('Location does not complete onboarding'),
            initialCity: 'Караганда',
            actions: const OnboardingActions(
              locationSupported: true,
              notificationsSupported: false,
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final locate = find.byKey(const Key('onboarding-location'));
        await tester.ensureVisible(locate);
        await tester.tap(locate);
        await tester.pumpAndSettle();

        expect(platform.positionReads, 1);
        expect(platform.enabledReads, 1);
        expect(platform.permissionReads, 1);
        expect(platform.permissionRequests, 0);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('onboarding_location_prompt_seen'), isTrue);
        expect(find.byKey(const Key('onboarding-continue')), findsOneWidget);
      }, () => client);
    } finally {
      await _dispose(tester);
      GeolocatorPlatform.instance = priorPlatform;
      client.close();
      expect(unexpected, isEmpty);
    }
  });

  for (final state in ['disabled', 'denied', 'deniedForever', 'unavailable']) {
    testWidgets('map $state location leaves manual address usable',
        (tester) async {
      final priorPlatform = GeolocatorPlatform.instance;
      final platform = _LocationPlatform();
      switch (state) {
        case 'disabled':
          platform.enabled = false;
        case 'denied':
          platform.permission = LocationPermission.denied;
          platform.requestedPermission = LocationPermission.denied;
        case 'deniedForever':
          platform.permission = LocationPermission.deniedForever;
        case 'unavailable':
          platform.failPosition = true;
      }
      final reads = _AddressReads();
      GeolocatorPlatform.instance = platform;
      try {
        await http.runWithClient(() async {
          await _pumpMap(tester);
          await tester.tap(find.byKey(const Key('address_locate')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(platform.positionReads, state == 'unavailable' ? 1 : 0);
          expect(platform.permissionRequests, state == 'denied' ? 1 : 0);
          expect(
            find.text('Открыть настройки'),
            state == 'disabled' || state == 'deniedForever'
                ? findsOneWidget
                : findsNothing,
          );
          await tester.tap(find.text('Понятно'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Начальный адрес, 16'), findsOneWidget);
          expect(
            tester
                .widget<FilledButton>(
                    find.byKey(const Key('address_map_confirm')))
                .onPressed,
            isNotNull,
          );
          expect(reads.reversePoints, hasLength(1));
        }, () => reads.client);
      } finally {
        await _dispose(tester);
        GeolocatorPlatform.instance = priorPlatform;
        reads.client.close();
        expect(reads.unexpected, isEmpty);
      }
    });
  }
}
