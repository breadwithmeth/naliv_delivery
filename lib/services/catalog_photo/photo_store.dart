import 'dart:typed_data';

const photoRetention = Duration(days: 30);

typedef SavedPhoto = ({Uint8List bytes, DateTime checkedAt});

abstract interface class PhotoStore {
  /// Physically removes records validated at or before [through]. Implementations
  /// remember the next possible expiry so lookups do not scan the cache each time.
  Future<void> pruneExpired(DateTime through);

  Future<SavedPhoto?> read(Uri url);

  /// Writes a missing record or replaces the version the download read.
  Future<void> write(Uri url, SavedPhoto photo, {DateTime? previousCheck});

  /// Removes only the version the download read.
  Future<void> remove(Uri url, {DateTime? previousCheck});
}
