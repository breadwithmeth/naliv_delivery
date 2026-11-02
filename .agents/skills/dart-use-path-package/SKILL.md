---
name: dart-use-path-package
description: Use when Dart code joins, compares, splits or converts filesystem paths, handles extensions, or must respect a foreign or in-memory filesystem's path style.
---

# Filesystem paths in Dart

Use the existing `package:path` dependency for path semantics, not indiscriminate
string replacement. This project already has path for tooling; do not add
`package:file`, migrate filesystem access, or rewrite non-path strings to apply
this skill. HTTP routing and URI encoding are distinct from native paths.

## Select the correct context

- Top-level `p.*` functions use the host style. For Windows strings on Linux use
  `p.Context(style: p.Style.windows)` (or `p.windows`); similarly use `p.posix`
  for explicitly POSIX inputs.
- If code already uses `package:file`, use `entity.fileSystem.path`, including
  tests using `MemoryFileSystem` with a style unlike the host. No new filesystem
  abstraction is needed just to join a local path.

## Operations and boundaries

| Intent | Operation |
| --- | --- |
| Join native segments | `context.join(root, 'sub', 'file.json')` |
| Inspect component names | `context.split(context.normalize(path))` |
| Test lexical descendant | `context.isWithin(root, path)` |
| Extract name/extension | `basename`, `extension`, `withoutExtension` |
| File URI conversion | matching context's `toUri` / `fromUri` |

`isWithin` excludes equality. Both it and normalization are lexical, not a
filesystem sandbox. For untrusted relative keys, reject absolute/outside-root
inputs before converting; symlink escape checks need filesystem-aware handling.

**`canonicalize` does not resolve symlinks**: it makes lexical canonical paths,
including Windows ASCII-case normalization. Use `FileSystemEntity.identical`
for filesystem-object identity, or `resolveSymbolicLinks` when a resolved target
path is needed; these perform I/O and can fail. `identical` follows directory
links within a path, **not a final link itself**: link-versus-target is false.
Resolve final links first when comparing their targets. Extension parsing and
normalization do not establish that an entry exists or is a file.

## Convert relative keys, not roots

For a validated descendant using the source context:

```dart
final relative = source.relative(filePath, from: root);
final segments = source.split(relative);
final gitKey = p.posix.joinAll(segments);
final url = Uri(
  scheme: 'https',
  host: 'example.invalid',
  pathSegments: ['assets', ...segments],
);
```

`p.url.joinAll` joins URL-style paths but does **not** percent-encode spaces or
`#`; `Uri(pathSegments: ...)` handles encoding. Do not use `Uri.parse(nativePath)`
or turn an absolute Windows root into a POSIX segment. Strip any diagnostic
`:line:column` suffix according to its actual format before path operations.

For extensions, define the intended compound suffixes explicitly: extension
level 2 is not a file-type detector (`main.dart.wasm` has `.dart.wasm`). Dotfiles,
trailing separators, case sensitivity, roots and relative paths need deliberate
cases. Keep literal suffix checks when that, rather than extension semantics,
is the requirement.

## Examples and checks

- [Cross-platform paths and compound extensions](examples/cross_platform_paths.dart).
- [Existing package:file context](examples/file_system_context.dart).

Check Windows/POSIX contexts explicitly and reuse existing tests. The second
example requires package:file; it is optional reference material, not a new
project dependency.

[canonicalize API](https://pub.dev/documentation/path/latest/path/canonicalize.html)
· [Filesystem identity API](https://api.dart.dev/dart-io/FileSystemEntity/identical.html)
