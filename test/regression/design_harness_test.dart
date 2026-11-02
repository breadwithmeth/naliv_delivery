import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tool/design/fixture_options.dart';
import '../../tool/design_harness.dart';

void main() {
  test('mistyped fixture scenarios fail instead of displaying a loaded account',
      () {
    for (final query in [
      {'surface': 'cards', 'cards': 'error'},
      {'surface': 'payment_kaspi', 'payment': 'success'},
      {'surface': 'not-an-active-surface'},
    ]) {
      expect(
          () => FixtureOptions.parse(query, cardScenarios: const [
                'loaded',
                'empty',
                'partial',
                'invalid',
                'authentication',
                'readTimeout',
                'linkTimeout'
              ], paymentScenarios: const [
                'completed',
                'pending',
                'unreadable',
                'refused'
              ]),
          throwsFormatException);
    }
  });

  test('nonfinite text geometry is rejected before mounting the fixture', () {
    for (final query in [
      {'scale': 'NaN'},
      {'scale': 'Infinity'},
      {'scale': '0'},
      {'keyboard': '-1'},
      {'keyboard': 'Infinity'},
    ]) {
      expect(
          () => FixtureOptions.parse(query,
              cardScenarios: const ['loaded'],
              paymentScenarios: const ['completed']),
          throwsFormatException);
    }
  });

  test('fixture asset serving cannot escape its build via encoded paths',
      () async {
    final temporary =
        await Directory.systemTemp.createTemp('naliv_fixture_server_');
    addTearDown(() => temporary.delete(recursive: true));
    final build = await Directory(p.join(temporary.path, 'build')).create();
    final asset = File(p.join(build.path, 'assets', 'font.ttf'));
    await asset.parent.create();
    await asset.writeAsBytes([0, 1, 2, 3]);
    await File(p.join(temporary.path, 'private.txt'))
        .writeAsString('outside fixture');
    expect((await fixtureAsset(build, Uri.parse('/assets/font.ttf')))?.path,
        asset.path);
    for (final path in [
      '/%2e%2e/private.txt',
      '/..%2fprivate.txt',
      '/..%5cprivate.txt',
      '/C%3a/private.txt',
    ]) {
      expect(await fixtureAsset(build, Uri.parse(path)), isNull);
    }
  });
}
