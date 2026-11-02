---
name: dart-use-primary-constructors
description: Use when a Dart task explicitly requests primary constructors, concise new/factory constructor declarations, related empty-body syntax, or compatibility diagnosis for those features.
---

# Primary constructors: check compatibility first

**Do not apply this syntax automatically in this project.** Its supported minimum
is Dart 3.11 / Flutter 3.41; the documented checkout uses Dart 3.12.2. Keep ordinary
constructors, braces and initializer lists for that baseline. Do not enable an
experiment, raise SDK constraints or run an automatic constructor migration to
reduce boilerplate.

| Target | Primary constructors and related concise syntax |
| --- | --- |
| Dart 3.11 | Unsupported |
| Dart 3.12 | Experimental; explicit experiment-enabled toolchain required |
| Dart 3.13+ | Stable with a compatible library language version |

A newer installed SDK alone does not change a package's language version, normally
derived from its lower SDK bound. For an explicitly requested migration in another
package, inspect SDK/language constraints and Flutter compatibility first. For a
3.12 experiment explicitly requested outside the supported production baseline,
follow that SDK's experiment documentation across execution, analysis and tests;
changing analyzer options alone is not a compatibility fix.

## Compatible baseline

```dart
class Point {
  final int x;
  final int y;

  const Point(this.x, this.y);
  const Point.zero() : this(0, 0);
}
```

Preserve constness, field mutability, assertions, initializer order, named/factory
APIs and redirecting constructors. An ordinary initializer list is the supported
place for computations from constructor parameters.

Existing extension-type header constructors are a different, already supported
feature:

```dart
extension type const UserId(int value) {}
```

That representation-field syntax does not permit ordinary class header
constructors on Dart 3.11, and an extension type is not a drop-in class replacement.

## Specialist syntax reference

Only after the version decision, read [the newer-syntax reference](references/primary_constructors.md)
for declaring parameters, initializer scopes, `this :`, concise `new`/`factory`,
const constructors and migration examples. Those examples target Dart 3.13,
not the current project's supported baseline. In particular, declaring a field
with a header parameter and initializing it again is an error.

Verify an intentional migration with the package's actual minimum language/SDK
and existing tests/analyzer. Do not use broad `dart fix` as an unreviewed feature
migration or assume a quick-fix exists for a particular constructor diagnostic.

[Language evolution](https://dart.dev/resources/language/evolution)
· [Dart 3.12 experimental preview](https://dart.dev/blog/announcing-dart-3-12)
