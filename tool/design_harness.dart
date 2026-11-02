// Project workflow, not an application entry point. All previews use strict fixtures.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'design/surface_manifest.dart';

const _usage = '''Safe Figma / Flutter / Dart design loop.
Usage: dart run tool/design_harness.dart <command> [options]

  doctor [--json]                  SDK, fixture/config/cache availability; no account calls
  refs [--refresh] [Figma flags]   Cached frame lookup; --refresh explicitly uses Figma GETs
  capture [verify_surface flags]  Serial strict-fixture captures and diagnostic differences
  check [test files] [--full] [--native] [--plan]
                                  Focused tests or full coverage, analysis, optional Windows journey
  preview [--plan]                 Existing Windows fixture gallery; quit before checks/builds
  build [--tracked] [--plan]       Fixture release by default; --tracked builds deployment output
  serve [--port 8790]              Serve only this harness's fixture release on loopback

Examples:
  dart run tool/design_harness.dart refs --page "Design System (Light)" --frame "Каталог"
  dart run tool/design_harness.dart capture catalog,all_products --theme both
  dart run tool/design_harness.dart capture catalog --theme both --capture-only --width 320 --text-scale 2
  dart run tool/design_harness.dart check test/regression/surface_harness_test.dart
  dart run tool/design_harness.dart check --full --native --plan

Commands are serial and fail-fast. Logs and run status: .figma_cache/harness/runs/.
The lock coordinates harness commands, not arbitrary external Flutter processes.
Serving keeps the lock until shutdown; quit the server before checks/builds.
Screenshots/differences never establish interaction or production acceptance.''';

typedef _Step = ({String executable, List<String> arguments, bool interactive});

_Step _dart(List<String> args) =>
    (executable: 'dart', arguments: args, interactive: false);
_Step _flutter(List<String> args, {bool interactive = false}) =>
    (executable: 'flutter', arguments: args, interactive: interactive);

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == '--help' || args.first == '-h') {
    stdout.writeln(_usage);
    return;
  }
  try {
    final root = _projectRoot();
    final command = args.first;
    final rest = args.skip(1).toList();
    switch (command) {
      case 'doctor':
        final opts = _parse(rest, json: true);
        if (opts.flag('help')) return _printHelp();
        await _doctor(root, opts.flag('json'));
      case 'refs':
        final live = rest.remove('--refresh');
        exitCode = await _runSteps(root, command, [
          _dart([
            'run',
            'tool/figma_spec.dart',
            'frames',
            if (!live) '--offline',
            ...rest
          ]),
        ]);
      case 'capture':
        exitCode = await _runSteps(root, command, [
          _dart(['run', 'tool/verify_surface.dart', ...rest]),
        ]);
      case 'check':
        final opts = _parse(rest, checks: true);
        if (opts.flag('help')) return _printHelp();
        if (opts.flag('full') && opts.rest.isNotEmpty) {
          throw const FormatException(
              '--full cannot be combined with focused test files.');
        }
        for (final file in opts.rest) {
          final full = p.normalize(p.join(root.path, file));
          if (!p.isWithin(p.join(root.path, 'test'), full) ||
              p.extension(full) != '.dart' ||
              !File(full).existsSync()) {
            throw FormatException(
                'Expected an existing test/*.dart path: $file');
          }
        }
        if (opts.flag('native') && !Platform.isWindows) {
          throw const FormatException(
              '--native requires the configured Windows toolchain.');
        }
        final steps = <_Step>[
          if (opts.flag('full') || opts.rest.isNotEmpty)
            _flutter([
              'test',
              ...opts.rest,
              if (opts.flag('full')) '--coverage',
              '--concurrency=1',
              '--timeout=90s'
            ]),
          _dart(['analyze', 'lib', 'test', 'integration_test', 'tool']),
          if (opts.flag('native'))
            _flutter([
              'test',
              'integration_test/shopping_e2e_test.dart',
              '-d',
              'windows',
              '--concurrency=1'
            ]),
        ];
        exitCode = opts.flag('plan')
            ? _printPlan(steps)
            : await _runSteps(root, command, steps);
      case 'preview':
        final opts = _parse(rest);
        if (opts.flag('help')) return _printHelp();
        final steps = [
          _flutter(['run', '-d', 'windows', '-t', 'tool/dev_surface.dart'],
              interactive: true)
        ];
        exitCode = opts.flag('plan')
            ? _printPlan(steps)
            : await _runSteps(root, command, steps);
      case 'build':
        final opts = _parse(rest, build: true);
        if (opts.flag('help')) return _printHelp();
        final tracked = opts.flag('tracked');
        final steps = [
          _flutter([
            'build',
            'web',
            '--release',
            '--no-wasm-dry-run',
            if (!tracked) ...[
              '-t',
              'tool/dev_surface.dart',
              '-o',
              _webPath(root)
            ]
          ])
        ];
        exitCode = opts.flag('plan')
            ? _printPlan(steps)
            : await _build(root, steps, tracked: tracked);
      case 'serve':
        final opts = _parse(rest, serve: true);
        if (opts.flag('help')) return _printHelp();
        final port = int.tryParse(opts.option('port') ?? '');
        if (port == null || port < 1 || port > 65535) {
          throw const FormatException(
              '--port must be an integer from 1 through 65535.');
        }
        await _serve(root, port);
      default:
        throw FormatException('Unknown harness command: $command');
    }
  } on FormatException catch (error) {
    stderr.writeln('${error.message}\n\n$_usage');
    exitCode = 64;
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exitCode = 78;
  } on ProcessException catch (error) {
    stderr.writeln('Could not launch tool: $error');
    exitCode = 70;
  } on FileSystemException catch (error) {
    stderr.writeln('Harness filesystem failure: $error');
    exitCode = 74;
  } on SocketException catch (error) {
    stderr.writeln('Fixture server failure: $error');
    exitCode = 71;
  }
}

