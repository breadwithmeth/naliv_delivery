import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/support/design_surfaces.dart';

const _surfaceArg = String.fromEnvironment('SURFACE', defaultValue: 'all');
const _themeArg = String.fromEnvironment('SURFACE_THEME', defaultValue: 'dark');

Future<void> _loadDesignFont() async {
  final bytes =
      File('assets/fonts/TikTokSans/TikTokSans-Variable.ttf').readAsBytesSync();
  final loader = FontLoader('TikTokSans');
  loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

void main() {
  if (_surfaceArg != 'all' && !surfaceIds.contains(_surfaceArg)) {
    throw ArgumentError.value(
        _surfaceArg, 'SURFACE', 'Expected all or ${surfaceIds.join(', ')}');
  }
  if (!{'dark', 'light', 'both'}.contains(_themeArg)) {
    throw ArgumentError.value(
        _themeArg, 'SURFACE_THEME', 'Expected dark, light, or both');
  }

  setUpAll(_loadDesignFont);

  for (final surface in _surfaceArg == 'all' ? surfaceIds : [_surfaceArg]) {
    for (final theme in _themeArg == 'both' ? ['dark', 'light'] : [_themeArg]) {
      testWidgets('captures fixture $surface ($theme) at 750×1624',
          (tester) async {
        // Only synthetic credentials, account, cart and consent are read by this fixture.
        // Capture lives under tool/ so it is not auto-discovered by flutter test.
        // ignore: invalid_use_of_visible_for_testing_member
        SharedPreferences.setMockInitialValues(surfaceFixturePreferences);
        SurfaceFixtureClient.resetUnexpectedRequests();
        await tester.binding.setSurfaceSize(designSurfaceSize);
        tester.view.devicePixelRatio = 2;
        tester.view.physicalSize = const Size(750, 1624);
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
          final image = await boundary.toImage(pixelRatio: 2);
          try {
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            return data!.buffer.asUint8List();
          } finally {
            image.dispose();
          }
        });
        final output =
            File('.figma_cache/render/current_${surface}_$theme.png');
        output.parent.createSync(recursive: true);
        output.writeAsBytesSync(bytes!);
        debugPrint('Fixture capture: ${output.path}');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
    }
  }
}
