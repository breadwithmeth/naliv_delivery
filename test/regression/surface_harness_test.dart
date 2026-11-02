import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import '../../tool/verify_surface.dart';

void main() {
  test('equivalent adaptive numbers select one isolated artifact variant', () {
    final options = SurfaceRunOptions.parse([
      'catalog,checkout_pickup',
      '--theme=both',
      '--capture-only',
      '--width=320',
      '--text-scale=2',
      '--keyboard=300',
    ]);
    final equivalent = SurfaceRunOptions.parse([
      'catalog',
      '--capture-only',
      '--width',
      '3.2e2',
      '--text-scale',
      '2.0',
      '--keyboard',
      '300.0',
    ]);
    expect(options.artifactDirectory, equivalent.artifactDirectory);
    expect(options.captureOnly, isTrue);
    expect(options.isReferenceGeometry, isFalse);
    expect(options.pixelWidth, 640);
    expect(options.pixelHeight, 1624);
    expect(surfaceCapturePath('catalog', 'dark', options: options),
        isNot(surfaceCapturePath('catalog', 'dark')));
    expect(
        SurfaceRunOptions.parse(['--capture-only', '--keyboard=-0'])
            .isReferenceGeometry,
        isTrue);
    expect(
        SurfaceRunOptions.parse(['--capture-only', '--width=375.25'])
            .pixelWidth,
        751);
  });

  final invalidArguments = <List<String>>[
    ['unknown'],
    ['catalog,'],
    ['catalog,catalog'],
    ['all,catalog'],
    ['all,all'],
    ['catalog', 'cart'],
    ['--unknown'],
    ['--theme'],
    ['--theme='],
    ['--theme=unknown'],
    ['--theme=both', '--theme', 'dark'],
    ['--capture-only', '--capture-only'],
    ['--capture-only=true'],
    ['--width'],
    ['--capture-only', '--width=320', '--width=375'],
    ['--capture-only', '--width=0'],
    ['--capture-only', '--width=-1'],
    ['--capture-only', '--width=NaN'],
    ['--capture-only', '--width=Infinity'],
    ['--capture-only', '--width=1e309'],
    ['--capture-only', '--width=1e100'],
    ['--capture-only', '--text-scale=0'],
    ['--capture-only', '--text-scale=-1'],
    ['--capture-only', '--text-scale=NaN'],
    ['--capture-only', '--text-scale=Infinity'],
    ['--capture-only', '--text-scale=1', '--text-scale=2'],
    ['--capture-only', '--keyboard=-1'],
    ['--capture-only', '--keyboard=NaN'],
    ['--capture-only', '--keyboard=Infinity'],
    ['--capture-only', '--keyboard=0', '--keyboard=300'],
    ['--width=320'],
    ['--text-scale=2'],
    ['--keyboard=300'],
  ];
  for (final args in invalidArguments) {
    test('rejects unsafe arguments ${args.join(' ')}', () {
      expect(() => SurfaceRunOptions.parse(args), throwsFormatException);
    });
  }

  group('artifact safety', () {
    late Directory root;
    setUp(() {
      root = Directory.systemTemp.createTempSync('surface_harness_');
      _put(root, 'pubspec.yaml', utf8.encode('name: fixture_test\n'));
      _put(
          root,
          path.join('assets', 'fonts', 'TikTokSans', 'TikTokSans-Variable.ttf'),
          [0]);
    });
    tearDown(() => root.deleteSync(recursive: true));

    test('usage errors neither invoke Flutter nor touch existing artifacts',
        () async {
      final owned = [
        surfaceCapturePath('catalog', 'dark'),
        surfaceDiffPath('catalog', 'dark'),
        surfaceMetricsPath('catalog', 'dark'),
        surfaceReferencePath('catalog', 'dark'),
        surfaceCapturePath('cart', 'light'),
      ];
      for (final file in owned) {
        _put(root, file, utf8.encode('preserve'));
      }
      var calls = 0;
      final status = await runSurfaceVerification([
        'catalog',
        '--capture-only',
        '--width=NaN',
      ], workingDirectory: root.path, flutterTestRunner: (_, __, ___) async {
        calls++;
        return 0;
      });
      expect(status, 64);
      expect(calls, 0);
      for (final file in owned) {
        expect(_file(root, file).readAsStringSync(), 'preserve');
      }
    });

    test('missing references fail preflight without deleting selected captures',
        () async {
      final options = SurfaceRunOptions.parse([
        'catalog,all_products',
        '--theme=both',
      ]);
      final stale = [
        for (final (surface, theme) in options.pairs) ...[
          surfaceCapturePath(surface, theme),
          surfaceDiffPath(surface, theme),
          surfaceMetricsPath(surface, theme),
        ],
      ];
      for (final file in stale) {
        _put(root, file, utf8.encode('preserve'));
      }
      var calls = 0;
      final status = await runSurfaceVerification([
        'catalog,all_products',
        '--theme=both',
      ], workingDirectory: root.path, flutterTestRunner: (_, __, ___) async {
        calls++;
        return 0;
      });
      expect(status, 66);
      expect(calls, 0);
      for (final file in stale) {
        expect(_file(root, file).readAsStringSync(), 'preserve');
      }
    });

    test('wrong reference dimensions fail before deleting any selected output',
        () async {
      final reference = surfaceReferencePath('catalog', 'dark');
      final current = surfaceCapturePath('catalog', 'dark');
      final diff = surfaceDiffPath('catalog', 'dark');
      _put(root, reference, _png(1, 1));
      _put(root, current, utf8.encode('preserve capture'));
      _put(root, diff, utf8.encode('preserve diff'));
      var calls = 0;
      final status = await runSurfaceVerification(['catalog'],
          workingDirectory: root.path, flutterTestRunner: (_, __, ___) async {
        calls++;
        return 0;
      });
      expect(status, 65);
      expect(calls, 0);
      expect(_file(root, current).readAsStringSync(), 'preserve capture');
      expect(_file(root, diff).readAsStringSync(), 'preserve diff');
      expect(readSurfacePngDimensions(_file(root, reference).path), (1, 1));
    });

    test(
        'adaptive capture owns only its selected variant and reports no metrics',
        () async {
      final args = [
        'catalog,checkout_pickup',
        '--theme=both',
        '--capture-only',
        '--width=320',
        '--text-scale=2',
        '--keyboard=300',
      ];
      final options = SurfaceRunOptions.parse(args);
      final preserved = [
        for (final (surface, theme) in options.pairs) ...[
          surfaceCapturePath(surface, theme),
          surfaceDiffPath(surface, theme),
          surfaceMetricsPath(surface, theme),
          surfaceReferencePath(surface, theme),
        ],
        surfaceCapturePath('cart', 'dark', options: options),
        path.join(options.artifactDirectory, 'runs', 'previous.json'),
      ];
      for (final file in preserved) {
        _put(root, file, utf8.encode('preserve'));
      }
      for (final (surface, theme) in options.pairs) {
        _put(root, surfaceDiffPath(surface, theme, options: options), [1]);
        _put(root, surfaceMetricsPath(surface, theme, options: options), [1]);
      }
      final png = _png(options.pixelWidth, options.pixelHeight);
      var calls = 0;
      final status =
          await runSurfaceVerification(args, workingDirectory: root.path,
              flutterTestRunner: (_, defines, workingDirectory) async {
        calls++;
        for (final (surface, theme) in options.pairs) {
          _put(root, surfaceCapturePath(surface, theme, options: options), png);
        }
        return 0;
      });
      expect(status, 0);
      expect(calls, 1);
      for (final file in preserved) {
        expect(_file(root, file).readAsStringSync(), 'preserve');
      }
      for (final (surface, theme) in options.pairs) {
        expect(
            _file(root, surfaceDiffPath(surface, theme, options: options))
                .existsSync(),
            isFalse);
        expect(
            _file(root, surfaceMetricsPath(surface, theme, options: options))
                .existsSync(),
            isFalse);
      }
      final evidence = _runEvidence(root, options);
      expect(evidence['complete'], isTrue);
      expect(evidence['captureOnly'], isTrue);
      expect(evidence['referenceGeometry'], isFalse);
      final artifacts = (evidence['artifacts'] as List).cast<Map>();
      expect(artifacts, hasLength(options.pairs.length));
      for (final artifact in artifacts) {
        expect(artifact['captureStatus'], 'validated');
        expect(artifact['pngDimensions'], {'width': 640, 'height': 1624});
        expect(artifact['comparisonStatus'], 'notRequested');
        expect(artifact.containsKey('comparison'), isFalse);
        expect((artifact['insets'] as Map)['viewInsets'],
            {'top': 0, 'bottom': 300, 'left': 0, 'right': 0});
      }
    });

    test('comparison success without fresh metrics cannot publish complete',
        () async {
      final args = ['catalog', '--theme=both'];
      final options = SurfaceRunOptions.parse(args);
      final png = _png(options.pixelWidth, options.pixelHeight);
      for (final (surface, theme) in options.pairs) {
        _put(root, surfaceReferencePath(surface, theme), png);
        _put(root, surfaceDiffPath(surface, theme), png);
        _put(root, surfaceMetricsPath(surface, theme),
            utf8.encode('{"complete":true}'));
      }
      var calls = 0;
      final status = await runSurfaceVerification(args,
          workingDirectory: root.path, flutterTestRunner: (_, __, ___) async {
        calls++;
        if (calls == 1) {
          for (final (surface, theme) in options.pairs) {
            _put(root, surfaceCapturePath(surface, theme), png);
          }
        }
        return 0;
      });
      expect(status, 66);
      expect(calls, 2);
      final evidence = _runEvidence(root, options);
      expect(evidence['complete'], isFalse);
      for (final artifact in (evidence['artifacts'] as List).cast<Map>()) {
        expect(artifact['captureStatus'], 'validated');
        expect(artifact['comparisonStatus'], 'notProduced');
        expect(artifact.containsKey('comparison'), isFalse);
      }
      for (final (surface, theme) in options.pairs) {
        expect(_file(root, surfaceMetricsPath(surface, theme)).existsSync(),
            isFalse);
        expect(
            _file(root, surfaceDiffPath(surface, theme)).existsSync(), isFalse);
      }
    });

    test('failed captures cannot publish complete or fabricated measurements',
        () async {
      final args = ['catalog', '--capture-only', '--width=320'];
      final options = SurfaceRunOptions.parse(args);
      var calls = 0;
      final status = await runSurfaceVerification(args,
          workingDirectory: root.path, flutterTestRunner: (_, __, ___) async {
        calls++;
        return 1;
      });
      expect(status, 1);
      expect(calls, 1);
      final evidence = _runEvidence(root, options);
      expect(evidence['complete'], isFalse);
      final artifact = (evidence['artifacts'] as List).single as Map;
      expect(artifact['captureStatus'], 'missing');
      expect(artifact.containsKey('pngDimensions'), isFalse);
      expect(artifact.containsKey('comparison'), isFalse);
    });

    test('a successful runner with wrong PNG dimensions is still a failed run',
        () async {
      final args = ['catalog', '--capture-only', '--width=320'];
      final options = SurfaceRunOptions.parse(args);
      var calls = 0;
      final status = await runSurfaceVerification(args,
          workingDirectory: root.path, flutterTestRunner: (_, __, ___) async {
        calls++;
        _put(root, surfaceCapturePath('catalog', 'dark', options: options),
            _png(1, 1));
        return 0;
      });
      expect(status, 65);
      expect(calls, 1);
      final evidence = _runEvidence(root, options);
      expect(evidence['complete'], isFalse);
      final artifact = (evidence['artifacts'] as List).single as Map;
      expect(artifact['captureStatus'], 'invalid');
      expect(artifact.containsKey('comparison'), isFalse);
    });
  });
}

