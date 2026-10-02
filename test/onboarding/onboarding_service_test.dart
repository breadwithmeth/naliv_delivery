import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/services/onboarding_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preferences_store.dart';

http.Response _cities(List<Map<String, Object>> cities) => http.Response(
      jsonEncode({
        'success': true,
        'data': {'cities': cities},
      }),
      200,
      headers: const {'content-type': 'application/json'},
    );

MockClient _cityClient(http.Response response) {
  final unexpected = <Uri>[];
  addTearDown(() => expect(unexpected, isEmpty));
  return MockClient((request) async {
    if (request.method == 'GET' && request.url.path == '/api/users/cities') {
      return response;
    }
    unexpected.add(request.url);
    throw StateError('Unexpected request: ${request.method} ${request.url}');
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  test('failed refresh preserves only valid cached cities as stale', () async {
    SharedPreferences.setMockInitialValues({
      'onboarding_available_cities_cache': jsonEncode([
        {'city_id': 7, 'name': 'Город А', 'delivery_type': 'DISTANCE'},
        {'name': 'Неизвестный город'},
      ]),
    });
    final result = await http.runWithClient(
      () => OnboardingService.loadAvailableCities(),
      () => _cityClient(http.Response('Unavailable', 503)),
    );

    expect(result.failed, isTrue);
    expect(result.isStale, isTrue);
    expect(result.cities.map((city) => city.name), ['Город А']);
    expect(result.cities.single.deliveryType, 'DISTANCE');
  });

  test('successful empty availability removes cached cities and ids', () async {
    SharedPreferences.setMockInitialValues({
      'onboarding_available_cities_cache': jsonEncode([
        {'city_id': 7, 'name': 'Город А'},
      ]),
    });
    final result = await http.runWithClient(
      () => OnboardingService.loadAvailableCities(),
      () => _cityClient(_cities([])),
    );

    expect(result.failed, isFalse);
    expect(result.isStale, isFalse);
    expect(result.cities, isEmpty);
    expect(OnboardingService.getCityNameById(7), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(
        jsonDecode(prefs.getString('onboarding_available_cities_cache')!), []);
  });

  test('malformed nonempty city data is a failure, not zero availability',
      () async {
    final result = await http.runWithClient(
      () => OnboardingService.loadAvailableCities(),
      () => _cityClient(_cities([
        {'city_id': 'invalid', 'name': 'Город А'},
      ])),
    );
    expect(result.failed, isTrue);
    expect(result.cities, isEmpty);
  });

  test('a rejected city write restores the previously persisted selection',
      () async {
    final store = OnboardingPreferences({
      'onboarding_selected_city': 'Город А',
    })
      ..rejectedKeys.add('onboarding_selected_city');
    store.install();

    await expectLater(
      OnboardingService.setSelectedCity('Город Б'),
      throwsStateError,
    );
    expect(await OnboardingService.getSelectedCity(), 'Город А');
    expect((await OnboardingService.getState()).isCompleted, isFalse);
  });

  test('entry gate remains closed until completion is actually persisted',
      () async {
    final write = Completer<bool>();
    final store = OnboardingPreferences()
      ..heldKey = 'onboarding_completed'
      ..heldWrite = write;
    store.install();
    final completion = OnboardingService.complete(city: 'Город А');
    await Future<void>.delayed(Duration.zero);

    expect((await OnboardingService.getState()).isCompleted, isFalse);
    write.complete(false);
    await expectLater(completion, throwsStateError);
    expect((await OnboardingService.getState()).isCompleted, isFalse);

    store.heldKey = null;
    await OnboardingService.complete(city: 'Город А');
    final saved = await OnboardingService.getState();
    expect(saved.isCompleted, isTrue);
    expect(saved.selectedCity, 'Город А');
  });
}
