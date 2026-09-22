// Dev tool: dump the redesign Figma file into a compact, machine-readable spec.
//
// Not shipped with the app. Run it whenever the design file changes:
//
//   dart run tool/figma_spec.dart spec          # dump every frame of the design pages
//   dart run tool/figma_spec.dart spec --page "Design System (Dark)"
//   dart run tool/figma_spec.dart png           # render frames to PNG for visual diffing
//   dart run tool/figma_spec.dart frames        # list pages/frames only
//
// Credentials: `.figma-token` at the repo root (git-ignored) or FIGMA_TOKEN env var.
// Target file: `.figma-design` at the repo root (a Figma URL) or FIGMA_FILE env var.
//
// Output lands in `.figma_cache/` (git-ignored): `spec/<page>/<frame>.json`, `shots/*.png`.
// Every dumped node keeps absolute geometry, fills, radii, effects, auto-layout and text
// metrics, which is what the Flutter side is built and verified against.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _api = 'https://api.figma.com/v1';
const _designPages = ['Design System (Dark)', 'Design System (Light)'];

Future<void> main(List<String> args) async {
  final cmd = args.isEmpty ? 'spec' : args.first;
  final opts = _parseFlags(args.skip(1).toList());

  final root = _repoRoot();
  final token = _readToken(root);
  final fileKey = _readFileKey(root);
  final outDir = Directory('${root.path}/.figma_cache')..createSync(recursive: true);
  final api = _FigmaApi(token, fileKey);

  switch (cmd) {
    case 'frames':
      await _listFrames(api, opts);
    case 'spec':
      await _dumpSpec(api, outDir, opts);
    case 'png':
      await _dumpPng(api, outDir, opts);
    case 'svg':
      await _dumpSvg(api, outDir, opts);
    default:
      stderr.writeln('unknown command "$cmd" (frames|spec|png|svg)');
      exitCode = 2;
  }
}

Map<String, String> _parseFlags(List<String> args) {
  final flags = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('--') && i + 1 < args.length) {
      flags[args[i].substring(2)] = args[++i];
    } else if (args[i].startsWith('--')) {
      flags[args[i].substring(2)] = 'true';
    }
  }
  return flags;
}

Directory _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('pubspec.yaml not found above ${Directory.current.path}');
    }
    dir = parent;
  }
}

String _readToken(Directory root) {
  final fromEnv = Platform.environment['FIGMA_TOKEN'];
  if (fromEnv != null && fromEnv.trim().isNotEmpty) return fromEnv.trim();
  final file = File('${root.path}/.figma-token');
  if (!file.existsSync()) {
    throw StateError('missing .figma-token at ${root.path} (or set FIGMA_TOKEN)');
  }
  return file.readAsStringSync().trim();
}

String _readFileKey(Directory root) {
  final fromEnv = Platform.environment['FIGMA_FILE'];
  if (fromEnv != null && fromEnv.trim().isNotEmpty) return _extractKey(fromEnv);
  final file = File('${root.path}/.figma-design');
  if (!file.existsSync()) {
    throw StateError('missing .figma-design at ${root.path} (or set FIGMA_FILE)');
  }
  return _extractKey(file.readAsStringSync().trim());
}

String _extractKey(String urlOrKey) {
  final match = RegExp(r'figma\.com/(?:design|file)/([A-Za-z0-9]+)').firstMatch(urlOrKey);
  return match?.group(1) ?? urlOrKey;
}

class _FigmaApi {
  _FigmaApi(this.token, this.fileKey);

  final String token;
  final String fileKey;

  /// Figma throttles the `nodes` endpoint per minute, so a 429 is normal on a full dump.
  /// Back off generously (honouring `Retry-After`) rather than failing the run.
  Future<Map<String, dynamic>> get(String path) async {
    const maxAttempts = 10;
    for (var attempt = 0; ; attempt++) {
      final res = await http.get(
        Uri.parse('$_api/$path'),
        headers: {'X-Figma-Token': token},
      );
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      final retryable = res.statusCode == 429 || res.statusCode >= 500;
      if (!retryable || attempt >= maxAttempts) {
        throw StateError('GET $path -> ${res.statusCode}: ${res.body}');
      }
      final retryAfter = int.tryParse(res.headers['retry-after'] ?? '');
      // Figma has been observed sending a nonsense Retry-After (~4 days); never honour that.
      final seconds = (retryAfter ?? 5 * (attempt + 1)).clamp(5, 120);
      stderr.writeln('  ${res.statusCode} on $path — retrying in ${seconds}s '
          '(attempt ${attempt + 1}/$maxAttempts)');
      await Future<void>.delayed(Duration(seconds: seconds));
    }
  }

