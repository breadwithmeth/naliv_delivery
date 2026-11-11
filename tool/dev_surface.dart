// flutter run -d windows -t tool/dev_surface.dart
// Fixture-only gallery: synthetic content, no authentication or production mutations.
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:naliv_delivery/services/notification_service.dart';
import 'package:naliv_delivery/services/push_provider.dart';
import '../test/support/design_surfaces.dart';
import '../test/support/remaining_milestone_fixture.dart';
import 'design/fixture_options.dart' show FixtureOptions;
import 'design/surface_manifest.dart';

void main() {
  // Initialize the binding *inside* the HTTP zone so scheduled frames inherit the
  // strict fixture client. Preferences remain in memory, not the device account.
  http.runWithClient(
    () {
      NotificationService.installProvider(InMemoryPushProvider());
      WidgetsFlutterBinding.ensureInitialized();
      // This entry point is fixture-only; no device credentials or consent are read.
      // Synthetic credentials only; the strict transport rejects unknown requests.
      final query = Uri.base.queryParameters;
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues(
        {...surfaceFixturePreferences}..removeWhere(
            (key, _) => query['guest'] == '1' && key == 'auth_token',
          ),
      );
      try {
        final options = FixtureOptions.parse(
          query,
          cardScenarios: CardFixtureScenario.values.map((value) => value.name),
          paymentScenarios: PaymentFixtureScenario.values.map(
            (value) => value.name,
          ),
          updateScenarios: AppUpdateFixtureScenario.values.map(
            (value) => value.name,
          ),
        );
        RemainingMilestoneFixture.paymentScenario =
            PaymentFixtureScenario.values.byName(options.payment);
        final selected = options.surface;
        runApp(
          selected != null
              ? LayoutBuilder(
                  builder: (context, constraints) => DesignSurfaceApp(
                    surface: selected,
                    brightness: options.theme == 'light'
                        ? Brightness.light
                        : Brightness.dark,
                    size: constraints.biggest,
                    textScaler: TextScaler.linear(options.textScale),
                    viewInsets: EdgeInsets.only(bottom: options.keyboardInset),
                    cardScenario: CardFixtureScenario.values.byName(
                      options.cards,
                    ),
                    updateScenario: AppUpdateFixtureScenario.values.byName(
                      options.updates,
                    ),
                  ),
                )
              : const _FixtureGallery(),
        );
      } on FormatException catch (error) {
        runApp(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              appBar: AppBar(title: const Text('Fixture configuration')),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        liveRegion: true,
                        label: 'Invalid fixture configuration',
                        child: const Text('Invalid fixture configuration'),
                      ),
                      const SizedBox(height: 16),
                      Text(error.message),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => runApp(const _FixtureGallery()),
                        child: const Text('Open fixture gallery'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    },
    () => SurfaceFixtureClient(
      onUnexpectedRequest: (message) => FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError(message),
          library: 'fixture HTTP',
        ),
      ),
    ),
  );
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
  AppUpdateFixtureScenario _updateScenario = AppUpdateFixtureScenario.off;

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
                    'Synthetic data · strict fixture transport · no live account',
                  ),
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
                              value: id,
                              child: Text('Fixture: $id'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _surface = value);
                        },
                      ),
                      SegmentedButton<Brightness>(
                        segments: const [
                          ButtonSegment(
                            value: Brightness.dark,
                            label: Text('Dark'),
                          ),
                          ButtonSegment(
                            value: Brightness.light,
                            label: Text('Light'),
                          ),
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
                                'Keyboard: ${inset.round()} px (simulated)',
                              ),
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
                  if (_surface == 'active_route')
                    DropdownButton<AppUpdateFixtureScenario>(
                      value: _updateScenario,
                      items: [
                        for (final scenario in AppUpdateFixtureScenario.values)
                          DropdownMenuItem(
                            value: scenario,
                            child: Text('Updates: ${scenario.name}'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _updateScenario = value);
                        }
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
                          updateScenario: _updateScenario,
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
