# Repository simplification

## Goal and boundaries

Make the app and repository easier to understand, cheaper to verify and lighter to run. Remove unnecessary tests and code rather than hiding them behind new abstractions. Keep integration/end-to-end journeys and small, important regressions for money, stock, persistence, authentication and payment uncertainty.

Production verification stays read-only. Preserve the existing API contracts, paid/free bottle allocation, chargeable card identity, durable payment locks, draft recovery, dark/light themes, text scaling and floating cart-only navigation. The active route is `main.dart` → `AppEntryGate` → `AuthenticationWrapper`; reachable `lib/pages` implementations are not automatically obsolete. User changes to the Android generated plugin registrant are outside cleanup ownership. Tracked web output remains the deployment artifact.

## Baseline and evidence

- Previous integrated suite: 297 passing tests. The source tree has many feature/service/contract files but no `integration_test` directory.
- `lib/utils/api.dart` combines HTTP operations and multiple model families in 4494 lines; `lib/model` and `lib/models` also contain live domain models. Consolidation requires actual references, not filename assumptions.
- `pubspec.yaml` has 283 lines, mostly generated instructional comments. `.gitignore` repeats plugin entries; README still describes a new Flutter template.
- Home loading initially waits for four requests, then promotions, then product sections/active order. Startup initializes package information/Sentry before the app. These are investigation candidates, not yet approved behavioral changes.
- Test removal does not shrink the production binary. Runtime/dependency/asset improvements must be measured separately.

## General plan

| Step | Outcome | Gate/status |
|---|---|---|
| S1 Test portfolio | Fewer independent, high-signal tests; retain critical journeys and unique failure boundaries | Implemented: 76 low-signal cases removed, five safety regressions added; 227 host cases and one native shopping journey pass |
| S2 Runtime work | Remove proven avoidable requests, blocking work, copying or broad rebuilds | Implemented and measured: warm cart projection reuse; store/category work overlaps bonus/city reads; bootstrap reads coordinated |
| S3 Internal structure | Remove dead APIs/models and consolidate ownership where it eliminates real duplication | Completed: 16 dead API methods, ten obsolete DTOs and unreachable legal UI removed; one cart model and shared persistence fixture |
| S4 Dependencies/resources | Remove unused direct packages and orphan bundled resources; simplify configuration | Completed: Markdown and orphan bundled resources removed; Cupertino/legal sources preserved; v21 splash linked to the base bitmap; release bytes down 9.3% |
| S5 Developer workflow | Useful README, one small verification path, clear test categories and optional expensive visual checks | Completed: README, serial test/analysis/native tasks and duplicate ignore rules; reuse the existing fixture gallery |
| S6 Integration | Retained suite, actual fixture journeys, analysis, release build/smoke and truthful before/after evidence | Completed: focused 94, full 226 with coverage, one native e2e, clean analysis, both releases built and exercised; measured results below. The later glass/bounds work added one focused regression and re-ran the suite at **227** |

Each step gets its concrete implementation plan below before changes start. Update this document when research changes the scope; complete all reachable steps in this pass rather than parking unspecified follow-ups.

## S1 — Test reduction decision rules

1. Map each test's assertions to a consumer-visible failure: flow, arithmetic, capacity, stock, state transition, precedence, persistence, concurrency or refusal.
2. Delete wording/source/geometry/forwarding checks, incidental defaults and tests that merely repeat stronger same-path integration assertions.
3. Retain distinct financial/security/persistence/race boundaries even when unit-level. Do not merge unrelated cases into a giant test to disguise the count.
4. Prefer the existing strict fixture transport and real feature routes. Unknown requests must fail; never fall through to production.
5. Put retained flows and important regressions in an obvious small structure, removing abandoned helpers and updating commands/imports. Actual device/browser end-to-end proof must be distinguished from widget integration.
6. Record exact removed cases, retained risk categories, final count and execution time. No target coverage percentage or artificial count ceiling.

