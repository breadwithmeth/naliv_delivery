// Dev tool: dump the redesign Figma file into a compact, machine-readable spec.
//
// Not shipped with the app. Run with --help for commands, filters and examples.
// Credentials: `.figma-token` at the repo root (git-ignored) or FIGMA_TOKEN env var.
// Target file: `.figma-design` at the repo root (a Figma URL) or FIGMA_FILE env var.
// Help and `frames --offline` never read credentials or make network requests.
// Output lands in `.figma_cache/` (git-ignored). Unique names keep their original
// paths; colliding names are retained separately with a node-ID suffix.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

const _api = 'https://api.figma.com/v1';
const _designPages = ['Design System (Dark)', 'Design System (Light)'];

const _usage = '''Usage: dart run tool/figma_spec.dart [command] [options]

Commands (default: spec):
  frames  List live design frames, or cached metadata with --offline.
  spec    Export compact JSON specs and merge spec/_index.json.
  png     Render original PNGs for visual comparison.
  svg     Export the existing {file-safe name: nodeId} icon map.

frames/spec/png:
  --page NAME    Exact page name; default: both Design System themes.
  --frame NAMES  Comma-separated exact frame names (outer whitespace ignored).
  --node IDS     Comma-separated exact Figma node IDs, e.g. 2093:14635.
                Use either --frame or --node, not both. Missing selections and
                same-page ambiguous frame names are errors; use candidate IDs.
frames:
  --offline      Read only cached spec/_index.json and actual cached specs.
                TSV: page, nodeId, frame, file, width x height, spec status.
                Status is ok, missing, invalid, mismatch:<actual ID>, or
                name-mismatch, or size-mismatch. This is cached-only, NOT live
                or whole-file evidence.
spec/png:
  --force        Re-export selected originals; never replace a different node.
  --batch N      Positive integer request batch (spec: 20, png: 8).
png:
  --scale N      Positive finite render scale (default: 2).
svg:
  --map FILE     Icon map (default: .figma_cache/icons.json).
  --out DIR      SVG destination (default: assets/icons/design).
All commands:
  --help, -h     Print this help without reading credentials or using the network.

Examples:
  dart run tool/figma_spec.dart --help
  dart run tool/figma_spec.dart frames --offline
  dart run tool/figma_spec.dart frames --offline --page "Design System (Light)"
  dart run tool/figma_spec.dart spec --page "Design System (Dark)" --frame "Каталог"
  dart run tool/figma_spec.dart png --node "2093:14635,2093:14858" --force
  dart run tool/figma_spec.dart svg --map .figma_cache/icons.json

Options accept --name value or --name=value; flags take no value.
Duplicate exports use <frame>__<nodeId with colon replaced by underscore>.
The unique unpadded frame name owns the legacy alias when names differ only by
outer whitespace; a modal/padded variant never replaces that ordinary alias.
Usage errors go to stderr with exit code 64, before credential/network work
when detectable from the arguments. Cache/data errors use 65; missing config 78.
''';

Future<void> main(List<String> args) async {
  exitCode = await runFigmaSpec(args);
}

Future<int> runFigmaSpec(
  List<String> args, {
  Directory? root,
  Map<String, String>? environment,
  StringSink? output,
  StringSink? errors,
  http.Client? client,
}) async {
  final out = output ?? stdout;
  final err = errors ?? stderr;
  http.Client? ownedClient;
  try {
    final invocation = _parseArguments(args);
    final opts = invocation.options;
    if (opts.containsKey('help')) {
      out.write(_usage);
      return 0;
    }
    final repo = root ?? _repoRoot();
    final cache = Directory(p.join(repo.path, '.figma_cache'));
    if (opts.containsKey('offline')) {
      return _listCachedFrames(cache, opts, out, err);
    }
    final env = environment ?? Platform.environment;
    final token = _readToken(repo, env);
    final fileKey = _readFileKey(repo, env);
    final api = _FigmaApi(
      token,
      fileKey,
      client ?? (ownedClient = http.Client()),
      out,
      err,
    );
    switch (invocation.command) {
      case 'frames':
        await _listFrames(api, opts);
      case 'spec':
        return await _dumpSpec(api, cache, opts);
      case 'png':
        return await _dumpPng(api, cache, opts);
      case 'svg':
        await _dumpSvg(api, cache, opts);
    }
    return 0;
  } on _UsageException catch (error) {
    err.writeln('${error.message}\n\n$_usage');
    return 64;
  } on _ConfigurationException catch (error) {
    err.writeln(error.message);
    return 78;
  } on FormatException catch (error) {
    err.writeln(error.message);
    return 65;
  } on FileSystemException catch (error) {
    err.writeln('File operation failed: ${error.message} (${error.path})');
    return 74;
  } on http.ClientException {
    err.writeln('Figma HTTP request failed.');
    return 69;
  } on StateError catch (error) {
    err.writeln(error.message);
    return 70;
  } finally {
    ownedClient?.close();
  }
}

