# Dart CLI reference

## Minimal process lifecycle

For an existing script, retain its parser and error policy. In a distributable
package, a thin entrypoint can set process status from testable command logic:

```dart
import 'dart:io';
import 'package:my_cli/src/cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await runCli(args);
}
```

`exit()` bypasses Dart cleanup and can lose buffered output or interfere with
VM-service-based inspection/coverage. Natural completion still requires closing
servers, cancelling subscriptions and awaiting owned asynchronous work. Throwing
an error does not magically close resources owned elsewhere.

Conventional statuses are 0 success, 64 usage, 65 invalid data, 70 software error,
and 78 configuration error. Use the tool's existing convention. `package:io`
provides `ExitCode` constants but is not required for a few documented integers.

Use `ArgParser` for simple scripts and `CommandRunner<int>` for multiple commands.
Only classify errors from parsing/required-option validation as usage failures.
The explicit-help path must work without supplying mandatory business arguments.
Avoid broad `on ArgumentError` handlers around command execution: programmer errors
are not malformed command lines.

- Results/JSON: stdout. Warnings, failures and progress: stderr.
- Explicit `--help`: stdout/status 0. Invalid input: stderr with usage/status 64.
- Default async stack traces are useful. `Trace.from(stack).terse` is optional if
  stack_trace is already used; `Chain.capture` is not a required wrapper.
- Before ANSI output check the stream's terminal/escape support and `NO_COLOR`.
  Machine-readable output must remain free of formatting/log chatter.

## Packaging when distribution is actually requested

Only a **new standalone package** calls for `dart create -t console <name>`.
Only published/installable commands call for an executable mapping:

```yaml
executables:
  my_cli: # bin/my_cli.dart
  secondary_cmd: helper # bin/helper.dart
```

Invoke local scripts with `dart run tool/x.dart`; invoke package executables with
`dart run <package>:<executable>` as appropriate. Keep existing version sources;
code generation (`build_version`, `build_cli`) is not a prerequisite.

Dart 3.11-compatible distribution includes `dart pub global activate <package>` and
`dart compile exe bin/cli.dart -o <output>`. Dart 3.12 adds remote package execution
(`dart run <package>[:<executable>]@<version>`) and `dart install <package>`.
Neither replaces the local `tool/` workflow or justifies raising an SDK floor.
`dart build cli` bundles code assets where supported; current defaults place the
bundle under `build/cli/_/bundle/` with `bin/` and `lib/`. Inspect the selected SDK's
help rather than hardcoding a bundle path in scripts.

Keep transient project caches in an established ignored location, commonly
`.dart_tool/<tool>/`; don't move existing harness evidence directories.

## Specialist references and examples

- [AOT SDK discovery](aot_sdk_discovery.md): distinguish a Dart SDK from the
  currently running compiled executable.
- [Signals, terminal teardown and broken pipes](signals_and_terminal.md): load
  for interactive tools, streaming output or long-lived child processes.
- [Single-command example](../examples/single_command_tool.dart).
- [Multi-command example](../examples/multi_command_runner.dart).

The Dart examples use the project's existing args dependency and built-in I/O;
no io or stack_trace dependency is needed. They are reference examples, not project
scaffolds. Reuse existing test utilities. Import command logic for fast unit tests;
subprocess tests should cover actual stream routing/status. test_process/test_descriptor are optional choices in
packages that already use them, not required additions to an existing Flutter app.

## Authoritative API references

- [args](https://pub.dev/packages/args)
- [dart run](https://dart.dev/tools/dart-run)
- [dart install](https://dart.dev/tools/dart-install)
- [dart build](https://dart.dev/tools/dart-build)
- [cli_util 0.6 dartExecutable](https://pub.dev/documentation/cli_util/0.6.0/cli_util/dartExecutable.html)