**Concrete portfolio decision.** The assertion audit found genuine safety coverage throughout the suite, but its conservative proposal retained too many low-priority cases. Keep financial/persistence/race contracts and actual multi-component journeys; delete routine endpoint request/payload echoes, ordinary formatting examples, purely geometric matrices and duplicate math exercised by stronger cart/checkout tests. Do not preserve those assertions in hidden mega-tests.

- Card flow: retain cancellation/baseline poisoning, duplicate-link suppression, URL/popup safety and late-result boundaries; remove unit rows already proven by saved-card API/page integration.
- Product configuration: retain required choices, edit/cancel/sibling isolation, persistence, exact mixed stepping, gift preview recovery and fractional replacement. Remove UI math/stock examples covered by the canonical bottling contract.
- API/name helpers: retain the auth acknowledgment/storage, malformed city data and name-corruption/ordinal/precision boundaries; remove ordinary transport echoes and cosmetic examples.
- Layout/content: remove order-card rectangles and checkout/chat theme-width matrices from permanent tests. Actual fixture review/capture remains optional. Trim low-risk FAQ/notification/profile-copy coverage and redundant route-only rows, not charge/draft/stock transitions.
- Move retained widget integration files under `test/integration` and important pure regressions under `test/regression`, keeping fixture/support ownership separate. Add a small native fixture end-to-end checkout journey under `integration_test` only where it spans a genuinely missing app boundary; reuse existing routes/transports.

Parent owns reorganization, native e2e, packaging and integration. Test edits are divided into disjoint card/product and peripheral files; all checks run after edits settle.

## S2 — Runtime optimization plan

**Concrete changes.** Cache cart display-group membership/order per committed provider mutation after verifying that consumers do not mutate provider-owned rows. Invalidate at every mutation/load boundary, preserving gift-allocation repair, zero-quantity rows, sibling configuration checks and first-seen ordering; retain behavior regressions for those transitions. Overlap home requests only when their true store/category prerequisites are known: promotions and active status need not wait for bonus/city reads, and products need only the store/category data. Keep auth cleanup and freshness semantics; do not introduce speculative duplicate home loads or new network caches. Bootstrap consent/package reads may overlap, but consent must still be available before Sentry initializes.

## S3 — Structure plan

**Concrete changes.** Use LSP to remove zero-caller raw/typed API convenience methods and any model families made obsolete by that cutover. Keep request/response normalization for live callers, payment/reauth/contracts and meaningful retained tests. Remove the unreachable `OfferPage`/`AgreementWrapper`/`MandatoryOfferPage`/`AgreementService` cluster plus its obsolete scaling helper: parent LSP found only internal references, not active routes. Keep the legal documents themselves. Remove the unused `LocationMixin` from the root state, not the live location service. Avoid cosmetic wholesale page moves or a new MVVM stack.

## S4 — Packaging plan

**Concrete changes.** Remove `flutter_markdown_plus` after the dead legal viewer cutover; exclude those now-unread legal documents from the Flutter bundle while retaining their source material. Keep `cupertino_icons`: the SDK's birthday picker requires its font, and a prior observed build warning already established that dependency; a source-import grep is insufficient to remove SDK assets. Remove the unreferenced web splash PNG and its output copy. The identical Android `drawable-v21/background.png` can resolve to the base drawable; remove only that duplicate, preserving the splash appearance/configuration. Do not trim Flutter engine variants/symbols without an SDK-backed packaging rule. Keep tracked web deployment and signing/native configuration.

## S5 — Workflow plan

Replace template instructions with current setup, fixture launch, retained test commands, analysis and release/e2e smoke commands. Keep expensive visual capture/diff optional, not multiplied into permanent geometry tests. Remove duplicated ignore/config comments without changing working launch/platform configuration.

## S6 — Verification and completion

