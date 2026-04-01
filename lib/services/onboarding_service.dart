import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:naliv_delivery/utils/api.dart';

class CityMapCenter {
  const CityMapCenter({required this.lat, required this.lon});

  final double lat;
  final double lon;
}

class OnboardingCity {
  const OnboardingCity({required this.id, required this.name, this.deliveryType});

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

class OnboardingService {
  static const String _completedKey = 'onboarding_completed';
  static const String _selectedCityKey = 'onboarding_selected_city';
  static const String _locationPromptSeenKey = 'onboarding_location_prompt_seen';
  static const String _notificationPromptSeenKey = 'onboarding_notification_prompt_seen';
  static const String _availableCitiesCacheKey = 'onboarding_available_cities_cache';

  static List<OnboardingCity> _citiesCache = <OnboardingCity>[];
  static Map<int, String> _cityIds = <int, String>{};

  static const Map<String, CityMapCenter> _cityCenters = {
    'Павлодар': CityMapCenter(lat: 52.2871, lon: 76.9674),
    'Караганда': CityMapCenter(lat: 49.8047, lon: 73.1094),
    'Темиртау': CityMapCenter(lat: 50.0549, lon: 72.9590),
    'Астана': CityMapCenter(lat: 51.1694, lon: 71.4491),
  };

  static List<String> get availableCities => List<String>.unmodifiable(_citiesCache.map((city) => city.name));

  static List<OnboardingCity> get cachedCities => List<OnboardingCity>.unmodifiable(_citiesCache);

  static Future<void> _hydrateCitiesFromPrefs() async {
    if (_citiesCache.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_availableCitiesCacheKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return;

      final parsedCities = <OnboardingCity>[];
      final parsedIds = <int, String>{};

      for (final item in decoded) {
        if (item is! Map) continue;
        final city = Map<String, dynamic>.from(item);
        final parsed = _parseCity(city);
        if (parsed == null) continue;
        parsedCities.add(parsed);
        parsedIds[parsed.id] = parsed.name;
      }

      if (parsedCities.isEmpty) return;

      _citiesCache = parsedCities;
      _cityIds = parsedIds;
    } catch (_) {}
  }

  static OnboardingCity? _parseCity(Map<String, dynamic> city) {
    final idValue = city['city_id'] ?? city['id'];
    final id = idValue is int ? idValue : int.tryParse(idValue?.toString() ?? '');
    final name = city['name']?.toString().trim();
    if (id == null || name == null || name.isEmpty) return null;

    return OnboardingCity(id: id, name: name, deliveryType: city['delivery_type']?.toString());
  }

  static Future<OnboardingState> getState() async {
    final prefs = await SharedPreferences.getInstance();
    return OnboardingState(
      isCompleted: prefs.getBool(_completedKey) ?? false,
      selectedCity: prefs.getString(_selectedCityKey),
      locationPromptSeen: prefs.getBool(_locationPromptSeenKey) ?? false,
      notificationPromptSeen: prefs.getBool(_notificationPromptSeenKey) ?? false,
    );
  }

  static Future<void> setSelectedCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedCityKey, city);
  }

  static Future<String?> getSelectedCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedCityKey);
  }

  static Future<List<OnboardingCity>> fetchAvailableCities({bool forceRefresh = false}) async {
    await _hydrateCitiesFromPrefs();

    if (!forceRefresh && _citiesCache.isNotEmpty) {
      return cachedCities;
    }

    final response = await ApiService.getAvailableCities();
    if (response == null || response.isEmpty) {
      return cachedCities;
    }

    final parsedCities = <OnboardingCity>[];
    final parsedIds = <int, String>{};

    for (final city in response) {
      final parsed = _parseCity(city);
      if (parsed == null) continue;
      parsedCities.add(parsed);
      parsedIds[parsed.id] = parsed.name;
    }

    if (parsedCities.isEmpty) {
      return cachedCities;
    }

    _citiesCache = parsedCities;
    _cityIds = parsedIds;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _availableCitiesCacheKey,
      json.encode([
        for (final city in parsedCities)
          {
            'city_id': city.id,
            'name': city.name,
            'delivery_type': city.deliveryType,
          },
      ]),
    );

    return cachedCities;
  }

  /// Best-effort IP geolocation to preselect a city. Returns a city name if it matches available cities.
  static Future<String?> guessCityByIp() async {
    // Skip IP lookup on web to avoid CORS failures in browsers; rely on city list/location instead.
    if (kIsWeb) return null;
    try {
      if (_citiesCache.isEmpty) return null;
      final resp = await http.get(Uri.parse('https://ipapi.co/json/')).timeout(const Duration(seconds: 4));
      if (resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      final cityName = data['city']?.toString();
      if (cityName == null || cityName.isEmpty) return null;

      final match = _citiesCache.firstWhere(
        (c) => c.name.toLowerCase() == cityName.toLowerCase(),
        orElse: () => _citiesCache.firstWhere(
          (c) => c.name.toLowerCase().contains(cityName.toLowerCase()),
          orElse: () => const OnboardingCity(id: -1, name: ''),
        ),
      );

      return match.name.isEmpty ? null : match.name;
    } catch (_) {
      return null;
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
    await prefs.setBool(_locationPromptSeenKey, true);
  }

  static Future<void> markNotificationPromptSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationPromptSeenKey, true);
  }

  static Future<void> complete({required String city}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedCityKey, city);
    await prefs.setBool(_completedKey, true);
  }
}
