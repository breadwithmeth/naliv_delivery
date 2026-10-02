import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's theme mode.
///
/// The product follows the OS by default, and both the sidebar and «Профиль - Переключение
/// свитчей» offer the manual override the design draws, so the choice has to live somewhere
/// outside a widget. Persisted, like the rest of the app's small preferences.
class ThemeController extends ChangeNotifier {
  static const String _key = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  /// Reads the stored choice; safe to call before `runApp` completes.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return;
    final restored = ThemeMode.values.where((mode) => mode.name == stored);
    if (restored.isEmpty) return;
    _mode = restored.first;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key, mode.name)) {
      throw StateError('Could not save theme mode');
    }
    _mode = mode;
    notifyListeners();
  }
}
