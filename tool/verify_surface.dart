// Development-only fixture capture and comparison. Never launches the real app.
// Usage: dart run tool/verify_surface.dart [surface,...|all] [options]
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;

import 'design/surface_manifest.dart';

String surfaceReferencePath(String surface, String theme) {
  final frame = surfaceReferenceFrames[surface];
  if (frame == null || (theme != 'dark' && theme != 'light')) {
    throw ArgumentError('Unknown surface/theme: $surface/$theme');
  }
  final page = theme == 'dark' ? 'Dark' : 'Light';
  return path.join(
      '.figma_cache', 'shots', 'Design_System__${page}___${frame.trim()}.png');
}

String surfaceCapturePath(String surface, String theme,
        {SurfaceRunOptions? options}) =>
    path.join(options?.artifactDirectory ?? _renderDirectory,
        'current_${surface}_$theme.png');

String surfaceDiffPath(String surface, String theme,
        {SurfaceRunOptions? options}) =>
    path.join(options?.artifactDirectory ?? _renderDirectory,
        'diff_${surface}_$theme.png');

String surfaceMetricsPath(String surface, String theme,
        {SurfaceRunOptions? options}) =>
    path.join(options?.artifactDirectory ?? _renderDirectory,
        'metrics_${surface}_$theme.json');

final _renderDirectory = path.join('.figma_cache', 'render');

class SurfaceRunOptions {
  SurfaceRunOptions._({
    required this.surfaces,
    required this.themes,
    required this.captureOnly,
    required this.width,
    required this.textScale,
    required this.keyboard,
    required this.showHelp,
  });

  static const referenceWidth = 375.0;
  static const height = 812.0;
  static const devicePixelRatio = 2.0;
  static const topInset = 48.0;
  static const bottomInset = 34.0;

  final List<String> surfaces;
  final List<String> themes;
  final bool captureOnly;
  final double width;
  final double textScale;
  final double keyboard;
  final bool showHelp;

  bool get isReferenceGeometry =>
      width == referenceWidth && textScale == 1 && keyboard == 0;
  int get pixelWidth => (width * devicePixelRatio).ceil();
  int get pixelHeight => (height * devicePixelRatio).ceil();

  String get artifactDirectory => isReferenceGeometry
      ? _renderDirectory
      : path.join(_renderDirectory, 'variants',
          'width_${width}__text_${textScale}__keyboard_$keyboard');

  List<(String, String)> get pairs => [
        for (final theme in themes)
          for (final surface in surfaces) (surface, theme),
      ];

  List<String> get dartDefines => [
        '--dart-define=SURFACE=${surfaces.join(',')}',
        '--dart-define=SURFACE_THEME=${themes.length == 2 ? 'both' : themes.single}',
        '--dart-define=SURFACE_CAPTURE_ONLY=$captureOnly',
        '--dart-define=SURFACE_WIDTH=$width',
        '--dart-define=SURFACE_TEXT_SCALE=$textScale',
        '--dart-define=SURFACE_KEYBOARD=$keyboard',
      ];

  Map<String, Object> get geometryJson => {
        'viewport': {
          'width': width,
          'height': height,
          'devicePixelRatio': devicePixelRatio,
        },
        'expectedPngDimensions': {
          'width': pixelWidth,
          'height': pixelHeight,
        },
        'textScaler': {'type': 'linear', 'scale': textScale},
        'insets': {
          'viewPadding': {
            'top': topInset,
            'bottom': bottomInset,
            'left': 0,
            'right': 0
          },
          'padding': {
            'top': topInset,
            'bottom': keyboard > 0 ? 0 : bottomInset,
            'left': 0,
            'right': 0,
          },
          'viewInsets': {'top': 0, 'bottom': keyboard, 'left': 0, 'right': 0},
        },
      };

