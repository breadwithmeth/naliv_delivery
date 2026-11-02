import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('busy fixture build leaves the published marker and assets untouched',
      () async {
    final sandbox = await _HarnessSandbox.create();
    final before = await sandbox.fixtureSnapshot();
    await sandbox.holdFlutterLock();

    final build = await sandbox.run(['build']);

    expect(build.code, 78, reason: build.diagnostics);
    expect(await sandbox.fixtureSnapshot(), before,
        reason: 'A refused build must not invalidate a usable fixture.');
    expect(await sandbox.compilerInvocation.exists(), isFalse);
  });

  test('serve refuses partial fixture output while a builder owns the lock',
      () async {
    final sandbox = await _HarnessSandbox.create();
    await sandbox.holdFlutterLock();
    await sandbox.fixtureIndex
        .writeAsString('<p>partially rebuilt fixture</p>');
    final port = await _unusedPort();

    final server = await sandbox.start(['serve', '--port', '$port']);
    final ready = await server.readyOrExited();

    expect(ready, isFalse,
        reason:
            'Serving must not accept the old marker during an active build.');
    expect(await server.code, 78, reason: server.diagnostics);
  });

  test('active fixture serving refuses rebuilds without changing served bytes',
      () async {
    final sandbox = await _HarnessSandbox.create();
    final before = await sandbox.fixtureSnapshot();
    final port = await _unusedPort();
    final server = await sandbox.start(['serve', '--port', '$port']);
    expect(await server.readyOrExited(), isTrue, reason: server.diagnostics);
    expect(await _getIndex(port), contains('<p>published fixture</p>'));

    final build = await sandbox.run(['build']);

    expect(build.code, 78, reason: build.diagnostics);
    expect(await sandbox.fixtureSnapshot(), before);
    expect(await sandbox.compilerInvocation.exists(), isFalse);
    expect(await _getIndex(port), contains('<p>published fixture</p>'));
  });

  test('failed fixture builds invalidate validity and release their lock',
      () async {
    final sandbox = await _HarnessSandbox.create();
    await sandbox.compilerMode.writeAsString('failure');

    final failure = await sandbox.run(['build']);

    expect(failure.code, 17, reason: failure.diagnostics);
    expect(await sandbox.fixtureMarker.exists(), isFalse);
    await sandbox.compilerMode.writeAsString('success');
    final recovered = await sandbox.run(['build']);
    expect(recovered.code, 0, reason: recovered.diagnostics);
    expect(jsonDecode(await sandbox.fixtureMarker.readAsString()),
        containsPair('synthetic', true));
  });

  test('fixture publication strips only the production push SDK loader',
      () async {
    final sandbox = await _HarnessSandbox.create();
    final sourceBefore = await sandbox.sourceIndex.readAsBytes();
    final trackedBefore = await sandbox.trackedIndex.readAsBytes();

    final build = await sandbox.run(['build']);

    expect(build.code, 0, reason: build.diagnostics);
    final html = await sandbox.fixtureIndex.readAsString();
    expect(_externalScripts(html), [
      'flutter.js',
      'onesignal-helper.js',
      'flutter_bootstrap.js',
    ]);
    expect(html, contains('window.fixtureBridgeSentinel = true'));
    expect(await sandbox.sourceIndex.readAsBytes(), sourceBefore);
    expect(await sandbox.trackedIndex.readAsBytes(), trackedBefore);
    final metadata = jsonDecode(await sandbox.fixtureMarker.readAsString());
    expect(metadata, containsPair('entrypoint', 'tool/dev_surface.dart'));
    expect(metadata, containsPair('synthetic', true));
  });

  test('tracked deployment builds retain the push SDK and fixture publication',
      () async {
    final sandbox = await _HarnessSandbox.create();
    final fixtureBefore = await sandbox.fixtureSnapshot();
    final sourceBefore = await sandbox.sourceIndex.readAsBytes();

    final build = await sandbox.run(['build', '--tracked']);

    expect(build.code, 0, reason: build.diagnostics);
    expect(_externalScripts(await sandbox.trackedIndex.readAsString()), [
      'flutter.js',
      'https://cdn.onesignal.com/sdks/web/v16/OneSignalSDK.page.js',
      'onesignal-helper.js',
      'flutter_bootstrap.js',
    ]);
    expect(await sandbox.fixtureSnapshot(), fixtureBefore);
    expect(await sandbox.sourceIndex.readAsBytes(), sourceBefore);
    expect(
        await File(
                p.join(sandbox.trackedIndex.parent.path, '.fixture-build.json'))
            .exists(),
        isFalse);
  });

  test('server bind failure releases the lock for the next fixture build',
      () async {
    final sandbox = await _HarnessSandbox.create();
    final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(occupied.close);

    final server = await sandbox.run(['serve', '--port', '${occupied.port}']);

    expect(server.code, 71, reason: server.diagnostics);
    final build = await sandbox.run(['build']);
    expect(build.code, 0, reason: build.diagnostics);
    expect(await sandbox.fixtureMarker.exists(), isTrue);
  });
  test('missing compiled HTML cannot publish validity or retain the build lock',
      () async {
    final sandbox = await _HarnessSandbox.create();
    await sandbox.compilerMode.writeAsString('missing-index');

    final failure = await sandbox.run(['build']);

    expect(failure.code, 74, reason: failure.diagnostics);
    expect(await sandbox.fixtureMarker.exists(), isFalse);
    final refused =
        await sandbox.run(['serve', '--port', '${await _unusedPort()}']);
    expect(refused.code, 78, reason: refused.diagnostics);
    await sandbox.compilerMode.writeAsString('success');
    final recovered = await sandbox.run(['build']);
    expect(recovered.code, 0, reason: recovered.diagnostics);
    expect(await sandbox.fixtureMarker.exists(), isTrue);
  });

  test('invalid fixture metadata releases the server lock after refusal',
      () async {
    final sandbox = await _HarnessSandbox.create();
    await sandbox.fixtureMarker.writeAsString(jsonEncode({
      'entrypoint': 'lib/main.dart',
      'synthetic': false,
    }));

    final server =
        await sandbox.run(['serve', '--port', '${await _unusedPort()}']);

    expect(server.code, 78, reason: server.diagnostics);
    final build = await sandbox.run(['build']);
    expect(build.code, 0, reason: build.diagnostics);
  });

  test('server termination releases ownership for the next fixture build',
      () async {
    final sandbox = await _HarnessSandbox.create();
    final server =
        await sandbox.start(['serve', '--port', '${await _unusedPort()}']);
    expect(await server.readyOrExited(), isTrue, reason: server.diagnostics);

    expect(server.process.kill(), isTrue);
    await server.code.timeout(const Duration(seconds: 10));
    final build = await sandbox.run(['build']);

    expect(build.code, 0, reason: build.diagnostics);
    expect(await sandbox.fixtureMarker.exists(), isTrue);
  });

  test(
      'fixture sanitizer recognizes loader attributes without deleting local code',
      () async {
    final sandbox = await _HarnessSandbox.create();
    await sandbox.sourceIndex.writeAsString('''<!doctype html>
<script defer SRC='//cdn.onesignal.com/sdks/web/v16/OneSignalSDK.page.js'></script>
<SCRIPT async src="https://CDN.ONESIGNAL.COM/sdks/web/v16/OneSignalSDK.page.js"></SCRIPT>
<script src=//cdn.onesignal.com/sdks/web/v16/OneSignalSDK.page.js></script>
<script data-src="https://cdn.onesignal.com/example.js">window.localCode = true;</script>
<script src="onesignal-helper.js"></script>
<script src="https://example.invalid/unrelated.js"></script>
''');

    final build = await sandbox.run(['build']);

    expect(build.code, 0, reason: build.diagnostics);
    final html = await sandbox.fixtureIndex.readAsString();
    expect(_externalScripts(html),
        ['onesignal-helper.js', 'https://example.invalid/unrelated.js']);
    expect(html, contains('window.localCode = true;'));
    expect(html, isNot(contains('OneSignalSDK.page.js')));
  });
}

