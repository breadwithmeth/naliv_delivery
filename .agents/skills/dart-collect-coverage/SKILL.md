---
name: dart-collect-coverage
description: Use when collecting or inspecting LCOV for this Flutter app, investigating uncovered behavior, or checking whether coverage evidence is current.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: "2026-11-02"
---
# Collect coverage through the existing harness

Flutter already emits LCOV. Do not install `coverage`, Mockito or a separate test runner merely to collect this checkout's coverage.

## Collect

Stop external Flutter runs and let any active harness operation finish. Never bypass a busy harness lock. From the repository root:

```sh
dart run tool/design_harness.dart check --full
```

This runs retained Flutter tests with `--coverage --concurrency=1 --timeout=90s`, then analyzes `lib test integration_test tool`, serially. Default-concurrency coverage previously exhausted memory here; do not run competing test/build processes. Add `--native` when the existing Windows shopping journey is required; its execution is separate from the retained host-test LCOV run.

## Inspect the evidence

- Confirm the test step completed successfully before treating a report as complete. The harness is fail-fast; coverage can exist even if later analysis fails. Report each step's actual result.
- Check that `coverage/lcov.info` is newly generated and nonempty, with expected source-file (`SF:`), line-hit (`DA:`) and `end_of_record` entries. A previous run's report is not proof of this run.
- Harness logs and run status are under `.figma_cache/harness/runs/`.
- This workflow does not promise `coverage/coverage.json`; missing raw JSON is not a failure. Do not claim native/device or production coverage from host-test LCOV.

## Investigate gaps

1. Distinguish a source file absent from `SF:` records from a recorded file with zero-hit lines. Inspect path variants before concluding the file is missing.
2. Check retained test discovery, imports and execution of the relevant production behavior. Compilation failures or timeouts are not coverage gaps to conceal.
3. Add meaningful focused behavior tests with existing `flutter_test` assertions and strict fixtures. Run the affected file through `check <actual test file>`, then regenerate coverage with `check --full`; the focused check alone does not request coverage.
4. Keep unknown fixture requests recorded and rejected, and production account operations read-only. Do not weaken assertions or insert `coverage:ignore-file`, `coverage:ignore-line` or ignore blocks to hide untested business logic.

A justified exclusion is an explicit, reviewed coverage-policy change, not a routine missing-file remedy. Manual VM-service collection belongs to a separately demonstrated tooling need; it is not required for this app's existing LCOV workflow.
