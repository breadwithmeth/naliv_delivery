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
import 'package:naliv_delivery/main.dart';
import 'package:naliv_delivery/core/theme_controller.dart';
import 'package:naliv_delivery/utils/app_navigator.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/liked_items_provider.dart';
import 'package:provider/provider.dart';
import '../support/preferences_store.dart';
import 'package:naliv_delivery/features/onboarding/legal_acceptance.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import 'package:naliv_delivery/services/push_provider.dart';
import 'package:naliv_delivery/pages/login_page.dart';
import '../support/design_surfaces.dart';
import 'package:flutter/foundation.dart';
import 'package:naliv_delivery/features/faq/ui/faq_page.dart';
import 'package:naliv_delivery/widgets/authentication_wrapper.dart';

class _CountingPush extends InMemoryPushProvider {
  int starts = 0;
  @override
  Future<void> initialize({
    required VoidCallback onChange,
    required void Function(Map<String, dynamic>, bool) onNotification,
  }) async {
    starts++;
  }
}

class _MissingLegalBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => key.startsWith('assets/agreements/')
      ? Future.error(StateError('Missing bundled document'))
      : rootBundle.load(key);
}

class _RecoveringLegalBundle extends CachingAssetBundle {
  bool failed = false;
  @override
  Future<ByteData> load(String key) {
    if (key == 'assets/agreements/offer.md' && !failed) {
      failed = true;
      return Future.error(StateError('Transient asset failure'));
    }
    return rootBundle.load(key);
  }
}

class _UnreadablePreferences extends OnboardingPreferences {
  _UnreadablePreferences(super.values);
  bool unavailable = true;
  @override
  Future<Map<String, Object>> getAll() {
    if (unavailable) return Future.error(StateError('Storage unavailable'));
    return super.getAll();
  }
}

