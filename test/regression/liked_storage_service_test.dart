import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/utils/liked_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferencesStorePlatform previousStore;
  late _LikesStore store;

  setUp(() async {
    previousStore = SharedPreferencesStorePlatform.instance;
    SharedPreferences.resetStatic();
    store = _LikesStore({
      'flutter.auth_token': 'fixture-user-token',
      'flutter.liked_items_v2_fixture-user_1': '[10]',
      'flutter.liked_items_v2_fixture-user_2': '[20]',
    });
    SharedPreferencesStorePlatform.instance = store;
    await AuthService.notifySessionChanged();
    await AuthService.bindAuthenticatedIdentity('fixture-user');
  });

  tearDown(() {
    SharedPreferencesStorePlatform.instance = previousStore;
    SharedPreferences.resetStatic();
  });

  test('concurrent different-item likes retain both confirmed changes',
      () async {
    await SharedPreferences.getInstance();
    await Future.wait([
      LikedStorageService.setLiked(businessId: 1, itemId: 11, liked: true),
      LikedStorageService.setLiked(businessId: 1, itemId: 12, liked: true),
    ]);
    expect(await LikedStorageService.getLikedIds(businessId: 1), {10, 11, 12});
    expect(
        jsonDecode((await store
            .getAll())['flutter.liked_items_v2_fixture-user_1']! as String),
        unorderedEquals([10, 11, 12]));
    expect(await LikedStorageService.getLikedIds(businessId: 2), {20});
  });

  test('concurrent unlike and different-item like retain both changes',
      () async {
    await SharedPreferences.getInstance();
    await Future.wait([
      LikedStorageService.setLiked(businessId: 1, itemId: 10, liked: false),
      LikedStorageService.setLiked(businessId: 1, itemId: 11, liked: true),
    ]);
    expect(await LikedStorageService.getLikedIds(businessId: 1), {11});
  });

  test('rejected liked-state write is reported and does not poison next change',
      () async {
    store.rejectNext = true;
    await expectLater(
      LikedStorageService.setLiked(businessId: 1, itemId: 11, liked: true),
      throwsStateError,
    );
    expect(await LikedStorageService.getLikedIds(businessId: 1), {10});
    await LikedStorageService.setLiked(businessId: 1, itemId: 12, liked: true);
    expect(await LikedStorageService.getLikedIds(businessId: 1), {10, 12});
    expect(
        jsonDecode((await store
            .getAll())['flutter.liked_items_v2_fixture-user_1']! as String),
        unorderedEquals([10, 12]));
  });

  test('queued same-store writes keep invocation order while first is delayed',
      () async {
    final gate = Completer<void>();
    store.holdNext = gate;
    final first =
        LikedStorageService.setLiked(businessId: 1, itemId: 11, liked: true);
    await store.writeStarted.future;
    final second =
        LikedStorageService.setLiked(businessId: 1, itemId: 12, liked: true);
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await Future.wait([first, second]);
    expect(await LikedStorageService.getLikedIds(businessId: 1), {10, 11, 12});
    expect(
        jsonDecode((await store
            .getAll())['flutter.liked_items_v2_fixture-user_1']! as String),
        unorderedEquals([10, 11, 12]));
  });
}

class _LikesStore extends InMemorySharedPreferencesStore {
  _LikesStore(super.values) : super.withData();

  bool rejectNext = false;
  Completer<void>? holdNext;
  final writeStarted = Completer<void>();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!key.startsWith('flutter.liked_items_')) {
      throw StateError('Unexpected preference write: $key');
    }
    final hold = holdNext;
    holdNext = null;
    if (hold != null) {
      writeStarted.complete();
      await hold.future;
    }
    if (rejectNext) {
      rejectNext = false;
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}