class _UsageException implements Exception {
  const _UsageException(this.message);

  final String message;
}

class _ConfigurationException implements Exception {
  const _ConfigurationException(this.message);

  final String message;
}

class _Invocation {
  const _Invocation(this.command, this.options);

  final String command;
  final Map<String, String> options;
}

_Invocation _parseArguments(List<String> args) {
  const commands = {'frames', 'spec', 'png', 'svg'};
  var command = 'spec';
  var start = 0;
  if (args.isNotEmpty && !args.first.startsWith('-')) {
    command = args.first;
    start = 1;
  }
  if (!commands.contains(command)) {
    throw _UsageException('Unknown command "$command".');
  }
  final values = switch (command) {
    'frames' => {'page', 'frame', 'node'},
    'spec' => {'page', 'frame', 'node', 'batch'},
    'png' => {'page', 'frame', 'node', 'batch', 'scale'},
    'svg' => {'map', 'out'},
    _ => <String>{},
  };
  final switches = {
    'help',
    if (command == 'frames') 'offline',
    if (command == 'spec' || command == 'png') 'force',
  };
  final options = <String, String>{};
  for (var i = start; i < args.length; i++) {
    final arg = args[i] == '-h' ? '--help' : args[i];
    if (!arg.startsWith('--')) {
      throw _UsageException('Unexpected argument "$arg".');
    }
    final equals = arg.indexOf('=');
    final key = arg.substring(2, equals < 0 ? null : equals);
    if (!values.contains(key) && !switches.contains(key)) {
      throw _UsageException('Unknown option "$arg" for $command.');
    }
    if (options.containsKey(key)) {
      throw _UsageException('Option --$key was supplied more than once.');
    }
    if (switches.contains(key)) {
      if (equals >= 0) {
        throw _UsageException('Flag --$key does not take a value.');
      }
      options[key] = 'true';
      continue;
    }
    String value;
    if (equals >= 0) {
      value = arg.substring(equals + 1);
    } else {
      if (i + 1 == args.length ||
          args[i + 1].startsWith('--') ||
          args[i + 1] == '-h') {
        throw _UsageException('Missing value for --$key.');
      }
      value = args[++i];
    }
    if (value.trim().isEmpty) {
      throw _UsageException('Missing value for --$key.');
    }
    options[key] = value;
  }
  if (options.containsKey('frame') && options.containsKey('node')) {
    throw const _UsageException('Use either --frame or --node, not both.');
  }
  for (final key in ['frame', 'node']) {
    if (options.containsKey(key)) _selectors(options[key]!, key);
  }
  final batch = options['batch'];
  if (batch != null && (int.tryParse(batch) == null || int.parse(batch) <= 0)) {
    throw const _UsageException('--batch must be a positive integer.');
  }
  final scale = options['scale'];
  if (scale != null) {
    final parsed = double.tryParse(scale);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      throw const _UsageException('--scale must be a positive finite number.');
    }
  }
  return _Invocation(command, options);
}

Set<String> _selectors(String value, String option) {
  final parts = value.split(',').map((part) => part.trim()).toList();
  if (parts.any((part) => part.isEmpty)) {
    throw _UsageException(
        '--$option requires a nonempty comma-separated list.');
  }
  if (option == 'node' &&
      parts.any((part) => !RegExp(r'^\d+:\d+$').hasMatch(part))) {
    throw const _UsageException('--node requires exact colon-separated IDs.');
  }
  return parts.toSet();
}

Directory _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
          'pubspec.yaml not found above ${Directory.current.path}');
    }
    dir = parent;
  }
}

String _readToken(Directory root, Map<String, String> environment) {
  final fromEnv = environment['FIGMA_TOKEN'];
  if (fromEnv != null && fromEnv.trim().isNotEmpty) return fromEnv.trim();
  final file = File(p.join(root.path, '.figma-token'));
  if (!file.existsSync()) {
    throw const _ConfigurationException(
        'Missing .figma-token at the repository root (or set FIGMA_TOKEN).');
  }
  final token = file.readAsStringSync().trim();
  if (token.isEmpty) {
    throw const _ConfigurationException('The .figma-token file is empty.');
  }
  return token;
}

