# Dart SDK Discovery and Subprocess Spawning in AOT & JIT

Guidance on locating the Dart SDK and spawning Dart child processes across JIT (`dart run`, `pub global activate`) and standalone AOT (`dart compile exe`, `dart install`) execution modes.

---

## 1. The AOT SDK Discovery Trap

When writing CLI developer tools that spawn `dart` child processes (e.g. running `build_runner`, `dart format`, `dart test`, or code analyzers), developers frequently write:

```dart
// ❌ WRONG: Breaks when compiled to AOT
final dart = Platform.resolvedExecutable;
final sdkDir = path.dirname(path.dirname(dart));
```

### Why This Fails in Standalone AOT:
* **JIT VM (`dart run`)**: `Platform.resolvedExecutable` normally identifies the SDK's Dart executable. Do not infer the mode solely from its filename: globally activated tools may run as compiled snapshots.
* **Standalone AOT binary (`dart compile exe`, `dart install` on Dart 3.12+)**: `Platform.resolvedExecutable` identifies the compiled application, not the Dart SDK.

### Consequences of Naive Resolution:
1. **Recursive Subprocess Loop**: If the application executes `Platform.resolvedExecutable` expecting the `dart` VM, it spawns itself recursively.
2. **Flag Rejection Crash**: If the child process passes VM flags (such as `--observe`, `--enable-vm-service`) or tool subcommands (like `run`, `format`, or `test`), the compiled binary fails immediately with unknown option errors.
3. **Broken SDK Root**: Traversing parent directories from `Platform.resolvedExecutable` to locate SDK resources (such as `libraries.json`) fails because the binary resides in an application bundle directory rather than a Dart SDK installation.

---

## 2. Reuse SDK Discovery

Prefer an existing SDK locator or explicitly configured executable. If the package already uses `package:cli_util` 0.6.0+, its nullable getters (`dartExecutable` and `sdkPath`) handle JIT/AOT discovery. Do not add or upgrade the dependency merely for an existing script already launched with a known Dart SDK.

```dart
import 'dart:io' as io;
import 'package:cli_util/cli_util.dart' as cli_util;

Future<void> runSubprocess() async {
  // Resolves the dart executable across both JIT and AOT environments
  final dartExe = cli_util.dartExecutable;
  if (dartExe == null) {
    io.stderr.writeln('Error: Could not locate the Dart SDK on PATH.');
    io.exitCode = 1;
    return;
  }

  final result = await io.Process.run(dartExe, ['format', '.']);
  io.stdout.write(result.stdout);
  io.stderr.write(result.stderr);
  io.exitCode = result.exitCode;
}
```

### Potential Dart SDK Locations:
A valid Dart SDK and `dart` executable may reside in several environmental locations across different developer setups:
* **Running VM (`Platform.resolvedExecutable`)**: When running on the JIT VM (`dart run`), `resolvedExecutable` points directly to `<dart-sdk>/bin/dart`.
* **Explicit Environment (`DART_SDK`)**: Defined when a developer explicitly points `DART_SDK` to an SDK installation directory.
* **System `PATH`**: Resolved via system `PATH` entries (`dart`, `dart.exe`, or `dart.bat`), including dereferencing symlinks and checking `bin/cache/dart-sdk` for Flutter installations.
* **Flutter Root (`FLUTTER_ROOT`)**: Bundled under `FLUTTER_ROOT/bin/cache/dart-sdk`.

The exact search order and SDK directory validation logic should be delegated to `package:cli_util` rather than re-implemented in application code.

---

## 3. Subprocess Spawning Invariants

When executing child subprocesses from a Dart CLI:

1. **Choose a Dart executable explicitly**: Reuse the existing locator/configuration, or `cli_util.dartExecutable` when available. A compiled app's own executable is not a Dart SDK.
2. **PATH-based choice**: `'dart'` is reasonable when that is the tool's documented SDK selection policy. Report missing SDK failures; do not silently select a different SDK.
3. **Windows batch wrappers**: A selected `.bat`/`.cmd` wrapper may need `runInShell: true`; an actual `dart.exe` does not. Avoid shell interpolation and untrusted command strings.
