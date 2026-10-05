# Redesign — status, decisions and open questions

Living document for the Градусы24 → Figma redesign. It exists so the work can continue without
its original author in the loop: **every question that needs a human answer is listed below with
the default I am proceeding on**, so nothing blocks unnecessarily, and nothing gets decided
silently either.

Last updated: 2026-10-04 (repository cleanup integrated and verified after catalog/card correction). The user's defects supersede the previous completion conclusions. Sections 3 onward and the dated catalog evidence below are historical records, not new acceptance; their sidebar, tiny-type, legacy-resource and queued-route statements are superseded by the current gates. `PLAN.md` contains G1–G9; `../CLEANUP_PLAN.md` contains the completed cleanup plan and measurements. Gift-container policy and `docs/kaspi.txt` remain unchanged.

---
## Current remediation gate

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

### Exercised integration

| Check | Current observed result |
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


### Actual fixture/browser observations

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

* **Portrait only**, all three surfaces: `AndroidManifest.xml` `screenOrientation="portrait"`,
  iOS `UISupportedInterfaceOrientations` = portrait, `SystemChrome` in `main.dart`. Web ignores it.
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

