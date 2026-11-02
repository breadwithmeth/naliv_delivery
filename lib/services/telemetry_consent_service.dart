import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Stores explicit telemetry consent and controls the reporting SDK lifecycle.
class TelemetryConsentService {
  static const String _consentKey = 'telemetry_consent_enabled';
  static bool _cachedConsent = false;
  static bool _hasStoredConsent = false;
  static Future<void> Function()? _startReporting;
  static Future<void>? _updatingSdk;

  /// Loads consent before reporting is initialized, defaulting to no collection.
  static Future<bool> loadConsent() async {
    final prefs = await SharedPreferences.getInstance();
    _hasStoredConsent = prefs.containsKey(_consentKey);
    _cachedConsent = prefs.getBool(_consentKey) ?? false;
    return _cachedConsent;
  }

  /// Installs the bootstrap callback and starts reporting only with consent.
  static Future<void> initialize({
    required Future<void> Function() startReporting,
  }) async {
    _startReporting = startReporting;
    await _synchronizeReporting();
  }

  /// Whether the current choice allows error reporting.
  static bool get cachedConsent => _cachedConsent;

  /// Whether a consent value has been stored previously.
  static bool get hasStoredConsent => _hasStoredConsent;

  /// Persists the choice and starts or stops reporting before completing.
  static Future<void> setConsent(bool allowed) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_consentKey, allowed)) {
      throw StateError('Could not save telemetry consent');
    }
    _cachedConsent = allowed;
    _hasStoredConsent = true;
    await _synchronizeReporting();
  }

  static Future<void> _synchronizeReporting() async {
    final pending = _updatingSdk;
    if (pending != null) {
      await pending;
      return _synchronizeReporting();
    }
    final update = _applyReportingState();
    _updatingSdk = update;
    try {
      await update;
    } finally {
      _updatingSdk = null;
    }
  }

  static Future<void> _applyReportingState() async {
    try {
      if (_cachedConsent && !Sentry.isEnabled) {
        await _startReporting?.call();
      }
    } finally {
      // A revocation can arrive while native SDK initialization is pending.
      if (!_cachedConsent) await Sentry.close();
    }
  }
}