List<String> _externalScripts(String html) =>
    RegExp(r'''<script\b[^>]*\ssrc\s*=\s*["']([^"']+)["'][^>]*>''',
            caseSensitive: false)
        .allMatches(html)
        .map((match) => match.group(1)!)
        .toList();

Future<int> _unusedPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Future<String> _getIndex(int port) async {
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
  try {
    socket.write('GET / HTTP/1.1\r\nHost: 127.0.0.1:$port\r\n'
        'Connection: close\r\n\r\n');
    await socket.flush();
    return await socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .join()
        .timeout(
          const Duration(seconds: 10),
        );
  } finally {
    socket.destroy();
  }
}

class _HarnessSandbox {
  _HarnessSandbox(this.root, this.dart, this.script, this.packages);

  final Directory root;
  final String dart;
  final String script;
  final String packages;
  final _processes = <_HarnessProcess>[];
  final _locks = <RandomAccessFile>[];

  File get fixtureIndex =>
      File(p.join(root.path, '.figma_cache', 'harness', 'web', 'index.html'));
  File get fixtureMarker =>
      File(p.join(fixtureIndex.parent.path, '.fixture-build.json'));
  File get sourceIndex => File(p.join(root.path, 'web', 'index.html'));
  File get trackedIndex =>
      File(p.join(root.path, 'build', 'web', 'index.html'));
  File get compilerMode => File(p.join(root.path, '.fake-flutter-mode'));
  File get compilerInvocation =>
      File(p.join(root.path, '.fake-flutter-invocation.json'));

