import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/ui/liquid_glass_dock.dart';

// The dock works from a GPU snapshot of the page. Renderers disagree about that
// snapshot's vertical origin (Impeller's OpenGL ES backend stores it bottom-up),
// so these checks compare it with direct Flutter painting captured in the same
// image: a relative inversion shows even if the capture itself is reversed.
// `integration_test/liquid_glass_orientation_test.dart` runs them on a device's
// real renderer, where the backend can actually differ.
const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);
const _bands = Column(
  children: [
    Expanded(
      child: ColoredBox(color: _red, child: SizedBox.expand()),
    ),
    Expanded(
      child: ColoredBox(color: _blue, child: SizedBox.expand()),
    ),
  ],
);

bool _near(Color actual, Color expected) =>
    (actual.r - expected.r).abs() < 0.1 &&
    (actual.g - expected.g).abs() < 0.1 &&
    (actual.b - expected.b).abs() < 0.1;

typedef _Capture = ({
  Color referenceTop,
  Color referenceBelow,
  Color top,
  Color below,
  Color glass,
});

// Red above blue: a vertical flip swaps them. The unsampled strip on the left
// is the reference; the dock sits over the blue half, so its glass must show
// blue, never the mirrored red.
Future<_Capture> _captureDock(WidgetTester tester) async {
  final boundaryKey = GlobalKey();
  final dockKey = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Row(
            children: [
              const SizedBox(width: 16, child: _bands),
              Expanded(
                child: LiquidGlassDock(
                  content: _bands,
                  dock: SizedBox(key: dockKey, height: 56),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  final glassCenter = tester.getCenter(find.byKey(dockKey));
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final capture = await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final data = (await image.toByteData())!;
      Color pixel(int x, int y) {
        final i = (y * image.width + x) * 4;
        return Color.fromARGB(
          data.getUint8(i + 3),
          data.getUint8(i),
          data.getUint8(i + 1),
          data.getUint8(i + 2),
        );
      }

      Color at(double fx, double fy) =>
          pixel((image.width * fx).floor(), (image.height * fy).floor());

      // The page points sit well clear of the dock and its soft shadow.
      return (
        referenceTop: at(0.01, 0.15),
        referenceBelow: at(0.01, 0.6),
        top: at(0.5, 0.15),
        below: at(0.5, 0.6),
        glass: pixel(glassCenter.dx.floor(), glassCenter.dy.floor()),
      );
    } finally {
      image.dispose();
    }
  });
  return capture!;
}

void _expectUprightPage(_Capture sample) {
  expect(
    _near(sample.referenceTop, sample.referenceBelow),
    isFalse,
    reason: 'the direct reference must retain two distinct marker rows',
  );
  expect(
    _near(sample.top, sample.referenceTop),
    isTrue,
    reason: 'upper page must match Flutter painting: $sample',
  );
  expect(
    _near(sample.below, sample.referenceBelow),
    isTrue,
    reason: 'lower page must match Flutter painting: $sample',
  );
}

void main() {
  setUpAll(LiquidGlassDock.warmUp);

  testWidgets('presents the page upright against an unsampled reference', (
    tester,
  ) async {
    final sample = await _captureDock(tester);

    _expectUprightPage(sample);
    expect(
      sample.glass.b,
      greaterThan(sample.glass.r),
      reason: 'the glass must refract the blue band behind it: $sample',
    );
  });

  test('shader exterior preserves page pixels even with reversed sampling',
      () async {
    final program =
        await ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag');
    final recorder = ui.PictureRecorder();
    final sourceCanvas = Canvas(recorder);
    sourceCanvas.drawRect(
        const Rect.fromLTWH(0, 0, 128, 64), Paint()..color = _red);
    sourceCanvas.drawRect(
        const Rect.fromLTWH(0, 64, 128, 64), Paint()..color = _blue);
    final sourcePicture = recorder.endRecording();
    final source = await sourcePicture.toImage(128, 128);
    final shader = program.fragmentShader();
    final values = <double>[
      128,
      128,
      16,
      80,
      96,
      32,
      16,
      16,
      16,
      16,
      0.05,
      0.05,
      0.06,
      0.32,
      1,
      1,
    ];
    for (var index = 0; index < values.length; index++) {
      shader.setFloat(index, values[index]);
    }
    shader.setImageSampler(0, source);
    final interiors = <Color>[];
    try {
      for (final flip in [0.0, 1.0]) {
        shader.setFloat(15, flip);
        final outputRecorder = ui.PictureRecorder();
        Canvas(outputRecorder)
          ..drawPicture(sourcePicture)
          ..drawRect(
              const Rect.fromLTWH(2, 66, 124, 60), Paint()..shader = shader);
        final outputPicture = outputRecorder.endRecording();
        final output = await outputPicture.toImage(128, 128);
        try {
          final pixels = (await output.toByteData())!;
          Color at(int x, int y) {
            final offset = (y * 128 + x) * 4;
            return Color.fromARGB(
                pixels.getUint8(offset + 3),
                pixels.getUint8(offset),
                pixels.getUint8(offset + 1),
                pixels.getUint8(offset + 2));
          }

          expect(_near(at(64, 74), at(0, 74)), isTrue,
              reason:
                  'The shadow must blend over the actual page for flip=$flip');
          expect(_near(at(4, 68), at(0, 68)), isTrue,
              reason: 'Rounded-corner exterior must preserve page pixels');
          interiors.add(at(64, 96));
        } finally {
          output.dispose();
          outputPicture.dispose();
        }
      }
      expect(interiors.first.r > interiors.first.b,
          isNot(interiors.last.r > interiors.last.b),
          reason: 'Flipping the sampler must still affect real glass');
    } finally {
      shader.dispose();
      source.dispose();
      sourcePicture.dispose();
    }
  });
}