ArgResults _parse(List<String> args,
    {bool json = false,
    bool checks = false,
    bool build = false,
    bool serve = false}) {
  final parser = ArgParser()..addFlag('help', abbr: 'h', negatable: false);
  if (json) parser.addFlag('json', negatable: false);
  if (!json && !serve) parser.addFlag('plan', negatable: false);
  if (checks) {
    parser
      ..addFlag('full', negatable: false)
      ..addFlag('native', negatable: false);
  }
  if (build) parser.addFlag('tracked', negatable: false);
  if (serve) parser.addOption('port', defaultsTo: '8790');
  final result = parser.parse(args);
  if (!checks && result.rest.isNotEmpty) {
    throw FormatException('Unexpected argument: ${result.rest.first}');
  }
  return result;
}

void _printHelp() => stdout.writeln(_usage);
int _printPlan(List<_Step> steps) {
  for (final step in steps) {
    stdout.writeln('${step.executable} ${step.arguments.join(' ')}');
  }
  stdout.writeln(
      'Plan only; no child process, capture, build, or account request started.');
  return 0;
}

Directory _projectRoot() {
  var root = Directory.current.absolute;
  while (!File(p.join(root.path, 'pubspec.yaml')).existsSync()) {
    if (root.parent.path == root.path) {
      throw StateError(
          'Run from this Flutter repository or a child directory.');
    }
    root = root.parent;
  }
  if (!File(p.join(root.path, 'tool', 'dev_surface.dart')).existsSync()) {
    throw StateError(
        'The selected Flutter repository has no strict fixture entrypoint.');
  }
  return root;
}

String _harnessPath(Directory root) =>
    p.join(root.path, '.figma_cache', 'harness');
String _webPath(Directory root) => p.join(_harnessPath(root), 'web');