  factory SurfaceRunOptions.parse(List<String> args) {
    var selection = 'all';
    var theme = 'dark';
    var width = referenceWidth;
    var textScale = 1.0;
    var keyboard = 0.0;
    var captureOnly = false;
    var showHelp = false;
    var hasSelection = false;
    final provided = <String>{};
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (!arg.startsWith('-')) {
        if (hasSelection) {
          throw const FormatException(
              'Only one comma-separated surface selection is allowed.');
        }
        hasSelection = true;
        selection = arg;
        continue;
      }
      final equals = arg.indexOf('=');
      final option = equals < 0 ? arg : arg.substring(0, equals);
      final normalized = option == '-h' ? '--help' : option;
      if (!{
        '--theme',
        '--capture-only',
        '--width',
        '--text-scale',
        '--keyboard',
        '--help',
      }.contains(normalized)) {
        throw FormatException('Unknown option: $option');
      }
      if (!provided.add(normalized)) {
        throw FormatException('Duplicate $normalized');
      }
      if (normalized == '--capture-only' || normalized == '--help') {
        if (equals >= 0) {
          throw FormatException('$normalized does not take a value.');
        }
        if (normalized == '--capture-only') {
          captureOnly = true;
        } else {
          showHelp = true;
        }
        continue;
      }
      final String value;
      if (equals >= 0) {
        value = arg.substring(equals + 1);
      } else {
        if (++i >= args.length || args[i].startsWith('--')) {
          throw FormatException('Missing $normalized value.');
        }
        value = args[i];
      }
      switch (normalized) {
        case '--theme':
          theme = value;
          break;
        case '--width':
          width = _surfaceNumber(value, normalized);
          break;
        case '--text-scale':
          textScale = _surfaceNumber(value, normalized);
          break;
        case '--keyboard':
          keyboard = _surfaceNumber(value, normalized, allowZero: true);
          break;
      }
    }
    if (!{'dark', 'light', 'both'}.contains(theme)) {
      throw FormatException('Unknown theme: $theme');
    }
    final selected = selection.split(',').map((id) => id.trim()).toList();
    if (selected.contains('all') && selected.length != 1) {
      throw const FormatException(
          'all must be used without other surface IDs.');
    }
    final seen = <String>{};
    for (final id in selected) {
      if (id != 'all' && !surfaceReferenceFrames.containsKey(id)) {
        throw FormatException(
            'Unknown surface ID: ${id.isEmpty ? '(empty)' : id}');
      }
      if (!seen.add(id)) throw FormatException('Duplicate surface ID: $id');
    }
    if (!(width * devicePixelRatio).isFinite ||
        (width * devicePixelRatio).ceil() > 0x7fffffff) {
      throw const FormatException('--width exceeds valid PNG dimensions.');
    }
    if (!captureOnly &&
        (width != referenceWidth || textScale != 1 || keyboard != 0)) {
      throw const FormatException(
          'Non-reference width, text scale, or keyboard inset requires --capture-only.');
    }
    return SurfaceRunOptions._(
      surfaces: List<String>.unmodifiable(
          selected.length == 1 && selected.first == 'all'
              ? surfaceIds
              : selected),
      themes: List<String>.unmodifiable(
          theme == 'both' ? ['dark', 'light'] : [theme]),
      captureOnly: captureOnly,
      width: width,
      textScale: textScale,
      keyboard: keyboard,
      showHelp: showHelp,
    );
  }

  factory SurfaceRunOptions.fromEnvironment() {
    const captureOnly =
        String.fromEnvironment('SURFACE_CAPTURE_ONLY', defaultValue: 'false');
    if (captureOnly != 'true' && captureOnly != 'false') {
      throw const FormatException(
          'SURFACE_CAPTURE_ONLY must be true or false.');
    }
    return SurfaceRunOptions.parse([
      const String.fromEnvironment('SURFACE', defaultValue: 'all'),
      '--theme',
      const String.fromEnvironment('SURFACE_THEME', defaultValue: 'dark'),
      '--width',
      const String.fromEnvironment('SURFACE_WIDTH', defaultValue: '375'),
      '--text-scale',
      const String.fromEnvironment('SURFACE_TEXT_SCALE', defaultValue: '1'),
      '--keyboard',
      const String.fromEnvironment('SURFACE_KEYBOARD', defaultValue: '0'),
      if (captureOnly == 'true') '--capture-only',
    ]);
  }
}

