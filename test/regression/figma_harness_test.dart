import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import '../../tool/figma_spec.dart';

const _dark = 'Design System (Dark)';
const _light = 'Design System (Light)';
const _darkDir = 'spec/Design_System__Dark_';
const _lightDir = 'spec/Design_System__Light_';
const _home = 'Home';
const _frames = <String, String>{
  '1:1': _home,
  '1:2': 'Home ',
  '1:3': 'Catalog',
};

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('figma_harness_');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  test('help works without credentials and does not create a cache', () async {
    for (final args in [
      ['--help'],
      ['frames', '-h'],
      ['svg', '--help'],
    ]) {
      final result = await _invoke(root, args);
      expect(result.code, 0);
      expect(result.err, isEmpty);
      expect(
          Directory(p.join(root.path, '.figma_cache')).existsSync(), isFalse);
    }
  });

  test('invalid commands and options fail before credentials or network',
      () async {
    for (final args in [
      ['unknown'],
      ['spec', '--unknown'],
      ['frames', '--offline', '--force'],
      ['spec', '--offline'],
      ['svg', '--node', '1:1'],
      ['spec', '--batch'],
      ['spec', '--batch', '0'],
      ['spec', '--batch', '-1'],
      ['spec', '--batch', 'nonsense'],
      ['png', '--scale', '0'],
      ['png', '--scale', '-1'],
      ['png', '--scale', 'NaN'],
      ['png', '--scale', 'Infinity'],
      ['frames', '--page', '--offline'],
      ['spec', '--node', ''],
      ['spec', '--node', '1:1,'],
      ['spec', '--node', '1-1'],
      ['spec', '--frame', 'Home', '--node', '1:1'],
      ['png', '--force=true'],
      ['frames', '--page', _dark, '--page', _light],
      ['spec', 'unexpected'],
    ]) {
      final result = await _invoke(root, args);
      expect(result.code, 64, reason: args.join(' '));
      expect(result.out, isEmpty, reason: args.join(' '));
      expect(
          Directory(p.join(root.path, '.figma_cache')).existsSync(), isFalse);
    }
  });

  test(
      'offline lookup supplements light specs and exposes stale or missing IDs',
      () async {
    _writeJson(root, '$_darkDir/Home.json', _spec('1:2', 'Home '));
    _writeJson(root, '$_lightDir/Catalog.json', _spec('2:3', 'Catalog'));
    _writeJson(root, 'spec/_index.json', [
      _entry(_dark, 'Home', '1:1', '$_darkDir/Home.json'),
      _entry(_dark, 'Missing', '1:9', '$_darkDir/Missing.json'),
    ]);
    final originalIndex = _index(root);

    final result = await _invoke(root, ['frames', '--offline']);

    expect(result.code, 0);
    final rows = _rows(result.out);
    expect(rows.map((row) => row[1]).toSet(), {'1:1', '1:2', '1:9', '2:3'});
    expect(rows.singleWhere((row) => row[1] == '1:1')[5], 'mismatch:1:2');
    expect(rows.singleWhere((row) => row[1] == '1:9')[5], 'missing');
    expect(rows.singleWhere((row) => row[1] == '1:2')[2], 'Home ');
    expect(rows.singleWhere((row) => row[1] == '2:3')[0], _light);
    expect(_index(root), originalIndex);
  });

  test(
      'offline names reject same-page ambiguity and nodes select exact variants',
      () async {
    _writeJson(root, '$_darkDir/Home__1_1.json', _spec('1:1', 'Home'));
    _writeJson(root, '$_darkDir/Home__1_2.json', _spec('1:2', 'Home '));
    _writeJson(root, '$_lightDir/Home.json', _spec('2:1', 'Home'));

    final ambiguous = await _invoke(root, [
      'frames',
      '--offline',
      '--page',
      _dark,
      '--frame',
      'Home',
    ]);
    expect(ambiguous.code, 64);
    expect(ambiguous.out, isEmpty);
    expect(ambiguous.err, contains('1:1'));
    expect(ambiguous.err, contains('1:2'));

    final exact = await _invoke(root, [
      'frames',
      '--offline',
      '--node',
      '1:2',
    ]);
    expect(exact.code, 0);
    expect(_rows(exact.out).map((row) => row[1]), ['1:2']);

    final light = await _invoke(root, [
      'frames',
      '--offline',
      '--page',
      _light,
      '--frame',
      'Home',
    ]);
    expect(light.code, 0);
    expect(_rows(light.out).map((row) => row[1]), ['2:1']);
  });

  test('empty offline caches fail explicitly rather than fetching Figma',
      () async {
    final result = await _invoke(root, ['frames', '--offline']);
    expect(result.code, 65);
    expect(result.out, isEmpty);
  });

  test('live frame selection rejects ambiguity consistently for every consumer',
      () async {
    for (final command in ['frames', 'spec', 'png']) {
      final result = await _invoke(
          root,
          [
            command,
            '--page',
            _dark,
            '--frame',
            'Home',
          ],
          live: true,
          client: _liveClient());
      expect(result.code, 64, reason: command);
      expect(result.out, isEmpty, reason: command);
      expect(result.err, contains('1:1'), reason: command);
      expect(result.err, contains('1:2'), reason: command);
      expect(
          Directory(p.join(root.path, '.figma_cache')).existsSync(), isFalse);
    }
  });

  test('unknown exact live selectors are usage errors without exports',
      () async {
    for (final selection in [
      ['--node', '1:99'],
      ['--frame', 'Missing'],
      ['--page', 'Missing page'],
    ]) {
      final result = await _invoke(root, ['spec', ...selection],
          live: true, client: _liveClient());
      expect(result.code, 64);
      expect(result.out, isEmpty);
      expect(
          Directory(p.join(root.path, '.figma_cache')).existsSync(), isFalse);
    }
  });

  test(
      'dark node exports repair collisions while preserving other index entries',
      () async {
    final untouched = {
      ..._entry(_light, 'Saved', '2:8', '$_lightDir/Saved.json'),
      'consumerMetadata': {'keep': true},
    };
    _writeJson(root, '$_lightDir/Saved.json', _spec('2:8', 'Saved'));
    _writeJson(root, '$_lightDir/Catalog.json', _spec('2:3', 'Catalog'));
    _writeJson(root, '$_darkDir/Home.json', _spec('1:2', 'Home '));
    _writeJson(root, 'spec/_index.json', [
      untouched,
      _entry(_dark, 'Home', '1:1', '$_darkDir/Home.json'),
      _entry(_dark, 'Home ', '1:2', '$_darkDir/Home.json'),
    ]);

    final result = await _invoke(
        root,
        [
          'spec',
          '--page',
          _dark,
          '--node',
          '1:1,1:2',
          '--batch',
          '1',
          '--force',
        ],
        live: true,
        client: _liveClient());

    expect(result.code, 0, reason: result.err);
    final index = _index(root);
    expect(index.singleWhere((entry) => entry['nodeId'] == '2:8'), untouched);
    expect(index.singleWhere((entry) => entry['nodeId'] == '2:3')['file'],
        '$_lightDir/Catalog.json');
    final ordinary = index.singleWhere((entry) => entry['nodeId'] == '1:1');
    final modal = index.singleWhere((entry) => entry['nodeId'] == '1:2');
    expect(ordinary['file'], '$_darkDir/Home__1_1.json');
    expect(modal['file'], '$_darkDir/Home__1_2.json');
    expect(_json(root, ordinary['file'] as String)['id'], '1:1');
    expect(_json(root, modal['file'] as String)['id'], '1:2');
    expect(_json(root, '$_darkDir/Home.json')['id'], '1:1');
    expect(
        File(p.join(root.path, '.figma_cache', 'spec', 'Design_System__Dark_',
                'Catalog.json'))
            .existsSync(),
        isFalse);
  });

  test('spec frame filters export only the requested unique name', () async {
    final untouched = {
      ..._entry(_dark, 'Saved', '1:8', '$_darkDir/Saved.json'),
      'consumerMetadata': 'retained',
    };
    _writeJson(root, '$_darkDir/Saved.json', _spec('1:8', 'Saved'));
    _writeJson(root, 'spec/_index.json', [untouched]);
    final result = await _invoke(
        root,
        [
          'spec',
          '--page',
          _dark,
          '--frame',
          'Catalog',
        ],
        live: true,
        client: _liveClient());

    expect(result.code, 0, reason: result.err);
    final index = _index(root);
    expect(index.map((entry) => entry['nodeId']).toSet(), {'1:8', '1:3'});
    expect(index.singleWhere((entry) => entry['nodeId'] == '1:8'), untouched);
    final selected = index.singleWhere((entry) => entry['nodeId'] == '1:3');
    expect(selected['file'], '$_darkDir/Catalog.json');
    expect(_json(root, '$_darkDir/Catalog.json')['id'], '1:3');
  });

  test('modal-only PNG export cannot replace the ordinary home alias',
      () async {
    const alias = 'shots/Design_System__Dark___Home.png';
    _writeBytes(root, alias, utf8.encode('ordinary-previous'));

    final modal = await _invoke(
        root,
        [
          'png',
          '--page',
          _dark,
          '--node',
          '1:2',
          '--force',
        ],
        live: true,
        client: _liveClient());
    expect(modal.code, 0, reason: modal.err);
    expect(_file(root, alias).readAsStringSync(), 'ordinary-previous');
    expect(
        _file(root, 'shots/Design_System__Dark___Home__1_2.png')
            .readAsStringSync(),
        'render:1:2');

    final ordinary = await _invoke(
        root,
        [
          'png',
          '--page',
          _dark,
          '--node',
          '1:1',
        ],
        live: true,
        client: _liveClient());
    expect(ordinary.code, 0, reason: ordinary.err);
    expect(_file(root, alias).readAsStringSync(), 'render:1:1');
    expect(
        _file(root, 'shots/Design_System__Dark___Home__1_1.png')
            .readAsStringSync(),
        'render:1:1');
    expect(
        _file(root, 'shots/Design_System__Dark___Home__1_2.png')
            .readAsStringSync(),
        'render:1:2');
  });

  test('mismatched API documents cannot replace a cached original or its index',
      () async {
    final original = _spec('1:3', 'Catalog');
    final entry = _entry(_dark, 'Catalog', '1:3', '$_darkDir/Catalog.json');
    _writeJson(root, '$_darkDir/Catalog.json', original);
    _writeJson(root, 'spec/_index.json', [entry]);

    final result = await _invoke(
        root,
        [
          'spec',
          '--page',
          _dark,
          '--node',
          '1:3',
          '--force',
        ],
        live: true,
        client: _liveClient(documents: {'1:3': _document('9:9', 'Catalog')}));

    expect(result.code, 65);
    expect(_json(root, '$_darkDir/Catalog.json'), original);
    expect(_index(root), [entry]);
  });

  test('API failures do not echo a response body containing credentials',
      () async {
    final result = await _invoke(root, ['frames'],
        live: true,
        client: MockClient((_) async => http.Response('secret-token', 403)));
    expect(result.code, 70);
    expect(result.err, contains('403'));
    expect(result.err, isNot(contains('secret-token')));
    expect(result.out, isEmpty);
  });
}

