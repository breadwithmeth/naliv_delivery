import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'photo_store.dart';

typedef _PhotoHeader = ({int checkedAt, int length});
typedef _DiskEntry = ({int checkedAt, int size});

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
  // Insertion order remains oldest write first for capacity eviction.
  final _entries = <String, _DiskEntry>{};
  int? _nextCheck;
  var _totalBytes = 0;
  var _indexed = false;

  static final _idle = Future<void>.value();

  bool _needsPrune(int cutoff) =>
      !_indexed || (_nextCheck != null && _nextCheck! <= cutoff);

  @override
  Future<void> pruneExpired(DateTime through) {
    final cutoff = through.microsecondsSinceEpoch;
    if (!_needsPrune(cutoff)) return _idle;
    return _serialize(() async {
      if (!_needsPrune(cutoff)) return;
      final directory = await _cacheDirectory();
      await _ensureIndex(directory);
      final expired = <String>[];
      int? next;
      for (final entry in _entries.entries) {
        final check = entry.value.checkedAt;
        if (check <= cutoff) {
          expired.add(entry.key);
        } else if (next == null || check < next) {
          next = check;
        }
      }
      for (final name in expired) {
        await _removeEntry(directory, name);
      }
      _nextCheck = next;
    });
  }

  void _rememberCheck(int checkedAt) {
    if (_nextCheck == null || checkedAt < _nextCheck!) {
      _nextCheck = checkedAt;
    }
  }

  @override
  Future<SavedPhoto?> read(Uri url) => _serialize(() async {
    final directory = await _cacheDirectory();
    final name = _name(url);
    final file = File(p.join(directory.path, name));
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      _forget(name);
      return null;
    }

    try {
      final input = await file.open();
      try {
        final header = await _readHeader(input);
        if (header != null) {
          final (:checkedAt, :length) = header;
          final bytes = await input.read(length);
          if (bytes.length == length) {
            return (
              bytes: bytes,
              checkedAt: DateTime.fromMicrosecondsSinceEpoch(
                checkedAt,
                isUtc: true,
              ),
            );
          }
        }
      } finally {
        await input.close();
      }
      await _removeEntry(directory, name);
    } on PathNotFoundException {
      // The OS may reclaim temporary files between operations.
      _forget(name);
    }
    return null;
  });

  static Future<_PhotoHeader?> _readHeader(
    RandomAccessFile input, {
    int? fileSize,
  }) async {
    final bytes = await input.read(_headerSize);
    if (bytes.length != _headerSize) return null;
    final header = ByteData.sublistView(bytes);
    if (header.getUint32(0) != _magic) return null;
    final checkedAt = header.getInt64(4);
    final length = header.getUint32(12);
    if (checkedAt < -_maxDateTimeMicros ||
        checkedAt > _maxDateTimeMicros ||
        length == 0 ||
        length > _maxPhotoBytes ||
        (fileSize ?? await input.length()) != _headerSize + length) {
      return null;
    }
    return (checkedAt: checkedAt, length: length);
  }

  @override
  Future<void> write(Uri url, SavedPhoto photo, {DateTime? previousCheck}) {
    final length = photo.bytes.length;
    if (length == 0 || length > _maxPhotoBytes) return Future<void>.value();

    return _serialize(() async {
      final directory = await _cacheDirectory();
      await _ensureIndex(directory);
      final name = _name(url);
      final current = _entries[name];
      if (current != null &&
          current.checkedAt != previousCheck?.microsecondsSinceEpoch) {
        return;
      }
      final size = _headerSize + length;
      final checkedAt = photo.checkedAt.microsecondsSinceEpoch;
      final staged = File(p.join(directory.path, _stagingName));
      await staged.create(exclusive: true);
      try {
        // Reserve room for the staged record without deleting the live copy.
        while (_totalBytes + size > _maxCacheBytes) {
          final oldest = _entries.keys.firstWhere((entry) => entry != name);
          await _removeEntry(directory, oldest);
        }

        final header = ByteData(_headerSize)
          ..setUint32(0, _magic)
          ..setInt64(4, checkedAt)
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
      _totalBytes -= _entries.remove(name)?.size ?? 0;
      _entries[name] = (checkedAt: checkedAt, size: size);
      _totalBytes += size;
      _rememberCheck(checkedAt);
    });
  }

  @override
  Future<void> remove(Uri url, {DateTime? previousCheck}) {
    if (previousCheck == null) return _idle;
    return _serialize(() async {
      final directory = await _cacheDirectory();
      await _ensureIndex(directory);
      final name = _name(url);
      if (_entries[name]?.checkedAt == previousCheck.microsecondsSinceEpoch) {
        await _removeEntry(directory, name);
      }
    });
  }

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
    final entries = <({String name, _DiskEntry record, DateTime modified})>[];
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File) continue;
      final name = p.basename(entry.path);
      if (name == _stagingName) {
        await _deleteIfPresent(entry);
      } else if (_recordName.hasMatch(name)) {
        try {
          final stat = await entry.stat();
          if (stat.type != FileSystemEntityType.file) continue;
          final input = await entry.open();
          final _PhotoHeader? header;
          try {
            header = await _readHeader(input, fileSize: stat.size);
          } finally {
            await input.close();
          }
          if (header == null) {
            await _deleteIfPresent(entry);
            continue;
          }
          entries.add((
            name: name,
            record: (checkedAt: header.checkedAt, size: stat.size),
            modified: stat.modified,
          ));
        } on PathNotFoundException {
          // The OS may reclaim temporary files between operations.
        }
      }
    }
    entries.sort((a, b) => a.modified.compareTo(b.modified));
    _entries.clear();
    _nextCheck = null;
    _totalBytes = 0;
    for (final entry in entries) {
      _entries[entry.name] = entry.record;
      _totalBytes += entry.record.size;
      _rememberCheck(entry.record.checkedAt);
    }
    _indexed = true;
  }

  Future<void> _removeEntry(Directory directory, String name) async {
    await _deleteIfPresent(File(p.join(directory.path, name)));
    _forget(name);
  }

  void _forget(String name) {
    _totalBytes -= _entries.remove(name)?.size ?? 0;
  }

  static Future<void> _deleteIfPresent(File file) async {
    try {
      await file.delete();
    } on PathNotFoundException {
      // Absent files are already removed.
    }
  }
}
