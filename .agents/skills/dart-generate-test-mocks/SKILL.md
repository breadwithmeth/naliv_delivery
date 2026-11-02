---
name: dart-generate-test-mocks
description: Use when a Dart or Flutter test needs an external-service test double, or an explicitly requested Mockito mock must be generated or repaired.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: "2026-11-02"
---
# Choose the existing test double first

This checkout already has `http`, `flutter_test`, strict HTTP fixtures and preference helpers. It does not declare Mockito or `build_runner`. Needing a test double is not permission to add a code-generation toolchain or reshape production code.

## HTTP and storage tests

1. Read the nearest test and its injection/interception seam. Prefer `test/support/`, `test/fixtures/` and local `http/testing.dart` `MockClient` handlers; use established `http.runWithClient` interception when appropriate. See `test/regression/api_contract_test.dart` for a strict request recorder.
2. Match the expected method, URI, query and relevant headers/body. Provide synthetic success, malformed-response and failure data for the behavior under test. Never delegate unknown requests to a real client or answer every URL with success.
3. Record unknown requests **before** throwing. Assert that record is empty outside the production catch boundary, preferably with `addTearDown`, so swallowed transport errors still fail the test.
4. Assert the real consumer's exact result or state and expected requests. A plausible empty fallback or a mock invocation alone does not establish correct behavior. Close owned clients and reset preferences/state with existing helpers.

Production accounts remain read-only: no real SMS, address/card writes, orders or payments.

## Mockito only for an explicit generation need

If an existing Mockito-based test or approved task requires generated mocks:

- Check the actual `pubspec.yaml` and generation convention first. If Mockito/`build_runner` are absent, identify that prerequisite; adding them is a separate justified dependency change, not an automatic setup step. Do not add `package:test` to this Flutter app merely to copy an example.
- Use `@GenerateMocks([DependencyType])` for strict missing-stub behavior and import the generated `<test_name>.mocks.dart` file. Do not use a `part` directive for Mockito's generated mocks.
- Run `dart run build_runner build` only with that toolchain configured. Do not delete unrelated generated output to force generation.
- Explicitly stub expected calls. `@GenerateNiceMocks` returns legal dummy values for unstubbed calls; switching to it is not a fix for unknown requests or missing stubs.
- Use `thenReturn(value)` for synchronous values, `thenAnswer((_) async => value)` for a `Future`, and `thenAnswer((_) => Stream.fromIterable(values))` for a `Stream`. An `async` callback returns a Future, not a Stream.
- Repair the missing stub or argument mismatch; verify meaningful outcomes and exact interactions. Maintain an external unexpected-call assertion when consumer code catches exceptions.

## Verification

Stop external Flutter runs. Use `dart run tool/design_harness.dart check <actual test file>` for the focused regression, then `check --full` for serial coverage and analysis. Add `--native` when the existing Windows journey is required. Do not substitute `dart test`, blanket stubs or weakened assertions.
