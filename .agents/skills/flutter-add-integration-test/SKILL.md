---
name: flutter-add-integration-test
description: Use when adding or extending a native Flutter device journey spanning screens, shared state, and transport behavior.
---
# Flutter native integration tests

## Extend the existing journey

Read `integration_test/shopping_e2e_test.dart` before authoring a new journey. It boots the real active route through `DesignSurfaceApp`, uses `WidgetTester`, and already initializes:

```dart
IntegrationTestWidgetsFlutterBinding.ensureInitialized();
```

`integration_test` and `flutter_test` are already in `pubspec.yaml`. Do not add Flutter Driver, `enableFlutterDriverExtension`, a host driver script, `lib/main_test.dart`, or production-entry changes. Native tests run with `flutter test`, not a required `flutter drive` harness. Use `test/integration/` widget/transport tests when no real engine/device is needed.

## Preserve the strict fixture boundary

Follow the existing shopping test's setup and teardown, not a fresh app bootstrap:

- `test/support/design_surfaces.dart`: `DesignSurfaceApp(surface: 'active_route', brightness: ...)`, `SurfaceFixtureClient`, `surfaceFixturePreferences` and unexpected-request tracking.
- `test/support/remaining_milestone_fixture.dart`: synthetic shopping/payment state and responses.
- Seed in-memory preferences before providers. For the chained journey, retain the existing removal of selected store/auth keys so store selection and synthetic login are actually exercised; do not replace the journey with an already-authenticated fixture.
- Keep mounting, interactions and unmounting inside `http.runWithClient`. Preserve the existing native `HttpOverrides` guard rejecting escaped HTTP creation and the frame-callback re-registration inside the fixture zone. Zone-only interception is not sufficient if engine callbacks retain an earlier zone.
- Reset scenario/request state between tests and restore overrides/viewport/global state when adding independent cases. Assert `SurfaceFixtureClient.unexpectedRequests` is empty and native escape attempts are zero even if the UI catches transport errors.

Never fall through to production. SMS, addresses/cards, orders and payments must be explicitly synthetic; real account mutations are forbidden during verification.

## Drive and assert the actual behavior

Reuse stable keys/semantics and the existing tap/scroll helper. For lazy content, select the intended Scrollable before `scrollUntilVisible`. Pump finite transitions; use `pumpAndSettle` only when animations terminate. For pending requests or repeating spinners, use bounded pumps and assert the expected state rather than sleeping or waiting forever.

Assert destinations **and** outcomes: selected store, product/quantity, cart totals, checkout continuation, synthetic request payloads, payment confirmation and server-confirmed fixture history. Add error/recovery coverage to the existing test layer; do not infer success from taps, a settled frame or a screenshot.

Runtime MCP may help inspect a running debug fixture; use only tools actually exposed by the runtime. It is not a prerequisite and does not inspect release bundles. `integration_test` cannot prove native system dialogs, external bank UI or real payment acceptance.

## Serial Windows execution

```sh
dart run tool/design_harness.dart check --full --native
```

For the native journey plus analysis without the full host suite, use `check --native`. The underlying native command is `flutter test integration_test/shopping_e2e_test.dart -d windows --concurrency=1`. Close previews and other Flutter runs first. Follow README low-memory Windows compiler settings; report platform limits rather than claiming unexercised Apple/bank/device acceptance.

Reference: [Flutter integration tests](https://docs.flutter.dev/testing/integration-tests).
