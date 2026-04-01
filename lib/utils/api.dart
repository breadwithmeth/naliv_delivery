import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../model/item.dart' as ItemModel;

/// Класс для работы с API
class ApiService {
  static const String baseUrl = 'https://njt25.naliv.kz/api';
  // static const String baseUrl = 'http://192.168.100.63:3009/api';
  // static const String baseUrl = 'http://localhost:3000/api';
  static const JsonEncoder _prettyJsonEncoder = JsonEncoder.withIndent('  ');

  // Ключ для хранения токена аутентификации
  static const String _authTokenKey = 'auth_token';

  /// Безопасное преобразование в double
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  /// Получить понравившиеся пользователю товары
  /// GET /api/users/liked-items?business_id=&page=&limit=
  static Future<Map<String, dynamic>?> getLikedItems({
    required int businessId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_authTokenKey);
      if (token == null) {
        debugPrint('API getLikedItems: no auth token');
        return null;
      }

      final uri = Uri.parse('$baseUrl/users/liked-items').replace(
        queryParameters: {
          'business_id': businessId.toString(),
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          return jsonResponse['data'];
        } else {
          debugPrint('API getLikedItems error: ${jsonResponse['message']}');
          return null;
        }
      } else {
        debugPrint('HTTP Error getLikedItems: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Network Error getLikedItems: $e');
      return null;
    }
  }

  /// Поставить / снять лайк для товара
  /// POST /api/users/liked-items/toggle { item_id: number }
  static Future<bool?> toggleLikeItem(int itemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_authTokenKey);
      if (token == null) {
        debugPrint('API toggleLikeItem: no auth token');
        return null;
      }

