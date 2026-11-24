import 'dart:typed_data';

typedef SavedPhoto = ({Uint8List bytes, DateTime checkedAt});

abstract interface class PhotoStore {
  Future<SavedPhoto?> read(Uri url);
  Future<void> write(Uri url, SavedPhoto photo);
  Future<void> remove(Uri url);
}