class _LegalPreferences extends OnboardingPreferences {
  _LegalPreferences(super.values);
  int legalWrites = 0;
  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key == 'flutter.legal_accepted_revisions') legalWrites++;
    return super.setValue(valueType, key, value);
  }
}

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
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: OnboardingPage(
        onCompleted: onCompleted,
        initialCity: initialCity,
        actions: actions,
      ),
    ),
  );
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

  Future<void> pumpBootstrap(WidgetTester tester, {
    AssetBundle? bundle, Future<bool> Function(Uri)? launch,
  }) async {
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/agreements/offer.md');
      await rootBundle.loadString('assets/agreements/privacy.md');
    });
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => BusinessProvider()),
          ChangeNotifierProvider(create: (_) => LikedItemsProvider()),
        ],
        child: DefaultAssetBundle(
          bundle: bundle ?? rootBundle,
          child: Main(contactLauncher: launch),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  Future<void> withAdmitted(WidgetTester tester, Future<void> Function() exercise, {
    String route = '/', Future<bool> Function(Uri)? launch,
  }) async {
    SharedPreferences.setMockInitialValues({...surfaceFixturePreferences}..remove('auth_token'));
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.binding.platformDispatcher.defaultRouteNameTestValue = route;
    final restore = NotificationService.installProvider(InMemoryPushProvider());
    final fixture = SurfaceFixtureClient();
    SurfaceFixtureClient.resetUnexpectedRequests();
    try {
      await http.runWithClient(() async {
        try {
          await pumpBootstrap(tester, launch: launch);
          await exercise();
          expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }, () => fixture);
    } finally {
      fixture.close();
      restore();
      debugDefaultTargetPlatformOverride = previous;
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue();
    }
  }

  testWidgets('completed installation predating intro needs only legal choices',
      (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    await pumpBootstrap(tester);
    expect(find.text('Условия использования'), findsOneWidget);
    expect(find.text('Персональные акции'), findsNothing);
  });

  testWidgets('a transient cached legal asset failure can be retried',
      (tester) async {
    SharedPreferences.setMockInitialValues({'intro_slides_seen': true});
    await pumpBootstrap(tester, bundle: _RecoveringLegalBundle());
    expect(find.textContaining('Не удалось открыть документы'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/agreements/privacy.md');
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Не удалось открыть документы'), findsNothing);
    expect(tester.widget<TextButton>(
      find.byKey(const ValueKey('legal-offer-document'))).onPressed, isNotNull);
  });

  testWidgets('admitted system Back respects an in-flight route guard',
      (tester) async {
    await withAdmitted(tester, () async {
      final saving = ValueNotifier(true);
      unawaited(AppNavigator.key.currentState!.push<void>(MaterialPageRoute(
        builder: (_) => ValueListenableBuilder<bool>(
          valueListenable: saving,
          builder: (_, busy, __) => PopScope(
            canPop: !busy,
            child: const Scaffold(body: Text('Отправляем заказ')),
          ),
        ),
      )));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Отправляем заказ'), findsOneWidget);
      saving.value = false;
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Отправляем заказ'), findsNothing);
      saving.dispose();
    });
  });

  testWidgets('warm FAQ request uses the existing admitted navigator',
      (tester) async {
    await withAdmitted(tester, () async {
      final navigator = AppNavigator.key.currentState;
      await tester.binding.handlePushRoute('/faq');
      await tester.pumpAndSettle();
      expect(find.byType(FaqPage), findsOneWidget);
      expect(AppNavigator.key.currentState, same(navigator));
      expect(find.byType(AuthenticationWrapper, skipOffstage: false), findsOneWidget);
    });
  });

  testWidgets('unknown cold route falls back to exactly one home',
      (tester) async {
    await withAdmitted(tester, () async {
      expect(find.byType(AuthenticationWrapper, skipOffstage: false), findsOneWidget);
      expect(AppNavigator.key.currentState!.canPop(), isFalse);
    }, route: '/unknown/nested');
  });

  testWidgets('home replacement retains the injected contact launcher',
      (tester) async {
    final launches = <Uri>[];
    await withAdmitted(tester, () async {
      unawaited(AppNavigator.goToHome());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Связаться'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Позвонить · Караганда'));
      await tester.pumpAndSettle();
      expect(launches, [Uri.parse('tel:+77719290005')]);
    }, launch: (uri) async { launches.add(uri); return true; });
  });

  testWidgets('warm FAQ before consent stays deferred until admission',
      (tester) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({...surfaceFixturePreferences}
      ..remove('auth_token')..remove('legal_accepted_revisions'));
    final push = _CountingPush();
    final restore = NotificationService.installProvider(push);
    final fixture = SurfaceFixtureClient();
    try {
      await http.runWithClient(() async {
        await pumpBootstrap(tester);
        await tester.binding.handlePushRoute('/faq');
        await tester.pumpAndSettle();
        expect(AppNavigator.key.currentState, isNull);
        expect(push.starts, 0);
        expect(find.text('Условия использования'), findsOneWidget);
        await _tap(tester, 'legal-offer-choice');
        await _tap(tester, 'legal-privacy-choice');
        await _tap(tester, 'legal-continue');
        expect(find.byType(FaqPage), findsOneWidget);
        expect(push.starts, 1);
        await tester.tap(find.byTooltip('Назад'));
        await tester.pumpAndSettle();
        expect(find.byType(AuthenticationWrapper), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => fixture);
    } finally {
      fixture.close();
      restore();
      debugDefaultTargetPlatformOverride = previous;
    }
  });

  testWidgets('storage read failure blocks and retry recovers without admission',
      (tester) async {
    final store = _UnreadablePreferences({'intro_slides_seen': true});
    store.install();
    await pumpBootstrap(tester);
    expect(AppNavigator.key.currentState, isNull);
    store.unavailable = false;
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/agreements/offer.md', cache: false);
      await rootBundle.loadString('assets/agreements/privacy.md', cache: false);
    });
    await tester.pumpAndSettle();
    expect(find.text('Условия использования'), findsOneWidget);
    expect(AppNavigator.key.currentState, isNull);
  });

  testWidgets(
    'clean install presents intro then independent legal choices before city',
    (tester) async {
      await pumpBootstrap(tester);
      expect(find.text('Персональные акции'), findsOneWidget);
      expect(AppNavigator.key.currentState, isNull);
      await tester.tap(find.text('Войти или зарегистрироваться'));
      await tester.pump();
      await tester.runAsync(() async {
        await rootBundle.loadString('assets/agreements/offer.md');
        await rootBundle.loadString('assets/agreements/privacy.md');
      });
      await tester.pumpAndSettle();
      expect(find.text('Условия использования'), findsOneWidget);
      expect(find.text('Ваш город'), findsNothing);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('legal-offer-choice')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('legal-privacy-choice')),
            )
            .value,
        isFalse,
      );
    },
  );

  testWidgets('legacy completed install cannot bypass legal gate via FAQ', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'intro_slides_seen': true,
      'onboarding_completed': true,
      'onboarding_selected_city': 'Караганда',
      'telemetry_consent_enabled': false,
    });
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/faq';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final requests = <String>[];
    await http.runWithClient(
      () async {
        await pumpBootstrap(tester);
        expect(find.text('Условия использования'), findsOneWidget);
        expect(AppNavigator.key.currentState, isNull);
        expect(requests, isEmpty);
        expect(
          (await SharedPreferences.getInstance()).getBool(
            'telemetry_consent_enabled',
          ),
          isFalse,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
      () => MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        throw StateError('No bootstrap requests before acceptance');
      }),
    );
  });

  testWidgets(
    'offline documents preserve independent choices; rejected save blocks',
    (tester) async {
      final store = OnboardingPreferences({
        'intro_slides_seen': true,
        'onboarding_completed': false,
        'telemetry_consent_enabled': false,
      })
        ..rejectedKeys.add('legal_accepted_revisions');
      store.install();
      await pumpBootstrap(tester);
      bool enabled() =>
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('legal-continue')),
              )
              .onPressed !=
          null;
      expect(enabled(), isFalse);
      await _tap(tester, 'legal-offer-document');
      expect(find.textContaining('Пользовательское соглашение'), findsWidgets);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(enabled(), isFalse);
      await _tap(tester, 'legal-offer-choice');
      expect(enabled(), isFalse);
      await _tap(tester, 'legal-privacy-document');
      expect(find.textContaining('ПОЛИТИКА КОНФИДЕНЦИАЛЬНОСТИ'), findsWidgets);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(enabled(), isFalse);
      await _tap(tester, 'legal-privacy-choice');
      expect(enabled(), isTrue);
      await _tap(tester, 'legal-continue');
      expect(
        find.textContaining('Не удалось сохранить согласия'),
        findsOneWidget,
      );
      expect(AppNavigator.key.currentState, isNull);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'legal_accepted_revisions',
        ),
        isNull,
      );
      store.rejectedKeys.clear();
      await http.runWithClient(() async {
        await _tap(tester, 'legal-continue');
        expect(find.text('Ваш город'), findsOneWidget);
        expect(
          (await SharedPreferences.getInstance()).getString(
            'legal_accepted_revisions',
          ),
          '{"offer":1,"privacy":1}',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpBootstrap(tester);
        expect(find.text('Ваш город'), findsOneWidget);
        expect(find.text('Условия использования'), findsNothing);
      }, () => _client(() => _cityResponse(_availableCities)));
    },
  );

  testWidgets('only outdated document requires acceptance', (tester) async {
    SharedPreferences.setMockInitialValues({
      'intro_slides_seen': true,
      'legal_accepted_revisions': '{"offer":2,"privacy":1}',
    });
    await pumpBootstrap(tester);
    final privacy = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('legal-privacy-choice')),
    );
    expect(privacy.value, isTrue);
    expect(privacy.onChanged, isNull);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('legal-continue')))
          .onPressed,
      isNull,
    );
    await _tap(tester, 'legal-offer-choice');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('legal-continue')))
          .onPressed,
      isNotNull,
    );
  });

  test('corrupt or obsolete acceptance is not evidence', () async {
    for (final raw in [
      'not json',
      '[]',
      '{"offer":true,"privacy":1}',
      '{"offer":1}',
      42,
    ]) {
      SharedPreferences.setMockInitialValues({'legal_accepted_revisions': raw});
      expect(LegalAcceptance.isCurrent(await LegalAcceptance.read()), isFalse);
    }
  });

  testWidgets('missing document blocks; malformed revision can be renewed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'intro_slides_seen': true});
    await pumpBootstrap(tester, bundle: _MissingLegalBundle());
    expect(find.textContaining('Не удалось открыть документы'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('legal-continue')))
          .onPressed,
      isNull,
    );
    expect(find.text('Повторить'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    SharedPreferences.setMockInitialValues({
      'intro_slides_seen': true,
      'legal_accepted_revisions': 7,
    });
    await pumpBootstrap(tester);
    expect(find.text('Условия использования'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('legal-offer-choice'))).value, isFalse);
    expect(AppNavigator.key.currentState, isNull);
  });

  testWidgets('double tap stores once; pending push waits for real bootstrap', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final prefs = _LegalPreferences(
      {...surfaceFixturePreferences}
        ..remove('auth_token')
        ..remove('legal_accepted_revisions'),
    )
      ..heldKey = 'legal_accepted_revisions'
      ..heldWrite = Completer<bool>();
    prefs.install();
    final push = _CountingPush();
    final restore = NotificationService.installProvider(push);
    addTearDown(restore);
    await NotificationService.instance.handleNotificationData({
      'type': 'order_status_change',
      'order_id': 45,
    }, clicked: true);
    SurfaceFixtureClient.resetUnexpectedRequests();
    final fixture = SurfaceFixtureClient();
    await http.runWithClient(() async {
      await pumpBootstrap(tester);
      expect(push.starts, 0);
      expect(AppNavigator.key.currentState, isNull);
      await _tap(tester, 'legal-offer-choice');
      await _tap(tester, 'legal-privacy-choice');
      await tester.tap(find.byKey(const ValueKey('legal-continue')));
      await tester.pump();
      expect(find.text('Сохраняем…'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('legal-continue')));
      expect(AppNavigator.key.currentState, isNull);
      expect(prefs.legalWrites, 1);
      prefs.heldWrite!.complete(true);
      await tester.pumpAndSettle();
      expect(push.starts, 1);
      expect(
        find.byType(LoginPage),
        findsOneWidget,
        reason:
            'pending orders push resumes guest sign-in only after admission',
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          'onboarding_selected_city',
        ),
        'Караганда',
      );
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'telemetry_consent_enabled',
        ),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(SurfaceFixtureClient.unexpectedRequests, isEmpty);
    }, () => fixture);
    fixture.close();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('onboarding is one screen with one continue button', (
    tester,
  ) async {
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
      await http.runWithClient(
        () async {
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
          expect(
            find.textContaining('Не удалось определить город'),
            findsNothing,
          );
          // Detecting never completes onboarding or saves the city by itself.
          expect(completed, 0);
          expect(await OnboardingService.getSelectedCity(), isNull);
          expect(
            (await OnboardingService.getState()).locationPromptSeen,
            isTrue,
          );

          await _tap(tester, 'onboarding-continue');
          expect(completed, 1);
          expect(await OnboardingService.getSelectedCity(), 'Город Б');
        },
        () => _client(
          () => _cityResponse(_availableCities),
          reverse: () => _reverseResponse('Город Б'),
        ),
      );
    },
  );

  testWidgets(
    'an unmatched location keeps the manual list usable and says so',
    (tester) async {
      var completed = 0;
      await http.runWithClient(
        () async {
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
            findsOneWidget,
          );
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
        ),
      );
    },
  );

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
