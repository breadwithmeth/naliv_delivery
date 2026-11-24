import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/features/notifications/notification_history.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import 'package:naliv_delivery/services/onesignal_push_provider.dart';
import 'package:naliv_delivery/services/push_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/native_push_fixture.dart';

const _a = 'push-account-a';
const _b = 'push-account-b';
final _history = NotificationHistory.instance;

Future<void> _save(String identity) {
  final payload = base64Url.encode(utf8.encode(jsonEncode({'sub': identity})));
  return AuthService.saveToken('e30.$payload.fixture');
}

class _Provider extends InMemoryPushProvider {
  late void Function(PushNotificationEvent) _notify;

  @override
  Future<void> initialize({
    required VoidCallback onChange,
    required void Function(PushNotificationEvent) onNotification,
  }) async => _notify = onNotification;

  void emit(String id, {bool clicked = false, Map<String, dynamic> data = const {}}) =>
      _notify(PushNotificationEvent(
        id: id,
        title: 'Настоящий заголовок',
        body: 'Видимый текст',
        data: data,
        clicked: clicked,
      ));
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Provider provider;
  late NotificationService service;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.notifySessionChanged();
    provider = _Provider();
    service = NotificationService(provider: provider);
  });

  tearDown(() async {
    service.dispose();
    await AuthService.bindAuthenticatedIdentity(null);
    SharedPreferences.setMockInitialValues({});
  });

  test('a verified foreground binding records a push without additional data', () async {
    await _save(_a);
    await AuthService.bindAuthenticatedIdentity(_a);
    await service.syncSubscriptionWithBackend();
    provider.emit('plain');
    provider.emit('plain', clicked: true);
    await _settle();
    var row = (await _history.read(_a)).single;
    expect(row.id, 'plain');
    expect(row.title, 'Настоящий заголовок');
    expect(row.body, 'Видимый текст');
    provider.emit('display', data: {'title': 'untrusted metadata', 'token': 'secret'});
    await _settle();
    row = (await _history.read(_a)).first;
    expect(row.title, 'Настоящий заголовок');
    final prefs = await SharedPreferences.getInstance();
    final rowKey = 'notification_history_v1.${base64Url.encode(utf8.encode(_a))}';
    expect(prefs.getString(rowKey), isNot(contains('secret')));
  });

  test('cold click waits for same-generation authenticated recipient', () async {
    await _save(_a);
    await service.initialize();
    provider.emit('unowned-cold', clicked: true);
    provider.emit('cold-click', clicked: true, data: {'externalId': _a});
    provider.emit('mismatch', clicked: true, data: {'externalId': _b});
    await _settle();
    expect(await _history.read(_a), isEmpty);
    await AuthService.bindAuthenticatedIdentity(_a);
    await _settle();
    expect((await _history.read(_a)).map((row) => row.id), ['cold-click']);
  });

  test('a pending click cannot cross a credential change even for the same account', () async {
    await _save(_a);
    await service.initialize();
    provider.emit('pending', clicked: true, data: {'external_id': _a});
    await _settle();
    await _save(_a);
    await AuthService.bindAuthenticatedIdentity(_a);
    await _settle();
    expect(await _history.read(_a), isEmpty);
  });

  test('after account turnover only matching explicit recipients can be captured', () async {
    await _save(_a);
    await AuthService.bindAuthenticatedIdentity(_a);
    await service.syncSubscriptionWithBackend();
    await _save(_b);
    await AuthService.bindAuthenticatedIdentity(_b);
    await service.syncSubscriptionWithBackend();
    provider.emit('old-untargeted');
    provider.emit('old-targeted', data: {'externalId': _a});
    provider.emit('conflicting', data: {'externalId': _b, 'recipient_user_id': _a});
    provider.emit('malformed', data: {'externalId': null});
    provider.emit('new-targeted', data: {'recipient_user_id': _b});
    await _settle();
    expect((await _history.read(_b)).map((row) => row.id), ['new-targeted']);
    expect(await _history.read(_a), isEmpty);
  });

  test('a legacy registration does not infer a recipient for a plain push', () async {
    SharedPreferences.setMockInitialValues({'onesignal_device_id': 'old-device'});
    await _save(_a);
    await AuthService.bindAuthenticatedIdentity(_a);
    await service.syncSubscriptionWithBackend();
    provider.emit('unknown');
    provider.emit('known', data: {'external_id': _a});
    await _settle();
    expect((await _history.read(_a)).map((row) => row.id), ['known']);
  });

  testWidgets('native receive and click expose the same OneSignal display ID',
      (tester) async {
    final native = NativePushFixture()..install();
    final adapter = OneSignalPushProvider();
    addTearDown(() {
      adapter.dispose();
      native.uninstall();
      expect(native.unexpected, isEmpty);
    });
    final events = <PushNotificationEvent>[];
    await adapter.initialize(onChange: () {}, onNotification: events.add);

    const notification = {
      'notificationId': '2f0bd200-51fd-48f9-b674-418f74d24598',
      'androidNotificationId': 42,
      'title': 'Заголовок из OneSignal',
      'body': 'Текст из OneSignal',
    };
    final messenger = tester.binding.defaultBinaryMessenger;
    const codec = StandardMethodCodec();
    await messenger.handlePlatformMessage(
      'OneSignal#notifications',
      codec.encodeMethodCall(const MethodCall(
        'OneSignal#onWillDisplayNotification',
        {'notification': notification},
      )),
      null,
    );
    await messenger.handlePlatformMessage(
      'OneSignal#notifications',
      codec.encodeMethodCall(const MethodCall(
        'OneSignal#onClickNotification',
        {'notification': notification, 'result': <String, dynamic>{}},
      )),
      null,
    );

    expect(events.map((event) => event.id), [
      '2f0bd200-51fd-48f9-b674-418f74d24598',
      '2f0bd200-51fd-48f9-b674-418f74d24598',
    ]);
    expect(events.map((event) => event.clicked), [false, true]);
    for (final event in events) {
      expect(event.title, 'Заголовок из OneSignal');
      expect(event.body, 'Текст из OneSignal');
      expect(event.data, isEmpty);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
