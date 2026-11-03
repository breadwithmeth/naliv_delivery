import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import 'package:naliv_delivery/services/push_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/native_push_fixture.dart';

String _token(String identity) =>
    'e30.${base64Url.encode(utf8.encode(jsonEncode({
              'sub': identity
            }))).replaceAll('=', '')}.fixture';

class _PushBackendFixture {
  final unexpected = <String>[];
  final upserts = <({String? authorization, String? identity})>[];
  final deletions = <String?>[];
  Completer<http.Response>? heldUpsert;
  final effects = <String>[];
  late final client = MockClient((request) async {
    if (request.url.origin == 'https://njt25.naliv.kz' &&
        request.url.queryParameters.isEmpty &&
        request.url.fragment.isEmpty) {
      if (request.method == 'POST' &&
          request.url.path == '/api/users/onesignal-subscription') {
        final body = jsonDecode(request.body);
        if (body is Map &&
            body.keys.toSet().difference({
              'subscriptionId',
              'onesignalId',
              'externalId',
              'deviceId',
              'deviceType',
              'permissionGranted',
              'optedIn',
            }).isEmpty &&
            body.length == 7 &&
            body['subscriptionId'] == 'fixture-subscription' &&
            body['deviceId'] == 'fixture-device' &&
            body['deviceType'] == 'android' &&
            body['permissionGranted'] == true &&
            body['optedIn'] == true) {
          upserts.add((
            authorization: request.headers['authorization'],
            identity: body['externalId'] as String?,
          ));
          effects.add('upsert:${body['externalId']}');
          if (heldUpsert != null) return heldUpsert!.future;
          return http.Response('{"success":true}', 200);
        }
      }
      if (request.method == 'DELETE' &&
          request.url.path ==
              '/api/users/onesignal-subscription/fixture-subscription' &&
          request.body.isEmpty) {
        deletions.add(request.headers['authorization']);
        effects.add('delete:${request.headers['authorization']}');
        return http.Response('', 204);
      }
    }
    unexpected.add('${request.method} ${request.url} ${request.body}');
    throw StateError(unexpected.last);
  });
}

NotificationService _notifications({PushProvider? provider}) {
  final service = NotificationService(
    provider: provider,
    navigatorKey: GlobalKey<NavigatorState>(),
    resolveIdentity: AuthService.refreshIdentity,
    chatServiceFactory: () => throw StateError('No chat route expected'),
  );
  addTearDown(service.dispose);
  return service;
}

Future<void> _flush(WidgetTester tester) async {
  for (var turn = 0; turn < 8; turn++) {
    await tester.pump();
  }
}

