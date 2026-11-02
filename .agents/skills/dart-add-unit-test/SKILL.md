---
name: dart-add-unit-test
description: Use when adding Dart or Flutter unit regressions for changed logic, reported bugs, malformed data, or boundary conditions.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: "2026-11-02"
---
# Add a behavior regression

Follow the nearest existing test before introducing another pattern. This Flutter checkout uses `package:flutter_test/flutter_test.dart` and its `expect` matchers; no new test or mocking dependency is needed.

## Write the test

1. Read the target behavior, reported failure and nearby tests. Name the observable production change that should make the regression fail.
2. Extend the relevant suite: `test/regression/` for boundaries, `test/integration/` for multi-component widget/transport flows. Reuse `test/support/` and `test/fixtures/`; reserve root `integration_test/` for the existing native journey. Use `_test.dart` filenames, not a mandatory mirror of `lib/`.
3. Arrange deterministic data with `setUp` and clean owned clients, providers, timers and subscriptions with `addTearDown`/`tearDown`. Reset preferences through existing test helpers.
4. Exercise real production logic and assert exact results, persisted state or emitted requests. Cover the reported boundary rather than merely checking non-nullness or that execution completes. Await futures and asynchronous error assertions.
5. For a bugfix, observe the focused regression fail for the reported reason before the minimal implementation fix. A regression for already-correct behavior may pass immediately; do not manufacture a failure.

Existing pattern (`test/regression/quantity_test.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/core/quantity.dart';

void main() {
  test('fractional measures retain capacity precision', () {
    expect(formatQuantity(0.475, 'л'), '0.475 л');
  });
}
```

## Keep HTTP strict

Reuse `http/testing.dart` `MockClient`, the established injection seam or `http.runWithClient`. Match the expected method, URI/query and relevant body/headers. Record unknown requests before rejecting them; assert the recorded list is empty outside the service's catch boundary, preferably in teardown. An exception inside a handler can be swallowed by production code.

Do not use blanket success responses, NiceMocks to hide missing stubs, live credentials or production mutations. Mockito/code generation is not the default. Preserve intended assertions when failures expose a real bug; do not weaken them to obtain green output.

## Run serially

Stop external Flutter runs; use the existing harness, not a second runner:

```sh
dart run tool/design_harness.dart check test/regression/quantity_test.dart
dart run tool/design_harness.dart check --full
```

Replace the focused path with the actual affected file. The full check collects LCOV and analyzes `lib test integration_test tool`; add `--native` for the existing Windows journey at native integration. The harness uses test concurrency 1. Report actual checks, failures and platform limits; never claim unrun verification.