  Future<List<_FrameRef>> designFrames({String? page}) async {
    final file = await get('files/$fileKey?depth=2');
    final pages = (file['document']['children'] as List).cast<Map<String, dynamic>>();
    final refs = <_FrameRef>[];
    for (final p in pages) {
      final name = p['name'] as String;
      if (page != null && name != page) continue;
      if (page == null && !_designPages.contains(name)) continue;
      for (final f in (p['children'] as List? ?? const [])) {
        refs.add(_FrameRef(name, f['name'] as String, f['id'] as String));
      }
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

Future<void> _listFrames(_FigmaApi api, Map<String, String> opts) async {
  final frames = await api.designFrames(page: opts['page']);
  for (final f in frames) {
    stdout.writeln('${f.page}\t${f.id}\t${f.name}');
  }
  stdout.writeln('${frames.length} frames');
}

Future<void> _dumpSpec(_FigmaApi api, Directory outDir, Map<String, String> opts) async {
  final frames = await api.designFrames(page: opts['page']);
  // The `nodes` endpoint is throttled per call, so fetch many frames per request: a whole
  // design page is only ~20 MB. Resumable — already-written frames are skipped.
  final batch = int.tryParse(opts['batch'] ?? '') ?? 20;
  final force = opts['force'] == 'true';
  final index = <Map<String, dynamic>>[];
  var done = 0;

  for (var i = 0; i < frames.length; i += batch) {
    final slice = frames.skip(i).take(batch).toList();
    final pending = <_FrameRef>[];
    for (final f in slice) {
      final dir = Directory('${outDir.path}/spec/${_slug(f.page)}')..createSync(recursive: true);
      if (File('${dir.path}/${f.slug}.json').existsSync() && !force) continue;
      pending.add(f);
    }
    if (pending.isEmpty) {
      done += slice.length;
      continue;
    }
    final ids = pending.map((f) => f.id).join(',');
    final nodes = await api.get('files/${api.fileKey}/nodes?ids=$ids');
    final byId = (nodes['nodes'] as Map).cast<String, dynamic>();
    for (final f in pending) {
      final entry = byId[f.id];
      if (entry == null || entry['document'] == null) {
        stderr.writeln('no document for ${f.name} (${f.id})');
        continue;
      }
      final spec = _compactNode((entry['document'] as Map).cast<String, dynamic>());
      final dir = Directory('${outDir.path}/spec/${_slug(f.page)}')..createSync(recursive: true);
      File('${dir.path}/${f.slug}.json')
          .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(spec));
    }
    done += slice.length;
    stdout.writeln('[$done/${frames.length}] ${slice.first.page} .. ${slice.last.name}');
  }

  for (final f in frames) {
    final file = File('${outDir.path}/spec/${_slug(f.page)}/${f.slug}.json');
    if (!file.existsSync()) continue;
    final spec = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    index.add({
      'page': f.page,
      'frame': f.name,
      'nodeId': f.id,
      'file': 'spec/${_slug(f.page)}/${f.slug}.json',
      'size': [spec['w'], spec['h']],
    });
  }
  File('${outDir.path}/spec/_index.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(index));
  stdout.writeln('wrote ${index.length} frame specs to ${outDir.path}/spec');
}

Future<void> _dumpPng(_FigmaApi api, Directory outDir, Map<String, String> opts) async {
  final frames = await api.designFrames(page: opts['page']);
  final scale = opts['scale'] ?? '2';
  final shots = Directory('${outDir.path}/shots')..createSync(recursive: true);
  for (var i = 0; i < frames.length; i += 8) {
    final slice = frames.skip(i).take(8).toList();
    final ids = slice.map((f) => f.id).join(',');
    final res = await api.get('images/${api.fileKey}?ids=$ids&format=png&scale=$scale');
    final images = (res['images'] as Map).cast<String, dynamic>();
    for (final f in slice) {
      final url = images[f.id] as String?;
      if (url == null) {
        stderr.writeln('no render for ${f.name} (${f.id})');
        continue;
      }
      final bytes = await http.readBytes(Uri.parse(url));
      File('${shots.path}/${_slug(f.page)}__${f.slug}.png').writeAsBytesSync(bytes);
    }
    stdout.writeln('rendered ${i + slice.length}/${frames.length}');
  }
}

/// Exports named nodes as SVG. The map is `{file-safe name: nodeId}`; a frame or component
/// node renders with all of its children, so a whole icon (bell + badge) comes out in one file.
Future<void> _dumpSvg(_FigmaApi api, Directory outDir, Map<String, String> opts) async {
  final mapFile = File(opts['map'] ?? '${outDir.path}/icons.json');
  if (!mapFile.existsSync()) {
    throw StateError('missing icon map at ${mapFile.path} — expected {"name": "nodeId"}');
  }
  final map = (jsonDecode(mapFile.readAsStringSync()) as Map).cast<String, String>();
  final dir = Directory(opts['out'] ?? 'assets/icons/design')..createSync(recursive: true);
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
        stderr.writeln('no svg returned for ${e.key} (${e.value})');
        continue;
      }
      final body = await http.read(Uri.parse(url));
      File('${dir.path}/${e.key}.svg').writeAsStringSync(body);
      written++;
      stdout.writeln('$written. ${e.key}.svg  <- ${e.value}');
    }
  }
  stdout.writeln('wrote $written svg files to ${dir.path}');
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
  if (n['opacity'] != null && (n['opacity'] as num) < 1) out['opacity'] = n['opacity'];
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
          .map((s) => '${_hex((s['color'] as Map).cast<String, dynamic>())}@${_round(s['position'])}')
          .join(',');
      out.add('$type(${p['gradientHandlePositions'] != null ? 'stops:$stops' : ''})');
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

String _b(Object? v) => ((v as num) * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();

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
      shadow['color'] = '${_hex(c)}${alpha < 1 ? '@${alpha.toStringAsFixed(2)}' : ''}';
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
