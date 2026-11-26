import 'dart:js_interop';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import 'photo_store.dart';

const _defaultCacheName = 'naliv-catalog-photos-v1';
const _checkedAtHeader = 'x-catalog-photo-checked-at-us';
const _maxEntries = 128;
const _maxPhotoBytes = 8 * 1024 * 1024;
const _maxDateTimeMicros = 8640000000000000000;

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

@JS()
extension type _LockingNavigator(JSObject _) implements JSObject {
  external web.LockManager? get locks;
}

class _WebPhotoStore implements PhotoStore {
  _WebPhotoStore(this._cacheName);

  final String _cacheName;
  Future<void> _pending = Future<void>.value();
  int? _nextCheck;
  static final _idle = Future<void>.value();

  Future<web.Cache> _open() => web.window.caches.open(_cacheName).toDart;

  // Serialize the multi-step Cache Storage mutations, across tabs when Web
  // Locks is available. A sweep must not delete a replacement after matching
  // its previous expired response.
  Future<void> _mutate(Future<void> Function() action) {
    final result = _pending.then((_) async {
      final locks = _LockingNavigator(web.window.navigator).locks;
      if (locks == null) {
        await action();
        return;
      }
      Future<JSAny?> run() async {
        await action();
        return null;
      }

      await locks.request(_cacheName, (() => run().toJS).toJS).toDart;
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static int? _checkedAt(web.Response response) {
    final timestamp = response.headers.get(_checkedAtHeader);
    final checkedAt = timestamp == null ? null : int.tryParse(timestamp);
    return checkedAt != null && checkedAt.abs() <= _maxDateTimeMicros
        ? checkedAt
        : null;
  }

  bool _needsPrune(int cutoff) => _nextCheck == null || _nextCheck! <= cutoff;

  @override
  Future<void> pruneExpired(DateTime through) {
    final cutoff = through.microsecondsSinceEpoch;
    if (!_needsPrune(cutoff)) return _idle;
    return _mutate(() async {
      if (!_needsPrune(cutoff)) return;
      final cache = await _open();
      // Even an empty scan has a deadline: another tab may add newer records.
      var nextCheck = through.add(photoRetention).microsecondsSinceEpoch;
      final keys = (await cache.keys().toDart).toDart;
      for (final key in keys) {
        final response = await cache.match(key).toDart;
        if (response == null) continue;
        final checkedAt = _checkedAt(response);
        if (checkedAt == null || checkedAt <= cutoff) {
          await cache.delete(key).toDart;
        } else if (checkedAt < nextCheck) {
          nextCheck = checkedAt;
        }
      }
      _nextCheck = nextCheck;
    });
  }

  @override
  Future<SavedPhoto?> read(Uri url) async {
    final cache = await _open();
    final response = await cache.match(url.toString().toJS).toDart;
    if (response == null) return null;
    final checkedAt = _checkedAt(response);
    if (checkedAt == null) return null;
    return (
      bytes: await _readBytes(response),
      checkedAt: DateTime.fromMicrosecondsSinceEpoch(checkedAt, isUtc: true),
    );
  }

  @override
  Future<void> write(Uri url, SavedPhoto photo, {DateTime? previousCheck}) {
    if (photo.bytes.isEmpty || photo.bytes.length > _maxPhotoBytes) {
      return _idle;
    }
    return _mutate(() async {
      final cache = await _open();
      final key = url.toString().toJS;
      final current = await cache.match(key).toDart;
      final currentCheck = current == null ? null : _checkedAt(current);
      if (currentCheck != null &&
          currentCheck != previousCheck?.microsecondsSinceEpoch) {
        return;
      }
      final checkedAt = photo.checkedAt.microsecondsSinceEpoch;
      final headers = web.Headers()..set(_checkedAtHeader, '$checkedAt');
      final response = web.Response(
        photo.bytes.toJS,
        web.ResponseInit(headers: headers),
      );
      await cache.put(key, response).toDart;
      if (_nextCheck != null && checkedAt < _nextCheck!) _nextCheck = checkedAt;

      // Cache Storage returns keys in insertion order.
      final keys = (await cache.keys().toDart).toDart;
      final excess = keys.length - _maxEntries;
      for (var i = 0; i < excess; i++) {
        await cache.delete(keys[i]).toDart;
      }
    });
  }

  @override
  Future<void> remove(Uri url, {DateTime? previousCheck}) {
    if (previousCheck == null) return _idle;
    return _mutate(() async {
      final cache = await _open();
      final key = url.toString().toJS;
      final current = await cache.match(key).toDart;
      if (current != null &&
          _checkedAt(current) == previousCheck.microsecondsSinceEpoch) {
        await cache.delete(key).toDart;
      }
    });
  }
}
