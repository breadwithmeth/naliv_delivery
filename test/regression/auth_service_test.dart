import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/services/chat_api_service.dart';
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

  test('logout invalidates a live private chat and removes its saved capability',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({
      'auth_token': 'opaque-session',
      'chat_widget_session': jsonEncode({
        'identity': 'user-a',
        'id': 'private-session',
        'token': 'private-capability',
      }),
    });
    final rejected = <String>[];
    final service = ChatApiService(
      enableSocket: false,
      client: MockClient((request) async {
        rejected.add('${request.method} ${request.url}');
        throw StateError(rejected.last);
      }),
    );
    addTearDown(service.dispose);
    await service.init(identity: 'user-a');
    expect(service.hasSession, isTrue);
    await AuthService.clearToken();
    expect(service.hasSession, isFalse);
    expect(await service.sendMessage('Нельзя отправить после выхода'),
        isA<SendFailure>());
    expect((await SharedPreferences.getInstance()).getString('chat_widget_session'),
        isNull);
    expect(await ChatApiService.ownsSession('private-session', 'user-a'), isFalse);
    expect(rejected, isEmpty);
  });
}