      final uri = Uri.parse('$baseUrl/users/liked-items/toggle');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'item_id': itemId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          // Ожидаем, что в data будет новое значение is_liked или сам liked_item
          if (jsonResponse['data'] is Map && jsonResponse['data']['is_liked'] != null) {
            return jsonResponse['data']['is_liked'] == true;
          }
          // fallback: возможно success=true означает теперь лайк стоит
          return true;
        } else {
          debugPrint('API toggleLikeItem error: ${jsonResponse['message']}');
          return null;
        }
      } else {
        debugPrint('HTTP Error toggleLikeItem: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Network Error toggleLikeItem: $e');
      return null;
    }
  }

  /// Безопасное преобразование в int
  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  static Future<Map<String, dynamic>?> getBusinesses({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      // Формируем URL с query параметрами
      final uri = Uri.parse('$baseUrl/businesses').replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      // Выполняем GET запрос
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      // Проверяем статус ответа
      if (response.statusCode == 200) {
        // Декодируем JSON ответ
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        // Проверяем успешность запроса
        if (jsonResponse['success'] == true) {
          return jsonResponse['data'];
        } else {
          debugPrint('API Error: ${jsonResponse['message'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        debugPrint('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
        return null;
      }
    } catch (e) {
      debugPrint('Network Error: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> getAvailableCities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_authTokenKey);
      final uri = Uri.parse('$baseUrl/users/cities');

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          final cities = jsonResponse['data']?['cities'];
          if (cities is List) {
            return cities.whereType<Map>().map((city) => Map<String, dynamic>.from(city)).toList();
          }
          return const [];
        }

        debugPrint('API getAvailableCities error: ${jsonResponse['message'] ?? 'Unknown error'}');
        return null;
      }

      debugPrint('HTTP Error getAvailableCities: ${response.statusCode} - ${response.reasonPhrase}');
      return null;
    } catch (e) {
      debugPrint('Network Error getAvailableCities: $e');
      return null;
    }
  }

  /// Получить список всех бизнесов (без пагинации)
  ///
  /// Возвращает только массив бизнесов
  static Future<List<Map<String, dynamic>>?> getAllBusinesses() async {
    try {
      final data = await getBusinesses(page: 1, limit: 1000); // Получаем большое количество
      return data?['businesses']?.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error getting all businesses: $e');
      return null;
    }
  }

  /// Получить конкретный бизнес по ID
  ///
  /// [businessId] - ID бизнеса
  ///
  /// Возвращает данные о бизнесе
  static Future<Map<String, dynamic>?> getBusinessById(int businessId) async {
    try {
      final uri = Uri.parse('$baseUrl/businesses/$businessId');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          return jsonResponse['data'];
        } else {
          debugPrint('API Error: ${jsonResponse['message'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        debugPrint('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
        return null;
      }
    } catch (e) {
      debugPrint('Network Error: $e');
      return null;
    }
  }

  /// Поиск адресов по текстовому запросу
  ///
  /// [query] - строка поиска (например, "улица Пушкина 12")
  ///
  /// Возвращает список найденных адресов
  static Future<List<Map<String, dynamic>>?> searchAddressByText(
    String query, {
    String? city,
    String country = 'Казахстан',
  }) async {
    try {
      final searchQuery = _buildAddressSearchQuery(query, city: city, country: country);

      // Формируем URL с query параметрами
      final uri = Uri.parse('$baseUrl/addresses/search').replace(
        queryParameters: {
          'query': searchQuery,
        },
      );

      // Выполняем GET запрос
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      // Проверяем статус ответа
      if (response.statusCode == 200) {
        // Декодируем JSON ответ
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        // Проверяем успешность запроса
        if (jsonResponse['success'] == true) {
          // Extract features array or use empty list
          final List<dynamic> features = jsonResponse['data']['features'] ?? [];
          final List<Map<String, dynamic>> addresses = features.cast<Map<String, dynamic>>();
          return _filterAddressResults(addresses, city: city, country: country, requireCityMatch: true);
        } else {
          debugPrint('API Error: ${jsonResponse['message'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        debugPrint('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
        return null;
      }
    } catch (e) {
      debugPrint('Network Error: $e');
      return null;
    }
  }

  /// Поиск адреса по координатам (обратное геокодирование)
  ///
  /// [lat] - широта (от -90 до 90)
  /// [lon] - долгота (от -180 до 180)
  ///
  /// Возвращает список найденных адресов (обычно один)
  static Future<List<Map<String, dynamic>>?> searchAddressByCoordinates(
    double lat,
    double lon,
  ) async {
    try {
      // Проверяем корректность координат
      if (lat < -90 || lat > 90) {
        debugPrint('Invalid latitude: $lat. Must be between -90 and 90');
        return null;
      }
      if (lon < -180 || lon > 180) {
        debugPrint('Invalid longitude: $lon. Must be between -180 and 180');
        return null;
      }

      // Формируем URL с query параметрами
      final uri = Uri.parse('$baseUrl/addresses/reverse').replace(
        queryParameters: {
          'lat': lat.toString(),
          'lon': lon.toString(),
        },
      );

      // Выполняем GET запрос
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      // Проверяем статус ответа
      if (response.statusCode == 200) {
        // Декодируем JSON ответ
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (kDebugMode) {
          debugPrint('Reverse geocode request: lat=$lat, lon=$lon');
          debugPrint('Reverse geocode raw response:\n${_prettyJsonEncoder.convert(jsonResponse)}');
        }

        // Проверяем успешность запроса
        if (jsonResponse['success'] == true) {
          final dynamic data = jsonResponse['data'];
          if (data is List) {
            return data.cast<Map<String, dynamic>>();
          } else if (data is Map<String, dynamic>) {
            return <Map<String, dynamic>>[data];
          } else {
            return <Map<String, dynamic>>[];
          }
        } else {
          debugPrint('API Error: ${jsonResponse['message'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        debugPrint('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
        return null;
      }
    } catch (e) {
      debugPrint('Network Error: $e');
      return null;
    }
  }

  /// Универсальный метод поиска адресов
  ///
  /// Автоматически определяет тип поиска по переданным параметрам
  ///
  /// [query] - текст для поиска (если указан, то поиск по тексту)
  /// [lat] - широта для поиска по координатам
  /// [lon] - долгота для поиска по координатам
  ///
  /// Возвращает список найденных адресов
  static Future<List<Map<String, dynamic>>?> searchAddresses({
    String? query,
    double? lat,
    double? lon,
    String? city,
    String country = 'Казахстан',
  }) async {
    // Если указан текстовый запрос
    if (query != null && query.isNotEmpty) {
      return await searchAddressByText(query, city: city, country: country);
    }

    // Если указаны координаты
    if (lat != null && lon != null) {
      final results = await searchAddressByCoordinates(lat, lon);
      return _filterAddressResults(results, city: city, country: country, requireCityMatch: true);
    }

    debugPrint('Error: Either query or coordinates (lat, lon) must be provided');
    return null;
  }

  /// Извлекает человекочитаемое название адреса из разных форматов ответа API.
  static String? extractAddressLabel(
    Map<String, dynamic>? rawAddress, {
    double? lat,
    double? lon,
    String? preferredCity,
    String country = 'Казахстан',
  }) {
    if (rawAddress == null) return null;

    final formattedFromGeocoding = _formatAddressFromGeocoding(
      _extractGeocoding(rawAddress),
      preferredCity: preferredCity,
      country: country,
    );
    if (formattedFromGeocoding != null) {
      return formattedFromGeocoding;
    }

    final directLabel = _compactDirectAddressLabel(
      _firstNonEmptyString([
        rawAddress['display_name'],
        rawAddress['label'],
        rawAddress['name'],
        rawAddress['description'],
      ]),
      preferredCity: preferredCity,
      country: country,
    );
    if (directLabel != null) {
      return directLabel;
    }

    if (lat != null && lon != null) {
      return '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
    }

    return null;
  }

  static String? extractCityName(Map<String, dynamic>? rawAddress) {
    if (rawAddress == null) return null;

    final geocoding = _extractGeocoding(rawAddress);
    final city = _firstNonEmptyString([
      geocoding?['city'],
      geocoding?['town'],
      geocoding?['municipality'],
      geocoding?['county'],
      geocoding?['state'],
      rawAddress['city'],
      rawAddress['town'],
      rawAddress['municipality'],
      rawAddress['region'],
      rawAddress['state'],
    ]);

    final normalized = city?.trim();
    return (normalized == null || normalized.isEmpty) ? null : normalized;
  }

  static String formatAddressSummary(
    Map<String, dynamic>? address, {
    String emptyText = 'Адрес не указан',
  }) {
    if (address == null) return emptyText;

    String? base = extractAddressLabel(address);
    base ??= address['address']?.toString();

    final street = address['street']?.toString().trim();
    final house = address['house']?.toString().trim();
    if ((base == null || base.trim().isEmpty) && street != null && street.isNotEmpty) {
      base = house != null && house.isNotEmpty ? '$street, $house' : street;
    }

    final parts = <String>[(base == null || base.trim().isEmpty) ? emptyText : base.trim()];
    final details = <String>[];

    final entrance = address['entrance']?.toString().trim();
    if (entrance != null && entrance.isNotEmpty) {
      details.add('Под. $entrance');
    }

    final floor = address['floor']?.toString().trim();
    if (floor != null && floor.isNotEmpty) {
      details.add('Эт. $floor');
    }

    final apartment = address['apartment']?.toString().trim();
    if (apartment != null && apartment.isNotEmpty) {
      details.add('Кв. $apartment');
    }

    if (details.isNotEmpty) {
      parts.add(details.join(', '));
    }

    return parts.join(' • ');
  }

  static Map<String, dynamic>? _extractGeoFeature(Map<String, dynamic> rawAddress) {
    if (rawAddress['type'] == 'Feature') {
      return rawAddress;
    }

    final features = rawAddress['features'];
    if (features is List && features.isNotEmpty && features.first is Map<String, dynamic>) {
      return features.first as Map<String, dynamic>;
    }

    return null;
  }

  static Map<dynamic, dynamic>? _extractGeocoding(Map<String, dynamic>? rawAddress) {
    if (rawAddress == null) return null;

    final feature = _extractGeoFeature(rawAddress) ?? rawAddress;
    final properties = feature['properties'];
    if (properties is! Map) return null;

    final geocoding = properties['geocoding'];
    if (geocoding is! Map) return null;

    return geocoding;
  }

  static List<Map<String, dynamic>>? _filterAddressResults(
    List<Map<String, dynamic>>? results, {
    String? city,
    String country = 'Казахстан',
    bool requireCityMatch = false,
  }) {
    if (results == null) return null;

    final filtered = results.where((item) {
      if (!_isCountryMatch(item, country)) {
        return false;
      }

      if (city == null || city.trim().isEmpty) {
        return true;
      }

      final matchesCity = _isSelectedCityMatch(item, city);
      return requireCityMatch ? matchesCity : true;
    }).toList();

    if (city == null || city.trim().isEmpty) {
      return filtered;
    }

    filtered.sort((a, b) {
      final aMatchesCity = _isSelectedCityMatch(a, city);
      final bMatchesCity = _isSelectedCityMatch(b, city);
      if (aMatchesCity == bMatchesCity) return 0;
      return aMatchesCity ? -1 : 1;
    });

    return filtered;
  }

  static bool _isCountryMatch(Map<String, dynamic> item, String country) {
    final normalizedCountry = _normalizeAddressToken(country);
    final tokens = _extractAddressTokens(item);

    if (tokens.contains(normalizedCountry)) {
      return true;
    }

    return tokens.contains('kazakhstan') || tokens.contains('казахстан') || tokens.contains('қазақстан') || tokens.contains('kz');
  }

  static bool _isSelectedCityMatch(Map<String, dynamic> item, String city) {
    final normalizedCity = _normalizeAddressToken(city);
    if (normalizedCity.isEmpty) return true;

    final geocoding = _extractGeocoding(item);
    final geocodingCity = _normalizeAddressToken(_firstNonEmptyString([
      geocoding?['city'],
      geocoding?['town'],
      geocoding?['municipality'],
      geocoding?['county'],
      geocoding?['state'],
    ]));

    if (geocodingCity == normalizedCity) {
      return true;
    }

    return _extractAddressTokens(item).contains(normalizedCity);
  }

  static List<String> _extractAddressTokens(Map<String, dynamic> item) {
    final geocoding = _extractGeocoding(item);
    final rawTexts = [
      item['display_name'],
      item['label'],
      item['name'],
      item['description'],
      geocoding?['label'],
      geocoding?['country'],
      geocoding?['country_code'],
      geocoding?['city'],
      geocoding?['town'],
      geocoding?['municipality'],
      geocoding?['district'],
      geocoding?['state'],
      geocoding?['county'],
    ];

    final tokens = <String>[];
    for (final value in rawTexts) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) continue;
      tokens.addAll(text.split(',').map(_normalizeAddressToken).where((token) => token.isNotEmpty));
    }

    return tokens;
  }

  static String? _formatAddressFromGeocoding(
    Map<dynamic, dynamic>? geocoding, {
    String? preferredCity,
    String country = 'Казахстан',
  }) {
    if (geocoding == null) return null;

    final street = _firstNonEmptyString([
      geocoding['street'],
      geocoding['road'],
      geocoding['name'],
    ]);
    final houseNumber = _firstNonEmptyString([
      geocoding['housenumber'],
      geocoding['house_number'],
    ]);
    final district = _firstNonEmptyString([
      geocoding['district'],
      geocoding['borough'],
      geocoding['quarter'],
      geocoding['suburb'],
      geocoding['neighbourhood'],
    ]);
    final city = _firstNonEmptyString([
      geocoding['city'],
      geocoding['town'],
      geocoding['municipality'],
      geocoding['county'],
      geocoding['state'],
    ]);
    final geoCountry = _normalizeAddressToken(_firstNonEmptyString([
      geocoding['country'],
      geocoding['country_code'],
    ]));
    final normalizedPreferredCity = _normalizeAddressToken(preferredCity);
    final normalizedCity = _normalizeAddressToken(city);
    final normalizedCountry = _normalizeAddressToken(country);

    if (geoCountry.isNotEmpty &&
        geoCountry != normalizedCountry &&
        geoCountry != 'kazakhstan' &&
        geoCountry != 'казахстан' &&
        geoCountry != 'қазақстан' &&
        geoCountry != 'kz') {
      return null;
    }

    if (normalizedPreferredCity.isNotEmpty && normalizedCity.isNotEmpty && normalizedPreferredCity != normalizedCity) {
      return null;
    }

    final parts = <String>[];
    if (street != null && houseNumber != null) {
      parts.add('$street, $houseNumber');
    } else if (street != null) {
      parts.add(street);
    }

    if (district != null && _normalizeAddressToken(district) != normalizedCity) {
      parts.add(district);
    }

    if (city != null) {
      parts.add(city);
    }

    if (parts.isNotEmpty) {
      return parts.join(', ');
    }

    return _compactDirectAddressLabel(
      _firstNonEmptyString([
        geocoding['label'],
        geocoding['name'],
      ]),
      preferredCity: preferredCity,
      country: country,
    );
  }

  static String? _compactDirectAddressLabel(
    String? label, {
    String? preferredCity,
    String country = 'Казахстан',
  }) {
    final raw = label?.trim();
    if (raw == null || raw.isEmpty) return null;

    final normalizedPreferredCity = _normalizeAddressToken(preferredCity);
    final normalizedCountry = _normalizeAddressToken(country);
    final compactParts = <String>[];

    for (final part in raw.split(',')) {
      final trimmed = part.trim();
      final normalized = _normalizeAddressToken(trimmed);
      if (normalized.isEmpty) continue;
      if (normalized == normalizedCountry ||
          normalized == 'kazakhstan' ||
          normalized == 'казахстан' ||
          normalized == 'қазақстан' ||
          normalized == 'kz') {
        continue;
      }
      if (compactParts.any((existing) => _normalizeAddressToken(existing) == normalized)) {
        continue;
      }
      compactParts.add(trimmed);
    }

    if (normalizedPreferredCity.isNotEmpty && compactParts.every((part) => _normalizeAddressToken(part) != normalizedPreferredCity)) {
      compactParts.add(preferredCity!.trim());
    }

    if (compactParts.isEmpty) {
      return raw;
    }

    return compactParts.take(3).join(', ');
  }

  static String _normalizeAddressToken(dynamic value) {
    return value?.toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  static String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  /// Отправить одноразовый код на указанный номер телефона
  /// Возвращает true при успешной отправке
  static Future<bool> sendAuthCode(String phoneNumber) async {
    final uri = Uri.parse('$baseUrl/auth/send-code');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phoneNumber}),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse['success'] == true;
      }
    } catch (e) {
      debugPrint('Error sendAuthCode: $e');
    }
    return false;
  }

  /// Проверка одноразового кода для аутентификации
  /// Возвращает данные пользователя при успешной верификации или null
  static Future<Map<String, dynamic>?> verifyAuthCode(String phoneNumber, String oneTimeCode) async {
    final uri = Uri.parse('$baseUrl/auth/verify-code');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phoneNumber,
          'onetime_code': oneTimeCode,
        }),
      );
      if (response.statusCode == 202) {
        // Сохраняем токен при успешной верификации
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          final data = jsonResponse['data'] as Map<String, dynamic>;
          if (data.containsKey('token') && data['token'] is String) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_authTokenKey, data['token'] as String);
          }
          return jsonResponse['data'] as Map<String, dynamic>;
        } else {
          debugPrint('API verifyAuthCode error: ${jsonResponse['message']}');
        }
      } else {
        debugPrint('HTTP verifyAuthCode error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network verifyAuthCode error: $e');
    }
    return null;
  }

  /// Получить полную информацию о пользователе
  static Future<Map<String, dynamic>?> getFullInfo() async {
    // Получаем сохраненный токен для авторизации
    final token = await getAuthToken();
    if (token == null) {
      debugPrint('No auth token found');
      return null;
    }
    final uri = Uri.parse('$baseUrl/auth/full-info');
    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          return jsonResponse['data'] as Map<String, dynamic>;
        } else {
          debugPrint('API getFullInfo error: ${jsonResponse['message']}');
        }
      } else {
        debugPrint('HTTP getFullInfo error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network getFullInfo error: $e');
    }
    return null;
  }

  /// Получить сохраненный токен аутентификации
  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey);
  }

  /// Проверить, авторизован ли пользователь (наличие токена)
  static Future<bool> isUserLoggedIn() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// Создать новый заказ для авторизованного пользователя
  /// [body] - тело запроса в формате JSON
  /// Возвращает данные созданного заказа или null
  /// Создать новый заказ для авторизованного пользователя (без оплаты)
  /// [body] - тело запроса в формате JSON
  /// Возвращает карту с результатом операции
  static Future<Map<String, dynamic>> createUserOrder(
    Map<String, dynamic> body,
  ) async {
    final token = await getAuthToken();
    if (token == null) {
      debugPrint('API createUserOrder: auth token not found');
      return {'success': false, 'error': 'Требуется авторизация'};
    }
    final uri = Uri.parse('$baseUrl/orders/create-order-no-payment');
    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (response.statusCode == 201) {
        // Успешный ответ, возвращаем все тело ответа,
        // так как оно может содержать и data, и message
        return jsonResponse;
      } else {
        debugPrint('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
        debugPrint('Error body: ${response.body}');
        // Возвращаем ответ с ошибкой, чтобы UI мог ее обработать
        return {'success': false, 'error': jsonResponse['error'] ?? 'Ошибка сервера', 'statusCode': response.statusCode};
      }
    } catch (e) {
      debugPrint('Network Error: $e');
      return {'success': false, 'error': 'Ошибка сети или разбора ответа'};
    }
  }

  /// Поиск товаров по имени
  /// Поиск товаров по имени (сырой ответ API)
  /// Поддерживает пагинацию как на /categories/:id/items
  static Future<Map<String, dynamic>?> searchItems(
    String name, {
    int? businessId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'name': name,
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (businessId != null) {
        queryParams['business_id'] = businessId.toString();
      }

      final uri = Uri.parse('$baseUrl/items/search').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          return jsonResponse;
        } else {
          debugPrint('API searchItems error: ${jsonResponse['message']}');
        }
      } else {
        debugPrint('HTTP searchItems error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network searchItems error: $e');
    }
    return null;
  }

  /// Поиск товаров по имени (типизированная версия как categoryItemsTyped)
  /// Возвращает CategoryItemsResponse
  static Future<CategoryItemsResponse?> searchItemsTyped(
    String name, {
    int? businessId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final raw = await searchItems(
        name,
        businessId: businessId,
        page: page,
        limit: limit,
      );
      if (raw == null) return null;

      // Ожидаем структуру вида:
      // { success, data: { items: [...], pagination?: {...} } }
      final success = raw['success'] == true;
      final data = (raw['data'] as Map<String, dynamic>? ?? {});

      // 1) Items -> List<CategoryItem>
      final List<dynamic> itemsRaw = (data['items'] as List?) ?? const [];
      final items = itemsRaw.map((e) => CategoryItem.fromJson(e)).toList();

      // 2) Pagination -> PaginationInfo
      PaginationInfo pagination;
      if (data['pagination'] is Map) {
        pagination = PaginationInfo.fromJson(data['pagination'] as Map<String, dynamic>);
      } else {
        // fallback, если бэкенд не вернул pagination
        final total = ApiService._parseInt(data['total']) == 0 ? items.length : ApiService._parseInt(data['total']);
        final totalPages = (total / limit).ceil().clamp(1, 999999);
        pagination = PaginationInfo(
          page: page,
          limit: limit,
          total: total,
          totalPages: totalPages,
        );
      }

      // 3) «Виртуальная» категория: "Поиск: <name>"
      final categoryInfo = CategoryInfo(
        categoryId: 0,
        name: 'Поиск: $name',
        photo: null,
        img: null,
      );

      // 4) Бизнес (если задан фильтр)
      final businessInfo = BusinessInfo(
        businessId: businessId ?? 0,
        name: '', // реального имени нет в поиске — оставляем пустым
        address: null,
      );

      // 5) Прочие поля CategoryItemsData
      final categoriesIncluded = <int>[];
      final subcategoriesCount = 0;

      final typedData = CategoryItemsData(
        category: categoryInfo,
        business: businessInfo,
        items: items,
        pagination: pagination,
        categoriesIncluded: categoriesIncluded,
        subcategoriesCount: subcategoriesCount,
      );

      return CategoryItemsResponse(
        success: success,
        data: typedData,
        message: raw['message'],
      );
    } catch (e) {
      debugPrint('Error parsing searchItemsTyped: $e');
      return null;
    }
  }

  /// Поиск адресов по текстовому запросу (типизированная версия)
  ///
  /// [query] - строка поиска (например, "улица Пушкина 12")
  ///
  /// Возвращает список объектов Address
  static Future<List<Address>?> searchAddressesByText(
    String query, {
    String? city,
    String country = 'Казахстан',
  }) async {
    try {
      final addressesData = await searchAddressByText(query, city: city, country: country);
      if (addressesData != null) {
        return addressesData.map((json) => Address.fromJson(json)).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error parsing addresses: $e');
      return null;
    }
  }

  /// Поиск адреса по координатам (типизированная версия)
  ///
  /// [lat] - широта (от -90 до 90)
  /// [lon] - долгота (от -180 до 180)
  ///
  /// Возвращает список объектов Address
  static Future<List<Address>?> searchAddressesByCoordinates(
    double lat,
    double lon,
  ) async {
    try {
      final addressesData = await searchAddressByCoordinates(lat, lon);
      if (addressesData != null) {
        return addressesData.map((json) => Address.fromJson(json)).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error parsing addresses: $e');
      return null;
    }
  }

  /// Универсальный метод поиска адресов (типизированная версия)
  ///
  /// Автоматически определяет тип поиска по переданным параметрам
  ///
  /// [query] - текст для поиска (если указан, то поиск по тексту)
  /// [lat] - широта для поиска по координатам
  /// [lon] - долгота для поиска по координатам
  ///
  /// Возвращает список объектов Address
  static Future<List<Address>?> searchAddressesTyped({
    String? query,
    double? lat,
    double? lon,
    String? city,
    String country = 'Казахстан',
  }) async {
    // Если указан текстовый запрос
    if (query != null && query.isNotEmpty) {
      final addressesData = await searchAddressByText(query, city: city, country: country);
      if (addressesData != null) {
        return addressesData.map((json) => Address.fromJson(json)).toList();
      }
      return null;
    }

    // Если указаны координаты
    if (lat != null && lon != null) {
      final addressesData = await searchAddresses(
        lat: lat,
        lon: lon,
        city: city,
        country: country,
      );
      if (addressesData != null) {
        return addressesData.map((json) => Address.fromJson(json)).toList();
      }
      return null;
    }

    debugPrint('Error: Either query or coordinates (lat, lon) must be provided');
    return null;
  }

  static String _buildAddressSearchQuery(
    String query, {
    String? city,
    String country = 'Казахстан',
  }) {
    final parts = <String>[country.trim()];
    final cityPart = city?.trim();
    if (cityPart != null && cityPart.isNotEmpty) {
      parts.add(cityPart);
    }

    final queryPart = query.trim();
    if (queryPart.isNotEmpty) {
      parts.add(queryPart);
    }

    return parts.join(', ');
  }

  /// Получить активные акции
  ///
  /// [businessId] - ID бизнеса для фильтрации (опционально)
  /// [limit] - количество результатов (по умолчанию 50)
  /// [offset] - смещение для пагинации (по умолчанию 0)
  ///
  /// Возвращает данные об активных акциях с метаинформацией
  static Future<Map<String, dynamic>?> getActivePromotions({
    int? businessId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // Формируем query параметры
      Map<String, String> queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (businessId != null) {
        queryParams['business_id'] = businessId.toString();
      }

      // Формируем URL с query параметрами
      final uri = Uri.parse('$baseUrl/promotions/active').replace(
        queryParameters: queryParams,
      );

      // Выполняем GET запрос
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      // Проверяем статус ответа
      if (response.statusCode == 200) {
        // Декодируем JSON ответ
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        // Проверяем успешность запроса
        if (jsonResponse['success'] == true) {
          return jsonResponse;
        } else {
          debugPrint('API Error: ${jsonResponse['message'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        debugPrint('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
        return null;
      }
    } catch (e) {
      debugPrint('Network Error: $e');
      return null;
    }
  }

  /// Получить список активных акций (только массив акций)
  ///
  /// [businessId] - ID бизнеса для фильтрации (опционально)
  /// [limit] - количество результатов (по умолчанию 50)
  /// [offset] - смещение для пагинации (по умолчанию 0)
  ///
  /// Возвращает список акций
  static Future<List<Map<String, dynamic>>?> getActivePromotionsList({
    int? businessId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await getActivePromotions(
        businessId: businessId,
        limit: limit,
        offset: offset,
      );

      if (response != null && response['data'] != null) {
        return (response['data'] as List).cast<Map<String, dynamic>>();
      }

      return null;
    } catch (e) {
      debugPrint('Error getting active promotions list: $e');
      return null;
    }
  }

  /// Получить активные акции (типизированная версия)
  ///
  /// [businessId] - ID бизнеса для фильтрации (опционально)
  /// [limit] - количество результатов (по умолчанию 50)
  /// [offset] - смещение для пагинации (по умолчанию 0)
  ///
  /// Возвращает список объектов Promotion
  static Future<List<Promotion>?> getActivePromotionsTyped({
    int? businessId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final promotionsData = await getActivePromotionsList(
        businessId: businessId,
        limit: limit,
        offset: offset,
      );
      if (promotionsData != null) {
        return promotionsData.map((json) => Promotion.fromJson(json)).toList();
      }

      return null;
    } catch (e) {
      debugPrint('Error parsing promotions: $e');
      return null;
    }
  }

  /// Получить товары конкретной акции
  /// [promotionId] - ID акции
  /// [businessId] - ID магазина (опционально)
  /// [page] - страница для пагинации
  /// [limit] - количество записей на странице
  static Future<Map<String, dynamic>?> getPromotionItems({
    required int promotionId,
    int? businessId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (businessId != null) {
        queryParams['business_id'] = businessId.toString();
      }
      final uri = Uri.parse('$baseUrl/promotions/$promotionId/items').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          return jsonResponse;
        } else {
          debugPrint('API Error: ${jsonResponse['message'] ?? 'Unknown error'}');
        }
      } else {
        debugPrint('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('Network Error: $e');
    }
    return null;
  }

  /// Получить список товаров акции (массив данных)
  /// Получить список товаров акции (массив)
  static Future<List<Map<String, dynamic>>?> getPromotionItemsList({
    required int promotionId,
    int? businessId,
    int page = 1,
    int limit = 20,
  }) async {
    final result = await getPromotionItems(
      promotionId: promotionId,
      businessId: businessId,
      page: page,
      limit: limit,
    );
    if (result != null && result['data'] is Map<String, dynamic>) {
      final data = result['data'] as Map<String, dynamic>;
      if (data['items'] is List) {
        return (data['items'] as List).cast<Map<String, dynamic>>();
      }
    }
    return null;
  }

  /// Получить товары акции (типизированная версия)
  /// Получить товары акции (типизированная версия)
  static Future<List<ItemModel.Item>?> getPromotionItemsTyped({
    required int promotionId,
    int? businessId,
    int page = 1,
    int limit = 20,
  }) async {
    final list = await getPromotionItemsList(
      promotionId: promotionId,
      businessId: businessId,
      page: page,
      limit: limit,
    );
    if (list != null) {
      return list.map((json) => ItemModel.Item.fromJson(json)).toList();
    }
    return null;
  }

  /// Получить категории с подкатегориями
  ///
  /// [businessId] - ID бизнеса для фильтрации (опционально)
  ///
  /// Возвращает список категорий с вложенными подкатегориями
  static Future<List<Map<String, dynamic>>?> getCategories({
    int? businessId,
  }) async {
    try {
      // Формируем query параметры
      Map<String, String> queryParams = {};

      if (businessId != null) {
        queryParams['business_id'] = businessId.toString();
      }

      // Формируем URL с query параметрами
      final uri = Uri.parse('$baseUrl/categories').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      // Выполняем GET запрос
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      // Проверяем статус ответа
      if (response.statusCode == 200) {
        // Декодируем JSON ответ
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        // Проверяем успешность запроса
        if (jsonResponse['success'] == true) {
          final dynamic data = jsonResponse['data'];

          // Проверяем тип данных
          if (data is List) {
            // Если data это массив, возвращаем его
            return data.cast<Map<String, dynamic>>();
          } else if (data is Map<String, dynamic>) {
            // Если data это объект, ищем массив категорий внутри
            if (data.containsKey('categories') && data['categories'] is List) {
              final List<dynamic> categories = data['categories'];
              return categories.cast<Map<String, dynamic>>();
            } else {
              debugPrint('❌ В объекте data не найден массив categories: $data');
              return [];
            }
          } else {
            debugPrint('❌ Неожиданный тип данных: ${data.runtimeType}');
            return [];
          }
        } else {
          debugPrint('API Error: ${jsonResponse['message'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        debugPrint('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
        return null;
      }
    } catch (e) {
      debugPrint('Network Error: $e');
      return null;
    }
  }

  /// Получить категории (типизированная версия)
  ///
  /// [businessId] - ID бизнеса для фильтрации (опционально)
  ///
  /// Возвращает список объектов Category
  static Future<List<Category>?> getCategoriesTyped({
    int? businessId,
  }) async {
    try {
      final categoriesData = await getCategories(
        businessId: businessId,
      );

      if (categoriesData != null) {
        return categoriesData.map((json) => Category.fromJson(json)).toList();
      }

      return null;
    } catch (e) {
      debugPrint('Error parsing categories: $e');
      return null;
    }
  }

  /// Получить товары категории (включая подкатегории)
  ///
  /// [categoryId] - ID категории
  /// [businessId] - ID бизнеса (обязательный)
  /// [page] - номер страницы (по умолчанию 1)
  /// [limit] - количество товаров на странице (по умолчанию 20)
  ///
  /// Возвращает данные о товарах категории с метаинформацией
  static Future<Map<String, dynamic>?> getCategoryItems(
    int categoryId, {
    required int businessId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // Формируем query параметры
      Map<String, String> queryParams = {
        'business_id': businessId.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
      };

      // Формируем URL с query параметрами
      final uri = Uri.parse('$baseUrl/categories/$categoryId/items').replace(
        queryParameters: queryParams,
      );

      // Выполняем GET запрос
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      // Проверяем статус ответа
      if (response.statusCode == 200) {
        // Декодируем JSON ответ
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        // Проверяем успешность запроса
        if (jsonResponse['success'] == true) {
          return jsonResponse;
        } else {
          debugPrint('API Error: ${jsonResponse['message'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        debugPrint('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
        return null;
      }
    } catch (e) {
      debugPrint('Network Error: $e');
      return null;
    }
  }

  /// Получить товары категории (типизированная версия)
  ///
  /// [categoryId] - ID категории
  /// [businessId] - ID бизнеса (обязательный)
  /// [page] - номер страницы (по умолчанию 1)
  /// [limit] - количество товаров на странице (по умолчанию 20)
  ///
  /// Возвращает объект CategoryItemsResponse
  static Future<CategoryItemsResponse?> getCategoryItemsTyped(
    int categoryId, {
    required int businessId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final responseData = await getCategoryItems(
        categoryId,
        businessId: businessId,
        page: page,
        limit: limit,
      );

      if (responseData != null) {
        return CategoryItemsResponse.fromJson(responseData);
      }

      return null;
    } catch (e) {
      debugPrint('Error parsing category items: $e');
      return null;
    }
  }

  /// Получить суперкатегории с вложенными категориями
  ///
  /// Возвращает список суперкатегорий
  static Future<List<Map<String, dynamic>>?> getSuperCategories() async {
    final uri = Uri.parse('$baseUrl/categories/supercategories');
    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          final data = jsonResponse['data'] as Map<String, dynamic>;
          return (data['supercategories'] as List?)?.cast<Map<String, dynamic>>();
        }
        debugPrint('API getSuperCategories error: ${jsonResponse['message']}');
      } else {
        debugPrint('HTTP getSuperCategories error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network getSuperCategories error: $e');
    }
    return null;
  }

  /// Получить список сохранённых карт пользователя
  /// [source] - опциональный параметр для фильтрации по источнику
  /// Возвращает список карт или null
  static Future<List<Map<String, dynamic>>?> getUserCards({String? source}) async {
    final token = await getAuthToken();
    if (token == null) {
      debugPrint('API getUserCards: no auth token');
      return null;
    }
    var uri = Uri.parse('$baseUrl/user/cards');
    if (source != null) {
      uri = uri.replace(queryParameters: {'source': source});
    }

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] is Map) {
          final data = jsonResponse['data'] as Map<String, dynamic>;
          final cards = data['cards'] as List<dynamic>?;
          return cards?.map((e) => (e as Map).cast<String, dynamic>()).toList();
        }
      } else {
        debugPrint('HTTP Error getUserCards: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network Error getUserCards: $e');
    }
    return null;
  }

  /// Сгенерировать ссылку для добавления новой карты
  /// Возвращает URL для редиректа или null
  static Future<String?> generateAddCardLink() async {
    final token = await getAuthToken();
    if (token == null) {
      debugPrint('API generateAddCardLink: auth token not found');
      return null;
    }
    final uri = Uri.parse('$baseUrl/payments/generate-add-card-link');
    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] is Map) {
          final data = jsonResponse['data'] as Map<String, dynamic>;
          // API возвращает addCardLink, а не redirect_url
          return data['addCardLink'] as String?;
        } else {
          debugPrint('API generateAddCardLink error: ${jsonResponse['error']?['message']}');
        }
      } else {
        debugPrint('HTTP Error generateAddCardLink: ${response.statusCode}');
        debugPrint('Error body: ${response.body}');
      }
    } catch (e) {
      debugPrint('Network Error generateAddCardLink: $e');
    }
    return null;
  }

  /// Получить информацию о бонусах пользователя
  static Future<Map<String, dynamic>?> getUserBonuses() async {
    final token = await getAuthToken();
    if (token == null) {
      debugPrint('API getUserBonuses: no auth token');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bonuses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('HTTP Error getUserBonuses: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network Error getUserBonuses: $e');
    }
    return null;
  }

  /// Провести оплату заказа с использованием сохраненной карты
  /// [orderId] - ID заказа
  /// [cardId] - ID сохраненной карты
  /// Возвращает результат операции оплаты
  static Future<Map<String, dynamic>> payOrder(
    String orderId,
    String cardId,
  ) async {
    final token = await getAuthToken();
    if (token == null) {
      debugPrint('API payOrder: auth token not found');
      return {'success': false, 'error': 'Требуется авторизация'};
    }

    final uri = Uri.parse('$baseUrl/orders/$orderId/pay');
    try {
      final body = {
        'payment_type': 'card',
        'card_id': cardId,
      };
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (response.statusCode == 200) {
        return jsonResponse;
      } else {
        debugPrint('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
        debugPrint('Error body: ${response.body}');
        return {'success': false, 'error': jsonResponse['error'] ?? 'Ошибка оплаты', 'statusCode': response.statusCode};
      }
    } catch (e) {
      debugPrint('Network Error: $e');
      return {'success': false, 'error': 'Ошибка сети или разбора ответа'};
    }
  }

  static Future<Map<String, dynamic>?> getOrderDetails(int orderId) async {
    final token = await getAuthToken();
    if (token == null) {
      debugPrint('API getOrderDetails: no auth token');
      return null;
    }

    final uri = Uri.parse('$baseUrl/orders/$orderId');
    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          final data = jsonResponse['data'];
          final mappedData = _asStringKeyedMap(data);
          if (mappedData != null) {
            final order = _asStringKeyedMap(mappedData['order']);
            if (order != null) {
              return order;
            }
            return mappedData;
          }
        } else {
          debugPrint('API getOrderDetails error: ${jsonResponse['message']}');
        }
      } else {
        debugPrint('HTTP Error getOrderDetails: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network Error getOrderDetails: $e');
    }

    return null;
  }

  /// Получить активные заказы пользователя
  /// [businessId] - фильтр по ID бизнеса (опционально)
  /// [deliveryType] - фильтр по типу доставки (опционально)
  /// Возвращает список активных заказов
  static Future<Map<String, dynamic>?> getMyActiveOrders({
    int? businessId,
    String? deliveryType,
  }) async {
    final token = await getAuthToken();
    if (token == null) {
      debugPrint('API getMyActiveOrders: no auth token');
      return null;
    }

    var uri = Uri.parse('$baseUrl/orders/my-active-orders');

    // Добавляем query параметры если они есть
    Map<String, String> queryParams = {};
    if (businessId != null) {
      queryParams['business_id'] = businessId.toString();
    }
    if (deliveryType != null) {
      queryParams['delivery_type'] = deliveryType;
    }

    if (queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          return jsonResponse;
        } else {
          debugPrint('API getMyActiveOrders error: ${jsonResponse['message']}');
        }
      } else {
        debugPrint('HTTP Error getMyActiveOrders: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network Error getMyActiveOrders: $e');
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getMyActiveOrdersList({
    int? businessId,
    String? deliveryType,
  }) async {
    final response = await getMyActiveOrders(
      businessId: businessId,
      deliveryType: deliveryType,
    );
    return _extractOrderList(
      response,
      preferredKeys: const ['active_orders', 'orders'],
    ).where(_isRecentActiveOrder).toList();
  }

  static Future<Map<String, dynamic>?> getMyOrdersHistory({
    int? businessId,
    String? deliveryType,
    int page = 1,
    int? pageSize,
  }) async {
    final token = await getAuthToken();
    if (token == null) {
      debugPrint('API getMyOrdersHistory: no auth token');
      return null;
    }

    final queryParams = <String, String>{};
    if (businessId != null) {
      queryParams['business_id'] = businessId.toString();
    }
    if (deliveryType != null) {
      queryParams['delivery_type'] = deliveryType;
    }
    queryParams['page'] = page.toString();
    if (pageSize != null) {
      queryParams['per_page'] = pageSize.toString();
    }

    final uri = Uri.parse('$baseUrl/orders/my-orders').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          return jsonResponse;
        }

        debugPrint('API getMyOrdersHistory error: ${jsonResponse['message']}');
      } else {
        debugPrint('HTTP Error getMyOrdersHistory: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network Error getMyOrdersHistory: $e');
    }

    return null;
  }

  static Future<List<Map<String, dynamic>>> getMyOrdersHistoryList({
    int? businessId,
    String? deliveryType,
    int page = 1,
    int? pageSize,
  }) async {
    final response = await getMyOrdersHistory(
      businessId: businessId,
      deliveryType: deliveryType,
      page: page,
      pageSize: pageSize,
    );
    return _extractOrderList(
      response,
      preferredKeys: const [
        'orders',
        'history_orders',
        'order_history',
        'completed_orders',
      ],
    );
  }

  static List<Map<String, dynamic>> _extractOrderList(
    Map<String, dynamic>? response, {
    List<String> preferredKeys = const [],
  }) {
    if (response == null) return <Map<String, dynamic>>[];

    final data = response['data'];
    if (data is List) {
      return _asStringKeyedMapList(data);
    }

    if (data is! Map) return <Map<String, dynamic>>[];

    for (final key in preferredKeys) {
      final candidate = data[key];
      if (candidate is List) {
        return _asStringKeyedMapList(candidate);
      }
    }

    for (final entry in data.entries) {
      if (entry.value is List) {
        final list = entry.value as List<dynamic>;
        if (list.every((item) => item is Map)) {
          return _asStringKeyedMapList(list);
        }
      }
    }

    return <Map<String, dynamic>>[];
  }

  static bool _isRecentActiveOrder(Map<String, dynamic> order) {
    final rawTimestamp = order['log_timestamp']?.toString() ?? order['created_at']?.toString();
    if (rawTimestamp == null || rawTimestamp.isEmpty) return true;

    final parsed = DateTime.tryParse(rawTimestamp);
    if (parsed == null) return true;

    return DateTime.now().difference(parsed.toLocal()) < const Duration(hours: 2);
  }

  static Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, entryValue) => MapEntry(key.toString(), entryValue));
    }
    return null;
  }

  static List<Map<String, dynamic>> _asStringKeyedMapList(List<dynamic> source) {
    return source.map(_asStringKeyedMap).whereType<Map<String, dynamic>>().toList();
  }

  static Future<Map<String, dynamic>?> getCourierLocation(int orderId) async {
    final token = await getAuthToken();
    if (token == null) {
      debugPrint('API getCourierLocation: no auth token');
      return null;
    }

    final uri = Uri.parse('$baseUrl/orders/$orderId/courier-location');
    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          final data = jsonResponse['data'];
          if (data is Map<String, dynamic>) {
            return data;
          }
          if (data is Map) {
            return data.cast<String, dynamic>();
          }
          return <String, dynamic>{'value': data};
        }

        debugPrint('API getCourierLocation error: ${jsonResponse['message']}');
      } else {
        debugPrint('HTTP Error getCourierLocation: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network Error getCourierLocation: $e');
    }

    return null;
  }

  /// Рассчитать стоимость доставки по координатам
  /// [businessId] - ID бизнеса
  /// [lat] - широта (от -90 до 90)
  /// [lon] - долгота (от -180 до 180)
  /// Возвращает объект с данными доставки: delivery_type, distance, delivery_cost и т.д.
  static Future<Map<String, dynamic>?> calculateDeliveryByAddress({
    required int businessId,
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.parse('$baseUrl/delivery/calculate-by-address').replace(
      queryParameters: {
        'business_id': businessId.toString(),
        'lat': lat.toString(),
        'lon': lon.toString(),
      },
    );
    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] is Map<String, dynamic>) {
          return jsonResponse['data'] as Map<String, dynamic>;
        } else {
          debugPrint('API Error calculateDelivery: ${jsonResponse['message']}');
        }
      } else {
        debugPrint('HTTP Error calculateDelivery: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Network Error calculateDelivery: $e');
    }
    return null;
  }

  /// Отправить FCM токен на сервер
  /// [fcmToken] - Firebase Cloud Messaging токен
  /// Возвращает true при успешной отправке
  static Future<bool> updateFCMToken(String fcmToken) async {
    final token = await getAuthToken();
    if (token == null) {
      debugPrint('API updateFCMToken: no auth token');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'fcmToken': fcmToken}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          debugPrint('✅ FCM токен успешно отправлен на сервер');
          return true;
        } else {
          debugPrint('❌ Ошибка API updateFCMToken: ${jsonResponse['message']}');
        }
      } else {
        debugPrint('❌ HTTP Error updateFCMToken: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Network Error updateFCMToken: $e');
    }
    return false;
  }

  /// Удалить FCM токен с сервера (при выходе из аккаунта)
  /// Возвращает true при успешном удалении
  static Future<bool> removeFCMToken() async {
    final token = await getAuthToken();
    if (token == null) {
      debugPrint('API removeFCMToken: no auth token');
      return false;
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM токен успешно удален с сервера');
        return true;
      } else {
        debugPrint('❌ HTTP Error removeFCMToken: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Network Error removeFCMToken: $e');
    }
    return false;
  }
}

