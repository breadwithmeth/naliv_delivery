---
name: dart-build-cli-app
description: Use when implementing or debugging Dart command-line tools, argument parsing, process exit status, terminal I/O, subprocesses, or CLI distribution.
---

# Dart CLI applications

Extend the existing tool and test layout first. A repository-local `tool/*.dart`
script does not need a new package, `bin/` migration, executable mapping, version
generator, or additional dependencies. This is not a Flutter UI skill.

## Core decisions

- Use the existing `package:args` parser: `ArgParser` for one command,
  `CommandRunner<int>` / `Command<int>` for a real command hierarchy. Typed
  `flag`, `option`, and `multiOption` accessors are available in args 2.5+.
- Keep reusable logic independently testable. For a new distributable CLI package,
  a thin `bin/` entrypoint and `lib/src/` command implementation are useful;
  preserve established local scripts rather than moving them gratuitously.
- Return an integer status from the runner; assign it to `exitCode` in `main`.
  Returning an integer alone does not set the process status. Let cleanup and
  asynchronous writes finish; avoid `exit()` in normal/error paths.
- Put results on stdout and diagnostics on stderr. Explicit help goes to stdout
  with status 0; parse/required-option errors and their usage go to stderr with
  status 64. Catch usage failures around parsing/option validation, not around all
  business logic. Keep unexpected failures distinguishable from usage errors.
- Use integer statuses already established by the tool (`0`, `64`, `70` are
  conventional), or `package:io` constants if that dependency already exists.
  Built-in async stack traces suffice; formatting packages are optional.
- Emit ANSI only for a capable terminal, respecting `NO_COLOR`. Restore original
  terminal modes/cursor and cancel signal subscriptions during cleanup.

## Subprocesses and versions

A compiled app's `Platform.resolvedExecutable` is the app itself, not necessarily
Dart. Reuse existing SDK discovery or an explicit executable. With cli_util 0.6+
its nullable `dartExecutable` getter is an option, not a reason to add a dependency.
Pass argument lists and preserve child output/status; use a shell only when needed
for an explicitly selected Windows batch wrapper.

Check the package's **minimum** SDK, not just the installed SDK. `dart run tool/x.dart`
and `dart compile exe bin/x.dart -o <output>` suit their respective existing targets.
Remote `dart run package@version` and `dart install` require Dart 3.12+; do not make
them required for a Dart 3.11 workflow. Native-asset bundles use `dart build cli`
where supported; consult that SDK's help for options and output layout. Declare
`executables:` only when publishing/installing package executables.

## References and checks

Read [the focused reference](references/cli_reference.md) only for packaging,
subprocess or terminal details and reusable examples. Test parsing/logic in memory
and use a few subprocess checks for stdout, stderr, exit status and cleanup.
Reuse the repository's existing test/harness commands; do not add test packages
just to follow this skill.
