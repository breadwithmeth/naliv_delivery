---
name: dart-use-ffigen
description: Use when generating or extending Dart FFI bindings from native headers, debugging ffigen configuration, or reviewing generated ABI declarations.
---

# Generate native bindings with ffigen

Prefer generation from authoritative C/Objective-C headers to hand-written ABI
signatures. Swift interop needs a supported exported bridge; do not assume direct
arbitrary Swift/C++ parsing. Generation does not compile, bundle or load a native
library by itself.

## Compatible workflow

1. Inspect the owning package's SDK constraint, resolved ffigen version, existing
   generator/configuration, headers and library-loading strategy. Preserve a
   working pinned YAML or Dart workflow for an incremental change. No automatic
   upgrade, YAML migration, header relocation or native-assets conversion.
2. Use documentation for that exact release. The `Headers`/`Functions` API and
   newer `Input`/`Visitor` API are different generations; never mix them. The
   reference includes a version-labelled example, not a dependency recommendation.
   The project minimum is Dart 3.11, even when the checkout is 3.12.2.
3. Add precise positive symbol filters and the necessary dependent declarations.
   Keep real compiler include paths, defines and target ABI settings. Prefer
   fixing header parse errors over `ignoreSourceErrors`. Mark `isLeaf` only when
   the function cannot call Dart or perform long/blocking work.
4. Reuse existing header/output locations and naming. For a new programmatic
   generator, `tool/ffigen.dart` with `Platform.script.resolve('../')` is a useful
   package-root convention, not a requirement to move existing files.
5. Preserve applicable native/package notices in the generated preamble and add a
   generation warning. Regenerate; never repair generated bindings by hand.
   Review that the diff includes the intended function and required types only.

## Avoid false requirements

- `lib/src/third_party/` and `.g.dart` are useful conventions, not Dart licensing
  or ffigen API requirements. Follow the package's existing layout and license.
- Record-use mappings are **optional**, only for an intentional compatible
  usage-recording/link-time design. ffigen **20.1.1 has neither**
  `Functions(recordUse: ...)` nor `Output(recordUseMapping: ...)`; copying those
  options into that release will not compile.
- Match generated binding style/asset identity to the existing loader. A runtime
  call alone does not require new hooks, recording packages or symbol stripping.

## Diagnose and validate

Run the existing generator and relevant analysis/tests when implementing a
binding change. Investigate include paths, target flags, SDK/package mismatch,
stale output and generator configuration before escalating an error. Narrow
justified generated-code lint suppressions belong in the generator preamble;
never blanket-suppress warnings, compiler errors or global rules. Report a
reproducible generator defect with versions/input only after configuration is
ruled out. Verify that the actual native binary exports the required ABI.

[Versioned example and specialist reference](references/ffigen_reference.md)
