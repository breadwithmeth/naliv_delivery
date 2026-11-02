# Whole-app quality remediation

## Authority and current status

The user's reported defects supersede the previous `DONE` quality conclusions. Historical tests, synthetic captures and releases remain recorded in `STATUS.md`; they do not establish readable typography, correct real card loading, correct bottling prices or Kaspi presentation compliance. This plan covers every active route, not just the redesigned landing page.

**Current cutover — 2026-10-09:** client corrections F1–F11 are retained. Catalogue,
category selection, information-complete cards and confirmation hierarchy are rebuilt;
genuine native/shader material now covers the whole cart control. Strict Windows and
release-web interactions, calibrated adaptive/keyboard captures and settled integration
checks passed. Current exercised evidence and unexecuted Apple checks are in `STATUS.md`.
Active routes/controls are mapped below. The selected material contract is actual native
Apple `UIGlassEffect` on iOS 26+ and genuine live-backdrop shader refraction elsewhere;
non-Apple output is not claimed Apple-native/pixel-identical. Xcode 26/Apple runtime
acceptance is a separate, explicit verification boundary.
Real bank/card-account, loyalty policy, 1C reversal and push-provider/device acceptance
remain external prerequisites. Earlier artwork/grid rules below are historical, not
constraints overriding required app information or the new usability request.

### Current design milestone — controls, sources and states

| Surface | Visible controls and destination/action | Data and states retained |
|---|---|---|
| Catalogue overview (`SupercategoryPage`) | Back to home; search to wrapper search; one section header to that leaf; card to actual product/configuration; stock-aware add/stepper; floating cart to wrapper cart | Selected-business `CatalogDataSource`; lazy section reads/full first-page prefetch; loading, missing supercategory, empty leaf, error/retry, stock/configuration availability |
| Category products (`CategoryProductsPage`) | Back/overview; one full-label category picker and complete selected sheet; sibling replacement; product/detail/quantity; search and cart | Branch/leaf IDs and contextual duplicate labels; prefetched continuity; page-more loading/error/retry; fractional stock/quantity and real source items |
| Shared product card | Full name and all known identity metadata; current/old price, saving, promotion and bonus; photo/missing-photo; detail and >=44 px quantity/configuration targets | `ProductView`/`presentItem`, no inferred country/ABV/material; two columns at 375, one for narrow/large text; home/cart rails and promotions share the new sizing |
| Confirmation (`CheckoutPage`) | Delivery/pickup; address/store change; optional delivery details; order quantity/remove/edit; benefit disclosure with existing bonus/code/certificate controls; quiet FAQ; persistent confirm/recovery | Existing cart/store/address and draft controllers; independent quote/bag/bonus loads; precise cost breakdown including mandatory bag/physical containers; existing exclusivity, invalidation/readiness and durable unknown-create/payment guards |
| Floating glass/cart | Same cart tap/count/total semantics; expanded material covers the badge and total; content can scroll entirely above it | Native capability on iOS 26+; shader samples the live underlay on other supported renderers, while controls stay sharp in a separate foreground; material loading/error states are explicit, not another blur called Liquid Glass |

Composition: consistent category sections instead of the oversized first-category sidebar;
one category-switch mechanism instead of chips plus a menu; wider information-complete
cards; fulfilment -> order review -> optional benefits -> one readable price breakdown.
Decorative chrome does not need a fake glass treatment. Genuine floating material must be
proved against a moving/textured backdrop and both themes, then active-route interactions
and large-text clearance must be reviewed.

Implemented material contract: `LiquidGlassDock` keeps the sampled scene separate from
sharp, hit-testable foreground controls. `shaders/liquid_glass.frag` uses a curved shell,
Snell refraction (IOR 1.45) concentrated in the rim over a nearly flat interior, a
per-pixel-rotated 21-tap golden-angle frost, mild dispersion, Fresnel plus a crisp top
streak, and dithering; there is no screenshot timer or CPU pixel readback. A theme base
tint plus adaptive shadow-lift/highlight-crush keep sharp text readable without flattening
the scene into fog. The 2026-10-11 quality pass removed the earlier fog, saturation boost
and tap-moiré after rendered dock review. Windows runtime checkerboard captures in
`.figma_cache/harness/optical/` show the bent rim, unchanged scene outside the dock, a
response to moved scenery and working foreground taps in both themes.
Ordinary chrome uses `AppSurface`/`AppSectionAction`; the old blur/rim glass API is removed.

