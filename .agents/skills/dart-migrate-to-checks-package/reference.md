# Matcher-to-Checks reference

Load only for an explicitly scoped `package:checks` migration. This reference preserves assertion semantics; it does not authorize a dependency or suite-wide migration.

Sources: [official migration guide](https://github.com/dart-lang/test/blob/master/pkgs/checks/doc/migrating_from_matcher.md), [Checks README](https://github.com/dart-lang/test/blob/master/pkgs/checks/README.md), [published API](https://pub.dev/documentation/checks/latest/checks/). Check the version actually selected by the project before adopting newer APIs.

## Common mappings

| Existing assertion | Checks equivalent | Semantic note |
| --- | --- | --- |
| `expect(actual, expected)` | `check(actual).equals(expected)` | Uses Dart `==`; see collections below. |
| `expect(actual, same(expected))` | `check(actual).identicalTo(expected)` | Identity, not equality. |
| `expect(actual, isA<T>())` | `check(actual).isA<T>()` | Returns a refined subject. |
| `expect(actual, hasLength(n))` | `check(actual).length.equals(n)` | Available on the applicable collection/string subject. |
| `expect(actual, isNull)` | `check(actual).isNull()` | |
| `expect(actual, isNotNull)` | `check(actual).isNotNull()` | Refines nullable subjects. |
| `expect(actual, isEmpty)` | `check(actual).isEmpty()` | |
| `expect(actual, isNotEmpty)` | `check(actual).isNotEmpty()` | |
| `expect(flag, isTrue)` | `check(flag).isTrue()` | Requires a non-nullable bool subject. |
| `expect(map, contains(key))` | `check(map).containsKey(key)` | Map keys, not iterable membership. |
| `expect(text, startsWith(prefix))` | `check(text).startsWith(prefix)` | |
| `expect(text, matches(pattern))` | `check(text).matchesPattern(RegExp(pattern))` | String patterns otherwise remain literal. |
| `expect(items, everyElement(greaterThan(0)))` | `check(items).every((item) => item.isGreaterThan(0))` | Preserve the real element condition. |
| `expect(value, isNot(equals(5)))` | `check(value).not((it) => it.equals(5))` | Preserve the negated condition. |

Do not translate Flutter finders or `findsOneWidget` as equality against a matcher object. Keep `flutter_test` and its widget-specific assertions.

## Equality, refinement and reasons

Collection matcher equality is structural; collection `==` normally is not:

```dart
// Before
expect(items, [1, 2, 3]);
expect(config, equals({'port': 8080}));

// After
check(items).deepEquals([1, 2, 3]);
check(config).deepEquals({'port': 8080});
```

Preserve a test's diagnostic reason:

```dart
check(result, because: 'server acknowledgment is required').isTrue();
```

`isTrue()`/`isFalse()` require `Subject<bool>`. For `bool?`, refine with `isNotNull()` before checking, or compare to the exact required boolean with `equals(true)`/`equals(false)`. Neither should accept null when the original assertion required true/false.

Property extraction returns another subject. Use cascades when asserting multiple properties of the same object:

```dart
check(response).isA<Response>()
  ..has((r) => r.statusCode, 'statusCode').equals(200)
  ..has((r) => r.body, 'body').contains('success');
```

For dynamic JSON or extension types, inspect static types and refine deliberately. Do not scatter unchecked casts or alter production types just to satisfy a converted assertion. For an extension type implementing `int`, an explicitly widened subject such as `check<int>(value).equals(3)` can preserve the intended comparison.

## Synchronous exceptions versus Future failures

Synchronous `throws<E>()` returns `Subject<E>` and accepts no inspection callback:

```dart
check(() => parseInvalid()).throws<FormatException>()
  .has((error) => error.message, 'message').equals('invalid input');
```

Future `throws<E>()` returns `Future<void>`. Await it; use its optional callback to inspect error details:

```dart
await check(loadInvalid()).throws<FormatException>((error) {
  error.has((value) => value.message, 'message').equals('invalid input');
});
```

Do not pass an async function as the subject of a synchronous throw assertion. Invoke it and check its returned Future. Do not chain `.equals()` onto an asynchronous assertion's `Future<void>`.

Future completion assertions also preserve the actual value condition:

```dart
await check(loadItems()).completes((items) => items.deepEquals([1, 2, 3]));
```

A completion-only assertion is appropriate only when completion itself is the contract. Do not replace meaningful value assertions with an empty condition callback to make migration pass.

## Streams

Checks evaluates streams through a queue. `withQueue` is convenient for one composite expectation:

```dart
await check(Stream.fromIterable([1, 2, 3])).withQueue.inOrder([
  (queue) => queue.emits((item) => item.equals(1)),
  (queue) => queue.emits((item) => item.equals(2)),
  (queue) => queue.emits((item) => item.equals(3)),
  (queue) => queue.isDone,
]);
```

For multiple separate assertions on one single-subscription stream, use an explicitly owned `StreamQueue` from `package:async` and cancel it in teardown. That import is a direct dependency decision, not permission to add another package automatically. Preserve completion/error conditions as well as emitted values.

## Custom assertions

Use a `Subject<T>` extension and `package:checks/context.dart` for custom matcher replacements. Return `Rejection` instead of throwing from predicate logic:

```dart
import 'package:checks/checks.dart';
import 'package:checks/context.dart';

extension NonNegativeChecks on Subject<int> {
  void isNonNegative() {
    context.expect(
      () => ['is non-negative'],
      (actual) => actual >= 0
          ? null
          : Rejection(which: ['is negative']),
    );
  }
}
```

Use `has((value) => value.field, 'field')` for non-failing property extraction. For extraction that can reject, `context.nest` takes a clause callback (`() => ['has a valid field']`) and returns `Extracted.value(...)` or `Extracted.rejection(...)` from its extraction callback. Asynchronous custom checks use `expectAsync`/`nestAsync` and must return the resulting Future.

## Discovery and verification

Search only approved files for `expect`, `expectLater`, `equals`, `matches`, `having` and custom matchers; inspect complete expressions rather than blind replacements. Keeping `flutter_test` intentionally keeps `expect` available, so removing `package:test/expect.dart` cannot prove that migration is complete.

Run the affected tests through the serial repository harness. Review failure messages and both positive/negative cases to establish semantic equivalence, not merely compilation. Check that no assertion, fixture rejection or failure condition was weakened.
