import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/pages/onboarding_page.dart';
import 'package:naliv_delivery/services/onboarding_service.dart';
import 'package:naliv_delivery/utils/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _manualActions = OnboardingActions(
  locationSupported: false,
  notificationsSupported: false,
);

const _availableCities = [
  {'city_id': 7, 'name': 'Город А', 'delivery_type': 'DISTANCE'},
  {'city_id': 8, 'name': 'Город Б', 'delivery_type': 'AREA'},
];

http.Response _cityResponse(List<Map<String, Object>> cities) => http.Response(
      jsonEncode({
        'success': true,
        'data': {'cities': cities},
      }),
      200,
      headers: const {'content-type': 'application/json'},
    );

/// A reverse-geocoding feature in [city], as the address service returns it.
http.Response _reverseResponse(String city) => http.Response(
      jsonEncode({
        'success': true,
        'data': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [73.14, 49.83],
            },
            'properties': {
              'geocoding': {
                'country': 'Казахстан',
                'city': city,
                'street': 'Улица',
                'housenumber': '1',
              },
            },
          },
        ],
      }),
      200,
      headers: const {'content-type': 'application/json'},
    );

MockClient _client(
  http.Response Function() cities, {
  http.Response Function()? reverse,
}) {
  final unexpected = <Uri>[];
  addTearDown(() => expect(unexpected, isEmpty));
  return MockClient((request) async {
    if (request.method == 'GET' && request.url.path == '/api/users/cities') {
      return cities();
    }
    if (reverse != null &&
        request.method == 'GET' &&
        request.url.path == '/api/addresses/reverse') {
      return reverse();
    }
    unexpected.add(request.url);
    throw StateError('Unexpected request: ${request.method} ${request.url}');
  });
}