  static Future<_HarnessSandbox> create() async {
    final project = Directory.current.absolute;
    final packageFile =
        File(p.join(project.path, '.dart_tool', 'package_config.json'));
    final config =
        jsonDecode(await packageFile.readAsString()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((entry) => entry['name'] == 'flutter');
    final flutterRoot =
        Directory.fromUri(packageFile.uri.resolve(flutter['rootUri'] as String))
            .parent
            .parent;
    final dart = p.join(flutterRoot.path, 'bin', 'cache', 'dart-sdk', 'bin',
        Platform.isWindows ? 'dart.exe' : 'dart');
    final root =
        await Directory.systemTemp.createTemp('naliv_harness_process_');
    final sandbox = _HarnessSandbox(root, dart,
        p.join(project.path, 'tool', 'design_harness.dart'), packageFile.path);
    addTearDown(sandbox.dispose);
    await File(p.join(root.path, 'pubspec.yaml'))
        .writeAsString('name: isolated_harness_fixture\n');
    final entrypoint = File(p.join(root.path, 'tool', 'dev_surface.dart'));
    await entrypoint.parent.create(recursive: true);
    await entrypoint
        .writeAsString('// Never executed by this subprocess test.\n');
    await sandbox.fixtureIndex.parent.create(recursive: true);
    await sandbox.fixtureIndex.writeAsString('<p>published fixture</p>');
    await sandbox.fixtureMarker.writeAsString('''{
  "entrypoint": "tool/dev_surface.dart",
  "builtAt": "2026-01-01T00:00:00.000Z",
  "synthetic": true
}\n''');
    await File(p.join(sandbox.fixtureIndex.parent.path, 'main.dart.js'))
        .writeAsString('published JavaScript bytes');
    await sandbox.sourceIndex.parent.create(recursive: true);
    await sandbox.sourceIndex.writeAsString(_sourceHtml);
    await sandbox.trackedIndex.parent.create(recursive: true);
    await sandbox.trackedIndex
        .writeAsString('<p>tracked deployment before</p>');
    await sandbox.compilerMode.writeAsString('success');
    final bin = await Directory(p.join(root.path, 'fake-bin')).create();
    final driver = File(p.join(bin.path, 'fake_flutter.dart'));
    await driver.writeAsString(_fakeFlutter);
    final launcher =
        File(p.join(bin.path, Platform.isWindows ? 'flutter.bat' : 'flutter'));
    if (Platform.isWindows) {
      await launcher.writeAsString('@"$dart" "${driver.path}" %*\r\n'
          '@exit /b %errorlevel%\r\n');
    } else {
      String quote(String value) => "'${value.replaceAll("'", "'\\''")}'";
      await launcher.writeAsString('#!/bin/sh\n'
          'exec ${quote(dart)} ${quote(driver.path)} "\$@"\n');
      final permissions = await Process.run('chmod', ['+x', launcher.path]);
      if (permissions.exitCode != 0) {
        throw StateError(
            'Cannot prepare compiler boundary: ${permissions.stderr}');
      }
    }
    return sandbox;
  }

  Future<void> holdFlutterLock() async {
    final file =
        File(p.join(root.path, '.figma_cache', 'harness', 'flutter.lock'));
    await file.parent.create(recursive: true);
    final lock = await file.open(mode: FileMode.append);
    _locks.add(lock);
    await lock.lock(FileLock.exclusive);
  }

  Future<Map<String, String>> fixtureSnapshot() async {
    final result = <String, String>{};
    await for (final entry in fixtureIndex.parent.list(recursive: true)) {
      if (entry is File) {
        result[p.relative(entry.path, from: fixtureIndex.parent.path)] =
            base64Encode(await entry.readAsBytes());
      }
    }
    return result;
  }

  Future<_HarnessProcess> start(List<String> arguments) async {
    final environment = Map<String, String>.of(Platform.environment);
    final pathKey = environment.keys
        .firstWhere((key) => key.toLowerCase() == 'path', orElse: () => 'PATH');
    environment[pathKey] = '${p.join(root.path, 'fake-bin')}'
        '${Platform.isWindows ? ';' : ':'}${environment[pathKey] ?? ''}';
    final process = _HarnessProcess(await Process.start(
        dart, ['--packages=$packages', script, ...arguments],
        workingDirectory: root.path, environment: environment));
    _processes.add(process);
    return process;
  }

  Future<({int code, String diagnostics})> run(List<String> arguments) async {
    final process = await start(arguments);
    final code = await process.code.timeout(const Duration(seconds: 30));
    return (code: code, diagnostics: process.diagnostics);
  }

  Future<void> dispose() async {
    try {
      for (final process in _processes.reversed) {
        process.process.kill();
        await process.code.timeout(const Duration(seconds: 10));
      }
    } finally {
      for (final lock in _locks.reversed) {
        await lock.unlock();
        await lock.close();
      }
      await root.delete(recursive: true);
    }
  }
}

class _HarnessProcess {
  _HarnessProcess(this.process) {
    final out = process.stdout.transform(utf8.decoder).forEach((text) {
      _stdout.write(text);
      if (_stdout.toString().contains('Fixture server ready:') &&
          !_ready.isCompleted) {
        _ready.complete();
      }
    });
    final errors =
        process.stderr.transform(utf8.decoder).forEach(_stderr.write);
    code = process.exitCode.then((value) async {
      await Future.wait([out, errors]);
      return value;
    });
  }