- Run retained tests with `--concurrency=1`, including the focused affected behavior before the full suite.
- Run `dart analyze lib test integration_test tool`.
- Build and exercise the strict fixture release through active routes and interactions; inspect the actual surface, not just test counters.
- Rebuild tracked web release, smoke entry/onboarding at 375 × 812 / DPR 2 and guard production mutations.
- Record final structure, test/footprint/work measurements and explicit native/authenticated-production limits. Remove temporary probes and close only owned services/tabs.

## Completed evidence — 2026-10-04

### Test portfolio and runtime proof

- Removed **76 expanded low-signal cases**, added **four cart invalidation regressions and one early async-failure regression**: **297 → 226 host cases**, a net reduction of **71 / 23.9%**. This is real case removal, not consolidation inside tables. There are **21 integration and 21 regression files**, plus one native e2e file.
- Focused changed-path run: **94 passed**. Full `flutter test --coverage --concurrency=1`: **226 passed**, 123.54 s wall time. LCOV: **10,331 / 14,063 lines = 73.46%**. The smaller coverage denominator is not itself evidence of stronger coverage.
- Native Windows e2e passed: active authentication wrapper → home category → complete catalog → plain `ProductPage` add → catalog quantity **2 / 26,340 ₸** → cart → pickup checkout (**26,370 ₸**, including the package) → saved-card fixture payment → completed order history. Asserted one created order, correct product/package amounts, acknowledged cart clearing, completed payment and **zero unexpected requests / native HTTP escapes**.
- `dart analyze lib test integration_test tool`: **no issues**. Both fixture and tracked `flutter build web --release --no-wasm-dry-run` builds passed. Cupertino icons remain bundled and tree-shake to 1,472 bytes, rather than being removed based on app-import guesses.
- Disposable work probe: **50 rows, 10,000 paired display/active reads**, **zero warm projection rebuilds**; one rebuild after mutation and one after reload. Cached reads took **1,043 μs** versus **316,331 μs** for equivalent uncached grouping/sorting/filtering in the Dart test VM. This measures projection work, not startup time or production frame speed; prices/physical gift calculations remain live.
- Deterministic home probe held both bonus and city responses. Promotion, category-product and active-order reads started before either hold was released; final fixture store/products loaded successfully. The corrupt-storage test failed before coordination with unhandled bonus/sign-in exceptions, then passed after the fix.

### Measured footprint

Byte sums include all files under the named directories; Dart/test file counts use `*.dart`/`*_test.dart`. Gzip uses `gzip.compress(main_js, mtime=0)`, matching the saved baseline.

| Measure | Before | After | Change |
|---|---:|---:|---:|
| `lib/` bytes | 1,251,641 | 1,193,233 | −58,408 / **4.7%** |
| Dart source files | 113 | 108 | −5 |
| `test/` bytes, including support/fixtures | 502,372 | 453,392 | −48,980 / **9.7%** |
| Host test files | 45 | 42 | −3 |
| New native e2e source bytes | 0 | 4,818 | +4,818 |
| Test source bytes including native e2e | 502,372 | 458,210 | −44,162 / **8.8%** |
| Tracked web release bytes | 50,302,831 | 45,613,042 | −4,689,789 / **9.3%** |
| Web asset bytes | 2,376,701 | 2,316,277 | −60,424 / **2.5%** |
| `main.dart.js` bytes | 4,694,903 | 4,695,396 | **+493** |
| `main.dart.js` deterministic gzip bytes | 1,314,115 | 1,314,542 | **+427** |

The JavaScript payload is effectively unchanged, not smaller. Dead declarations were already largely tree-shaken; improvements are source/test maintenance, resource distribution and repeated runtime work. Flutter engine variants/symbols were not deleted.

### Actual surfaces, safety and limits