/// Модель для адреса
class Address {
  final String name;
  final AddressPoint point;
  final String description;
  final String kind;
  final String precision;
  final double? distance;

  Address({
    required this.name,
    required this.point,
    required this.description,
    required this.kind,
    required this.precision,
    this.distance,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      name: json['name'] ?? '',
      point: AddressPoint.fromJson(json['point'] ?? {}),
      description: json['description'] ?? '',
      kind: json['kind'] ?? '',
      precision: json['precision'] ?? '',
      distance: ApiService._parseDouble(json['distance']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'point': point.toJson(),
      'description': description,
      'kind': kind,
      'precision': precision,
      if (distance != null) 'distance': distance,
    };
  }

  @override
  String toString() {
    return 'Address(name: $name, description: $description, kind: $kind, precision: $precision${distance != null ? ', distance: ${distance}m' : ''})';
  }
}

/// Модель для координат адреса
class AddressPoint {
  final double lat;
  final double lon;

  AddressPoint({
    required this.lat,
    required this.lon,
  });

  factory AddressPoint.fromJson(Map<String, dynamic> json) {
    return AddressPoint(
      lat: ApiService._parseDouble(json['lat']) ?? 0.0,
      lon: ApiService._parseDouble(json['lon']) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
    };
  }

  @override
  String toString() {
    return 'AddressPoint(lat: $lat, lon: $lon)';
  }
}

/// Модель для бизнеса
class Business {
  final int businessId;
  final String name;
  final String? description;

