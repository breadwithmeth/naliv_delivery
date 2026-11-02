import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/utils/address_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _address = <String, dynamic>{
  'id': 501,
  'address': 'Тестовый адрес, 16',
  'lat': 49.8047,
  'lon': 73.1094,
  'entrance': '2',
  'floor': '7',
  'apartment': '45',
};

class _FailingStore extends InMemorySharedPreferencesStore {
  _FailingStore(super.data) : super.withData();

  String? failNextKey;
  String? heldKey;
  Completer<bool>? heldWrite;

  bool _fail(String key) {
    if (key != failNextKey) return false;
    failNextKey = null;
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == heldKey && heldWrite != null) {
      heldKey = null;
      if (!await heldWrite!.future) return false;
    }
    if (_fail(key)) return false;
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (_fail(key)) return false;
    return super.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferencesStorePlatform priorStore;
  late _FailingStore store;

  setUp(() {
    priorStore = SharedPreferencesStorePlatform.instance;
    SharedPreferences.resetStatic();
    store = _FailingStore({
      'flutter.selected_address': jsonEncode(_address),
      'flutter.address_history': <String>[
        jsonEncode({
          ..._address,
          'name': _address['address'],
        })
      ],
    });
    SharedPreferencesStorePlatform.instance = store;
  });

  tearDown(() {
    SharedPreferencesStorePlatform.instance = priorStore;
    SharedPreferences.resetStatic();
  });

  test(
      'failed selected-address write keeps prior delivery address and emits no success',
      () async {
    final events = <Map<String, dynamic>?>[];
    final subscription =
        AddressStorageService.selectedAddressStream.listen(events.add);
    addTearDown(subscription.cancel);
    store.failNextKey = 'flutter.selected_address';

    expect(
        await AddressStorageService.saveSelectedAddress({
          ..._address,
          'address': 'Другой адрес, 10',
        }),
        isFalse);
    await Future<void>.delayed(Duration.zero);

    expect(await AddressStorageService.getSelectedAddress(), _address);
    final persisted = await store.getAll();
    expect(
        jsonDecode(persisted['flutter.selected_address']! as String), _address);
    expect(events, isEmpty);
  });

  test(
      'editing a selected server address creates only a device copy and updates delivery details',
      () async {
    expect(
        await AddressStorageService.saveBookAddress({
          ..._address,
          'entrance': '2А',
          'floor': '9',
        }, replacing: _address),
        isTrue);

    final book = await AddressStorageService.getBookSnapshot();
    final copy = book.localAddresses.single;
    expect(copy['device_local'], isTrue);
    expect(copy['edited_from'], '501');
    expect(book.hiddenIds, {'501'});
    expect(book.selectedAddress, copy);
    expect(book.selectedAddress?['entrance'], '2А');
    expect(book.selectedAddress?['floor'], '9');
    expect(book.selectedAddress?['apartment'], '45');
    expect(book.selectedAddress?['point'], {'lat': 49.8047, 'lon': 73.1094});
    final history = await AddressStorageService.getAddressHistory();
    expect(history.single['entrance'], '2А');
    expect(history.single['id'], copy['id']);

    expect(
        await AddressStorageService.saveBookAddress({
          ...copy,
          'apartment': '46Б',
        }, replacing: copy),
        isTrue);
    final edited = await AddressStorageService.getBookSnapshot();
    expect(edited.localAddresses.single['id'], copy['id']);
    expect(edited.selectedAddress?['apartment'], '46Б');
  });

  test('failed removal rolls back book, history and selected delivery address',
      () async {
    expect(await AddressStorageService.saveBookAddress(_address), isTrue);
    final saved =
        (await AddressStorageService.getBookSnapshot()).localAddresses.single;
    expect(await AddressStorageService.selectBookAddress(saved), isTrue);
    final before = await store.getAll();
    final events = <Map<String, dynamic>?>[];
    final subscription =
        AddressStorageService.selectedAddressStream.listen(events.add);
    addTearDown(subscription.cancel);
    store.failNextKey = 'flutter.selected_address';

    expect(await AddressStorageService.removeBookAddress(saved), isFalse);
    await Future<void>.delayed(Duration.zero);

    expect(await store.getAll(), before);
    expect(
        (await AddressStorageService.getBookSnapshot()).localAddresses.single,
        saved);
    expect(await AddressStorageService.getSelectedAddress(), saved);
    expect((await AddressStorageService.getAddressHistory()).first['id'],
        saved['id']);
    expect(events, isEmpty);
  });

