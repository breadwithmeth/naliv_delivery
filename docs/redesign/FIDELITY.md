# Fidelity report — redesigned screens vs the Figma file

## Current measurements — 2026-10-02

The readability remediation, clarified gift/Kaspi follow-up and catalog/card balance correction are implemented and reviewed in strict fixtures. This is **not pixel-parity or authenticated-production acceptance**. Compact readable browsing supersedes the former catalog/card visual conclusions; gift packing and official Kaspi artwork remain unchanged. See `PLAN.md` and the current gate in `STATUS.md`.

The 2026-10-04 cleanup re-exercised light active home/search/cart, dark cart with 1.6× inherited text and real wheel scrolling, a native paid-order fixture journey, and tracked intro/city onboarding. It did **not** rerun the full Figma sweep: numbers below remain dated 2026-10-02. Current **226 host cases / one native e2e**, release footprint and limitations are recorded in `../CLEANUP_PLAN.md` and `STATUS.md`; run commands/test categories are in the root README.

### Method and scope

- The final `dart run tool/verify_surface.dart all --theme both` completed **82 captures** for **41 surfaces**, at **375 × 812 logical / DPR 2 = 750 × 1624 pixels**, and **50 applicable frame comparisons**. Sixteen surfaces per theme have no exact app frame and are capture-only.
- Current metric: for each app pixel, take `max(abs(ΔR), abs(ΔG), abs(ΔB))`; report its mean out of 255 and the percentage above 32. Only the simulated **48 px top / 34 px bottom** logical insets are excluded. This is not the historical masked-artwork/channel-average measurement.
- `tool/design/surface_compare_test.dart` has **no golden threshold**. Passing means the captures/references had valid dimensions and measurement completed, not that the residual is acceptable.
- The removed throwaway probe passed **882** render/strict-request cases across all 41 surfaces, 320/375/800, 1×/1.6×/2× and both themes, with 300 px keyboard insets for 12 relevant surfaces at the larger scales. A render pass alone does not prove usable interactions.
- Catalog correction additionally passed **306 disposable render/state cases** over the shared-card consumers and price/quantity/stock boundaries. Actual release-browser screenshots reviewed catalog, selected quantities, complete grids and wheel-scrolled photo/unavailable states at 320/375/800 widths, 1×/1.6×/2× and both themes. These are variations of the existing strict `DesignSurfaceApp`, not authenticated API fixtures or new golden baselines.

### Current diagnostic results

| Surface | Dark mean Δ /255 | Dark pixels >32 | Light mean Δ /255 | Light pixels >32 |
|---|---:|---:|---:|---:|
| home | 67.47 | 51.02% | 97.83 | 43.23% |
| catalog | 86.42 | 47.77% | 75.82 | 35.77% |
| all_products | 94.05 | 47.38% | 41.57 | 22.67% |
| cart | 76.92 | 35.18% | 44.85 | 31.30% |
| profile | 15.66 | 8.61% | 14.51 | 8.22% |
| profile_guest | 23.66 | 11.92% | 22.23 | 11.26% |
| orders | 12.42 | 3.85% | 10.54 | 4.33% |
| order_detail | 23.56 | 12.86% | 19.44 | 11.09% |
| support | 18.98 | 8.43% | 18.50 | 8.20% |
| certificates | 14.25 | 7.02% | 13.93 | 7.50% |
| addresses | 14.40 | 9.54% | 14.19 | 8.57% |
| address_map | 97.21 | 43.07% | 42.62 | 53.58% |
| address_details | 13.84 | 9.83% | 13.63 | 9.67% |
| cards | 20.64 | 14.83% | 21.53 | 28.24% |
| checkout_delivery | 31.39 | 24.24% | 29.05 | 21.87% |
| checkout_pickup | 33.89 | 22.66% | 32.24 | 23.71% |
| certificate_purchase | 27.76 | 20.21% | 55.34 | 36.00% |
| payment_success | 13.92 | 10.24% | 13.62 | 10.22% |
| search | 26.67 | 37.35% | 19.23 | 24.05% |
| favorites | 5.56 | 3.30% | 5.53 | 3.32% |
| bonus_history | 14.41 | 5.76% | 13.03 | 6.12% |
| bonus_explainer | 27.22 | 13.67% | 25.70 | 13.58% |
| faq | 28.78 | 9.42% | 23.70 | 9.44% |
| intro | 15.84 | 12.00% | 17.00 | 12.26% |
| sign_in | 51.99 | 50.32% | 39.91 | 17.66% |