On iOS 26+, `NativeLiquidGlassBackdrop` uses `UIVisualEffectView` with `UIGlassEffect`,
not `UIBlurEffect`. Capability false selects the shader on older iOS; missing registration
or native failures remain errors. Native source is wired into Runner, but **Windows does
not prove Xcode compilation, UIKit sampling, native corner/theme updates or disposal**.
Apple acceptance requires macOS, Xcode 26+ and an iOS 26+ runtime:

```sh
flutter build ios --simulator --debug --no-codesign -t tool/dev_surface.dart
flutter run -d <iOS-26-or-newer-simulator-UDID> -t tool/dev_surface.dart
```

Exercise scrolling imagery, both themes, corner/tint updates, foreground taps and repeated
mount/disposal; also exercise older supported iOS to prove the shader path. Native press
reactions are not claimed: the UIKit background is pointer-transparent. Platform views
cannot be sampled by the Flutter shader; do not put them in its optical underlay.

The dedicated plans below were defined before implementation. Dependencies ordered the work; independent card/domain repairs ran alongside shared presentation work. Integration owned builds, formatters, analysis and tests after shared edits settled. Problem/evidence paragraphs describe the original audit, not the current implemented tree. Current commands, route observations and limits are recorded in `STATUS.md`; diagnostic measurements are in `FIDELITY.md`.

`PROMO_BOTTLING_PLAN.md` records the original promotion/configuration audit and M1–M5 contracts. M1 money/stock boundaries are retained; M2 active campaign terms, M3 coherent item composition and M4 the first-screen live bottling summary/picker are integrated in the current cutover. M5's production bank/accounting acceptance remains separate from client verification.

| Goal | Status | Depends on |
|---|---|---|
| G1 Readable typography and adaptive shared components | Implemented; fixture-verified | Audit complete |
| G2 Home composition and spacing | Implemented; fixture/browser-reviewed | G1 shared sizing contract |
| G3 Saved-card loading and binding states | Repaired; strict fixture journeys verified | Existing read-only contract; authenticated production read unavailable |
| G4 Bottling allocation, pricing and configuration | Clarified paid/gift contract verified, including create/repeat and physical cart counter | User-confirmed policy: all physical bottles charged normally, including gift litres |
| G5 Logo drawer removal and navigation cleanup | Removed; active route/continuations verified | Active route inventory |
| G6 Coherent remaining active surfaces | Rebuilt; 41-surface dark/light and adaptive review | G1/G3/G4; native/backend limits recorded separately |
| G7 Proven dead code/resources cleanup | Removed; tests/analysis/release packaging passed | G5; live legacy styling/FAQ migrations |
| G8 Kaspi.kz presentation | Official Figma assets/rules applied; link-flow states reviewed in strict fixtures | `docs/kaspi.txt` supplies authoritative design; real-bank lifecycle remains a verification limit |
| G9 End-to-end integration and truthful release evidence | Historical G1–G9 evidence below; current usability/native-shader cutover commands and limits are in `STATUS.md` | No app-wide production acceptance inferred from fixtures |

## Prior catalog/card balance correction — superseded by the current cutover

The user rejected the oversized, unbalanced item cards after the readability remediation. Earlier 297-test/82-capture acceptance does not establish the balance of these cards.

**Scope and decision.** Refine `ProductCard` and the active catalog overview/all-products pages, migrating every shared-card consumer. Preserve 14 px product names, 12 px metadata, inherited scaling, 44 px actions, both themes, pricing/options/stock semantics and cart-only floating navigation. Cap artwork at 96 px, remove unconditional promotion-space reservation and duplicate saving text, combine auxiliary metadata, use a compact initial add control and a quiet selected stepper. Two-column browsing must remain practical at 320/375 px at normal text size; larger text reduces columns. Replace the full-height featured lead-in with a concise section heading and horizontal products. Limit category overview previews to two rows; “Все” opens the complete prefetched/paginated category, not a truncated data source.

**Controls/data/states before implementation.** Back returns to the previous route; search uses the wrapper's search destination; category chips, featured heading and “Все” open `CategoryProductsPage`; card image/name opens the real product/configuration route; add/increment/decrement use existing stock-aware cart methods; the floating cart opens the wrapper cart. `CatalogDataSource` keeps the store-scoped existing category API. Initial loading, successful empty, read failure/retry and page-more loading/retry remain distinct. No new endpoint, production mutation or alternate preview system.

