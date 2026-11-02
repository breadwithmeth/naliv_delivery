import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:naliv_delivery/ui/liquid_glass_dock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/support/design_surfaces.dart';

import '../verify_surface.dart' show SurfaceRunOptions, surfaceCapturePath;

Future<void> _loadCaptureAssets() async {
  final bytes =
      File('assets/fonts/TikTokSans/TikTokSans-Variable.ttf').readAsBytesSync();
  final loader = FontLoader('TikTokSans');
  loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  // Use the same cached material future as mounted docks, outside the fake clock.
  await LiquidGlassDock.warmUp();
}

void main() {
  final options = SurfaceRunOptions.fromEnvironment();
  final size = Size(options.width, SurfaceRunOptions.height);

  setUpAll(_loadCaptureAssets);

  for (final surface in options.surfaces) {
    for (final theme in options.themes) {
      testWidgets(
          'captures fixture $surface ($theme) at ${options.pixelWidth}×${options.pixelHeight}',
          (tester) async {
        // Only synthetic credentials, account, cart and consent are read by this fixture.
        // Capture lives under tool/ so it is not auto-discovered by flutter test.
        // ignore: invalid_use_of_visible_for_testing_member
        SharedPreferences.setMockInitialValues(surfaceFixturePreferences);
        SurfaceFixtureClient.resetUnexpectedRequests();
        await tester.binding.setSurfaceSize(size);
        tester.view.devicePixelRatio = SurfaceRunOptions.devicePixelRatio;
        tester.view.physicalSize = Size(
            size.width * SurfaceRunOptions.devicePixelRatio,
            size.height * SurfaceRunOptions.devicePixelRatio);
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
          tester.view.reset();
        });

        final boundaryKey = GlobalKey();
        await http.runWithClient(() async {
          await tester.pumpWidget(RepaintBoundary(
            key: boundaryKey,
            child: DesignSurfaceApp(
              surface: surface,
              brightness: theme == 'dark' ? Brightness.dark : Brightness.light,
              size: size,
              textScaler: TextScaler.linear(options.textScale),
              viewInsets: EdgeInsets.only(bottom: options.keyboard),
            ),
          ));
          // Avoid pumpAndSettle: home SVG/banner animation never settles. Allow the
          // mocked catalogue/recommendation GETs and preference read to finish.
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 100));
          // Store readiness mounts nested pages on a later frame; settle their
          // enabled-state and purchase-sheet transitions without waiting on home animation.
          await tester.pump(const Duration(milliseconds: 400));
        }, () => SurfaceFixtureClient());

        expect(SurfaceFixtureClient.unexpectedRequests, isEmpty,
            reason: 'The fixture must never contact an unknown API');
        expect(tester.takeException(), isNull);

        final boundary = boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(
              pixelRatio: SurfaceRunOptions.devicePixelRatio);
          try {
            expect(image.width, options.pixelWidth);
            expect(image.height, options.pixelHeight);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            return data!.buffer.asUint8List();
          } finally {
            image.dispose();
          }
        });
        final output =
            File(surfaceCapturePath(surface, theme, options: options));
        output.parent.createSync(recursive: true);
        output.writeAsBytesSync(bytes!);
        debugPrint('Fixture capture: ${output.path}');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
    }
  }
}