Future<void> _doctor(Directory root, bool machine) async {
  final sdk = await Process.run('flutter', ['--version', '--machine'],
      workingDirectory: root.path, runInShell: Platform.isWindows);
  if (sdk.exitCode != 0) {
    stderr.write(sdk.stderr);
    throw StateError(
        'Flutter SDK discovery failed. Run flutter doctor -v for the toolchain.');
  }
  final version = jsonDecode(sdk.stdout as String) as Map<String, dynamic>;
  final specDir = Directory(p.join(root.path, '.figma_cache', 'spec'));
  final specs = specDir.existsSync()
      ? specDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) =>
              p.extension(file.path) == '.json' &&
              p.basename(file.path) != '_index.json')
          .length
      : 0;
  final report = {
    'flutter': version['frameworkVersion'],
    'dart': version['dartSdkVersion'],
    'flutterRoot': version['flutterRoot'],
    'platform': Platform.operatingSystem,
    'cachedSpecFiles': specs,
    'figmaCredentialAvailable':
        (Platform.environment['FIGMA_TOKEN']?.isNotEmpty ?? false) ||
            File(p.join(root.path, '.figma-token')).existsSync(),
    'figmaTargetAvailable':
        (Platform.environment['FIGMA_FILE']?.isNotEmpty ?? false) ||
            File(p.join(root.path, '.figma-design')).existsSync(),
    'surfaceCount': surfaceReferenceFrames.length,
    'fixtureEntrypoint': 'tool/dev_surface.dart',
    'runtimeMcpConfigured':
        File(p.join(root.path, '.omp', 'mcp.json')).existsSync(),
    'runtimeMcpRequires':
        'Running debug fixture app; not a release-bundle inspector.',
    'network':
        'SDK discovery only; no Figma/API/account request made by doctor.',
    'smoke':
        'Not exercised by doctor. Capture/test success is not interaction proof.',
    'serialScope':
        'Harness processes share a lock; stop external Flutter runs before checks.',
  };
  if (machine) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  } else {
    for (final entry in report.entries) {
      stdout.writeln('${entry.key}: ${entry.value}');
    }
  }
}

// Retain only the user's existing splash block; never restore an entire generated file.
String preserveSplashRegistration(String before, String generated) {
  const plugin =
      'net.jonhanson.flutter_native_splash.FlutterNativeSplashPlugin';
  if (!before.contains(plugin) || generated.contains(plugin)) return generated;
  final blocks = RegExp(
          r'^    try \{\r?\n(?:(?!^    \}).*\r?\n)*^    \} catch \(Exception e\) \{\r?\n(?:(?!^    \}).*\r?\n)*^    \}',
          multiLine: true)
      .allMatches(before)
      .where((match) => match.group(0)!.contains(plugin))
      .toList();
  final opener = RegExp(
      r'(  public static void registerWith\(@NonNull FlutterEngine flutterEngine\) \{\r?\n)');
  if (blocks.length != 1 || opener.allMatches(generated).length != 1) {
    throw StateError(
        'Cannot safely preserve the existing Android splash block; inspect the generated registration.');
  }
  final newline = generated.contains('\r\n') ? '\r\n' : '\n';
  final block = blocks.single
      .group(0)!
      .replaceAll('\r\n', '\n')
      .replaceAll('\n', newline);
  return generated.replaceFirstMapped(
      opener, (match) => '${match.group(0)}$block$newline');
}

Future<T> _withFlutterLock<T>(
    Directory root, Future<T> Function() action) async {
  final work = Directory(_harnessPath(root))..createSync(recursive: true);
  final lock =
      await File(p.join(work.path, 'flutter.lock')).open(mode: FileMode.append);
  var locked = false;
  try {
    try {
      await lock.lock(FileLock.exclusive);
      locked = true;
    } on FileSystemException {
      throw StateError(
          'Another harness command owns the Flutter lock. Finish/quit it first.');
    }
    return await action();
  } finally {
    try {
      if (locked) await lock.unlock();
    } finally {
      await lock.close();
    }
  }
}

