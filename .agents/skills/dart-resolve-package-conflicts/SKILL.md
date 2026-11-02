---
name: dart-resolve-package-conflicts
description: Use when Flutter pub reports incompatible dependency or SDK constraints, or an explicitly scoped package update is blocked by the resolved graph.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: "2026-11-02"
---
# Resolve the constraint conflict, not the lockfile

Pub selects one version of each package satisfying all applicable constraints. `pubspec.yaml` declares allowed versions; `pubspec.lock` records the solver's concrete result. Removing a locked version cannot make disjoint allowed ranges overlap.

## Diagnose from the existing failure

1. Read the reported solver chain; do not rerun an already-reported failure merely to confirm it. Distinguish incompatible package ranges from SDK constraints, network/authentication failures or a stale package cache.
2. Inspect the relevant `pubspec.yaml` declarations, `pubspec.lock` versions and direct dependency paths. This is a Flutter app: use `flutter pub` for pub operations. Its SDK floors are declared in `pubspec.yaml`; do not lower them to bypass a package requirement.
3. Use `flutter pub deps` to inspect the currently available graph and `flutter pub outdated` when release selection is needed. These are diagnostic commands, not repairs. A failed solve may leave only the previous graph available.
4. Find the smallest compatible parent-package release by reading its constraints/changelog. For `a → shared >=2 <3` and `b → shared >=3 <4`, choose a compatible release of `a` or `b`; no `shared` version satisfies both existing ranges.

## Make the minimum scoped repair

- If existing root constraints already allow the compatible release, preview `flutter pub upgrade --dry-run <actual package>`, then run `flutter pub upgrade <actual package>` for the chosen package.
- If a root constraint must change, edit only the relevant direct dependency after confirming API compatibility, then run `flutter pub get`. For a transitive conflict, change the introducing direct dependency rather than editing downloaded package manifests.
- Let pub generate the lockfile. Never delete it, remove individual entries, edit recorded versions/checksums or alter the cache to force a solve. Review the manifest/lockfile changes; targeted upgrades can still selectively unlock necessary related packages.
- Do not run blanket `pub upgrade`, `--major-versions`, `--tighten` or a dependency/SDK migration as routine conflict repair. Preserve existing constraint conventions instead of imposing caret syntax everywhere, especially on SDK/path/git dependencies.
- A `dependency_overrides` entry bypasses declared compatibility; it is not evidence of a repair. If no compatible release exists, report the actual package incompatibility and required replacement/fork decision rather than forcing a misleading success.

## Verify the resolved behavior

Confirm the chosen shared version satisfies both selected parent releases and review any required API edits. Stop external Flutter runs, run `dart run tool/design_harness.dart check <actual affected test file>`, then `dart run tool/design_harness.dart check --full` for serial coverage and analysis. Add `--native` when the existing Windows journey is required. Use strict synthetic fixtures; dependency resolution never authorizes production mutations or unrelated upgrades.

Reference: [official targeted upgrade behavior](https://dart.dev/tools/pub/cmd/pub-upgrade).