**Acceptance.** Actual fixture catalog/all-products journeys prove category navigation, details, add/remove, cart and full-list continuation. Review normal/discounted/unavailable/in-cart cards, photos and missing art in dark/light, 320/375/800 widths, 1×/1.6×/2× text and live resize. Run existing focused flows, full serial tests/coverage and analysis, refresh affected captures, then rebuild/smoke tracked release. Current catalog/card evidence supersedes its earlier visual acceptance.

**Observed completion.** Shared card APIs/callers and active catalog composition are migrated. Prices follow metadata; optional old prices determine the parent height, and wrapping/unavailable text takes priority over artwork. Reference-size cards are 255 px without an old-price row, 271 px when the dataset contains one; mixed grids grow to 324/360 px at 1.6×/2×. At 320/375 px, full lists use two columns at 1× and one at larger text; at 800 px they use four at 1× and three at larger text. Strict release fixtures proved the active wrapper → catalog → cart route, add/increment/remove, prefetched “Все”, page-two continuation and captured-photo configuration → 2 L / 5300 ₸ cart. Dark/light browser review covered all requested widths/scales and state-preserving live resize. Existing focused tests (20), disposable render/state cases (306), full serial tests (297), coverage, analysis, 82 captures/50 comparisons, both release builds and read-only tracked-entry smoke passed. `STATUS.md`/`FIDELITY.md` record current evidence and deliberate reference departures.

## Non-negotiable contracts

- Production API and personal account are read-only during verification. No SMS, chat send, address/card mutation, order creation, certificate activation/purchase or payment. Synthetic transports reject unexpected requests and non-fixture credentials; no production fallback.
- Active entry: `main.dart` → `AppEntryGate` → intro/onboarding → `AuthenticationWrapper` → `HomeScreen/HomePage`. The wrapper's destinations, not file names, define scope. Reachable `lib/pages/*` must not be indiscriminately deleted.
- Preserve light/dark themes, OS text scaling and floating cart-only navigation. No replacement sidebar or bottom tab bar.
- Reference: 375 × 812 logical pixels, 48/34 simulated insets, DPR 2 exports. Production respects real device insets; never add a fake status bar to native layouts. Review 320/375/800 widths, 1×/1.6×/2× text, resizing and a 300 px keyboard inset.
- Maintain actual checkout/order/payment safety: latest-state delivery quotes, exclusive benefits, accepted creation snapshot, refusal retaining draft/cart, unknown acknowledgment locking resubmission, server-confirmed payment only, historical payments preserving unrelated cart.
- Preserve endpoint names, relation identities, persistence and supported behavior. No invented inbox/unread count, support phone, ETA, scheduled delivery, tips/rating, card deletion, bank success or certificate code.
- Shared primitives remain `lib/design/*` and `lib/ui/*`; the existing strict development gallery remains the preview surface. No parallel architecture/preview system.
- LSP references precede exported API changes/deletions. Permanent regressions assert behavior, arithmetic, state transitions, boundaries and persistence—not wording, source text or forwarding.

## Active inventory: controls, destinations, states and sources