- Release fixture at **375 × 812 / DPR 2**: light active home → typed search `Aperol` → three supplied results → add/increment → **26,340 ₸ / quantity 2** → cart → decrement → explicit final delete → empty cart / **0 ₸**. No production API requests, non-read requests or browser runtime errors were recorded.
- Dark cart at inherited **1.6× text** rendered **105,360 ₸**, readable wrapped rows and the fixed checkout footer. Real pointer-wheel scrolling exposed the final row; screenshots, not semantics-only scroll offsets, establish that review. No browser runtime errors were recorded. This was not a new full Figma comparison sweep.
- Tracked release rendered intro and actual city onboarding. Anonymous **OPTIONS `/api/users/cities` → 204 / GET → 200** supplied Astana, Karaganda, Pavlodar and Temirtau controls. GET/OPTIONS-only guards were active during navigation; four Sentry envelope attempts were deliberately blocked, not counted as application exceptions. No API mutation, SMS, real checkout or payment was performed; the personal-session 401 was not retried.
- AAPT2 compiled/linked app resources with a temporary minimal manifest. The v21 launch-background XML references the same base drawable resource/PNG; no duplicate v21 bitmap is required. This proves resource resolution, **not** an Android/iOS device run or APK acceptance.
- Release generation removed development-only splash registration from the Android registrant. The pre-existing user registration was restored after builds; the original Java content was preserved rather than blindly accepting generated changes.
- Browser selector waits incorrectly assumed text/`aria-label` representations; actual observation and screenshots established the controls. A nested `tab.id().click()` helper discrepancy was reported and worked around with a guarded native page click. These automation failures are not an application clean-console claim.
- Native e2e, mock transports and pixel review do **not** establish authenticated production, real bank/Kaspi acceptance or mobile IME behavior. Existing financial/auth/stock/gift regressions remain; no production fallback was added.

## Revision log

- Initial plan: evidence-led test reduction plus runtime/structure/packaging cleanup. Current test count is a baseline, not a quality target. Avoid a wholesale rewrite until a real duplication/cost is demonstrated.
- Assertion audit revision: rejected blanket unit-test deletion and cosmetic count consolidation. Several hundred tests include important unique finance/storage failures, so reduction prioritizes redundant/low-risk coverage. Missing chained checkout coverage will be verified using the existing strict fixture app rather than another preview architecture.
- Runtime audit revision: rejected removing the Cupertino font based only on app imports and rejected speculative auth/home overlap that could require duplicate refreshes. Chosen optimizations preserve store fallback, consent order and SDK picker rendering. Dead legal code is removed, but legal documents are retained.
- Card audit revision: page/API tests do not cover every parser/binding baseline edge identified by the scout. Keep those unique card-ID/PAN/duplicate/mask/cancellation/auth regressions; only remove assertions actually superseded by a stronger path.
- Async integration revision: reproduced unhandled bonus/sign-in failures while the store read was pending. Coordinated independent/core/scoped waits preserve failure propagation and overlap; one corrupt-storage regression now catches this boundary. Consent/package reads use the same coordinated-await rule before Sentry.
- Test move revision: the shared onboarding preference store was still outside the new categories, and one relative import broke. Moved it to `test/support` with LSP and repaired the unresolved caller; the full retained suite and analyzer then passed.
- Native fixture revision: integration-runner engine callbacks used their registration zone rather than the later HTTP test zone. The first attempt received an unauthenticated production 401; no production mutation occurred. The native test now re-registers the existing frame callbacks in the strict fixture zone and rejects any native HTTP-client escape. The passing journey asserted zero escapes and zero unexpected fixture requests. Plain catalog items correctly open `ProductPage`, not the option editor; the native journey follows that real route, while retained bottling tests cover options.
- Post-cleanup revision: the user then asked for the design's glass material, a bounded cart control, a smaller add-to-cart confirmation and gutter-bounded category tiles. That work added one focused home bounds regression (**227 host cases**; `dart analyze lib test integration_test tool` clean; coverage **10,389 / 14,122 = 73.57 %**) and left the measured cleanup footprint unchanged. Details and the measured before/after geometry are in `docs/redesign/STATUS.md`.