String _readFileKey(Directory root, Map<String, String> environment) {
  final fromEnv = environment['FIGMA_FILE'];
  if (fromEnv != null && fromEnv.trim().isNotEmpty) return _extractKey(fromEnv);
  final file = File(p.join(root.path, '.figma-design'));
  if (!file.existsSync()) {
    throw const _ConfigurationException(
        'Missing .figma-design at the repository root (or set FIGMA_FILE).');
  }
  final value = file.readAsStringSync().trim();
  if (value.isEmpty) {
    throw const _ConfigurationException('The .figma-design file is empty.');
  }
  return _extractKey(value);
}

String _extractKey(String urlOrKey) {
  final match =
      RegExp(r'figma\.com/(?:design|file)/([A-Za-z0-9]+)').firstMatch(urlOrKey);
  return match?.group(1) ?? urlOrKey;
}

class _FigmaApi {
  _FigmaApi(this.token, this.fileKey, this.client, this.output, this.errors);

  final String token;
  final String fileKey;
  final http.Client client;
  final StringSink output;
  final StringSink errors;

  /// Figma throttles the `nodes` endpoint per minute, so a 429 is normal on a full dump.
  /// Back off generously (honouring `Retry-After`) rather than failing the run.
  Future<Map<String, dynamic>> get(String path) async {
    const maxAttempts = 10;
    for (var attempt = 0;; attempt++) {
      final res = await client.get(
        Uri.parse('$_api/$path'),
        headers: {'X-Figma-Token': token},
      );
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      final retryable = res.statusCode == 429 || res.statusCode >= 500;
      if (!retryable || attempt >= maxAttempts) {
        throw StateError('Figma GET $path returned HTTP ${res.statusCode}.');
      }
      final retryAfter = int.tryParse(res.headers['retry-after'] ?? '');
      // Figma has been observed sending a nonsense Retry-After (~4 days); never honour that.
      final seconds = (retryAfter ?? 5 * (attempt + 1)).clamp(5, 120);
      errors.writeln('  ${res.statusCode} on $path — retrying in ${seconds}s '
          '(attempt ${attempt + 1}/$maxAttempts)');
      await Future<void>.delayed(Duration(seconds: seconds));
    }
  }

  Future<List<_FrameRef>> designFrames({String? page}) async {
    final file = await get('files/$fileKey?depth=2');
    final pages =
        (file['document']['children'] as List).cast<Map<String, dynamic>>();
    final refs = <_FrameRef>[];
    for (final p in pages) {
      final name = p['name'] as String;
      if (page != null && name != page) continue;
      if (page == null && !_designPages.contains(name)) continue;
      for (final f in (p['children'] as List? ?? const [])) {
        refs.add(_FrameRef(name, f['name'] as String, f['id'] as String));
      }
    }
    if (page != null && !pages.any((item) => item['name'] == page)) {
      throw _UsageException('Unknown Figma page "$page".');
    }
    return refs;
  }
}

class _FrameRef {
  _FrameRef(this.page, this.name, this.id);

  final String page;
  final String name;
  final String id;

  String get slug => name
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<_FrameRef> _selectFrames(
    List<_FrameRef> available, Map<String, String> opts) {
  final page = opts['page'];
  final scoped = [
    for (final frame in available)
      if (page == null ? _designPages.contains(frame.page) : frame.page == page)
        frame,
  ];
  final nodeValue = opts['node'];
  if (nodeValue != null) {
    final ids = _selectors(nodeValue, 'node');
    final missing = ids.difference(scoped.map((frame) => frame.id).toSet());
    if (missing.isNotEmpty) {
      throw _UsageException('Unknown Figma node(s): ${missing.join(', ')}.');
    }
    return [
      for (final frame in scoped)
        if (ids.contains(frame.id)) frame
    ];
  }
  final frameValue = opts['frame'];
  if (frameValue == null) return scoped;
  final names = _selectors(frameValue, 'frame');
  final missing =
      names.difference(scoped.map((frame) => frame.name.trim()).toSet());
  if (missing.isNotEmpty) {
    throw _UsageException('Unknown Figma frame(s): ${missing.join(', ')}.');
  }
  for (final name in names) {
    final byPage = <String, Set<String>>{};
    for (final frame in scoped) {
      if (frame.name.trim() == name) {
        (byPage[frame.page] ??= <String>{}).add(frame.id);
      }
    }
    for (final entry in byPage.entries) {
      if (entry.value.length > 1) {
        throw _UsageException(
            'Ambiguous Figma frame "$name" on "${entry.key}". '
            'Candidate IDs: ${entry.value.join(', ')}. Select with --node.');
      }
    }
  }
  return [
    for (final frame in scoped)
      if (names.contains(frame.name.trim())) frame,
  ];
}

Future<void> _listFrames(_FigmaApi api, Map<String, String> opts) async {
  final frames =
      _selectFrames(await api.designFrames(page: opts['page']), opts);
  for (final frame in frames) {
    api.output.writeln('${frame.page}\t${frame.id}\t${frame.name}');
  }
  api.output.writeln('${frames.length} frames');
}

class _SpecHeader {
  const _SpecHeader(this.id, this.name, this.size);

