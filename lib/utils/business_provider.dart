import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider для управления выбранным магазином
class BusinessProvider with ChangeNotifier {
  Map<String, dynamic>? _selectedBusiness;
  static const _storageKey = 'selected_business';

  /// Получить текущий выбранный магазин
  Map<String, dynamic>? get selectedBusiness => _selectedBusiness;

  /// Получить название текущего магазина
  String? get selectedBusinessName => _selectedBusiness?['name'];

  /// Получить ID текущего магазина
  int? get selectedBusinessId {
    return _selectedBusiness?['id'] ??
        _selectedBusiness?['business_id'] ??
        _selectedBusiness?['businessId'];
  }

  /// Установить выбранный магазин
  Future<void> setSelectedBusiness(Map<String, dynamic>? business) async {
    _selectedBusiness = business;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (business == null) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(_storageKey, jsonEncode(business));
      }
    } catch (_) {}
  }

  /// Очистить выбранный магазин
  Future<void> clearSelectedBusiness() async {
    _selectedBusiness = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }

  Future<void> loadSavedBusiness() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _selectedBusiness = decoded;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Проверить, выбран ли магазин
  bool get hasSelectedBusiness => _selectedBusiness != null;
}