| Surface | Visible controls → real destination/action | Data and required states |
|---|---|---|
| Entry, intro, city/location onboarding | Slides, sign-in, city choice, explicit location/settings/permission or skip, continue/back | Existing city API/cache and preferences; loading/error/empty/stale, denied/unsupported permission, rejected writes; no automatic permission/IP lookup |
| Startup/profile completion | Startup retry; name, birthday, consent and completion | Existing full-info/profile contract; bounded startup, validation, saving/refusal; both themes |
| Home | Static logo; support → chat; star → bonuses/sign-in; heart → favorites/sign-in; bell → notification preferences; person → full-screen profile; store → store sheet; search; campaigns; kitchen/categories; products; active order; floating cart | Businesses/categories/promotions/products, optional account bonuses/order; loading, failure/retry, absent sections, missing/failed artwork; no invented phone/count |
| Browse/search/campaign/favorites | Category chips, search/clear, pagination, detail, like, stock-bounded quantity, cart | Existing store-scoped reads; idle/loading/error/retry/empty/unavailable. Fixture-only like mutations |
| Simple/configurable product | Back, like, required single/multiple/optional options, volume/container counts, add/save/cart | Actual Item/options/promotions/stock; missing image, invalid required choice, no stock, exact-group collision and cancel. Configuration has no exact Figma frame |
| Cart | Quantity/bottle-batch controls, explicit last-unit delete, exact configuration edit, recommendations, totals, checkout/catalog | Local persisted cart + selected store/recommendation reads; empty/stock/restore states; preserve siblings and explicit bottle mix |
| Checkout/payment/confirmation | Delivery/pickup, store/address, optional details, bag, bonus/promo/certificate, quote retry, create, saved-card/Kaspi selection, payment/history | Frozen quote/create/pay APIs; loading/refusal/unknown/pending/completed; keyboard-safe totals/actions. Production mutations prohibited |
| Profile/settings | Sign-in; orders/certificates/addresses/cards/FAQ/support; theme/telemetry; confirmed logout | Fresh full-info and preferences; guest/loading/unknown collection/failure/retry, return-from-child refresh, failed writes |
| Address book/map/details | Select/add/search/locate/settings, resolve point, details, save/edit, device-only removal/account hide, FAQ/back | Full-info/geocoder reads + serialized device preferences; unresolved point, stale search, denied permission, write failure/rollback. No server CRUD |
| Cards/hosted form | Refresh/retry, add, bank launch/reload/back, waiting/cancel; payment selection where identity exists | Existing full-info/cards/link contracts; distinguish summary mask from chargeable ID; empty/error/auth/timeout/partial read; bank return alone is not binding success |
| Orders/detail | History, refresh, repeat/pay, real totals/items/events, support/FAQ/cart | Existing read-only history/detail; unknown fields remain unknown; fixture-only repeat/create/payment |
| Bonuses/certificates | History/explainer/FAQ; code/QR only when supplied; certificates filter/claim/buy; amount/recipient/message/card/pending status | Existing bonus/certificate APIs; loading/empty/error/refusal, persisted page-session pending identity, supplied-code completion; synthetic mutations only |
| FAQ/support/notifications | FAQ search/sections/retry/back; chat history/draft/order attachment/send/retry; notification switches | Existing FAQ content/chat service/preferences; loading/empty/error/acknowledged send, no fake operator/inbox |

## G1 — readable typography and adaptive components

**Problem/evidence.** `AppTypography.caption/label` are 8/10 px, compact card price/savings use 6 px, and `ProductRow` uses explicit 10 px styles. `ProductCard` is 110 × 240/213 with one-line titles and a 30 px stepper; larger text alone would clip. Active startup/profile completion still use legacy `.s/.sp` scaling.

**Dedicated implementation plan.**
1. Set deliberate readable roles: primary body/actions 16 px; secondary product/store/field text 14 px; auxiliary badge/caption/old-price/saving text at least 12 px. Preserve 16/20/24/32 heading hierarchy, TikTok Sans and variable-font axes. Document departures from tiny Figma metadata instead of claiming pixel parity.
2. Replace explicit 6–10 px consumer text in active shared components and remaining screens with roles. Preserve OS `TextScaler`; no clamping or `FittedBox` shrinking.
3. Make product cards/rows flow-based with wrapping titles/prices, real control hit targets and heights derived from available width/text scale. Rework every active grid/strip consumer to use the same sizing API; no duplicated magic heights or narrow three-column layout with unreadable text.
4. Migrate startup/profile-completion off the legacy scaling/color stack before deleting it. Keep form validation, submit contracts, birthday selection and required-profile gate.

**Acceptance.** Names, units, prices, savings and actions are legible without overlaps at 320/375/800 and 1×/1.6×/2×; unavailable stock remains disabled; keyboard/semantics actions operate the same cart. Both themes retain hierarchy/contrast. Existing gallery demonstrates cards, rows and active forms. Focused tests cover actual consumer layout/interaction boundaries, not font-constant copies.

## G2 — home composition and spacing

**Problem/evidence.** Home currently uses a 24 px top gap, fixed 57 px header/store, 38 px search, 114/128 px campaign strip, fixed 40 px carousel gutter and 144 px category tiles. Live campaign subtitles/missing artwork and larger fonts change anchors. The user's reported spacing defect is accepted; old synthetic screenshot conclusions are reopened.

**Measured design anchors.** Header x16/y72/w343/h57; store x16/y141/h57; search x16/y210/h38; campaigns y272/h114, selected x40/w295; kitchen x16/y410/h160; categories x16/y594/w343, 98 px artwork. The 48 px top inset belongs to the fixture/device, not home padding. Unsupported phone/unread labels are not real content.

