# Fidelity report — redesigned screens vs the Figma file

## Current measurements — 2026-10-09

The F1–F11 client corrections and whole-screen design cutover are implemented and reviewed in
strict fixtures. **This is not pixel-parity, authenticated-production, bank or push acceptance.**
All 212 original Figma frames are retained, including separate ordinary/modal home variants.
The measurements below come from the settled-source `dart run tool/verify_surface.dart all
--theme both`; implementation and runtime evidence is in `STATUS.md`.

### Method and scope

- The final `dart run tool/verify_surface.dart all --theme both` completed **82 captures** for **41 surfaces**, at **375 × 812 logical / DPR 2 = 750 × 1624 pixels**, and **50 applicable frame comparisons**. Sixteen surfaces per theme have no exact app frame and are capture-only.
- Current metric: for each app pixel, take `max(abs(ΔR), abs(ΔG), abs(ΔB))`; report its mean out of 255 and the percentage above 32. Only the simulated **48 px top / 34 px bottom** logical insets are excluded. This is not the historical masked-artwork/channel-average measurement.
- `tool/design/surface_compare_test.dart` has **no golden threshold**. Passing means the captures/references had valid dimensions and measurement completed, not that the residual is acceptable.
- The owned disposable adaptive probe passed **434** render/strict-request cases across 41 surfaces, 320/375/800 logical widths, 1.6×/2× inherited text and both themes; relevant forms also used a 300 px keyboard inset. These are overflow/transport checks, not proof that every control was operated at every size.
- A retained bottling regression verifies that the live summary and first quantity control remain above the purchase action at the 375 × 812 / 48–34 inset reference. Actual browser journeys establish navigation and state transitions separately.

### Current diagnostic results

| Surface | Dark mean Δ /255 | Dark pixels >32 | Light mean Δ /255 | Light pixels >32 |
|---|---:|---:|---:|---:|
| home | 22.05 | 16.59% | 30.81 | 18.54% |
| catalog | 53.83 | 35.94% | 49.48 | 28.08% |
| all_products | 73.89 | 40.67% | 50.23 | 28.30% |
| cart | 91.24 | 45.64% | 50.97 | 25.54% |
| profile | 15.93 | 8.81% | 14.81 | 8.42% |
| profile_guest | 23.30 | 11.73% | 21.83 | 11.04% |
| orders | 15.37 | 9.68% | 11.32 | 4.42% |
| order_detail | 28.22 | 22.90% | 21.36 | 12.07% |
| support | 20.45 | 9.13% | 20.36 | 8.02% |
| certificates | 18.07 | 12.69% | 15.31 | 7.50% |
| addresses | 19.40 | 11.59% | 18.88 | 9.85% |
| address_map | 93.71 | 43.17% | 42.75 | 53.59% |
| address_details | 20.31 | 12.54% | 19.75 | 11.37% |
| cards | 13.43 | 8.50% | 13.62 | 8.48% |
| checkout_delivery | 31.46 | 26.16% | 29.30 | 21.03% |
| checkout_pickup | 37.44 | 24.36% | 34.97 | 19.60% |
| certificate_purchase | 27.76 | 20.21% | 55.35 | 36.00% |
| payment_success | 15.22 | 6.83% | 14.59 | 6.68% |
| search | 24.67 | 32.32% | 19.71 | 23.80% |
| favorites | 9.54 | 8.45% | 7.57 | 4.10% |
| bonus_history | 18.20 | 11.99% | 14.74 | 6.68% |
| bonus_explainer | 23.86 | 13.56% | 23.46 | 13.63% |
| faq | 17.56 | 9.55% | 16.00 | 9.31% |
| intro | 15.84 | 12.00% | 17.00 | 12.26% |
| sign_in | 49.52 | 50.62% | 36.41 | 18.10% |

Catalogue/cart/map residuals remain large. These figures are not a pixel match and must not be attributed solely to font antialiasing. Fixtures contain synthetic names, missing product/category photos and synthetic map tiles; readable/scalable content also changes geometry. The measurements do not isolate the contribution of each difference.

### Visual review and deliberate departures

- All 82 final-source full captures were reviewed uncropped in 22 light/dark contact sheets; changed bottling frames were additionally reviewed full-size after the live-summary cutover. Actual guest shopping and account/support journeys are recorded separately in `STATUS.md`.
- Text scaling remains inherited. At the normal 375 px reference, home categories and complete product grids retain the full-frame three-column composition; narrower/larger-text layouts reduce columns and flow row controls instead of forcing unreadable text or fixed-height clipping.
- A single `ProductCard` serves grids/strips. Metadata, bonus/gift chips, price and ≥44 px add/quantity controls have priority over missing/synthetic artwork. Previously documented forced two-column/96 px artwork rules are superseded.
- Guest profile is inside the store card with an independent ≥44 px target; signed-in shortcuts remain separate. Canonical white dark-brand artwork is used instead of whitening the light asset. The floating cart has one lower glass layer and the original starburst alpha, without a second circular backing; no drawer/bottom tab strip was introduced.
- The pour picker starts with live paid/gift litres, complete physical mix, ADD/REPLACE pricing and promotion progress. Affected bottle rows show actual paid/gift drink allocation; gift drink is 0 ₸, every physical container is charged. The first normal-size control is visible above the cart action. Larger text scrolls; it is not shrunk to match an unrelated simple-product frame.
- Order names occupy the full text width above price/quantity; a real long-name 30318 order was reviewed after the final fix. Unresolved payment hides Pay/Repeat and exposes refresh, including at 320 px/2×. Missing backend values remain unknown rather than synthetic customer/order metadata.
- Card success uses black text on green. Unavailable bonus/history data is an error/unknown state, not a fake zero balance or QR. Unsupported scanner, notification-count and fixed “25%” decorations were removed.
- Widget captures lack system fallback for `№`; the fresh release browser with fallback fonts rendered the actual order title correctly. Initial blocked-font/cached-bundle observations are not counted as final visual proof.
- Official Kaspi SVGs preserve their geometry/colors; the compact action stays intact at 160 × 52 inside an accessible full-width hit-area. Selection uses compact artwork plus the Gold badge; progress/unknown/error use full logos with suitable theme contrast. Normal text still scales. Actual 320 px/2× uncertainty dialog and 320/375/800 resizing were reviewed; direct URL fixtures use one app navigator so dialog text inherits the fixture scaler instead of escaping to a differently scaled outer gallery route.