double _surfaceNumber(String value, String option, {bool allowZero = false}) {
  final number = double.tryParse(value);
  if (number == null ||
      !number.isFinite ||
      (allowZero ? number < 0 : number <= 0)) {
    throw FormatException(
        '$option requires a finite ${allowZero ? 'nonnegative' : 'positive'} number.');
  }
  return number == 0 ? 0.0 : number;
}

final _usage =
    '''Capture development-only fixture screenshots and optionally compare Figma exports.

Usage: dart run tool/verify_surface.dart [surface,...|all] [options]
Surfaces: ${surfaceIds.join(', ')} (default: all)
Options:
  --theme dark|light|both   Theme selection (default: dark)
  --capture-only           Capture without Figma comparison
  --width positive-number Logical width (default: 375)
  --text-scale positive-number TextScaler.linear scale (default: 1)
  --keyboard nonnegative-number Bottom view inset (default: 0)
  --help, -h               Show this help

Height is 812 logical pixels, DPR 2, and top/bottom view padding is 48/34.
Non-reference geometry, scale, or keyboard requires --capture-only and uses a
separate variant directory. Default outputs stay in .figma_cache/render/.
Surfaces without an exact Figma frame are capture-only; no borrowed-frame metric.
Every started run writes JSON evidence; comparisons describe pixel differences,
not active routes, usability, or pixel-perfectness. Light references must be Figma
exports from tool/figma_spec.dart png; legacy light_*.png snapshots are not used.''';

Future<void> main(List<String> args) async {
  exitCode = await runSurfaceVerification(args);
}

typedef SurfaceFlutterTestRunner = Future<int> Function(
    String testFile, List<String> defines, String workingDirectory);