  final Process process;
  final _stdout = StringBuffer();
  final _stderr = StringBuffer();
  final _ready = Completer<void>();
  late final Future<int> code;

  String get diagnostics => 'stdout:\n$_stdout\nstderr:\n$_stderr';

  Future<bool> readyOrExited() => Future.any([
        _ready.future.then((_) => true),
        code.then((_) => false),
      ]).timeout(const Duration(seconds: 20));
}

const _sourceHtml = '''<!doctype html>
<html><head>
<script src="flutter.js" defer=""></script>
<script src="https://cdn.onesignal.com/sdks/web/v16/OneSignalSDK.page.js" defer=""></script>
<script>window.fixtureBridgeSentinel = true;</script>
<script src="onesignal-helper.js"></script>
</head><body>
<script src="flutter_bootstrap.js" async></script>
</body></html>
''';

// Only the external compiler is substituted. The real harness owns the process,
// operating-system lock, build marker, HTML publication and HTTP server.
const _fakeFlutter = r'''
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final root = Directory.current;
  final fixtureOutput = '${root.path}${Platform.pathSeparator}.figma_cache'
      '${Platform.pathSeparator}harness${Platform.pathSeparator}web';
  final prefix = ['build', 'web', '--release', '--no-wasm-dry-run'];
  final fixture = [...prefix, '-t', 'tool/dev_surface.dart', '-o', fixtureOutput];
  final isFixture = jsonEncode(args) == jsonEncode(fixture);
  final isTracked = jsonEncode(args) == jsonEncode(prefix);
  if (!isFixture && !isTracked) {
    stderr.writeln('Unexpected compiler invocation: $args');
    exitCode = 64;
    return;
  }
  await File('.fake-flutter-invocation.json').writeAsString(jsonEncode(args));
  final output = Directory(isFixture ? fixtureOutput : 'build/web');
  await output.create(recursive: true);
  await File('${output.path}/index.html')
      .writeAsString(await File('web/index.html').readAsString());
  await File('${output.path}/main.dart.js').writeAsString('rebuilt JavaScript');
  final mode = (await File('.fake-flutter-mode').readAsString()).trim();
  if (mode == 'failure') {
    stderr.writeln('Controlled compiler failure');
    exitCode = 17;
  } else if (mode == 'missing-index') {
    await File('${output.path}/index.html').delete();
  } else if (mode != 'success') {
    throw StateError('Unexpected compiler mode: $mode');
  }
}
''';
