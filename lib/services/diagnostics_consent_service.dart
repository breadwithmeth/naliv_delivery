import 'package:shared_preferences/shared_preferences.dart';

class DiagnosticsConsentService {
  static const String _diagnosticsEnabledKey = 'diagnostics_enabled';

  static Future<bool?> getDiagnosticsConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_diagnosticsEnabledKey);
  }

  static Future<bool> isDiagnosticsEnabled() async {
    return (await getDiagnosticsConsent()) ?? false;
  }

  static Future<void> setDiagnosticsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_diagnosticsEnabledKey, enabled);
  }

  static Future<void> clearDiagnosticsConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_diagnosticsEnabledKey);
  }
}