Home/catalog/cart/map residuals are large; these figures must not be described as a pixel match or explained away as font antialiasing. Fixtures use synthetic names, missing product/category artwork and synthetic map tiles, while readable layout deliberately changes tiny metadata and columns. The measurements do not isolate the contribution of each difference.

### Visual review and deliberate departures

- The previous 39 dark/light baselines were reviewed in contact sheets. Added Kaspi and 3+1 surfaces were reviewed full-size in both themes; gift cart/configuration, checkout and created-order detail received actual browser review. Critical journeys and exact price observations are recorded separately in `STATUS.md`.
- Body/actions use 16 px, secondary text 14 px, auxiliary text at least 12 px; text scaling is not clamped. Cards/rows grow and grids use fewer columns rather than reproducing unreadable 6–10 px metadata. Home has two category columns at the 375 px/1× reference, adapting to one at narrow/large text and up to three at wider widths.
- Catalog/card balance deliberately departs from the lead illustration and tiny dense reference metadata: 96 px maximum artwork, prices immediately following readable names/metadata, a 44 px add tile and quiet selected stepper. Normal card heights are 255 px, or 271 px for datasets with an old-price row; the mixed grid grows to 324/360 px at 1.6×/2×. Full lists use 2/1/1 columns at phone widths and 4/3/3 at 800 px for the three reviewed scales. Overview previews are bounded to two rows; “Все” and page-two continuation retain the complete list. Wrapping prices/status take priority over artwork, not text size. Muted fallback art and real captured photography were reviewed separately; the baseline captures still use synthetic missing-art items.
- The logo is static; no drawer/bottom tab strip. Header actions remain reachable, with floating cart-only navigation and scroll clearance. Store/search/campaign/bonus content participates in adaptive flow. Production uses real insets, not a simulated Figma status bar.
- One product-card implementation serves grids/strips. Configuration shows explicit paid selections, all physical bottle counts, paid/free drink quantities and shared price breakdowns. Gift litres add ordinary fully charged bottles; the cart counter shows total physical litres. There is no borrowed simple-product frame for this undesigned configuration.
- Order names occupy the full text width above price/quantity; a real long-name 30318 order was reviewed after the final fix. Unresolved payment hides Pay/Repeat and exposes refresh, including at 320 px/2×. Missing backend values remain unknown rather than synthetic customer/order metadata.
- Card success uses black text on green. Unavailable bonus/history data is an error/unknown state, not a fake zero balance or QR. Unsupported scanner, notification-count and fixed “25%” decorations were removed.
- Widget captures lack system fallback for `№`; the fresh release browser with fallback fonts rendered the actual order title correctly. Initial blocked-font/cached-bundle observations are not counted as final visual proof.
- Official Kaspi SVGs preserve their geometry/colors; the compact action stays intact at 160 × 52 inside an accessible full-width hit-area. Selection uses compact artwork plus the Gold badge; progress/unknown/error use full logos with suitable theme contrast. Normal text still scales. Actual 320 px/2× uncertainty dialog and 320/375/800 resizing were reviewed; direct URL fixtures use one app navigator so dialog text inherits the fixture scaler instead of escaping to a differently scaled outer gallery route.

Capture-only IDs (both themes): `promotion`, `onboarding`, `payment_method`, `payment_kaspi`, `checkout_error`, `product_options`, `product_pour`, `product_pour_real`, `product_pour_gift`, `product_pour_three_plus_one`, `product_pour_fractional`, `product_replacement`, `notifications`, `profile_setup`, `startup`, `active_route`. Notification preferences are not the Figma inbox. Gift packing/tariff follows the explicit user policy and is exercised through synthetic create/repeat, not a production transaction. The official Kaspi component is sourced/reviewed independently; there is no exact app-screen Figma baseline for the mixed payment screen.

Fresh tracked release smoke at 375 × 812 / DPR 2 reached intro → real city onboarding using a read-only public cities GET. Synthetic fixtures do not establish authenticated production, real bank/OS lifecycle or bank certification. Official presentation review is source-linked, not inferred from a pixel score.

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
