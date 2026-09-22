# Fidelity report — redesigned screens vs the Figma file

Measured, not asserted. Every number below comes from rendering a rebuilt screen at the design's
own size and subtracting the exported frame, pixel by pixel.

Last run: 2026-09-22. Regenerate with:

```bash
dart run tool/figma_spec.dart png --page "Design System (Dark)"   # exports the frames
flutter test .figma_cache/home_reference_test.dart                 # renders the rebuilt home
flutter test .figma_cache/design_diff_test.dart                    # diffs dark + light
flutter test .figma_cache/card_diff_test.dart                      # diffs the card grid
```

## Method

* The app is rendered at **375 × 812 @2×**, with the status bar (48 pt) and home-indicator area
  (34 pt) simulated so the comparison is like-for-like with the mock frame, then **excluded** from
  the diff — the device draws that chrome, the app must not.
* `RenderRepaintBoundary.toImage(pixelRatio: 2)` inside `tester.runAsync`. Awaiting it directly
  deadlocks on the second capture in a file (measured: a 10-minute timeout).
* Reported as **mean absolute channel difference out of 255** plus the share of pixels differing by
  more than 32. Mean is the headline because a pixel-perfect target is not attainable: font
  rasterisation alone accounts for a couple of units.
* Regions that cannot match by construction are excluded and named, never quietly averaged away —
  e.g. the card grid's artwork, where the harness has no product photos.

## Results

| Screen | State | meanΔ /255 | pixels > 32 | Worst bands (meanΔ) |
|---|---|---|---|---|
| Home («Главная») | dark | **10.78** | 8.90 % | y≈725: 99 · y≈775: 47 · y≈750: 45 |
| Home («Главная») | light | **14.07** | 9.66 % | y≈725: 101 · y≈750: 48 · y≈775: 47 · y≈75–100: 30–34 |
| Product-card grid | dark | **11.28** | 6.63 % | artwork excluded; residual is text AA |

Reading the residuals:

* **y≈700–790 (Δ ≈ 100)** — the bottom band, and it is a deliberate deviation: `Главная` draws the
  88 px glass strip, and the product requirement is *no bottom bar*, only the cart button. The
  scalloped button's own SVG shadow is also ignored by `flutter_svg`, so the design's shadow is
  re-applied in Flutter (`AppShadows.control`).
* **light, y≈75–100 (Δ 30–34)** — the address card and search field. Their light-theme surface is
  the next thing to tune if the remaining few percent matter.
* **everything else ≤ 24** — text antialiasing, plus the substituted glyphs listed below.

## Known deviations (all deliberate, all with a reason)

| Bucket | Detail |
|---|---|
| Removed by request | The full-width bottom bar behind the cart button |
| Glyphs Figma won't export | `Store_Icon_UIA` (same-family shop glyph used), the search field's scan glyph (drawn as five bars), `vuesax/bold/heart` (Material's filled heart on search rows) |
| Design inconsistency | The saving line «Выгода 1317 ₸» has no thousands separator while prices do; one formatter (NBSP) is used for both |
| Design editing artifacts | A grid card with duplicated stepper nodes at identical coordinates; a promo panel whose artwork bleeds outside its rounded box |
| Undesigned states | Empty cart, category-with-no-items, and most error states — the design defines an error only for FAQ |

## Not yet measured

Measured today: the home screen (both themes) and the product-card grid. **Still unmeasured:** the
catalogue screens, product detail, cart, orders, profile, bonuses, certificates, intro slides and
search.

They are not unmeasurable — the pattern is the same three steps per screen: export its frame
(`tool/figma_spec.dart png`), render the rebuilt screen in a throwaway harness, diff with the crop
offsets. What each one needs is a harness that reproduces the screen's data as fixtures, which for
data-driven screens means freezing a sample response. That is the work, and it is deliberately left
to whoever picks this up rather than faked with a number.