  Business({
    required this.businessId,
    required this.name,
    this.description,
  });

  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      businessId: ApiService._parseInt(json['business_id']),
      name: json['name'] ?? '',
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'business_id': businessId,
      'name': name,
      if (description != null) 'description': description,
    };
  }

  @override
  String toString() {
    return 'Business(businessId: $businessId, name: $name)';
  }
}

/// Модель для акции
class Promotion {
  final int marketingPromotionId;
  final String? name;
  final DateTime startPromotionDate;
  final DateTime endPromotionDate;
  final int businessId;
  final String? cover;
  final int visible;
  final bool? isActive;
  final Business? business;
  final List<PromotionDetail> details;
  final List<PromotionStory>? stories;
  final int itemsCount;
  final int daysLeft;

  Promotion({
    required this.marketingPromotionId,
    this.name,
    required this.startPromotionDate,
    required this.endPromotionDate,
    required this.businessId,
    this.cover,
    required this.visible,
    this.isActive,
    this.business,
    required this.details,
    this.stories,
    required this.itemsCount,
    required this.daysLeft,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      marketingPromotionId: ApiService._parseInt(json['marketing_promotion_id']),
      name: json['name'],
      startPromotionDate: DateTime.parse(json['start_promotion_date']),
      endPromotionDate: DateTime.parse(json['end_promotion_date']),
      businessId: ApiService._parseInt(json['business_id']),
      cover: json['cover'],
      visible: ApiService._parseInt(json['visible']),
      isActive: json['is_active'],
      business: json['business'] != null ? Business.fromJson(json['business']) : null,
      details: (json['details'] as List? ?? []).map((detail) => PromotionDetail.fromJson(detail)).toList(),
      stories: json['stories'] != null ? (json['stories'] as List).map((story) => PromotionStory.fromJson(story)).toList() : null,
      itemsCount: ApiService._parseInt(json['items_count']),
      daysLeft: ApiService._parseInt(json['days_left']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'marketing_promotion_id': marketingPromotionId,
      if (name != null) 'name': name,
      'start_promotion_date': startPromotionDate.toIso8601String(),
      'end_promotion_date': endPromotionDate.toIso8601String(),
      'business_id': businessId,
      if (cover != null) 'cover': cover,
      'visible': visible,
      if (isActive != null) 'is_active': isActive,
      if (business != null) 'business': business!.toJson(),
      'details': details.map((detail) => detail.toJson()).toList(),
      if (stories != null) 'stories': stories!.map((story) => story.toJson()).toList(),
      'items_count': itemsCount,
      'days_left': daysLeft,
    };
  }

  @override
  String toString() {
    return 'Promotion(id: $marketingPromotionId, name: $name, daysLeft: $daysLeft)';
  }
}

/// Модель для деталей акции
class PromotionDetail {
  final int detailId;
  final String type; // "SUBTRACT" | "DISCOUNT"
  final int? baseAmount;
  final int? addAmount;
  final double? discount;
  final int itemId;
  final String name;
  final Item? item;

