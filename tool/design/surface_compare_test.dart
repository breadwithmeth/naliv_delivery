// Development-only pixel measurements for the fixture captures. No golden threshold:
// these metrics describe fixture differences, not active app navigation.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import '../verify_surface.dart';
import 'surface_manifest.dart';

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

Future<void> _compare(
    String surface, String theme, SurfaceRunOptions options) async {
  final referencePath = surfaceReferencePath(surface, theme);
  final capturePath = surfaceCapturePath(surface, theme);
  final diffPath = surfaceDiffPath(surface, theme);
  final metricsPath = surfaceMetricsPath(surface, theme);

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
      // Remove only this pair's owned outputs after its inputs are validated.
      for (final outputPath in [diffPath, metricsPath]) {
        final oldOutput = File(outputPath);
        if (oldOutput.existsSync()) await oldOutput.delete();
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
      final meanDelta = deltaTotal / count;
      final percentOver32 = 100 * over32 / count;
      writeSurfaceJson(metricsPath, {
        'schemaVersion': 1,
        'complete': true,
        'surface': surface,
        'theme': theme,
        ...options.geometryJson,
        'pngDimensions': {'width': _width, 'height': _height},
        'referencePath': referencePath,
        'capturePath': capturePath,
        'diffPath': diffPath,
        'metrics': {
          'deltaDefinition': 'maximumAbsoluteRgbChannelDifference',
          'meanMaxChannelDelta': meanDelta,
          'pixelsOver32': over32,
          'percentOver32': percentOver32,
          'pixelCount': count,
          'excludedLogicalInsets': {'top': 48, 'bottom': 34},
        },
      });
      stdout.writeln(
        '$surface/$theme fixture vs Figma: mean max-channel Δ='
        '${meanDelta.toStringAsFixed(2)}/255; '
        'pixels Δ>32=${percentOver32.toStringAsFixed(2)}%; '
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
  final options = SurfaceRunOptions.fromEnvironment();
  if (options.captureOnly || !options.isReferenceGeometry) {
    throw ArgumentError(
        'Comparison is only available for reference-sized, unscaled captures without keyboard insets.');
  }
  final comparedPairs = [
    for (final pair in options.pairs)
      if (surfaceReferenceFrames[pair.$1] != null) pair,
  ];
  // A direct invocation must also finish preflight before deleting any heatmap.
  for (final (surface, theme) in comparedPairs) {
    for (final inputPath in [
      surfaceReferencePath(surface, theme),
      surfaceCapturePath(surface, theme),
    ]) {
      final dimensions = readSurfacePngDimensions(inputPath);
      if (dimensions != (_width, _height)) {
        throw FormatException(
            '$inputPath has ${dimensions.$1}x${dimensions.$2} pixels; '
            'expected ${_width}x$_height. Comparison cannot resize or crop inputs.');
      }
    }
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final (surface, theme) in comparedPairs) {
    test('fixture image difference: $surface/$theme',
        () => _compare(surface, theme, options));
  }
}
