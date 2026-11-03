# Redesign — status, decisions and open questions

Living document for the Градусы24 → Figma redesign. It exists so the work can continue without
its original author in the loop: **every question that needs a human answer is listed below with
the default I am proceeding on**, so nothing blocks unnecessarily, and nothing gets decided
silently either.

Last updated: 2026-11-03. Current source release: **1.2.116+12116**. The latest Figma composition restoration is recorded first below; the earlier correctness release and its APK evidence are historical. Client corrections F1–F11, dark/light themes, inherited text scaling, floating cart-only navigation and genuine glass remain preserved. Physical Huawei/S25 Ultra, Apple-native glass, bank, loyalty-policy, 1C reversal and signed-device push acceptance remain external prerequisites. The clarified gift-container charging policy and `docs/kaspi.txt` remain unchanged.

---
## Current remediation gate
### Plain headers and declutter — 2026-11-04

- **Headers.** No blur: the page colour sits solid behind the status bar and title and fades to
  transparent 36 px below (`header-scrim`). Glass stays only on the bottom bar and round buttons.
- **Checkout.** «Изменить адрес» opens the map and returns straight to checkout; entrance, floor
  and flat stay inline. Removed the store city chip, the pickup note, the inline FAQ panel and
  the «Далее — выбор оплаты» caption (a caption shows only when something blocks the order).
- **Help.** Always-shown FAQ boxes on checkout, payment, cards, addresses and support became one
  «?» disc in the header. The FAQ panel stays only on the payment failure notice.
- **Removed as redundant.** OTP «Вставить код» (paste works in the field and through autofill)
  and the «Код отправлен» snackbar; «Карта» under every saved card; «Чат поддержки» under the
  support name (only connection problems show); «Ещё не в корзине» on the product page;
  «Из аккаунта / На этом устройстве» on addresses (the selected one still says «Для доставки»);
  home bonus and bell icons (the bonus card and Profile → «Уведомления» cover them).
- **Notifications.** Titled «Уведомления»; dropped the intro text, the subscription-ID
  diagnostic and the support link with its footnote.
- **Bottling.** Once a gift exists the hint reads «До следующего подарка: X».

### One frosted material, payment, OTP, settings and bonus QR — 2026-11-04

