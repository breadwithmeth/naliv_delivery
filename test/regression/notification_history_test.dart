import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/features/notifications/notification_history.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import 'package:naliv_delivery/services/push_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/preferences_store.dart';

const _owner = 'history-account-a';
const _other = 'history-account-b';
final _ownerKey = 'notification_history_v1.${base64Url.encode(utf8.encode(_owner))}';
final _history = NotificationHistory.instance;

HistoryNotification _row(String id, int minute, {String title = 'Заказ'}) =>
    HistoryNotification(
      id: id,
      title: title,
      body: 'Заказ доставлен',
      receivedAt: DateTime.utc(2026, 6, 1, 0, minute),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OnboardingPreferences preferences;
  setUp(() async {
    preferences = OnboardingPreferences()..install();
    await AuthService.notifySessionChanged();
    await AuthService.bindAuthenticatedIdentity(_owner);
  });

  tearDown(() async {
    await AuthService.bindAuthenticatedIdentity(null);
    SharedPreferences.setMockInitialValues({});
  });

  test('persists display data, newest first, without reordering a clicked ID', () async {
    var changes = 0;
    void listener() => changes++;
    _history.addListener(listener);
    addTearDown(() => _history.removeListener(listener));

    await Future.wait([
      _history.append(_owner, _row('first', 2)),
      _history.append(_owner, _row('older', 1)),
      _history.append(_owner, _row('newer', 3)),
    ]);
    preferences.install(); // Re-read from the platform, not the old cache.
    expect(await _history.append(_owner, _row('first', 4, title: 'Changed')), isFalse);
    final rows = await _history.read(_owner);
    expect(rows.map((row) => row.id), ['newer', 'first', 'older']);
    expect(rows[1].receivedAt, DateTime.utc(2026, 6, 1, 0, 2));
    expect(rows[1].title, 'Заказ');
    expect(rows[1].body, 'Заказ доставлен');
    expect(changes, 3);
  });

  test('caps visible entries and remembers evicted IDs across reload', () async {
    for (var n = 0; n <= 100; n++) {
      await _history.append(_owner, _row('push-$n', n));
    }
    preferences.install();
    expect(await _history.append(_owner, _row('push-0', 101)), isFalse);
    final rows = await _history.read(_owner);
    expect(rows, hasLength(100));
    expect(rows.first.id, 'push-100');
    expect(rows.last.id, 'push-1');
  });

  test('account switch hides previous rows and cannot write for that account', () async {
    expect(await _history.append(_owner, _row('a-secret', 1)), isTrue);
    await AuthService.notifySessionChanged();
    expect(await _history.read(_owner), isEmpty);
    await AuthService.bindAuthenticatedIdentity(_other);
    expect(await _history.append(_owner, _row('a-late', 2)), isFalse);
    expect(await _history.read(_owner), isEmpty);
    expect(await _history.read(_other), isEmpty);
  });

  test('explicit logout removes the outgoing account history before reuse', () async {
    final restoreProvider =
        NotificationService.installProvider(InMemoryPushProvider(supported: false));
    addTearDown(restoreProvider);
    expect(await _history.append(_owner, _row('private', 1)), isTrue);
    final ending = AuthService.clearToken();
    expect(await _history.read(_owner), isEmpty);
    await ending;
    await AuthService.bindAuthenticatedIdentity(_owner);
    expect(await _history.read(_owner), isEmpty);
  });

  test('stored malformed history is an error, not an empty inbox', () async {
    final cache = await SharedPreferences.getInstance();
    await cache.setString(_ownerKey, '{"entries":oops}');
    await expectLater(_history.read(_owner), throwsFormatException);
  });

  test('rejected preference write publishes neither change nor a cached row', () async {
    var changes = 0;
    void listener() => changes++;
    _history.addListener(listener);
    addTearDown(() => _history.removeListener(listener));
    preferences.rejectedKeys.add(_ownerKey);
    await expectLater(_history.append(_owner, _row('rejected', 1)), throwsStateError);
    expect(await _history.read(_owner), isEmpty);
    expect(changes, 0);
  });

  test('write settling after reauthentication cannot announce stale data', () async {
    final gate = Completer<bool>();
    preferences
      ..heldKey = _ownerKey
      ..heldWrite = gate;
    var changes = 0;
    void listener() => changes++;
    _history.addListener(listener);
    addTearDown(() => _history.removeListener(listener));
    final append = _history.append(_owner, _row('stale', 1));
    await Future<void>.delayed(Duration.zero);
    await AuthService.notifySessionChanged();
    await AuthService.bindAuthenticatedIdentity(_owner);
    gate.complete(true);
    expect(await append, isFalse);
    expect(changes, 0);
    expect(await _history.read(_owner), isEmpty);
  });
}
