import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class OnboardingPreferences extends InMemorySharedPreferencesStore {
  OnboardingPreferences([Map<String, Object> values = const {}])
      : super.withData({
          for (final entry in values.entries)
            'flutter.${entry.key}': entry.value,
        });

  final rejectedKeys = <String>{};
  String? heldKey;
  Completer<bool>? heldWrite;

  void install() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = this;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final plainKey = key.substring('flutter.'.length);
    if (rejectedKeys.contains(plainKey)) return false;
    if (plainKey == heldKey && heldWrite != null) {
      if (!await heldWrite!.future) return false;
    }
    return super.setValue(valueType, key, value);
  }
}
