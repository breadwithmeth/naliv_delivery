import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/services/app_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/preferences_store.dart';

const _key = 'app_update_snooze_android_1.2.118';
final _time = DateTime.utc(2026, 11, 11, 12);

class _BrokenPreferences extends OnboardingPreferences {
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<Map<String, Object>> getAll() async {
    if (failRead) throw StateError('unreadable');
    return super.getAll();
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (failWrite) throw StateError('unwritable');
    return super.setValue(type, key, value);
  }
}

void main() {
  late OnboardingPreferences preferences;
  late MockClient client;
  late List<String> unexpected;
  late String body;
  late int status;
  late int requests;
  Future<http.Response> Function()? response;
  late DateTime now;

  AppUpdateService service({
    AppUpdatePlatform? platform = AppUpdatePlatform.android,
    String installed = '1.2.117',
    Future<String> Function()? installedVersion,
  }) => AppUpdateService(
    platform: platform,
    installedVersion: installedVersion ?? () async => installed,
    now: () => now,
  );

  Future<T> run<T>(Future<T> Function() action) =>
      http.runWithClient(action, () => client);

  setUp(() {
    preferences = OnboardingPreferences()..install();
    now = _time;
    body = '{"android":"1.2.118","ios":"1.2.113"}';
    status = 200;
    requests = 0;
    response = null;
    unexpected = [];
    client = MockClient((request) async {
      if (request.method != 'GET' ||
          request.url.toString() !=
              'https://app.gradusy24.kz/app-update.json' ||
          request.headers['Accept'] != 'application/json' ||
          request.headers.containsKey('Authorization') ||
          request.body.isNotEmpty) {
        unexpected.add('${request.method} ${request.url} ${request.headers}');
        throw StateError('Unexpected update request');
      }
      requests++;
      return response != null ? response!() : http.Response(body, status);
    });
  });
  tearDown(() {
    client.close();
    expect(unexpected, isEmpty);
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'offers only a strictly newer numeric version for the selected store',
    () async {
      await run(() async {
        final android = await service().check();
        expect(android?.version, '1.2.118');
        expect(android?.platform, AppUpdatePlatform.android);
        expect(
          android?.storeUri.toString(),
          'https://play.google.com/store/apps/details?id=kz.gradusy24.app',
        );
        expect(await service(platform: AppUpdatePlatform.ios).check(), isNull);
        final ios = await service(
          platform: AppUpdatePlatform.ios,
          installed: '1.2.112',
        ).check();
        expect(ios?.version, '1.2.113');
        expect(
          ios?.storeUri.toString(),
          'https://apps.apple.com/kz/app/id6473792920',
        );
        expect(await service(installed: '1.2.118').check(), isNull);
        expect(await service(installed: '2.0.0').check(), isNull);
        body = '{"android":" 1.10.0 ","ios":false,"extra":42}';
        expect(
          (await service(installed: ' 1.9.9 ').check())?.version,
          '1.10.0',
        );
      });
    },
  );

  test(
    'malformed selected versions and installed prereleases fail open',
    () async {
      await run(() async {
        for (final value in [
          'null',
          'false',
          '42',
          '"1.2"',
          '"-1.2.118"',
          '"1.2.118-beta"',
          '"1.2.118+5"',
          '"1.2.1e3"',
          '""',
        ]) {
          body = '{"android":$value,"ios":"9.0.0"}';
          expect(await service().check(), isNull, reason: value);
        }
        for (final invalid in [
          '1.2',
          '1.2.117-beta',
          '1.2.117+5',
          '-1.2.3',
          '',
        ]) {
          body = '{"android":"9.0.0"}';
          expect(
            await service(installed: invalid).check(),
            isNull,
            reason: invalid,
          );
        }
        for (final invalid in ['{}', '[]', 'null', '<html>app</html>', '{']) {
          body = invalid;
          expect(await service().check(), isNull, reason: invalid);
        }
        body = '{"android":"1.2.118"}';
        for (final code in [404, 500]) {
          status = code;
          expect(await service().check(), isNull);
        }
        response = () async => throw StateError('offline');
        expect(await service().check(), isNull);
        response = null;
        status = 200;
        expect(
          await service(
            installedVersion: () async => throw StateError('plugin'),
          ).check(),
          isNull,
        );
        (_BrokenPreferences()..failRead = true).install();
        expect(await service().check(), isNull);
      });
    },
  );

  test(
    'unsupported runtime touches no package, preferences, network or launcher',
    () async {
      (_BrokenPreferences()..failRead = true).install();
      var installedReads = 0;
      var launches = 0;
      final disabled = AppUpdateService(
        platform: null,
        installedVersion: () async {
          installedReads++;
          return '1.0.0';
        },
        openUrl: (_) async {
          launches++;
          return true;
        },
      );
      expect(await run(disabled.check), isNull);
      expect([installedReads, requests, launches], [0, 0, 0]);
    },
  );

  test(
    'snooze survives cache reset until exactly 24 hours, not another release',
    () async {
      await run(() async {
        final first = service();
        final offer = (await first.check())!;
        expect(await first.snooze(offer), isTrue);
        expect(
          (await SharedPreferences.getInstance()).get(_key),
          _time.add(const Duration(hours: 24)).millisecondsSinceEpoch,
        );
        preferences.install();
        now = _time.add(const Duration(hours: 23, minutes: 59, seconds: 59));
        expect(await service().check(), isNull);
        body = '{"android":"1.2.119"}';
        expect((await service().check())?.version, '1.2.119');
        body = '{"android":"1.2.118"}';
        now = _time.add(const Duration(hours: 24));
        expect((await service().check())?.version, '1.2.118');
      });
    },
  );

  test('wrong-type deadlines do not suppress a valid offer', () async {
    for (final value in ['9999999999999', true, 9999999999999.0]) {
      OnboardingPreferences({_key: value}).install();
      expect((await run(service().check))?.version, '1.2.118');
    }
  });

  test('refused and throwing writes keep only the session cooldown', () async {
    for (final throwing in [false, true]) {
      final store = _BrokenPreferences()..failWrite = throwing;
      if (!throwing) store.rejectedKeys.add(_key);
      store.install();
      await run(() async {
        final current = service();
        final offer = (await current.check())!;
        expect(await current.snooze(offer), isFalse);
        expect(await current.check(), isNull);
        store.install();
        expect((await service().check())?.version, '1.2.118');
      });
    }
  });

  testWidgets(
    'whole check times out including a held package read and recovers',
    (tester) async {
      final installed = Completer<String>();
      final current = service(installedVersion: () => installed.future);
      await run(() async {
        AppUpdateOffer? result;
        var completed = false;
        unawaited(
          current.check().then((value) {
            result = value;
            completed = true;
          }),
        );
        await tester.pump(const Duration(seconds: 5));
        expect(completed, isTrue);
        expect(result, isNull);
        installed.complete('1.2.117');
        await tester.pump();
        expect((await current.check())?.version, '1.2.118');
      });
    },
  );

  testWidgets(
    'concurrent checks share one request and subsequent failures can recover',
    (tester) async {
      final held = Completer<http.Response>();
      response = () => held.future;
      await run(() async {
        final current = service();
        final first = current.check();
        final second = current.check();
        await tester.pump();
        expect(requests, 1);
        held.complete(http.Response('offline', 500));
        expect(await first, isNull);
        expect(await second, isNull);
        response = null;
        expect((await current.check())?.version, '1.2.118');
        expect(requests, 2);
      });
    },
  );
}
