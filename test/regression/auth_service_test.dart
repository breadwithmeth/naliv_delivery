import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/services/chat_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../support/preferences_store.dart';

class _PresenceRemovalStore extends InMemorySharedPreferencesStore {
  _PresenceRemovalStore(super.values) : super.withData();

  @override
  Future<bool> remove(String key) async {
    final present = (await getAll()).containsKey(key);
    await super.remove(key);
    return present;
  }
}

class _RefusingAuthStore extends InMemorySharedPreferencesStore {
  _RefusingAuthStore(super.values) : super.withData();

  bool refuseTokenWrite = false;
  bool refuseTokenRemoval = false;
  bool throwTokenWrite = false;
  bool refuseExpiryWrite = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.token_expiry' && refuseExpiryWrite) return false;
    if (key == 'flutter.auth_token' && throwTokenWrite) {
      throw StateError('fixture storage exception');
    }
    if (key == 'flutter.auth_token' && refuseTokenWrite) return false;
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (key == 'flutter.auth_token' && refuseTokenRemoval) return false;
    return super.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    SharedPreferences.setMockInitialValues({});
  });

  for (final owner in ['first-caller', 'second-caller']) {
    testWidgets('credential saves complete in independent widget zone $owner',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      var completed = false;
      Object? failure;
      final saving = AuthService.saveToken('zone-session-$owner');
      unawaited(saving.then<void>((_) {
        completed = true;
      }, onError: (Object error) {
        failure = error;
        completed = true;
      }));
      for (var turn = 0; turn < 100 && !completed; turn++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(completed, isTrue,
          reason:
              'Credential queue retained work from a completed caller zone');
      expect(failure, isNull);
      await saving;
      expect(await AuthService.getToken(), 'zone-session-$owner');
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  test('pending credential persistence cannot grant a captured session',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    final store = OnboardingPreferences()
      ..heldKey = 'auth_token'
      ..heldWrite = Completer<bool>();
    store.install();
    final saving = AuthService.saveToken('pending-authentication');
    for (var turn = 0; turn < 8; turn++) {
      await Future<void>.value();
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), 'pending-authentication');
    final sessionBeforeAcknowledgement = await AuthService.captureSession();
    final tokenBeforeAcknowledgement = await AuthService.getToken();
    store.heldWrite!.complete(true);
    await saving;

    expect(sessionBeforeAcknowledgement, isNull);
    expect(tokenBeforeAcknowledgement, isNull);
    expect(
        (await AuthService.captureSession())?.token, 'pending-authentication');
    expect(
        (await store.getAll())['flutter.auth_token'], 'pending-authentication');
  });

  test('failed publication with refused rollback never grants persisted token',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    final store = _RefusingAuthStore({})
      ..refuseExpiryWrite = true
      ..refuseTokenRemoval = true;
    SharedPreferencesStorePlatform.instance = store;
    final token = 'e30.${base64Url.encode(utf8.encode(jsonEncode({
              'sub': 'failed-owner',
              'exp': 4102444800
            }))).replaceAll('=', '')}.fixture';
    await expectLater(AuthService.saveToken(token), throwsStateError);
    expect((await store.getAll())['flutter.auth_token'], token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    expect(await AuthService.getToken(), isNull);
    expect(await AuthService.captureSession(), isNull);
    expect(AuthService.currentIdentity, isNull);
  });

  test('captured sessions survive identity binding but not same-token login',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    await AuthService.saveToken('stable-session');
    final session = await AuthService.captureSession();
    expect(session, isNotNull);
    final revision = AuthService.credentialRevision;
    await AuthService.bindAuthenticatedIdentity('user-a');
    expect(AuthService.credentialRevision, revision);
    expect(session!.isCurrent, isTrue);
    await AuthService.saveToken('stable-session');
    expect(AuthService.credentialRevision, greaterThan(revision));
    expect(session.isCurrent, isFalse);
    final replacement = await AuthService.captureSession();
    final ending = AuthService.clearToken();
    expect(replacement!.isCurrent, isFalse);
    expect(AuthService.isEndingSession, isTrue);
    expect(await AuthService.captureSession(), isNull);
    await ending;
  });

  test('logout waits for local writes without resurrecting token or expiry',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    final store = OnboardingPreferences()
      ..heldKey = 'auth_token'
      ..heldWrite = Completer<bool>();
    store.install();
    final token = 'e30.${base64Url.encode(utf8.encode(jsonEncode({
              'sub': 'user-a',
              'exp': 4102444800
            }))).replaceAll('=', '')}.fixture';
    final saving = AuthService.saveToken(token);
    final rejectedSave = expectLater(saving, throwsStateError);
    for (var turn = 0; turn < 8; turn++) {
      await Future<void>.value();
    }
    final ending = AuthService.clearToken();
    expect(await AuthService.getToken(), isNull);
    store.heldWrite!.complete(true);
    await rejectedSave;
    await ending;

    expect(await AuthService.captureSession(), isNull);
    final persisted = await store.getAll();
    expect(persisted.containsKey('flutter.auth_token'), isFalse);
    expect(persisted.containsKey('flutter.token_expiry'), isFalse);
  });

  test('credential storage exception cannot leave an optimistic login cached',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    final store = _RefusingAuthStore({})..throwTokenWrite = true;
    SharedPreferencesStorePlatform.instance = store;
    await expectLater(
        AuthService.saveToken('failed-session'), throwsStateError);
    expect(await AuthService.getToken(), isNull);
    expect(await AuthService.captureSession(), isNull);
    expect((await store.getAll()).containsKey('flutter.auth_token'), isFalse);
  });

  test('refused credential persistence reports failure instead of local login',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    final store = _RefusingAuthStore({})..refuseTokenWrite = true;
    SharedPreferencesStorePlatform.instance = store;

    await expectLater(
      AuthService.saveToken('rejected-session'),
      throwsStateError,
    );

    expect((await store.getAll()).containsKey('flutter.auth_token'), isFalse);
    expect(await AuthService.getToken(), isNull);
  });

  test(
      'refused local logout removal reports failure and suspends private state',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    final store = _RefusingAuthStore({
      'flutter.auth_token': 'retained-session',
    })
      ..refuseTokenRemoval = true;
    SharedPreferencesStorePlatform.instance = store;
    await AuthService.bindAuthenticatedIdentity('user-a');

    await expectLater(AuthService.clearToken(), throwsStateError);

    expect(AuthService.currentIdentity, isNull);
    expect(AuthService.isEndingSession, isFalse);
    expect((await store.getAll())['flutter.auth_token'], 'retained-session');
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(await AuthService.getToken(), isNull);
    expect(await AuthService.captureSession(), isNull);
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

  test(
      'logout invalidates a live private chat and removes its saved capability',
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
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('chat_widget_session'), isNull);
    await prefs.reload();
    expect(prefs.getString('chat_widget_session'), isNull);
    expect(
        await ChatApiService.ownsSession('private-session', 'user-a'), isFalse);
    expect(rejected, isEmpty);
  });
}