  final String id;
  final String name;
  final List<Object?> size;
}

class _CachedFrame {
  _CachedFrame(this.entry, this.status)
      : frame = _FrameRef(entry['page'] as String, entry['frame'] as String,
            entry['nodeId'] as String);

  final Map<String, dynamic> entry;
  final String status;
  final _FrameRef frame;
}

class _CacheCatalog {
  _CacheCatalog(this.index, this.records, this.headers, this.invalidFiles);

  final List<Map<String, dynamic>> index;
  final List<_CachedFrame> records;
  final Map<String, _SpecHeader?> headers;
  final List<String> invalidFiles;
}

String _identity(_FrameRef frame) => '${frame.page}\t${frame.id}';

File _cacheFile(Directory cache, String relative) {
  final parts = p.windows.split(relative);
  if (p.posix.isAbsolute(relative) ||
      p.windows.isAbsolute(relative) ||
      parts.contains('..')) {
    throw const FormatException('Invalid relative path in cached spec index.');
  }
  return File(p.joinAll([cache.path, ...parts]));
}

_SpecHeader? _readSpecHeader(File file) {
  if (!file.existsSync()) return null;
  try {
    final data = jsonDecode(file.readAsStringSync());
    if (data is! Map<String, dynamic> ||
        data['id'] is! String ||
        data['name'] is! String) {
      return null;
    }
    return _SpecHeader(
        data['id'] as String, data['name'] as String, [data['w'], data['h']]);
  } on FormatException {
    return null;
  }
}

String _specStatus(
    _FrameRef frame, File file, _SpecHeader? header, List<dynamic> size) {
  if (!file.existsSync()) return 'missing';
  if (header == null) return 'invalid';
  if (header.id != frame.id) return 'mismatch:${header.id}';
  if (header.name.trim() != frame.name.trim()) return 'name-mismatch';
  if (size[0] != header.size[0] || size[1] != header.size[1]) {
    return 'size-mismatch';
  }
  return 'ok';
}

Map<String, dynamic> _indexEntry(
        _FrameRef frame, String file, _SpecHeader header) =>
    {
      'page': frame.page,
      'frame': header.name,
      'nodeId': header.id,
      'file': file,
      'size': header.size,
    };

_CacheCatalog _readCacheCatalog(Directory cache) {
  final indexFile = File(p.join(cache.path, 'spec', '_index.json'));
  final index = <Map<String, dynamic>>[];
  final headers = <String, _SpecHeader?>{};
  final records = <String, _CachedFrame>{};
  final invalidFiles = <String>[];
  if (indexFile.existsSync()) {
    final decoded = jsonDecode(indexFile.readAsStringSync());
    if (decoded is! List) {
      throw const FormatException('Cached spec/_index.json must be a list.');
    }
    for (final raw in decoded) {
      if (raw is! Map<String, dynamic> ||
          raw['page'] is! String ||
          raw['frame'] is! String ||
          raw['nodeId'] is! String ||
          raw['file'] is! String ||
          raw['size'] is! List ||
          (raw['size'] as List).length != 2) {
        throw const FormatException(
            'Invalid record in cached spec/_index.json.');
      }
      index.add(raw);
      final frame = _FrameRef(raw['page'] as String, raw['frame'] as String,
          raw['nodeId'] as String);
      final relative = raw['file'] as String;
      final file = _cacheFile(cache, relative);
      if (!headers.containsKey(relative)) {
        headers[relative] = _readSpecHeader(file);
      }
      final record = _CachedFrame(raw,
          _specStatus(frame, file, headers[relative], raw['size'] as List));
      final key = _identity(frame);
      if (!records.containsKey(key) || record.status == 'ok') {
        records[key] = record;
      }
    }
  }
  final pages = {
    ..._designPages,
    for (final entry in index) entry['page'] as String,
  };
  for (final page in pages) {
    final dir = Directory(p.join(cache.path, 'spec', _slug(page)));
    if (!dir.existsSync()) continue;
    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      if (p.extension(file.path) != '.json') continue;
      final relative = p.posix.join('spec', _slug(page), p.basename(file.path));
      if (!headers.containsKey(relative)) {
        headers[relative] = _readSpecHeader(file);
      }
      final header = headers[relative];
      if (header == null) {
        invalidFiles.add(relative);
        continue;
      }
      final frame = _FrameRef(page, header.name, header.id);
      final key = _identity(frame);
      if (!records.containsKey(key) || records[key]!.status != 'ok') {
        records[key] = _CachedFrame(_indexEntry(frame, relative, header), 'ok');
      }
    }
  }
  return _CacheCatalog(index, records.values.toList(), headers, invalidFiles);
}

