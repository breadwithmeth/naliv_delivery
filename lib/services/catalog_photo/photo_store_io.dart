import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'photo_store.dart';

final _nativeStore = DiskPhotoStore._temporary();

PhotoStore createPhotoStore() => _nativeStore;

Future<http.Response> fetchPhoto(Uri url) => http.get(url);

class DiskPhotoStore implements PhotoStore {
  DiskPhotoStore(Directory cacheDirectory) : _directory = cacheDirectory;
  DiskPhotoStore._temporary();

  static const _maxPhotoBytes = 8 * 1024 * 1024;
  static const _maxCacheBytes = 64 * 1024 * 1024;
  static const _maxDateTimeMicros = 8640000000000000000;
  static const _stagingName = '.pending-photo';
  static final _recordName = RegExp(r'^[0-9a-f]{64}\.photo$');

  // One versioned record keeps the check time and payload in the same rename.
  static const _magic = 0x43503031; // CP01
  static const _headerSize =
      16; // Magic, UTC epoch microseconds, payload length.

  Directory? _directory;
  Future<void> _pending = Future<void>.value();
  // Insertion order is oldest write first; rebuilt lazily, only before writing.
  final _sizes = <String, int>{};
  var _totalBytes = 0;
  var _indexed = false;

  @override
  Future<SavedPhoto?> read(Uri url) => _serialize(() async {
    final directory = await _cacheDirectory();
    final file = File(p.join(directory.path, _name(url)));
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return null;
    }

    try {
      final input = await file.open();
      try {
        final headerBytes = await input.read(_headerSize);
        if (headerBytes.length != _headerSize) return null;
        final header = ByteData.sublistView(headerBytes);
        if (header.getUint32(0) != _magic) return null;
        final checkedAt = header.getInt64(4);
        final length = header.getUint32(12);
        if (checkedAt < -_maxDateTimeMicros ||
            checkedAt > _maxDateTimeMicros ||
            length == 0 ||
            length > _maxPhotoBytes ||
            await input.length() != _headerSize + length) {
          return null;
        }
        final bytes = await input.read(length);
        if (bytes.length != length) return null;
        return (
          bytes: bytes,
          checkedAt: DateTime.fromMicrosecondsSinceEpoch(
            checkedAt,
            isUtc: true,
          ),
        );
      } finally {
        await input.close();
      }
    } on PathNotFoundException {
      // The OS may reclaim temporary files between operations.
      return null;
    }
  });

  @override
  Future<void> write(Uri url, SavedPhoto photo) {
    final length = photo.bytes.length;
    if (length == 0 || length > _maxPhotoBytes) return Future<void>.value();

    return _serialize(() async {
      final directory = await _cacheDirectory();
      await _ensureIndex(directory);
      final name = _name(url);
      final size = _headerSize + length;
      final staged = File(p.join(directory.path, _stagingName));
      await staged.create(exclusive: true);
      try {
        // Reserve room for the staged record without deleting the live copy.
        while (_totalBytes + size > _maxCacheBytes) {
          final oldest = _sizes.keys.firstWhere((entry) => entry != name);
          await _removeEntry(directory, oldest);
        }

        final header = ByteData(_headerSize)
          ..setUint32(0, _magic)
          ..setInt64(4, photo.checkedAt.microsecondsSinceEpoch)
          ..setUint32(12, length);
        final output = await staged.open(mode: FileMode.write);
        try {
          await output.writeFrom(header.buffer.asUint8List());
          await output.writeFrom(photo.bytes);
          await output.flush();
        } finally {
          await output.close();
        }
        await staged.rename(p.join(directory.path, name));
      } catch (_) {
        try {
          await _deleteIfPresent(staged);
        } on FileSystemException {
          // Retry cleaning up the orphan when the next write rebuilds the index.
          _indexed = false;
        }
        rethrow;
      }
      _totalBytes -= _sizes.remove(name) ?? 0;
      _sizes[name] = size;
      _totalBytes += size;
    });
  }

  @override
  Future<void> remove(Uri url) => _serialize(() async {
    await _removeEntry(await _cacheDirectory(), _name(url));
  });

  Future<Directory> _cacheDirectory() async => _directory ??= Directory(
    p.join((await getTemporaryDirectory()).path, 'naliv_catalog_photos_v1'),
  );

  static String _name(Uri url) =>
      '${sha256.convert(utf8.encode('$url'))}.photo';

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _ensureIndex(Directory directory) async {
    if (_indexed && await directory.exists()) return;
    await directory.create(recursive: true);
    final entries = <({String name, int size, DateTime modified})>[];
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File) continue;
      final name = p.basename(entry.path);
      if (name == _stagingName) {
        await _deleteIfPresent(entry);
      } else if (_recordName.hasMatch(name)) {
        final stat = await entry.stat();
        if (stat.type != FileSystemEntityType.file) continue;
        if (stat.size <= _headerSize ||
            stat.size > _headerSize + _maxPhotoBytes) {
          await _deleteIfPresent(entry);
          continue;
        }
        entries.add((name: name, size: stat.size, modified: stat.modified));
      }
    }
    entries.sort((a, b) => a.modified.compareTo(b.modified));
    _sizes.clear();
    _totalBytes = 0;
    for (final entry in entries) {
      _sizes[entry.name] = entry.size;
      _totalBytes += entry.size;
    }
    _indexed = true;
  }

  Future<void> _removeEntry(Directory directory, String name) async {
    await _deleteIfPresent(File(p.join(directory.path, name)));
    _totalBytes -= _sizes.remove(name) ?? 0;
  }

  static Future<void> _deleteIfPresent(File file) async {
    try {
      await file.delete();
    } on PathNotFoundException {
      // Absent files are already removed.
    }
  }
}