Future<int> _build(Directory root, List<_Step> steps,
        {required bool tracked}) =>
    _withFlutterLock(root, () async {
      if (tracked) return _runStepsLocked(root, 'build', steps);
      final marker = File(p.join(_webPath(root), '.fixture-build.json'));
      if (marker.existsSync()) marker.deleteSync();
      var published = false;
      try {
        final result = await _runStepsLocked(root, 'build', steps);
        if (result == 0) {
          final index = File(p.join(_webPath(root), 'index.html'));
          final html = index.readAsStringSync();
          final isolated = _stripFixturePushSdk(html);
          if (isolated != html) index.writeAsStringSync(isolated);
          marker.writeAsStringSync(jsonEncode({
            'entrypoint': 'tool/dev_surface.dart',
            'builtAt': DateTime.now().toUtc().toIso8601String(),
            'synthetic': true,
          }));
          published = true;
        }
        return result;
      } finally {
        if (!published && marker.existsSync()) marker.deleteSync();
      }
    });

String _stripFixturePushSdk(String html) {
  final scripts =
      RegExp(r'<script\b([^>]*)>[\s\S]*?</script\s*>', caseSensitive: false);
  final source = RegExp(
      r'''(?:^|\s)src\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))''',
      caseSensitive: false);
  return html.replaceAllMapped(scripts, (script) {
    final attribute = source.firstMatch(script.group(1)!);
    if (attribute == null) return script.group(0)!;
    final uri = Uri.tryParse(
        attribute.group(1) ?? attribute.group(2) ?? attribute.group(3)!);
    return uri?.host.toLowerCase() == 'cdn.onesignal.com'
        ? ''
        : script.group(0)!;
  });
}

Future<int> _runSteps(Directory root, String command, List<_Step> steps) =>
    _withFlutterLock(root, () => _runStepsLocked(root, command, steps));

Future<int> _runStepsLocked(
    Directory root, String command, List<_Step> steps) async {
  final runs = Directory(p.join(_harnessPath(root), 'runs'))
    ..createSync(recursive: true);
  final id =
      '${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}_$pid';
  final logFile = File(p.join(runs.path, '$id.log'));
  final log = logFile.openWrite();
  final stateFile = File(p.join(runs.path, '$id.json'));
  final state = <String, dynamic>{
    'command': command,
    'startedAt': DateTime.now().toUtc().toIso8601String(),
    'status': 'running',
    'log': p.relative(logFile.path, from: root.path),
    'steps': <Map<String, dynamic>>[],
    'productionAcceptance': false,
  };
  final registry = File(p.join(root.path, 'android', 'app', 'src', 'main',
      'java', 'io', 'flutter', 'plugins', 'GeneratedPluginRegistrant.java'));
  final before = registry.existsSync() ? registry.readAsStringSync() : null;
  var result = 70;
  stateFile
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(state));
  stdout.writeln('Harness log: ${p.relative(logFile.path, from: root.path)}');
  try {
    for (final step in steps) {
      final record = <String, dynamic>{
        'executable': step.executable,
        'arguments': step.arguments,
        'startedAt': DateTime.now().toUtc().toIso8601String(),
      };
      (state['steps'] as List<Map<String, dynamic>>).add(record);
      final label = '${step.executable} ${step.arguments.join(' ')}';
      stdout.writeln('Running: $label');
      log.writeln('Running: $label');
      final process = await Process.start(step.executable, step.arguments,
          workingDirectory: root.path,
          runInShell: Platform.isWindows,
          mode: step.interactive
              ? ProcessStartMode.inheritStdio
              : ProcessStartMode.normal);
      record['pid'] = process.pid;
      final interrupts = ProcessSignal.sigint.watch().listen((_) {
        if (Platform.isWindows) {
          unawaited(
              Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F']));
        } else {
          process.kill(ProcessSignal.sigint);
        }
      });
      try {
        if (step.interactive) {
          log.writeln(
              'Interactive output belongs to the native terminal; only lifecycle is logged.');
          result = await process.exitCode;
        } else {
          final drains = [
            process.stdout.forEach((bytes) {
              log.add(bytes);
              stdout.add(bytes);
            }),
            process.stderr.forEach((bytes) {
              log.add(bytes);
              stderr.add(bytes);
            }),
          ];
          result = await process.exitCode;
          await Future.wait(drains);
        }
      } finally {
        await interrupts.cancel();
      }
      record['exitCode'] = result;
      record['finishedAt'] = DateTime.now().toUtc().toIso8601String();
      stateFile
          .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(state));
      if (result != 0) break;
    }
    return result;
  } finally {
    try {
      if (before != null && registry.existsSync()) {
        final current = registry.readAsStringSync();
        final preserved = preserveSplashRegistration(before, current);
        if (preserved != current) {
          registry.writeAsStringSync(preserved);
          state['splashRegistration'] =
              'preserved existing block without replacing other plugins';
        }
      }
      state['status'] = result == 0 ? 'succeeded' : 'failed';
      state['exitCode'] = result;
      state['finishedAt'] = DateTime.now().toUtc().toIso8601String();
      stateFile
          .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(state));
    } finally {
      await log.close();
    }
  }
}