Future<({int code, String out, String err})> _invoke(
    Directory root, List<String> args,
    {bool live = false, http.Client? client}) async {
  final output = StringBuffer();
  final errors = StringBuffer();
  final transport = client ??
      MockClient((_) async => throw StateError('Unexpected network request.'));
  try {
    final code = await runFigmaSpec(args,
        root: root,
        environment: live
            ? const {'FIGMA_TOKEN': 'secret-token', 'FIGMA_FILE': 'design'}
            : const {},
        output: output,
        errors: errors,
        client: transport);
    return (code: code, out: output.toString(), err: errors.toString());
  } finally {
    transport.close();
  }
}

List<List<String>> _rows(String output) => output
    .split('\n')
    .where((line) => line.contains('\t'))
    .map((line) => line.split('\t'))
    .toList();

File _file(Directory root, String relative) =>
    File(p.joinAll([root.path, '.figma_cache', ...p.posix.split(relative)]));

void _writeJson(Directory root, String relative, Object value) {
  final file = _file(root, relative);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(value));
}

void _writeBytes(Directory root, String relative, List<int> bytes) {
  final file = _file(root, relative);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
}

Map<String, dynamic> _json(Directory root, String relative) =>
    jsonDecode(_file(root, relative).readAsStringSync())
        as Map<String, dynamic>;

