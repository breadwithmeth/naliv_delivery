import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/services/onboarding_service.dart';
import 'package:naliv_delivery/services/store_city.dart';

const _cities = [
  OnboardingCity(id: 2, name: 'Караганда'),
  OnboardingCity(id: 3, name: 'Астана'),
  OnboardingCity(id: 4, name: 'Темиртау'),
];

void main() {
  group('storeCityIn', () {
    test('city_id wins over a misleading address', () {
      expect(
        storeCityIn({'city_id': 4, 'address': 'Караганда, Мира 1'}, _cities),
        'Темиртау',
      );
      expect(storeCityIn({'city_id': '3', 'address': 'Мира 1'}, _cities),
          'Астана');
    });

    test('falls back to a city named in the address or description', () {
      expect(storeCityIn({'address': 'Бухар-Жырау 70, Караганда'}, _cities),
          'Караганда');
      expect(
          storeCityIn(
              {'city_id': 99, 'description': 'Магазин в Темиртау'}, _cities),
          'Темиртау');
    });

    test('is null when nothing identifies a known city', () {
      expect(storeCityIn({'address': 'Мира 1'}, _cities), isNull);
      expect(storeCityIn(null, _cities), isNull);
      expect(storeCityIn({'city_id': 4}, const []), isNull);
    });
  });

  group('storeCoordinates', () {
    test('reads numeric and string coordinates and rejects unusable points',
        () {
      expect(storeCoordinates({'lat': 50.05, 'lon': '72.96'}),
          (lat: 50.05, lon: 72.96));
      expect(storeCoordinates({'lat': 0, 'lon': 0}), isNull);
      expect(storeCoordinates({'lat': 91, 'lon': 10}), isNull);
      expect(storeCoordinates({'lat': 50.0}), isNull);
      expect(storeCoordinates(null), isNull);
    });
  });

  group('addressMatchesCity', () {
    test('matches regardless of prefix and case', () {
      expect(addressMatchesCity({'city': 'Темиртау'}, 'Темиртау'), isTrue);
      expect(addressMatchesCity({'city': 'г. Темиртау'}, 'Темиртау'), isTrue);
      expect(addressMatchesCity({'city': 'КАРАГАНДА'}, 'Караганда'), isTrue);
    });

    test('reports a different known city', () {
      expect(addressMatchesCity({'city': 'Караганда'}, 'Темиртау'), isFalse);
      expect(addressMatchesCity({'city': 'Астана'}, 'Караганда'), isFalse);
    });

    test('unknown address city or store city is never a mismatch', () {
      expect(addressMatchesCity({'street': 'Мира'}, 'Темиртау'), isNull);
      expect(addressMatchesCity({'city': ''}, 'Темиртау'), isNull);
      expect(
          addressMatchesCity({'city': 'Карагандинская область'}, 'Караганда'),
          isNull);
      expect(addressMatchesCity({'city': 'Караганда'}, null), isNull);
      expect(addressMatchesCity(null, 'Караганда'), isNull);
    });
  });
}
