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

MockClient _client(http.Response Function() respond) {
  final unexpected = <Uri>[];
  addTearDown(() => expect(unexpected, isEmpty));
  return MockClient((request) async {
    if (request.method == 'GET' && request.url.path == '/api/users/cities') {
      return respond();
    }
    unexpected.add(request.url);
    throw StateError('Unexpected request: ${request.method} ${request.url}');
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required VoidCallback onCompleted,
  OnboardingActions actions = _manualActions,
  String? initialCity = 'Город А',
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        'telemetry_consent_enabled': false,
      }));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'failure and confirmed empty availability both block continuation',
      (tester) async {
    var response = http.Response('Unavailable', 503);
    await http.runWithClient(() async {
      await _pumpPage(tester, onCompleted: () => fail('No city was selected'));
      expect(find.byKey(const ValueKey('onboarding-cities-error')),
          findsOneWidget);
      await _tap(tester, 'onboarding-continue');
      expect((await OnboardingService.getState()).isCompleted, isFalse);

      response = _cityResponse([]);
      await _tap(tester, 'onboarding-retry-cities');
      expect(
          find.byKey(const ValueKey('onboarding-cities-error')), findsNothing);
      expect(find.byKey(const ValueKey('onboarding-cities-empty')),
          findsOneWidget);
      await _tap(tester, 'onboarding-continue');
      expect((await OnboardingService.getState()).isCompleted, isFalse);
    }, () => _client(() => response));
  });

  testWidgets(
      'cached city stays usable when refresh fails and permissions deny',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'telemetry_consent_enabled': false,
      'onboarding_available_cities_cache': jsonEncode(_availableCities),
    });
    var completed = 0;
    final actions = OnboardingActions(
      locationSupported: true,
      notificationsSupported: true,
      requestLocationPermission: () async => LocationPermissionResult(
        success: false,
        message: 'Доступ отключён в настройках.',
        permissionStatus: LocationPermission.deniedForever,
        needsSettingsRedirect: true,
      ),
      locate: () => throw StateError('Denied location must not be read'),
      enableNotifications: () => throw StateError('Permission service failed'),
      openLocationSettings: () async => false,
    );
    await http.runWithClient(() async {
      await _pumpPage(tester, actions: actions, onCompleted: () => completed++);
      expect(find.byKey(const ValueKey('onboarding-retry-cities')),
          findsOneWidget);
      await _tap(tester, 'onboarding-continue');
      await _tap(tester, 'onboarding-location');
      expect(find.byKey(const ValueKey('onboarding-location')), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding-location-settings')),
          findsOneWidget);
      await _tap(tester, 'onboarding-notifications');
      expect(find.byKey(const ValueKey('onboarding-notifications')),
          findsOneWidget);
      await _tap(tester, 'onboarding-complete');

      expect(completed, 1);
      final state = await OnboardingService.getState();
      expect(state.selectedCity, 'Город А');
      expect(state.isCompleted, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('telemetry_consent_enabled'), isFalse);
    }, () => _client(() => http.Response('Unavailable', 503)));
  });

  testWidgets('a pending optional notification request cannot block completion',
      (tester) async {
    final request = Completer<bool>();
    var completed = 0;
    await http.runWithClient(() async {
      await _pumpPage(
        tester,
        onCompleted: () => completed++,
        actions: OnboardingActions(
          locationSupported: false,
          notificationsSupported: true,
          enableNotifications: () => request.future,
        ),
      );
      await _tap(tester, 'onboarding-continue');
      await _tap(tester, 'onboarding-notifications');
      await _tap(tester, 'onboarding-skip-notifications');
      await _tap(tester, 'onboarding-complete');
      expect(completed, 1);
      expect((await OnboardingService.getState()).isCompleted, isTrue);

      request.complete(true);
      await tester.pumpAndSettle();
      expect(completed, 1);
      expect(find.byKey(const ValueKey('onboarding-notifications')),
          findsOneWidget);
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
      await _pumpPage(tester, onCompleted: () {});
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(await OnboardingService.getSelectedCity(), isNull);
      await _tap(tester, 'onboarding-continue');
      expect(await OnboardingService.getSelectedCity(), 'Город Б');
      expect((await OnboardingService.getState()).isCompleted, isFalse);
    }, () => _client(() => _cityResponse(_availableCities)));
  });
}