  PromotionDetail({
    required this.detailId,
    required this.type,
    this.baseAmount,
    this.addAmount,
    this.discount,
    required this.itemId,
    required this.name,
    this.item,
  });

  factory PromotionDetail.fromJson(Map<String, dynamic> json) {
    return PromotionDetail(
      detailId: ApiService._parseInt(json['detail_id']),
      type: json['type'] ?? '',
      baseAmount: json['base_amount'] != null ? ApiService._parseInt(json['base_amount']) : null,
      addAmount: json['add_amount'] != null ? ApiService._parseInt(json['add_amount']) : null,
      discount: ApiService._parseDouble(json['discount']),
      itemId: ApiService._parseInt(json['item_id']),
      name: json['name'] ?? '',
      item: json['item'] != null ? Item.fromJson(json['item']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'detail_id': detailId,
      'type': type,
      if (baseAmount != null) 'base_amount': baseAmount,
      if (addAmount != null) 'add_amount': addAmount,
      if (discount != null) 'discount': discount,
      'item_id': itemId,
      'name': name,
      if (item != null) 'item': item!.toJson(),
    };
  }

  @override
  String toString() {
    return 'PromotionDetail(id: $detailId, type: $type, name: $name)';
  }
}

/// Модель для истории акции
class PromotionStory {
  final int storyId;
  final String cover;
  final int marketingPromotionId;
  final String promo;