Future<File?> fixtureAsset(Directory root, Uri uri) async {
  final segments =
      uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
  if (segments.any((segment) =>
      segment == '.' ||
      segment == '..' ||
      segment.contains('/') ||
      segment.contains('\\') ||
      segment.contains(':'))) {
    return null;
  }
  final base = await root.resolveSymbolicLinks();
  final file =
      File(p.joinAll([base, if (segments.isEmpty) 'index.html', ...segments]));
  if (!await file.exists()) return null;
  final actual = await file.resolveSymbolicLinks();
  if (!p.isWithin(base, actual)) return null;
  return File(actual);
}

Future<void> _serve(Directory root, int port) =>
    _withFlutterLock(root, () => _serveLocked(root, port));

Future<void> _serveLocked(Directory root, int port) async {
  final web = Directory(_webPath(root));
  final marker = File(p.join(web.path, '.fixture-build.json'));
  if (!marker.existsSync() ||
      !File(p.join(web.path, 'index.html')).existsSync()) {
    throw StateError(
        'Build the fixture first: dart run tool/design_harness.dart build');
  }
  final metadata =
      jsonDecode(marker.readAsStringSync()) as Map<String, dynamic>;
  if (metadata['entrypoint'] != 'tool/dev_surface.dart' ||
      metadata['synthetic'] != true) {
    throw StateError(
        'Refusing to serve output without a strict-fixture build marker.');
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  final signals = <StreamSubscription<ProcessSignal>>[
    ProcessSignal.sigint
        .watch()
        .listen((_) => unawaited(server.close(force: true))),
    if (!Platform.isWindows)
      ProcessSignal.sigterm
          .watch()
          .listen((_) => unawaited(server.close(force: true))),
  ];
  stdout.writeln('Fixture server ready: http://127.0.0.1:$port');
  try {
    await for (final request in server) {
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.response.headers.set('X-Content-Type-Options', 'nosniff');
      if (request.method != 'GET' && request.method != 'HEAD') {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        await request.response.close();
        continue;
      }
      final file = await fixtureAsset(web, request.uri);
      if (file == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        final type = switch (p.extension(file.path)) {
          '.html' => 'text/html',
          '.js' => 'application/javascript',
          '.json' => 'application/json',
          '.wasm' => 'application/wasm',
          '.css' => 'text/css',
          '.png' => 'image/png',
          '.svg' => 'image/svg+xml',
          '.ttf' => 'font/ttf',
          '.otf' => 'font/otf',
          '.woff2' => 'font/woff2',
          _ => 'application/octet-stream',
        };
        request.response.headers.set(HttpHeaders.contentTypeHeader, type);
        if (request.method == 'GET') {
          await request.response.addStream(file.openRead());
        }
      }
      await request.response.close();
    }
  } finally {
    for (final signal in signals) {
      await signal.cancel();
    }
    await server.close(force: true);
  }
}