List<Map<String, dynamic>> _index(Directory root) =>
    (jsonDecode(_file(root, 'spec/_index.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

Map<String, dynamic> _entry(String page, String name, String id, String file) =>
    {
      'page': page,
      'frame': name,
      'nodeId': id,
      'file': file,
      'size': [375, 812],
    };

Map<String, dynamic> _spec(String id, String name) => {
      'id': id,
      'name': name,
      'type': 'FRAME',
      'w': 375,
      'h': 812,
    };

Map<String, dynamic> _document(String id, String name) => {
      'id': id,
      'name': name,
      'type': 'FRAME',
      'absoluteBoundingBox': {'x': 0, 'y': 0, 'width': 375, 'height': 812},
    };

http.Client _liveClient({Map<String, Map<String, dynamic>>? documents}) {
  return MockClient((request) async {
    final uri = request.url;
    if (uri.host == 'renders.invalid') {
      final id =
          p.posix.basenameWithoutExtension(uri.path).replaceAll('_', ':');
      return http.Response.bytes(utf8.encode('render:$id'), 200);
    }
    if (uri.path == '/v1/files/design') {
      return _response({
        'document': {
          'children': [
            {
              'name': _dark,
              'children': [
                for (final entry in _frames.entries)
                  {'id': entry.key, 'name': entry.value, 'type': 'FRAME'},
              ],
            },
            {'name': _light, 'children': <Object>[]},
          ],
        },
      });
    }
    final ids = uri.queryParameters['ids']?.split(',') ?? <String>[];
    if (uri.path == '/v1/files/design/nodes') {
      return _response({
        'nodes': {
          for (final id in ids)
            id: {'document': documents?[id] ?? _document(id, _frames[id]!)},
        },
      });
    }
    if (uri.path == '/v1/images/design') {
      return _response({
        'images': {
          for (final id in ids)
            id: 'https://renders.invalid/${id.replaceAll(':', '_')}.png',
        },
      });
    }
    return http.Response('Unexpected request', 404);
  });
}

http.Response _response(Object value) => http.Response(jsonEncode(value), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});
