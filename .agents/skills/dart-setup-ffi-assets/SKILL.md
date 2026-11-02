---
name: dart-setup-ffi-assets
description: Use when a Dart or Flutter package explicitly needs C/C++ source compilation, bundled native libraries, or native build/link hooks.
---

# Native code assets

Keep existing plugin/native integration unless the task explicitly calls for code
assets. This skill does not authorize a migration, new native package, downloads,
or dependency upgrades in an otherwise unrelated Flutter change.

## Choose the smallest integration

1. Inspect package SDK constraints, resolved dependency versions, target platforms,
   headers/bindings and existing build configuration. The project supports Dart
   3.11 / Flutter 3.41; a newer checkout does not raise that minimum. Confirm hook
   and generator APIs against the **selected versions**, not a latest-only example.
2. For ordinary source compilation/bundling, use `hook/build.dart` and
   `CBuilder.library(...).run(...)` where supported. Use the hook input's target
   configuration and package/output URIs, not host OS guesses or absolute paths.
3. Add `hook/link.dart` only when a link-time transformation is actually needed.
   `CLibrary` is the shared build/link specification for that two-phase design;
   do not substitute `CLibrary.build` for a complete build-only `CBuilder` flow.
4. Keep hook imports in regular package dependencies: `hooks`, `code_assets` and,
   for local compilation, `native_toolchain_c`. `ffigen` is a development generator;
   usage-recording and crypto dependencies belong only to designs needing them.
   Choose a compatible set; do not copy old version pins or add every package.

## Safety and evidence

- Prefer the existing programmatic toolchain. Local compilation needs a suitable
  compiler/target SDK (MSVC desktop C++ on Windows, Xcode tools on macOS, GCC/Clang
  on Linux); it does not guarantee every cross-target build works.
- Match binding asset identity and exported symbols, including Windows exports.
  Preserve applicable licenses and existing source/output locations.
- Usage-based tree shaking is optional. It requires compatible recording APIs,
  generated mappings and indirect-symbol retention; never guess mappings or treat
  missing metadata as proof that nothing is used.
- Prebuilt binaries require trusted target-specific artifacts and pinned SHA-256
  digests (or verified signatures), **not MD5**. Reject unsupported targets and
  mismatches before registration. Offline/local selection must be explicit; no
  silent network fallback. Keep network-free packages network-free.
- Host tests prove only the exercised host path. Release link-time stripping needs
  a release/AOT consumer and symbol inspection; each supported target needs its
  own build/runtime evidence. Do not assume `dart test` exercises link hooks.

Read [the native-asset reference](references/native_assets.md) for focused build,
link and download patterns. Use the repository's existing verification workflow;
report untested targets and offline modes rather than claiming universal support.
