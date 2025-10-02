import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naliv_delivery/utils/api.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _tokenExpiryKey = 'token_expiry';

  /// Проверяет валидность токена через API запрос
  static Future<bool> isTokenExpired() async {
    try {
      final userInfo = await ApiService.getFullInfo();
      return userInfo == null; // если null - значит токен невалидный
    } catch (e) {
      print('Error checking token validity: $e');
      return true;
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();

    // Декодируем JWT токен для получения времени истечения
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw Exception('Invalid token format');

      final payload = json
          .decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));

      // Получаем время истечения из токена (exp обычно в секундах)
      if (payload['exp'] != null) {
        final expiry =
            DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000);
        await prefs.setString(_tokenExpiryKey, expiry.toIso8601String());
      }
    } catch (e) {
      print('Error parsing token: $e');
    }

    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenExpiryKey);
  }
}
