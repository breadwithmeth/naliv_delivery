---
name: flutter-build-responsive-layout
description: Use when Flutter content must remain usable across window sizes, large text, keyboard insets, or different input methods.
---
# Responsive Flutter layouts

## Measure the allocated space

Use `LayoutBuilder` for local constraints and `MediaQuery.sizeOf(context)` for the app window. Base breakpoints on content that no longer fits, not phone/tablet detection, physical display size or orientation. Physical `Display` dimensions can exceed letterboxed content; they are not a substitute for the constraints used to lay out that content.

Read the active route in `lib/widgets/authentication_wrapper.dart`, then the actual feature and its existing `lib/design/` and `lib/ui/` patterns. Preserve floating cart-only navigation, destinations, shared state and scroll position. A responsive fix does not authorize a router, navigation-shell or orientation-policy migration.

## Make content fit without losing behavior

- Allow text and error messages to wrap; retain inherited `TextScaler`. Replace text-dependent fixed heights with padding/minimums. Do not disable accessibility scaling to match a screenshot.
- Use `Expanded`/`Flexible` only within compatible Flex constraints; a vertically unbounded scrolling Column has no finite remaining height.
- Stack or wrap competing controls when needed. Center/constrain readable content on wide windows. Do not automatically convert checkout lists to grids or add sidebars. For actual product grids, use existing delegates and lazy builders.
- Keep one clear scroll owner and lazy rendering for large collections. Reserve enough scroll clearance for the actual floating cart dock and safe area.
- Account for keyboard-reduced space and focused-field visibility; do not subtract keyboard/safe-area insets twice. Keep the last field and action reachable.
- Preserve focus order, visible keyboard focus and usable touch/mouse targets. Resizing must not reset cart/form state.

## Prove the dimensions and interactions

Reuse `test/support/design_surfaces.dart` and `test/integration/home_layout_test.dart` or the affected screen test. The fixture controls expose width, text scaling and keyboard inset:

```sh
dart run tool/design_harness.dart preview
dart run tool/design_harness.dart capture checkout_pickup --theme both --capture-only --width 320 --text-scale 2 --keyboard 300
```

Run preview and capture serially; close preview first. Check 320/375/800 logical-pixel widths, normal/2x text, keyboard hidden/shown, both themes and long/empty/error data. Canonical design geometry is 375 x 812 with top/bottom insets 48/34 and DPR 2; adaptive captures must not overwrite its fixed-reference evidence.

Assert no layout exceptions, readable controls, final-content clearance and working navigation/inputs; pixel differences alone prove none of those. Fixtures use synthetic preferences and strict transports; never fall through to production or mutate real accounts, orders or payments.

Run focused tests via `dart run tool/design_harness.dart check <existing-test-path>`.
