---
name: dart-fix-runtime-errors
description: Use when an observed Dart or Flutter exception occurs in a running debug app, including fixture-only failures requiring runtime stack and state evidence.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: "2026-11-02"
---
# Fixing a Dart or Flutter runtime failure

Use this workflow for an **observed exception in a running app**, not for static-analysis warnings. The repository's Dart MCP server is registered in `.omp/mcp.json`; the native fixture launcher is `flutter run -d windows -t tool/dev_surface.dart`. The fixture is not an authenticated production route.

## Connect to the running app

1. Prefer the user's existing running debug app. If none exists and the failure is reproducible with fixtures, launch the development gallery above. Do not use production credentials or mutate the live account.
2. Call Dart MCP `dtd` with `command: listDtdUris`. Connect to the **matching workspace** URI via `dtd` `command: connect`, `uri: <DTD WS URI>`. If several apps are connected, pass the selected VM-service `appUri` to each runtime tool.
3. If the app was started using Dart MCP `launch_app`, `list_running_apps` reports its process and DTD URI. An app started with `flutter run` outside MCP requires the DTD discovery/connect steps instead.

## Diagnose before changing code

1. Call `get_runtime_errors` with `clearRuntimeErrors: false`. Record the exception, first project stack frame, triggering action, and state. `get_app_logs` and `widget_inspector` (`get_widget_tree`, optionally `summaryOnly: true`) distinguish an invisible route or layout problem from a thrown exception.
2. Use OMP LSP definition/hover/references at the failing symbol; read the **displayed** relevant lines before editing. Trace the cause, including data and provider state. Do not merely catch an unexpected exception or replace it with a success-looking fallback.
3. Reproduce the same action or fixture state. If the error only occurs in release web, Dart MCP inspection of the native debug gallery does not prove the release behavior: use release browser evidence too.

## Fix and verify

1. Make the smallest cause-level edit; preserve frozen backend contracts and relevant callsites.
2. Use `hot_reload` for a compatible code change; use `hot_restart` if global state, constants, or initialization must reset. A hot-reload success message alone is **not** a fix.
3. Exercise the original failure path again. Check `get_runtime_errors` **after** the action; check the visible surface/widget tree and resulting state. Only clear stale runtime errors after recording them.
4. Add a permanent behavior regression using existing strict fixtures, then stop the debug app and other external Flutter runs before checks. Run `dart run tool/design_harness.dart check <actual test file>` for focused proof, then `dart run tool/design_harness.dart check --full` for serial LCOV and analysis of `lib test integration_test tool`. Add `--native` when the existing Windows journey is required; do not launch competing checks or default-concurrency coverage.

If DTD discovery or connection is unavailable, say exactly which runtime tool failed and fall back to the observable test/browser reproduction; do not claim a live inspector check.