  test(
      'confirmed server hide clears its selection and prevents reselection from history',
      () async {
    expect(await AddressStorageService.removeBookAddress(_address), isTrue);
    final book = await AddressStorageService.getBookSnapshot();
    expect(book.hiddenIds, {'501'});
    expect(book.selectedAddress, isNull);
    expect(book.localAddresses, isEmpty);
    expect(await AddressStorageService.getAddressHistory(), isEmpty);
    expect(await AddressStorageService.selectBookAddress(_address), isFalse);
  });

  test(
      'failure halfway through selection restores previous history and selection',
      () async {
    final before = await store.getAll();
    store.failNextKey = 'flutter.address_history';
    expect(
        await AddressStorageService.selectBookAddress({
          ..._address,
          'id': 502,
          'address': 'Другой адрес, 22',
          'lat': 49.81,
        }),
        isFalse);
    expect(await store.getAll(), before);
    expect(await AddressStorageService.getSelectedAddress(), _address);
  });

  test('queued selection waits for rollback and readers wait for the new tail',
      () async {
    final firstAddress = {
      ..._address,
      'id': 502,
      'address': 'Первый адрес, 22',
    };
    final secondAddress = {
      ..._address,
      'id': 503,
      'address': 'Второй адрес, 33',
    };
    final held = Completer<bool>();
    store
      ..heldKey = 'flutter.address_history'
      ..heldWrite = held;

    final first = AddressStorageService.selectBookAddress(firstAddress);
    var secondCompleted = false;
    final second =
        AddressStorageService.selectBookAddress(secondAddress).then((value) {
      secondCompleted = true;
      return value;
    });
    var readCompleted = false;
    final read = AddressStorageService.getBookSnapshot().then((book) {
      readCompleted = true;
      return book;
    });
    try {
      await Future<void>.delayed(Duration.zero);
      expect(secondCompleted, isFalse);
      expect(readCompleted, isFalse);
      expect(
          jsonDecode(
              (await store.getAll())['flutter.selected_address'] as String),
          AddressStorageService.deliveryAddress(firstAddress));
    } finally {
      held.complete(false);
      await first;
      await second;
      await read;
    }

    expect(await first, isFalse);
    expect(await second, isTrue);
    final book = await read;
    expect(book.selectedAddress,
        AddressStorageService.deliveryAddress(secondAddress));
    expect(
        (await AddressStorageService.getAddressHistory())
            .map((item) => item['id']),
        [503, 501]);
  });

  test('a serialization error cannot poison the following address write',
      () async {
    final nextAddress = {..._address, 'apartment': '46Б'};
    final refused = AddressStorageService.saveSelectedAddress({
      ..._address,
      'apartment': Object(),
    });
    final accepted = AddressStorageService.saveSelectedAddress(nextAddress);

    expect(await refused, isFalse);
    expect(await accepted, isTrue);
    expect(await AddressStorageService.getSelectedAddress(), nextAddress);
  });

  test('malformed book entries do not block editing a valid stored address',
      () async {
    final valid = {
      ..._address,
      'id': 'device_fixture',
      'device_local': true,
      'lat': '49.8047',
      'lon': '73.1094',
    };
    final malformed = <String>[
      '{broken-json',
      jsonEncode(['not', 'an', 'address']),
      jsonEncode({'address': 'Invalid coordinate', 'lat': 'NaN', 'lon': 73}),
    ];
    await store.setValue('StringList', 'flutter.profile_local_addresses',
        <String>[malformed[0], jsonEncode(valid), ...malformed.skip(1)]);
    await store.setValue(
        'String', 'flutter.selected_address', jsonEncode(valid));

    expect(
      await AddressStorageService.saveBookAddress({
        ...valid,
        'apartment': '46Б',
      }, replacing: valid),
      isTrue,
    );

    final book = await AddressStorageService.getBookSnapshot();
    expect(book.unreadableEntries, 3);
    final saved = book.localAddresses.single;
    expect(saved['id'], 'device_fixture');
    expect(saved['address'], 'Тестовый адрес, 16');
    expect(saved['lat'], 49.8047);
    expect(saved['lon'], 73.1094);
    expect(saved['point'], {'lat': 49.8047, 'lon': 73.1094});
    expect(saved['apartment'], '46Б');
    expect(book.selectedAddress, saved);
    final raw =
        (await store.getAll())['flutter.profile_local_addresses']! as List;
    expect(raw.where(malformed.contains), malformed);
  });

