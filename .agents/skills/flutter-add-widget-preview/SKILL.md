---
name: flutter-add-widget-preview
description: Use when interactively inspecting Flutter components or screen states in a deterministic local preview.
---
# Preview Flutter widgets without a second gallery

## Use the existing project surface

This project already has a fixture-only gallery. Do not add `previews.dart`, `@Preview` scaffolding, another app entrypoint or another preview framework for ordinary screen work.

- `tool/dev_surface.dart`: Windows gallery with surface/theme/width/text-scale/keyboard controls and hot reload.
- `test/support/design_surfaces.dart`: `DesignSurfaceApp`, strict `SurfaceFixtureClient` and synthetic preferences; `active_route` mounts the actual authentication wrapper.
- `tool/design/surface_manifest.dart`: existing surface IDs and exact reference-frame mapping. Reuse existing states (`checkout_delivery`, `checkout_pickup`, `checkout_error`, etc.); inspect actual fixture setup before assuming an empty-state ID exists.
- `tool/design_harness.dart`: existing serial preview, capture, fixture build and loopback serve coordinator.

Launch from the repository root:

```sh
dart run tool/design_harness.dart preview
```

This delegates to `flutter run -d windows -t tool/dev_surface.dart`. Close preview before checks/builds/capture. Do not retry known-failing debug Chrome DDC without a relevant change. Runtime MCP is optional, development-only and requires the running debug fixture; it cannot inspect a release web bundle.

## Add only a missing state

Inspect the real route in `lib/widgets/authentication_wrapper.dart`. Prefer the existing surface/scenario controls. If a needed state is absent, extend the existing test-only fixture/scenario and manifest coherently rather than cloning the widget or building a mock screen. Preserve strict request rejection, synthetic preferences, both themes, inherited text scaling and floating cart-only navigation. Never fall through to production or trigger real SMS, address/card mutations, orders or payments.

For screenshot/release-web review, reuse:

```sh
dart run tool/design_harness.dart capture checkout_error --theme both --capture-only
dart run tool/design_harness.dart build
dart run tool/design_harness.dart serve --port 8790
```

Run these serially. Default build output is the isolated fixture bundle, not tracked `build/web`. Review interactions as well as visuals; fixture success does not prove production acceptance.

## Only if Flutter Widget Previewer itself is requested

Check the installed SDK's [Widget Previewer reference](https://docs.flutter.dev/tools/widget-previewer). A minimal standalone annotation is:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

@Preview(name: 'Label', size: Size(200, 80))
Widget labelPreview() => const Text('Synthetic label');
```

The previewer runs on web: invoked `dart:io`/`dart:ffi` APIs and native plugins are unsupported. Provide explicit constraints and required theme/provider context; do not bypass platform code or weaken production behavior merely to make a preview run. Advanced custom `Preview`/`MultiPreview` APIs are SDK-version-specific, not prerequisites for this gallery.
