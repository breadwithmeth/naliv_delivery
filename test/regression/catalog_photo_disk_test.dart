@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/services/catalog_photo/photo_store_io.dart';
import 'package:path/path.dart' as p;

const _mib = 1024 * 1024;

void main() {
  late Directory cache;
  late DiskPhotoStore store;
  final url = Uri.parse('https://photos.example.invalid/folder/photo.png?v=1');
  final checkedAt = DateTime.utc(2026, 11, 24, 1, 2, 3, 456, 789);
  final original = (bytes: Uint8List.fromList([1, 2, 3]), checkedAt: checkedAt);

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('naliv_catalog_photos_');
    addTearDown(() => cache.delete(recursive: true));
    store = DiskPhotoStore(cache);
  });

  test(
    'distinct query variants retain their bytes and check times on reopen',
    () async {
      final variant = url.replace(query: 'v=2');
      final later = checkedAt.add(const Duration(days: 1));
      await store.write(url, original);
      await store.write(variant, (
        bytes: Uint8List.fromList([9]),
        checkedAt: later,
      ));

      final reopened = DiskPhotoStore(cache);
      final first = await reopened.read(url);
      final second = await reopened.read(variant);
      expect(first?.bytes, [1, 2, 3]);
      expect(first?.checkedAt, checkedAt);
      expect(second?.bytes, [9]);
      expect(second?.checkedAt, later);
    },
  );

  test('replacement publishes new bytes and check time together', () async {
    await store.write(url, original);
    final later = checkedAt.add(const Duration(minutes: 1));
    await store.write(
      url,
      (bytes: Uint8List.fromList([7]), checkedAt: later),
      previousCheck: checkedAt,
    );

    final saved = await DiskPhotoStore(cache).read(url);
    expect(saved?.bytes, [7]);
    expect(saved?.checkedAt, later);
  });

  test('an oversized replacement leaves the previous record intact', () async {
    await store.write(url, original);
    await store.write(
      url,
      (
        bytes: Uint8List(8 * _mib + 1),
        checkedAt: checkedAt.add(const Duration(days: 1)),
      ),
      previousCheck: checkedAt,
    );

    final saved = await DiskPhotoStore(cache).read(url);
    expect(saved?.bytes, [1, 2, 3]);
    expect(saved?.checkedAt, checkedAt);
  });

  test('a blocked staging write leaves the last good file intact', () async {
    await store.write(url, original);
    final obstruction = await Directory(
      p.join(cache.path, '.pending-photo'),
    ).create();
    final sentinel = File(p.join(obstruction.path, 'unrelated.txt'));
    await sentinel.writeAsString('keep');

    await expectLater(
      store.write(
        url,
        (bytes: Uint8List.fromList([7]), checkedAt: checkedAt),
        previousCheck: checkedAt,
      ),
      throwsA(isA<FileSystemException>()),
    );
    final saved = await DiskPhotoStore(cache).read(url);
    expect(saved?.bytes, [1, 2, 3]);
    expect(saved?.checkedAt, checkedAt);
    expect(await sentinel.readAsString(), 'keep');
  });

  test('truncated data is a cache miss', () async {
    await store.write(url, original);
    final file = (await cache.list().single) as File;
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.truncate(await handle.length() - 1);
    } finally {
      await handle.close();
    }

    expect(await DiskPhotoStore(cache).read(url), isNull);
  });

  test('removal is idempotent and persists across reopen', () async {
    final variant = url.replace(query: 'v=2');
    await store.write(url, original);
    await store.write(variant, original);
    await store.remove(url, previousCheck: checkedAt);
    await store.remove(url, previousCheck: checkedAt);

    final reopened = DiskPhotoStore(cache);
    expect(await reopened.read(url), isNull);
    expect((await reopened.read(variant))?.bytes, [1, 2, 3]);
  });

  test('the next sweep removes untouched v1 records at the cutoff', () async {
    final retainedUrl = url.replace(query: 'v=2');
    final oldestRetained = checkedAt.add(const Duration(microseconds: 1));
    await store.write(url, original);
    final expired = (await cache.list().single) as File;
    // File mtime is not successful validation time.
    await expired.setLastModified(checkedAt.add(const Duration(days: 29)));
    await store.write(retainedUrl, (
      bytes: Uint8List.fromList([9]),
      checkedAt: oldestRetained,
    ));
    final unrelated = File(p.join(cache.path, 'keep.txt'));
    await unrelated.writeAsString('keep');

    final reopened = DiskPhotoStore(cache);
    await reopened.pruneExpired(checkedAt);

    expect(await expired.exists(), isFalse);
    expect((await reopened.read(retainedUrl))?.checkedAt, oldestRetained);
    expect(await unrelated.readAsString(), 'keep');

    await reopened.pruneExpired(oldestRetained);
    expect(await cache.list().map((entry) => entry.path).toList(), [
      unrelated.path,
    ]);
  });

  test('a queued sweep does not delete a same-URL replacement', () async {
    await store.write(url, original);
    await store.pruneExpired(checkedAt.subtract(const Duration(microseconds: 1)));
    final renewedAt = checkedAt.add(const Duration(days: 1));
    await Future.wait([
      store.write(
        url,
        (bytes: Uint8List.fromList([7]), checkedAt: renewedAt),
        previousCheck: checkedAt,
      ),
      store.pruneExpired(checkedAt),
    ]);
    final saved = await DiskPhotoStore(cache).read(url);
    expect(saved?.bytes, [7]);
    expect(saved?.checkedAt, renewedAt);
  });

  test('late mutations cannot replace or delete a renewed disk record', () async {
    await store.write(url, original);
    final updated = (
      bytes: Uint8List.fromList([9]),
      checkedAt: checkedAt.add(const Duration(days: 1)),
    );
    await store.write(url, updated, previousCheck: checkedAt);
    await store.write(
      url,
      (
        bytes: original.bytes,
        checkedAt: updated.checkedAt.add(const Duration(seconds: 1)),
      ),
      previousCheck: checkedAt,
    );
    await store.remove(url, previousCheck: checkedAt);

    final saved = await DiskPhotoStore(cache).read(url);
    expect(saved?.bytes, [9]);
    expect(saved?.checkedAt, updated.checkedAt);
  });

  test(
    'cache pressure after reopen evicts only the oldest owned file',
    () async {
      final bytes = Uint8List(7 * _mib + _mib ~/ 2)..[0] = 12;
      final photo = (bytes: bytes, checkedAt: checkedAt);
      await store.write(url, photo);
      final oldest = (await cache.list().single) as File;
      await oldest.setLastModified(DateTime.utc(2000));
      final unrelated = File(p.join(cache.path, 'keep.txt'));
      await unrelated.writeAsString('not a cache record');
      for (var i = 2; i <= 8; i++) {
        await store.write(url.replace(query: 'v=$i'), photo);
      }

      final reopened = DiskPhotoStore(cache);
      final newest = url.replace(query: 'v=9');
      await reopened.write(newest, photo);

      expect(await reopened.read(url), isNull);
      final retained = (await reopened.read(url.replace(query: 'v=2')))?.bytes;
      final added = (await reopened.read(newest))?.bytes;
      expect(retained?.length, bytes.length);
      expect(retained?[0], 12);
      expect(added?.length, bytes.length);
      expect(added?[0], 12);
      expect(await unrelated.readAsString(), 'not a cache record');
      var diskBytes = 0;
      await for (final file in cache.list()) {
        if (file is File && file.path != unrelated.path) {
          diskBytes += await file.length();
        }
      }
      expect(diskBytes, lessThanOrEqualTo(64 * _mib));
    },
  );

  test('native transport sends a public GET for the complete URL', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url, url);
      expect(request.headers, isEmpty);
      expect(request.bodyBytes, isEmpty);
      return http.Response.bytes([3, 4], 200);
    });
    addTearDown(client.close);

    final response = await http.runWithClient(
      () => fetchPhoto(url),
      () => client,
    );
    expect(response.statusCode, 200);
    expect(response.bodyBytes, [3, 4]);
  });
}
