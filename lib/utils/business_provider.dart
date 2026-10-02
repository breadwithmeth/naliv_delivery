import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider для управления выбранным магазином
class BusinessProvider with ChangeNotifier {
  Map<String, dynamic>? _selectedBusiness;
  static const _storageKey = 'selected_business';

  Future<void> _pending = Future<void>.value();
  bool _disposed = false;

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

  /// Persists the store before publishing it; a rejected write returns `false`.
  Future<bool> setSelectedBusiness(Map<String, dynamic>? business) {
    final next = business == null ? null : Map<String, dynamic>.of(business);
    return _enqueue(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = next == null
            ? !prefs.containsKey(_storageKey) || await prefs.remove(_storageKey)
            : await prefs.setString(_storageKey, json.encode(next));
        if (!saved) {
          await prefs.reload();
          return false;
        }
        _selectedBusiness = next;
        if (!_disposed) notifyListeners();
        return true;
      } catch (error) {
        try {
          await (await SharedPreferences.getInstance()).reload();
        } catch (_) {
          // The failed operation must not publish an optimistic cache value.
        }
        debugPrint('Не удалось сохранить выбранный магазин: $error');
        return false;
      }
    });
  }

  /// Clears the persisted store without publishing a rejected removal.
  Future<bool> clearSelectedBusiness() => setSelectedBusiness(null);

  Future<void> loadSavedBusiness() => _enqueue(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final saved = prefs.getString(_storageKey);
          _selectedBusiness =
              saved == null ? null : json.decode(saved) as Map<String, dynamic>;
          if (!_disposed) notifyListeners();
        } catch (error) {
          debugPrint('Не удалось загрузить выбранный магазин: $error');
        }
      });

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Проверить, выбран ли магазин
  bool get hasSelectedBusiness => _selectedBusiness != null;
}