**Dedicated implementation plan.**
1. Audit inset ownership and content width once. Use 16 px side gutters, 12 px header/store/search gaps and 24 px section rhythm; remove padding compensation/magic placement unrelated to content.
2. Make header/support/actions, store and search content-sized at readable roles, with wrapping/adaptive grouping and accessible targets. Keep all real actions visible; logo becomes static under G5.
3. Derive carousel width/gutters from the centered content constraints; use one consistent campaign height strategy and truthful copy fallback without hidden blank art. Empty campaigns consume no strip gap.
4. Make kitchen/category artwork and captions coherent; responsive columns and content heights must preserve titles at large scale. Do not invent artwork or pretend synthetic photos are production assets.
5. Keep the cart floating and reserve its clearance exactly once; live order/bonus/product sections participate in normal flow.

**Acceptance.** Readable 375 composition follows measured side gutters/section rhythm; intentional height departures are recorded. 320/800 and 2× text have no overlap or stranded actions. Exercise store cancellation/confirmation, search/category/campaign/detail/profile/bonus/cart destinations, absent campaigns, missing art and active-order states in strict fixtures. Review actual dark/light screenshots, not diff metrics alone.

## G3 — saved-card loading and binding

**Problem/evidence.** Profile reads full-info cards, payment/certificate use `/user/cards?source=halyk`; requests and link preparation are unbounded. The parser rejects the entire list for one invalid/mask-only record; fixtures assume the same ID-bearing records for both endpoints. Auth loss is reported as network failure. Exact production envelope/chargeable identity must be checked read-only if reachable.

**Dedicated implementation plan.**
1. Inspect existing documentation, read-only available account context and real endpoint shapes; distinguish display-only full-info summaries from chargeable bank card records. Do not invent an envelope or substitute a summary ID into payment.
2. Repair the observed envelope/source mismatch across profile/payment/certificate consumers. Keep an absent/malformed collection distinct from a genuine empty list; isolate invalid records only when their identity/mask safety can be preserved, with visible partial-data feedback.
3. Bound list and hosted-link preparation in `CardFlow` so timeout exits loading/preparing and exposes retry. Distinguish missing/expired authentication from read/network failures.
4. Keep duplicate launch suppressed and baseline identity trustworthy. Adding after a failed read must not falsely confirm an already-existing card; recover baseline or clearly keep unconfirmed state. Pending survives appropriate refresh/return and cancellation never claims success.
5. Remove empty-state magic offsets; use shared rows, FAQ panel and a keyboard-safe primary action. No unsupported overflow/delete control.

**Acceptance.** Strict fixtures exercise actual observed shape, empty, malformed/partial, auth loss, stalled read/link, retry, cancel and unchanged-count/new-ID binding. Profile, payment and certificate consistently show the intended card collection; only known chargeable identity enables pay. Actual gallery journey list → synthetic bank cancel/confirm → refresh proves state, without production binding/payment.

## G4 — bottling arithmetic and configuration

**Problem/evidence.** `price_type` is persisted but not read by pricing; container allow-list is {1,2,3}; volume is inferred from amount/name with a ≤20 heuristic; greedy allocation may silently change requested litres; quantity merging can use an unrelated option step. Preview duplicates cart arithmetic. No exact volume/container configuration Figma frame exists.

**Dedicated implementation plan.**
1. Obtain read-only public catalog examples and documented semantics for container option, quantity unit, `parent_item_amount`, ADD/REPLACE and promotions. The user clarified the gift policy: 3+1 means four physical litres, drink price for three, and ordinary charges for all four litres' containers. No new backend feature, free bottle or container discount is required.
2. Make the existing cart pricing calculation the single source for product preview, display-group totals and checkout. Respect confirmed ADD/REPLACE charge semantics, base-unit quantities and per-container factors; preserve order relation IDs and paid/free amount contract.
3. Accept actual positive container volumes, not 1/2/3 only. Container detection must use structured option/unit evidence rather than generic positive amounts or drink keywords alone. Do not guess millilitres solely from a large number or substitute a drink step for unknown container capacity.
4. Make allocations exact and whole for paid **and gift** volume; impossible targets fail visibly rather than dropping/overshooting litres. Keep paid selection separate from derived physical bottles so reopening, reload and stepping cannot gift the same litres again. Preserve the explicit paid mix and exact gift mix where representable; stock applies to all physical litres. Serialize actual whole-container volumes. Repeated orders must restore a valid paid/gift split from fulfilled physical volume, or explicitly refuse an unrepresentable group rather than inflate it.
5. Redesign the existing configuration route with product identity/artwork, clearly separated required choices and container quantities, paid/free volume, product/option/container/discount subtotal and one total/action. Labels must reflect price semantics. Use shared components; no invented pixel-match claim.
6. Delete the dead divergent cart allocation path under G7 after reference proof. Do not introduce a new automatic cheapest-container policy without a real contract/user requirement.

