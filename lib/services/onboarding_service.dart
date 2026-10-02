import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:naliv_delivery/utils/api.dart';

class CityMapCenter {
  const CityMapCenter({required this.lat, required this.lon});

  final double lat;
  final double lon;
}

class OnboardingCity {
  const OnboardingCity(
      {required this.id, required this.name, this.deliveryType});

  final int id;
  final String name;
  final String? deliveryType;
}

class OnboardingState {
  const OnboardingState({
    required this.isCompleted,
    required this.selectedCity,
    required this.locationPromptSeen,
    required this.notificationPromptSeen,
  });

  final bool isCompleted;
  final String? selectedCity;
  final bool locationPromptSeen;
  final bool notificationPromptSeen;
}

class OnboardingCitiesResult {
  const OnboardingCitiesResult({
    required this.cities,
    this.isStale = false,
    this.failed = false,
  });

  final List<OnboardingCity> cities;
  final bool isStale;
  final bool failed;
}

class OnboardingService {
  static const String _completedKey = 'onboarding_completed';
  static const String _selectedCityKey = 'onboarding_selected_city';
  static const String _locationPromptSeenKey =
      'onboarding_location_prompt_seen';
  static const String _notificationPromptSeenKey =
      'onboarding_notification_prompt_seen';
  static const String _availableCitiesCacheKey =
      'onboarding_available_cities_cache';

  static List<OnboardingCity> _citiesCache = <OnboardingCity>[];
  static Map<int, String> _cityIds = <int, String>{};

  static const Map<String, CityMapCenter> _cityCenters = {
    'Павлодар': CityMapCenter(lat: 52.2871, lon: 76.9674),
    'Караганда': CityMapCenter(lat: 49.8047, lon: 73.1094),
    'Темиртау': CityMapCenter(lat: 50.0549, lon: 72.9590),
    'Астана': CityMapCenter(lat: 51.1694, lon: 71.4491),
  };

  static List<String> get availableCities =>
      List<String>.unmodifiable(_citiesCache.map((city) => city.name));

  static List<OnboardingCity> get cachedCities =>
      List<OnboardingCity>.unmodifiable(_citiesCache);

  static Future<void> _hydrateCitiesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_availableCitiesCacheKey);
    final cities = <OnboardingCity>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) continue;
            final parsed = _parseCity(Map<String, dynamic>.from(item));
            if (parsed != null &&
                !cities.any((city) =>
                    city.id == parsed.id || city.name == parsed.name)) {
              cities.add(parsed);
            }
          }
        }
      } catch (_) {
        // Corrupt cache is not a list of available cities.
      }
    }
    _replaceCities(cities);
  }

  static void _replaceCities(List<OnboardingCity> cities) {
    _citiesCache = cities;
    _cityIds = {for (final city in cities) city.id: city.name};
  }

  static OnboardingCity? _parseCity(Map<String, dynamic> city) {
    final idValue = city['city_id'] ?? city['id'];
    final id =
        idValue is int ? idValue : int.tryParse(idValue?.toString() ?? '');
    final nameValue = city['name'];
    final name = nameValue is String ? nameValue.trim() : null;
    if (id == null || id <= 0 || name == null || name.isEmpty) return null;

    return OnboardingCity(
      id: id,
      name: name,
      deliveryType: city['delivery_type'] is String
          ? (city['delivery_type'] as String).trim()
          : null,
    );
  }

  static Future<OnboardingState> getState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return OnboardingState(
      isCompleted: prefs.getBool(_completedKey) ?? false,
      selectedCity: prefs.getString(_selectedCityKey),
      locationPromptSeen: prefs.getBool(_locationPromptSeenKey) ?? false,
      notificationPromptSeen:
          prefs.getBool(_notificationPromptSeenKey) ?? false,
    );
  }

  static Future<void> setSelectedCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await _persist(
      prefs,
      prefs.setString(_selectedCityKey, city),
      'Could not save selected city',
    );
  }

  static Future<String?> getSelectedCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedCityKey);
  }

  static Future<List<OnboardingCity>> fetchAvailableCities(
      {bool forceRefresh = false}) async {
    return (await loadAvailableCities(forceRefresh: forceRefresh)).cities;
  }

  static Future<OnboardingCitiesResult> loadAvailableCities(
      {bool forceRefresh = true}) async {
    try {
      await _hydrateCitiesFromPrefs();
      if (!forceRefresh && _citiesCache.isNotEmpty) {
        return OnboardingCitiesResult(cities: cachedCities, isStale: true);
      }

      final response = await ApiService.getAvailableCities()
          .timeout(const Duration(seconds: 10));
      if (response == null) {
        return OnboardingCitiesResult(
          cities: cachedCities,
          isStale: _citiesCache.isNotEmpty,
          failed: true,
        );
      }

      final cities = <OnboardingCity>[];
      for (final city in response) {
        final parsed = _parseCity(city);
        if (parsed != null &&
            !cities.any(
                (city) => city.id == parsed.id || city.name == parsed.name)) {
          cities.add(parsed);
        }
      }
      if (response.isNotEmpty && cities.isEmpty) {
        return OnboardingCitiesResult(
          cities: cachedCities,
          isStale: _citiesCache.isNotEmpty,
          failed: true,
        );
      }

      // A successful empty response must clear previously available cities.
      _replaceCities(cities);
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(
          _availableCitiesCacheKey,
          json.encode([
            for (final city in cities)
              {
                'city_id': city.id,
                'name': city.name,
                'delivery_type': city.deliveryType,
              },
          ]),
        )) {
          throw StateError('Could not cache available cities');
        }
      } catch (error) {
        // Fresh server data remains usable even if the cache cannot be saved.
        debugPrint('Could not cache onboarding cities: $error');
      }
      return OnboardingCitiesResult(cities: cachedCities);
    } catch (error) {
      debugPrint('Could not load onboarding cities: $error');
      return OnboardingCitiesResult(
        cities: cachedCities,
        isStale: _citiesCache.isNotEmpty,
        failed: true,
      );
    }
  }

  static CityMapCenter? getCityCenter(String? city) {
    if (city == null) return null;
    return _cityCenters[city.trim()];
  }

  static String? getCityNameById(dynamic cityId) {
    if (cityId == null) return null;
    final parsedId = cityId is int ? cityId : int.tryParse(cityId.toString());
    if (parsedId == null) return null;
    return _cityIds[parsedId];
  }

  static Future<void> markLocationPromptSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await _persist(
      prefs,
      prefs.setBool(_locationPromptSeenKey, true),
      'Could not save location prompt choice',
    );
  }

  static Future<void> markNotificationPromptSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await _persist(
      prefs,
      prefs.setBool(_notificationPromptSeenKey, true),
      'Could not save notification prompt choice',
    );
  }

  static Future<void> complete({required String city}) async {
    final prefs = await SharedPreferences.getInstance();
    await _persist(
      prefs,
      prefs.setString(_selectedCityKey, city),
      'Could not save selected city',
    );
    await _persist(
      prefs,
      prefs.setBool(_completedKey, true),
      'Could not save onboarding completion',
    );
  }

  static Future<void> _persist(
    SharedPreferences prefs,
    Future<bool> write,
    String failure,
  ) async {
    try {
      if (await write) return;
    } catch (_) {
      await prefs.reload();
      rethrow;
    }
    // SharedPreferences updates its memory cache before the platform write.
    // Restore persisted state so a rejected completion cannot open the gate.
    await prefs.reload();
    throw StateError(failure);
  }
}
