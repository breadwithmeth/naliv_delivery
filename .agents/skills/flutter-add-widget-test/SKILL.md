---
name: flutter-add-widget-test
description: Use when testing Flutter widget rendering, user interactions, navigation results, or loading/error/retry states without a native device journey.
---
# Flutter widget tests

## Reuse this project's fixtures

`flutter_test` is already a dev dependency. Extend the affected `_test.dart` under `test/integration/` (multi-component UI/transport flows) or `test/regression/` (behavior boundaries), rather than scaffolding a demo app or adding packages.

Read the target widget and neighboring tests first. Useful references:

- `test/integration/checkout_page_test.dart`: controlled requests, checkout assertions, synthetic account/cart state.
- `test/integration/home_layout_test.dart`: viewport, text scaling, dock clearance and layout assertions.
- `test/support/design_surfaces.dart`: `DesignSurfaceApp`, `SurfaceFixtureClient`, `surfaceFixturePreferences` for shared active-route fixtures.
- `test/support/preferences_store.dart`: existing preference-test support.

Trace `lib/widgets/authentication_wrapper.dart` when the test needs the active route. Supply only the real inherited dependencies required by the widget (theme, locale, providers, navigator). Use a small component wrapper for isolated widgets; use the existing active-route fixture for route behavior.

## Write assertions around the behavior

1. Name the regression and the production change that would make it fail. Set synthetic preferences before creating providers; install strict `MockClient`/`http.runWithClient` before mounting networked widgets. Reject and record unexpected requests; never forward to production.
2. Pump the actual widget. Assert the initial state with semantic labels, stable keys or scoped finders. Reuse keys before adding new ones.
3. Drive the real control with `tap`, `enterText` or scrolling. For lazy content, pass the intended **Scrollable finder** to `scrollUntilVisible`, not an unrelated ListView.
4. Assert the visible result and relevant business outcome: request method/payload/count, preserved cart, navigation destination, validation preventing submission, or error/retry behavior. Do not assert only mock invocation or hide failure by weakening expectations.

## Pump deliberately

`pump()` processes a frame; a finite-duration pump advances known animations/timers. Use controlled Completers for pending/success/error responses. `pumpAndSettle()` is suitable only when frames terminate: repeating loading animations never settle. For asynchronous state, use bounded pumps with an explicit expected-state assertion, not arbitrary sleeps or unbounded loops. Keep loading pending long enough to assert it, then resolve it and assert error/success; retry must issue the intended request exactly once.

Unmount/dispose in the fixture scope, restore surface size/overrides/global state, and assert unexpected requests plus `tester.takeException()`. Never send real SMS, mutate addresses/cards, submit orders or pay during tests.

## Serial verification

```sh
dart run tool/design_harness.dart check test/integration/checkout_page_test.dart
```

Replace the path with the affected existing test. This runs the focused test and analysis; integration runs the full retained suite afterward. Do not launch competing Flutter checks/previews.
