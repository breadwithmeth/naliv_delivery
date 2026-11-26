import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naliv_delivery/services/catalog_photo/catalog_photo_cache.dart';
import 'package:naliv_delivery/services/catalog_photo/photo_store.dart';

import '../support/fixture_product_image.dart';

class _Store implements PhotoStore {
  final entries = <Uri, SavedPhoto>{};
  @override
  Future<void> pruneExpired(DateTime through) async {
    entries.removeWhere((_, photo) => !photo.checkedAt.isAfter(through));
  }

  @override
  Future<SavedPhoto?> read(Uri url) async => entries[url];
  @override
  Future<void> write(Uri url, SavedPhoto photo, {DateTime? previousCheck}) async {
    final current = entries[url];
    if (current == null || current.checkedAt == previousCheck) {
      entries[url] = photo;
    }
  }
  @override
  Future<void> remove(Uri url, {DateTime? previousCheck}) async {
    if (entries[url]?.checkedAt == previousCheck) entries.remove(url);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final url = Uri.parse('https://photos.invalid/item.png?v=1');
  final photo = Uri.parse(fixtureProductImage).data!.contentAsBytes();
  final now = DateTime.utc(2026, 11, 24);

  test(
    'two sizes share one download; reopening uses the saved original',
    () async {
      final store = _Store();
      final answer = Completer<http.Response>();
      var requests = 0;
      final cache = CatalogPhotoCache(store, (_) {
        requests++;
        return answer.future;
      }, now: () => now);
      final loads = Future.wait([
        cache.images(url).single,
        cache.images(url).single,
      ]);
      answer.complete(http.Response.bytes(photo, 200));
      expect(await loads, [photo, photo]);
      expect(requests, 1);
      final reopened = CatalogPhotoCache(
        store,
        (_) => throw StateError('offline'),
        now: () => now,
      );
      expect(await reopened.images(url).single, photo);
    },
  );

  test(
    'stale artwork is available before a same-URL replacement finishes',
    () async {
      final store = _Store();
      final stale = (
        bytes: Uint8List.fromList([1]),
        checkedAt: now.subtract(const Duration(days: 3)),
      );
      store.entries[url] = stale;
      final answer = Completer<http.Response>();
      final cache = CatalogPhotoCache(
        store,
        (_) => answer.future,
        now: () => now,
      );
      final events = StreamIterator(cache.images(url));
      expect(await events.moveNext(), isTrue);
      expect(events.current, stale.bytes);
      expect(store.entries[url], stale);
      answer.complete(http.Response.bytes(photo, 200));
      expect(await events.moveNext(), isTrue);
      expect(events.current, photo);
      expect(await events.moveNext(), isFalse);
      expect(store.entries[url]!.bytes, photo);
      expect(store.entries[url]!.checkedAt, now);
    },
  );

  test('a paused stale subscriber cannot start a second replacement', () async {
    final store = _Store();
    final stale = Uint8List.fromList([1]);
    store.entries[url] = (
      bytes: stale,
      checkedAt: now.subtract(const Duration(days: 1)),
    );
    final answer = Completer<http.Response>();
    var requests = 0;
    final cache = CatalogPhotoCache(store, (requested) {
      expect(requested, url);
      if (++requests == 1) return answer.future;
      return Future.value(http.Response.bytes(stale, 200));
    }, now: () => now);
    final paused = StreamIterator(cache.images(url));
    final active = StreamIterator(cache.images(url));
    addTearDown(paused.cancel);
    addTearDown(active.cancel);

    expect(await paused.moveNext(), isTrue);
    expect(paused.current, stale);
    expect(await active.moveNext(), isTrue);
    expect(active.current, stale);
    answer.complete(http.Response.bytes(photo, 200));
    expect(await active.moveNext(), isTrue);
    expect(active.current, photo);
    expect(await active.moveNext(), isFalse);

    expect(await paused.moveNext(), isTrue);
    expect(paused.current, photo);
    expect(await paused.moveNext(), isFalse);
    expect(requests, 1);
    expect(store.entries[url]?.bytes, photo);
  });

  test('unchanged revalidation renews retention without emitting twice', () async {
    final store = _Store();
    var clock = now;
    store.entries[url] = (
      bytes: photo,
      checkedAt: now.subtract(const Duration(days: 29)),
    );
    var requests = 0;
    final cache = CatalogPhotoCache(store, (requested) async {
      expect(requested, url);
      requests++;
      return http.Response.bytes(photo, 200);
    }, now: () => clock);

    expect(await cache.images(url).toList(), [photo]);
    expect(store.entries[url]?.checkedAt, now);
    clock = now.add(const Duration(days: 1, seconds: -1));
    expect(await cache.images(url).toList(), [photo]);
    expect(requests, 1);
  });

  test('a 30-day-old photo is discarded instead of masking a failure', () async {
    final store = _Store();
    store.entries[url] = (
      bytes: photo,
      checkedAt: now.subtract(const Duration(days: 30)),
    );
    final cache = CatalogPhotoCache(store, (requested) async {
      expect(requested, url);
      return http.Response('offline', 503);
    }, now: () => now);

    await expectLater(cache.images(url), emitsError(isA<http.ClientException>()));
    expect(store.entries[url], isNull);
  });

  test('a fresh lookup prunes an unused URL without downloading it', () async {
    final store = _Store();
    final untouchedUrl = url.replace(query: 'v=2');
    store.entries[url] = (bytes: photo, checkedAt: now);
    store.entries[untouchedUrl] = (
      bytes: photo,
      checkedAt: now.subtract(const Duration(days: 30)),
    );
    final cache = CatalogPhotoCache(store, (requested) {
      fail('Unexpected request for $requested');
    }, now: () => now);

    expect(await cache.images(url).single, photo);
    expect(store.entries.keys, [url]);
  });

  test('a new query URL never falls back to the shared previous URL', () async {
    final store = _Store();
    final previous = (bytes: photo, checkedAt: now);
    store.entries[url] = previous;
    final changedUrl = url.replace(query: 'v=2');
    final requested = <Uri>[];
    final cache = CatalogPhotoCache(store, (uri) async {
      requested.add(uri);
      return http.Response('offline', 503);
    }, now: () => now);

    await expectLater(
      cache.images(changedUrl),
      emitsError(isA<http.ClientException>()),
    );
    expect(await cache.images(url).single, photo);
    expect(requested, [changedUrl]);
    expect(store.entries[url], previous);
  });

  for (final response in [
    http.Response('offline', 503),
    http.Response.bytes(utf8.encode('<html>not a photo</html>'), 200),
  ]) {
    test(
      'failed refresh (${response.statusCode}) preserves previous bytes',
      () async {
        final store = _Store();
        final stale = (
          bytes: photo,
          checkedAt: now.subtract(const Duration(days: 3)),
        );
        store.entries[url] = stale;
        final cache = CatalogPhotoCache(
          store,
          (_) async => response,
          now: () => now,
        );
        expect(await cache.images(url).toList(), [photo]);
        expect(store.entries[url], stale);
      },
    );
  }
}