**Acceptance.** Real-shaped regression matrix covers fractional capacity, exact/impossible targets, ADD/REPLACE, stock boundary, promotions, sibling-preserving edit/cancel, persistence and repeat. For three paid 1 L bottles at 1000 ₸/L plus one gift litre, four ordinary 100 ₸ bottles give **3400 ₸ / 4 L**. Product preview = cart = checkout item subtotal; physical bottle capacity equals order amount, and no gift bottle is free or discounted. Strict gallery journeys select, add, step, edit/cancel/save, create and repeat an order with exact volumes/tariffs.

## G5 — delete logo drawer; clean navigation

**Problem/evidence.** `HomeScreen` creates `AppSidebar`; `HomePage.drawer` and logo open it. The component explicitly has no design reference. Header star/heart/bell/person plus full-screen profile already expose every supported destination/theme/logout. Legacy tab-index intents are declared but ignored by the active wrapper.

**Dedicated implementation plan.**
1. Check LSP references, remove HomePage sidebar/menu API, HomeScreen drawer-only identity/theme/logout parameters, wrapper drawer-only wiring and `lib/ui/app_sidebar.dart`. Logo is static artwork: no menu tooltip, click semantics, hidden drawer or renamed replacement.
2. Preserve full-screen profile entry and all header/profile destinations. Update the gallery and delete tests pinning obsolete drawer behavior; retain genuine destination behavior tests.
3. Replace vestigial tab-index navigation with explicit destinations where live notification/login/checkout callers need them. Preserve home return, notification → actual orders/order context and login continuation; do not stack another wrapper or revive tabs.
4. Remove stale comments claiming checkout/destinations are not rebuilt.

**Acceptance.** Actual home logo cannot open a drawer; account opens full-screen profile; bonuses/favorites/settings/orders/certificates/addresses/cards/FAQ/support, theme and logout remain reachable. Live notification/login/home continuation has defined exercised behavior. No `AppSidebar`/logo menu/openDrawer path remains.

## G6 — coherent remaining active screen families

**Dedicated implementation plan, per family.**
- **Browse/product/cart:** G1 responsive shared cards/rows feed home/catalog/category/search/campaign/favorites/recommendations/simple detail. Replace positioned tiny metadata, clipped prices and improvised configuration edit layout; stock/like/detail/quantity/cart actions retain meaning. G4 owns pricing/configuration semantics.
- **Checkout/payment/certificates:** Apply readable summaries, consistent selectable rows/inputs/feedback, shared spacing and inset ownership. Preserve pending/unknown locks, exclusive benefits and actual server identities; never make pending look successful. G3 owns card reads, G8 owns only authoritative Kaspi visuals.
- **Account/settings/help/loyalty/orders:** Review full-screen profile, profile completion, notification preferences, cards/addresses, FAQ/chat, bonuses/certificates and order detail/history for readable secondary text, coherent surfaces/actions and loading/empty/error retry. Remove forced-dark profile birthday dialog. Permission dialogs should inherit the same Material palette rather than an unrelated all-platform Cupertino surface.
- **Entry/onboarding/address:** Review intro/login/code, startup, city selection, store sheet, address search/map/details at narrow/large-text and keyboard states; retain explicit permission and persistence failure behavior. No arbitrary fixed vertical offsets that strand actions.
- **Missing visual coverage:** Extend the existing gallery/capture registry to bonus history/explainer, FAQ, notification preferences, intro/login and profile completion. Screen families without exact applicable frames are capture-only and named; notification settings are not mislabeled as the Figma inbox.

**Acceptance.** Every active inventory row has an exercised route/state and actual dark/light visual review or an explicitly unreachable native prerequisite. Critical controls/totals/fields remain readable/reachable under resizing/text scaling/keyboard. No fabricated reference-only behavior; no second design convention.

## G7 — unused code, resources and superseded implementations

