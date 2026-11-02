import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/ui/scene_sampler_orientation.dart';

const _red = [255, 0, 0, 255];
const _blue = [0, 0, 255, 255];
const _gray = [127, 127, 127, 255];

// Two adjacent 2x2 patches: Flutter's image painter on the left, raw shader on
// the right. The read-back may reverse BOTH rows without changing their relation.
ByteData _readback(
  List<int> referenceTop,
  List<int> referenceBottom,
  List<int> sampledTop,
  List<int> sampledBottom,
) =>
    Uint8List.fromList([
      ...referenceTop,
      ...referenceTop,
      ...sampledTop,
      ...sampledTop,
      ...referenceBottom,
      ...referenceBottom,
      ...sampledBottom,
      ...sampledBottom,
    ]).buffer.asByteData();

void main() {
  for (final scenario in [
    (
      name: 'upright sampling with top-down readback',
      referenceTop: _red,
      referenceBottom: _blue,
      sampledTop: _red,
      sampledBottom: _blue,
      flip: false,
    ),
    (
      name: 'inverted sampling with top-down readback',
      referenceTop: _red,
      referenceBottom: _blue,
      sampledTop: _blue,
      sampledBottom: _red,
      flip: true,
    ),
    (
      name: 'upright sampling with bottom-up readback',
      referenceTop: _blue,
      referenceBottom: _red,
      sampledTop: _blue,
      sampledBottom: _red,
      flip: false,
    ),
    (
      name: 'inverted sampling with bottom-up readback',
      referenceTop: _blue,
      referenceBottom: _red,
      sampledTop: _red,
      sampledBottom: _blue,
      flip: true,
    ),
  ]) {
    test(scenario.name, () {
      expect(
        sceneSamplerNeedsYFlip(
          _readback(
            scenario.referenceTop,
            scenario.referenceBottom,
            scenario.sampledTop,
            scenario.sampledBottom,
          ),
        ),
        scenario.flip,
      );
    });
  }

  test('an unrecognizable shader result cannot select an orientation', () {
    expect(
      () => sceneSamplerNeedsYFlip(_readback(_red, _blue, _gray, _blue)),
      throwsStateError,
    );
  });

  test('an indistinguishable reference cannot select an orientation', () {
    expect(
      () => sceneSamplerNeedsYFlip(_readback(_red, _red, _red, _blue)),
      throwsStateError,
    );
  });
}