int _listCachedFrames(Directory cache, Map<String, String> opts,
    StringSink output, StringSink errors) {
  final catalog = _readCacheCatalog(cache);
  if (catalog.records.isEmpty) {
    throw const FormatException(
        'No cached frame metadata or valid specs. Offline mode never fetches Figma.');
  }
  final page = opts['page'];
  if (page != null &&
      !catalog.records.any((record) => record.frame.page == page)) {
    throw _UsageException('Unknown cached Figma page "$page".');
  }
  final frames = _selectFrames(
      catalog.records.map((record) => record.frame).toList(), opts);
  final selected = frames.map(_identity).toSet();
  errors.writeln('Cached-only frame lookup: not live or whole-file evidence; '
      'missing/mismatched specs are explicitly marked. No network requests.');
  for (final file in catalog.invalidFiles) {
    errors.writeln('Invalid cached spec: $file');
  }
  for (final record in catalog.records) {
    if (!selected.contains(_identity(record.frame))) continue;
    final entry = record.entry;
    final size = entry['size'] as List;
    output.writeln('${entry['page']}\t${entry['nodeId']}\t${entry['frame']}\t'
        '${entry['file']}\t${size[0]} x ${size[1]}\t${record.status}');
  }
  output.writeln('${frames.length} cached frames');
  return 0;
}

String _specAlias(_FrameRef frame) =>
    p.posix.join('spec', _slug(frame.page), '${frame.slug}.json');

String _pngAlias(_FrameRef frame) =>
    p.posix.join('shots', '${_slug(frame.page)}__${frame.slug}.png');

String _nodePath(String alias, String id) =>
    '${p.posix.withoutExtension(alias)}__${id.replaceAll(':', '_')}'
    '${p.posix.extension(alias)}';

Map<String, List<_FrameRef>> _aliasGroups(
    List<_FrameRef> frames, String Function(_FrameRef) alias) {
  final groups = <String, List<_FrameRef>>{};
  for (final frame in frames) {
    // The cache is shared with Windows, so case-only collisions are collisions too.
    (groups[alias(frame).toLowerCase()] ??= []).add(frame);
  }
  return groups;
}

bool _ownsAlias(_FrameRef frame, List<_FrameRef> group) {
  if (group.length == 1) return true;
  final unpadded =
      group.where((item) => item.name == item.name.trim()).toList();
  return unpadded.length == 1 && unpadded.single.id == frame.id;
}

void _preserveSpecAlias(Directory cache, String alias, String page,
    _CacheCatalog catalog, Map<String, Map<String, dynamic>> updates) {
  final header = catalog.headers[alias];
  if (header == null) return;
  final preserved = _nodePath(alias, header.id);
  final file = _cacheFile(cache, preserved);
  final existing = _readSpecHeader(file);
  if (file.existsSync() && existing?.id != header.id) {
    throw FormatException('Refusing to overwrite conflicting spec $preserved.');
  }
  if (!file.existsSync()) {
    file.parent.createSync(recursive: true);
    _cacheFile(cache, alias).copySync(file.path);
  }
  final actual = existing ?? header;
  catalog.headers[preserved] = actual;
  final frame = _FrameRef(page, actual.name, actual.id);
  updates[_identity(frame)] = _indexEntry(frame, preserved, actual);
}

List<Map<String, dynamic>> _mergeIndex(
    _CacheCatalog catalog, Map<String, Map<String, dynamic>> updates) {
  final merged = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final entry in catalog.index) {
    final key = '${entry['page']}\t${entry['nodeId']}';
    final update = updates[key];
    if (update != null) {
      if (!seen.add(key)) continue;
      merged.add({...entry, ...update});
    } else {
      merged.add(entry);
      seen.add(key);
    }
  }
  for (final entry in updates.entries) {
    if (seen.add(entry.key)) merged.add(entry.value);
  }
  for (final record in catalog.records) {
    if (record.status == 'ok' && seen.add(_identity(record.frame))) {
      merged.add(record.entry);
    }
  }
  return merged;
}

