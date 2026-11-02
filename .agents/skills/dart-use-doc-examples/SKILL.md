---
name: dart-use-doc-examples
description: Use when Dart API documentation needs external runnable examples, selected snippet regions, or hidden setup using dartdoc's example directive.
---

# External Dartdoc examples

Keep short, clear examples inline in a `dart`-labelled fence. Extract examples when
reuse, substantial setup or independent analysis/testing makes a separate file
useful; do not create scaffolding for a three-line snippet.

**Check the dartdoc version actually used locally and by the publishing pipeline.**
The package's Dart language constraint does not guarantee support for
`{@example}` or every directive option. If support is unavailable, retain a fenced
inline sample or a normal source link; do not upgrade the SDK just for injection.

## Directive and paths

```text
{@example <path>[#<region>] [lang=LANGUAGE] [indent=keep|strip]}
```

Put the directive on its own `///` line. A leading `/` resolves from the package
root; otherwise it is relative to the documented source file's directory. Paths
use URI rules and forward slashes, including on Windows (`%20` for spaces).
`..` resolution stops at the package root. Absolute/network URIs are unsupported.

The fence language defaults to the extension; `lang=text` overrides it.
`indent=strip` removes common space indentation by default; `indent=keep`
preserves it. Non-space indentation can disable stripping.

## Region example

A complete, local-only `example/client.dart` needs no HTTP client or real service:

```dart
void main() {
  // #region request_snippet
  const response = 'fixture response'; // #hide
  final message = response.toUpperCase();
  print(message);
  // #endregion request_snippet
}
```

```dart
/// Formats an already available response.
///
/// {@example /example/client.dart#request_snippet}
```

Only the selected region is embedded; marker lines and the **whole line**
containing `#hide` are removed. Hidden setup still participates in analysis and
execution of the example. Explain assumptions such as the existing `response`
in nearby prose so the extracted snippet is understandable.

With **no region suffix**, the entire file is included and no markers are
filtered, including `#hide`. Markers are text-based, not Dart-specific; accidental
marker text can affect extraction. Regions nest; `#endregion` closes the nearest
open region, and mismatched names/structure can produce warnings.

## Check the actual documentation

Analyze the external file with the existing analyzer workflow. Where docs are
generated, run the established `dart doc`/dartdoc command and inspect rendered
content plus missing-file/region/directive warnings; analysis alone does not
verify injection. Running an example is separate: use only synthetic/local data
and never trigger production requests merely to verify documentation.

[Directive specification](https://github.com/dart-lang/dartdoc/blob/main/doc/directives.md)
