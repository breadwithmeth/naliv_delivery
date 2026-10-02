// flutter run -d windows -t tool/dev_surface.dart
// Fixture-only gallery: synthetic content, no authentication or production mutations.
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/design_surfaces.dart';
import '../test/support/remaining_milestone_fixture.dart';

void main() {
  // Initialize the binding *inside* the HTTP zone so scheduled frames inherit the
  // strict fixture client. Preferences remain in memory, not the device account.
  http.runWithClient(() {
    WidgetsFlutterBinding.ensureInitialized();
    // This entry point is fixture-only; no device credentials or consent are read.
    // Synthetic credentials only; the strict transport rejects unknown requests.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(surfaceFixturePreferences);
    final query = Uri.base.queryParameters;
    RemainingMilestoneFixture.paymentScenario =
        PaymentFixtureScenario.values.firstWhere(
      (value) => value.name == query['payment'],
      orElse: () => PaymentFixtureScenario.completed,
    );
    final selected = query['surface'];
    runApp(selected != null && surfaceIds.contains(selected)
        ? LayoutBuilder(
            builder: (context, constraints) => DesignSurfaceApp(
              surface: selected,
              brightness: query['theme'] == 'light'
                  ? Brightness.light
                  : Brightness.dark,
              size: constraints.biggest,
              textScaler:
                  TextScaler.linear(double.tryParse(query['scale'] ?? '') ?? 1),
              viewInsets: EdgeInsets.only(
                  bottom: double.tryParse(query['keyboard'] ?? '') ?? 0),
              cardScenario: CardFixtureScenario.values.firstWhere(
                (value) => value.name == query['cards'],
                orElse: () => CardFixtureScenario.loaded,
              ),
            ),
          )
        : const _FixtureGallery());
  },
      () => SurfaceFixtureClient(
            onUnexpectedRequest: (message) => FlutterError.reportError(
              FlutterErrorDetails(
                  exception: StateError(message), library: 'fixture HTTP'),
            ),
          ));
}

class _FixtureGallery extends StatefulWidget {
  const _FixtureGallery();

  @override
  State<_FixtureGallery> createState() => _FixtureGalleryState();
}

class _FixtureGalleryState extends State<_FixtureGallery> {
  String _surface = surfaceIds.first;
  Brightness _brightness = Brightness.dark;
  double _width = 375;
  double _textScale = 1;
  double _keyboardInset = 0;
  CardFixtureScenario _cardScenario = CardFixtureScenario.loaded;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Scaffold(
          appBar:
              AppBar(title: const Text('Fixture gallery · development only')),
          body: SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Text(
                      'Synthetic data · strict fixture transport · no live account'),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      DropdownButton<String>(
                        value: _surface,
                        items: [
                          for (final id in surfaceIds)
                            DropdownMenuItem(
                                value: id, child: Text('Fixture: $id')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _surface = value);
                        },
                      ),
                      SegmentedButton<Brightness>(
                        segments: const [
                          ButtonSegment(
                              value: Brightness.dark, label: Text('Dark')),
                          ButtonSegment(
                              value: Brightness.light, label: Text('Light')),
                        ],
                        selected: {_brightness},
                        onSelectionChanged: (values) =>
                            setState(() => _brightness = values.single),
                      ),
                      DropdownButton<double>(
                        value: _width,
                        items: [
                          for (final width in [320.0, 375.0, 800.0])
                            DropdownMenuItem(
                              value: width,
                              child: Text('Width: ${width.round()}'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _width = value);
                        },
                      ),
                      DropdownButton<double>(
                        value: _textScale,
                        items: [
                          for (final scale in [1.0, 1.6, 2.0])
                            DropdownMenuItem(
                              value: scale,
                              child: Text('Text: $scale×'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _textScale = value);
                        },
                      ),
                      DropdownButton<double>(
                        value: _keyboardInset,
                        items: [
                          for (final inset in [0.0, 300.0])
                            DropdownMenuItem(
                              value: inset,
                              child: Text(
                                  'Keyboard: ${inset.round()} px (simulated)'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _keyboardInset = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<CardFixtureScenario>(
                    value: _cardScenario,
                    items: [
                      for (final scenario in CardFixtureScenario.values)
                        DropdownMenuItem(
                          value: scenario,
                          child: Text('Cards: ${scenario.name}'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _cardScenario = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  // The outer gallery controls are not part of the captured 375×812 surface.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = _width.clamp(0.0, constraints.maxWidth);
                      final size = Size(width, designSurfaceSize.height);
                      return SizedBox(
                        width: size.width,
                        height: size.height,
                        child: DesignSurfaceApp(
                          key: const ValueKey('fixture-app'),
                          surface: _surface,
                          size: size,
                          textScaler: TextScaler.linear(_textScale),
                          viewInsets: EdgeInsets.only(bottom: _keyboardInset),
                          cardScenario: _cardScenario,
                          brightness: _brightness,
                          onSurfaceChanged: (value) =>
                              setState(() => _surface = value),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      );
}