Future<int> runSurfaceVerification(List<String> args,
    {String? workingDirectory,
    SurfaceFlutterTestRunner? flutterTestRunner}) async {
  final SurfaceRunOptions options;
  try {
    options = SurfaceRunOptions.parse(args);
  } on FormatException catch (error) {
    stderr.writeln('${error.message}\n\n$_usage');
    return 64;
  }
  if (options.showHelp) {
    stdout.writeln(_usage);
    return 0;
  }
  final root = workingDirectory ?? Directory.current.path;
  final pairs = options.pairs;
  final comparedPairs = [
    if (!options.captureOnly)
      for (final pair in pairs)
        if (surfaceReferenceFrames[pair.$1] != null) pair,
  ];
  // Complete every input check before touching any prior output.
  try {
    if (!File(path.join(root, 'pubspec.yaml')).existsSync()) {
      stderr.writeln('Run this command from the Flutter project root.');
      return 66;
    }
    final font =
        path.join('assets', 'fonts', 'TikTokSans', 'TikTokSans-Variable.ttf');
    final missing = [
      if (!File(path.join(root, font)).existsSync()) font,
      for (final (surface, theme) in comparedPairs)
        if (!File(path.join(root, surfaceReferencePath(surface, theme)))
            .existsSync())
          surfaceReferencePath(surface, theme),
    ];
    if (missing.isNotEmpty) {
      stderr.writeln('Missing capture input(s):\n${missing.join('\n')}');
      stderr.writeln(
          'Export matching Figma references with tool/figma_spec.dart png.');
      return 66;
    }
    for (final (surface, theme) in comparedPairs) {
      final reference = surfaceReferencePath(surface, theme);
      _requireSurfacePngDimensions(
          path.join(root, reference), options.pixelWidth, options.pixelHeight);
    }
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    return 65;
  } on FileSystemException catch (error) {
    stderr.writeln('Could not read capture inputs: $error');
    return 74;
  }

  final startedAt = DateTime.now().toUtc();
  final evidencePath = path.join(options.artifactDirectory, 'runs',
      '${startedAt.microsecondsSinceEpoch}_$pid.json');
  final entries = <Map<String, Object?>>[
    for (final (surface, theme) in pairs)
      {
        'surface': surface,
        'theme': theme,
        ...options.geometryJson,
        'capturePath': surfaceCapturePath(surface, theme, options: options),
        'captureStatus': 'pending',
        'comparisonStatus': options.captureOnly
            ? 'notRequested'
            : surfaceReferenceFrames[surface] == null
                ? 'noReference'
                : 'pending',
      },
  ];
  final runner = flutterTestRunner ?? _flutterTest;
  var status = 70;
  var phase = 'prepare';
  stdout.writeln(
      'Strict fixture screenshots only; this does not verify live routes.');
  try {
    // Own only the selected surface/theme/variant outputs. Never remove exports,
    // other selections, other variants, or the evidence from previous runs.
    for (final (surface, theme) in pairs) {
      for (final ownedPath in [
        surfaceCapturePath(surface, theme, options: options),
        surfaceDiffPath(surface, theme, options: options),
        surfaceMetricsPath(surface, theme, options: options),
      ]) {
        final file = File(path.join(root, ownedPath));
        if (file.existsSync()) file.deleteSync();
      }
    }
    phase = 'capture';
    status = await runner(
        'tool/design/surface_capture_test.dart', options.dartDefines, root);
    final captureErrors = _collectCaptureEvidence(root, options, entries);
    if (status == 0 && captureErrors.isNotEmpty) {
      stderr.writeln(captureErrors.join('\n'));
      status =
          entries.any((entry) => entry['captureStatus'] == 'invalid') ? 65 : 66;
    }
    if (status == 0 && comparedPairs.isNotEmpty) {
      phase = 'comparison';
      status = await runner(
          'tool/design/surface_compare_test.dart', options.dartDefines, root);
    }
  } on ProcessException catch (error) {
    stderr.writeln('Could not start Flutter test runner: $error');
    status = 70;
  } on FileSystemException catch (error) {
    stderr.writeln('Could not prepare fixture images: $error');
    status = 74;
  }

  // Preserve truthful partial evidence on failed runs, without inventing metrics.
  if (phase == 'prepare') {
    for (final entry in entries) {
      entry['captureStatus'] = 'notProduced';
      if (entry['comparisonStatus'] == 'pending') {
        entry['comparisonStatus'] = 'notProduced';
      }
    }
  } else {
    _collectCaptureEvidence(root, options, entries);
    final comparisonErrors = _collectComparisonEvidence(root, options, entries);
    if (status == 0 && comparisonErrors.isNotEmpty) {
      stderr.writeln(comparisonErrors.join('\n'));
      status = 66;
    }
  }
  final evidence = {
    'schemaVersion': 1,
    'kind': 'strictFixtureSurfaceRun',
    'complete': status == 0,
    'status': status == 0 ? 'complete' : '${phase}_failed',
    'exitCode': status,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': DateTime.now().toUtc().toIso8601String(),
    'projectDirectory': path.normalize(path.absolute(root)),
    'captureOnly': options.captureOnly,
    'referenceGeometry': options.isReferenceGeometry,
    'artifacts': entries,
  };
  try {
    writeSurfaceJson(path.join(root, evidencePath), evidence);
    stdout.writeln('Fixture evidence: $evidencePath');
  } on FileSystemException catch (error) {
    stderr.writeln('Could not write fixture evidence: $error');
    return 74;
  }
  return status;
}

List<String> _collectCaptureEvidence(String root, SurfaceRunOptions options,
    List<Map<String, Object?>> entries) {
  final errors = <String>[];
  for (final entry in entries) {
    if (entry['captureStatus'] != 'pending') continue;
    final capturePath = entry['capturePath']! as String;
    try {
      final file = File(path.join(root, capturePath));
      if (!file.existsSync()) {
        entry['captureStatus'] = 'missing';
        entry['captureError'] = 'Capture did not produce an expected PNG.';
        errors.add('Missing fixture capture: $capturePath');
        continue;
      }
      final dimensions = _requireSurfacePngDimensions(
          file.path, options.pixelWidth, options.pixelHeight);
      entry['captureStatus'] = 'validated';
      entry['pngDimensions'] = {
        'width': dimensions.$1,
        'height': dimensions.$2,
      };
    } on FormatException catch (error) {
      entry['captureStatus'] = 'invalid';
      entry['captureError'] = error.message;
      errors.add(error.message.toString());
    } on FileSystemException catch (error) {
      entry['captureStatus'] = 'invalid';
      entry['captureError'] = error.toString();
      errors.add(error.toString());
    }
  }
  return errors;
}

