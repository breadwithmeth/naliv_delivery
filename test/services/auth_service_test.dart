import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _PresenceRemovalStore extends InMemorySharedPreferencesStore {
  _PresenceRemovalStore(super.values) : super.withData();

  @override
  Future<bool> remove(String key) async {
    final present = (await getAll()).containsKey(key);
    await super.remove(key);
    return present;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    SharedPreferences.setMockInitialValues({});
  });

  test('logout clears an opaque token with no expiry and is idempotent',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    final store =
        _PresenceRemovalStore({'flutter.auth_token': 'opaque-session'});
    SharedPreferencesStorePlatform.instance = store;

    await AuthService.clearToken();
    await AuthService.clearToken();

    final persisted = await store.getAll();
    expect(persisted.containsKey('flutter.auth_token'), isFalse);
    expect(persisted.containsKey('flutter.token_expiry'), isFalse);
    expect(await AuthService.getToken(), isNull);
  });
}