Future<void> _expectCompletion<T>(
  WidgetTester tester,
  Future<T> future,
  String phase, {
  String Function()? details,
}) async {
  var completed = false;
  Object? failure;
  StackTrace? trace;
  unawaited(future.then<void>((_) {
    completed = true;
  }, onError: (Object error, StackTrace stack) {
    failure = error;
    trace = stack;
    completed = true;
  }));
  for (var turn = 0; turn < 100 && !completed; turn++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(completed, isTrue,
      reason: 'Pending phase: $phase. ${details?.call() ?? ''}');
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
}

class _ControlledProvider extends InMemoryPushProvider {
  _ControlledProvider() : super(deviceType: 'android');

  int starts = 0;
  int disposals = 0;
  bool failStartup = false;
  Completer<void>? startup;
  VoidCallback? changed;
  int loginAttempts = 0;
  int rejectedLogins = 0;

  @override
  Future<void> login(String identity) async {
    loginAttempts++;
    if (rejectedLogins > 0) {
      rejectedLogins--;
      throw StateError('fixture login refused once');
    }
    await super.login(identity);
  }

  @override
  Future<void> initialize({
    required VoidCallback onChange,
    required void Function(Map<String, dynamic>, bool) onNotification,
  }) async {
    starts++;
    if (failStartup) throw StateError('fixture provider failure');
    await startup?.future;
    changed = onChange;
  }

  @override
  void dispose() {
    disposals++;
    changed = null;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onesignal_device_id': 'fixture-device',
    });
  });

  tearDown(() {
    SharedPreferences.setMockInitialValues({});
  });

  NotificationService? crossZoneService;
  final crossZoneProvider = _ControlledProvider();
  for (final owner in ['first-caller', 'second-caller']) {
    testWidgets('push side effects complete in independent widget zone $owner',
        (tester) async {
      final service =
          crossZoneService ??= NotificationService(provider: crossZoneProvider);
      if (owner == 'second-caller') addTearDown(service.dispose);
      await _expectCompletion(tester, service.subscribeToTopic(owner),
          'cross-zone push topic $owner');
      expect(crossZoneProvider.tags['notification_$owner'], 'true');
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('failed authenticated push login retries after anonymous sync',
      (tester) async {
    final provider = _ControlledProvider()
      ..current = const PushSubscriptionSnapshot(
        subscriptionId: 'fixture-subscription',
        permissionGranted: true,
        optedIn: true,
      );
    final backend = _PushBackendFixture();
    addTearDown(() => expect(backend.unexpected, isEmpty));
    await http.runWithClient(() async {
      final service = _notifications(provider: provider);
      final anonymous = service.syncTokenWithServerIfNeeded();
      await _expectCompletion(tester, anonymous, 'anonymous synchronization');
      expect(await anonymous, isTrue);
      expect(backend.upserts.single.identity, isNull);
      provider.rejectedLogins = 1;
      await AuthService.saveToken(_token('user-a'));
      final failed = service.syncTokenWithServerIfNeeded();
      await _expectCompletion(tester, failed, 'rejected provider login');
      expect(await failed, isFalse);
      expect(provider.externalId, isNull);
      expect(backend.upserts.where((entry) => entry.identity == 'user-a'),
          isEmpty);
      final retry = service.syncTokenWithServerIfNeeded();
      await _expectCompletion(tester, retry, 'explicit provider login retry');
      expect(await retry, isTrue);
      expect(provider.loginAttempts, 2);
      expect(provider.externalId, 'user-a');
      expect(backend.upserts.last, (
        authorization: 'Bearer ${_token('user-a')}',
        identity: 'user-a',
      ));
    }, () => backend.client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
      'guest startup clears a provider identity retained from an old app',
      (tester) async {
    final provider = _ControlledProvider()..externalId = 'previous-account';
    final service = _notifications(provider: provider);
    await _expectCompletion(tester, service.initialize(), 'guest startup');
    await _flush(tester);
    expect(provider.externalId, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
      'invalidation during initialization cannot restore old push identity',
      (tester) async {
    final provider = _ControlledProvider()
      ..externalId = 'previous-account'
      ..startup = Completer<void>();
    await AuthService.saveToken(_token('user-a'));
    final service = _notifications(provider: provider);
    final syncing = service.syncTokenWithServerIfNeeded();
    await _flush(tester);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await AuthService.notifySessionChanged();
    provider.startup!.complete();
    await _expectCompletion(
        tester, syncing, 'invalidated startup synchronization');
    expect(await syncing, isFalse);
    await _flush(tester);
    expect(provider.externalId, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
      'failed initialization is retryable and successful startup is shared',
      (tester) async {
    final provider = _ControlledProvider()..failStartup = true;
    final service = _notifications(provider: provider);
    await _expectCompletion(tester,
        expectLater(service.initialize(), throwsStateError), 'failed startup');
    expect(provider.starts, 1);
    provider.failStartup = false;
    provider.startup = Completer<void>();
    final first = service.initialize();
    final second = service.initialize();
    await _flush(tester);
    expect(provider.starts, 2);
    provider.startup!.complete();
    await _expectCompletion(
        tester, Future.wait([first, second]), 'coalesced initialization retry');
    await _flush(tester);
    await _expectCompletion(tester, service.initialize(), 'cached startup');
    expect(provider.starts, 2);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
      'disposing pending startup cannot register live callbacks or sync',
      (tester) async {
    final provider = _ControlledProvider()..startup = Completer<void>();
    final rejected = <String>[];
    final client = MockClient((request) async {
      rejected.add('${request.method} ${request.url}');
      throw StateError(rejected.last);
    });
    await http.runWithClient(() async {
      final service = _notifications(provider: provider);
      final starting = service.initialize();
      await _flush(tester);
      service.dispose();
      provider.startup!.complete();
      await _expectCompletion(tester, starting, 'disposed startup release');
      provider.changed?.call();
      await _flush(tester);
      expect(await service.syncTokenWithServerIfNeeded(), isFalse);
      expect(provider.disposals, 1);
      expect(rejected, isEmpty);
    }, () => client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('queued logout deletes old credentials after an in-flight upsert',
      (tester) async {
    final provider = _ControlledProvider()
      ..current = const PushSubscriptionSnapshot(
        subscriptionId: 'fixture-subscription',
        permissionGranted: true,
        optedIn: true,
      );
    final backend = _PushBackendFixture()
      ..heldUpsert = Completer<http.Response>();
    addTearDown(() => expect(backend.unexpected, isEmpty));
    await AuthService.saveToken(_token('user-a'));
    await http.runWithClient(() async {
      final service = _notifications(provider: provider);
      final syncing = service.syncTokenWithServerIfNeeded();
      await _flush(tester);
      expect(backend.upserts, hasLength(1));
      final logout = service.logoutUser(authToken: _token('user-a'));
      await _expectCompletion(tester, AuthService.saveToken(_token('user-b')),
          'account B local save');
      final currentSync = service.syncTokenWithServerIfNeeded();
      await _flush(tester);
      expect(backend.deletions, isEmpty);
      final held = backend.heldUpsert!;
      backend.heldUpsert = null;
      held.complete(http.Response('{"success":true}', 200));
      String details() =>
          'backend=${backend.effects}, provider=${provider.externalId}';
      await _expectCompletion(tester, syncing, 'account A upsert completion',
          details: details);
      await _expectCompletion(tester, logout, 'captured-account cleanup',
          details: details);
      await _expectCompletion(tester, currentSync, 'account B synchronization',
          details: details);
      await _flush(tester);

      expect(backend.effects.first, 'upsert:user-a');
      expect(backend.effects[1], 'delete:Bearer ${_token('user-a')}');
      expect(
          backend.deletions.every(
              (authorization) => authorization == 'Bearer ${_token('user-a')}'),
          isTrue);
      expect(backend.upserts.last, (
        authorization: 'Bearer ${_token('user-b')}',
        identity: 'user-b',
      ));
      expect(provider.externalId, 'user-b');
    }, () => backend.client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
      'concurrent notification initialization owns one provider startup',
      (tester) async {
    final native = NativePushFixture()..install();
    final backend = _PushBackendFixture();
    final gate = Completer<void>();
    native.initialize = () => gate.future;
    addTearDown(() {
      native.uninstall();
      expect(native.unexpected, isEmpty);
      expect(backend.unexpected, isEmpty);
    });
    await AuthService.saveToken(_token('user-a'));
    await http.runWithClient(() async {
      final service = _notifications();
      final requests = [
        service.initialize(),
        service.initialize(),
        service.getPermissionState(),
      ];
      await _flush(tester);
      final starts = native.initializations;
      gate.complete();
      await _expectCompletion(
          tester, Future.wait(requests), 'native initialization gate release');
      await _flush(tester);
      expect(starts, 1);
      expect(native.initializations, 1);
    }, () => backend.client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
      'delayed account A push login cannot overwrite account B ownership',
      (tester) async {
    final native = NativePushFixture()..install();
    final backend = _PushBackendFixture();
    final gate = Completer<void>();
    native.login = (identity) async {
      if (identity == 'user-a') await gate.future;
    };
    addTearDown(() {
      native.uninstall();
      expect(native.unexpected, isEmpty);
      expect(backend.unexpected, isEmpty);
    });
    await AuthService.saveToken(_token('user-a'));
    await http.runWithClient(() async {
      final service = _notifications();
      final oldSync = service.syncTokenWithServerIfNeeded();
      await _flush(tester);
      expect(native.logins, contains('user-a'));
      await AuthService.saveToken(_token('user-b'));
      final currentSync = service.syncTokenWithServerIfNeeded();
      await _flush(tester);
      gate.complete();
      await _expectCompletion(tester, Future.wait([oldSync, currentSync]),
          'stale native login release');
      await _flush(tester);

      expect(native.effects.last, 'login:user-b');
      expect(
        backend.upserts,
        isNot(contains((
          authorization: 'Bearer ${_token('user-b')}',
          identity: 'user-a',
        ))),
      );
    }, () => backend.client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('local logout removes credentials before optional push settles',
      (tester) async {
    final native = NativePushFixture()..install();
    final backend = _PushBackendFixture();
    final gate = Completer<void>();
    native.logout = () => gate.future;
    addTearDown(() {
      native.uninstall();
      expect(native.unexpected, isEmpty);
      expect(backend.unexpected, isEmpty);
    });
    await AuthService.saveToken(_token('user-a'));
    await AuthService.bindAuthenticatedIdentity('user-a');
    await http.runWithClient(() async {
      final ending = AuthService.clearToken();
      await _flush(tester);
      final tokenWhileProviderPending = await AuthService.getToken();
      final localEndingWhileProviderPending = AuthService.isEndingSession;
      gate.complete();
      await _expectCompletion(tester, ending, 'local logout completion');
      await _flush(tester);

      expect(tokenWhileProviderPending, isNull);
      expect(localEndingWhileProviderPending, isFalse);
      expect(AuthService.currentIdentity, isNull);
      expect(backend.deletions, ['Bearer ${_token('user-a')}']);
    }, () => backend.client);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
