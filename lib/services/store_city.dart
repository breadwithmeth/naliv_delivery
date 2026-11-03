import 'onboarding_service.dart';

const _cityFields = [
  'city',
  'city_name',
  'cityName',
  'city_title',
  'cityTitle',
  'address',
  'description',
];

String _fold(Object? value) => (value?.toString() ?? '')
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Resolves the city name of [business] against the already-loaded [cities].
///
/// The server sends `city_id` (and no name), so the id is authoritative; the
/// names found in descriptive fields (mainly the address) are the fallback.
String? storeCityIn(
  Map<String, dynamic>? business,
  Iterable<OnboardingCity> cities,
) {
  if (business == null) return null;
  final idValue = business['city_id'] ?? business['cityId'];
  final id = idValue is int ? idValue : int.tryParse('${idValue ?? ''}');
  if (id != null) {
    for (final city in cities) {
      if (city.id == id) return city.name;
    }
  }
  for (final field in _cityFields) {
    final text = _fold(business[field]);
    if (text.isEmpty) continue;
    for (final city in cities) {
      final name = _fold(city.name);
      if (name.isNotEmpty && text.contains(name)) return city.name;
    }
  }
  return null;
}

/// City name of the store, loading the available cities when they are not
/// cached yet. Null when the store carries no resolvable city.
Future<String?> storeCityName(Map<String, dynamic>? business) async {
  if (business == null) return null;
  final cached = OnboardingService.getCityNameById(
      business['city_id'] ?? business['cityId']);
  if (cached != null) return cached;
  final cities = await OnboardingService.fetchAvailableCities();
  return storeCityIn(business, cities) ?? _explicitCity(business);
}

String? _explicitCity(Map<String, dynamic> business) {
  for (final field in const ['city', 'city_name', 'cityName']) {
    final value = business[field];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

/// Store coordinates, or null when the store has no usable point.
({double lat, double lon})? storeCoordinates(Map<String, dynamic>? business) {
  if (business == null) return null;
  final lat = _number(business['lat'] ?? business['latitude']);
  final lon =
      _number(business['lon'] ?? business['lng'] ?? business['longitude']);
  if (lat == null || lon == null) return null;
  if (lat.abs() > 90 || lon.abs() > 180 || (lat == 0 && lon == 0)) return null;
  return (lat: lat, lon: lon);
}

double? _number(Object? value) {
  final parsed = value is num ? value.toDouble() : double.tryParse('$value');
  return parsed != null && parsed.isFinite ? parsed : null;
}

/// Whether [address] lies in [city]. Null when the address carries no usable
/// city (unknown is never treated as a mismatch).
bool? addressMatchesCity(Map<String, dynamic>? address, String? city) {
  final wanted = _fold(city);
  if (address == null || wanted.isEmpty) return null;
  final actual = _fold(address['city']);
  if (actual.isEmpty || actual.contains('област') || actual.contains('обл.')) {
    return null;
  }
  return actual.contains(wanted) || wanted.contains(actual);
}