**Dedicated implementation plan.**
1. Use scout inventory plus LSP references to remove the unreachable legacy shell: bottom menu/main/catalog/category/tap-board/liked/legacy search/cart/profile/bonus/orders and their private card/cart/search/dialog helpers. Preserve reachable `lib/pages/*` listed above.
2. Migrate live FAQ model/repository/open helper to the feature convention before removing legacy FAQ widgets and duplicate route name. Migrate live startup/profile-completion styling and MaterialApp legacy scaling initialization before removing `shared/app_theme.dart`/`utils/responsive.dart`.
3. Remove production-unused refractive widget/shader and its implementation-only test; remove obsolete legacy-screen tests, not active behavior regressions. Trim dead globals only after live callers are checked.
4. Prune assets/fonts/dependencies referenced solely by deleted code or nowhere in application/platform/dynamic bundling. Preserve splash config, plugin/platform entries and runtime asset contracts. Update pubspec/lock via one integration resolution and build.
5. Preserve legal documents/agreement files unless their product/legal replacement is established; an unreachable legal gate is not permission to delete legal material or silently introduce a new mandatory gate.

**Acceptance.** No active caller/import/asset reference points to removed files; one pricing/cart/screen implementation per active route. Full suite, analyzer, asset capture and release packaging succeed after cleanup. Any intentionally retained legal/platform/dynamic resource is named.

## G8 — authoritative Kaspi.kz presentation

**Authority.** `docs/kaspi.txt` supplies [«Оплата с Kaspi.kz»](https://www.figma.com/design/pNQjZoaE1v2Ud2cpqtU4sq?node-id=6192-46556), not merely QR usage guidance. Implemented from Russian web guide `6199:59680`; Kazakh guide confirms the same geometry. Official exports: compact `6199:60011`, Gold `6199:60019`, full logos `6199:60564` / `6199:60478`, compact payment button `6199:60489`.

**Dedicated implementation plan.** Read that authoritative document; inventory its required naming/logo/button/QR/copy/color/size/clear-space constraints; apply them to every active Kaspi selection/payment/pending/dialog surface without changing the frozen payment APIs. Use supplied/official assets, no recreated logo. Review each required state against document clauses in both themes and supported viewport/text scales.

**Acceptance.** Clause-linked evidence and actual visual review with no invented compliance. Use official SVG artwork intact, one contrast-appropriate button style and object layout, full logo at least 112 px, logo clear space at least 20% of its height, button height at least 48 px and surrounding clearance at least 8 px. Surrounding text follows inherited scaling. Pending/unknown/completed states cannot launch another payment or claim success; only existing server-confirmed completion navigates to success.

## G9 — integration and release

**Dedicated verification plan.**
1. After edits settle, format only owned changes and run focused affected-path regressions. Run full `flutter test --coverage --concurrency=1`, native `flutter test integration_test/shopping_e2e_test.dart -d windows`, then `dart analyze lib test integration_test tool`. Regenerate ignored LCOV; do not reuse previous counts as evidence. Test categories and cleanup measurements are in `docs/CLEANUP_PLAN.md`.
2. Launch the actual strict fixture gallery. Exercise home/profile/navigation, card timeout/retry/binding, exact bottling/price/edit/checkout, entry/account/address/help/loyalty/order families. Reject unknown requests and prohibit production mutations.
3. Capture/review changed and newly covered surfaces in dark/light at 375 × 812/48/34/DPR2; compare only exact matching frames. Review 320/800, 1.6×/2×, resizing and keyboard. Record intentional readable-size/unsupported-contract departures separately from image-diff noise.
4. Update `STATUS.md` and `FIDELITY.md` with measured current evidence, actual defects/fixes and unresolved prerequisites. Remove temporary probes after smoke proof.
5. Rebuild tracked `build/web` with `flutter build web --release --no-wasm-dry-run`; smoke the actual first-run entry at 375 × 812/DPR2. Close verification tabs/services. Do not claim native permissions/bank lifecycle, personal-account transactions or bank certification from synthetic fixtures. Source-linked official presentation review is separate from transaction certification.

**Completion rule.** Every reachable specified behavior and dedicated acceptance above is established; no placeholders/fake successes. Gift policy and authoritative Kaspi material are supplied and implemented. Native-bank/authenticated-production limits remain evidence boundaries, not prerequisites for the clarified client behavior or an app-wide production `DONE` claim.