File _file(Directory root, String relativePath) =>
    File(path.join(root.path, relativePath));

void _put(Directory root, String relativePath, List<int> bytes) {
  final file = _file(root, relativePath);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
}

Map<String, dynamic> _runEvidence(Directory root, SurfaceRunOptions options) {
  final files =
      Directory(path.join(root.path, options.artifactDirectory, 'runs'))
          .listSync()
          .whereType<File>()
          .where((file) => path.extension(file.path) == '.json');
  return files
      .map((file) {
        try {
          return jsonDecode(file.readAsStringSync());
        } on FormatException {
          return null;
        }
      })
      .whereType<Map<String, dynamic>>()
      .singleWhere((value) => value['kind'] == 'strictFixtureSurfaceRun');
}

// Valid transparent PNGs keep these filesystem safety tests independent of Flutter.
Uint8List _png(int width, int height) {
  final output = BytesBuilder(copy: false)
    ..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> bytes) {
    final payload = Uint8List.fromList([...ascii.encode(type), ...bytes]);
    var crc = 0xffffffff;
    for (final byte in payload) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    output
      ..add((ByteData(4)..setUint32(0, bytes.length)).buffer.asUint8List())
      ..add(payload)
      ..add((ByteData(4)..setUint32(0, crc ^ 0xffffffff)).buffer.asUint8List());
  }

  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 6);
  chunk('IHDR', header.buffer.asUint8List());
  chunk('IDAT', ZLibEncoder().convert(Uint8List(height * (1 + width * 4))));
  chunk('IEND', []);
  return output.takeBytes();
}
