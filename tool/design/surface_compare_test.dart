// Development-only pixel measurements for the fixture captures. No golden threshold:
// these metrics describe fixture differences, not active app navigation.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import '../verify_surface.dart';

const _width = 750;
const _height = 1624;
const _topInsetPx = 48 * 2;
const _bottomInsetPx = 34 * 2;

Future<ui.Image> _decode(String path) async {
  final file = File(path);
  if (!file.existsSync()) throw StateError('Missing PNG: $path');
  final codec = await ui.instantiateImageCodec(await file.readAsBytes());
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}

Future<Uint8List> _rgba(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) throw StateError('Cannot read decoded PNG pixels');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

Future<void> _saveHeatmap(String path, Uint8List pixels) async {
  final completed = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    _width,
    _height,
    ui.PixelFormat.rgba8888,
    completed.complete,
  );
  final image = await completed.future;
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Cannot encode heatmap: $path');
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  } finally {
    image.dispose();
  }
}

Future<void> _compare(String surface, String theme) async {
  final referencePath = surfaceReferencePath(surface, theme);
  final capturePath = surfaceCapturePath(surface, theme);
  final diffPath = surfaceDiffPath(surface, theme);
  // Direct test invocation must not leave an old heatmap on failure either.
  final oldDiff = File(diffPath);
  if (oldDiff.existsSync()) await oldDiff.delete();

  final reference = await _decode(referencePath);
  try {
    final captured = await _decode(capturePath);
    try {
      for (final (path, image) in [
        (referencePath, reference),
        (capturePath, captured)
      ]) {
        if (image.width != _width || image.height != _height) {
          throw StateError(
            '$path has ${image.width}x${image.height} pixels; expected ${_width}x$_height. '
            'Comparison requires exact dimensions, not overlapping crops.',
          );
        }
      }
      final expected = await _rgba(reference);
      final actual = await _rgba(captured);
      final heatmap = Uint8List(_width * _height * 4);
      var deltaTotal = 0;
      var over32 = 0;
      var count = 0;
      for (var y = _topInsetPx; y < _height - _bottomInsetPx; y++) {
        for (var x = 0; x < _width; x++) {
          final i = (y * _width + x) * 4;
          var delta = 0;
          for (var channel = 0; channel < 3; channel++) {
            final difference =
                (expected[i + channel] - actual[i + channel]).abs();
            if (difference > delta) delta = difference;
          }
          deltaTotal += delta;
          count++;
          if (delta > 32) over32++;
          heatmap[i] = delta;
          heatmap[i + 3] = 255;
        }
      }
      await _saveHeatmap(diffPath, heatmap);
      stdout.writeln(
        '$surface/$theme fixture vs Figma: mean max-channel Δ='
        '${(deltaTotal / count).toStringAsFixed(2)}/255; '
        'pixels Δ>32=${(100 * over32 / count).toStringAsFixed(2)}%; '
        'heatmap=$diffPath (excludes 48px top / 34px bottom logical insets)',
      );
    } finally {
      captured.dispose();
    }
  } finally {
    reference.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const surface = String.fromEnvironment('SURFACE', defaultValue: 'all');
  const theme = String.fromEnvironment('SURFACE_THEME', defaultValue: 'dark');
  if (surface != 'all' && !surfaceReferenceFrames.containsKey(surface)) {
    throw ArgumentError.value(
        surface, 'SURFACE', 'Expected a surface ID or all');
  }
  if (theme != 'dark' && theme != 'light' && theme != 'both') {
    throw ArgumentError.value(
        theme, 'SURFACE_THEME', 'Expected dark, light or both');
  }
  final surfaces = surface == 'all' ? surfaceReferenceFrames.keys : [surface];
  final themes = theme == 'both' ? ['dark', 'light'] : [theme];
  for (final t in themes) {
    for (final s in surfaces) {
      if (surfaceReferenceFrames[s] == null) {
        stdout.writeln('$s/$t: capture-only; no matching Figma frame.');
        continue;
      }
      test('fixture image difference: $s/$t', () => _compare(s, t));
    }
  }
}