Future<int> _dumpSpec(
    _FigmaApi api, Directory outDir, Map<String, String> opts) async {
  final available = await api.designFrames(page: opts['page']);
  final frames = _selectFrames(available, opts);
  final catalog = _readCacheCatalog(outDir);
  final groups = _aliasGroups(available, _specAlias);
  final updates = <String, Map<String, dynamic>>{};
  final paths = <String, String>{};
  for (final frame in frames) {
    final alias = _specAlias(frame);
    final old = catalog.headers.containsKey(alias)
        ? catalog.headers[alias]
        : _readSpecHeader(_cacheFile(outDir, alias));
    catalog.headers[alias] = old;
    final collision = groups[alias.toLowerCase()]!.length > 1 ||
        (old != null && old.id != frame.id);
    final path = collision ? _nodePath(alias, frame.id) : alias;
    paths[_identity(frame)] = path;
    if (collision) {
      _preserveSpecAlias(outDir, alias, frame.page, catalog, updates);
    }
    final file = _cacheFile(outDir, path);
    final header = catalog.headers.containsKey(path)
        ? catalog.headers[path]
        : _readSpecHeader(file);
    catalog.headers[path] = header;
    if (path != alias && file.existsSync() && header?.id != frame.id) {
      throw FormatException('Refusing to overwrite conflicting spec $path.');
    }
  }
  final batch = int.parse(opts['batch'] ?? '20');
  final force = opts.containsKey('force');
  var failed = false;
  for (var i = 0; i < frames.length; i += batch) {
    final slice = frames.skip(i).take(batch).toList();
    final pending = [
      for (final frame in slice)
        if (force ||
            catalog.headers[paths[_identity(frame)]]?.id != frame.id ||
            catalog.headers[paths[_identity(frame)]]?.name.trim() !=
                frame.name.trim())
          frame,
    ];
    if (pending.isNotEmpty) {
      final ids =
          pending.map((frame) => Uri.encodeComponent(frame.id)).join(',');
      final nodes = await api.get('files/${api.fileKey}/nodes?ids=$ids');
      final byId = (nodes['nodes'] as Map).cast<String, dynamic>();
      for (final frame in pending) {
        final entry = byId[frame.id];
        if (entry == null || entry['document'] == null) {
          api.errors.writeln('No document for ${frame.name} (${frame.id}).');
          failed = true;
          continue;
        }
        final document = (entry['document'] as Map).cast<String, dynamic>();
        if (document['id'] != frame.id ||
            (document['name'] as String).trim() != frame.name.trim()) {
          throw FormatException('Mismatched Figma spec for node ${frame.id}.');
        }
        final spec = _compactNode(document);
        final path = paths[_identity(frame)]!;
        final file = _cacheFile(outDir, path);
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert(spec));
        catalog.headers[path] = _SpecHeader(spec['id'] as String,
            spec['name'] as String, [spec['w'], spec['h']]);
      }
    }
    api.output.writeln(
        '[${i + slice.length}/${frames.length}] ${slice.first.page} .. ${slice.last.name}');
  }
  for (final frame in frames) {
    final path = paths[_identity(frame)]!;
    final header = catalog.headers[path];
    if (header == null ||
        header.id != frame.id ||
        header.name.trim() != frame.name.trim()) {
      continue;
    }
    updates[_identity(frame)] = _indexEntry(frame, path, header);
    final alias = _specAlias(frame);
    if (path != alias && _ownsAlias(frame, groups[alias.toLowerCase()]!)) {
      _cacheFile(outDir, path).copySync(_cacheFile(outDir, alias).path);
      catalog.headers[alias] = header;
    }
  }
  final index = _mergeIndex(catalog, updates);
  final indexFile = File(p.join(outDir.path, 'spec', '_index.json'));
  indexFile.parent.createSync(recursive: true);
  indexFile
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(index));
  api.output.writeln('Wrote ${index.length} cached index records; '
      '${updates.length} verified entries updated.');
  return failed ? 65 : 0;
}

