---
name: flutter-fix-layout-issues
description: Use when Flutter reports overflows, unbounded viewport or InputDecorator constraints, ParentData errors, or missing layout sizes.
---
# Fix Flutter layout constraints

**Constraints go down; sizes go up; parents position children.** Locate the first exception and inspect constraints along that axis. Later `RenderBox was not laid out` errors may be consequences, not the cause. Do not repeatedly launch a known-failing environment just to recapture an already reported error.

## Diagnose before choosing a wrapper

| Failure | Check and smallest valid fix |
| --- | --- |
| Unbounded vertical viewport | Identify the scroll owner. A `ListView` in a bounded `Column` can use `Expanded`; inside `SingleChildScrollView`, the Column's height is unbounded and flex is not a fix. Prefer one lazy `ListView`/`CustomScrollView`; use a non-scrolling shrink-wrapped inner list only for small content. Use an explicit height only when the design needs a separately bounded viewport. |
| Unbounded InputDecorator width | In a bounded `Row`, constrain the text field using `Expanded`/`Flexible` or a meaningful finite width. Trace any unbounded ancestor first. |
| RenderFlex overflow | Measure text/control space at the failing width and text scale. Wrap flexible text, stack or wrap controls, or scroll the intended axis; `Expanded` is not a universal overflow fix. |
| Incorrect ParentDataWidget | `Expanded`/`Flexible` must apply to a Flex child, `Positioned` to a Stack child, without an intervening incompatible render-object parent. Put padding inside the flex child. |

Example **only when the Column receives finite height**, such as a Scaffold body:

```dart
Column(
  children: [
    const Text('Header'),
    Expanded(
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: buildItem,
      ),
    ),
  ],
)
```

Do not put that Column under a vertical scroll view. If large text/keyboard leaves no room for fixed headers/footers, move them into the single scrolling content instead. Avoid clipping errors, disabling text scaling, arbitrary fixed heights, and blanket `shrinkWrap` on large lists.

## Reproduce safely in this project

Trace `lib/widgets/authentication_wrapper.dart` to the active feature/remaining legacy destination. Reuse `test/support/design_surfaces.dart` and relevant `test/integration/` tests. Launch `dart run tool/design_harness.dart preview` (the existing `tool/dev_surface.dart` Windows gallery); runtime MCP needs that debug app and is optional. Do not retry the known-failing debug Chrome path without a relevant change.

Check the failing geometry plus normal sizes: 320/375/800 px, inherited text scale up to 2, both themes, keyboard inset 300 and realistic long content. Avoid double-applying keyboard/safe-area insets. Assert no layout exception **and** final controls/fields remain reachable above the floating cart dock. Never verify with production SMS/orders/payments or account mutations.

Run focused tests through `dart run tool/design_harness.dart check <existing-test-path>`; use fixture captures for visual proof, not as a substitute for interactions.
