import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The 21+ acknowledgment belongs to the installation, not the account or
/// legal consent.
final class AgeConfirmationSession extends ChangeNotifier {
  AgeConfirmationSession()
      : _persistent = true,
        _isReady = false,
        _isConfirmed = false {
    unawaited(_restore());
  }

  /// Creates a fixture session that neither reads nor writes the installation.
  AgeConfirmationSession.inMemory({bool confirmed = false})
      : _persistent = false,
        _isReady = true,
        _isConfirmed = confirmed;

  static const _preferenceKey = 'age_confirmation_21_plus';
  static const _storageTimeout = Duration(seconds: 5);

  final bool _persistent;
  bool _isReady;
  bool _isConfirmed;
  bool _presenting = false;
  bool _disposed = false;

  bool get isReady => _isReady;
  bool get isConfirmed => _isConfirmed;

  static Future<SharedPreferences> _preferences() =>
      SharedPreferences.getInstance().timeout(_storageTimeout);

  Future<void> _restore() async {
    var confirmed = false;
    try {
      final prefs = await _preferences();
      // A failed setBool can leave an optimistic value in the shared cache.
      await prefs.reload().timeout(_storageTimeout);
      confirmed = prefs.get(_preferenceKey) == true;
    } catch (error) {
      debugPrint('Could not read age confirmation: $error');
    }
    if (_disposed) return;
    _isConfirmed = confirmed;
    _isReady = true;
    notifyListeners();
  }

  /// Runs one gate at a time, releasing navigation only after the presenter closes.
  Future<void> requestConfirmation(
    Future<void> Function(Future<bool> Function() save) present,
  ) async {
    if (!_isReady || _isConfirmed || _presenting || _disposed) return;
    _presenting = true;
    Future<bool>? write;

    Future<bool> save() async {
      final pending = write ??= _save();
      final saved = await pending;
      if (!saved && identical(write, pending)) write = null;
      return saved;
    }

    try {
      await present(save);
    } finally {
      // A route replacement can close the dialog while the explicit tap is saving.
      final pending = write;
      final confirmed = pending != null && await pending;
      _presenting = false;
      if (!_disposed) {
        _isConfirmed = confirmed;
        notifyListeners();
      }
    }
  }

  Future<bool> _save() async {
    if (!_persistent) return true;
    try {
      final prefs = await _preferences();
      return await prefs.setBool(_preferenceKey, true).timeout(_storageTimeout);
    } catch (error) {
      debugPrint('Could not save age confirmation: $error');
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