Future<int> _dumpPng(
    _FigmaApi api, Directory outDir, Map<String, String> opts) async {
  final available = await api.designFrames(page: opts['page']);
  final selected = _selectFrames(available, opts);
  final groups = _aliasGroups(available, _pngAlias);
  final paths = <String, String>{};
  for (final frame in selected) {
    final alias = _pngAlias(frame);
    paths[_identity(frame)] = groups[alias.toLowerCase()]!.length > 1
        ? _nodePath(alias, frame.id)
        : alias;
  }
  final frames = [
    for (final frame in selected)
      if (opts.containsKey('force') ||
          !_cacheFile(outDir, paths[_identity(frame)]!).existsSync())
        frame,
  ];
  final batch = int.parse(opts['batch'] ?? '8');
  final scale = opts['scale'] ?? '2';
  var failed = false;
  for (var i = 0; i < frames.length; i += batch) {
    final slice = frames.skip(i).take(batch).toList();
    final ids = slice.map((frame) => Uri.encodeComponent(frame.id)).join(',');
    final res =
        await api.get('images/${api.fileKey}?ids=$ids&format=png&scale=$scale');
    final images = (res['images'] as Map).cast<String, dynamic>();
    for (final frame in slice) {
      final url = images[frame.id] as String?;
      if (url == null || url.isEmpty) {
        api.errors.writeln('No render for ${frame.name} (${frame.id}).');
        failed = true;
        continue;
      }
      final bytes = await api.client.readBytes(Uri.parse(url));
      final file = _cacheFile(outDir, paths[_identity(frame)]!);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
    }
    api.output.writeln('Rendered ${i + slice.length}/${frames.length}');
  }
  for (final frame in selected) {
    final path = paths[_identity(frame)]!;
    final alias = _pngAlias(frame);
    if (path != alias &&
        _ownsAlias(frame, groups[alias.toLowerCase()]!) &&
        _cacheFile(outDir, path).existsSync()) {
      _cacheFile(outDir, path).copySync(_cacheFile(outDir, alias).path);
    }
  }
  if (frames.isEmpty) {
    api.output.writeln('All requested Figma PNGs already exist.');
  }
  return failed ? 65 : 0;
}

/// Exports named nodes as SVG. The map is `{file-safe name: nodeId}`; a frame or component
/// node renders with all of its children, so a whole icon (bell + badge) comes out in one file.
Future<void> _dumpSvg(
    _FigmaApi api, Directory outDir, Map<String, String> opts) async {
  final mapFile = File(opts['map'] ?? p.join(outDir.path, 'icons.json'));
  if (!mapFile.existsSync()) {
    throw StateError(
        'missing icon map at ${mapFile.path} — expected {"name": "nodeId"}');
  }
  final map =
      (jsonDecode(mapFile.readAsStringSync()) as Map).cast<String, String>();
  final dir = Directory(opts['out'] ?? 'assets/icons/design')
    ..createSync(recursive: true);
  final entries = map.entries.toList();
  var written = 0;
  for (var i = 0; i < entries.length; i += 10) {
    final slice = entries.skip(i).take(10).toList();
    final ids = slice.map((e) => Uri.encodeComponent(e.value)).join(',');
    final res = await api.get('images/${api.fileKey}?ids=$ids&format=svg');
    final images = (res['images'] as Map).cast<String, dynamic>();
    for (final e in slice) {
      final url = images[e.value] as String?;
      if (url == null || url.isEmpty) {
        api.errors.writeln('no svg returned for ${e.key} (${e.value})');
        continue;
      }
      final body = await api.client.read(Uri.parse(url));
      File(p.join(dir.path, '${e.key}.svg')).writeAsStringSync(body);
      written++;
      api.output.writeln('$written. ${e.key}.svg  <- ${e.value}');
    }
  }
  api.output.writeln('wrote $written svg files to ${dir.path}');
}

String _slug(String s) => s
    .replaceAll(RegExp(r'[\\/:*?"<>|()]+'), '_')
    .replaceAll(RegExp(r'\s+'), '_')
    .trim();

/// Compact, style-oriented view of a Figma node. Absolute geometry is kept so a frame
/// can be rebuilt bottom-up; world-space coordinates are relative to the frame origin.
Map<String, dynamic> _compactNode(Map<String, dynamic> n) {
  final bb = n['absoluteBoundingBox'] as Map<String, dynamic>?;
  final out = <String, dynamic>{
    'id': n['id'],
    'name': n['name'],
    'type': n['type'],
  };
  if (bb != null) {
    out['x'] = _round(bb['x']);
    out['y'] = _round(bb['y']);
    out['w'] = _round(bb['width']);
    out['h'] = _round(bb['height']);
  }
  if (n['opacity'] != null && (n['opacity'] as num) < 1) {
    out['opacity'] = n['opacity'];
  }
  if (n['visible'] == false) out['hidden'] = true;
  final corner = n['cornerRadius'];
  if (corner != null) out['r'] = corner;
  if (n['rectangleCornerRadii'] != null) out['r4'] = n['rectangleCornerRadii'];
  final fills = _paint(n['fills']);
  if (fills.isNotEmpty) out['fill'] = fills;
  final strokes = _paint(n['strokes']);
  if (strokes.isNotEmpty) {
    out['stroke'] = strokes;
    out['strokeWeight'] = n['strokeWeight'];
  }
  final effects = _effects(n['effects']);
  if (effects.isNotEmpty) out['effects'] = effects;
  final layout = _layout(n);
  if (layout.isNotEmpty) out['layout'] = layout;
  if (n['type'] == 'TEXT') out['text'] = _text(n);
  final kids = (n['children'] as List?)?.cast<Map<String, dynamic>>();
  if (kids != null && kids.isNotEmpty) {
    out['children'] = kids.map(_compactNode).toList();
  }
  return out;
}

