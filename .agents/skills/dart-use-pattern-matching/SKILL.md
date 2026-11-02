---
name: dart-use-pattern-matching
description: Use when Dart code validates structured JSON, destructures records or collections, or branches exhaustively over sealed classes and enums.
---

# Dart patterns

Use patterns when they simplify structural matching, not for every condition.
These Dart 3 patterns work with the project's Dart 3.11 minimum; they do not need
experimental constructors, generated models or new dependencies.

## Choose a construct

- Produce a value: exhaustive `switch` expression, `pattern => expression`.
- Execute statements: `switch` statement; nonempty cases implicitly terminate,
  while empty cases can share a body.
- Extract several fields from an object/record: destructuring declaration.
- Promote one variable or compare one scalar: ordinary `is`/`if` is usually clearer.
- Prefer direct property access when only one known property is needed.

| Pattern | Key constraint |
| --- | --- |
| `A() || B()` | Alternatives bind the same variable names and types |
| `pattern1 && pattern2` | No overlapping variable declarations |
| `>= 0 && < 100` | Relational operands must be constants |
| `pattern?` / `pattern!` | Null-check fails to match / null-assert throws |
| `pattern as T` | Cast failure throws; not soft schema validation |
| `[a, b]` / `[a, ...]` | Exact length / unconstrained remaining elements |
| `{'key': pattern}` | Key must exist; extra keys are ignored |
| `(a, named: b)` | Record shape must match exactly |
| `Type(field: var x)` | Matches type, reads its getter |

Use `when` for a condition after a structural match. For sealed/enum domains,
enumerate the intended variants without a catch-all so added variants cause an
exhaustiveness diagnostic. An intentional fallback for open/dynamic input is a
separate decision.

## Validate without silently dropping data

A nullable map value pattern still **requires the key**. For an optional omitted
key, first match the required structure, then inspect the lookup. If absence and
explicit null differ, also use `containsKey`.

```dart
String? readAvatar(Map<String, Object?> profile) =>
    switch (profile['avatarUrl']) {
      final String? value => value,
      _ => throw FormatException('avatarUrl must be String or null'),
    };
```

An `as String?` cast instead throws a type error for malformed values; it does not
provide a `FormatException` contract. Similarly, `[String first, ...]` validates
only the first element, not every list item. Validate each item explicitly when
the schema requires all strings. Do not use filtering `if-case`, `whereType`, or
lazy casts to hide malformed records or delay errors past the parser boundary.

[JSON examples](examples/json_patterns.dart) retain discriminated unions, nested
map/list patterns and optional-key handling. For record assignment, existing
variables can be swapped with `(a, b) = (b, a)`; object/record shorthand can use
`:var field` when its name matches the getter.

Check omitted/null/wrong-type optional values, malformed list items and unknown
variants with the existing tests. Analyzer exhaustiveness does not validate a
runtime JSON schema; run the relevant parser cases too.
