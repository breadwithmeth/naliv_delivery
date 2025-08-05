import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Сервис для работы с сохраненными адресами пользователя
class AddressStorageService {
  static const String _selectedAddressKey = 'selected_address';
  static const String _addressHistoryKey = 'address_history';
  static const String _isFirstLaunchKey = 'is_first_launch';

  /// Проверяет, является ли это первым запуском приложения
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstLaunchKey) ?? true;
  }

  /// Отмечает, что приложение уже запускалось
  static Future<void> markAsLaunched() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstLaunchKey, false);
  }

  /// Проверяет, есть ли сохраненный адрес
  static Future<bool> hasSelectedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final addressJson = prefs.getString(_selectedAddressKey);
    final hasAddress = addressJson != null && addressJson.isNotEmpty;

    print('🔍 AddressStorageService.hasSelectedAddress():');
    print('   addressJson: $addressJson');
    print('   hasAddress: $hasAddress');

    return hasAddress;
  }

  /// Получает сохраненный адрес
  static Future<Map<String, dynamic>?> getSelectedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final addressJson = prefs.getString(_selectedAddressKey);

    if (addressJson != null && addressJson.isNotEmpty) {
      try {
        return json.decode(addressJson);
      } catch (e) {
        print('Ошибка при декодировании адреса: $e');
        return null;
      }
    }
    return null;
  }

  // StreamController для уведомления об изменении выбранного адреса
  static final StreamController<Map<String, dynamic>?>
      _selectedAddressController =
      StreamController<Map<String, dynamic>?>.broadcast();

  /// Поток изменений выбранного адреса
  static Stream<Map<String, dynamic>?> get selectedAddressStream =>
      _selectedAddressController.stream;

  /// Сохраняет выбранный адрес
  static Future<bool> saveSelectedAddress(Map<String, dynamic> address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addressJson = json.encode(address);
      final result = await prefs.setString(_selectedAddressKey, addressJson);
      // уведомляем слушателей
      _selectedAddressController.add(address);
      return result;
    } catch (e) {
      print('Ошибка при сохранении адреса: $e');
      return false;
    }
  }

  /// Удаляет сохраненный адрес
  static Future<bool> removeSelectedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final result = await prefs.remove(_selectedAddressKey);
    // уведомляем слушателей о сбросе
    _selectedAddressController.add(null);
    return result;
  }

  /// Получает историю поиска адресов
  static Future<List<Map<String, dynamic>>> getAddressHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_addressHistoryKey) ?? [];

    try {
      return historyJson
          .map((item) => json.decode(item) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Ошибка при получении истории адресов: $e');
      return [];
    }
  }

  /// Добавляет адрес в историю поиска
  static Future<bool> addToAddressHistory(Map<String, dynamic> address) async {
    try {
      final history = await getAddressHistory();

      // Проверяем, нет ли уже такого адреса в истории
      final existingIndex = history.indexWhere((item) =>
          item['name'] == address['name'] &&
          item['point']['lat'] == address['point']['lat'] &&
          item['point']['lon'] == address['point']['lon']);

      if (existingIndex != -1) {
        // Удаляем существующий и добавляем в начало
        history.removeAt(existingIndex);
      }

      // Добавляем в начало списка
      history.insert(0, address);

      // Ограничиваем историю 10 последними адресами
      if (history.length > 10) {
        history.removeRange(10, history.length);
      }

      final prefs = await SharedPreferences.getInstance();
      final historyJson = history.map((item) => json.encode(item)).toList();
      return await prefs.setStringList(_addressHistoryKey, historyJson);
    } catch (e) {
      print('Ошибка при добавлении адреса в историю: $e');
      return false;
    }
  }

  /// Очищает историю адресов
  static Future<bool> clearAddressHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove(_addressHistoryKey);
  }

  /// Полная очистка всех данных адресов
  static Future<void> clearAllAddressData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedAddressKey);
    await prefs.remove(_addressHistoryKey);
  }
}