double _round(Object? v) => ((v as num).toDouble() * 100).roundToDouble() / 100;

List<String> _paint(Object? paints) {
  final out = <String>[];
  for (final raw in (paints as List? ?? const [])) {
    final p = (raw as Map).cast<String, dynamic>();
    if (p['visible'] == false) continue;
    final type = p['type'] as String;
    if (type == 'SOLID') {
      final c = (p['color'] as Map).cast<String, dynamic>();
      final a = ((p['opacity'] ?? 1) as num) * ((c['a'] ?? 1) as num);
      out.add('${_hex(c)}${a < 1 ? '@${a.toStringAsFixed(2)}' : ''}');
    } else if (type.startsWith('GRADIENT')) {
      final stops = (p['gradientStops'] as List? ?? const [])
          .map((s) => (s as Map).cast<String, dynamic>())
          .map((s) =>
              '${_hex((s['color'] as Map).cast<String, dynamic>())}@${_round(s['position'])}')
          .join(',');
      out.add(
          '$type(${p['gradientHandlePositions'] != null ? 'stops:$stops' : ''})');
    } else if (type == 'IMAGE') {
      out.add('IMAGE:${p['imageRef']}:${p['scaleMode']}');
    } else {
      out.add(type);
    }
  }
  return out;
}

String _hex(Map<String, dynamic> c) => '#'
    '${_b(c['r'])}${_b(c['g'])}${_b(c['b'])}';

String _b(Object? v) =>
    ((v as num) * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();

List<Map<String, dynamic>> _effects(Object? effects) {
  final out = <Map<String, dynamic>>[];
  for (final raw in (effects as List? ?? const [])) {
    final e = (raw as Map).cast<String, dynamic>();
    if (e['visible'] == false) continue;
    // Keep every field: GLASS (Figma's glass material) carries parameters that are not in
    // the public REST docs, so the spec is the only place we can read them back from.
    final shadow = <String, dynamic>{...e}..remove('visible');
    if (e['color'] != null) {
      final c = (e['color'] as Map).cast<String, dynamic>();
      final alpha = (c['a'] as num? ?? 1).toDouble();
      shadow['color'] =
          '${_hex(c)}${alpha < 1 ? '@${alpha.toStringAsFixed(2)}' : ''}';
    }
    if (e['offset'] != null) {
      shadow['offset'] = [_round(e['offset']['x']), _round(e['offset']['y'])];
    }
    out.add(shadow);
  }
  return out;
}

Map<String, dynamic> _layout(Map<String, dynamic> n) {
  final out = <String, dynamic>{};
  if (n['layoutMode'] != null && n['layoutMode'] != 'NONE') {
    out['mode'] = n['layoutMode'];
    out['gap'] = n['itemSpacing'];
    out['padding'] = [
      n['paddingTop'] ?? 0,
      n['paddingRight'] ?? 0,
      n['paddingBottom'] ?? 0,
      n['paddingLeft'] ?? 0,
    ];
    out['primary'] = n['primaryAxisAlignItems'];
    out['counter'] = n['counterAxisAlignItems'];
    if (n['itemSpacing'] == null && n['layoutMode'] != null) out['gap'] = 0;
  }
  if (n['layoutSizingHorizontal'] != null) {
    out['sizing'] = [n['layoutSizingHorizontal'], n['layoutSizingVertical']];
  }
  if (n['clipsContent'] == true) out['clip'] = true;
  return out;
}

Map<String, dynamic> _text(Map<String, dynamic> n) {
  final st = (n['style'] as Map).cast<String, dynamic>();
  return {
    'chars': n['characters'],
    'font': st['fontPostScriptName'] ?? st['fontFamily'],
    'family': st['fontFamily'],
    'weight': st['fontWeight'],
    'size': st['fontSize'],
    'lineHeightPx': _round(st['lineHeightPx'] ?? 0),
    'lineHeightUnit': st['lineHeightUnit'],
    'letterSpacing': st['letterSpacing'],
    'align': st['textAlignHorizontal'],
    'valign': st['textAlignVertical'],
    if (st['textDecoration'] != null) 'decoration': st['textDecoration'],
    if (st['textCase'] != null) 'case': st['textCase'],
    if (n['textAutoResize'] != null) 'autoResize': n['textAutoResize'],
  };
}