- **One material.** `lib/ui/frosted_surface.dart` (`Frost`, `FrostedSurface`, `FrostedScope`,
  `FrostedHeaderLayout`) is shared by the bottom dock, the new scroll-frosted headers (status
  bar included, the design's dark header with opacity), glass back/search/like discs,
  certificate fields, the support composer and the search pill. Header controls are scoped so
  nothing blurs twice.
- **Cart.** `AppCartButton` is the design's 78 px stamp; with items a pill with the total emerges
  from behind it and a brand-red count badge sits on the stamp. The search page uses the same
  control (its Figma variant is wrong and was not adopted).
- **Payment.** The page sits on `FrostedDock` with one strong full-width pay action; cards scroll
  under the bar, and the list ends at the measured bar height. Kaspi and cards share one row
  anatomy, with the full Kaspi logo and Gold. Every Kaspi failure path has its own
  `PaymentNoticePage`. «Попробовать снова» appears only after a settled refusal; uncertain
  states offer «Проверить оплату» / «Открыть оплату» and never a second charge. Card masks wrap
  only between groups.
- **OTP.** Six boxes in two groups of three, driven by one real `TextField` with
  `oneTimeCode` autofill. It handles paste of any formatted code and an explicit «Вставить код»
  (clipboard read only on tap), auto-submits once, and on a wrong code shakes, shows an inline
  error and retries.
- **Settings.** Grouped sections, a Светлая / Тёмная / Авто theme choice, an explained
  data-collection toggle, notifications reachable from the profile, and logout separated.
- **Bonus QR.** Tapping the QR opens a fullscreen black-on-white code over a blurred scrim,
  with a hero transition and dismiss by close, tap, swipe or Esc.
- **Fix found in review.** Login notices overrode the snackbar background, which left white
  text on light grey in light theme. They now use the theme notice, and raw exception text is
  no longer shown.
- Gate: 700 tests, clean analysis, Windows shopping journey, fixture and tracked web rebuilt.
  Evidence: `.figma_cache/render/round/`.


### Strict Kaspi.kz guideline compliance — 2026-11-03

Audited the app against Kaspi's «Оплата с Kaspi.kz | Компоненты и правила» file
(`pNQjZoaE1v2Ud2cpqtU4sq`, rules frame `6192:46527`). Two violations fixed:
- the full-width pay button was the stretched hug-width compact button; it is now the official
  «Button / Gold»;
- the button's internal white wordmark was used as a standalone logo on dark screens; dark
  screens now use the official white-plate logo.

The Gold badge moved to the trailing edge of the Kaspi list row, as in Kaspi's list example. Payment
states now follow Kaspi's recommended process: red loader, «Подтвердите оплату в приложении»,
«Оплата принята» + amount, «Отмена покупки», «Ошибка». Full trace in `FIDELITY.md`.

Evidence: 646 tests, clean analysis, Windows shopping journey; fixture captures at
375 px both themes and 320 px / 2× text, plus a live tap through the loader to «Оплата принята»
(`.figma_cache/kaspi/final_*`, `final2_*`). No real Kaspi payment was made.

### Saved bank cards were silently dropped — 2026-11-03

- **Cause** (live read with the owner's account, read-only GETs): `GET /user/cards?source=halyk`
  returns masks as six BIN digits, an ASCII ellipsis and the last four (`400000...1234`).
  `SavedCard.safeMask` accepted only `*•xX` masking, so every card was rejected and the
  page showed no usable card.
- **Fix:** ellipsis runs are normalised to `••••` before the existing safety checks (digit
  limits and PAN rejection unchanged). Regression in `saved_card_api_test.dart` failed before
  the fix. The live response now parses to 5 of 5 chargeable cards and the cards page lists them.
- **Server inconsistency, not changed:** `/auth/full-info` lists 3 cards for the same account
  while the Halyk endpoint lists 5, so the profile row summary («3 карты») differs from the
  cards page. No card was added, removed or charged during the check.

### Smoothness, frosted bar and motion — 2026-11-03

- **Frosted bar.** The liquid-glass shader (per-frame page snapshot, Gaussian pre-blur, fragment
  shader, native `UIGlassEffect` view) is removed with `flutter_shaders`. `FrostedDock`
  (`lib/ui/frosted_dock.dart`) is one `BackdropFilter` blur over the bar only, a theme tint and a
  hairline, X/YouTube-style; high contrast gets an opaque bar.
- **Rebuilds and layout.** Page-level cart watches became scoped selectors; product cards no
  longer lay out text per card (`TextWidthCache`), drop `Opacity`/clip layers; rails and the cart
  list are lazy; home is a `CustomScrollView`; images decode at display size.
- **Measured** (tracked release, live catalogue, headless Chromium wheel scroll, frames > 25 ms):
  home 42–45 → 1–2 of ~300; catalogue 66–68 → 0; p90 27.9 → 7.1 ms, both themes, with motion on.
- **Motion** (`lib/design/motion.dart`, `lib/ui/motion_widgets.dart`, all zero under reduced
  motion): add pill ↔ stepper swap, direction-aware count slide (cards, cart, product), cart badge
  bump and total slide, press scale on cards/home tiles, heart pop, chip colour, checkout sliding
  thumb, bottling bonus/gift appear, image fade-in. Reviewed frame-by-frame at 0–400 ms; that
  review caught a zero-height checkout thumb (selected mode invisible), fixed before release.

### Draft-beer bottling: pick physical litres — 2026-11-03

- **One rule.** The customer picks physical bottles; a `3+1` promotion means exactly 4 l, with the
  4th litre an optional bonus. Gift = `floor(T / (base + add)) × add`, paid = `T − gift`, every
  physical container is charged at its ordinary tariff (policy unchanged), stock is checked against
  `T`, and the order payload keeps one row per physical bottle variant (`amount` = litres).
- **Configurator.** Hero, title, litre price, one bottles list (name/volume · «тара 100 ₸» ·
  stepper). One compact line above the total: «4 л · 4 бутылки», a «1 л в подарок» badge, and either
  the one-tap «+1 л в подарок» (adds the matching bottle, preferring the size already picked most) or
  the hint «До подарка: X л». The paid/gift split, per-bottle allocation text and price-composition
  paragraphs are removed; the whole-bottle gift refusal is gone.
- **Cart/checkout/repeat.** Cart row: litres, `4× 1 л`, short «1 л в подарок» chip; checkout: one gift
  line and one «Тара» total. Cart stepper repeats the whole physical set; repeat order maps fulfilled
  amounts directly. Carts saved by earlier builds (paid litres + retained gift bottles) migrate on
  restore to the same bottles (`version: 2` state, `giftBottleCounts` dropped).
- **Evidence.** Rewritten tests: `product_detail_bottling_test`, `bottling_contract_test` (incl. legacy
  migration), `cart_evaluation/projection/gifts`, `repeat_order_service`, `promotion_engine` (physical
  gift). Not yet run by the author of this change; the integrating run is the evidence.

### Store-city checkout, address flow, grouped catalogue and kitchen gating — 2026-11-02

- **Address city follows the store.** `lib/services/store_city.dart` resolves the
  selected store's city from `city_id` (address text as fallback). Checkout passes
  that city and the store's coordinates to the address picker; search, reverse
  lookup and the map centre use them instead of the onboarding/location city. An
  address with a known different city shows «Адрес в другом городе» with a
  «Выбрать адрес в г. X» action and blocks order creation and quoting; an unknown
  city is not blocked. Profile address editing keeps the onboarding city.
- **Checkout and address UI.** Segmented delivery/pickup control; store card with
  city chip; address card with the street as heading and the city line; grouped
  details form (Подъезд/Этаж/Квартира + an editable «Комментарий курьеру», sent in
  the existing `extra` field); unified status rows. Map page: city-scoped search
  pill, centred pin, bottom card with a pinned confirm and a separate retry
  action; device location outside the store city is explained. Details and search
  pages redesigned to match.
- **Catalogue.** Supercategory pages show one section per parent category (Вино,
  Пиво баночное и бутылочное, Пиво разливное …) with child chips and a preview
  rail; tabs list parents only; the sheet groups children under parents; the
  category page offers «Все» + child chips. The old flat leaf list and its
  red featured panel are removed.
- **Kitchen.** `lib/core/kitchen_policy.dart`: supercategory 7 «Кухня» (category
  tree registered from the API, seed 237) is available only at store 11
  (Бухар-Жырау 70). Elsewhere it is filtered from home, catalogue, search,
  favourites, promotions and recommendations, refused at cart ingress, dropped on
  cart restore and skipped in repeat orders.
- Live read-only check: Темиртау (store 9) home/search show no kitchen; store 11
  still shows it; Слабоалкогольные напитки reads as grouped parents.
- Gate: 638 tests, clean analysis, Windows shopping journey, fixture and tracked web
  rebuilt. Evidence: `.figma_cache/render/probe/compare_checkout_address.png`,
  `compare_catalog_kitchen.png`, `after_*`, `final_*`.

### Card, cart control and add-to-cart follow-up — 2026-11-02

- Product cards: larger contained artwork, «объём · страна» meta, and a quiet
  raised add pill (orange «+», «В корзину» when it fits); only items already in
  the cart show the solid orange stepper.
- Cart control (superseded 2026-11-03): always the 78 px scalloped stamp, 27 px above
  the bar; with items an orange glass pill with the total grows out from behind it and a
  32 px `brandRed` count badge sits on its top-left, stamp and pill centred together
  (Figma «Главная - Скролл ниже 1»). The Figma search variant is intentionally not used.
- Notifications float above the cart dock (theme `insetPadding`); dark notices
  get a hairline border.
- Product page: «В корзину» adds the first step, confirms with «Добавлено», then
  becomes «Перейти в корзину» with «В корзине: N шт» — repeated presses open the
  cart instead of silently re-confirming. Regression in `catalog_flow_test.dart`.
- Gate: 604 tests, clean analysis, Windows shopping journey, tracked web rebuilt;
  real-catalogue captures `real_v5_*`, `real_v6_*`, fixture `v5_snack_*`.

### Real-catalogue visual rework — 2026-11-02

The single-name fixture hid the real problems. The tracked release was rendered
against the live public catalogue (store 11, read-only GETs; any write request
blocked) at 375 × 812 / DPR 2 in both themes. Long product names produced 5–6 line
cards, ragged rows and misaligned prices; cart names wrapped in a 90 px column; the
featured rail left dead red space; the floating dock blur was grainy.

- `ProductCard`/`ProductGrid`/`ProductRail`: Figma card anatomy with 2-line names,
  one meta line, bottom-pinned price and a 32 px solid-orange CTA with white glyphs
  inside a 44 px hit area. Rows and rails use one computed extent, so prices and
  actions align; single-item rails start at the left.
- Catalogue hierarchy: a supercategory shows one section per parent category (header
  with «Все», a child chip row, a product rail ending in a card-styled «Все товары»);
  tabs name parents and scroll to them, the sheet groups children under parents, and
  the products page filters a parent by «Все» + child chips with the parent as context.
- Cart/search rows clamp names to two lines and move price/stepper to a second
  line at phone widths. Steppers share the solid accent.
- Product page: badges beside the title, spec chips instead of a repeated
  category line, a raised stepper card that shows the step to be added, and no
  placeholder-only descriptions.
- `LiquidGlassDock`: full-bleed bar with top radius 20 like Figma; the frost is a
  Gaussian pre-blur of the bar crop sampled by the existing refraction shader
  (no stochastic per-pixel disc), so the grain is gone. Clearance follows the bar.

Evidence: `.figma_cache/render/probe/real_*.png` (before), `real_v2_*`, `real_v3_*`,
`real_v4_*` (after) and `real_compare_*.png`; fixture-only surfaces in
`fidelity_v3_*`. Final gate on this source: **603 tests passed**, analysis of
`lib test integration_test tool` clean, strict Windows shopping journey passed,
tracked `build/web` rebuilt. Physical-phone glass performance is not measured.

### Figma composition restoration — 2026-11-02

Implemented against the supplied Figma file rather than the October intentional
layout departures. The active routes retain their existing services, ownership
guards and real financial/product data.

- Restored home spacing/kitchen height, category-title navigation, the featured
  rail and three-column compact catalogue. Added compact photo badges and larger
  cart recommendations without removing full detail or stock/configuration controls.
- Reworked cart/checkout density, profile identity and full address, authentication
  artwork, bottom-aligned map confirmation, address/order/certificate/bonus rows,
  FAQ filtering, top-row search and centered Favorites.
- Preserved inherited scaling and reachable controls. Large-text headings use the
  full width; compact catalogue falls back to a grid. The keyboard checkout header
  scrolls with the form instead of consuming its gesture area.
- Live interaction exposed merged favorite semantics and unreadable light-theme
  storage feedback. Favorite actions now own an isolated semantic node; inverse
  feedback uses its matching foreground rather than normal black body text.

Visual evidence:

- **111 reviewed fixture captures:** 42 surfaces in both themes at 375 × 812 /
  DPR 2, 19 compact 320 px / 2× text cases including keyboard-300, and eight
  768/1280 px home/cart captures. No recorded page/console errors or unexpected
  network requests. The canonical layout captures precede the final feedback-only
  color correction; its actual warning state is verified separately.
- Before/Figma/after panels cover home, catalogue, all products, cart and profile.
  The web fixture embeds exported product art offline; baseline image placeholders
  differ, so image improvement is not attributed solely to layout.
- Actual browser actions exercised category selection → product → quantity/add;
  loaded search, favorite add/remove through semantics, and the 13,170 ₸ cart;
  FAQ filtering; map-panel scrolling/confirmation; and entrance `12` in dark
  320 px / 2× / keyboard-300 checkout. Favorite persistence refusal remains
  explicit; this is not a claim of durable fixture storage.

Evidence: `.figma_cache/render/probe/fidelity_final.json`,
`fidelity_diagnostics.json`, `fidelity_interactions.json`,
`fidelity_comparison_*.png`, `fidelity_map_compact_confirm.png`,
`fidelity_checkout_compact_entrance.png`, and `fidelity_search_loaded_*.png`.
The synthetic data, gift rows, missing category artwork and genuine glass grain
remain documented differences in [`FIDELITY.md`](FIDELITY.md), not pixel parity.
No production SMS, address/card mutations, orders or payments were performed.

Final settled-source gate:

- **603 retained tests passed**, including both-theme feedback contrast regressions;
  `dart analyze lib test integration_test tool`: **no issues**.
- Fresh LCOV: **15,791 / 18,831 = 83.86%**, 107 source records.
- Strict Windows shopping journey passed through active home/catalogue, product/cart,
  fixture authentication, pickup checkout, saved-card payment and paid history.
- Strict release fixture and tracked `build/web` rebuilt successfully after the
  final feedback correction. Production-bundle home rendered in both persisted
  themes at 375 × 812 / DPR 2 using exactly five known synthetic GETs per run,
  zero unknown requests/mutations, and no page/console errors.
- Final light/dark warning screenshots confirm readable feedback after actual
  favorite changes. Semantic add/remove was operated separately, and cart quantity
  remained independent. No physical-phone, Apple-native, real-bank or deployed
  service-worker acceptance is inferred.
- This design pass updates source and tracked web output; it does not rebuild the
  earlier Android APK artifacts or change package/signing/version identities.

Commands: `dart run tool/design_harness.dart check --full --native`,
`dart run tool/design_harness.dart build`, and
`dart run tool/design_harness.dart build --tracked`.
Final logs: `.figma_cache/harness/runs/2026-11-02T02-49-50.736638Z_21744.log`,
`2026-11-02T02-55-43.321458Z_14940.log`, and
`2026-11-02T02-56-30.217570Z_6708.log`.
Additional evidence: `fidelity_coverage.json`, `fidelity_production.json`,
`fidelity_production_*.png`, and `fidelity_feedback_*.png` under the probe directory.

### App-wide correctness, ownership and performance — 2026-11-02

This pass covers the active feature routes and still-reachable legacy destinations,
not a framework rewrite. It preserves backend contracts, physical-bottle pricing,
signing identity, package ID, minSdk and renderer choices; no dependency upgrades or
production account mutations were performed.

- **Identity/private data:** credentials publish only after checked persistence.
  Captured token/revision ownership rejects late prior-account results and cleanup.
  Optional push initialization/login can retry without holding local login/logout.
  Card reauthentication still requires its own successful login/profile return.
- **Cart/repeat:** durability status is separate from content revisions. Checkout
  requires the latest saved revision. Corrupt saved bytes remain intact until explicit
  reload or confirmed durable discard; failed repeat-address persistence is a partial
  result, not a claimed atomic restoration.
- **Financial flows:** account-owned intent persists before POST. Storage refusal
  sends nothing; timeout, parsing and 5xx uncertainty survives route/app recreation.
  Existing read/status recovery never becomes a blind second order or charge.
- **Browse/address:** query and map-intent generations reject stale completions.
  Favorites reconcile membership with session ownership. Failed address drafts retain
  retry/discard; malformed records do not poison valid records, and canonical labels
  remain distinct from display details.
- **Structure/performance:** catalogue DTOs and JSON normalization are separated from
  HTTP transport; obsolete wrappers/re-exports are removed. Pricing is operation-scoped,
  catalogue quantity reads are indexed by precomputed structural keys, exact bottle
  allocation avoids target-sized arrays, subscriptions are narrow and image decoding
  follows physical display geometry. Timings, image sizes and rebuild counts are in
  [`CLEANUP_PLAN.md`](../CLEANUP_PLAN.md#measured-implementation-evidence).
- **Harness/rendering:** fixture publication/serve lifetime is lock-owned and fixture
  HTML cannot initialize production push. Glass/shadow use premultiplied compositing;
  the paired orientation probe initializes every application uniform, retaining the
  tiny read-back and genuine scene response rather than an opaque substitute.
- **Global recovery usability:** compact error notices scroll independently and retain
  a usable focused form at 320 px / 2× text / 300 px keyboard. Navigator semantics are
  isolated so modal routes cannot prune the global recovery actions. The reachable-tree
  regression failed before correction, then opened confirmation through a semantic tap;
  cancellation and rejected storage preserve original bytes and typed input.

Visual and interaction evidence:

- **72 release-fixture captures:** 28 surfaces in both themes at 375 × 812 / DPR 2,
  four compact large-text/keyboard states, and home/cart at 768 and 1280 px in both
  themes. All images were inspected. No page/console errors, DOM horizontal overflow
  or application API/push network requests were recorded. These normal-state captures
  precede the final error-only notice corrections; they do not prove authenticated
  production behavior.
- Actual fixture interactions exercised search `Aperol`, add/quantity updates,
  favorite removal state and cart totals (**13,170 ₸ / +395 bonuses**), payment-method
  scrolling clear of the footer, and the compact profile form's remaining controls.
- Actual Windows renderer orientation suite: **2 passed**. Source is unchanged since
  that run. Apple-native composition and physical-phone rendering are not inferred.

Final integration/release gate:

- Full serial retained suite: **601 passed**; analysis of `lib test integration_test tool`:
  **no issues**. Fresh LCOV: **15,474 / 18,494 = 83.67%**, 107 source records.
- Strict Windows shopping journey passed through active authentication/home, store,
  product/cart, fixture OTP, pickup checkout, saved-card payment and paid history.
  No unexpected requests/native HTTP escapes were accepted.
- Tracked production web and universal/three-ABI release APK builds passed after the
  final semantic correction. All APKs retain package `kz.gradusy24.app`, minSdk **24**
  and the established signer; all three existing `FIXED-*` copies are hash-matched.

| APK | Version code | Size (MiB) |
|---|---:|---:|
| Universal | 12116 | 78.38 |
| ARMv7 | 13116 | 32.42 |
| ARM64 | 14116 | 34.65 |
| x86_64 | 16116 | 36.08 |

Use the same ABI for an installed split update; universal code 12116 is lower than the
split codes. Do not uninstall or discard user data to work around a downgrade.
Universal SHA-256: `a44fa8a8246b07ac504bc6f53b8fd96823ce6656fe0967d44b241ce61c948c27`.

- Final production-bundle guest home rendered in both actual persisted themes at
  375 × 812 / DPR 2: **5 GET / 0 OPTIONS** per navigation, versus old **5 GET / 5 OPTIONS**.
  Strict interception fulfilled only known synthetic reads; no page/console errors.
- Final 320 px corrupt-cart startup exposes both recovery actions in the accessibility
  tree. Light-theme cancellation preserves unread bytes; confirmed checked clear,
  home retry and reload restore and retain `{business_id: 1, items: []}`.
  The complete recovery journey made **13 known synthetic GETs**, no unknown API
  requests or mutations, and had no page/console errors. Fresh screenshots were inspected.
- The external APK build's generated Java change was limited back to the user's
  existing splash block; no whole-file generated-plugin rollback was applied.
  Temporary probes were removed; owned tabs/web services and Gradle were stopped.

Physical Huawei/S25 Ultra, Apple-native composition, handset permissions/GPS, real bank
or push, authenticated production, Linux Docker/deployment and deployed service-worker
acceptance remain unverified. The checks above are not exhaustive edge-case proof.

Evidence: `.figma_cache/render/probe/quality116_fixtures_verified.json`,
`quality116_interactions.json`, `quality116_compact_recovery.png`,
`quality116_rgba_before.json`, `quality116_rgba_initialized.json`,
`quality116_production_final.json`, `quality116_coverage.json` and `quality116_apks.json`.

### Reliability and static delivery follow-up — 2026-10-30

Release **1.2.115+12115** supersedes the 1.2.114 outputs described below. This pass
does not redesign the UI, change rendering backends, upgrade dependencies or perform
production account/provider mutations.

- **Session-refresh isolation:** `AuthenticationWrapper._checkAuth` previously shared
  one pending account read across different tokens. A replacement session could not
  refresh until the previous request finished; ending a session likewise left the
  guest home waiting. Both failures were reproduced in
  `test/integration/authentication_refresh_test.dart`. Refreshes are now coalesced
  only for the same token, with a request generation and token/ending-session checks
  before and after identity binding. An old completion cannot publish account state
  or clear the replacement session's pending read. Existing HTTP requests are not
  force-cancelled; their stale results are ignored.
- **Reserved HTTP paths:** real Nginx returned app HTML/200 for four missing association
  or nested legacy-worker paths. `nginx.conf` now excludes those reserved prefixes
  from SPA fallback. Known association JSON, worker JavaScript, their no-cache headers
  and ordinary app-route fallback remain intact. Five missing-path checks now return
  404; fourteen final checks passed against the actual release web root.
- **Static transfer optimization:** gzip is enabled for compressible static types from
  1 KiB, with `Vary: Accept-Encoding`; release cache headers are unchanged. On the
  rebuilt 1.2.115 `main.dart.js`, identity transfer was **4,882,480 bytes**, gzip
  **1,652,673 bytes** (**66.15% fewer payload bytes**). Decompression reproduced the
  exact uncompressed bundle. No network-latency or server-CPU improvement is claimed.

Verification:

- The two new session cases failed before the fix; both then passed, including repeated
  resume callbacks while the replacement read was pending. Together with existing
  home-flow checks: **4 focused tests passed**.
- Full `flutter test --coverage --concurrency=1 --no-pub --timeout=90s`:
  **382 passed**; LCOV regenerated. `dart analyze lib test integration_test tool`:
  **no issues**.
- Tracked web and universal/three-ABI production APK builds succeeded.
  `apksigner` verified every APK against the established signing identity; `aapt`
  confirmed package `kz.gradusy24.app`, version **1.2.115**, minSdk **24**, and codes
  **12115 / 13115 / 14115 / 16115** (universal / ARMv7 / ARM64 / x86_64).
  Existing `FIXED-*` copies were refreshed and hash-checked. Universal SHA-256:
  `dfcfe251db6ccebdf837c671d808c727e65cdb458fad2df48f542e2ae16c54ec`.
- The actual production web bundle was exercised through the corrected Nginx server:
  guest home at **375/768/1280 × 812, DPR 2**, both themes; cart opened its empty state
  at 375 px in dark mode. Six home captures and the cart capture were reviewed:
  upright page, readable controls and no horizontal overflow. Strict fixtures handled
  **42 GETs / 42 preflights**, with no unexpected API requests or page exceptions.
  OneSignal was deliberately blocked (one blocked-resource diagnostic per navigation);
  push delivery was not tested.
- A suspected visual sampling mismatch was checked with a disposable red/blue release
  probe, using the real `LiquidGlassDock` on CanvasKit. The page matched its direct
  reference and glass over the blue half was blue-dominant: center RGB **(6, 6, 180)**.
  No orientation defect reproduced; no extra shader/platform workaround was added.
  The disposable entry point/build were removed, retaining its PNG evidence.

Local HTTP proof used Nginx **1.30.6 / Windows**, substituting only loopback listen and
document root in the production server block. Linux Docker execution, deployment and
physical Huawei/S25 Ultra retesting remain unverified. The prior Huawei acceptance
limit still applies; this is not a new handset acceptance claim.

Evidence: `.figma_cache/harness/maintenance115_http.json`,
`.figma_cache/render/probe/maintenance115_web_smoke.json`,
`maintenance115_web_home_<theme>_<width>.png`, `maintenance115_web_cart_empty_dark.png`
and `maintenance115_color_probe.png`. Owned browser/server processes and the release
Gradle daemon were stopped after verification.

### Huawei orientation follow-up — 2026-10-30

Client ground truth: the home page remains inverted on an older supported **Huawei**;
the **Samsung S25 Ultra** is not affected. The Huawei model, Android/EMUI version and
actual renderer are not yet available. The only connected Android device is unauthorized;
no personal phone was inspected or modified.

**Backend hypothesis (Flutter 3.44.8 engine source; not read from either phone).**
`android_context_dynamic_impeller.cc` refuses automatic Vulkan selection when
`ro.com.google.clientidbase` is `android-huawei` (“AHB imports do not consistently
work”); `flutter_main.cc` starts automatic Impeller selection at API 29.
**[INFERENCE]** A matching Huawei on Android 10+ can therefore take Impeller OpenGL ES,
while a Vulkan-capable S25 Ultra can take Vulkan. Neither phone's actual renderer
is verified. On OpenGL ES, `TextureGLES::GetYCoordScale()` is `-1` for render-to-texture
images, and runtime-effect samplers do not receive the built-in image painter's
coordinate correction. Upstream describes the caller's responsibility
([flutter/flutter#169429](https://github.com/flutter/flutter/issues/169429)).
The available emulator reproduced this GLES orientation difference; Android below
API 29 normally takes Skia. **The reason the earlier correction failed on the Huawei
is not established.**

**Two concrete weaknesses were found and corrected.**

1. *The whole page went through the glass shader.* Any wrong orientation measurement
   turned the entire UI upside down. The page is now drawn by Flutter's own image painter
   (`drawImageRect`, upright on every renderer); the shader runs only over the glass and
   its 14 px shadow ring (`bounds.inflate(14)`, matching `distance > 14.0` in
   `liquid_glass.frag`). A wrong measurement can now at worst mirror what the glass
   refracts. Six surfaces (home/catalog/cart × dark/light) were captured before and after:
   **0 differing pixels** (max channel delta 0) on the host renderer.
2. *The measurement assumed the read-back's origin.* It inferred orientation from an
   absolute red/blue value in the first row returned by `Picture.toImage` /
   `toByteData`, so a reversed read-back reverses the decision. That counterexample is
   reproduced; it is **not proof that the Huawei takes that path**. At warm-up Flutter's
   normal image painter and the raw shader now draw the same two-row scene side by side
   into one **4 × 2** output and `sceneSamplerNeedsYFlip` compares corresponding rows
   (and rejects results where either patch lost its two distinct markers). A reversed
   read-back cannot change that relation. It is one 32-byte read-back at initialization,
   not a per-frame read-back, renderer switch, device-name check or rotation.

`LiquidGlassDock` also logs one line, `sampler needs a vertical flip: <bool>`, after the
measurement (`adb logcat -s flutter`; Impeller prints its chosen backend there too). If a
device still misbehaves, that pair of lines is the first thing to collect.

Retained regression coverage:

- `scene_sampler_orientation_test.dart`: upright/inverted sampler × top-down/bottom-up
  read-back (four decisions), plus an unrecognizable shader result and an
  indistinguishable reference. The old absolute decision failed both bottom-up cases and
  the ambiguous reference.
- `liquid_glass_orientation_test.dart` compares the page with an **unsampled Flutter
  reference in the same capture** and requires the glass over the blue band to refract
  blue, not the mirrored red. During development, a deliberately reversed calibration
  swapped the page rows before the structural fix; after it, the page stayed upright.
  Reversing the classifier decision then failed only the glass assertion, as intended;
  that source mutation was restored. The temporary `debugSceneFlipY` getter/setter and
  its forced-state test have been removed: no test-only rendering control ships.

Verification and release evidence:

- After removing the test-only switch: **7 focused checks passed**; full
  `flutter test --coverage --concurrency=1 --no-pub --timeout=90s`: **380 passed**.
  `dart analyze lib test integration_test tool`: **no issues**. LCOV was regenerated.
- The retained page/glass renderer check passed on an Android API 34 x86_64 emulator
  with **Impeller OpenGL ES** (`flip: true`) and **Skia** (`flip: false`). The strict
  gallery was also launched in Android debug and **release/AOT** on GLES; the page
  and glass were upright. These Android runs preceded removal of only the test switch.
  Screenshot: `.figma_cache/render/probe/hw_gles_release_dock2.png`.
  Vulkan and either client's physical phone were **not** exercised.
- Final production entry-point builds succeeded: universal APK, all three ABI APKs,
  and tracked release `build/web` via `dart run tool/design_harness.dart build --tracked`.
  The APKs were rebuilt after removal of the switch; none is a gallery APK.
- The rebuilt production web home was exercised with guest-only synthetic storage and
  strict intercepted GET/OPTIONS responses, at **375 / 768 / 1280 × 812**, **DPR 2**,
  in dark and light themes. All six captures were reviewed: upright content/glass,
  no horizontal overflow. The floating cart opened the actual empty-cart route.
  No page exceptions or unexpected API requests occurred; **42 reads and 42 preflights**
  were handled locally. The optional OneSignal SDK was deliberately blocked, producing
  one blocked-resource console diagnostic per navigation; push was not verified.
  Evidence: `.figma_cache/render/probe/hw114_web_smoke.json`,
  `hw114_web_home_<theme>_<width>.png`, and `hw114_web_cart_empty_dark.png`.

`apksigner verify --print-certs` validated every final APK and confirmed the same
signing identity as the previously delivered 1.2.113 universal. `aapt dump badging`
confirmed `kz.gradusy24.app`, version name **1.2.114**, minSdk **24**, and these codes/ABIs:

| Production APK (`build/app/outputs/flutter-apk/`) | Version code | Native ABIs | Bytes |
|---|---:|---|---:|
| `app-release.apk` | 12114 | ARMv7, ARM64, x86_64 | 81,420,048 |
| `app-armeabi-v7a-release.apk` | 13114 | ARMv7 | 33,744,132 |
| `app-arm64-v8a-release.apk` | 14114 | ARM64 | 36,066,288 |
| `app-x86_64-release.apk` | 16114 | x86_64 | 37,575,538 |

Universal APK SHA-256:
`3663a94d54ba9829c5101b9f9ce68d81b001022c6fe8b1aa4a956b9c19a93608`.
The three existing `build/fixed_apks/FIXED-*` copies were refreshed from their matching
verified outputs and their file hashes matched. Update a previous split install with
the **same ABI**; the universal's lower code cannot replace an installed split.
Do not uninstall to bypass a downgrade and lose app data.
The owned temporary AVD was deleted and the final Gradle daemon stopped.

Build identity is **1.2.114+12114**, distinct from the prior 1.2.113 APKs. Package ID,
signing configuration, minSdk 24, dock geometry and the native Apple path are unchanged.
Physical Huawei acceptance remains an explicit external check: do not infer it from host
tests, a software-GPU emulator or the S25 Ultra result for the preceding build.

### Home composition and compact cart — 2026-10-29

The client asked for a smaller cart control and a composition pass without replacing the
Figma style or cart-only navigation. Active entry remains `AuthenticationWrapper` →
`HomeScreen` → `features/home/ui/home_page.dart`; no legacy home route was substituted.

Visible controls and existing contracts:

| Control | Destination / behavior | State and data source |
|---|---|---|
| Support, bonus, favorites, notifications, profile header actions | Existing chat, bonus history, favorites, notification settings and profile routes | Signed-in header; gated destinations retain login continuation |
| Store/address card | Store chooser; a different store requires confirmation before discarding an active cart | `HomeDataSource` stores, selected-store preferences and cart business scope; failed persistence leaves the cart unchanged |
| Search | Active search screen | Selected store; search owns loading/empty/error states |
| Banner carousel | Promotion items | Server-supplied promotion/store IDs; absent banners omitted |
| Campaign/category tiles and product-section actions | Store-scoped supercategory/catalogue | `HomeViewData` category/promo data; absent optional campaign omitted |
| Product cards and quantity controls | Product details / existing cart quantity mutations | Server-backed product data and `CartProvider`; full names/attributes retained |
| Active-order card | Existing order detail | Only shown when supplied by home data |
| Bonus/QR card or guest sign-in | Bonus history or existing login flow | Authenticated bonus data versus guest prompt; no new loyalty policy |
| Floating cart capsule | Active cart | Empty and filled states from `CartProvider`; no bottom-navigation tabs |

The wrapper retains its loader, bounded auth/home reads and explicit home retry on failure.
Production data contracts are unchanged. Verification uses synthetic guest/signed-in data,
strict fixture transports and in-memory preferences; blank fixture product images and solid
category fills are not evidence of missing production artwork.

| Composition defect | Implemented correction |
|---|---|
| Oversized cart control | Stamp **78 → 56 px**, minimum control height **124 → 72 px** (margins excluded); centered filled cluster, at least 24 px count badge |
| Large-text cart hides the page end | Explicit 1.2 text line heights and single-line scale-down total; scroll reserve measures the same typography |
| Support label splits at narrow widths | Measure available inline width; omit only the text when necessary, retaining the phone icon, tooltip and tap action |
| Store icon becomes an orange square | Glyph-only `shop_glyph.svg`; existing tile-bearing artwork remains unchanged for other consumers |
| Categories suddenly become two oversized columns at 360 px | Three columns retained at normal text; captions wrap at word boundaries, use bounded gutter overhang and scale long words rather than splitting them |

Intentional Figma departures are limited to the compact dock and adaptive text/header behavior.
Dark/light themes, the floating capsule contract and natural product-card heights remain.

Implementation-stage checks: six focused home tests passed; full serial suite **371 passed**;
`dart analyze lib test integration_test tool` reported no issues. The four new layout cases
failed under reverted dock-height, category-width and support-label mutations, then passed
with the implementation restored. The clearance case exposed and fixed an actual overlap at
320 × 640 / 2× text with 12 cart items and an unusually large amount.

Rendered review covered guest/signed-in home at 375/360/320 widths, short-phone heights,
both themes, and larger text; shared-dock captures also covered catalog, all products,
search, favorites, orders, promotion, certificates and bonus history. Synthetic captures
measure layout, not authenticated production acceptance. Final integration evidence follows
the configuration audit below.

Final release-fixture interaction smoke: active `AuthenticationWrapper` home → category →
add one Aperol → back to home with cart count **1** / **13,170 ₸** → compact dock →
active cart with that item/amount. No checkout/order/payment was triggered. A separate
actual `main.dart` fixture boot exercised the production composition root, category
navigation and browser Back after preserving Flutter history state. Its strict transport
kept account/content synthetic and reporting requests in memory; the browser additionally
denied external OneSignal. Reviewed current PNGs under `.figma_cache/render/probe/`:
`final_active_home_dark.png`, `final_home_filled_dark.png`, `final_active_cart_dark.png`,
`final_guest_home_light_360.png` and `final_actual_main_home.png`. All 375 × 812 images
are 750 × 1624; the narrow light image is 720 × 1480 (360 × 740 / DPR 2).

### Configuration audit — 2026-10-29

Four independent Codex audits covered Android, Apple/desktop, web deployment and
Dart/repository hygiene. Findings were checked against source, the current Flutter
template and executable behavior before applying bounded corrections.

| Area | Verified defect / correction | Acceptance boundary |
|---|---|---|
| Android application/task declarations | Removed the nonexistent foreground-task service and obsolete duplicate overlays; disabled automatic backup, added empty task affinity and the `PROCESS_TEXT` query; custom-scheme filter no longer claims domain verification | Real Geolocator service/foreground permission retained; HTTPS association remains enabled but needs the website file |
| Account data transfer | Android 12+ extraction rules exclude both credential/device-protected shared-preference domains in cloud and device transfer; auth/chat capabilities share those preferences | Ordinary backup disabled. Existing local app data is not cleared; a new-device restore will not carry those settings/tokens when rules are honored. OEM device-transfer acceptance is not established |
| Android build compatibility | Gradle 8.14.3 with distribution checksum, AGP 8.11.1, Kotlin 2.2.20 and Java/Kotlin target 17; obsolete explicit `kotlin-stdlib-jdk7` removed | Signed release build passed without the three prior Flutter support warnings; no AGP 9 or blind R8/resource-shrinking cutover |
| Versions and SDK declarations | `pubspec.yaml` owns `1.2.113+12113`; Android uses Flutter version accessors; Dart 3.11 / Flutter 3.41 floors now match the resolved lockfile | Application ID/signing continuity and universal/ABI version-code scheme retained; four newly redundant null assertions removed by analyzer code actions |
| Unused permission dependency | Removed the sole uncalled `permission_handler` method/import, direct dependency and five platform packages after LSP reference checks | Live permission/service checks still use Geolocator; no new location flow or privilege added |
| Splash/icon configuration | API 31+ night splash and generator dark color now use `#121212`; one standalone launcher-icon configuration remains, aligned to minSdk 24 | No branding regeneration. Direct image inspection confirmed both existing maskable icons are branded; an initial blank-icon audit claim was rejected |
| macOS sandbox/build settings | Added outbound-network/location entitlements and purpose disclosure; Podfile and three build configurations now target 10.15 | Both entitlement plists and the Xcode project parse; signed macOS network/location behavior requires Apple execution |
| iOS extension packaging/version inputs | Extension frameworks copy to `Frameworks`, `.appex` embedding remains `PlugIns`; Runner/extension versions use generated Flutter inputs, extension configurations reference the existing `Generated.xcconfig` | OpenStep parsing verifies build-phase/configuration structure; archive embedding, provisioning and runtime not exercised on Windows |
| Docker build context | Allowlisted only `build/web`, nginx configuration and Docker control files; application source/local signing/Figma files are not intended context inputs | Docker executable/engine unavailable here; image build/context upload was not exercised |
| Static Hosting | Firebase fallback excludes association, OneSignal and legacy-worker paths; entry/runtime files get no-cache headers, workers JavaScript MIME and association files JSON MIME | Eleven local HTTP cases passed, including missing nested protected paths returning 404. Installed Windows emulator's `glob-slasher` emits backslashes, so verification used a throwaway POSIX URL-normalization adapter; this is not production-host or unmodified Windows-emulator proof |
| Web startup recovery | The 60 s recovery hint was overwritten by a queued rotating-fact transition; recovery/removal now stops the interval and pending fact transition and restores visible text | Actual browser DOM reproduced before and retained the instruction afterward; `probe/startup_recovery_fixed.png` reviewed at 375 × 812 / DPR 2 |
| Stale setup instructions | Removed unused browser VAPID launch argument and obsolete direct-Firebase/token/topic/client-server-key examples; existing push/hosting guides now describe OneSignal and dashboard-owned credentials | Provider-side Firebase/FCM/APNs registrations retained; documentation is not device-delivery acceptance |
| Telemetry consent and web SDK | No stored choice now means no collection; SDK initialization is lazy and consent changes start/close it through serialized lifecycle handling. Traces, sessions, client reports and default PII disabled; misleading “anonymous” wording removed | Two regressions failed before the fix; three retained real-Sentry/in-memory-transport cases pass. A release-browser probe additionally reproduced the JS bridge ignoring Dart privacy settings; web now retains Flutter handlers with Dart transport only. Opt-in/off/re-enable delivered 1/0/1 synthetic events, no JS Sentry client/CDN or reporting-host request; native SDK behavior is unchanged |
| Browser-history startup state | Custom hash helpers used `replaceState(null, ...)` / `pushState(null, ...)`, erasing Flutter's history tag. The actual main entry reproduced a null-check error in engine history teardown; helpers now preserve the current state object | Release-main fixture startup changed from one captured bootstrap exception to zero; preserved `{flutter: true}` observed. Active home → category and actual browser Back returned to home. No new URL/deep-link routing contract was introduced |
| Repository hygiene | Added precise ignore guards for generated/local caches and diagnostic output | Already tracked files remain tracked. Approval-required inventory and retention decisions: [`../CLEANUP_PLAN.md`](../CLEANUP_PLAN.md#configuration-hygiene-audit--2026-10-29) |

Remaining prerequisites and decisions:

- **Android App Links:** the live `assetlinks.json` endpoint returned 404 and the API 34
  verifier reported `legacy_failure`. Publishing requires the authoritative Play App Signing
  SHA-256 (not an assumed upload-key fingerprint) and ownership of the HTTPS host.
- **Incoming native URLs:** association/filter declarations do not implement a destination
  router. Confirm the supported product/order/auth-return URL contract before implementing
  it; the existing typed OneSignal `additionalData` flow is a different entry path.
- **Apple release acceptance:** use Xcode 26+ and inspect exported app/extension versions,
  embedded frameworks, profiles, entitlements, APNs delivery and native glass interactions.
  Before Xcode 27/iOS 27 SDK use, complete manual UIScene migration while preserving both
  generated-plugin and native-glass registration. Current custom AppDelegate does not meet
  Flutter's stock auto-migration shape; this is a next-SDK gate, not a reproduced Xcode 26 failure.
- **Registered identities:** iOS Team `W922PUY77B`, bundle `com.example.nalivDelivery`,
  extension, App Group and AASA agree; none was renamed. macOS/Linux invalid placeholder
  IDs and desktop publisher metadata need approved owner/account values, not invented names.
- **Hosting/push ownership:** Firebase defaults and historical generation metadata name
  different projects. Select the real site/project explicitly; no deploy, DNS/provider
  change, personal-account test push or payment/order/address/card/SMS mutation was performed.
- **Conservative retention:** keep dormant provider registration files, Gradle wrappers,
  Cupertino font, natural product-card heights and tracked web output. Broader package
  majors, shrinking and notification appearance changes were not silently included.

One deferred review minor: the independent 60 s startup watchdog still fires once after a
fast successful boot and returns on `__splashRemoved`; fact timers are cancelled. No
user-visible regression from that single callback was demonstrated.

Final integration checks on the settled implementation:

| Check | Observed result |
|---|---|
| `flutter test --coverage --concurrency=1 --timeout=90s` | **374 passed**; LCOV **12,924 / 16,792** executable lines (**76.97%**) |
| `dart analyze lib test integration_test tool` | **No issues** |
| Windows `shopping_e2e_test.dart` with `CMAKE_BUILD_PARALLEL_LEVEL=1 CL=/MP1` | **1 passed**: active route, category/product, quantity two, synthetic OTP/pickup/card payment and paid-order history; strict fixture, not a production order |

The first unrestricted Windows build failed in MSBuild's C++ task with
`OutOfMemoryException`; the single-job retry compiled and launched. That run exposed
an obsolete exact-text finder: whole-word category captions made it select an off-screen
section heading. The retained journey now targets a hit-testable category semantics node,
not caption implementation text; the full native journey then passed without missed taps.
The full host suite was not narrowed or replaced by the native retry.

Final signed artifacts, all package `kz.gradusy24.app` / version **1.2.113**:

| Output under `build/app/outputs/flutter-apk/` | ABI | Version code | Bytes |
|---|---|---:|---:|
| `app-release.apk` | ARMv7 + ARM64 + x86_64 | 12113 | 81,420,048 |
| `app-armeabi-v7a-release.apk` | ARMv7 | 13113 | 33,744,132 |
| `app-arm64-v8a-release.apk` | ARM64 | 14113 | 36,066,292 |
| `app-x86_64-release.apk` | x86_64 | 16113 | 37,575,538 |

Both release-build commands completed. `apksigner verify` passed for all four; their
certificate fingerprint matches the previously delivered universal APK. Existing three
diagnostic copies under `build/fixed_apks/` were refreshed, not left pointing at older UI.
Keep the same ABI for an installed split; a universal version-code downgrade is not a
reason to uninstall and erase app data.

Compiled-manifest/resource inspection confirmed backup/cleartext disabled, blank affinity,
the new shared-preference cloud/device-transfer exclusions, absent lock-screen flags and
absent stale service; real Geolocator and `PROCESS_TEXT` remain. The signed universal
installed on the disposable API 34 x86_64 emulator, cold-launched `MainActivity`, remained
the resumed/live app and rendered the intro sign-in control without a crash/ANR overlay.
Installed package flags lacked `ALLOW_BACKUP`; no login or personal-account mutation was
attempted. Screenshot: `probe/final_android_release.png` (1080 × 1920 physical pixels).

Tracked `build/web` was rebuilt with `flutter build web --release --no-wasm-dry-run`.
The release bundle rendered at 375 × 812 / DPR 2; intro entry opened the city-onboarding
screen. The browser intentionally blocked the external city-read/OneSignal requests,
so its explicit retry state is not evidence of production availability or push delivery.
Fresh-start consent left no JavaScript Sentry client; Flutter history state remained
tagged. Reviewed screenshot: `probe/final_release_web_intro.png` (750 × 1624).
The owned probes, comparison template, temporary servers/browser tabs and disposable
emulator are removed/stopped; useful ignored capture evidence remains.




### Android dock orientation and lock-screen fixes — 2026-10-29

Reported on a physical Android phone: every page with the floating dock (home first) rendered
upside down while touch scrolling stayed normal, onboarding was fine, and waking a locked phone
showed the app instead of the unlock screen.

| Defect | Root cause | Fix |
|---|---|---|
| Page vertically flipped | The dock draws the whole page through `liquid_glass.frag`, which samples a `Scene.toImageSync` image. Impeller's OpenGL ES backend stores render-to-texture images bottom-up and applies its Y correction (`TextureGLES::GetYCoordScale`) only to built-in shaders, never to runtime effects, so the page came out flipped there. Skia was correct; onboarding has no dock | `uFlipY` shader uniform. `LiquidGlassDock.warmUp` measures the sampler once (a two-row red/blue scene through the real shader, 2×2 px readback) and sets it. No per-frame readback, and no renderer is named |
| App shown over the lock screen | `MainActivity` declared `android:showWhenLocked="true"` and `android:turnScreenOn="true"` (added 2024-10 with the OneSignal setup); no code relies on either | Both attributes removed; no app-requested keyguard occlusion or screen wake. PIN sleep/wake verified below; notification-tap-specific behavior was not exercised |

Exercised verification (Android emulator API 34 x86_64, debug builds of the strict fixture
surface; no production traffic):

| Check | Observed result |
|---|---|
| `integration_test/liquid_glass_orientation_test.dart` on Impeller OpenGL ES, before the fix | **Failed**: the upper page region read blue, not red |
| Same test after the fix, and `flutter test test/regression/liquid_glass_orientation_test.dart` on the host | **Passed** |
| Fixture `home` on Impeller OpenGL ES and on Skia (`enable-impeller=false`) | Upright and identical; the glass shows the tiles behind it |
| Probe result inverted on the host (temporary mutation, reverted) | The regression test failed with the flipped colours |
| PIN set, app in foreground, screen off then on | Before: the app held focus over the keyguard. After: `NotificationShade` held focus and the lock screen was shown |
| `flutter test --concurrency=1`; `dart analyze lib test integration_test tool` | **367 passed**; no issues |

Limits: only Impeller OpenGL ES and Skia were observed. Vulkan and Metal were not exercised;
the probe measures behavior instead of assuming it, so they need no special case, but that is
unproven here. The reporter's phone was not authorized for adb, so the exact device renderer
was not read.

### Material quality pass — 2026-10-11

The user rejected the first refractive material's quality. Review of the rendered docks
(home/catalog/cart/checkout, both themes) found: a luminance fog that flattened the
interior into an opaque slab, saturation boost that turned colored content into muddy
washes, weak blur that left the optical checker as tile mush, a constant interior dome
warp, pow-blob rim highlights, and banding. Also fixed: the checkout dock hugged screen
edges (8 px margins, radius 28) while every other dock uses 16 px / radius 36, and the
home promo card reserved 160 px of artwork height even with nothing to show.

| Change | Implemented result |
|---|---|
| `shaders/liquid_glass.frag` rewritten | 21-tap per-pixel-rotated golden-angle frost (kills tap-moiré), rim-concentrated refraction (SDF normal, IOR 1.45, bend 16–32 px) over a nearly flat interior, mild dispersion, Fresnel + crisp top streak + faint counter-light, dithering. Fog and saturation boost removed |
| Theme range control | Adaptive shadow-lift (light) / highlight-crush (dark) instead of fog; a base material tint (dark 32% `#0E0E10`, light 30% white) carries the glass identity; mid-tones stay untouched so the scene remains visible |
| Dock defaults | `LiquidGlassDock` default tint is now the theme base material; consumers can still override |
| Checkout dock | Uses the shared default margins/radius; `_footerReserve` follows `AppSpacing.xl` |
| Home promo card | Without artwork and fill the card hugs its copy instead of reserving 160 px |

Exercised verification (Flutter processes serial; tests `--concurrency=1`):

| Check | Observed result |
|---|---|
| Windows optical probe (dark + light): scene outside material untouched, material responds to moved scenery, exactly one foreground tap | **2 × passed**; top-region mean Δ 0, material mean Δ ≈ 42/255 (evidence in `.figma_cache/harness/optical/`) |
| Focused `checkout_page_test`, `home_flow_test`, entire `design_harness_test` | **33 passed** |
| `flutter test --coverage --concurrency=1 --timeout=90s` | **366 passed** |
| Application LCOV (`SF:lib/` records) | **76.79%** — 12,824 / 16,701 lines, 99 files |
| `dart analyze lib test integration_test tool` (also after probe removal) | **No issues found** |
| Windows shopping journey | **1 passed** |
| Capture refresh with the final shader | **128 captures** (82 canonical + 50 comparisons, 30 narrow/2×, 8 keyboard, 8 wide) |
| Fixture rebuild + browser review | home/catalog/cart/checkout in both themes: frosted scene visible, bent rim, sharp foreground, readable amounts |

Command evidence: `.figma_cache/harness/runs/2026-10-11T13-21-28.998248Z_18076.json`;
captures `.figma_cache/render/runs/1791724663728720_25208.json`,
`.../width_320.0__text_2.0__keyboard_0.0/runs/1791724760398050_24224.json`,
`.../width_320.0__text_2.0__keyboard_300.0/runs/1791724805973722_32000.json`,
`.../width_800.0__text_1.0__keyboard_0.0/runs/1791724831574326_4024.json`.
The disposable optical probe source was removed after its run; its PNGs/measurements remain.
The red tint visible behind the light cart footer is the genuine blurred `Подарок` gift
banner behind the dock — correct glass behavior, with the gift banner's own readable
foreground above it. The Apple boundary is unchanged: shader proof only; native
`UIGlassEffect` acceptance still requires macOS/Xcode 26+/iOS 26+.

### Catalogue, confirmation and genuine glass cutover — 2026-10-09

| Requested change | Implemented result |
|---|---|
| Simplify the catalogue | Uniform category sections; removed the oversized featured-category sidebar and competing strip; short pinned navigation while heading/context scroll |
| Unambiguous category navigation | One complete wrapping picker with selected semantics, overview and explicit close; sibling replacement retains the existing prefetched/paginated data contract |
| Give cards enough space | Natural-height `ProductGrid`/`ProductRail`; two columns at 375 px, one at 320 px or large text, at most four on wide windows; complete known identity, prices, saving, gift and bonus outside artwork |
| Usable confirmation hierarchy | Fulfilment → editable order review → collapsed benefits → labelled cost breakdown → quiet help; actual footer height reserved outside the scroll viewport; keyboard footer contains only creation/recovery |
| Genuine Liquid Glass | GPU live-scene shader with curved-shell Snell refraction, rough transmission, dispersion and Fresnel reflection; separate sharp controls; actual `UIGlassEffect` bridge on iOS 26+ |
| Glass around the whole cart control | One growing shell covers the 78 px starburst, badge and amount; removed the lower strip and separate amount material; original SVG crop/75% opacity and cart actions retained |

Active routes and controls are mapped in `PLAN.md`. All nine floating-cart destinations
and cart/product/configured-product/confirmation footers use the new dock. Ordinary
chrome uses `AppSurface`/`AppSectionAction`; obsolete imitation-glass and fixed-card-height
APIs are removed, without compatibility aliases. Cart/store identity, dynamic mandatory
bag, independent quote/bag/bonus startup, precise benefits, kilogram steps/stock,
structured product identity, paid/gift container tariffs and unknown-order/payment locks
remain the F1–F11 contracts. Disclosure changes do not introduce financial retries.

#### Settled verification

Flutter processes ran serially; test commands used `--concurrency=1`.

| Exercised path | Observed result |
|---|---|
| Entire `test/integration/checkout_page_test.dart` | **28 passed** |
| Entire `test/regression/design_harness_test.dart`, after managed-viewport registration fix | **3 passed** |
| `flutter test --coverage --concurrency=1 --timeout=90s` | **366 passed** |
| Application LCOV, records matching `SF:lib/` or `SF:lib\` | **76.78%** — 12,820 / 16,697 lines, **99** application Dart files |
| `dart analyze lib test integration_test tool`, including after the browser-helper change | **No issues found** |
| Windows active-wrapper shopping journey | **1 passed**; synthetic store/category/product/OTP/bag/payment/history, no production transport |
| Native Windows optical probe | Both themes: scene outside the material unchanged; refracted grid changes when underlay moves; foreground cart tap count **1** per theme |
| Explicit canonical/adaptive capture passes | **128 captures**: 82 canonical, 30 narrow/2×, 8 keyboard, 8 wide; **50** canonical diagnostic comparisons |
| Fixture and tracked release builds | Both succeeded; user-owned Android splash registration preserved |
| Current release-fixture browser | Complete picker/sibling navigation, stock limit 20 and decrement to 19, expanded cart hit, checkout quantity/draft/bonus/clearance exercised |
| Guarded tracked release, 375 × 812 / DPR 2 | City onboarding rendered; actual “Повторить запрос” caused a second deliberately blocked city-read preflight; cached-city warning and scroll-reachable disabled continuation observed |

Command evidence:

- Confirmation: `.figma_cache/harness/runs/2026-10-09T09-29-07.085957Z_16088.json`.
- Full suite/analysis/native: `.figma_cache/harness/runs/2026-10-09T09-32-12.028393Z_20592.json`.
- Browser-helper module/analysis: `.figma_cache/harness/runs/2026-10-09T12-01-45.403681Z_2832.json`.
- Fixture build: `.figma_cache/harness/runs/2026-10-09T09-39-43.008727Z_27348.json`.
- Tracked build: `.figma_cache/harness/runs/2026-10-09T09-41-06.320995Z_25496.json`.
- Canonical: `.figma_cache/render/runs/1791538219760364_23592.json`.
- Narrow: `.figma_cache/render/variants/width_320.0__text_2.0__keyboard_0.0/runs/1791538278120345_10700.json`.
- Keyboard: `.figma_cache/render/variants/width_320.0__text_2.0__keyboard_300.0/runs/1791538302472765_24968.json`.
- Wide: `.figma_cache/render/variants/width_800.0__text_1.0__keyboard_0.0/runs/1791538314893799_24436.json`.

Coverage is Dart application line coverage, not Swift, GLSL or native-rendering coverage.
The final browser-helper edit only registered its existing requested viewport on the
managed tab; it did not change fixtures, expected assets or dimension assertions.
The whole harness regression module and analysis passed afterward; no app bundle change
required another Flutter build.

#### Current browser geometry and state

Authoritative runtime metadata/request decisions/diagnostics:
`.figma_cache/harness/review/current-runtime-evidence.json`. PNGs are retained beside it.
Both checkout scenarios used native mouse/keyboard input and asserted entrance **12**
after collapse/reopen and applied bonus **3,951 ₸** after closing benefits.
The observed paid quantities were `[1, 6, 1, 2]`, plus a separately displayed gift unit;
same-origin synthetic cart persistence means a reload is not a cart reset.

The labelled review and payable amount agreed:
**131,700 products + 30 bag + 700 delivery + 100 service − 3,951 bonus = 128,579 ₸**.
An earlier visibly tapped order row independently changed 2 → 3 units, line price
26,340 → 39,510 ₸ and total 145,700 → 158,870 ₸, with neighbouring rows unchanged.

| Current rendered checkout | Canvas/PNG pixels | Last help bottom | Creation action top–bottom |
|---|---|---:|---:|
| Light, 375 × 812 / DPR 2 | 750 × 1624 | 624 | 716–756 |
| Dark, 320 × 812 / DPR 2, 2× text, 300 px keyboard | 640 × 1624 | 360 | 394–490 |

The adaptive scroll viewport ends at **380** and the simulated keyboard starts at
**512**: the last help control is inside the scroll viewport and the action is above
the keyboard. The light **92 px** gap is to the action, not a claim of 92 px clearance
above the material shell. Fresh calibrated navigation proved the live canvas as well as
PNG dimensions; a correctly sized but padded screenshot is not sufficient evidence.

Before tracked-app navigation, the current guard probe allowed local GET/HEAD (**200**)
and rejected local POST and a production-host GET. Guards allowed only GET/HEAD to
loopback/Flutter font-engine CDNs and remained active until page close. The exercised
tracked entry was already city onboarding, not the intro CTA assumed by an initial
driver wait. Actual city API preflights to `njt25.naliv.kz`, OneSignal and Sentry resources
were deliberately denied. Completed fixture/tracked diagnostics contain these expected
network blocks, but no unexpected Flutter/shader/page exceptions. No phone entry, SMS,
address/card/chat mutation, order creation or payment was sent to production.

#### Acceptance boundary

Windows optical images and measurements are in `.figma_cache/harness/optical/`.
They prove the live Flutter shader, not Apple-native composition or pixel parity.
Native Runner integration requires **macOS/Xcode 26+ and an iOS 26+ runtime** for build,
sampling, corner/theme updates, foreground taps and mounting/disposal acceptance;
older supported iOS shader selection also remains an Apple-runtime check.
Commands and platform-view limitations are in `PLAN.md`. Apple execution is unclaimed,
not silently replaced with blur. Synthetic fixtures and old-frame diagnostic differences
do not establish authenticated production, real-bank or push-device acceptance.


### Design harness prerequisite — 2026-10-09

Reused the existing strict fixture gallery and capture/comparison tools. Added
`tool/design_harness.dart`, `tool/design/fixture_browser.js`, strict fixture URL options,
one pure-Dart surface registry, and the project-specific `naliv-design-loop` OMP skill.
Editor tasks now use the serial harness; removed the stale Mac CMake path and legacy
Dart analyzer settings. Runtime MCP configuration was schema-linked and its enabled
capabilities checked against the installed SDK help. Global OMP preferences are unchanged;
no live MCP connection or release-bundle inspection is inferred from configuration.

| Exercised harness path | Observed result |
|---|---|
| SDK/cache doctor | Flutter 3.44.8 / Dart 3.12.2; 41 strict fixture surfaces; reports capabilities/limits without reading an account |
| Focused harness regressions + `dart analyze lib test integration_test tool` | **56 passed; no issues** |
| Offline Figma lookup | Both themes' catalogue/all-products/checkout nodes resolved; no network fallback |
| Exact-node spec repair | Read-only Figma GETs repaired ordinary dark/light home IDs and preserved modal originals; merged index now has 212 records, all four home variants report `ok` |
| Held lock / second command | Second harness command exited **78** before starting its child; owned lock probe stopped and removed |
| Canonical multi-surface capture | Catalogue, all products, pickup confirmation and cart: **8 captures + 8 measured diagnostic comparisons**, 750 × 1624 |
| Adaptive capture-only | Catalogue/pickup, both themes, 320 px / 2× / 300 px keyboard: **4 captures**, 640 × 1624; no comparison metrics; canonical outputs retained |
| Fixture release build | Built `.figma_cache/harness/web`; existing Android splash block preserved without replacing other registrations |
| Actual release-browser helper | Catalogue boot/category selection; 375 px light and 320 px/2×/keyboard dark PNG dimensions verified; `cards=error` rejected visibly and helper closed its tab |
| Fixture static server | HEAD 200 with `no-store`; POST 405; encoded parent escape 404 |

Logs/status: `.figma_cache/harness/runs/`. Capture evidence:
`.figma_cache/render/runs/1791529789527878_24516.json` and
`.figma_cache/render/variants/width_320.0__text_2.0__keyboard_300.0/runs/1791529877544999_24780.json`.
Actual browser PNGs: `.figma_cache/harness/harness_catalog_light.png` and
`harness_catalog_adaptive_dark.png`. These established the harness, not acceptance of
the former catalogue layout: its redundant navigation, cramped cards and large-text
hierarchy triggered the implemented cutover above. No application production mutation occurred.


### Prior client corrections and full-frame cutover — 2026-10-09

| Issue | Implemented client behavior | Acceptance boundary |
|---|---|---|
| F1 Checkout login | OTP continuation returns to the existing checkout draft; delivery, store, quantities and benefits are retained | Synthetic guest-to-paid native/browser journey; no real SMS |
| F2 Store consistency | Persisted cart business identity; same-store selection and cancellation preserve rows; a different store requires explicit discard confirmation | Legacy nonempty carts with unknown origin cannot silently adopt a store |
| F3 Branded bag | Resolve master code `KR-00002264` through typed catalogue search for the selected business; charge one mandatory bag and require current stock/price before submission | Anonymous production reads confirmed `Майка фирменная`, observed store 1 price 40 ₸ and other observed stores 30 ₸; fixture SKU 48044 / 30 ₸ is synthetic |
| F4 Bonuses | Shared eligible base and monetary precision, current balance loading and refresh; unavailable balance is not zero; removed the contradictory 25% FAQ promise | Existing 30% client cap retained, not declared authoritative loyalty policy |
| F5 Returns | Display actual signed bonus ledger entries and server return states without manufacturing reversals | 1C sale/return integration and redeemed-bonus reversal require backend sandbox artifacts |
| F6 Saved cards | Canonical supported Halyk rows and separate full-info account summaries; stable display identity separate from verified charge identity; masked-only collection rows remain visible but cannot pay | A real affected-account Halyk/full-info snapshot is still required; no speculative fallback endpoint or charge ID |
| F7 Payment launch | Accepted links remain reopenable without another create/pay request; unknown-result locks persist; only server status confirms success | Fixture refusal, uncertainty, cancellation and recovery are not real bank/OS acceptance |
| F8 Kilograms | Fractional quantities and stock, server-provided sales step and price unit; no step inferred from package weight | Missing authoritative kilogram step explicitly blocks fresh increases |
| F9 Identity | Structured type, packaging/material, country, volume/weight and ABV survive list/detail/cart/order projection | No invented glass, ABV or ambiguous comma-name parser |
| F10 Categories | Complete category destinations, selected semantics, clear leaf/“Все” continuation and accessible targets | Existing store-scoped catalogue API; no alternate router |
| F11 Support | Identity-owned chat session; allowlisted support events; cold-click login continuation; foreground message deduplication and background-read pause | Publisher payload/recipient mapping, HTTPS worker and signed mobile delivery remain unaccepted |

Full-frame review retained all **212 original Figma frames**, including ordinary/modal home
variants. Ordinary aliases now reference dark `2093:14635` / light `2098:32279`; modal originals
`2093:14858` / `2098:32504` remain separately preserved. Sources:
`.figma_cache/issue_plan_figma_manifest.json` and `.figma_cache/shots/`.

In that prior pass, the cart used one lower material layer and the SVG's original 75% alpha,
without redundant circular backing or multiplied color-filter opacity. That material and
catalogue density are superseded by the current refractive/full-cart-shell and natural-card
cutover above. Guest profile remained inside the store card with independent ≥44 px targets;
dark home used the canonical white brand asset. Configurable pour products exposed live paid/gift litres, physical mix, truthful ADD/REPLACE
tariffs and per-container gift allocation before the picker; large text/narrow rows remain
scrollable. The campaign header advertises only active terms present on its individual items.

#### Settled-source verification

All Flutter processes ran serially; every test command used `--concurrency=1`.

| Command / check | Observed result |
|---|---|
| Focused `product_detail_bottling_test.dart` and `promotion_items_page_test.dart` | Existing behavior regressions passed; the new first-screen-clearance regression failed before the compact layout and passed afterward |
| Owned adaptive render/strict-transport probe | 434 passed; 41 surfaces, both themes, 320/375/800 px, 1.6×/2× text, relevant 300 px keyboard cases |
| `flutter test --coverage --concurrency=1 --timeout=90s` | **304 passed** |
| Application LCOV, `coverage/lcov.info`, `SF:lib/` records | **76.08%** — 12,532 / 16,472 lines, 96 files |
| `dart analyze lib test integration_test tool` | **No issues found** |
| `flutter test integration_test/shopping_e2e_test.dart -d windows --concurrency=1` | **1 passed**; expected “OneSignal push is not supported on this platform” |
| `dart run tool/verify_surface.dart all --theme both` | **82** full 750 × 1624 captures; **50** comparisons, **32** capture-only combinations with no exact Figma counterpart |
| `flutter build web --release --no-wasm-dry-run` | Tracked `build/web` built successfully |
| `flutter build web --release --no-wasm-dry-run -t tool/dev_surface.dart -o .figma_cache/issue_implementation_web` | Strict fixture release built successfully |

Current command output is `artifact://1018`; final per-surface diagnostic values are in
`FIDELITY.md`. All full frames were reviewed in the final 22 contact sheets, including the
compact live bottling summary. A successful comparison command is not pixel-parity acceptance.
The 434-case probe was disposable, not a new permanent suite. The retained regression tests
consumer-visible obscuring of the first bottle control, not a pinned arbitrary dimension.

#### Actual runtime controls and state

- Native active-wrapper journey starts with an empty cart and no selected store/token: home →
  category → product 100 → quantity 2 → pickup checkout → synthetic phone/OTP → same draft →
  order with mandatory bag 48044 × 1 → saved-card payment → server-confirmed paid history.
  Expected payable amount is **26,370 ₸**. No production mutation transport is permitted.
- Release-fixture browser shopping separately exercised guest category/leaf/“Все” navigation,
  quantity 2 (**26,340 ₸** cart), delivery (**27,170 ₸**), pickup (**26,370 ₸** including
  the synthetic 30 ₸ bag), cross-store discard cancellation, same-store retention, OTP continuation,
  fixture balance 3,951 and confirmed order 901/history/detail. Final header store/profile targets
  were also operated independently in both themes: store opens the store sheet; the nested
  profile glyph opens guest profile, not store selection.
- Final compact pour runtime used cache/service-worker bypass to avoid an older fixture bundle.
  Kronenbourg 1 L × 2 produced paid 2 L, physical 2 × 1 L, drink **5,200 ₸**, containers
  **220 ₸**, total **5,420 ₸**; saving and opening cart retained those values. The 3+1 runtime
  showed paid 3 L, gift 1 L, physical 4 × 1 L, drink **3,000 ₸**, all containers **400 ₸**
  and total **3,400 ₸**, with the actual split on its bottle row; saving and opening the gift
  cart retained the 4 L / 4 × 1 L mix, 0 ₸ gift drink and ordinary container charges.
- Account runtime exercised loaded, genuinely empty, mixed verified/masked-only and mask-only
  card collections; a stalled read exposed a retryable timeout, and retry restored the verified
  row. Synthetic card binding cancellation remained pending until its explicit cancel action,
  not successful. Certificate filters, purchase-sheet amount selection and dismissal were
  operated without a real purchase.
- Pending fixture Kaspi payment opened its waiting dialog, retained an unconfirmed server state
  after dismissal and exposed “Открыть оплату” instead of another charge action. Reopening showed
  the same accepted link and no new payment request; duplicate-request counts and unknown-result
  persistence are independently asserted by the retained payment-recovery regressions.
- Address controls continued from the synthetic map to detail fields and device-only save;
  the address book showed the local entry and selected delivery origin. Bonus history displayed
  actual fixture signs (+250 / −100) and opened its explainer. Support opened searchable FAQ,
  returned to its composer and sent only an explicitly synthetic message.
  Notification settings' support action opened that chat; no real push permission was requested.
- The existing gallery's actual text dropdown was operated at 2× on its 375 px dark home.
  Store/search text reflowed, campaign action stayed visible and the shared cart glass remained
  operable; the lower content scrolls rather than being shrunk. This interactive sample is
  separate from the 434-case rendering probe and from exact-frame pixel acceptance.
- Final tracked release was actually launched at **375 × 812 / DPR 2**. Intro CTA continued
  to the city screen. The guarded city's preflight was blocked, so the observed final state was
  a recoverable city-read error with retry and disabled continuation. This is safe release-entry/
  failure-state evidence, **not a successful final production city GET or authenticated smoke**.
  Its request log contains only GET/OPTIONS; no SMS/order/card/address/chat/payment mutations.

Owned disposable UI probe and one-off dark-brand export map were removed after recording
their results. Required brand assets, all original Figma frames, reference manifest and evidence
images remain. Only this work's browser tabs and two static verification services were stopped.

Evidence PNGs remain ignored under `.figma_cache/`: the earlier store-cancel/resumed-checkout/
confirmed-payment/history journey frames, `issue_runtime_pour_final_light.png`,
`issue_runtime_tracked_intro_final.png` and `issue_runtime_tracked_city_guarded_final.png`.
The user-owned Android `FlutterNativeSplashPlugin` registration was restored after the final
generation; unrelated registrations were retained.

#### External acceptance not supplied

| Prerequisite | Required evidence |
|---|---|
| Affected personal card account | Same-account authenticated Halyk collection and full-info snapshots; verified bank charge identity and supported envelope |
| Actual bank launch/payment | Platform sandbox, actual gateway URL/scheme, cancellation/return/reopen lifecycle and server-confirmed status |
| Loyalty policy | Authoritative rate, eligible base, cap, precision/rounding and event semantics; current 30% client cap is retained pending policy |
| 1C return reversal | Original order, redeemed bonuses, returned item, backend return artifact and matching signed ledger; no client-manufactured refund |
| Support push | Deployed publisher payload/recipient schema, HTTPS worker and signed Android/iOS devices; development APS/app group is not delivery proof |

No real SMS, order, payment, account-address/card mutation, return or production support message
was executed. Historical gates below remain history; they do not override these acceptance limits.

### Three-litre bottles withdrawn, promotion review fixes — 2026-10-07

Requested: remove three-litre bottles, and a review of the promotion work.

- **Range change:** `SmartCartSelection.filteredBottles` drops exactly three-litre containers (other
  capacities, including larger kegs, stay), so the picker never offers one and no new selection or
  gift allocation can use one. `knownBottleRelationIds`, `litersForCounts`, `isBottleVariant` and
  `_bottleVolumeForCartItem` keep every container the store identifies, so a cart that already holds
  a three-litre bottle keeps its litres, its tariff, its gift allocation and its order rows; the
  configurator lists such a row as `… больше не продаётся` with the add button disabled and remove
  live. `_syncPourFlowBottleCounts` builds rows for every counted container, and `withGiftContainers`
  attaches retained gifts for withdrawn containers too.
- **Valid review findings fixed:** the `+100` bonus chip no longer disappears from discounted cards
  (chips are the first two of `[-10%, 2+1, +100]`, so the frames' `-10%` + `+100` pair survives);
  reconciliation now reads the server's own figure (`resolveServerChargedAmount` prefers
  `cost_summary`/`payable_amount`/`final_amount` over the `total_amount` the client sent — proved by
  a payload carrying both); promotion refresh is scoped to catalogue merges, so a repeated order can
  no longer overwrite live promotions with historical or empty ones; the inverse gift rule walks the
  candidate awards, so a basket only the runner-up promotion explains (five units of `2+1` + `3+1`)
  is still restorable.
- **Second expiry path:** the catalogue list builds items through `CategoryItemPromotion`, which
  forced the window to null. The DTO now parses and re-emits the nested window and
  `ItemPromotion.fromCategoryItemPromotion` carries it, so catalogue entries expire client-side too.
- **Evidence:** `flutter test --coverage --concurrency=1`: **258 passed**, **10,610 / 14,361 lines =
  73.88 %**; `dart analyze lib test integration_test tool` clean. New regressions: withdrawal
  (offered set, legacy cart litres/tariff, re-save), inverse candidate walk, repeat-order freshness
  guard, bonus chip on discounted cards, echoed-total reconciliation, catalogue entry window.
- **Docs:** `PROMO_BOTTLING_PLAN.md` records the withdrawal under M4, the corrected chip priority, the
  no-snapping decision for stepping, discount stacking (selection applies to the gift award only) and
  the scoped refresh.

### Promotions, item page and bottling — 2026-10-07

The reported defects (no promotion item cards, an untrustworthy promotion calculation, weak bottling,
a chaotic item page) were researched against the re-dumped light frames, the API payloads and the
running app; the plans and the evidence live in `PROMO_BOTTLING_PLAN.md` (M1–M5).

- **M1 promotion kernel — implemented.** `lib/utils/promotion_engine.dart` is now the only promotion
  evaluator: `selectSubtractPromotion` picks the customer-best `N+M` award deterministically,
  `isPromotionActive` reads both flat and nested validity windows, `evaluatePromotion` exposes
  paid/free/physical units, `nextGiftIn`, `progress`, `unlocked`, the `2+1` label and the campaign
  name, and the forward/inverse gift pair plus price application live in one file.
  `subtract_promotion_math.dart` is deleted; seven lib callers and two test files import the engine.
- **Defect fixed:** validity was never parsed. `ItemPromotion.fromJson` only read flat
  `start_date`/`end_date`, while the server nests the window under
  `promotion.{start,end}_promotion_date`; both stayed null, `isActive` was always true and an expired
  promotion kept gifting. The model now reads and re-emits the nested window and campaign name, and
  the engine filters by it — restored rows expire too.
- **Money safety:** `checkoutAmountNotice` compares the client total with the server's `cost_summary`
  after order creation and `PaymentMethodPage` shows the divergence under the amount
  (`payment-amount-notice`) instead of letting the two figures differ silently.
- **Freshness:** touching a row from the catalogue replaces its stored promotions with the live ones.
- **M2 promotion presentation — slices 1–3 implemented.** Cards advertise an active `N+M` through the
  shared `AppPromoChip` (priority `-10%` → `2+1` → `+100`, gift in accent, at most two chips); the
  item page renders a promo card with the campaign name, the rule, a progress bar and
  `Добавьте ещё N, чтобы получить подарок` / `Подарок в корзине`; the cart renders the free units as
  their own `0 ₸` line (`Подарок · 1 л`, the frame's `При заказе N и более этот товар в подарок`
  caption, `cart-gift-*` keys). Reviewed on the strict fixture cart at 375 × 812 / DPR 2 in both
  themes: the seeded `2+1` row shows the gift line at `0 ₸` while the paid line keeps 26 340 ₸ for
  two units and the basket total counts paid units only (131 700 ₸).
- **Verification:** full `flutter test --coverage --concurrency=1`: **251 passed**, **10,587 / 14,335
  lines = 73.85 %** at that point (superseded by the counts in the entry above); `dart analyze lib
  test integration_test tool` clean; new
  `test/regression/promotion_engine_test.dart` (13 cases incl. round trips `0…12` for `2+1`/`3+1`/`2+2`,
  unattainable physical values, expiry, nested window, two freshness cases),
  `test/regression/checkout_contract_test.dart` (3 reconciliation cases) and
  `test/integration/promotion_presentation_test.dart` (9 cases across card, item page and cart).
  The fixture cart now seeds one live `2+1` row so the shell exercises the gift line.
- **Remaining:** M2 slices 4–5 (checkout summary gift line, promotion-page header), M3 item-page
  shell, M4 bottling picker, M5 states/a11y/rollout; cross-item gifts wait on a backend gift-item
  reference (`PROMO_BOTTLING_PLAN.md` §5 Q1). No promotion change was exercised against
  authenticated production; the reconciliation is the guard for that.

### Cart chrome, glass and category bounds — 2026-10-04

- **Design source:** the branch merge had dropped `.figma-token`/`.figma-design`, so the light page was re-dumped (`dart run tool/figma_spec.dart spec --page "Design System (Light)"`, 105 frames) plus four reference PNGs. Measured recipes: the floating cart control is a 78 px starburst with the cart glyph and — once the cart has items — a 125 × 34 r=100 pill whose left edge sits **47 px into the badge**, with the 32 px `#880514` count badge on the badge's upper-left corner; the shapes are GLASS (`#F16800 @ 75 %`) with the single drop shadow. Section `Все` is a 46 × 28 r=100 accent@75 % glass chip; the store-card chip is 32 × 32 r=8 glass; the signed-out home CTA is a 279 × 49 r=100 glass pill; the product confirmation is a 343 × 54 stadium inside the 129 px glass bar; the `Menu` discs are 40 × 40 glass.
- **Reported defects, measured before the fix:** with items in the cart the control rendered **375 × 66** at 1× — full width, count and total on two wrapped rows — and **375 × 86 / 101** at 1.6× / 2×. Cause: the count badge was a `Container(alignment: Alignment.center)` inside a `Wrap`, and a non-null alignment makes a container expand to its constraint maximum. The product-page confirmation clipped its row at 2× (the label ran off the right edge).
- **Implemented:** the control matches the frames — glass starburst + pill, count badge over the corner, one row at every scale, price scaled down instead of wrapped or clipped, bounded by the screen gutters. The control is now **78 px tall at 1×/1.6×/2×** (pill 34.8 → 55.6 px, capped at 296 px wide) instead of 375 × 66–101. `AppGlassChip` renders the section `Все` action on home and catalog headers; the store chip, signed-out CTA and confirmation pill are glass; `AppIconButton` blurs its disc (repeated favourite rows pass `blur: 0` rather than paying for a save layer per item). Category tiles use the frames' 98 px columns with 24 px gaps — **three across the 343 px content at 375**, artwork as wide as its column — and drop to two columns at 1.6×/2× instead of the previous two columns at every scale.
- **Verification:** focused **18 passed** (home, catalog, cart and product-detail regressions plus the new bounds test); full `flutter test --coverage --concurrency=1`: **227 passed**, **10,389 / 14,122 lines = 73.57 %**; `dart analyze lib test integration_test tool` clean. Fixture release reviewed at 375 × 812 / DPR 2 with no browser runtime errors: light home (three category columns, glass store chip), filled control at 1× and 2×, dark catalog (glass discs and `Все`), dark home at 1.6× (two columns), product confirmation at 2×.
- **Limits:** the frames draw a pill-only cart control on the search page; the app keeps its single shared starburst control there. Product-card steppers stay opaque instead of carrying a `BackdropFilter` per card — only the floating chrome blurs. No pixel diff was re-run, so this is design-fact and geometry evidence, not parity acceptance.

### Repository cleanup — 2026-10-04

- **Tests:** 76 low-signal expanded cases removed; four cart-cache and one async-failure regression added. Retained **226 host cases** in **21 integration / 21 regression files**, plus one native e2e. Unique money, gift, stock, persistence, auth, race and card-identity failures remain; no case-count reduction by hiding assertions inside tables.
- **Structure/resources:** removed 16 dead API methods, ten unused DTOs, unreachable legal viewer/service code and unused responsive helper; one canonical `lib/model/cart_item.dart`, shared preference fixture under `test/support`. Removed Markdown dependency and orphan bundled legal/splash bytes, not legal sources, Cupertino font or SDK engine variants.
- **Runtime:** revision-cached membership/order/filter projections retain live price/gift calculations. A 50-row / 10,000 paired-read probe observed zero warm rebuilds, one after mutation and one after reload. Home store/category work starts before held bonus/city reads complete; coordinated waits prevent orphan async errors. Consent and package reads overlap before Sentry.
- **Verification:** focused **94 passed**; full serial coverage suite **226 passed**, **10,331 / 14,063 lines = 73.46%**; `dart analyze lib test integration_test tool` clean. One actual Windows fixture journey reached paid order history through plain-product add, catalog quantity 2, cart, pickup order/package and saved-card payment; asserted zero unexpected requests/native HTTP escapes. Both canonical fixture and tracked release builds passed.
- **Actual release surfaces:** light home → typed search `Aperol` → add/increment → cart **26,340 ₸** → explicit final delete / empty cart; dark cart at **1.6× inherited text**, real wheel scroll and fixed checkout footer. Browser runtime errors and production API requests were absent in these fixture runs. No new full Figma sweep/pixel-parity claim.
- **Footprint:** web distribution **50,302,831 → 45,613,042 bytes (−9.3%)**; source **−4.7%**; host test/support/fixture bytes **−9.7%**. New native e2e adds 4,818 source bytes. JavaScript did **not** shrink: **+493 raw / +427 deterministic-gzip bytes**. See the cleanup plan's exact table and measurement method.
- **Safety/limits:** tracked intro → city onboarding at 375 × 812 / DPR 2 used anonymous **GET `/api/users/cities` → 200**, with four city radios and GET/OPTIONS-only guards during navigation. Sentry envelope attempts were deliberately blocked; no production mutation/SMS/order/payment, authenticated-account retry or mobile IME proof. An initial native runner read escaped its HTTP zone and got an unauthenticated 401; the final harness re-registers engine callbacks in the strict fixture zone and rejects native-network escapes.
- **Native/ownership:** AAPT2 linked v21 splash XML to the retained base bitmap; no Android/iOS device claim. The user's pre-existing Android splash registration was restored after SDK generation. Disposable probes/baselines were removed after recording evidence; owned tabs/servers were closed, unrelated Flutter processes left alone.

### Catalog/card balance correction — 2026-10-02 evidence

- **Shared card:** 96 px maximum artwork, 14 px two-line name, 12 px combined country/volume and 16 px current price. Price follows metadata instead of sitting beneath a large reserved gap. Old price remains 12 px; duplicate saving text and obsolete `dense`/card-saving APIs were removed, with all home/catalog/cart/campaign sizing consumers migrated. Missing art uses the muted theme surface. Long/wrapped prices and unavailable text take space from artwork, never from readable type or actions.
- **Actions:** initial add is a separate 44 × 44 px tile; selected quantity uses a quiet full-width stepper. Stock-disabled add stays disabled; increment/decrement, configuration and inherited scaling retain their existing semantics. Detailed savings remain on product/row surfaces.
- **Catalog:** a concise featured heading/horizontal strip replaces the tall lead illustration; its orphan artwork was removed. Category chips have 44 px minimum height. Ordinary previews display at most two rows; “Все” retains the complete prefetched data and subsequent pagination. Catalog content is bounded to 840 px and grids to four columns.
- **Observed geometry:** normal cards are 255 px, or 271 px when an old-price row is required by the dataset. Mixed-grid heights are 324/360 px at 1.6×/2×. Full lists use two columns at 320/375 px and 1×, one at larger text; 800 px uses four at 1× and three at larger text. Dark/light actual browser review included missing art, captured product photography, discounts, unavailable stock and selected quantity across those widths/scales. Real wheel scrolling, not semantics-only movement, established the photo/stock views. A 2× live resize 320 → 375 → 800 retained one item / 13 170 ₸.
- **Actual journeys:** strict fixture `AuthenticationWrapper` home → active catalog → floating cart succeeded. Add/increment changed the running total to 13 170/26 340 ₸; two decrements restored the empty cart. Featured “Все” opened prefetched items without another initial read; scrolling issued page 2 and displayed the three supplied continuation items. The captured Kronenbourg photo opened its real bottle configurator; replacing the default 1 L bottle with one 2 L bottle produced **2 L / 5300 ₸**, then the shared catalog quantity and cart retained that selection/total. No checkout/payment was executed.
- **Pre-cleanup verification:** focused catalog/home/cart/campaign tests **20 passed**; removed disposable matrix **306 cases passed** across nine shared-card consumer surfaces plus plain/discount/unavailable/selected/high-price/large-quantity states. Full `flutter test --coverage --concurrency=1`: **297 passed**, **10 569 / 14 491 lines = 72.93%**, 94 recorded files. `dart analyze lib test tool`: no issues. Refreshed capture CLI: **82 captures / 50 comparisons**, reviewed with current browser evidence; no pixel-parity claim. Canonical fixture release and tracked release builds passed.
- **Release smoke/safety:** tracked release at 375 × 812 / DPR 2 rendered intro and actual city onboarding. Public **GET `/api/users/cities` → 200** supplied four city controls. A browser request guard refused production methods other than GET/OPTIONS; no production mutation was attempted. The previous personal-session 401 was not renewed/repeated. Native/mobile IME and authenticated production behavior remain outside this proof.
- **Automation limits:** an early disposable transport re-finalized its incoming request, and Item's generic serialization did not preserve the API's `variants` envelope; the strict probe was corrected, not allowed to fall through. Semantics-only scroll offsets and screenshots disagreed, so photo/stock acceptance uses real wheel-rendered images. A wrong city-path wait timed out despite visible city controls; a fresh replay observed the correct `/api/users/cities` response. These automation errors are not a clean-console claim.
- **Cleanup:** removed the disposable card/state probe, mixed transport entry/bundle and screenshot index after proof; closed both owned browser tabs and stopped both isolated servers. Current browser/Figma captures and the canonical fixture release remain ignored. Unrelated Flutter processes were not stopped.

### Implemented changes

- **Readable shared components:** body/actions 16 px, secondary text 14 px, auxiliary text at least 12 px; inherited text scaling remains enabled. One flow-based `ProductCard`, shared quantity controls and content-sized rows replace the narrow/wide copies and fixed-height metadata. Grids/strips adapt their columns and heights.
- **Home/navigation:** static logo, five 44 px header actions, consistent gutters/section gaps, adaptive store/search/campaign content and category captions. Category artwork remains 98 px; columns adapt from one to three. No drawer, replacement sidebar or bottom tabs. Full-screen profile and explicit `AppDestination` login/notification continuation replace ignored tab-index flags. Missing bonus data is not shown as a zero balance or invented QR.
- **Cards/authentication:** profile, payment and certificate use the existing `/user/cards?source=halyk` envelope; full-info masks are account summaries, not chargeable IDs. Safe partial reads retain valid rows and expose rejected data. Reads/link preparation exit loading after 12 seconds; retries reject stale completions. Cancellation invalidates the binding baseline until a complete refresh. Reauthentication returns to the requesting route, preserving order/certificate/cart identity; required profile completion stays in the same login route. SMS code entry is a real labelled, writable six-digit field.
- **Pricing/configuration:** one `CartItem.calculatePrice` breakdown feeds preview/cart/checkout. ADD charges stay outside base promotions; REPLACE substitutes base; FIXED discounts clamp per replacement rate. Exact whole-container allocation supports structured fractional/ml capacities and refuses impossible targets. Atomic staged edits validate required selections, stock, sibling collisions and one promotion snapshot before replacing rows. Explicit mixes survive merge/reload; grouped order serialization conserves paid/free volume. Public category/search metadata did not establish a same-store contract mismatch: the initial comparison used different stores/products.
- **Clarified gift policy:** paid drink selection remains separate from physical volume. SUBTRACT gifts extend exact whole-container capacity; every ADD bottle, including gift-volume bottles, retains its ordinary tariff outside drink discounts. Cart total/counter and order rows show physical litres. Paid counts drive edits/stepping; a persisted exact gift mix prevents re-gifting on reload and preserves representable repeat/batch mixes. Repeated orders recover a valid paid/free split from fulfilled physical quantities; impossible groups are explicitly refused, not inflated.
- **Authoritative Kaspi presentation:** `docs/kaspi.txt` links [«Оплата с Kaspi.kz»](https://www.figma.com/design/pNQjZoaE1v2Ud2cpqtU4sq?node-id=6192-46556). Official SVG exports supply compact mark/Gold badge, dark/light full logos and the intact compact payment button. One red button style, full-width accessible hit-area, 52 px height, official object positions, no tint/effects and required clear space replace the generic bank glyph/action. Ordinary text scales; brand artwork is not reflowed/redrawn. Link progress/pending/errors use official contrast-appropriate logos. Kaspi reserves the existing durable guard before link creation; unknown/completed states use neutral status/refresh controls, and only explicit refusal restores a charge action.
- **Payment safety:** `OrderPaymentGuard` reserves persisted per-order state before POST. Unknown outcomes stay locked across history/detail/new consumers and preference-cache reload; no TTL or new endpoint. Old refusal reads cannot unlock a newer attempt. Storage failure sends no charge request. Unresolved detail shows refresh, not Pay or Repeat; confirmed state remains terminal. Long order names now occupy the full content width above price/quantity, rather than a fixed side slot.
- **Remaining active families:** themed scrolling startup/profile/birthday/permission surfaces, feature FAQ, readable bonuses and unavailable-data feedback reuse `lib/design/*` and `lib/ui/*`. Unsupported scanner/unread-count/bonus-percentage decorations were removed. Light card confirmation uses readable black text on green.
- **Cleanup:** removed the proven-unreachable legacy shell/screens and private card/cart/search/dialog helpers, drawer, `ProductCardWide`, duplicate FAQ/theme stack, refractive widget/shader, orphan implementation assets/fonts/tests and unused `ItemVariant`. Removed `carousel_slider` and `scrollable_positioned_list`; live quantity formatting moved from deleted globals to `lib/core/quantity.dart`. Legal material, splash/platform entries and dynamic assets remain. Declared `path` and the required Cupertino icon font dependency; packaging reports no missing icon-font warning.
- **Verification cleanup:** removed the temporary matrix probe and closed both verification browser tabs and isolated fixture/release HTTP servers after final smoke. Useful Figma reference/capture caches remain ignored.

### Historical integration — superseded by the current remediation gate

| Check | Previously observed result |
|---|---|
| Focused cart/bottling/configuration/checkout/repeat/payment regression run | 78 passed |
| `flutter test --coverage --concurrency=1` | 297 passed; LCOV: 10,549 / 14,471 executable lines, 72.90%, across 94 recorded files |
| Removed throwaway render probe | 882 passed: all 41 surfaces × 320/375/800 widths × 1×/1.6×/2× × both themes, plus 300 px keyboard insets for 12 relevant surfaces at the two larger scales; render exceptions and unexpected fixture requests asserted absent |
| `dart analyze lib test tool` | No issues found |
| `dart run tool/verify_surface.dart all --theme both` | 82 captures at 750 × 1624; 50 applicable frame comparisons completed; 16 capture-only surfaces per theme |
| `flutter build web --release --no-wasm-dry-run -t tool/dev_surface.dart -o .figma_cache/quality_gallery_web` | Release fixture gallery built |
| `flutter build web --release --no-wasm-dry-run` | Current tracked `build/web` built |

Coverage describes recorded executable lines, not complete app/backend acceptance. Comparison tests have **no golden threshold**; successful measurement is not a Figma pixel-match verdict. Current metrics, capture-only IDs and visual departures are in `FIDELITY.md`.
The default-concurrency coverage attempt failed with Dart out-of-memory errors and was not accepted. The full suite was then completed with `--concurrency=1`, not reduced or skipped. A Kaspi refusal regression initially checked the durable state while its failure notice still owned the busy reservation; the assertion now checks the consumer-visible retry state after dismissal, without weakening production payment protection.


### Historical fixture/browser observations

- Home logo left the active route unchanged; profile opened normally. Store cancellation preserved scope; confirmation changed the header/data source. Submitted search produced a genuine empty state. Home resize 375 → 320 → 800 → 375 with 2× light text was reviewed.
- Synthetic bank cancellation did not confirm binding. Baseline refresh/re-add and explicit bank confirmation followed by canonical-list refresh proved a new ID; the light success text is black. A stalled card read exited at 12 seconds and recovered on retry. Synthetic phone `+70000000000` / code `123456` reauthentication returned to cards through the real writable OTP control.
- Captured store-6 item 30318: one 2 L bottle = **5300 ₸** in preview/cart and created-order detail; pickup with the synthetic 30 ₸ bag = **5330 ₸**. An unsaved 3 L / 8010 ₸ edit was discarded, retaining 2 L / 5300 ₸.
- Explicitly synthetic item 9201: .5 + 1.25 L = **1.75 L / 4750 ₸**; created rows itemize **1400 + 3350 ₸**, pickup/bag total **4780 ₸**. Synthetic REPLACE item 9202: **1.25 L / 500 ₸**, pickup/bag total **530 ₸**. The fixture resolver matches request rows to the original current-cart paid/gift snapshot, prices drink only on its paid quantity and all physical containers normally, and rejects unknown/mismatched/omitted rows. It has no made-up price or production fallback; physical gift rows cannot earn a second gift.
- Before the clarified fix, captured item 1186 with paid 1 L + 3 L showed **4 L / 3820 ₸**, with no containers for its 2 gift litres. After: **6 physical L / 3920 ₸**, bottles **1×1 L + 1×2 L + 1×3 L**. Doubling preserved the exact mix: **12 L / 7840 ₸**. Reopen/save did not inflate litres; pickup with the 30 ₸ fixture bag was **3950 ₸**, and create → synthetic payment → detail → Repeat preserved that checkout amount.
- Literal synthetic 3+1 item 9301: three paid 1 L bottles became **4 physical L / four ordinary 100 ₸ bottles / 3400 ₸**; preview, physical cart counter and created-order detail agreed. Reopen/save stayed stable; pickup/bag total was **3430 ₸**. Selecting a paid 3 L bottle (150 ₸) plus the added 1 L gift bottle (100 ₸) gave **4 L / 3250 ₸**; detail itemized **3150 + 100 + 30 = 3280 ₸**, without per-row re-gifting or invoice-rounding drift.
- Actual Kaspi fixture action opened the served, explicitly synthetic bank page, not a real bank. Official red compact action and selection mark/Gold badge were reviewed in both themes. Progress/pending/refusal and server-completed navigation were exercised; pending/unreadable state removed the charge action, and explicit refusal restored it only after the notice closed. No support message or real payment was sent.
- Final Kaspi notice replay at **320 px / 2× dark** kept the official logo intact and both dismiss/support actions readable. Kaspi-only 16 px horizontal dialog insets provide room without reducing text scale; card notice styling is unchanged. The final tracked release was rebuilt and its fresh intro entry smoke-reviewed again at 375 × 812 / DPR 2.
- Unreadable charge acknowledgment → actual history → same detail kept Pay and Repeat unavailable; refresh remained locked, and return to payment kept Pay disabled. Seeded ordinary rows itemized **13170 + 79020 + 13170 + 30 = 105390 ₸**, matching the summary. The unresolved footer was also reviewed at **320 px / 2× dark** with its refresh action reachable.
- The previous 39 dark/light baselines were reviewed through contact sheets; added Kaspi and 3+1 baselines received full-size review in both themes. Changed gift cart/configuration/checkout/order and Kaspi states received browser review. Kaspi uncertainty was reviewed at 320 px/2× and resized to 800/375; direct URL fixtures now use one app navigator so notices share the intended text scaler. The final long-name order row was verified from a fresh bundle after bypassing HTTP/service-worker caches.
- Fresh tracked release at **375 × 812 / DPR 2** rendered intro → actual city onboarding. Production network evidence was **GET `/api/users/cities` → 200** plus OPTIONS preflight, without SMS/account/order/payment mutation. OneSignal/Sentry were blocked by the verification allowlist; initial requests aborted by the deliberate reload are not app failures. No non-request browser error was observed in that release replay.

Automation had wrong-label/text waits, a multiline-name selector mismatch, earlier malformed fixture phone attempts and the previously recorded modifier-key error. City text waiting timed out despite loaded visible semantics and GET 200; observed controls/screenshots proved the route. Corrected native-input/observed-ID journeys are the evidence; this is not a globally error-free automation claim.
- Follow-up cleanup removed the 882-case throwaway probe and served synthetic bank HTML, closed all owned verification/bank tabs and stopped both follow-up HTTP servers. Useful ignored Figma/capture caches remain; unrelated running Flutter processes were not stopped.

### Verification limits

The former gift/Kaspi prerequisites are resolved by the user's clarification and supplied Figma. The available personal-session read still returned **HTTP 401** from full-info; it was not renewed or re-probed. No authenticated production card list, real bank binding/payment, certificate/order mutation, native permission lifecycle or real mobile IME is established by fixtures. Production remained read-only. Client gift arithmetic/packing and official presentation are verified separately from authenticated production/native-bank behavior.


## 1. How to pick this up

| Thing | Where |
|---|---|
| Design source of truth | `figma.com/design/HYTqbt63dc1ediNylJF7pt` — «Градусы24 Приложение», 106 screens × 2 themes, 375 × 812 |
| Design dump (regenerate) | `dart run tool/figma_spec.dart spec` → `.figma_cache/spec/` (212 frames) |
| Design token scales | `dart run tool/design_report.dart` → `.figma_cache/report.md` |
| Frame renders (compare against) | `dart run tool/figma_spec.dart png --page "Design System (Dark)"` → `.figma_cache/shots/` |
| Fixture capture/diff | `dart run tool/verify_surface.dart all --theme both` → ignored `.figma_cache/render/`; 41 surfaces × 2 themes, 25 comparisons per theme |
| App running locally | `flutter run -d windows -t tool/dev_surface.dart` — strict synthetic gallery with width/text-scale/theme controls |
| Credentials | `.figma-token`, `.figma-design` (git-ignored); API session in `.figma_cache/session.json` |

**Authentication verification.** The saved personal session returned 401; do not renew it or repeat the failed probe during read-only verification. Use the strict gallery instead. Its synthetic sign-in accepts only `+70000000000` / `123456`; it sends no real SMS. Direct fixture selection supports `surface`, `theme`, `scale`, `keyboard`, `cards` and `payment` query parameters, for example `?surface=cards&theme=light&cards=readTimeout`.

**Verifying in a browser.** Flutter web renders to a canvas. Enable its accessibility placeholder to inspect semantics, then use observed controls and native pointer/keyboard events. Re-observe after navigation and wait for route transitions before using new element IDs. For reference screenshots explicitly set 375 × 812 / DPR 2; fixtures supply the 48 px top / 34 px bottom insets. Production web has no simulated status-bar inset.

Use native typing into the focused Flutter editor. In this pass `browser.fill` produced a Flutter framework logical-key lookup exception; replay with native typing is recorded separately, not silently counted as an error-free first attempt. Release browser inspection does not use the debug-only Dart runtime MCP server.

---

## 2. Current constraints and defaults

| # | Question | Default I am using | Why it matters |
|---|---|---|---|
| 1 | **Navigation:** the account action opens the full-screen profile; the user requires deletion of the logo-driven drawer. No bottom tabs or replacement drawer. | **Static logo; full-screen profile** | Header/profile actions preserve supported destinations; G5 owns clean removal |
| 2 | **Search idle state**: the frame draws the field alone at y = 60 with no header; I keep the consistent header («Поиск» + back) in all four states. | **Consistent header** | Cosmetic, 1 argument |
| 3 | **Option flows exist but have no exact Figma frame.** Active option/bottling details now use shared design primitives, required single/multiple and optional choices, whole bottle counts and exact-group cart edits. | **Rebuilt, capture-only** | Preserve frozen pricing and supported behavior without borrowing a simple-product frame as configuration conformance |
| 4 | **Scheduled delivery** («Запланировать»), **rating + tips** («Как всё прошло»), **notifications inbox**, **card deletion**: the design has them, the frozen backend has no endpoint. 15 frames, excluded per your "build only what the backend supports". | **Not built** | Scope; revisit if the backend grows |
| 5 | **Client bottling/option regressions are repaired; gift packing/tariff is unverified.** Structured identities/units replace capacity/name guesses; ordinary choices such as «Лайм» and «Классический» remain selectable. | **Behavioral persistence/pricing regressions; explicit G4 prerequisite** | Exact selections, sibling groups and bottle mixes survive save/edit/reload; anonymous metadata is not a gift-container contract |
| 6 | **Money separators**: the design's own text is inconsistent — price `'11\xa0853 ₸'` (NBSP) but saving `'Выгода 1317 ₸'` (no separator). I format both with NBSP. | **One formatter, NBSP** | Cosmetic |
| 7 | **Banner artwork can be missing/failed.** Display actual campaign title/subtitle and CTA for a valid promotion ID. Hide the strip when there are no campaigns. | **Useful campaign copy, no blank placeholder** | No invented promotion destination or reserved empty advertising panel |
| 8 | **Trailing spaces** in API names («Белое ») are trimmed on display. | **Trim** | Cosmetic |

---

## 3. Historical decisions and implementation evidence

* **Portrait requested** on mobile: Android manifest, iOS supported orientations and
  `SystemChrome` in `main.dart`; web is not locked. Android 16 ignores portrait requests
  on displays with smallest width ≥ 600 dp, so large-screen layout must remain responsive.
* **One typeface**, TikTok Sans (OFL-1.1), bundled. The *variable* file, not statics: measured
  against the design's own text boxes, 16 pt statics drift −6 % at 8 px and +1.7 % at 20 px, while
  `opsz = fontSize` lands within 1 %.
* **Both themes**, following the OS (`ThemeMode.system`), with the sidebar's toggle overriding —
  the design has «Тема оформления» on `Профиль - Переключение свитчей`.
* **No second style layer**: `lib/design/` is the only source; `AppColors`/`globals.dart` are
  deleted with the pages that import them (still pending — see §5).
* **Sidebar instead of tabs**; the only floating control is the cart button — a 78 px scalloped
  disc when empty, the 133.2 × 42 pill with count + total when filled (`Поиск - Удачный поиск`).
* **`ProductCard` not-in-cart state is a lone «+»**, not «− 0 +» (the design's second grid card and
  the old card's `canDecrease ? count : ''` agree).
* **Catalogue row/card copy** comes from the API; nothing invented. `presentItemName`,
  promotion maths, bonus rules and the like-toggle flow are reused verbatim from the frozen layer.
* **Icons exported from the file** where Figma's image API allows it. It refuses three nodes —
  `Store_Icon_UIA`, the search field's scan glyph, and `vuesax/bold/heart` — so `store` uses the
  same-family shop glyph, `scan` is drawn (five bars), and the search row's heart is Material's.
  The product page's heart is the outline one and is exported properly.

---

## 3b. Cart specifics (built after your last message)

* **Delete rule — implemented.** At one unit the minus slot becomes a deliberate delete button; the
  cart's trash glyph is custom-painted so it renders without relying on a Material-font glyph absent
  from the test/browser rendering environment. The line is never silently removed by decrement.
* **«Вам также может понравиться» has no endpoint.** The strip is filled from the **first cart
  line's category**, excluding items already in the cart (max 6). This is an inference, not the
  design's data — if a recommendations endpoint appears, replace `_maybeLoadRecommendations`.
* **Empty cart is undesigned.** The cart frames contain no empty state, so the screen shows a
  plain «Корзина пуста» with a «В каталог» action.
* **Row metrics**: 343 × 60, r10, pitch 64; artwork 52 × 52; title 16/500; origin 10/400 muted;
  **line total** (not unit price) 16/700 in the accent; step control 77 × 33 whose minus is bare
  and whose plus sits in a 21 × 21 accent pill.
* **Strip cards** are a third measured variant (160 × 244, `ProductCardWide`): badges side by side,
  origin stacked on the right, artwork 152 × 159.
* **«Оформить» opens the rebuilt checkout.** Supported delivery/pickup, quoting, benefits, order creation and confirmed payment use their existing APIs. Mutating verification is strictly synthetic; see §3ai.

---

## 3c. Two things the light theme taught us

1. **The design separates floating controls by a shadow, not a fill.** The 40 px discs are
   `#FFFFFF @ 75 %` on a `#FFFFFF` background in light mode — invisible without their
   `#000000 @ 16 %, blur 8, offset (0, 4)` shadow. That single recipe is now `AppShadows.control`
   (both palettes carry it) and is applied to the discs and the round cart button; the pill CTAs
   carry none, exactly as the frames show. It also fixes the cart button's missing shadow, whose
   SVG drop-shadow filter `flutter_svg` ignores.
2. **Theme choice persists.** `lib/core/theme_controller.dart` stores the mode
   (`theme_mode`), the app follows the OS by default, and both the sidebar and the profile row
   drive it. Verified live: toggling «Тема оформления» switched the running app to light, and it
   came back light after a full rebuild.

The profile's theme row reflects the **effective** theme (so "following the OS into dark" reads
as on), while the switch pins an explicit mode when touched.

---

## 3d. Orders

* **History list built** (`lib/features/orders/ui/orders_page.dart`): 343 × 114 cards, pitch 118,
  humanised dates («22 сентября в 06:58»), «№N», «Сумма», and the status in the top-right —
  error red when cancelled, muted otherwise. Status text comes from the frozen
  `orderStatusLabels`.
* **«Начислено» is computed, not fetched.** The order payload has **no** earned-bonus field
  (`cost_summary` carries `bonus_used`, not `bonus_points`), so the line is derived from the
  order's items with the cart's own rule — 3 %, tobacco excluded. Verified live: the tobacco
  order shows no accrual, a 3 200 ₸ order shows exactly **+96 бонусов**.
* **Backend gap found:** one order carries `status: 67` with `status_description:
  «Неизвестный статус»`, which the frozen helper turns into «Статус 67». The app cannot label a
  status the backend does not name — a data issue to raise, not a code one.
* **Order detail (`Карточка заказа`) is still the legacy page**; its card is the next orders step.
* The design's status wording differs from the app's frozen map («Собираем (15-30 мин)» vs
  «Собирается», «Доставлено» vs «Доставлен»). The app's real labels win.

## 3e. FAQ — needs a content decision

The design's FAQ asks «Как оформить заказ?», «Какие способы оплаты доступны?» and so on. The app's
FAQ is 44 different entries grouped into 7 sections («Авторизация, Профиль и Сбои приложения»,
«Оплата, Удаленные счета и Расчет стоимости», …) and **none of the design's questions exist in
it**. Rebuilding the screen therefore means choosing content:

* default I would take: keep the app's 44 real entries, add the design's accordion row treatment,
  and keep the section titles as group headers;
* the design's screen is a flat list with no search, while the app's FAQ has search — I would keep
  the search as an addition rather than drop a working feature.

## 3f. Bonuses

* **History screen built** (`lib/features/bonuses/ui/bonus_history_page.dart`): «Баланс» header, a
  343 × 56 balance card (total 32/900 in the accent, «Как работают бонусы?» link), then 343 × 63
  rows. Verified live: balance 1000, one entry rendered as «+1000 бонусов» in gold with the
  timestamp converted to local time («3 ноября в 04:30»).
* **The design's row title has no data source.** `/bonuses` history entries are
  `{bonusId, organizationId, amount, timestamp}` — no order reference and no entry type, so
  «Заказ №45» from the frame cannot be rendered. The row shows the signed amount and its date.
* **The explainer is design-only content.** The app had no «Как работают бонусы» screen, so
  `bonus_how_it_works_page.dart` carries the frame's copy verbatim (1 бонус = 1₸, the three-step
  accrual, the 25 % spending cap, tobacco/delivery exclusions, the FAQ pointer). Its sizes follow
  the frames — body text is 10/400 there, which is genuinely small but is what the design asks for.

## 3g. Certificates

* **Screen built** (`lib/features/certificates/ui/certificates_page.dart`): the code-activation row
  (246 px field + 85 px «Ок»), the «Купить сертификат» row, a content-sized three-way filter
  (`active` / `redeemed` / `canceled` — the app's own status values, verified live by
  `certificates?status=active`), and 343 × 71 rows (name 20/700 accent, amount 16/500, state line
  green/muted/error). The account holds no certificates, so the empty state is what renders —
  «Сертификатов нет» + «Активируйте код или купите новый сертификат».
* **Purchasing is bridged, never executed.** «Купить сертификат» opens the **legacy** purchase
  flow, because buying involves a real payment. No verification run submits it.
* **Claiming is wired** (`claimCertificate`) with a snackbar result; the design shows no claim
  result frame, so the feedback is a snackbar rather than an invented screen.
* The certificate payload's amount key is undocumented, so the row tries
  `amount/balance/value/denomination/face_value` and hides the amount when none is present rather
  than printing a wrong number.

## 3h. Certificates placeholder (by request) and the intro slides

Historical decision, superseded by §3ag: the certificate placeholder is removed and all active callers now enter the feature certificate page directly. The intro-slide implementation below remains separate from queued city/location onboarding.

* **Certificates is now a placeholder**, as asked: `certificates_placeholder_page.dart` — a
  new-styled stub whose action opens the detailed screen, which in turn bridges to the legacy
  purchase flow. Nothing was lost by parking this area: activation and purchase stay reachable,
  and the detailed implementation is intact at `features/certificates/ui/certificates_page.dart`
  (nothing in this session is committed, so deleting it would have destroyed it).
* **The four intro slides are built and live** (`lib/features/onboarding/ui/intro_slides_page.dart`):
  the wordmark at y = 70, a 100 px accent badge with a 68 px glyph, title 20/700, body 14/400
  muted, and the constant «Войти или зарегистрироваться» pill. Copy is the frames' own
  (Персональные акции / Быстрый заказ / История покупок / Бонусы).
  * The frames contain **no pagination dots**, so none are drawn — the slides advance by swiping.
  * Two asset traps worth remembering: the slides' glyph layers are **all named**
    `vuesax/bold/discount-shape` in the file while exporting three different shapes, and the
    exported **wordmark is white-on-transparent** (drawn for the dark theme) so it must be tinted
    from the palette or it vanishes on the light theme.
  * Gated by its own `intro_slides_seen` preference in `AppEntryGate`, **not** by
    `OnboardingService` — the slides are independent of the city/permission onboarding that
    follows them, so the frozen service was left untouched.
* **Still to do in this cluster:** the phone-entry, code-entry and address screens.

## 3i. Non-content states consolidated

`lib/ui/app_states.dart` now owns `AppEmptyState`, `AppErrorState` and `AppLoading`. Every rebuilt
screen had grown its own private copy — six near-identical `_Centered`/`_Message`/`_Empty` widgets
— which is precisely the drift the redesign exists to remove. The eight affected screens
(favourites, cart, orders, bonuses, certificates, category, supercategory, search) now share one
implementation.

The design's conventions are encoded in the widget: empty = centred 20/700 title over an optional
14/400 muted subtitle, with a `muted` flag for the frames that use `#676767` instead of white
(«Товары не найдены», «История пуста»); error = the same shape with an optional retry, because the
FAQ frame is the one place the design shows an error and it has **no** button.

**Follow-ups:** `authentication_wrapper.dart` still carries its own `AppLoadFailed` for a failed
home load — the ninth copy, left alone to keep this refactor bounded; and true *offline* handling
(no connectivity) is not addressed anywhere, since the design never draws that state.

## 3j. Process note

The consolidation broke the build for one step: three files had their private classes deleted while
their call sites didn't match the patterns I searched for, leaving dangling `_Message`/`_centered`
calls. `dart analyze` caught every one and they are fixed — but the lesson is the one that bit me
twice before in this session: **verify each scripted replacement actually matched** (count your
replacements) instead of trusting the script's own progress output.

## 3k. Handoff: what to review

**Nothing in this session is committed.** `git status` now reads **8 modified + 11 untracked**
entries — deliberately small:

* modified: `.gitignore`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`,
  `lib/main.dart`, `lib/widgets/app_entry_gate.dart`, `lib/widgets/authentication_wrapper.dart`,
  `pubspec.yaml`, `pubspec.lock`;
* untracked: `lib/design/`, `lib/ui/`, `lib/core/`, `lib/features/`, `test/design/`,
  `docs/redesign/`, `assets/fonts/TikTokSans/`, `assets/icons/design/`, `tool/figma_spec.dart`,
  `tool/design_report.dart`.

**The legacy code is untouched.** At one point `git status` showed 54 modified files because I had
been running `dart format lib` (the whole tree) instead of formatting only the files I edited.
Every one of those extra 46 files was verified **token-identical to HEAD** (whitespace stripped,
MD5 compared) and reverted, so the frozen data layer, pages and services are byte-for-byte as
they were. Format only the files you touch — `dart format <paths>`, never `dart format lib`.

Verification after the revert: `dart analyze lib` → 0 errors, 0 warnings;
`flutter test test/design/components_test.dart` → 11/11.

## 3l. Accessibility pass (partial, with what remains)

Audit of the new code: **41 `GestureDetector`s, 0 `Semantics`**. Two findings, handled differently.

1. **Icon-only controls had no labels** — a screen reader would announce the bare glyphs of the
   −/+ steppers, the like hearts, the buy row and the filter tabs. Fixed for the most-used
   component: `StepTap` in `lib/ui/product_card.dart` wraps the card's −/+ in
   `Semantics(button: true, label: 'Убрать/Добавить одну штуку')`. **Still to do:** the same
   treatment for the row stepper and like button (`lib/ui/product_row.dart`), the cart's stepper,
   `AppIconButton` (its discs carry tooltips but not `Semantics` labels), and the filter tabs.
2. **Tap targets are below the 44 dp guideline** — the card's −/+ hit areas are 12 × 30 dp, the
   row's 14 × 30. **Not "fixed":** the frames' entire control is only 30 dp tall and 102 dp wide
   (77 dp on rows), so reaching 44 would mean distorting the design. This is a decision for the
   designer — raise it, don't paper over it. Widening the zones to ~28 dp each is the most the
   layout allows (the count would otherwise be squeezed), if a middle ground is wanted.

Other checks that passed without work: every icon disc already carries a `tooltip`, text uses
`MediaQuery`-driven scaling untouched by the redesign, and nothing in the new code hardcodes a
min/max text scale or disables the semantics tree.

## 3m. Docs and the release note

* **Docs are covered by this file.** `docs/redesign/STATUS.md` is the living record for the
  redesign; `docs/redesign_instructions.md` (pre-existing) remains the design doctrine. Every
  legacy `docs/*.md` topic note is untouched and still accurate, because the frozen data layer,
  API and business rules were not modified.
* **There is no `CHANGELOG.md` in this repo**, and the redesign is unreleased — nothing is
  committed and `pubspec.yaml` still reads `1.2.113`. Writing a changelog now would document a
  version that does not exist, so the entry is staged here instead, ready to paste when the
  redesign ships:

```markdown
## 1.3.0 — redesign (in progress)
- New design system: tokens, light/dark themes (OS default with a manual override), TikTok Sans,
  and icons exported from the design file. `lib/design/`, `lib/ui/`
- Screens rebuilt to the design: home, catalogue → category → search, product detail, favourites,
  cart, orders, profile, bonuses + explainer, intro slides. Certificates is a placeholder.
- Cart: explicit delete button replaces the implicit removal when the last unit is decremented.
- Architecture: feature-first `lib/features/*`, navigation intent enums, shared empty/error/loading
  states, one money formatter. Legacy data layer and business rules untouched.
- Removed: `flutter_motion_kit`, `path_drawing` (unused; the latter also blocked a Flutter upgrade).
- Pending: checkout (delivery/pickup), addresses & cards, FAQ/support/notification settings, the
  auth screens after the intro slides, and the removal of `AppColors`/`globals.dart` with the
  legacy pages they belong to.
```

## 3n. Accessibility — completion, plus a correction to my own audit

**Correction first.** §3l counted `Semantics(` occurrences and concluded that icon-only controls
had no labels. That was partly wrong: Flutter's `Tooltip` **already attaches a semantic label**, and
every disc in `AppIconButton` is created with one, so the top-bar back/search/like controls were
announcing correctly all along. The genuine gap was only the glyph-only controls.

**Now labelled:**

| Component | Labels added |
|---|---|
| `ProductCard` stepper | `StepTap` — «Убрать одну штуку» / «Добавить одну штуку» |
| `ProductRow` stepper | `_SemanticTap` — same pair |
| `ProductRow` like disc | `_SemanticTap` — «В избранное» / «Убрать из избранного», state-aware |
| Cart stepper | `_SemanticTap` — «Убрать одну штуку» / «Добавить одну штуку» |

Controls with visible text (the filter tabs, the CTAs, the activation button) need nothing: a screen
reader reads their label already.

**Still open, and it is a design decision, not a code task:** the step controls' tap targets are
12–14 × 30 dp, well under the 44 dp guideline. The frames' whole control is 30 dp tall and 102 dp
wide (77 on rows), so reaching 44 would mean distorting the design — raise it with the designer
rather than fixing it silently. Widening the zones to ~28 dp is the most the layout allows before
the count gets squeezed.

## 3o. Performance pass — done, and it ends with a retraction

**Retraction of my own first finding.** The audit initially flagged
`context.watch<CartProvider>()` inside `itemBuilder` as "one dependency per card" — that was wrong,
and I checked it before touching anything. The `context` a sliver's `itemBuilder` receives belongs to
the element created for **that child**, so the dependency registers on that card's element and the
rebuild is already scoped to the single card. `category_products_page.dart:151`, `search_page.dart:188`
and `favorites_page.dart:200` are **correct as written** — worth not "fixing". (That is the third
overstated audit finding this session; all three are corrected in place, because a record that
inflates work is worse than no record.)

**The one real observation, and why it stays.** Nine screens hold
`final cart = context.watch<CartProvider>();` at page level to feed the floating cart button
(`bonus_history:79`, `cart:104`, `category_products:76`, `supercategory:95/342/445`,
`certificates:114`, `favorites:115`, `orders:70`, `product:71`, `search:97`). Any cart change
therefore rebuilds the whole page rather than just the button — roughly 9–12 visible cards of wasted
work per tap.

Measured against the alternative, that is **not worth a nine-file refactor**: the widgets are
const-heavy, the rebuild happens on a human tap (not per frame, not in a list scroll), and the
visible-card count is bounded by the grid. Extracting a `CartButtonHost` that watches on its own
would scope it, and it stays on the list as an optional tidy-up — not a defect, and explicitly *not*
something to do while the remaining screens are unbuilt, because touching nine working pages to save
a bounded tap-time rebuild is how regressions get introduced.

**Conclusion for this item: no significant rebuild problem in the rebuilt screens.** The genuinely
heavy files are the legacy ones (`main_page.dart` 98 KB, `checkout_page.dart` 97 KB) — and profiling
them would be wasted effort, because both are being replaced (`main_page` already is). One caveat
carried forward: `CartProvider` is a single large `ChangeNotifier`, so any of its fields notifying
rebuilds every watcher. If it grows past cart/quantity concerns, split it then — with a measurement,
not on suspicion.
## 3p. Auth after the slides — recon done, screens NOT built

Gathered so the next run doesn't re-derive the flow. **`lib/pages/login_page.dart` (778 lines) is the
whole auth story**, and it is already half-replaced: `_onboardingView()` and `_slidePage()` are dead
weight now that the rebuilt intro slides shipped, and `_startAutoSlide`/`_onCarouselInteraction*` go
with them.

**What stays untouched (frozen contract, do not rebuild):**

| Region | Lines | Contract |
|---|---|---|
| `_sendCode()` | 199–237 | `ApiService.sendAuthCode(phone)`; reads `result.cooldownSeconds` and arms `_startSendCodeCooldown` |
| `_startSendCodeCooldown` / `_sendCodeButtonLabel` / `_formatCooldown` | 238–282 | resend timer, `phone`-keyed |
| `_verifyCode()` | 283–350 | `ApiService.verifyAuthCode(phone, code)` → `NotificationService.instance.syncTokenWithServerIfNeeded()` → `Navigator.pushAndRemoveUntil` |
| `_normalizedPhone` / `_ensurePhonePrefix` / `PhoneTextInputFormatter` | 13–67, 181–198 | `+` + 11 digits — WhatsApp delivery depends on this exact shape |

**What is to be rebuilt — presentation only:**

| Region | Lines |
|---|---|
| `_authFormView()` | 514–605 |
| `_phoneInput()` | 606–658 |
| `_otpInput()` | 659–740 |
| `_primaryButton()` | 741–771 |

Roughly 260 lines whose only job is layout, and which currently draw with `AppColors.orange` and
Material icons instead of the design tokens. The rebuild is: same four methods, same state fields
(`_codeSent`, `_isLoading`, cooldown), design-styled bodies on `AppPalette`.

**Before writing a line:** export the auth frames from the real Figma file (note the frame names are
not in `.figma_cache/spec/_index.json` — the earlier dump keyed pages rather than frames, so run
`tool/figma_spec.dart png` for the auth page first and confirm the phone/code/address frames and
their exact copy). The address step is a third screen and belongs to the addresses item, not here.

**Why this is not done:** it is one 778-line file with a live API flow behind it, and it needs the
frames exported first. Starting it without the frames would mean inventing the layout, which is the
one thing this project has consistently refused to do.

## 3q. Frame inventory for every remaining item (read off the real file)

`dart run tool/figma_spec.dart frames` lists 212 frames across both theme pages. These are the
dark-page node IDs — the exact handles for `spec`/`png` export, so no screen has to be invented:

**Checkout (Корзина - Доставка / Самовывоз / оплата)** — 13 frames

- `2093:9880` Корзина - Доставка - Скролл ниже 1
- `2093:10070` Корзина - Самовывоз
- `2093:10241` Корзина - Самовывоз - Скролл ниже
- `2093:10412` Корзина - Доставка - Выбор магазина
- `2093:10696` Корзина - Доставка - Выбор времени доставки - Сейчас
- `2093:10907` Корзина - Доставка - Выбор времени доставки - Запланировать
- `2093:11105` Корзина - Доставка - Выбрано Запланировать
- `2093:11276` Корзина - Доставка - Скролл ниже 2
- `2093:11805` Корзина - Доставка - Скролл ниже 3
- `2093:11976` Корзина - Доставка - Акционный товар
- `2093:15859` Корзина - Проводим оплату
- `2093:15871` Корзина - Оплата прошла успешно
- `2093:15888` Корзина - Ошибка оплаты

**Addresses (Адреса)** — 6 frames

- `2093:8928` Адреса - Добавленный адрес
- `2093:8964` Адреса - Нажатие на 3 точки
- `2093:9011` Адреса - Детали адреса
- `2093:9034` Адреса - Детали адреса - Заполненное поле
- `2093:9053` Адреса - Карта
- `2093:9274` Адреса - Карта - Ввод в поисковую строку

**Cards (Карты)** — 3 frames

- `2093:8745` Карты - Добавленные карты
- `2093:8801` Карты - Сообщение об успешном добавлении карты
- `2093:8861` Карты - Подтвердить удаление карты

**Auth (Регистрация и логин)** — 9 frames

- `2093:8277` Регистрация и логин - Слайд 1
- `2093:8319` Регистрация и логин - Слайд 2
- `2093:8337` Регистрация и логин - Слайд 3
- `2093:8355` Регистрация и логин - Слайд 4
- `2093:8375` Регистрация и логин - Вход по номеру телефона
- `2093:8416` Регистрация и логин - Введите код
- `2093:15823` Регистрация и логин - Укажите адрес доставки
- `2093:15843` Регистрация и логин - Загрузка
- `2093:15850` Регистрация и логин - Загрузка завершена

**FAQ** — 2 frames

- `2093:9841` FAQ - Не удалось загрузить
- `2093:9851` FAQ

**33 frames** cover the four open items.## 3r. FAQ — smaller than it looks, but its cached spec is a trap

Probed because 2 frames *look* like the cheapest remaining item. Two findings, one good, one a trap.

**Good: the data/presentation seam already exists.** `lib/pages/faq_page.dart` (1153 lines) separates
cleanly — `FaqEntry` (29), `FaqSectionData` (41), **`FaqRepository` (66, holds the 44 real entries in
7 sections)**, `FaqSearchDocument` (409), `FaqShortcutCard` (445), and only then the screen itself
(`FaqPage` 602 / `_FaqPageState` 616, i.e. ~550 lines of UI to the end of file). A rebuild replaces
**the UI only and reuses `FaqRepository`** — so this is genuinely the smallest of the four, and it
needs no content decision after all: the design is silent on copy, the rule is "build what the app
needs", and the app's own 44 entries are the right content. The earlier open question about FAQ copy
can be closed on that basis; record it as decided, not pending.

**Retraction — the "empty spec" trap I reported was my own probe's bug.** I claimed both cached FAQ
frames parse to 0 text nodes and warned against trusting the cache. Wrong: `tool/figma_spec.dart`'s
`_compactNode` renames Figma's `characters` to **`chars`**, and my probe looked for `characters`. Every
cached frame was reported "empty" for that reason. The cache is fine, and always was — the FAQ frame
contains real copy («Как оформить заказ?», «Какие способы оплаты доступны?», «Сколько времени занимает
доставка?» plus answers). **Read specs via `chars`, not `characters`.** I did re-export both pages while
chasing this (210 frames, ~40 s, idempotent) — no harm, but no benefit either.

**Why not built now:** the design content has to be re-exported, and the UI region is ~550 lines with
search, section ranges («N ответов • вопросы X–Y») and multi-state behaviour behind it. That is not a
slice that can be finished and verified in what remains here.

## 3s. Design brief for the remaining screens (read from the verified specs)

Extracted with the correct `chars` key. Sizes are the design's own; colours are the distinct fills

> **The `fills:` column is empty and that is a probe bug, not a fact — do not conclude these frames
> are uncoloured.** My colour walk looked for a `color` map of `r/g/b` floats; the compact schema
> stores it another way. Read the `fill` / `color` keys directly (or just re-read the frame) when
> building. The **copy is verified** and is the part that costs time to transcribe.

### Checkout

- **Корзина - Доставка - Скролл ниже 1** — 375.0×812.0 · 58 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Доставка - Скролл ниже 2** — 375.0×812.0 · 58 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Доставка - Скролл ниже 3** — 375.0×812.0 · 58 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Доставка - Выбор магазина** — 375.0×812.0 · 75 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Доставка - Выбор времени доставки - Сейчас** — 375.0×812.0 · 65 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Доставка - Выбор времени доставки - Запланировать** — 375.0×812.0 · 65 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Доставка - Выбрано Запланировать** — 375.0×812.0 · 58 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Доставка - Акционный товар** — 375.0×812.0 · 62 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Пустое поле Промокод** — 375.0×812.0 · 61 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Пустое поле Сертификат** — 375.0×812.0 · 61 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Самовывоз** — 375.0×812.0 · 58 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Самовывоз - Скролл ниже** — 375.0×812.0 · 58 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира

### Addresses

- **Адреса - Добавленный адрес** — 375.0×812.0 · 10 text · fills: 
  - copy: 09:41 | Мои адреса | Добавьте адрес | Вопросы по адресу и доставке | Посмотрите ответы про GPS, ручной ввод адреса и ограничения по доставке | Открыть FAQ | Ангарская улица, 17 | Подъезд 2, Этаж 7, Кв. 45
- **Адреса - Нажатие на 3 точки** — 375.0×812.0 · 15 text · fills: 
  - copy: 09:41 | Мои адреса | Добавьте адрес | Вопросы по адресу и доставке | Посмотрите ответы про GPS, ручной ввод адреса и ограничения по доставке | Открыть FAQ | Ангарская улица, 17 | Подъезд 2, Этаж 7, Кв. 45 | Изменить адрес
- **Адреса - Детали адреса** — 375.0×812.0 · 12 text · fills: 
  - copy: 09:41 | Детали адреса | Подтвердить и выбрать адрес | Выбранный адрес | Ангарская улица, 17 | Подъезд | Например: 2 или 2А | Этаж | Например: 7 или м
- **Адреса - Детали адреса - Заполненное поле** — 375.0×812.0 · 12 text · fills: 
  - copy: 09:41 | Детали адреса | Подтвердить и выбрать адрес | Выбранный адрес | Ангарская улица, 17 | Подъезд | 2А | Этаж | Например: 7 или м
- **Адреса - Карта** — 375.0×812.0 · 13 text · fills: 
  - copy: LOWERVAILSBURG | STREET | UNION | street name | 09:41 | Караганда, улица или дом | Ангарская улица, 17 | Сначала подтвердите точку на карте, затем добавьте подъезд, этаж и квартиру на следующем шаге | Подтвердить адрес
- **Адреса - Карта - Ввод в поисковую строку** — 375.0×812.0 · 13 text · fills: 
  - copy: LOWERVAILSBURG | STREET | UNION | street name | 09:41 | Ангарская улица, 17 | Сначала подтвердите точку на карте, затем добавьте подъезд, этаж и квартиру на следующем шаге | Подтвердить адрес

### Cards

- **Карты - Добавленные карты** — 375.0×812.0 · 10 text · fills: 
  - copy: 09:41 | Мои карты | Добавить новую карту | Не получается добавить карту? | В FAQ собраны ответы по привязке карты и оплате заказов | Открыть FAQ | **** **** **** 4444 | Карта | **** **** **** 4949
- **Карты - Подтвердить удаление карты** — 375.0×812.0 · 14 text · fills: 
  - copy: Не получается добавить карту? | В FAQ собраны ответы по привязке карты и оплате заказов | Открыть FAQ | **** **** **** 4444 | Карта | **** **** **** 4949 | 09:41 | Мои карты | Добавить новую карту
- **Карты - Сообщение об успешном добавлении карты** — 375.0×812.0 · 11 text · fills: 
  - copy: 09:41 | Мои карты | Добавить новую карту | Новая карта сохранена и готова к оплате | Не получается добавить карту? | В FAQ собраны ответы по привязке карты и оплате заказов | Открыть FAQ | **** **** **** 4444 | Карта

### Auth

- **Регистрация и логин - Вход по номеру телефона** — 375.0×812.0 · 26 text · fills: 
  - copy: 3 | DEF | 􀆛 | 09:41 | Вход по номеру телефона | Отправим короткий код подтверждения | Не приходит SMS-код? | +7| | Получить код
- **Регистрация и логин - Введите код** — 375.0×812.0 · 32 text · fills: 
  - copy: 3 | DEF | 􀆛 | 09:41 | Введите код | СМС отправлено на +7 777 777 77 77 | Проблемы с кодом? Открыть FAQ | 9 | Подтвердить
- **Регистрация и логин - Загрузка** — 375.0×812.0 · 1 text · fills: 
  - copy: 09:41
- **Регистрация и логин - Загрузка завершена** — 375.0×812.0 · 2 text · fills: 
  - copy: 09:41 | Готово!
- **Регистрация и логин - Укажите адрес доставки** — 375.0×812.0 · 11 text · fills: 
  - copy: 09:41 | Подтвердить и выбрать адрес | Пропустить | Укажите адрес доставки | Можно заполнить сейчас или позже на этапе оформления заказа. Буквы тоже подойдут: корпус, секция, подъезд А, кв. 12Б. | Подъезд | Например: 2 или 2А | Этаж | Например: 7 или м

### FAQ

- **FAQ** — 375.0×812.0 · 7 text · fills: 
  - copy: 09:41 | FAQ | Как оформить заказ? | Какие способы оплаты доступны? | Вы можете оплатить заказ банковской картой онлайн или при получении, если такой способ доступен в вашем регионе. | Сколько времени занимает доставка? | Есть ли минимальная сумма заказа?
- **FAQ - Не удалось загрузить** — 375.0×812.0 · 3 text · fills: 
  - copy: 09:41 | FAQ | Не удалось загрузить FAQ. Попробуйте еще раз позже.

## 3t. The red test files — one fixed, one still open, plus a retraction

**`test/orders/orders_history_page_test.dart` → fixed, passing.** The test built the legacy
`OrdersHistoryPage` in a `MaterialApp` with no localization delegates, so `DateFormat('d MMMM y', 'ru')`
threw `LocaleDataException` and the page never rendered ("Found 0 widgets with text «Оплатить»"). Fix:
an async `setUp` calling `initializeDateFormatting('ru')`. The page's real contract — the pay action
appearing only for payable entries — is now actually exercised, which is what the test was written for.

**Retraction — I called this a live crash and it wasn't.** I added `initializeDateFormatting('ru')` to
`main()` on the grounds that nothing initialized `intl`. Wrong: `main.dart:128` registers
`GlobalMaterialLocalizations.delegate`, which loads the date symbols for the app's locale itself. That
also explains why the rebuilt orders and bonus-history screens rendered correctly on live verification
despite both calling `DateFormat(..., 'ru')`. The startup change was redundant, so I reverted it —
adding startup work to fix a bug that does not exist is exactly the weightless code this record keeps
telling me not to write. (Sixth overstated finding; the probe-vs-artifact pattern again.)

**`test/pricing/product_detail_bottling_test.dart` → still open (5 failures).** Root cause is different
and not yet diagnosed: `UnsupportedError` thrown while building a `LayoutBuilder`, so the page never
lays out and the «1250 ₸» assertions find nothing. This is a harness/constraint problem, not the
`intl` one. Left open deliberately rather than papered over — it pins the options/bottling **pricing**
logic that the legacy bridge still uses, so it is worth repairing, not deleting.

## 3u. Startup loader hang — fixed and verified live on web

**Symptom (reported):** the app never leaves the loading screen in dev.

**Cause — two of them, neither where it looked.** `AuthenticationWrapper._checkAuth()` only called
`_loadHome()` when `userInfo != null`:

```dart
if (userInfo == null) { await AuthService.clearToken(); }
else if (mounted) { await _loadHome(); }        // ← signed-out sessions never got here
```

`build()` returns `AppLoadingScreen` while `_homeData == null`, so **any signed-out or invalid-token
session sat on the loader forever**. The home screen is public — the design ships a signed-out variant
(«Главная - Без входа в аккаунт», node `2098:32279`) — so it must load regardless of session. Second:
`ApiService.getFullInfo()`'s `http.get` has **no timeout**, so a stalled `/auth/full-info` (dead dev
server) blocked the check indefinitely.

**Fix:** `_checkAuth` now bounds the check with a 10 s timeout, treats a timeout as "guest", and
always calls `_loadHome()` afterwards. `authentication_wrapper.dart` only; no API or contract change.

**Verified live** (`flutter run -d web-server --web-port=8099`, 375×950, fresh profile): slides →
onboarding 1/2 (notifications) → 2/2 (geolocation) → city picker → **the signed-out home renders** with
the real store card «Градусы24 · Бухар-Жырау 70, Караганда», the promo carousel, the «Кухня» card, all
six category tiles and the empty cart disc.

**OneSignal was not the cause, though the report was reasonable:** the onboarding's
«Разрешить уведомления» awaits `NotificationService.enablePushNotifications()`, and with no OneSignal
in dev that path is already safe — `onesignal_web_bridge_web.dart` returns `null` when the
`GradusyOneSignal` global is absent, and every bridge call carries a 10 s timeout and a catch. Tapped
it and it advanced to step 2 cleanly.

**Retraction — my own verification was lying to me.** Several turns of "0 errors, 0 warnings" came
from `grep -cE "^\s+(error|warning)"`, and `dart analyze` prints `warning - …` at **column 0**, so the
pattern matched nothing and I reported a clean tree that had **10 warnings** (all dead imports and
unused parameters from the rebuild). Fixed the filter, cleared all 10, and the tree is now genuinely
0 errors / 0 warnings. **Use `grep -E "error - |warning - "`.** (Seventh overstated/under-counted
finding — the probe, again, not the artifact.)

## 3v. FAQ rebuilt — designed, wired and verified

**Built:** `lib/features/faq/ui/faq_page.dart` — `AppTopBar('FAQ')`, the design's search field
(«Найти вопрос или ответ»), section headings, and one-card-per-question with the answer expanded
underneath. First answer opens by default, matching the frame. Content is the app's own 44 entries in
7 sections via `FaqRepository`; only the chrome is new. The palette/type idiom is `context.palette` +
`AppTypography.*`.

**Cutover (clean, no shim):** the named route `/faq` in `main.dart` now builds the new page, which
also migrates all six legacy `openFaqPage(...)` callers at once — profile, checkout, login, help chat,
order detail, payment method. `initialSection` is preserved: the list scrolls the requested section
into view, which is exactly what the legacy `_scrollCategoryIntoView` did. The wrapper's two
`_push(const FaqPage())` sites point at the new page too. The legacy `FaqPage`/`_FaqPageState` remain
in place only as the repository's home until the `AppColors` cleanup.

**Verified live** (`127.0.0.1:8099`, signed-out): sidebar → FAQ renders the real questions, the first
answer expanded, the next section heading visible below.

**Verified deterministically** — `test/faq/faq_page_test.dart`, 3/3:
1. the first question *and* its answer render (the design's open-by-default behaviour);
2. a query narrows to matches, drops a section whose entries all miss, and removes an unrelated
   question entirely;
3. a query that matches nothing shows the empty state.

Assertion 2 was wrong on first run — I asserted the matched answer stays collapsed, but that entry is
the default-opened one, so the code was right and the test was wrong. Noted because the test caught
it, which is the point of writing it.

**Deliberately not built:** the design's «FAQ - Не удалось загрузить» frame. The content is a local
constant that cannot fail to load, so a failure state would be unreachable theatre. If FAQ ever moves
behind the API, build it then.

**Still legacy in this area:** «Поддержка» (help chat) and notification settings screens. Both are
reachable and functional; neither is rebuilt to the design yet.

## 3w. Support and notifications — frames exist, and they are NOT the same screen

Recon for the last unbuilt pair, and a naming trap worth recording.

| Design frame | Node | What it is | Status |
|---|---|---|---|
| Поддержка | `2093:8576` | support chat | **buildable** — legacy `help_chat_page.dart` (1019 lines) is live and works, so a backend exists |
| Поддержка - Ввод сообщения | `2093:8635` | the chat with the composer focused | same screen, second state |
| Уведомления | `2093:8248` | a notifications **inbox** | excluded — no endpoint (one of the 15) |
| Уведомления - Уведомлений нет | `2093:8470` | the inbox's empty state | excluded with it |

**The trap:** the sidebar row «Уведомления» in this app opens `NotificationSettingsPage` — push/telemetry
**toggles** — while the design's «Уведомления» frames are an **inbox** of past notifications. Same word,
two different things. Do not "rebuild Уведомления" by reading those frames and deleting the settings
screen: the toggles are the part the app actually needs, and the inbox is the part with no backend.

Extracted copy for the chat frames:

- **Поддержка** (375.0×812.0) — 09:41 | Поддержка | Сообщение | Сначала можно проверить FAQ | Там уже есть ответы по входу, оплате, доставке, бонусам и возвратам | Открыть FAQ | Оператор на связи
- **Поддержка - Ввод сообщения** (375.0×812.0) — Проверили информацию — карта успешно добавлена и готова к использованию. Если вы столкнётесь с ошибкой при оплате, пожалуйста, сообщите нам, и мы поможем разобраться. | “The” | the | to | q | w | e
- **Уведомления** (375.0×812.0) — 09:41 | Уведомления | Хотите получать скидки и подарки? | Прочитать все | Бесплатная доставка от 10 000 ₸ | Соберите заказ на 10 000 ₸ и мы доставим его бесплатно. Выбирайте любимые напитки без лишних затрат! | 10 июня

**Not built:** the support chat is a message list plus composer over the legacy send/history API. It is
the one remaining screen where the legacy code is *working* and sizeable (1019 lines), so a partial
rebuild would be a live regression rather than a missing screen — which is why it was not started on
a nearly-spent context. Everything needed to start is above: frames, node IDs, the legacy file, and
the backend it already talks to.

## 3x. Whole-suite state after today's edits (measured, not assumed)

`flutter test` → **56 passed, 8 failed**. Every failure is in
`test/pricing/product_detail_bottling_test.dart`, the pre-existing red file whose root cause is
already diagnosed in §3t (`UnsupportedError` building a `LayoutBuilder` — a harness/constraint
problem, not the `intl` one). Nothing else in the suite regressed from today's changes: the warning
cleanup (unused imports, `super.key` removals in `cart_page`/`product_row`), the `AuthenticationWrapper`
startup fix, the FAQ rebuild and the `/faq` routing cutover all pass.

Correction: I had recorded this file as "5 failing tests" from a partial run. **It is 8.** The earlier
number came from grepping one run's output rather than counting the suite's own summary — the same
under-measuring habit behind the `chars` walker and the analyzer filter. Count from the summary line.

## 3y. Three boot bugs, two of them mine — from a real console trace

Reported: blank dark screen, then endless loading on web. The trace was conclusive.

**1. Portrait lock aborted `main()` on web (mine).** The stack shows
`DomScreenOrientation.lock` → `[_completeErrorObject] completeError` →
`setPreferredOrientation` → `SystemChrome.setPreferredOrientations` → **`main.dart:36`**. On web
`screen.orientation.lock()` **rejects unless the document is fullscreen**, and I awaited it unguarded
at the top of `main()`, so on a browser that refuses the lock the app never reached `runApp` — a blank
page with no error the user can see. Fix: skip the call when `kIsWeb` (Android/iOS keep their native
locks in the manifest / Info.plist, so the requirement is still enforced where it matters).

**2. The web splash deleted itself mid-boot.** `web/index.html` had a
"ultimate safety net: remove splash after 15 seconds no matter what". A cold debug-web load fetches
**1152 DDC modules** and takes longer than that, so the splash vanished while the app was still
booting → the blank dark page. Fix: the net now waits for `flutter-view, flt-glass-pane` before
handing over, and if Flutter still has not appeared it **keeps the branded splash and tells the user**
(«Загрузка занимает дольше обычного…») instead of blanking. Verified on a cache-disabled cold load:
splash → app, no blank window.

**3. Home fetch could hang forever.** `HomeDataSource.load()` `Future.wait`s four endpoints with no
timeout, so one stalled request left `_homeData == null` and the loader spinning — the
"endless loading". Fix: `.timeout(20s)` in `_loadHome`, after which the existing error state shows
with its retry. Same class of bug as the un-timed `/auth/full-info` fixed in §3u — **any await on the
startup path needs a bound.**

**OneSignal console flood — fixed.** `web/index.html:88` logged on *every* failed bridge call, and a
blocked SDK makes all of them fail: a web run printed **40 identical `OneSignal web error`** entries.
The bridge already tolerates a missing SDK (null bridge + 10 s timeout + catch), so nothing was broken —
it was pure noise. The catch now logs **once**, with a message that says what actually happened
(«push is disabled on this origin»), and suppresses repeats.

**Verified after the fixes**, cold load with the HTTP cache disabled:
- served HTML contains both the 60 s net and the dedupe (checked by fetching `index.html` directly);
- a fresh load logs **2 console entries, 0 errors, 0 OneSignal errors** (was 40);
- during the boot window that used to be blank, the screen shows the **branded splash** — «Градусы24»,
  the tagline, the progress bar and a rotating fact («Свежее разливное пиво») — which is the whole
  point of the fix.

**Agent tooling installed (requested):** `.agents/skills/` now holds the official Dart/Flutter skill
sets (`npx skills add flutter/agent-plugins` + `dart-lang/skills`) — 12 `dart-*` skills plus the
`flutter-*` ones (widget/integration tests, layout issues, responsive layout, localization, routing),
including `dart-fix-runtime-errors`, which is exactly the workflow that would have shortened this hunt.

## 3z. Smoke test of the still-legacy screens (after today's routing changes)

Ran because the FAQ cutover touched the route table, and addresses/cards/support are the screens my
remaining items cover — a regression there would be invisible until someone rebuilt them.

| Screen | Result |
|---|---|
| Адреса (legacy) | opens, renders, no errors |
| Карты (legacy) | opens — «Мои карты», empty state, FAQ hint card, «Добавить новую карту» |
| Поддержка (legacy) | **not reached** — my tap sequence landed on a category tile instead |
| Крепкие напитки (rebuilt) | renders correctly with live data as a side effect of the mis-tap |

**Console across the whole walk: 1 error**, and it is the expected suppressed line
(«OneSignal web unavailable — push is disabled on this origin»). So the dedupe works and there are no
navigation crashes.

**Method note, worth keeping:** driving Flutter web by coordinate is fragile — the same tap that opened
the sidebar one minute earlier landed on a product tile the next, and I burned three attempts on it.
Stable-finder automation (Flutter Driver / the widget inspector over MCP) would make this reliable, and
`integration_test` with `find.byKey` would make it permanent. That is the concrete argument for the
tooling in §3y, not a tidiness one: the verification loop is the slow part of this project.

## 4a. How to run this app in dev on Windows (the OOM is the toolchain, not the app)

**Symptom:** `flutter run -d chrome` dies with
`../../runtime/platform/allocation.cc: 22: error: Out of memory` (Dart 3.12.2, windows_x64) during
compilation, with a stack full of `_Utf8ConversionSink` / `Stream.fold` frames.

**Diagnosis:** the **DDC dev compiler** ran out of memory, not the application. The earlier console
dump confirms the scale — the debug web build loads **1152 modules** (`DDC is about to load
1152/1152 scripts`). DDC plus a file watcher plus a heavyweight dependency set (`sentry_flutter`,
`onesignal_flutter`, `provider`, `shared_preferences`, `package_info_plus`, …) is the memory hog here.
Nothing in the app crashes at runtime in this trace; the crash is inside `flutter run` while emitting
the bundle.

**Confirmed by the run that produced this entry:**

```
Compiling lib\main.dart for the Web...  62.3s
✓ Built build\web
```

**Use this instead:**

```bash
flutter build web --release      # one dart2js compile, no watcher
# then serve the output statically, e.g.
python -m http.server 8100 --directory build/web
```

Three problems disappear at once:

| | `flutter run -d chrome` (DDC) | `build web --release` + static serve |
|---|---|---|
| Memory | OOMs on this machine | a single compile, no watcher |
| First paint | 20–60 s (1152 modules) | seconds |
| Splash window | long enough to need the 60 s net | barely exists |

That last row matters: the blank-screen bug in §3y was *caused* by the slow DDC boot outlasting the
splash. A release build makes that whole class of problem rare, and the splash fix keeps it honest
when it does happen.

**Verified end-to-end:** `flutter build web --release` finished in **62 s** (the debug run OOMs), and
served statically (`python -m http.server 8100 --directory build/web`) the app reaches its first
screen in **under 7 s** — against 20–60 s under DDC, with 2 console entries and 1 error, the expected
suppressed OneSignal line.

**Build warning triaged, no action taken:** `Expected to find fonts for (MaterialIcons,
packages/cupertino_icons/CupertinoIcons), but found (MaterialIcons)`. Checked before reacting —
**zero `CupertinoIcons` references in `lib`** and `cupertino_icons` is not a declared dependency, so no
glyph can be missing and the warning is spurious. Adding the package would be a dependency nobody
uses; the MaterialIcons tree-shake (1 645 184 → 25 232 bytes) is working as intended.

**If you must use hot reload**, keep the module count down (drop unused dependencies — two were
already removed early in this project) and close memory-heavy apps; the watcher's footprint is what
crosses the line, not the app's.

---

## 4. Rules you have given that must hold

1. **No bottom bar, ever.** Only the cart button may float, showing the total when needed.
2. **The cart must show a delete button before removing an item** — decrementing the last unit must
   surface an explicit delete affordance rather than silently dropping the line.
3. Apps and designs drift: where the design is silent, build what the app needs; where the design
   shows something the app cannot do (no backend), leave it out and record it here.
4. Backend is **frozen** and **production**. No new endpoints; verify read-only.
5. The account under test is personal: **never** touch payments, **never** create orders, and do not
   mutate addresses or cards.

---

## 5. Remaining work

The previous screen-by-screen execution sequence is frozen. The measured recovery plan now lives in
`docs/redesign/PLAN.md`.

The renderer uses a complete blur fallback when shader filters are unsupported, including the first unsupported frame. Mocked API contracts cover home, authentication, and category-item paths without production I/O. Authentication presentation is complete and retains frozen auth behavior.

Active cutovers now include onboarding, addresses, saved cards, checkout/fulfillment, certificate purchase and configured products as well as browse/cart/profile/orders/bonuses/help. The gallery covers 24 synthetic surfaces in both themes. Current integration evidence is in §3ai; earlier counts and legacy-bridge claims are historical. Native/bank and authenticated production mutation behavior remain unverified.

### Earlier pixel-diff baseline (not refreshed for this geometry pass)

| Screen | meanΔ | pixels > 32 |
|---|---|---|
| Home (dark) | 10.74 / 255 | 8.66 % |
| Home (light) | 13.89 / 255 | 5.23 % |
| Product cards grid | 11.28 / 255 | 6.63 % |

Residuals are the deliberately-removed bottom bar, the unexportable icon glyphs, and text
antialiasing.

## 3aa. Home, catalog, cart and profile fidelity pass

The active feature routes now match the supplied 375 × 812 Figma geometry for home (including lower-scroll bonus/product sections), catalog landing, all-products grid, cart, and profile. Stable widget keys support exact rectangle assertions. Cart last-unit deletion remains explicit; the backend and account data were not mutated.

The home’s supplemental product rows use the existing read-only category-items API. Each optional row is isolated so its failure does not fail the home surface.

Verification:

- `flutter test` → **98/98**.
- `dart analyze lib test` reports 0 errors and 0 warnings; 28 info-level lints remain.
- `flutter build web --release --no-wasm-dry-run` regenerated tracked `build/web`.
- A temporary fixture-only widget harness rendered all six home/catalog/all-products/cart/profile cases after the final spacing changes. It used mocked responses and made no production requests.
- Release Chromium reached the onboarding screen at a 375 × 812 CSS viewport, with no runtime exceptions. Its screenshot measured 469 × 1015 physical pixels. This release browser smoke did not navigate through authenticated routes; active route geometry was verified in the fixture widget harness.
- The only browser console error was the pre-existing OneSignal-disabled-origin log; no app runtime exception was reported.

Temporary fixture harness and generated renders were removed after review.

## 3ab. Home functionality correction

The preceding fidelity pass protected rectangles but did **not** prove guest home interactions: the release browser had only reached onboarding. The follow-up opened the active release home against production's read-only GETs and corrected the missing behavior.

- The logo opens the drawer using the header's Scaffold context. The search field, category tiles, promo category card, campaign banners, floating cart and support entry now navigate from the active route. The support control opens the existing chat because the API exposes no support phone; the Figma phone number was a mockup placeholder and is no longer dialed.
- Stores load from the existing businesses/cities endpoints. The city-grouped sheet selects and persists a `BusinessProvider` store, then reloads price/availability-scoped home content. Switching with a nonempty cart requires explicit confirmation and clears the old store's cart only after consent.
- Banners use real promotion IDs and show a usable label/CTA when the backend sends no cover. One banner is centered; placeholder banners are inert and never point to an unrelated campaign. The search scan icon no longer encodes a fake barcode. Bonus QR codes require a real `cardUuid`; missing codes show an unavailable state rather than an invented scannable payload.
- The guest bonus CTA enters the phone form directly and back returns home. The guest gate no longer logs out an already anonymous user or initializes push SDK through that path. Home product rows prioritize the beverage/food categories shown in the reference, while optional failures remain isolated.
- The active-order card appears only for an authenticated user's recent active order. It uses the frozen read-only active-orders endpoint and existing status labels; tapping it opens order detail. No account was accessed to verify this state: mocked transport and a throwaway 375 × 812 visual render verified its geometry. The render was removed afterward. The aperitif-specific wine artwork and slogan no longer appear on unrelated catalog categories. Promotion item results remain on a **legacy** destination and still need their own visual cutover in the whole-app roadmap.

Verification: `flutter test` **108/108**; `dart analyze lib test` 0 errors, 0 warnings, 27 pre-existing info-level lints; final release web build succeeds. At 375 × 812 release Chromium, guest home, city-grouped store switching (Karaganda → Astana), lower product rows, search, campaign items, catalog category, cart, support, and direct guest phone-form/back were exercised. No production account was mutated; SMS, payment, and order actions were not invoked. Browser reported no runtime exceptions; localhost logged only its known OneSignal-disabled-origin message. The authenticated order card was exercised only with local fixture data.

## 3ac. Repeatable development verification and OMP integration

Project-scoped `.omp/config.yml` enables Dart LSP diagnostics after edits and in delegated tasks, shows turn duration, retains longer diagnostic lines (2,048-byte cap), and caps interactive provider retries at three attempts/60 seconds. `.omp/mcp.json` registers the installed Dart MCP via `cmd.exe /c dart mcp-server`; `.omp/AGENTS.md` records the route, backend-safety, and verification boundaries without replacing the milestone roadmap. No global OMP settings or production API contracts were changed.

The installed `.agents/skills/dart-fix-runtime-errors/SKILL.md` advertised runtime MCP inspection but actually prescribed static analysis and `dart fix`. It now documents DTD discovery, runtime errors/widget inspection, cause-level repair, hot reload, and replay of the failing action. This changes agent instructions only, not application behavior.

- `flutter run -d windows -t tool/dev_surface.dart` opens a **synthetic**, 375 × 812 gallery of active home, catalog, all-products, cart, and profile surfaces with dark/light toggles. Fixture HTTP rejects unknown or authenticated requests; no production account is used. The Windows CMake install stage now gives Sentry's nested plugin installer a concrete staging directory instead of the Flutter runner's unevaluated generator-expression path.
- `dart run tool/verify_surface.dart all --theme both` renders ten deterministic screenshots with the real app widgets and writes five-by-two difference heatmaps against exporter-named Figma references. It reports mean channel difference and pixels over 32; differences in synthetic labels/products are **not** pass/fail claims. Capture/compare tests live under `tool/design/`, outside normal test auto-discovery. Generated PNGs stay under ignored `.figma_cache/render/`.
- VS Code's `Design fixtures (Windows)` launch configuration and Tasks for fixture comparison, tests, and analysis provide one-click entry to the same verified commands. The old Chrome debug configuration was not removed or silently changed.
- `tool/figma_spec.dart png --page \"Design System (Light)\" --frame \"...\"` can export specific frames and skip already present PNGs. The five Light references were fetched into ignored `.figma_cache/shots/`; future clean workstations need local Figma credentials to fetch their own copies.

Verification on this workstation: all ten dark/light captures and comparisons completed; native Windows **debug and release** builds succeeded. The debug gallery attached to Dart MCP: the runtime inspector saw `_FixtureGallery`, `DesignSurfaceApp`, and fixture controls, `get_runtime_errors` returned no errors, and hot reload succeeded. A release-web fixture gallery rendered and switched home → catalog at 375 × 812 without app runtime exceptions. After that isolated build, `flutter build web --release --no-wasm-dry-run` restored the tracked production `build/web`; a fresh 375 × 812 production browser smoke returned to the active guest home with no runtime exceptions. Browser DPR was explicitly set to 2 and the screenshot dimensions were 750 × 1624. The known localhost OneSignal-disabled-origin message remains. The project-scoped OMP config was confirmed effective in this session; the MCP tool registration is ready for the next OMP session, and its same Windows command was verified against a running debug gallery.

## 3ad. Home-adjacent route audit and focused UI pass (2026-09-29)

`PLAN.md` now inventories actual home → one/two-step destinations, their controls, data and loading/empty/error states. Its next cutover milestone is promotion products and read-only order detail, then support; onboarding and account/checkout work remain queued. The home bell and drawer now say **notification settings**, because the active destination edits push preferences; the Figma inbox still has no backend and was not fabricated.

- Home header hides the support label rather than overlapping the right actions in a narrow window; category tiles use two columns below the reference layout while the 375 px geometry stays unchanged.
- Catalog landing and leaf grids use width-aware columns, card quantity transitions animate, featured heading opens the corresponding leaf, and loaded section items are reused on navigation. Null/failed category reads now show retry instead of pretending to be a valid empty category. Cart recommendations remain optional if that fetch fails.
- Profile rows are centered on wide windows, telemetry reports loading/failure and rolls back a failed save; switches animate. Notification settings are theme-aware and scrollable, persist the existing three topic switches, retain push permission/topic operations and report loading/errors. There is no push-history feed.
- Product detail's price and add action now share available width without overflowing at 320/375 px; category/country metadata also truncates safely. Explicit final-unit cart deletion and frozen API contracts remain unchanged.

Verification: `flutter test` **122/122** after the fixes; `dart analyze lib test tool` 0 errors/0 warnings, 27 info-level lints; `dart run tool/verify_surface.dart all --theme both` captured and compared 10 fixture screens at 750 × 1624 physical pixels. The isolated release-web fixture gallery was opened at 375 × 812 CSS pixels / DPR 2: catalog → featured leaf and light profile rendered without runtime browser errors. `flutter build web --release --no-wasm-dry-run` regenerated tracked `build/web`; its production browser smoke reached first-run intro slides with no app runtime exceptions, **not** an authenticated profile or production inbox. Synthetic fixture diffs are content-dependent (home dark mean Δ70.83, catalog dark Δ20.72, profile dark Δ8.03) and do not establish production pixel parity. No account mutation, SMS, payment or order was attempted.

## 3ae. Functional repair pass (2026-09-29)

Home/sidebar route taps now close the drawer before pushing; logout clears the local session even if push deregistration fails, returns from nested profile routes to home, and is hidden for guests. Guest favorites, order history, bonuses and cards request sign-in instead of displaying an authenticated feed as empty. The product-detail route now carries cart/store context from home, catalog, search, favorites and cart recommendations so its cart and like actions have destinations.

Catalog category lists paginate beyond the first page; favorites use the API's already-unwrapped liked-items payload. Failed catalog/search/favorites reads distinguish error from valid empty results. Out-of-stock add controls no longer insert items; product detail's add button does not duplicate a quantity already selected in its stepper. Notification topic preferences no longer default to a falsely subscribed state; failed saves and unsupported push operations report failure instead of appearing successful. Theme and telemetry settings update visible state only after storage succeeds.

**Verification boundary:** requested static checks only. `dart analyze lib test tool` reported 0 errors, 0 warnings and 27 existing info-level lints. No tests, app launch, runtime interaction, production request or release rebuild was performed for this repair pass. Option-product configuration still uses the supported legacy route; a notification inbox remains unavailable without a backend contract.

## 3af. Account icon → full-screen profile (2026-09-29)

The home header's account icon now navigates to the existing `AppDestination.profile` route (`ProfilePage` with its own back button), rather than opening the navigation drawer. The logo still opens the drawer for other destinations. The active wrapper route test exercises account → profile → back and checks that no drawer replaces the page. This preserves the 375 × 812 Figma profile layout in both themes.

The full integration run exposed two stale fixture contracts from the preceding functional repair: prefetched category products were unnecessarily refetched without pagination metadata, and desktop notification topic controls were expected to toggle even though push is unsupported there. The page treats caller-supplied items without continuation metadata as complete; the notification regression now verifies saved choices remain read-only on desktop. Focused route, profile, catalog and notification tests passed; `flutter test` **122/122** and `dart analyze lib test tool` 0 errors/0 warnings (27 info lints). Profile dark/light fixture capture and diff completed; isolated web fixture home account → profile → back rendered at 375 × 812, DPR 2, with no browser runtime errors. These are fixture-only observations, not authenticated production verification.

After those checks, `flutter build web --release --no-wasm-dry-run` regenerated tracked `build/web`. A release-browser smoke at 375 × 812 / DPR 2 reached first-run onboarding without runtime errors; it did **not** reach authenticated production profile.

## 3ag. Useful full-screen profile and home-adjacent cutovers (2026-10-02)

### Active routes and supported behavior

- Home account → `AppDestination.profile` remains a full page with its own back control; the logo still opens the separate drawer. Profile now shows the actual account name/login, address summary and masked-card summary from full-info. Missing collections remain unknown, malformed records fail, and guests see sign-in instead of invented empty account data. Refresh/retry, refresh after child routes, pending feedback and confirmed logout are implemented.
- Certificates now enter `features/certificates/ui/certificates_page.dart` directly. The obsolete placeholder page and callers are removed. Failed reads/claims are not treated as empty/success; refused claims retain the code. Status changes reject stale responses, pagination uses limit 50/offset, numeric-string and zero balances are respected, and certificate codes are selectable. Purchase keeps its supported legacy payment bridge.
- Campaign products in `pages/promotion_items_page.dart` use current catalog cards/grids, scoped likes and quantities, full pagination, retryable loading/empty/error and working detail/cart navigation. No exact campaign-list frame exists; comparison against `Каталог - Все товары` was removed in the following pass and the surface is capture-only. Option products retain their supported legacy detail route.
- `pages/order_detail_page.dart` and the active orders list now distinguish history/read errors from empty data. Detail shows only supplied items/totals/fields/events, preserves repeated statuses at different timestamps, and retains refresh, repeat, payment retry, support and FAQ. Missing dates/totals stay unavailable; no tracking/ETA/rating/tips are invented.
- `pages/help_chat_page.dart` shows real server history, preserves a failed-send draft and clears it only after acknowledgment, reports session/history/send/poll errors and offers explicit retries. Order attachment requires a user action; entering order support sends nothing automatically. Polls do not overlap, disposal ends in-flight ownership, and `ChatApiService(enableSocket: false)` keeps fixture journeys off Socket.IO. The server's `fromMe: true` identifies the operator, not the visitor.

### Intentional usability changes

- Home star opens bonuses/sign-in; heart opens favorites/sign-in. Empty campaign feeds reserve no advertising panel. Missing/loading/failed artwork shows the campaign's actual copy rather than an unlabeled rectangle.
- There is **no supplied support telephone contract**: `HomeDataSource.supportPhone` is the display label `Поддержка`. The attempted dial/copy sheet was removed rather than manufacturing a `tel:` destination. Home explicitly offers support chat; native dialing is not implemented or claimed verified.
- Shared headers grow beyond their 57 px minimum for large text. Light-theme icon discs use the palette's primary foreground; selected hearts retain white. Grid and cart-recommendation steppers are outside product-navigation ancestry, including disabled stock controls. Shared step targets and the floating cart use keyboard-capable `InkWell` controls; cart semantics name the destination, count and total.
- Narrow/large-text cart rows stack identity above price/quantity; totals and checkout stack without collision. Recommendation cards scale their geometry with text, title width excludes metadata, and the light-theme decrement glyph uses the primary foreground. The totals bar owns layout space instead of covering the last scrollable controls. The reference-width geometry regression still passes.
- The dev gallery keeps cart ownership across surface navigation, pushes profile children normally, and uses fresh strict socket-disabled chat clients for order → support. Width 320/375/800 and text 1/1.6/2 controls are development-only.

### Exercised verification

- `flutter test --coverage` → **159/159**; LCOV generated at ignored `coverage/lcov.info`. New recommendation stock/navigation and cart keyboard regressions failed before their fixes and passed afterward. The narrow/large-text cart regression reproduced overlapping totals and row overflow before the responsive fix.
- `dart analyze lib test tool` → **0 errors, 0 warnings, 27 existing info lints**. No new suppression was added.
- `dart run tool/verify_surface.dart all --theme both` captured and compared **22** deterministic 750 × 1624 surfaces. Cart was recaptured after its final decrement-color fix. Synthetic labels/products and intentional extra identity/failure controls affect diffs; these metrics are not pixel-parity or authenticated-production claims. Profile mean max-channel differences: dark 15.15/255, light 14.38/255.
- Release fixture browser exercised home account → guest → simulated sign-in → actual synthetic summaries; profile → certificates → failed claim with retained input → redeemed zero balance → back; profile → order history → order detail → support → acknowledged mock send → back; home support entry; and campaign increment → floating cart with exactly the added item and 13,170 ₸ total. Light profile at 320 px/1.6× and 800 px/1×, wide certificates, and narrow cart were reviewed visually.
- A removed throwaway runtime harness exercised empty campaigns and a 300 px keyboard inset in both themes. The campaign strip reserved no blank space (promo began 24 px below search); support retained its draft and its editor bottom remained at 500 px, above the 512 px keyboard edge.
- Browser automation initially triggered a Flutter framework logical-key lookup exception during input setup, and one unsettled accessibility hit target opened an underlying product. Both failures were recorded rather than suppressed. The final cart replay and native-typing certificate/filter replay reported no new runtime errors. The fixture transport had no unexpected HTTP during the 22 captures. Widget capture lacks a system font fallback for the `№` glyph; actual release-browser order titles rendered it correctly.
- `flutter build web --release --no-wasm-dry-run` regenerated the final tracked `build/web`. A fresh production release smoke at 375 × 812 / DPR 2 rendered first-run intro slides with a 750 × 1624 screenshot and no browser runtime errors. It did **not** bypass onboarding or reach an authenticated production profile. Native dialing, production chat sends and payment/order/account mutations were not exercised.

### Remaining scope and safety

First-run city/location onboarding, addresses, saved-card add/confirmation, checkout, certificate purchase and option/bottling presentation remain queued or on documented legacy bridges. Notification inbox/unread state, scheduled delivery, ratings/tips, unsupported card deletion and fabricated operator presence remain excluded. No production SMS, chat send, certificate activation, address/card mutation, order creation or payment was executed. Fixtures and their screenshots do not establish authenticated production readiness.

## 3ah. City, address and saved-card cutovers

### Active routes and real behavior

- `AppEntryGate` still owns first-run `OnboardingPage`. City selection uses the existing supported API/cache and preference keys. Requests fail distinctly from a genuine empty list; valid stale cities remain usable with retry feedback. Manual selection works without location. Location, settings, notifications and telemetry require explicit user action; denial/unsupported services cannot block completion. City and completion writes must succeed before advancing. The unused IP-location path was removed. Public read-only cities supplied the actual `AREA` / `DISTANCE` values; unknown raw enum labels are not displayed.
- Profile and drawer enter the rebuilt `ProfileAddressesPage`; post-auth address capture uses the same map/search/details flow. Account records and device records are visibly distinct. Editing an account record creates a device copy; removal hides it only on this device. Device records can be added, edited, selected for delivery and removed, with destructive confirmation. No server address CRUD exists or was invented.
- `MapAddressPage` preserves the production 2GIS template and supports manual search, explicit locate/settings, reverse-geocoding retry and optional delivery details. An unresolved coordinate cannot advance. Debounced search invalidates shortened queries and rejects late success/error replies. Changing the map point preserves typed entrance/floor/apartment. Book/history/selected-address writes are serialized, failed writes attempt rollback and reload persisted state, and selection events emit only after success. SharedPreferences multi-key writes are **not crash-atomic**; rollback/reload failure remains a storage limitation.
- The address flow can be scoped to one city: `AddressSelectionModalHelper.show(city:, fallbackCenter:)` and `MapAddressPage(city:)` replace the onboarding city for reverse lookup, text search and label extraction (checkout passes the selected store's city). A stored/history address whose known city differs is ignored as the map centre; `fallbackCenter`, then the city's centre, then the onboarding city's centre is used instead. A device fix outside the scoped city shows an explicit «Вы сейчас не в г. X…» message (confirmed with one extra unscoped reverse lookup, only on that failure path) and leaves search and the map usable. The map page is a floating city-aware search pill, a recentre control and a bottom confirmation card (resolved street in bold, city line, retry for unresolved/outside/error states); the details page is a street summary card with «Изменить» plus labelled Подъезд/Этаж/Квартира fields (a row when wide, stacked at narrow width or large text) over a pinned primary action; the search page shows «Ищем адреса в г. X» with street-bold, district/city-secondary results.
- `ProfileCardsPage`, `AddCardWebViewPage` and `PaymentMethodPage` retain actual hosted-bank and payment contracts. Lists expose loading/empty/read failure/retry; masks and identities come from the server, not fabricated bank metadata. Web reserves its popup before asynchronous link generation. Link/launch/refresh failures remain actionable, duplicate launch is suppressed and pending binding can be cancelled. Bank open/return is **not** success: only a refreshed server ID absent from the baseline confirms binding, even when list size stays unchanged. No unsupported deletion is shown.
- Payment presentation preserves the existing card and Kaspi calls, order-ID/amount precedence, payload and success routing. The browser fixture exercised selection only; it did not execute payment. Profile refresh after returning from card binding reflects the new synthetic server identity. Address summaries intentionally remain server-only rather than claiming a device edit changed the account.

### Integration fixes

- Idempotent logout no longer fails when an optional token-expiry preference is absent. Malformed cached account data no longer prevents entering profile and performing its fresh read.
- Grid product content is keyboard reachable without activating disabled stock controls. `AppTopBar` supplies real default back navigation; onboarding explicitly disables back while saving. Address tiles now expose a button/selected state and their accessibility tap preserves delivery coordinates and optional details.
- Loading-screen fact timers are owned and cancelled on disposal, replacing delayed futures that survived a fast route transition. Radio/checkbox tiles have their own Material ancestry, keeping ink/background visible. Unsupported SVG filters were removed without changing paths or gradients.
- Strict fixtures now mirror production localization delegates, include timestamped orders, and use the actual request/query envelopes for home preload, card-source reads and geocoding. Unknown requests and non-fixture authorization are rejected; there is no production fallback. Search envelope and locale failures were observed and repaired, not suppressed.

### Exercised verification

- `flutter test --coverage` → **201/201**; ignored `coverage/lcov.info` generated. Focused onboarding/address/card/auth/shared/home/API regressions passed. Boundaries include rejected preference writes and rollback, stale geocoding replies, unresolved map points, retained optional fields, cancelled/failed binding and unchanged-count/new-identity confirmation. The address accessibility regression performs the real semantics action and checks persisted delivery data.
- `dart analyze lib test tool` → **0 errors, 0 warnings, 27 existing info lints**; no new suppression.
- `dart run tool/verify_surface.dart all --theme both` → **34** deterministic 750 × 1624 captures and **28** exact-frame comparisons. `promotion`, `onboarding` and `payment_method` are capture-only; standalone `promotion --theme both` also succeeds without a borrowed comparison. Matching light address/book/details/card frames were exported; both themes were visually reviewed. Synthetic content, the fixture map and intentional usability controls make these diagnostic diffs, not pixel-parity claims. Mean max-channel differences: addresses dark/light **11.49/20.56**, details **10.61/10.99**, cards **8.00/7.19**, map **95.22/43.81** (all `/255`).
- Final release gallery exercised explicit denied location/notification requests, manual city choice, skips and completion into fixture home; profile → addresses → FAQ/back; add → search result → resolved map → details → device save/select; edit with optional fields retained through a map change; cancellation/confirmation of local removal and account-record hiding. Card journeys proved cancellation plus refresh gives no false success, cancellation clears waiting, and explicit mock-bank confirmation plus refresh proves a new ID and updates profile. Card/Kaspi rows changed actual selection without submitting payment.
- Geometry was reviewed at 320/375/800 widths, dark/light and 1.6×/2× text, including reachable large-text onboarding completion and scrollable card content with its footer owning space. A removed throwaway release probe exercised search/details with a **300 px simulated keyboard inset**, native editor typing and both themes. At 375 dark and 320 light/2×, details confirmation ended at **454 px**, above the **512 px** keyboard edge; apartment fields scrolled into view and retained edited values. Search results and editor also remained above the keyboard. This is layout-inset proof, not a real OS soft-keyboard or permission check.
- Browser automation recorded an early malformed search-fixture envelope and a transient snackbar covering a card footer. The final geocoder replay succeeded; keyboard opened the hosted-form fixture. No new Flutter runtime exception or unknown fixture HTTP was reported in the final replay/captures. OneSignal and Sentry CDN fetches were blocked by the verification browser allowlist; those integrations are not claimed exercised.
- `flutter build web --release --no-wasm-dry-run` regenerated tracked `build/web`. A 375 × 812 / DPR 2 smoke rendered the real first-run intro and its sign-in/registration control. It did not bypass entry gates or fabricate an authenticated account.

### Remaining scope and limits

At this earlier pass checkout, certificate purchase and option/bottling remained queued; §3ai supersedes those route claims. Its real OS, bank/native and production-mutation limits remain unchanged. Notification inbox/unread state, scheduled delivery, ratings/tips, unsupported card deletion and fabricated operator presence remain excluded.

## 3ai. Remaining milestones: checkout, certificate purchase and configuration

### Active routes and contracts

* All checkout entries still converge on `lib/pages/checkout_page.dart`, now rebuilt with shared theme/components. Delivery/pickup, optional address details, confirmed store choice, bag/summary, bonus cap, promo/certificate validation and mutually exclusive benefits use the existing contracts. Quote responses belong to the latest address/cart/store/mode; missing, malformed or failed quotes cannot create an order.
* Creation is **POST `/api/orders/create-order-no-payment`**, with neutral `delivery_time: NOW` and `courier_tips: 0`, actual option/subtract-promotion payloads and no fabricated `saved_card_id: 1`. Definitive refusal preserves input/cart. Unknown acceptance locks resubmission and offers actual order history. Accepted creation snapshots the payable amount and clears the ordered cart once before payment.
* Completed card/Kaspi status enters `PaymentSuccessPage` with the real order ID and actual OrdersPage destination. Pending or malformed/network-uncertain card acknowledgment cannot show success or repeat the charge. Paying a historical order does not clear the unrelated current cart. No promised delivery ETA is invented.
* `BusinessProvider` persists before publishing a store and returns success/failure; wrapper, checkout, repeat-order and legacy menu callers do not destroy the cart before a successful write. Address storage clears its completed queue tail when idle, preserving serialized rollback/read behavior without retaining a retired test scheduling zone.
* Active certificates and profile no longer bridge to the deleted `lib/pages/certificates_page.dart`. The themed purchase sheet accepts arbitrary positive finite amounts and optional recipient/message, reuses saved-card/hosted binding, retains draft/card/pending identity across sheet reopening within its page session, and completes only with both confirmed server payment and a valid supplied certificate code. Pending recovery reads `/api/certificates/purchases/<id>/status`; it never recharges.
* Option navigation uses the rebuilt existing `ProductDetailPage`. Required single/multiple and optional selections, stock/quantity bounds and whole bottle counts retain SmartCart/pricing/promotions. Cart editing changes the exact base-variant group; cancel is local and sibling collisions are refused. Allocation stepping repeats/removes the exact selected primitive bottle batch; the final batch has an explicit delete action.
* Persisted option snapshots retain real `item_name`. Known snapshot relation identity wins over the fallback bottle-name heuristic. Product-name metadata extraction requires a word boundary, so «Разливное пиво» cannot become «ное пиво».
* The checkout footer owns the keyboard inset; while the keyboard is open its header joins the scrollable body. Large-text order-history cards grow rather than clipping totals outside their tappable area. The purchase sheet's close control is constrained to the full-width header, separate from the drag handle.

### Exercised fixture journeys

The release-built development gallery uses strict synthetic credentials/transports only. Unknown requests are rejected, never forwarded to production.

* Failed delivery quote → explicit retry; delivery/pickup fee changes; optional entrance edit; bad promo refusal → valid promo → certificate → bonuses, with mutually exclusive amounts. Refused creation retained cart/input; a later accepted create preserved **102239 ₸** through payment, completed as synthetic order **901**, and entered actual order history.
* Store-choice cancellation retained the original store/cart. Confirmed change persisted the choice before showing an empty cart; catalogue return uses the fixture's real catalogue destination.
* Certificate amount **12345**, optional recipient/message and definitive refusal retained the draft. Pending purchase survived close/reopen, status GET completed without another purchase, and supplied **`FIXT-2026-GIFT-0001`** appeared in the refreshed list. Hosted-form cancellation stayed waiting until explicitly cancelled; synthetic bank confirmation plus card refresh introduced the actual new server card identity.
* Lemonade single + multiple + optional choices produced **1200 ₸**; edit cancellation retained it, while removing gift packaging and saving produced **1150 ₸**. **1×1 L + 1×2 L** pour allocation produced **3 L / 3170 ₸**, stepped to **6 L / 6340 ₸**, returned to the original mix and exposed explicit final-batch deletion.
* Actual browser review covered the 375 reference, 320 px / 2× light layouts and 800 px / 1.6× dark layouts, window resizing, native keyboard typing and simulated **300 px** keyboard insets. The purchase action and checkout submit remained above that inset; optional checkout fields stayed editable. Simulation does not prove an actual mobile/native IME or OS lifecycle.
* The final fixture bundle also completed order **901 / 106190 ₸** into actual history and returned a confirmed store change to a populated, correctly scoped catalogue. A final pending purchase recovered by GET and refreshed the supplied certificate list.

### Verification and visual limits

* Focused checkout/certificate/title/active-order layout integration: **45 passed**. Full `flutter test --coverage`: **239 passed**; `coverage/lcov.info` regenerated.
* `dart analyze lib test tool`: **0 errors, 0 warnings, 24 existing infos**.
* `dart run tool/verify_surface.dart all --theme both`: **48 captures**, zero unexpected fixture requests, and **36 exact-frame comparisons**, at **750 × 1624** pixels (375 × 812 logical, 48/34 insets). The capture driver settles store-readiness and modal/enabled-state transitions.
* Newly compared mean max-channel Δ / pixels Δ>32: delivery **31.90 / 24.24% dark**, **30.06 / 22.20% light**; pickup **35.21 / 22.33%**, **33.21 / 23.90%**; purchase **26.75 / 19.89%**, **62.44 / 41.60%**; confirmation **11.38 / 9.83%**, **11.34 / 9.94%**. Synthetic addresses, cards, amounts and extra usable controls differ from the reference; confirmation intentionally replaces the unsupported ETA with real identity/history. These are not pixel-match claims.
* Configuration/error/payment-method/onboarding/promotion remain capture-only where no exact matching frame exists. Native permission/bank handoff, real card/order/certificate mutation, actual payment and authenticated production journeys are not established by fixtures. Production remained read-only; OneSignal and Sentry CDN requests were blocked, so those integrations were not exercised.
* Tracked `flutter build web --release --no-wasm-dry-run` completed. The actual production entry rendered the first-run **«Персональные акции»** intro and **«Войти или зарегистрироваться»** control at **375 × 812 / DPR 2**. No SMS, bank, address/card, certificate, order or payment mutation was attempted; release errors contained only the blocked external SDK requests.
* Browser automation once emitted an unsupported generic modifier-key location and hit the Flutter web key mapper, not an application request path. Final native-input verification used `ControlLeft` with the fixture tab brought to the foreground and produced no new page errors. No application exception suppression was added.
* All verification browser tabs and both isolated fixture/release servers were closed after smoke proof.


## 3aj. Glass forms and grouped settings (certificates, support, profile, notifications)

* **Shared pieces.** `lib/ui/frosted_controls.dart` (`FrostedTextField` — 45 px, r10 glass field with an animated accent focus ring; `FrostedButton` — orange glass button over `Frost.accent`), `lib/ui/app_switch.dart` (the Figma 50 × 30 pill: orange on, grey off, white knob, 220 ms glide, 50 × 48 touch target) and `lib/ui/settings_widgets.dart` (`SettingsSection`, `SettingsRow`, `SettingsChoice`).
* **Certificates.** «Активировать по коду» is a glass field (`certificate-code-input`) plus an orange glass «Ок» (85 px, 12 px gap, stretched together under large text). The page uses `FrostedHeaderLayout`; the purchase sheet is one frosted surface whose amount / recipient / message fields and Купить / Проверить статус / К сертификатам buttons are glass (a `FrostedScope` stops the fields blurring a second time). All keys are unchanged.
* **Support.** The composer is a floating frosted pill (r30, ≥46 px) with a 38 px orange glass send button, riding above the keyboard while the chat scrolls blurred beneath it; the header is `FrostedHeaderLayout`. `support-composer`, `support-message-input`, `support-send` (still an `IconButton`) and `support-send-error` are kept.
* **Profile settings.** Account block first, then grouped sections: «Заказы и покупки», «Оплата и доставка», «Приложение» (theme, notifications, information collection), «Помощь», and «Выйти» alone at the bottom. **Theme is a Светлая / Тёмная / Авто segmented choice** (`ThemeController` already supported `ThemeMode.system`; the old binary switch could not express it and showed the effective brightness). Information collection is a toggle with the current state in its subtitle and a footer saying what is sent, that it is off by default and revocable. «Уведомления» is now reachable from the profile. Saving/error states, snackbars and the keys `profile-telemetry-switch`, `profile-logout`, `profile-sign-in`, `profile-avatar`, `profile-name` are kept; `profile-theme-switch` is replaced by `profile-theme-choice` / `profile-theme-{light,dark,system}`.
* **Notification settings** use the same sections and rows (device status + enable action, per-topic switches, subscription ID / clear, support-chat link) under `FrostedHeaderLayout`; behaviour and messages are unchanged.
* Departures from Figma: the settings screen is grouped and has a segmented theme choice instead of the ambiguous moon/sun switch; the activation/composer controls use the shared glass tokens (`Frost.tint` / `Frost.accent`, 0.9 accent) rather than 75 % orange, so white text stays legible. Not yet visually verified.