  PromotionStory({
    required this.storyId,
    required this.cover,
    required this.marketingPromotionId,
    required this.promo,
  });

  factory PromotionStory.fromJson(Map<String, dynamic> json) {
    return PromotionStory(
      storyId: ApiService._parseInt(json['story_id']),
      cover: json['cover'] ?? '',
      marketingPromotionId: ApiService._parseInt(json['marketing_promotion_id']),
      promo: json['promo'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'story_id': storyId,
      'cover': cover,
      'marketing_promotion_id': marketingPromotionId,
      'promo': promo,
    };
  }

  @override
  String toString() {
    return 'PromotionStory(id: $storyId, promo: $promo)';
  }
}

/// Модель для товара
class Item {
  final int itemId;
  final String name;
  final double price;
  final String? image;
  final String? description;
  final int categoryId;
  final int businessId;
  final int amount;
  final bool is_liked; // По умолчанию не лайкнут
  final List<ItemOption>? options;

  Item({
    required this.itemId,
    required this.name,
    required this.price,
    this.image,
    this.description,
    required this.categoryId,
    required this.is_liked,
    required this.businessId,
    required this.amount,
    this.options,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      itemId: ApiService._parseInt(json['item_id']),
      name: json['name'] ?? '',
      price: ApiService._parseDouble(json['price']) ?? 0.0,
      image: json['image'],
      description: json['description'],
      categoryId: ApiService._parseInt(json['category_id']),
      businessId: ApiService._parseInt(json['business_id']),
      amount: ApiService._parseInt(json['amount']),
      is_liked: json['is_liked'] ?? false, // По умолчанию не лайкнут
      options: json['options'] != null ? (json['options'] as List).map((option) => ItemOption.fromJson(option)).toList() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'name': name,
      'price': price,
      if (image != null) 'image': image,
      if (description != null) 'description': description,
      'category_id': categoryId,
      'business_id': businessId,
      'amount': amount,
      if (options != null) 'options': options!.map((option) => option.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'Item(id: $itemId, name: $name, price: $price)';
  }
}

/// Модель для опции товара
class ItemOption {
  final int optionId;
  final String name;
  final int required;
  final String selection; // "SINGLE" | "MULTIPLE"
  final List<ItemOptionItem> optionItems;

  ItemOption({
    required this.optionId,
    required this.name,
    required this.required,
    required this.selection,
    required this.optionItems,
  });

  factory ItemOption.fromJson(Map<String, dynamic> json) {
    return ItemOption(
      optionId: ApiService._parseInt(json['option_id']),
      name: json['name'] ?? '',
      required: ApiService._parseInt(json['required']),
      selection: json['selection'] ?? '',
      optionItems: (json['option_items'] as List? ?? []).map((item) => ItemOptionItem.fromJson(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'option_id': optionId,
      'name': name,
      'required': required,
      'selection': selection,
      'option_items': optionItems.map((item) => item.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'ItemOption(id: $optionId, name: $name, selection: $selection)';
  }
}

/// Модель для элемента опции товара
class ItemOptionItem {
  final int relationId;
  final int itemId;
  final String priceType; // "ADD" | "REPLACE"
  final String item_name;

  final double price;
  final int parentItemAmount;

  ItemOptionItem({
    required this.relationId,
    required this.itemId,
    required this.priceType,
    required this.item_name,
    required this.price,
    required this.parentItemAmount,
  });

  factory ItemOptionItem.fromJson(Map<String, dynamic> json) {
    return ItemOptionItem(
      relationId: ApiService._parseInt(json['relation_id']),
      itemId: ApiService._parseInt(json['item_id']),
      priceType: json['price_type'] ?? '',
      item_name: json['item_name'] ?? '',
      price: ApiService._parseDouble(json['price']) ?? 0.0,
      parentItemAmount: ApiService._parseInt(json['parent_item_amount']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'relation_id': relationId,
      'item_id': itemId,
      'price_type': priceType,
      'price': price,
      'parent_item_amount': parentItemAmount,
    };
  }

  @override
  String toString() {
    return 'ItemOptionItem(relationId: $relationId, itemId: $itemId, priceType: $priceType, price: $price)';
  }
}

/// Модель для категории
class Category {
  final int categoryId;
  final String name;
  final int? parentId;
  final int itemsCount;
  final List<Category> subcategories;

  Category({
    required this.categoryId,
    required this.name,
    this.parentId,
    required this.itemsCount,
    required this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      categoryId: ApiService._parseInt(json['category_id']),
      name: json['name'] ?? '',
      parentId: json['parent_id'] != null ? ApiService._parseInt(json['parent_id']) : null,
      itemsCount: ApiService._parseInt(json['items_count']),
      subcategories: (json['subcategories'] as List? ?? []).map((subcategory) => Category.fromJson(subcategory)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'name': name,
      if (parentId != null) 'parent_id': parentId,
      'items_count': itemsCount,
      'subcategories': subcategories.map((subcategory) => subcategory.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'Category(id: $categoryId, name: $name, itemsCount: $itemsCount, subcategories: ${subcategories.length})';
  }

  /// Проверяет, является ли категория родительской (имеет подкатегории)
  bool get hasSubcategories => subcategories.isNotEmpty;

  /// Проверяет, является ли категория подкатегорией
  bool get isSubcategory => parentId != null;

  /// Получает все подкатегории рекурсивно (включая подкатегории подкатегорий)
  List<Category> getAllSubcategories() {
    List<Category> allSubcategories = [];

    for (var subcategory in subcategories) {
      allSubcategories.add(subcategory);
      allSubcategories.addAll(subcategory.getAllSubcategories());
    }

    return allSubcategories;
  }

  /// Находит категорию по ID среди текущей категории и всех подкатегорий
  Category? findCategoryById(int id) {
    if (categoryId == id) {
      return this;
    }

    for (var subcategory in subcategories) {
      final found = subcategory.findCategoryById(id);
      if (found != null) {
        return found;
      }
    }

    return null;
  }

  /// Получает общее количество товаров включая подкатегории
  int getTotalItemsCount() {
    int total = itemsCount;
    for (var subcategory in subcategories) {
      total += subcategory.getTotalItemsCount();
    }
    return total;
  }
}

/// Модель для ответа API товаров категории
class CategoryItemsResponse {
  final bool success;
  final CategoryItemsData data;
  final String? message;

  CategoryItemsResponse({
    required this.success,
    required this.data,
    this.message,
  });

  factory CategoryItemsResponse.fromJson(Map<String, dynamic> json) {
    return CategoryItemsResponse(
      success: json['success'] ?? false,
      data: CategoryItemsData.fromJson(json['data'] ?? {}),
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data.toJson(),
      if (message != null) 'message': message,
    };
  }

  @override
  String toString() {
    return 'CategoryItemsResponse(success: $success, items: ${data.items.length})';
  }
}

/// Модель для данных товаров категории
class CategoryItemsData {
  final CategoryInfo category;
  final BusinessInfo business;
  final List<CategoryItem> items;
  final PaginationInfo pagination;
  final List<int> categoriesIncluded;
  final int subcategoriesCount;

  CategoryItemsData({
    required this.category,
    required this.business,
    required this.items,
    required this.pagination,
    required this.categoriesIncluded,
    required this.subcategoriesCount,
  });

  factory CategoryItemsData.fromJson(Map<String, dynamic> json) {
    return CategoryItemsData(
      category: CategoryInfo.fromJson(json['category'] ?? {}),
      business: BusinessInfo.fromJson(json['business'] ?? {}),
      items: (json['items'] as List? ?? []).map((item) => CategoryItem.fromJson(item)).toList(),
      pagination: PaginationInfo.fromJson(json['pagination'] ?? {}),
      categoriesIncluded: (json['categories_included'] as List? ?? []).map((id) => ApiService._parseInt(id)).toList(),
      subcategoriesCount: ApiService._parseInt(json['subcategories_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category.toJson(),
      'business': business.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'pagination': pagination.toJson(),
      'categories_included': categoriesIncluded,
      'subcategories_count': subcategoriesCount,
    };
  }

  @override
  String toString() {
    return 'CategoryItemsData(category: ${category.name}, items: ${items.length}, subcategories: $subcategoriesCount)';
  }
}

/// Модель для информации о категории
class CategoryInfo {
  final int categoryId;
  final String name;
  final String? photo;
  final String? img;

  CategoryInfo({
    required this.categoryId,
    required this.name,
    this.photo,
    this.img,
  });

  factory CategoryInfo.fromJson(Map<String, dynamic> json) {
    return CategoryInfo(
      categoryId: ApiService._parseInt(json['category_id']),
      name: json['name'] ?? '',
      photo: json['photo'],
      img: json['img'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'name': name,
      if (photo != null) 'photo': photo,
      if (img != null) 'img': img,
    };
  }

  @override
  String toString() {
    return 'CategoryInfo(id: $categoryId, name: $name)';
  }
}

/// Модель для информации о бизнесе
class BusinessInfo {
  final int businessId;
  final String name;
  final String? address;

  BusinessInfo({
    required this.businessId,
    required this.name,
    this.address,
  });

  factory BusinessInfo.fromJson(Map<String, dynamic> json) {
    return BusinessInfo(
      businessId: ApiService._parseInt(json['business_id']),
      name: json['name'] ?? '',
      address: json['address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'business_id': businessId,
      'name': name,
      if (address != null) 'address': address,
    };
  }

  @override
  String toString() {
    return 'BusinessInfo(id: $businessId, name: $name)';
  }
}

/// Модель для товара в категории
class CategoryItem {
  final int itemId;
  final String name;
  final String? description;
  final double price;
  final String? img;
  final String? code;
  final ItemCategory category;
  final int visible;
  final String? unit;
  final double? quantity;
  final double? stepQuantity;
  final List<CategoryItemOption>? options;
  final List<CategoryItemPromotion>? promotions;
  final int? amount; // добавлено: доступное количество / остаток

  CategoryItem({
    required this.itemId,
    required this.name,
    this.description,
    required this.price,
    this.img,
    this.code,
    required this.category,
    required this.visible,
    this.unit,
    this.quantity,
    this.stepQuantity,
    this.options,
    this.promotions,
    this.amount,
  });

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      itemId: ApiService._parseInt(json['item_id']),
      name: json['name'] ?? '',
      description: json['description'],
      price: ApiService._parseDouble(json['price']) ?? 0.0,
      img: json['img'],
      code: json['code'],
      category: ItemCategory.fromJson(json['category'] ?? {}),
      visible: ApiService._parseInt(json['visible']),
      unit: json['unit'] ?? json['unit_name'] ?? json['measure'],
      quantity: ApiService._parseDouble(json['quantity']) ?? ApiService._parseDouble(json['parent_item_amount']),
      stepQuantity: ApiService._parseDouble(json['quantity_step']) ??
          ApiService._parseDouble(json['step_quantity']) ??
          ApiService._parseDouble(json['parent_item_amount']),
      options: json['options'] != null ? (json['options'] as List).map((option) => CategoryItemOption.fromJson(option)).toList() : null,
      promotions:
          json['promotions'] != null ? (json['promotions'] as List).map((promotion) => CategoryItemPromotion.fromJson(promotion)).toList() : null,
      amount: json['amount'] != null ? ApiService._parseInt(json['amount']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'name': name,
      if (description != null) 'description': description,
      'price': price,
      if (img != null) 'img': img,
      if (code != null) 'code': code,
      'category': category.toJson(),
      'visible': visible,
      if (unit != null) 'unit': unit,
      if (quantity != null) 'quantity': quantity,
      if (stepQuantity != null) 'quantity_step': stepQuantity,
      if (amount != null) 'amount': amount,
      if (options != null) 'options': options!.map((option) => option.toJson()).toList(),
      if (promotions != null) 'promotions': promotions!.map((promo) => promo.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'CategoryItem(id: $itemId, name: $name, price: $price)';
  }

  /// Проверяет, виден ли товар
  bool get isVisible => visible == 1;

  /// Проверяет, есть ли опции у товара
  bool get hasOptions => options != null && options!.isNotEmpty;

  /// Проверяет, есть ли акции на товар
  bool get hasPromotions => promotions != null && promotions!.isNotEmpty;
}

/// Модель для категории товара
class ItemCategory {
  final int categoryId;
  final String name;
  final int? parentCategory;

  ItemCategory({
    required this.categoryId,
    required this.name,
    this.parentCategory,
  });

  factory ItemCategory.fromJson(Map<String, dynamic> json) {
    return ItemCategory(
      categoryId: ApiService._parseInt(json['category_id']),
      name: json['name'] ?? '',
      parentCategory: json['parent_category'] != null ? ApiService._parseInt(json['parent_category']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'name': name,
      if (parentCategory != null) 'parent_category': parentCategory,
    };
  }

  @override
  String toString() {
    return 'ItemCategory(id: $categoryId, name: $name)';
  }

  /// Проверяет, является ли категория подкатегорией
  bool get isSubcategory => parentCategory != null;
}

/// Модель для информации о пагинации
class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: ApiService._parseInt(json['page'], defaultValue: 1),
      limit: ApiService._parseInt(json['limit'], defaultValue: 20),
      total: ApiService._parseInt(json['total']),
      totalPages: ApiService._parseInt(json['totalPages']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'limit': limit,
      'total': total,
      'totalPages': totalPages,
    };
  }

  @override
  String toString() {
    return 'PaginationInfo(page: $page/$totalPages, total: $total)';
  }

  /// Проверяет, есть ли следующая страница
  bool get hasNextPage => page < totalPages;

  /// Проверяет, есть ли предыдущая страница
  bool get hasPreviousPage => page > 1;

  /// Получает номер следующей страницы
  int? get nextPage => hasNextPage ? page + 1 : null;

  /// Получает номер предыдущей страницы
  int? get previousPage => hasPreviousPage ? page - 1 : null;
}

/// Модель для опции товара в категории
class CategoryItemOption {
  final int optionId;
  final String name;
  final bool required;
  final String selection; // "single" | "multiple"
  final List<CategoryItemVariant> variants;

  CategoryItemOption({
    required this.optionId,
    required this.name,
    required this.required,
    required this.selection,
    required this.variants,
  });

  factory CategoryItemOption.fromJson(Map<String, dynamic> json) {
    return CategoryItemOption(
      optionId: ApiService._parseInt(json['option_id']),
      name: json['name'] ?? '',
      required: json['required'] == true || json['required'] == 1,
      selection: json['selection'] ?? 'single',
      variants: (json['variants'] as List? ?? []).map((variant) => CategoryItemVariant.fromJson(variant)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'option_id': optionId,
      'name': name,
      'required': required,
      'selection': selection,
      'variants': variants.map((variant) => variant.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'CategoryItemOption(id: $optionId, name: $name, required: $required, variants: ${variants.length})';
  }
}

/// Модель для варианта опции товара в категории
class CategoryItemVariant {
  final int relationId;
  final int itemId;
  final String priceType; // "add" | "replace"
  final String? item_name; // может быть null, если не указано
  final double price;
  final double parentItemAmount;

  CategoryItemVariant({
    required this.relationId,
    required this.itemId,
    required this.priceType,
    required this.item_name,
    required this.price,
    required this.parentItemAmount,
  });

  factory CategoryItemVariant.fromJson(Map<String, dynamic> json) {
    return CategoryItemVariant(
      relationId: ApiService._parseInt(json['relation_id']),
      itemId: ApiService._parseInt(json['item_id']),
      priceType: json['price_type'] ?? 'add',
      item_name: json['item_name'], // может быть null
      price: ApiService._parseDouble(json['price']) ?? 0.0,
      parentItemAmount: ApiService._parseDouble(json['parent_item_amount']) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'relation_id': relationId,
      'item_id': itemId,
      'price_type': priceType,
      'price': price,
      'parent_item_amount': parentItemAmount,
    };
  }

  @override
  String toString() {
    return 'CategoryItemVariant(relationId: $relationId, itemId: $itemId, priceType: $priceType, price: $price)';
  }
}

/// Модель для акции товара в категории
class CategoryItemPromotion {
  final int detailId;
  final String type; // "SUBTRACT" | "DISCOUNT"
  final int? baseAmount;
  final int? addAmount;
  final double? discount;
  final String name;

  CategoryItemPromotion({
    required this.detailId,
    required this.type,
    this.baseAmount,
    this.addAmount,
    this.discount,
    required this.name,
  });

  factory CategoryItemPromotion.fromJson(Map<String, dynamic> json) {
    return CategoryItemPromotion(
      detailId: ApiService._parseInt(json['detail_id']),
      type: json['type'] ?? '',
      baseAmount: json['base_amount'] != null ? ApiService._parseInt(json['base_amount']) : null,
      addAmount: json['add_amount'] != null ? ApiService._parseInt(json['add_amount']) : null,
      discount: ApiService._parseDouble(json['discount']),
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'detail_id': detailId,
      'type': type,
      if (baseAmount != null) 'base_amount': baseAmount,
      if (addAmount != null) 'add_amount': addAmount,
      if (discount != null) 'discount': discount,
      'name': name,
    };
  }

  @override
  String toString() {
    return 'CategoryItemPromotion(id: $detailId, type: $type, name: $name)';
  }

  /// Форматированное описание акции
  String get formattedDescription {
    if (type == 'SUBTRACT' && baseAmount != null && addAmount != null) {
      return '$baseAmount+$addAmount';
    }
    return name;
  }
}
