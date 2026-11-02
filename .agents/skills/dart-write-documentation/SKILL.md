---
name: dart-write-documentation
description: Use when adding or reviewing Dart API doc comments, symbol links, library documentation, or Effective Dart documentation conventions.
---

# Dart API documentation

Read the declaration and implementation/callers before documenting behavior.
State the actual contract: nullability, side effects, failure modes or cache
semantics only when established. Do not invent return/exception behavior from a
name or merely repeat the signature.

## Write useful comments

- Prefer public API documentation. Private API docs or ordinary `//` comments are
  also useful for non-obvious invariants; do not impose a private-member ban.
  Avoid documenting trivial accessors merely to increase coverage.
- Use `///` above the declaration and its annotations. Begin with one short
  user-centric summary sentence; separate later prose with a `///` blank line.
- Start methods/functions with a third-person verb, properties with a noun
  phrase, and boolean properties with “Whether”. Avoid “This method/class…” and
  Javadoc tags such as `@param`, `@return` or `@throws`; explain them in prose.
- Explain parameters, returns and exceptions together in readable prose when
  relevant. Inherit unchanged override documentation; document changed behavior.
  For a getter/setter pair, normally document only the getter.

## Links and examples

Use `[identifier]` for a resolvable symbol (`[id]`, `[Client.close]`), without
call parentheses. Link an unnamed constructor as `[Client.new]`. Use backticks for
keywords, literal values and arbitrary expressions, including `null` and `true`.

For an out-of-scope symbol from an **already available dependency**, a
library-level doc import can avoid adding an ordinary import solely for docs:

```dart
/// @docImport 'package:http/http.dart';
library;

/// A component that can be used with [Client].
```

Use that relationship only if true. `@docImport` is not a pubspec dependency
substitute or permission to introduce a package. Respect existing library-level
docs/annotations, prefixes and the selected analyzer/dartdoc support.

Keep small samples inline in a language-labelled fence. External runnable samples
are useful for reuse or substantial setup, not mandatory for every snippet.
Use `dart-use-doc-examples` only when external example injection is needed;
verify directive support before adopting it. Examples must remain synthetic and
must not execute production mutations.

[Documentation examples](references/documentation_examples.md) cover prose versus
tags, annotations, property openers, constructor links and doc imports. They are
illustrations, not evidence for an undocumented implementation's behavior.

## Check documentation, not just syntax

Use the repository's existing analysis workflow. The `comment_references` lint
checks references only when enabled and applicable; a clean `dart analyze` is
**not** proof every link resolves or renders. When generated API docs matter,
run the established dartdoc command and inspect diagnostics/output as well.
Do not add lints/dependencies or rewrite global configuration just for this skill.

[Effective Dart: Documentation](https://dart.dev/effective-dart/documentation)