Position _position() => Position(
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

LocationPermissionResult _granted() => LocationPermissionResult(
      success: true,
      message: 'Доступ разрешён',
      permissionStatus: LocationPermission.whileInUse,
    );

LocationPermissionResult _denied() => LocationPermissionResult(
      success: false,
      message: 'Доступ отключён в настройках.',
      permissionStatus: LocationPermission.deniedForever,
      needsSettingsRedirect: true,
    );

Future<void> _pumpPage(
  WidgetTester tester, {
  required VoidCallback onCompleted,
  OnboardingActions actions = _manualActions,
  String? initialCity,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark(),
    home: OnboardingPage(
      onCompleted: onCompleted,
      initialCity: initialCity,
      actions: actions,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

bool _continueEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(const ValueKey('onboarding-continue')))
        .onPressed !=
    null;

String? _selected(WidgetTester tester) =>
    tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>)).groupValue;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        'telemetry_consent_enabled': false,
      }));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('onboarding is one screen with one continue button',
      (tester) async {
    await http.runWithClient(() async {
      await _pumpPage(tester, onCompleted: () {});
      expect(find.text('Ваш город'), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-city-7')), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-city-8')), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-continue')), findsOneWidget);
      expect(find.text('Продолжить'), findsOneWidget);
      // No permissions step, no back, no separate completion.
      expect(find.text('Разрешения'), findsNothing);
      for (final key in [
        'onboarding-complete',
        'onboarding-back',
        'onboarding-notifications',
        'onboarding-skip-notifications',
        'onboarding-skip-location',
        'onboarding-location-settings',
        'onboarding-telemetry',
      ]) {
        expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
      }
    }, () => _client(() => _cityResponse(_availableCities)));
  });

  testWidgets('continue stays disabled until a city is chosen', (tester) async {
    var completed = 0;
    await http.runWithClient(() async {
      await _pumpPage(tester, onCompleted: () => completed++);
      expect(_selected(tester), isNull);
      expect(_continueEnabled(tester), isFalse);
      await _tap(tester, 'onboarding-continue');
      expect(completed, 0);
      expect((await OnboardingService.getState()).isCompleted, isFalse);

      await _tap(tester, 'onboarding-city-8');
      expect(_selected(tester), 'Город Б');
      expect(_continueEnabled(tester), isTrue);
    }, () => _client(() => _cityResponse(_availableCities)));
  });

  testWidgets('a single city needs no choice and is preselected',
      (tester) async {
    var completed = 0;
    await http.runWithClient(() async {
      await _pumpPage(tester, onCompleted: () => completed++);
      expect(_selected(tester), 'Город А');
      expect(_continueEnabled(tester), isTrue);
      // One city leaves nothing to detect.
      expect(find.byKey(const ValueKey('onboarding-location')), findsNothing);
      await _tap(tester, 'onboarding-continue');
      expect(completed, 1);
      expect((await OnboardingService.getState()).selectedCity, 'Город А');
    }, () => _client(() => _cityResponse([_availableCities.first])));
  });

  testWidgets(
      'failure and confirmed empty availability both block continuation until a retry brings cities',
      (tester) async {
    var response = http.Response('Unavailable', 503);
    await http.runWithClient(() async {
      await _pumpPage(tester, onCompleted: () => fail('No city was selected'));
      expect(find.byKey(const ValueKey('onboarding-cities-error')),
          findsOneWidget);
      expect(_continueEnabled(tester), isFalse);
      await _tap(tester, 'onboarding-continue');
      expect((await OnboardingService.getState()).isCompleted, isFalse);

      response = _cityResponse([]);
      await _tap(tester, 'onboarding-retry-cities');
      expect(
          find.byKey(const ValueKey('onboarding-cities-error')), findsNothing);
      expect(find.byKey(const ValueKey('onboarding-cities-empty')),
          findsOneWidget);
      expect(_continueEnabled(tester), isFalse);
      await _tap(tester, 'onboarding-continue');
      expect((await OnboardingService.getState()).isCompleted, isFalse);

      response = _cityResponse(_availableCities);
      await _tap(tester, 'onboarding-retry-cities');
      expect(find.byKey(const ValueKey('onboarding-cities-empty')),
          findsNothing);
      expect(find.byKey(const ValueKey('onboarding-city-7')), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-city-8')), findsOneWidget);
      expect(_continueEnabled(tester), isFalse);
    }, () => _client(() => response));
  });

  testWidgets('a cached city list stays usable when the refresh fails',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'telemetry_consent_enabled': false,
      'onboarding_available_cities_cache': jsonEncode(_availableCities),
    });
    var completed = 0;
    await http.runWithClient(() async {
      await _pumpPage(tester, onCompleted: () => completed++);
      expect(find.byKey(const ValueKey('onboarding-retry-cities')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-cities-error')),
          findsNothing);
      await _tap(tester, 'onboarding-city-7');
      await _tap(tester, 'onboarding-continue');
      expect(completed, 1);
      expect((await OnboardingService.getState()).selectedCity, 'Город А');
    }, () => _client(() => http.Response('Unavailable', 503)));
  });

  testWidgets(
      'continue saves the city, completes, and asks for notifications exactly once',
      (tester) async {
    var completed = 0;
    var notificationRequests = 0;
    await http.runWithClient(() async {
      await _pumpPage(
        tester,
        onCompleted: () => completed++,
        actions: OnboardingActions(
          locationSupported: false,
          notificationsSupported: true,
          enableNotifications: () async {
            notificationRequests++;
            return true;
          },
        ),
      );
      await _tap(tester, 'onboarding-city-8');
      expect(notificationRequests, 0,
          reason: 'choosing a city must not ask for permission');
      await _tap(tester, 'onboarding-continue');

      expect(completed, 1);
      expect(notificationRequests, 1);
      final state = await OnboardingService.getState();
      expect(state.selectedCity, 'Город Б');
      expect(state.isCompleted, isTrue);
      expect(state.notificationPromptSeen, isTrue);
      // Telemetry stays opt-in in Settings: onboarding never writes the consent.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('telemetry_consent_enabled'), isFalse);
    }, () => _client(() => _cityResponse(_availableCities)));
  });

  testWidgets('no notification request where notifications are unsupported',
      (tester) async {
    var completed = 0;
    var notificationRequests = 0;
    await http.runWithClient(() async {
      await _pumpPage(
        tester,
        onCompleted: () => completed++,
        actions: OnboardingActions(
          locationSupported: false,
          notificationsSupported: false,
          enableNotifications: () async {
            notificationRequests++;
            return true;
          },
        ),
        initialCity: 'Город А',
      );
      await _tap(tester, 'onboarding-continue');
      expect(completed, 1);
      expect(notificationRequests, 0);
    }, () => _client(() => _cityResponse(_availableCities)));
  });

  testWidgets('a failing notification request cannot block completion',
      (tester) async {
    var completed = 0;
    var notificationRequests = 0;
    await http.runWithClient(() async {
      await _pumpPage(
        tester,
        onCompleted: () => completed++,
        initialCity: 'Город А',
        actions: OnboardingActions(
          locationSupported: false,
          notificationsSupported: true,
          enableNotifications: () {
            notificationRequests++;
            return Future<bool>.error(StateError('Permission service failed'));
          },
        ),
      );
      await _tap(tester, 'onboarding-continue');
      expect(notificationRequests, 1);
      expect(completed, 1);
      final state = await OnboardingService.getState();
      expect(state.selectedCity, 'Город А');
      expect(state.isCompleted, isTrue);
      expect(tester.takeException(), isNull);
    }, () => _client(() => _cityResponse(_availableCities)));
  });

  testWidgets('a pending notification request cannot block completion',
      (tester) async {
    final request = Completer<bool>();
    var completed = 0;
    await http.runWithClient(() async {
      await _pumpPage(
        tester,
        onCompleted: () => completed++,
        initialCity: 'Город А',
        actions: OnboardingActions(
          locationSupported: false,
          notificationsSupported: true,
          enableNotifications: () => request.future,
        ),
      );
      await _tap(tester, 'onboarding-continue');
      expect(completed, 1);
      expect((await OnboardingService.getState()).isCompleted, isTrue);

      request.complete(true);
      await tester.pumpAndSettle();
      expect(completed, 1);
    }, () => _client(() => _cityResponse(_availableCities)));
  });

  testWidgets(
      'locating selects the matching city and leaves saving to continue',
      (tester) async {
    var completed = 0;
    var permissionRequests = 0;
    await http.runWithClient(() async {
      await _pumpPage(
        tester,
        onCompleted: () => completed++,
        initialCity: 'Город А',
        actions: OnboardingActions(
          locationSupported: true,
          notificationsSupported: false,
          requestLocationPermission: () async {
            permissionRequests++;
            return _granted();
          },
          locate: () async => _position(),
        ),
      );
      expect(_selected(tester), 'Город А');
      await _tap(tester, 'onboarding-location');
      expect(permissionRequests, 1);
      expect(_selected(tester), 'Город Б');
      expect(find.textContaining('Не удалось определить город'), findsNothing);
      // Detecting never completes onboarding or saves the city by itself.
      expect(completed, 0);
      expect(await OnboardingService.getSelectedCity(), isNull);
      expect((await OnboardingService.getState()).locationPromptSeen, isTrue);

      await _tap(tester, 'onboarding-continue');
      expect(completed, 1);
      expect(await OnboardingService.getSelectedCity(), 'Город Б');
    },
        () => _client(
              () => _cityResponse(_availableCities),
              reverse: () => _reverseResponse('Город Б'),
            ));
  });

  testWidgets(
      'an unmatched location keeps the manual list usable and says so',
      (tester) async {
    var completed = 0;
    await http.runWithClient(() async {
      await _pumpPage(
        tester,
        onCompleted: () => completed++,
        actions: OnboardingActions(
          locationSupported: true,
          notificationsSupported: false,
          requestLocationPermission: () async => _granted(),
          locate: () async => _position(),
        ),
      );
      await _tap(tester, 'onboarding-location');
      expect(
          find.text('Не удалось определить город. Выберите его в списке.'),
          findsOneWidget);
      expect(_selected(tester), isNull);
      expect(_continueEnabled(tester), isFalse);
      await _tap(tester, 'onboarding-city-7');
      expect(_continueEnabled(tester), isTrue);
      await _tap(tester, 'onboarding-continue');
      expect(completed, 1);
      expect(await OnboardingService.getSelectedCity(), 'Город А');
    },
        () => _client(
              () => _cityResponse(_availableCities),
              reverse: () => _reverseResponse('Другой город'),
            ));
  });

  testWidgets('a denied location leaves the manual list usable',
      (tester) async {
    var completed = 0;
    await http.runWithClient(() async {
      await _pumpPage(
        tester,
        onCompleted: () => completed++,
        actions: OnboardingActions(
          locationSupported: true,
          notificationsSupported: false,
          requestLocationPermission: () async => _denied(),
          locate: () => throw StateError('Denied location must not be read'),
        ),
      );
      await _tap(tester, 'onboarding-location');
      expect(
          find.text('Нет доступа к геолокации. Выберите город в списке.'),
          findsOneWidget);
      // No settings redirect and no skip button: the list is the way forward.
      expect(find.byKey(const ValueKey('onboarding-location-settings')),
          findsNothing);
      expect(find.byKey(const ValueKey('onboarding-location')), findsOneWidget);
      await _tap(tester, 'onboarding-city-8');
      await _tap(tester, 'onboarding-continue');
      expect(completed, 1);
      expect(await OnboardingService.getSelectedCity(), 'Город Б');
    }, () => _client(() => _cityResponse(_availableCities)));
  });

  testWidgets('a location read that throws leaves the manual list usable',
      (tester) async {
    await http.runWithClient(() async {
      await _pumpPage(
        tester,
        onCompleted: () {},
        actions: OnboardingActions(
          locationSupported: true,
          notificationsSupported: false,
          requestLocationPermission: () async => _granted(),
          locate: () async => throw StateError('No position'),
        ),
      );
      await _tap(tester, 'onboarding-location');
      expect(
          find.text('Не удалось определить город. Выберите его в списке.'),
          findsOneWidget);
      await _tap(tester, 'onboarding-city-7');
      expect(_continueEnabled(tester), isTrue);
    }, () => _client(() => _cityResponse(_availableCities)));
  });

  testWidgets('disposed location request cannot persist or advance onboarding',
      (tester) async {
    final request = Completer<LocationPermissionResult>();
    var completed = 0;
    await http.runWithClient(() async {
      await _pumpPage(
        tester,
        onCompleted: () => completed++,
        actions: OnboardingActions(
          locationSupported: true,
          notificationsSupported: false,
          requestLocationPermission: () => request.future,
          locate: () => throw StateError('Disposed location must not be read'),
        ),
      );
      await _tap(tester, 'onboarding-location');
      await tester.pumpWidget(const SizedBox.shrink());
      request.complete(LocationPermissionResult(
        success: false,
        message: 'Отказано',
        permissionStatus: LocationPermission.denied,
      ));
      await tester.pumpAndSettle();
      final state = await OnboardingService.getState();
      expect(state.locationPromptSeen, isFalse);
      expect(state.isCompleted, isFalse);
      expect(completed, 0);
    }, () => _client(() => _cityResponse(_availableCities)));
  });

  testWidgets('keyboard city selection is saved only when continuing',
      (tester) async {
    await http.runWithClient(() async {
      await _pumpPage(tester, onCompleted: () {}, initialCity: 'Город А');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(await OnboardingService.getSelectedCity(), isNull);
      await _tap(tester, 'onboarding-continue');
      expect(await OnboardingService.getSelectedCity(), 'Город Б');
      expect((await OnboardingService.getState()).isCompleted, isTrue);
    }, () => _client(() => _cityResponse(_availableCities)));
  });
}
