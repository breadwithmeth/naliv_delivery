import 'dart:js_interop';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import 'photo_store.dart';

const _defaultCacheName = 'naliv-catalog-photos-v1';
const _checkedAtHeader = 'x-catalog-photo-checked-at-us';
const _maxEntries = 128;
const _maxPhotoBytes = 8 * 1024 * 1024;

PhotoStore createPhotoStore({String cacheName = _defaultCacheName}) =>
    _WebPhotoStore(cacheName);

Future<http.Response> fetchPhoto(Uri url) async {
  // Let the browser revalidate its HTTP cache without adding request headers
  // that would require the CDN to support a CORS preflight.
  final response = await web.window
      .fetch(
        url.toString().toJS,
        web.RequestInit(credentials: 'omit', cache: 'no-cache'),
      )
      .toDart;
  final headers = <String, String>{};
  _IterableHeaders(response.headers).forEach(
    (String value, String name) {
      headers[name] = value;
    }.toJS,
  );
  return http.Response.bytes(
    await _readBytes(response),
    response.status,
    headers: headers,
    reasonPhrase: response.statusText,
  );
}

Future<Uint8List> _readBytes(web.Response response) async {
  final buffer = await response.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

// package:web does not expose Headers' iterable methods.
@JS()
extension type _IterableHeaders(JSObject _) implements JSObject {
  external void forEach(JSFunction callback);
}

class _WebPhotoStore implements PhotoStore {
  _WebPhotoStore(this._cacheName);

  final String _cacheName;

  Future<web.Cache> _open() => web.window.caches.open(_cacheName).toDart;

  @override
  Future<SavedPhoto?> read(Uri url) async {
    final cache = await _open();
    final response = await cache.match(url.toString().toJS).toDart;
    if (response == null) return null;
    final timestamp = response.headers.get(_checkedAtHeader);
    final checkedAt = timestamp == null ? null : int.tryParse(timestamp);
    if (checkedAt == null) return null;
    return (
      bytes: await _readBytes(response),
      checkedAt: DateTime.fromMicrosecondsSinceEpoch(checkedAt, isUtc: true),
    );
  }

  @override
  Future<void> write(Uri url, SavedPhoto photo) async {
    if (photo.bytes.length > _maxPhotoBytes) return;
    final cache = await _open();
    final headers = web.Headers();
    headers.set(_checkedAtHeader, '${photo.checkedAt.microsecondsSinceEpoch}');
    final response = web.Response(
      photo.bytes.toJS,
      web.ResponseInit(headers: headers),
    );
    await cache.put(url.toString().toJS, response).toDart;

    // Cache Storage returns keys in insertion order.
    final keys = (await cache.keys().toDart).toDart;
    final excess = keys.length - _maxEntries;
    for (var i = 0; i < excess; i++) {
      await cache.delete(keys[i]).toDart;
    }
  }

  @override
  Future<void> remove(Uri url) async {
    final cache = await _open();
    await cache.delete(url.toString().toJS).toDart;
  }
}
