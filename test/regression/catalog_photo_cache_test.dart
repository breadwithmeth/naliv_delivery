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
  Future<SavedPhoto?> read(Uri url) async => entries[url];
  @override
  Future<void> write(Uri url, SavedPhoto photo) async => entries[url] = photo;
  @override
  Future<void> remove(Uri url) async => entries.remove(url);
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
