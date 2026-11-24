import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'photo_store.dart';

/// Original photo bytes are shared by all card sizes. Prices and availability
/// never enter this cache. A stale hit is delivered before starting the refresh.
class CatalogPhotoCache {
  CatalogPhotoCache(this._store, this._fetch, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const freshness = Duration(days: 1);
  final PhotoStore _store;
  final Future<http.Response> Function(Uri) _fetch;
  final DateTime Function() _now;
  final _downloads = <Uri, Future<Uint8List>>{};

  Stream<Uint8List> images(Uri url) async* {
    SavedPhoto? saved;
    try {
      saved = await _store.read(url);
    } catch (_) {
      // Private browsing, disk permissions, and OS eviction must not block images.
    }
    if (saved != null) {
      yield saved.bytes;
      final age = _now().difference(saved.checkedAt);
      if (!age.isNegative && age < freshness) return;
    }
    try {
      final bytes = await _downloads.putIfAbsent(
        url,
        () => _download(url, saved).whenComplete(() {
          _downloads.remove(url);
        }),
      );
      if (saved == null ||
          !identical(bytes, saved.bytes) && !listEquals(bytes, saved.bytes)) {
        yield bytes;
      }
    } catch (_) {
      if (saved == null) rethrow;
    }
  }

  Future<Uint8List> _download(Uri url, SavedPhoto? saved) async {
    final response = await _fetch(url);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw http.ClientException(
        'Invalid photo response (${response.statusCode})',
        url,
      );
    }
    final unchanged =
        saved != null && listEquals(saved.bytes, response.bodyBytes);
    final bytes = unchanged ? saved.bytes : response.bodyBytes;
    if (!unchanged) {
      // A CDN can return HTML or truncated image data with status 200. Do not
      // replace a usable photo unless the new payload actually yields a frame.
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1,
        targetHeight: 1,
      );
      try {
        (await codec.getNextFrame()).image.dispose();
      } finally {
        codec.dispose();
      }
    }
    final directives = response.headers['cache-control']?.toLowerCase().split(
      ',',
    );
    try {
      if (bytes.lengthInBytes > 8 * 1024 * 1024 ||
          (directives?.any((d) => d.trim() == 'no-store') ?? false)) {
        await _store.remove(url);
      } else {
        await _store.write(url, (bytes: bytes, checkedAt: _now().toUtc()));
      }
    } catch (_) {
      // Quota or storage failure: the downloaded image can still be displayed.
    }
    return bytes;
  }
}
