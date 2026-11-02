# Primary constructor reference — Dart 3.13 language version

These examples describe the stable newer feature, **not** the current project's
Dart 3.11 baseline. Dart 3.12 preview syntax can evolve; check the exact preview
SDK documentation when explicitly experimenting. Do not change SDK constraints,
analysis options or production constructors merely to use these examples.

## Header parameters and constness

```dart
class Point(var int x, var int y);
class PointFinal(final int x, final int y);
class const ConstPoint(final int x, final int y);
```

- `var` / `final` declaring parameters create and initialize instance fields.
- `this.field` initializing parameters initialize existing fields.
- `super.parameter` forwards to the corresponding super-constructor parameter.
- Plain parameters (`int y`) create no field; they are available during primary
  initialization and in the primary constructor body.
- A const primary constructor places `const` before the type name. All instance
  fields must satisfy the usual const restrictions; no body block, late fields or
  mutable instance fields, and initializers must be potentially constant.

With an existing `Base(int value)` constructor, a plain forwarding parameter is:

```dart
class C(final int x, int y) extends Base {
  this : super(y);
}
```

For extension types there is exactly one representation parameter. Its declaring
semantics are special: `final` may be explicit in the newer feature, but `var` is
not allowed. The established pre-3.13 form remains `extension type E(int value) {}`.
Enums can also use primary constructor parameters:

```dart
enum const MyEnum(final int x) {
  entry(1);
}
```

## Initializers without double assignment

```dart
class Point(var int x, int inputY) {
  final int y;
  this : assert(x >= 0), y = inputY * 2;
}
```

`inputY` deliberately is a **plain** parameter; it does not implicitly initialize
`y`. Writing `var int y` in the header and `y = y * 2` in `this :` initializes that
field twice and is invalid. Assertions and initializer lists end in `;` when no
constructor body is needed; `this { ... }` provides a body for a non-const primary
constructor. A const constructor cannot have a body block, even an empty one.

Header parameters are in the **primary initializer scope** for non-late field
initializers and the `this :` list:

```dart
class DeltaPoint(final int x, int delta) {
  final int y = x + delta;
}
```

They are not in scope as parameters in a `late` initializer. A reference there
must resolve through normal member scope (for example the induced field `x`);
a plain parameter such as `delta` is unavailable. Initializer-scope parameters
cannot be assigned during initialization. In the constructor body, an induced
field name instead denotes the instance field, so a mutable field can be updated:

```dart
class ScopingDemo(var String x, String suffix) {
  final String original = x;
  this {
    x = x.toUpperCase();
    print('$x$suffix');
  }
}
```

## Empty declarations and concise constructors

In the newer feature, eligible empty class/mixin/extension/extension-type bodies
may use `;`. This syntax is not a baseline-compatible substitute for `{}`:

```dart
class C(int x);
mixin class MC;
mixin M;
extension Ext on C;
extension type ET(int x);
```

Mixin-class primary constructors must have no parameters, body or initializer
list; an arbitrary parameterized primary constructor is not valid there.

| Traditional declaration | New concise declaration |
| --- | --- |
| `MyClass() {}` | `new() {}` |
| `MyClass.name() {}` | `new name() {}` |
| `const MyClass();` | `const new();` |
| `const MyClass.name();` | `const new name();` |
| `factory MyClass() => value;` | `factory() => value;` |
| `factory MyClass.name() => value;` | `factory name() => value;` |

These are constructor **declarations**, not changes to call-site syntax.

## Migration examples, only for an explicit compatible migration

Preserve public constructor names, visibility, defaults, field semantics,
assertions and evaluation order. A simple `User(this.name, this.age)` class can
become `class User(final String name, final int age);` when those fields were
final. A computed field can use primary initializer scope:

```dart
class Rect(final double width, final double height) {
  final double area = width * height;
}
```

A class/mixin class/enum with a primary constructor cannot also have another
non-redirecting generative constructor. Other generative constructors must
redirect to the primary (extension types have their own rules):

```dart
class Point(final int x, final int y) {
  new zero() : this(0, 0);
}
```

Concise declarations do not require moving fields into the header. With a class
body-only design:

```dart
class DatabaseService {
  final String url;
  new(this.url);
  new local() : url = 'localhost';
  factory create() => DatabaseService('default');
}
```

When diagnosing errors, inspect the actual analyzer diagnostic: common causes are
unsupported language version, late access to a plain primary parameter, double
initialization or a non-redirecting generative constructor alongside a primary.
Fix the semantic cause, not a guessed diagnostic code, and do not blanket-run
`dart fix` as a feature migration.

## Sources

- [Primary constructors](https://dart.dev/language/primary-constructors)
- [Concise constructor syntax](https://dart.dev/language/constructors#concise-constructor-syntax)
- [Language versioning](https://dart.dev/language/versioning)
- [Dart 3.13 announcement](https://dart.dev/blog/announcing-dart-3-13)
