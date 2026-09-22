// Dev tool: turn the dumped Figma spec into a frequency report used to curate `lib/design`.
//
//   dart run tool/design_report.dart                    # both themes
//   dart run tool/design_report.dart --page Dark        # filter by page substring
//
// Input: `.figma_cache/spec/**` produced by `tool/figma_spec.dart spec`.
// Output: console summary + `.figma_cache/report.md` (full histograms).
//
// The point is to answer "which values are real and how often do they occur" before a single
// token is written — a colour used once on one frame is not a design token.

import 'dart:convert';
import 'dart:io';

final _colors = <String, int>{};
final _texts = <String, int>{};
final _radii = <String, int>{};
final _effects = <String, int>{};
final _gaps = <String, int>{};
final _paddings = <String, int>{};
final _sizes = <String, int>{};
final _perFrame = <String, Map<String, int>>{};

void main(List<String> args) {
  final filter = _flag(args, 'page');
  final root = _repoRoot();
  final specDir = Directory('${root.path}/.figma_cache/spec');
  if (!specDir.existsSync()) {
    stderr.writeln('no spec found — run: dart run tool/figma_spec.dart spec');
    exitCode = 2;
    return;
  }

  var files = 0;
  for (final entity in specDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    if (entity.path.endsWith('_index.json')) continue;
    if (filter != null && !entity.path.toLowerCase().contains(filter.toLowerCase())) continue;
    final frame = jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
    files++;
    _visit(frame, frame);
  }

  final md = StringBuffer()
    ..writeln('# Design spec report')
    ..writeln()
    ..writeln('$files frames analysed'
        '${filter == null ? '' : ' (filter: $filter)'}')
    ..writeln()
    ..writeln('## Frame sizes\n')
    ..writeln(_table(_sizes))
    ..writeln('## Colors (fills, strokes, effect colors)\n')
    ..writeln(_table(_colors))
    ..writeln('## Text styles\n')
    ..writeln(_table(_texts))
    ..writeln('## Corner radii\n')
    ..writeln(_table(_radii))
    ..writeln('## Effects\n')
    ..writeln(_table(_effects))
    ..writeln('## Auto-layout gaps\n')
    ..writeln(_table(_gaps))
    ..writeln('## Auto-layout paddings (t r b l)\n')
    ..writeln(_table(_paddings));
  File('${root.path}/.figma_cache/report.md').writeAsStringSync(md.toString());

  stdout
    ..writeln('frames analysed: $files')
    ..writeln('frame sizes: ${_sizes.entries.take(5).map((e) => '${e.key}×${e.value}').join(', ')}')
    ..writeln('distinct colours: ${_colors.length}, text styles: ${_texts.length}, '
        'radii: ${_radii.length}, effects: ${_effects.length}')
    ..writeln('\ntop colours:')
    ..writeln(_table(_colors, limit: 20))
    ..writeln('top text styles (family|weight|size|lineHeight×|letterSpacing|align|deco):')
    ..writeln(_table(_texts, limit: 30))
    ..writeln('radii:')
    ..writeln(_table(_radii))
    ..writeln('effects:')
    ..writeln(_table(_effects))
    ..writeln('\nfull report: .figma_cache/report.md');
}

void _visit(Map<String, dynamic> node, Map<String, dynamic> frame) {
  final name = frame['name'] as String;
  final counts = _perFrame.putIfAbsent(name, () => <String, int>{});

  if (node == frame && node['w'] != null) {
    _bump(_sizes, '${node['w']}×${node['h']}');
  }
  for (final fill in (node['fill'] as List? ?? const [])) {
    _bump(_colors, fill as String);
    _bump(counts, 'fill');
  }
  for (final stroke in (node['stroke'] as List? ?? const [])) {
    _bump(_colors, stroke as String);
  }
  if (node['r'] != null) _bump(_radii, '${node['r']}');
  if (node['r4'] != null) _bump(_radii, 'corners:${node['r4']}');
  for (final effect in (node['effects'] as List? ?? const [])) {
    final e = (effect as Map).cast<String, dynamic>();
    final type = e['type'] as String;
    _bump(_effects, type);
    if (e['color'] != null) _bump(_colors, '${e['color']} (${type.toLowerCase()})');
    if (type == 'GLASS' || type.contains('BLUR')) {
      _bump(_effects, '$type ${e.entries.where((x) => x.key != 'type' && x.key != 'color').map((x) => '${x.key}=${x.value}').join(' ')}');
    } else {
      _bump(_effects, '$type radius=${e['radius']} offset=${e['offset']}');
    }
  }
  final layout = node['layout'] as Map<String, dynamic>?;
  if (layout != null) {
    if (layout['gap'] != null) _bump(_gaps, '${layout['gap']}');
    final pad = layout['padding'] as List?;
    if (pad != null && pad.any((v) => (v as num) != 0)) {
      _bump(_paddings, pad.join(' '));
    }
  }
  final text = node['text'] as Map<String, dynamic>?;
  if (text != null) {
    final size = (text['size'] as num).toDouble();
    final lh = (text['lineHeightPx'] as num).toDouble();
    final ratio = size == 0 ? 0.0 : (lh / size);
    final key = [
      text['family'],
      'w${text['weight']}',
      '${_num(size)}px',
      'lh×${ratio.toStringAsFixed(3)}',
      'ls${text['letterSpacing']}',
      text['align'],
      if (text['decoration'] != null) text['decoration'],
      if (text['case'] != null) text['case'],
    ].join('|');
    _bump(_texts, key);
  }
  for (final child in (node['children'] as List? ?? const [])) {
    _visit((child as Map).cast<String, dynamic>(), frame);
  }
}

String _num(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

void _bump(Map<String, int> map, String key) => map[key] = (map[key] ?? 0) + 1;

String _table(Map<String, int> map, {int limit = 400}) {
  final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return entries
      .take(limit)
      .map((e) => '- `${e.key}` × ${e.value}')
      .join('\n');
}

String? _flag(List<String> args, String name) {
  final i = args.indexOf('--$name');
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

Directory _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('pubspec.yaml not found');
    dir = parent;
  }
}