Capture-only IDs (both themes): `promotion`, `onboarding`, `payment_method`, `payment_kaspi`, `checkout_error`, `product_options`, `product_pour`, `product_pour_real`, `product_pour_gift`, `product_pour_three_plus_one`, `product_pour_fractional`, `product_replacement`, `notifications`, `profile_setup`, `startup`, `active_route`. Notification preferences are not the Figma inbox. Gift packing/tariff follows the explicit user policy and is exercised through synthetic create/repeat, not a production transaction. The official Kaspi component is sourced/reviewed independently; there is no exact app-screen Figma baseline for the mixed payment screen.

Final tracked release smoke at 375 × 812 / DPR 2 operated intro → city onboarding with production mutation guards. The final city's preflight was blocked; retry and disabled continuation were observed, not a successful final public cities GET. An earlier read-only cities observation is historical. Synthetic journeys establish client transitions separately, not authenticated production, real bank/OS lifecycle or bank certification. Official presentation review is source-linked, not inferred from a pixel score.

### Kaspi rule trace

Source: [Russian web guide `6199:59680`](https://www.figma.com/design/pNQjZoaE1v2Ud2cpqtU4sq?node-id=6199-59680), version `2316344552721705817`, last modified 2025-08-27. Russian and Kazakh guides were read; the active app language remains Russian.

| Guide nodes | Applied presentation |
|---|---|
| `6199:59691`, `6199:59695`, `6199:60135` | Official SVGs; full logos 112 × 28; compact mark beside Kaspi.kz name plus Gold; no unsupported Red/Kredit products |
| `6199:60299`, `6199:60336`, `6199:60371` | Logo clear space at least 20% of height; no recoloring, altered internal objects, radius or logo effects |
| `6199:60489`, `6199:60588` | Intact official red compact payment-button artwork, not a redrawn prefix/logo or invented brand-colored generic button |
| `6199:61045`, `6199:61115`, `6199:61154` | Kaspi first in method selection; one selected charge action; full-width hit-area, 52 ≥ 48 px high, at least 8 px surrounding clearance |
| `6199:61231`, `6199:61259`, `6199:61280`, `6199:61284`, `6199:61288`, `6199:61293` | Internal button objects remain in their official positions; one exact color/style, only for payment; unknown/completed uses neutral state controls instead of recolored/reflowed brand buttons |


## Historical measurements — 2026-09-22

The results below are retained historical measurements, not current app acceptance. The user's reported readability/home defects superseded their earlier quality conclusion. The historical commands were:

```bash
dart run tool/figma_spec.dart png --page "Design System (Dark)"   # exports the frames
flutter test .figma_cache/home_reference_test.dart                 # renders the rebuilt home
flutter test .figma_cache/design_diff_test.dart                    # diffs dark + light
flutter test .figma_cache/card_diff_test.dart                      # diffs the card grid
```

### Historical method

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

### Historical results

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

### Historical deviations

| Bucket | Detail |
|---|---|
| Removed by request | The full-width bottom bar behind the cart button |
| Glyphs Figma won't export | `Store_Icon_UIA` (same-family shop glyph used), the search field's scan glyph (drawn as five bars), `vuesax/bold/heart` (Material's filled heart on search rows) |
| Design inconsistency | The saving line «Выгода 1317 ₸» has no thousands separator while prices do; one formatter (NBSP) is used for both |
| Design editing artifacts | A grid card with duplicated stepper nodes at identical coordinates; a promo panel whose artwork bleeds outside its rounded box |
| Undesigned states | Empty cart, category-with-no-items, and most error states — the design defines an error only for FAQ |

### Historical coverage boundary

Measured today: the home screen (both themes) and the product-card grid. **Still unmeasured:** the
catalogue screens, product detail, cart, orders, profile, bonuses, certificates, intro slides and
search.

They are not unmeasurable — the pattern is the same three steps per screen: export its frame
(`tool/figma_spec.dart png`), render the rebuilt screen in a throwaway harness, diff with the crop
offsets. What each one needs is a harness that reproduces the screen's data as fixtures, which for
data-driven screens means freezing a sample response. That is the work, and it is deliberately left
to whoever picks this up rather than faked with a number.
