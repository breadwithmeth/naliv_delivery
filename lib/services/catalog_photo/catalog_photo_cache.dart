import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'photo_store.dart';

typedef _Lookup = (SavedPhoto? saved, Future<Uint8List>? download);

/// Original photo bytes are shared by all card sizes. Prices and availability
/// never enter this cache. An exact URL stays reusable by any product until it
/// expires; changing a product's URL does not evict or fall back to the old one.
class CatalogPhotoCache {
  CatalogPhotoCache(this._store, this._fetch, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const freshness = Duration(days: 1);
  static const retention = photoRetention;
  final PhotoStore _store;
  final Future<http.Response> Function(Uri) _fetch;
  final DateTime Function() _now;
  final _lookups = <Uri, Future<_Lookup>>{};

  Stream<Uint8List> images(Uri url) async* {
    final cutoff = _now().subtract(retention);
    try {
      await _store.pruneExpired(cutoff);
    } catch (_) {
      // Storage may be unavailable. Check the age again before using any hit.
    }

    final (saved, download) = await _lookups.putIfAbsent(
      url,
      () => _lookup(url),
    );
    final fallback = saved != null && saved.checkedAt.isAfter(cutoff)
        ? saved.bytes
        : null;
    if (fallback != null) yield fallback;
    if (download == null) return;

    try {
      final bytes = await download;
      if (!identical(bytes, fallback)) yield bytes;
    } catch (_) {
      if (fallback == null) rethrow;
    }
  }

  Future<_Lookup> _lookup(Uri url) async {
    SavedPhoto? saved;
    try {
      saved = await _store.read(url);
    } catch (_) {
      // Private browsing, disk permissions, and OS eviction must not block images.
    }
    if (saved != null) {
      final age = _now().difference(saved.checkedAt);
      if (!age.isNegative && age < freshness) {
        _lookups.remove(url);
        return (saved, null);
      }
    }

    // Claim the refresh before delivery: a paused stale subscriber must never
    // start a second download using a snapshot another subscriber has replaced.
    final download = _download(url, saved).whenComplete(() {
      _lookups.remove(url);
    });
    // There may be no listener yet (or the stale consumer may cancel).
    download.ignore();
    return (saved, download);
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
      final previousCheck = saved?.checkedAt;
      if (bytes.lengthInBytes > 8 * 1024 * 1024 ||
          (directives?.any((d) => d.trim() == 'no-store') ?? false)) {
        await _store.remove(url, previousCheck: previousCheck);
      } else {
        await _store.write(
          url,
          (bytes: bytes, checkedAt: _now().toUtc()),
          previousCheck: previousCheck,
        );
      }
    } catch (_) {
      // Quota or storage failure: the downloaded image can still be displayed.
    }
    return bytes;
  }
}
