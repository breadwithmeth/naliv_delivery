import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Device-local internal text revisions; neither app versions nor legal approval dates.
class LegalAcceptance {
  static const preferenceKey = 'legal_accepted_revisions';
  static const current = <String, int>{'offer': 1, 'privacy': 1};
  static const assets = <String, String>{
    'offer': 'assets/agreements/offer.md',
    'privacy': 'assets/agreements/privacy.md',
  };

  static Future<Map<String, int>> read() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.get(preferenceKey);
    if (raw is! String) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded.values.any((value) => value is! int || value < 1)) {
        return {};
      }
      return {
        for (final entry in decoded.entries) entry.key: entry.value as int,
      };
    } on FormatException {
      return {};
    }
  }

  static bool isCurrent(Map<String, int> accepted) =>
      current.entries.every((entry) => accepted[entry.key] == entry.value);

  static Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (await prefs.setString(preferenceKey, jsonEncode(current))) return;
    } catch (_) {
      await prefs.reload();
      rethrow;
    }
    await prefs.reload();
    throw StateError('Could not persist legal acceptance');
  }
}