List<String> _collectComparisonEvidence(String root, SurfaceRunOptions options,
    List<Map<String, Object?>> entries) {
  final errors = <String>[];
  for (final entry in entries) {
    if (entry['comparisonStatus'] != 'pending') continue;
    final surface = entry['surface']! as String;
    final theme = entry['theme']! as String;
    final metricsPath = surfaceMetricsPath(surface, theme, options: options);
    final diffPath = surfaceDiffPath(surface, theme, options: options);
    try {
      final file = File(path.join(root, metricsPath));
      if (!file.existsSync() || !File(path.join(root, diffPath)).existsSync()) {
        throw FormatException(
            'Missing comparison evidence for $surface/$theme.');
      }
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic> ||
          decoded['complete'] != true ||
          decoded['surface'] != surface ||
          decoded['theme'] != theme ||
          decoded['capturePath'] != entry['capturePath'] ||
          decoded['referencePath'] != surfaceReferencePath(surface, theme) ||
          decoded['diffPath'] != diffPath) {
        throw FormatException('Invalid comparison evidence: $metricsPath');
      }
      final metrics = decoded['metrics'];
      if (metrics is! Map<String, dynamic> ||
          metrics['meanMaxChannelDelta'] is! num ||
          !(metrics['meanMaxChannelDelta'] as num).isFinite ||
          metrics['percentOver32'] is! num ||
          !(metrics['percentOver32'] as num).isFinite ||
          metrics['pixelCount'] is! int ||
          (metrics['pixelCount'] as int) <= 0 ||
          metrics['pixelsOver32'] is! int) {
        throw FormatException('Invalid comparison measurements: $metricsPath');
      }
      entry['comparisonStatus'] = 'measured';
      entry['comparison'] = {
        'referencePath': decoded['referencePath'],
        'diffPath': diffPath,
        'metricsPath': metricsPath,
        'metrics': metrics,
      };
    } on FormatException catch (error) {
      entry['comparisonStatus'] = 'notProduced';
      entry['comparisonError'] = error.message;
      errors.add(error.message.toString());
    } on FileSystemException catch (error) {
      entry['comparisonStatus'] = 'notProduced';
      entry['comparisonError'] = error.toString();
      errors.add(error.toString());
    }
  }
  return errors;
}

(int, int) readSurfacePngDimensions(String filePath) {
  final file = File(filePath).openSync();
  final Uint8List header;
  try {
    header = file.readSync(24);
  } finally {
    file.closeSync();
  }
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (header.length != 24) {
    throw FormatException('Invalid PNG header: $filePath');
  }
  for (var index = 0; index < signature.length; index++) {
    if (header[index] != signature[index]) {
      throw FormatException('Invalid PNG signature: $filePath');
    }
  }
  final data = ByteData.sublistView(header);
  if (data.getUint32(8) != 13 || data.getUint32(12) != 0x49484452) {
    throw FormatException('Missing PNG IHDR: $filePath');
  }
  final width = data.getUint32(16);
  final height = data.getUint32(20);
  if (width == 0 || height == 0 || width > 0x7fffffff || height > 0x7fffffff) {
    throw FormatException('Invalid PNG dimensions: $filePath');
  }
  return (width, height);
}

(int, int) _requireSurfacePngDimensions(
    String filePath, int width, int height) {
  final dimensions = readSurfacePngDimensions(filePath);
  if (dimensions != (width, height)) {
    throw FormatException(
        '$filePath has ${dimensions.$1}x${dimensions.$2} pixels; '
        'expected ${width}x$height. Images must not be resized or cropped for comparison.');
  }
  return dimensions;
}

void writeSurfaceJson(String filePath, Object value) {
  final file = File(filePath);
  file.parent.createSync(recursive: true);
  final temporary = File('$filePath.tmp');
  try {
    temporary.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(value),
        flush: true);
    temporary.renameSync(file.path);
  } finally {
    if (temporary.existsSync()) temporary.deleteSync();
  }
}

Future<int> _flutterTest(
    String testFile, List<String> defines, String workingDirectory) async {
  stdout.writeln('Running flutter test $testFile (${defines.join(' ')})');
  final process = await Process.start(
    'flutter',
    ['test', testFile, '--concurrency=1', ...defines],
    runInShell: Platform.isWindows,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}
