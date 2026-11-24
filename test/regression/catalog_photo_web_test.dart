@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/services/catalog_photo/photo_store_web.dart';
import 'package:web/web.dart' as web;

void main() {
  late String cacheName;
  final photoUrl = Uri.parse('https://cdn.example.test/photo.jpg?version=1');
  final otherUrl = Uri.parse('https://cdn.example.test/photo.jpg?version=2');
  final first = (
    bytes: Uint8List.fromList([255, 216, 1, 2]),
    checkedAt: DateTime.utc(2026, 11, 24, 10, 15, 30, 123, 456),
  );
  final updated = (
    bytes: Uint8List.fromList([255, 216, 3, 4]),
    checkedAt: DateTime.utc(2026, 11, 24, 11, 15),
  );

  setUp(() {
    cacheName = 'catalog-photo-test-${web.window.crypto.randomUUID()}';
    addTearDown(() async {
      await web.window.caches.delete(cacheName).toDart;
    });
  });

  test(
    'persists bytes and the check timestamp across store instances',
    () async {
      final store = createPhotoStore(cacheName: cacheName);
      expect(await store.read(photoUrl), isNull);
      await store.write(photoUrl, first);

      final browserCache = await web.window.caches.open(cacheName).toDart;
      final response = await browserCache
          .match(photoUrl.toString().toJS)
          .toDart;
      expect(response, isNotNull);
      final buffer = await response!.arrayBuffer().toDart;
      expect(buffer.toDart.asUint8List(), orderedEquals([255, 216, 1, 2]));

      final reopened = createPhotoStore(cacheName: cacheName);
      final saved = (await reopened.read(photoUrl))!;
      expect(saved.bytes, orderedEquals([255, 216, 1, 2]));
      expect(saved.checkedAt, DateTime.utc(2026, 11, 24, 10, 15, 30, 123, 456));
      expect(saved.checkedAt.isUtc, isTrue);
    },
  );

  test('overwrite and removal affect only the exact query variant', () async {
    final store = createPhotoStore(cacheName: cacheName);
    await store.write(photoUrl, first);
    await store.write(otherUrl, first);
    await store.write(photoUrl, updated);

    final reopened = createPhotoStore(cacheName: cacheName);
    final saved = (await reopened.read(photoUrl))!;
    expect(saved.bytes, orderedEquals([255, 216, 3, 4]));
    expect(saved.checkedAt, DateTime.utc(2026, 11, 24, 11, 15));
    expect(
      (await reopened.read(otherUrl))!.bytes,
      orderedEquals([255, 216, 1, 2]),
    );

    await reopened.remove(photoUrl);
    final afterRemoval = createPhotoStore(cacheName: cacheName);
    expect(await afterRemoval.read(photoUrl), isNull);
    expect(
      (await afterRemoval.read(otherUrl))!.bytes,
      orderedEquals([255, 216, 1, 2]),
    );
  });

  test(
    'evicts the oldest entry when a write takes the cache over 128',
    () async {
      final store = createPhotoStore(cacheName: cacheName);
      await store.write(photoUrl, first);
      for (var i = 2; i <= 129; i++) {
        await store.write(photoUrl.replace(query: 'version=$i'), updated);
      }

      final browserCache = await web.window.caches.open(cacheName).toDart;
      expect((await browserCache.keys().toDart).toDart, hasLength(128));
      expect(await store.read(photoUrl), isNull);
      expect(
        (await store.read(otherUrl))!.bytes,
        orderedEquals([255, 216, 3, 4]),
      );
      final latest = await store.read(photoUrl.replace(query: 'version=129'));
      expect(latest!.bytes, orderedEquals([255, 216, 3, 4]));
    },
  );

  test('does not persist photos larger than 8 MiB', () async {
    final store = createPhotoStore(cacheName: cacheName);
    await store.write(photoUrl, (
      bytes: Uint8List(8 * 1024 * 1024 + 1),
      checkedAt: first.checkedAt,
    ));

    expect(await store.read(photoUrl), isNull);
  });
}
