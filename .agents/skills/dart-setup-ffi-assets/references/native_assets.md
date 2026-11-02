# Native code-asset reference

## Version and integration boundaries

These are patterns for a package already tasked with native code assets, not a
migration prescription for an app using a platform plugin. Resolve a compatible
set of hooks/code_assets/native_toolchain_c for the package's minimum SDK.
For example, native_toolchain_c 0.19.5 declares Dart >=3.10, hooks ^2.0.0 and
code_assets ^2.1.0. The older `native_toolchain_c: ^0.1.0` is a different API family;
do not combine it with this reference's hooks API. This is not a dependency-add
instruction. Confirm selected package constraints and target support first.

Hook-imported packages belong in regular dependencies. ffigen is a development
dependency only when generating bindings. crypto is needed only by a digest-based
downloader; record_use is needed only by a compatible recorded-usage design.

## Build-only source package

Use a build hook when the goal is compilation plus bundling, without a separate
link-time optimization. For a package whose `src/native_add.c` exports its C ABI
and whose bindings use the matching asset identity:

```dart
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final builder = CBuilder.library(
      name: 'native_add',
      assetName: 'native_add.dart',
      sources: ['src/native_add.c'],
    );
    await builder.run(input: input, output: output);
  });
}
```

Use `input.packageRoot` to resolve package files and `input.outputDirectory` for
outputs where the selected API requires URIs. Source lists above are package-root
relative. `Platform.script.resolve('../')` is useful for a plain generator script
in `tool/`, but a hook should use the hook's supplied locations. Preserve license
notices. Resolve compiler/target SDK prerequisites rather than invoking arbitrary
shell compiler commands or installing toolchains as an incidental change.

## Optional two-phase build/link example

For a package deliberately using linker optimization, share a specification in
`lib/src/c_library.dart`:

```dart
import 'package:native_toolchain_c/native_toolchain_c.dart';

final cLibrary = CLibrary(
  name: 'sqlite3',
  assetName: 'src/third_party/sqlite3.g.dart',
  sources: ['third_party/sqlite/sqlite3.c'],
);
```

The corresponding `hook/build.dart` builds intermediates for the link phase:

```dart
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:sqlite/src/c_library.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    await cLibrary.build(
      input: input,
      output: output,
      defines: {
        if (input.config.code.targetOS == OS.windows)
          'SQLITE_API': '__declspec(dllexport)',
      },
    );
  });
}
```

Pair it with `CLibrary.link` in `hook/link.dart`; a build-only `CLibrary.build`
is not the ordinary one-phase equivalent of `CBuilder.run`. The SQLite paths and
export macro belong to that example, not every native package.

The [upstream SQLite link example](https://github.com/dart-lang/native/blob/main/pkgs/code_assets/example/sqlite/hook/link.dart)
uses `LinkerOptions.treeshake`, recorded method uses and a generated native-symbol
mapping. Use an example matching the resolved package versions. In particular,
ffigen 20.1.1's `Functions` has no `recordUse` parameter and its `Output` has no
`recordUseMapping` parameter; those cannot be added by copying a newer example.

Only apply usage-based stripping when the selected SDK/compiler and generator
produce the required metadata. Distinguish missing recording information from
an intentionally empty set of uses. Retain indirectly referenced exports,
callbacks and native registration entrypoints; qualify recorded references as
needed for the actual package instead of mapping every unrelated method by name.
Do not hand-author a fake generated map or require a universal directory/suffix.

## Precompiled downloads, only when requested

The download route belongs in `hook/build.dart`, not an app's startup path.
Select by the requested target OS, architecture and ABI (including libc or
simulator distinctions where applicable), not the host executing the hook.

1. Obtain an immutable release artifact over HTTPS from the agreed source.
2. Look up its pinned SHA-256 digest in trusted package metadata. Unknown targets
   or missing digests fail before use; a hash downloaded from the same untrusted
   source does not establish authenticity.
3. Download into the hook output/cache area, checking HTTP status. Close the
   `HttpClient` in `finally` and remove unusable partial output on failure.
4. Validate before registering a bundled `CodeAsset`; revalidate cached artifacts.
   MD5 is not suitable for adversarial integrity protection.

A streaming digest helper (requires the selected crypto package) is:

```dart
import 'dart:io';
import 'package:crypto/crypto.dart';

Future<String> hashAsset(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();
```

After successful validation, the standard bundled registration pattern is:

```dart
output.assets.code.add(
  CodeAsset(
    package: input.packageName,
    name: 'native_add.dart',
    linkMode: DynamicLoadingBundled(),
    file: file.uri,
  ),
);
```

Here `input`/`output` are the hook callback arguments and `file` is the verified
artifact. Use a real binding asset name; invented hash tables or release URLs are
not deployable examples. The reference intentionally supplies neither.

If local/offline selection is part of the requested design, document its explicit
user define or verified-local-artifact mode. A hooks configuration can use:

```yaml
hooks:
  user_defines:
    native_add:
      local_build: true
```

`native_add` is the actual package name in this example. Read the define through
the selected hooks version's user-defines API; do not assume it is an untyped map.
An offline local build still requires cached Dart dependencies and a compatible
compiler/target SDK. Do not silently download when local mode fails.

## Verification boundaries

Use existing package tests/harness commands. A host test establishes only the
configuration exercised; development/JIT tests do not prove release link-hook
execution or symbol stripping. For an intended release bundle, inspect its actual
output path (current `dart build cli` defaults to `build/cli/_/bundle/`):

- macOS: `nm -gU <actual-dylib>`.
- Linux: `nm -D <actual-so>`.
- Windows developer shell: `dumpbin /EXPORTS <actual-dll>`.

Compare consumers with used and unused functions. Expected runtime/ABI exports
may remain; do not claim the table must contain only a single selected function
or rely on one exact log message as proof. Verify loading/calls on each target;
separate cross-compilation from runtime acceptance. Exercise requested offline
modes without network and record what was actually tested.

## Sources

- [CLibrary 0.19.5](https://pub.dev/documentation/native_toolchain_c/0.19.5/native_toolchain_c/CLibrary-class.html)
- [CBuilder 0.19.5](https://pub.dev/documentation/native_toolchain_c/0.19.5/native_toolchain_c/CBuilder-class.html)
- [code_assets examples](https://github.com/dart-lang/native/tree/main/pkgs/code_assets/example)
- [ffigen 20.1.1 Functions](https://pub.dev/documentation/ffigen/20.1.1/ffigen/Functions-class.html)
- [ffigen 20.1.1 Output](https://pub.dev/documentation/ffigen/20.1.1/ffigen/Output-class.html)
