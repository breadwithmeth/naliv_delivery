import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Stores telemetry consent and keeps Sentry scopes aligned with the user's choice.
class TelemetryConsentService {
  static const String _consentKey = 'telemetry_consent_enabled';
  static bool _cachedConsent = false;
  static bool _hasStoredConsent = false;

  /// Loads consent from storage into cache. Call during app bootstrap.
  static Future<bool> loadConsent() async {
    final prefs = await SharedPreferences.getInstance();
    _hasStoredConsent = prefs.containsKey(_consentKey);
    _cachedConsent = prefs.getBool(_consentKey) ?? false;
    return _cachedConsent;
  }

  /// Returns the cached consent flag (fast path for beforeSend hooks).
  static bool get cachedConsent => _cachedConsent;

  /// Whether a consent value has been stored previously.
  static bool get hasStoredConsent => _hasStoredConsent;

  /// Updates consent and immediately refreshes Sentry scope to reflect the new state.
  static Future<void> setConsent(bool allowed) async {
    _cachedConsent = allowed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, allowed);

    await Sentry.configureScope((scope) async {
      if (!allowed) {
        // Clear any user info when consent is revoked.
        scope.setUser(null);
      }
    });
  }

  /// Convenience to populate user context when consent is granted.
  static Future<void> applyUserContext({String? id, String? username, String? email}) async {
    if (!_cachedConsent) {
      return;
    }
    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(id: id, username: username, email: email));
    });
  }

  /// Clears user context regardless of consent (e.g., on logout).
  static Future<void> clearUserContext() async {
    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }
}
