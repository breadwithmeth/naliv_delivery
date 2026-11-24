import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../services/catalog_photo/catalog_photo_cache.dart';
import '../services/catalog_photo/photo_store_io.dart'
    if (dart.library.js_interop) '../services/catalog_photo/photo_store_web.dart'
    as platform;

final _cache = CatalogPhotoCache(
  platform.createPhotoStore(),
  platform.fetchPhoto,
);

/// Flutter keeps decoded images by size; the persistent cache keeps one original
/// per public URL. Inline fixture artwork never enters persistent storage.
ImageProvider catalogPhotoProvider(
  String source, {
  int? cacheWidth,
  int? cacheHeight,
}) {
  if (!source.startsWith('https://') && !source.startsWith('http://')) {
    return ResizeImage.resizeIfNeeded(
      cacheWidth,
      cacheHeight,
      NetworkImage(source),
    );
  }
  final url = Uri.tryParse(source);
  if (url == null || url.host.isEmpty || url.userInfo.isNotEmpty) {
    return ResizeImage.resizeIfNeeded(
      cacheWidth,
      cacheHeight,
      NetworkImage(source),
    );
  }
  final epoch =
      DateTime.now().millisecondsSinceEpoch ~/
      CatalogPhotoCache.freshness.inMilliseconds;
  late final ImageProvider result;
  result = ResizeImage.resizeIfNeeded(
    cacheWidth,
    cacheHeight,
    _CatalogPhoto((url, epoch), () {
      unawaited(result.evict());
    }),
  );
  return result;
}

typedef _PhotoKey = (Uri, int);

class _CatalogPhoto extends ImageProvider<_PhotoKey> {
  const _CatalogPhoto(this._key, this._evict);
  final _PhotoKey _key;
  final VoidCallback _evict;

  @override
  Future<_PhotoKey> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(_key);

  @override
  ImageStreamCompleter loadImage(_PhotoKey key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(key.$1, decode), scale: 1);

  Future<ui.Codec> _load(Uri url, ImageDecoderCallback decode) async {
    final images = StreamIterator(_cache.images(url));
    try {
      await images.moveNext();
      final bytes = images.current;
      // Paint the local copy now. If revalidation replaces it, the next lookup
      // must not reuse Flutter's decoded copy of the previous version.
      unawaited(_finishRefresh(images));
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (_) {
      _evict();
      rethrow;
    }
  }

  Future<void> _finishRefresh(StreamIterator<Uint8List> images) async {
    try {
      if (await images.moveNext()) _evict();
    } finally {
      await images.cancel();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _CatalogPhoto && other._key == _key;
  @override
  int get hashCode => _key.hashCode;
}
