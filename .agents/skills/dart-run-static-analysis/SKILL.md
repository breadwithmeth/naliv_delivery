---
name: dart-run-static-analysis
description: Use when inspecting Dart analyzer diagnostics, resolving warnings or type errors in changed files, or preparing analysis evidence for integration.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: "2026-11-02"
---
# Analyze with the existing policy

Read the current `analysis_options.yaml`, `pubspec.yaml` and affected code. This checkout already includes `package:flutter_lints/flutter.yaml`. Analysis is not permission to introduce strict-language flags, plugins, packages, new lint baselines or a formatter-policy migration.

## Inspect diagnostics

- Use OMP LSP diagnostics or `dart analyze <actual file>` for a focused inspection. Read the displayed source and related callsites before editing.
- Record diagnostic code, location and cause. Separate introduced problems from unrelated existing diagnostics; report blockers without silently rewriting unrelated code.
- Fix type/behavior problems at their cause. Do not downgrade errors, alter API contracts or add success-looking fallbacks to obtain a clean analyzer result.

## Apply only scoped fixes

Prefer a targeted code action or manual edit for one or two files. An unscoped `dart fix --apply` can change the entire checkout; do not use it as routine analysis remediation.

For an **explicitly approved directory-wide** mechanical repair, preview the specific diagnostic in the intended directory:

```sh
dart fix --dry-run --code=<diagnostic_code> <approved_directory>
```

Review every affected file and fix type. Apply with `--apply` replacing `--dry-run` only when all proposed changes are within the approved scope and preserve behavior. Do not enable extra lints to manufacture more fixes. Format only edited Dart paths with `dart format <actual edited files>`, never `dart format .` for a focused task.

## Suppression is not remediation

Do not use `ignore_for_file: type=lint`, exclude affected source trees, suppress type errors or disable rules globally to hide failures. A demonstrated false positive may justify a single-code, narrow line suppression with an explanation; inspect the underlying cause first. Preserve established generated-file policy instead of adding broad exclusions.

## Verify serially

Stop external Flutter runs. For repository analysis through the lock-protected harness:

```sh
dart run tool/design_harness.dart check
```

With no files or flags, this runs `dart analyze lib test integration_test tool`, not tests. For behavior changes, run `check <actual affected test file>` first; it runs that test with concurrency 1 and then analysis. At integration use `check --full` for retained tests, LCOV and analysis; add `--native` when the existing Windows journey is required. Never run competing Flutter processes or default-concurrency coverage.

Report actual commands and results, including unrelated diagnostics that prevent a clean run. Analysis alone does not prove runtime behavior or passing tests, and never authorizes production mutations.

Reference: [Dart fix scopes and diagnostic filtering](https://dart.dev/tools/dart-fix).
