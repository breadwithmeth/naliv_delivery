import 'dart:typed_data';

/// Interprets a 4×2 RGBA read-back of adjacent reference/shader patches.
///
/// Either patch may come first. Storage row order reverses both patches, so
/// their relative orientation determines whether the shader needs correction.
bool sceneSamplerNeedsYFlip(ByteData pixels) {
  final firstTop = _marker(pixels, 0);
  final secondTop = _marker(pixels, 8);
  final firstBottom = _marker(pixels, 16);
  final secondBottom = _marker(pixels, 24);
  if (firstTop == firstBottom || secondTop == secondBottom) {
    throw StateError(
      'The scene orientation probe did not preserve two '
      'distinct rows in both the reference and shader patches.',
    );
  }
  return firstTop != secondTop;
}

int _marker(ByteData pixels, int offset) {
  final red = pixels.getUint8(offset);
  final blue = pixels.getUint8(offset + 2);
  if (red > 192 && blue < 64) return 1;
  if (blue > 192 && red < 64) return -1;
  throw StateError(
    'The scene orientation probe returned neither a red nor '
    'a blue marker at byte $offset: r=$red b=$blue.',
  );
}
