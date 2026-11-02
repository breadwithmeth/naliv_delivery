---
name: dart-migrate-to-checks-package
description: Use when the task explicitly requests a scoped migration of Dart test assertions to package:checks.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: "2026-11-02"
---
# Explicit assertion migration only

This checkout uses `flutter_test` matchers and does not declare `checks`. Working on older tests, adding a regression, running analysis or requesting general modernization does not authorize changing assertion libraries. Keep the existing style unless a `package:checks` migration is explicitly in scope.

## Approved migration workflow

1. Identify the approved files/assertions and behavior contracts. Read their fixtures, widget matchers and custom matchers before changing imports. Do not expand to the whole suite.
2. Inspect `pubspec.yaml` and the compatible Checks API. Adding `checks` under `dev_dependencies` is required only if the approved migration needs it and it is absent; do not install it during unrelated testing. Let Flutter pub generate the lockfile and review dependency changes. Remove a direct `matcher` dependency only after every direct use is gone; transitive presence is normal.
3. Preserve Flutter's test framework. Keep `package:flutter_test/flutter_test.dart`, `testWidgets`, finders and widget-specific matchers such as `findsOneWidget`. Do not replace Flutter imports wholesale with `package:test/scaffolding.dart`. Pure-Dart import splitting applies only to a genuine Dart test package.
4. Translate only the approved assertions using [the focused migration reference](reference.md). Preserve collection deep equality, failure reasons, nullable/type refinements, exception detail checks and asynchronous completion. Await Future/stream assertions. Keep Flutter-only assertions in their existing form; never compare a Finder to a matcher object.
5. Search the approved scope for remaining assertions and review the diff. Keeping `flutter_test` keeps `expect` available, so import removal is not a completeness check. Do not replace meaningful checks with empty callbacks, unconditional passes or weaker assertions.

## Verification

Stop external Flutter processes; run the affected file through the serial harness, for example:

```sh
dart run tool/design_harness.dart check test/regression/quantity_test.dart
dart run tool/design_harness.dart check --full
```

Use the actual affected path. Full verification collects LCOV with concurrency 1 and analyzes `lib test integration_test tool`. Add `--native` when the existing Windows journey is required. Reuse strict fixtures; assertion migration does not require Mockito, a new harness, live account writes or production API changes.

The reference retains specialist mappings, synchronous/Future/stream differences and custom-check guidance. Load it only for an approved migration and validate against the resolved package version.
