import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/product_view.dart';
import '../utils/cart_provider.dart';

/// Device-wide preference, independent of the account, theme and Reduce Motion.
class HapticPreference extends ChangeNotifier {
  static const _key = 'shopping_haptics_enabled';
  bool? _enabled;
  bool get allowsFeedback => _enabled == true && !loadFailed;
  bool? get enabled => _enabled;
  Future<void>? _loading;
  bool loadFailed = false;
  bool saving = false;

  Future<void> load() {
    if (_enabled != null) return Future.value();
    return _loading ??= _read().whenComplete(() => _loading = null);
  }

  Future<void> _read() async {
    try {
      _enabled = await SharedPreferencesAsync().getBool(_key) ?? true;
      loadFailed = false;
    } catch (_) {
      loadFailed = true; // Fail silent; the profile row offers a retry.
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool next) async {
    final previous = _enabled;
    if (saving || previous == null || previous == next) return;
    saving = true;
    if (!next) _enabled = false; // Opt-out beats pending confirmations.
    notifyListeners();
    try {
      await SharedPreferencesAsync().setBool(_key, next);
      _enabled = next;
    } catch (_) {
      _enabled = previous;
      rethrow;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}

/// System feedback for accepted shopping actions; never blocks the mutation.
abstract final class AppHaptics {
  static final preference = HapticPreference();

  static const _quantityClickInterval = Duration(milliseconds: 90);

  @visibleForTesting
  static Stopwatch quantityClickStopwatch = Stopwatch();

  /// Increments [item] synchronously and returns whether its quantity went
  /// from zero to positive. Feedback never blocks the cart action.
  static bool addCatalogStep(CartProvider cart, ProductView item) {
    final key = item.catalogKey;
    final before = cart.getCatalogQuantityForKey(key);
    cart.incrementCatalogItem(item.source);
    if (cart.getCatalogQuantityForKey(key) > before) {
      if (before == 0) {
        firstAdded();
        return true;
      }
      quantityChanged();
    }
    return false;
  }

  /// Decrements [item] and confirms only a decrease the cart accepted.
  static void removeCatalogStep(CartProvider cart, ProductView item) {
    final key = item.catalogKey;
    final before = cart.getCatalogQuantityForKey(key);
    cart.decrementCatalogItem(item.source);
    if (cart.getCatalogQuantityForKey(key) < before) quantityChanged();
  }

  /// Confirms a verified first addition without throttling.
  static void firstAdded() {
    if (_allowed) _send(HapticFeedback.lightImpact());
  }

  /// Only emitted quantity clicks start a cooldown. Faster edits remain
  /// synchronous and do not queue feedback.
  static void quantityChanged() {
    if (!_allowed) return;
    final stopwatch = quantityClickStopwatch;
    if (stopwatch.isRunning) {
      if (stopwatch.elapsedMicroseconds < _quantityClickInterval.inMicroseconds) {
        return;
      }
      stopwatch.reset();
    } else {
      stopwatch.start();
    }
    _send(HapticFeedback.selectionClick());
  }

  /// Confirms a distinct selection, independently of the cart stepper's clock.
  static void selectionConfirmed() {
    if (_allowed) _send(HapticFeedback.selectionClick());
  }

  static bool get _allowed => preference.allowsFeedback && supported &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  static bool get supported {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  static void _send(Future<void> feedback) {
    // The optional system channel already treats a missing implementation
    // as a no-op. A platform error also leaves the accepted action intact.
    unawaited(feedback.onError<PlatformException>((_, _) {}));
  }
}