  test('malformed history entries do not prevent selecting a valid address',
      () async {
    final malformed = ['{broken-history', jsonEncode(false)];
    await store.setValue('StringList', 'flutter.address_history', <String>[
      malformed[0],
      jsonEncode(_address),
      malformed[1],
    ]);
    final next = {
      ..._address,
      'id': 502,
      'address': 'Новый адрес, 22',
      'lat': '49.81',
      'lon': '73.12',
    };

    expect(await AddressStorageService.selectBookAddress(next), isTrue);

    final history = await AddressStorageService.getAddressHistory();
    expect(history.map((item) => item['id']), [502, 501]);
    expect(history.first['point'], {'lat': 49.81, 'lon': 73.12});
    expect((await AddressStorageService.getSelectedAddress())?['lat'], 49.81);
    final raw = (await store.getAll())['flutter.address_history']! as List;
    expect(raw.where(malformed.contains), malformed);
  });

  test('malformed original entries survive removal of a valid local address',
      () async {
    final local = {
      ..._address,
      'id': 'device_fixture',
      'device_local': true,
    };
    final malformedBook = [
      '{broken-book',
      jsonEncode({'address': 'Impossible point', 'lat': 91, 'lon': 73}),
    ];
    final malformedHistory = ['{broken-history', jsonEncode(7)];
    await store.setValue('StringList', 'flutter.profile_local_addresses',
        <String>[jsonEncode(local), ...malformedBook]);
    await store.setValue('StringList', 'flutter.address_history',
        <String>[...malformedHistory, jsonEncode(local)]);
    await store.setValue(
        'String', 'flutter.selected_address', jsonEncode(local));

    expect(await AddressStorageService.removeBookAddress(local), isTrue);

    final book = await AddressStorageService.getBookSnapshot();
    expect(book.localAddresses, isEmpty);
    expect(book.hiddenIds, isEmpty);
    expect(book.selectedAddress, isNull);
    expect(await AddressStorageService.getAddressHistory(), isEmpty);
    final persisted = await store.getAll();
    expect(persisted['flutter.profile_local_addresses'], malformedBook);
    expect(persisted['flutter.address_history'], malformedHistory);
  });

  test('history reads keep valid neighbors of malformed saved entries',
      () async {
    final raw = <String>[
      '{broken-history',
      jsonEncode({
        ..._address,
        'lat': '49.8047',
        'lon': '73.1094',
      }),
      jsonEncode(null),
      jsonEncode({'address': 'Bad point', 'lat': 'Infinity', 'lon': 73}),
    ];
    await store.setValue('StringList', 'flutter.address_history', raw);

    final history = await AddressStorageService.getAddressHistory();

    expect(history, hasLength(1));
    expect(history.single['id'], 501);
    expect(history.single['address'], 'Тестовый адрес, 16');
    expect(history.single['lat'], 49.8047);
    expect(history.single['lon'], 73.1094);
    expect((await store.getAll())['flutter.address_history'], raw);
    expect(
        (await AddressStorageService.getBookSnapshot()).unreadableEntries, 3);
  });

  test(
      'book reads normalize valid coordinate strings without rewriting storage',
      () async {
    final raw = <String>[
      jsonEncode({
        ..._address,
        'lat': ' 49.8047 ',
        'lon': '73.1094',
      }),
    ];
    await store.setValue('StringList', 'flutter.profile_local_addresses', raw);

    final book = await AddressStorageService.getBookSnapshot();

    expect(book.localAddresses.single['lat'], 49.8047);
    expect(book.localAddresses.single['lon'], 73.1094);
    expect(
        book.localAddresses.single['point'], {'lat': 49.8047, 'lon': 73.1094});
    expect((await store.getAll())['flutter.profile_local_addresses'], raw);
  });

  test(
      'history capacity limits valid addresses without deleting corrupt originals',
      () async {
    final unreadable = ['{broken-history', jsonEncode(false)];
    await store.setValue('StringList', 'flutter.address_history', <String>[
      unreadable[0],
      for (var i = 0; i < 10; i++)
        jsonEncode({
          ..._address,
          'id': i,
          'address': 'Сохранённый адрес $i',
        }),
      unreadable[1],
    ]);

    expect(
        await AddressStorageService.selectBookAddress({
          ..._address,
          'id': 502,
          'address': 'Новый адрес, 22',
        }),
        isTrue);

    final history = await AddressStorageService.getAddressHistory();
    expect(history.map((item) => item['id']), [502, 0, 1, 2, 3, 4, 5, 6, 7, 8]);
    final raw = (await store.getAll())['flutter.address_history']! as List;
    expect(raw, hasLength(12));
    expect(raw.where(unreadable.contains), unreadable);
  });
}
