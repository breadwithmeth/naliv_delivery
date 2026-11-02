# Repository simplification

## Goal and boundaries

Make the app and repository easier to understand, cheaper to verify and lighter to run. Remove unnecessary tests and code rather than hiding them behind new abstractions. Keep integration/end-to-end journeys and small, important regressions for money, stock, persistence, authentication and payment uncertainty.

Production verification stays read-only. Preserve the existing API contracts, paid/free bottle allocation, chargeable card identity, durable payment locks, draft recovery, dark/light themes, text scaling and floating cart-only navigation. The active route is `main.dart` → `AppEntryGate` → `AuthenticationWrapper`; reachable `lib/pages` implementations are not automatically obsolete. User changes to the Android generated plugin registrant are outside cleanup ownership. Tracked web output remains the deployment artifact.

## App-wide quality review and restructuring — 2026-11-02

The current request is a whole-app correctness/performance review with restructuring
and edge-case coverage, not another isolated patch. Preserve the frozen API,
paid/free bottle policy, themes/geometry, real glass, signing and platform support.
Prior 1.2.115 verification is historical until this pass is integrated.

### Coverage and ownership

| Workstream | Reviewed surface | Required correction / structural boundary |
|---|---|---|
| Cart/domain | Models, quantity/stock/configurations, gifts, promotion/bonus math, persistence, repeat restoration | Visible failed-save/retry state; latest merged catalogue metadata; truthful partial repeat outcome; operation-scoped evaluation and indexed catalogue quantity |
| Financial flows | Checkout/quotes/benefits, order creation/recovery, cards/payments, certificates, order history/detail | 408/5xx uncertainty; account-owned durable intent before mutation; retained recovery identity; complete benefit snapshot; store-scoped packaging data |
| Browse/rendering | Home, categories/pagination, search, favorites, product routes, cards/images/design/glass | Latest-query ownership/continuation; shared favorites reconciliation; narrow cart subscriptions and physical-width image decoding |
| Identity/comms | Auth/profile/login/setup, chat, push/provider bridge, consent and fixture composition | Credential-labelled async work; private-state invalidation; injected provider; single-flight/serialized synchronization; optional provider detached from local auth |
| Address/onboarding | Permissions/location, map/search/details, local address book and checkout boundary | Latest intent wins; failed drafts remain retryable; malformed rows do not poison valid operations; bounded reads; canonical label separate from display details |
| Platform/tooling | Native entry/configuration, browser/history/workers, hosting/build/assets and fixture harness | Existing platform decisions retained; lock owns marker/build/serve lifetime; fixtures cannot initialize production push |
| Shared API/composition | HTTP headers/ownership, typed normalization, pure-model imports and app entry | Remove needless public-GET preflights; separate catalogue decoding from transport; integrate credential/cart-durability contracts |

Source review yielded five prioritized hypotheses in each feature/domain slice and
two harness findings. Regressions/measurements must verify them before a fix is claimed.
Review alone does not establish physical-phone, Apple, bank, push or deployment acceptance.

### Shared contracts and decisions

- Identity owns `AuthService.credentialRevision`, `captureSession()` and immutable
  `AuthSession` (`token`, `revision`, `isCurrent`). Credential changes/local logout
  invalidate captures synchronously; verified identity binding alone does not.
  Provider cleanup receives captured prior credentials, never a newly stored account.
  Card consumers also retain their local reauthentication gate until that exact
  login route returns verified success; credential publication cannot bypass a
  required profile or cancelled verification.
- Cart commands retain synchronous in-memory responsiveness. Separate pending/failed/
  saved persistence state, explicit retry and `ensureSaved()` gate checkout on the
  latest durable revision. `restoreFailed` preserves unread original data and blocks
  edits until explicit `retryLoad()` or confirmed checked discard. A cold unknown-store
  discard resets unbound; ordinary store selection remains responsible for binding.
  Save-status changes do not broadcast cart-content revisions. Explicit replacements
  remain write-before-publish.
- A repeat that commits cart/store but fails address persistence reports a partial
  outcome, never a fictional atomic multi-key transaction or claimed restored address.
- Financial intent is durable/account-owned before POST. Storage refusal sends nothing.
  Known IDs use existing read/status recovery. Unknown without ID stays explicitly
  unresolved with orders/support navigation; absence from a list is not proof of refusal.
- Money evaluation is operation-scoped, not revision-cached across promotion expiry.
  Quantity/membership indices retain existing configuration, ordering and stock semantics.
- Exact bottle allocation uses no arrays proportional to microlitres, invented precision
  or quantity caps, approximate fills or price preference. Preserve minimum bottle count,
  earlier-input tie preference and existing bounded-availability behavior.
- Production and fixtures use a real provider boundary, not test-only production toggles.
  Fixture HTML omits production push initialization; tracked deployment HTML retains it.
  Harness lock acquisition precedes output mutation and protects active served output.

### Execution and verification

1. Write failing consumer regressions on existing entrypoints before bug fixes.
   Performance-only refactors start with old-path measurements and semantic coverage.
2. Implement disjoint ownership slices. Integration owner alone changes API/main,
   shared DTO imports, release metadata and documentation.
3. Migrate all affected callers; remove obsolete paths, aliases and test-only switches.
4. Measure bottle allocation, cart evaluation/lookup, public-GET preflights and image/
   rebuild bounds. No flaky timing assertions or phone frame-time claims from host timing.
5. Exercise strict fixture flows for ordering, refusal, disposal/recreation, account
   changes and failed-save retry; then run full serial tests/LCOV and analysis.
6. Rebuild tracked release web and signed production APKs; smoke actual release surfaces
   and record finding dispositions, benchmark context and external acceptance limits.

Use the supplied dirty feature checkout without reset/cleanup/commits. Keep production
verification read-only, heavy Flutter processes serial and ownership of mutable files
explicit. Stop owned services/Gradle after integration.

### Measured implementation evidence

Temporary Flutter host probes ran serially with identical synthetic inputs. These
are operation/decoded-image measurements, not physical-phone frame-time claims.

| Operation | Before | After | Correctness check |
|---|---:|---:|---|
| Exact fill, 4.75001 L from six-decimal capacities | 82–125 ms/call across 2/4/8 capacities; two 4,750,011-entry arrays | 0.036–0.213 ms/call across the same cases; no target-sized arrays | Same exact ten-bottle allocation; independent small-case enumeration and large-count cases |
| Cart evaluation, 500 rows × 10 render/submit-style evaluations | 9,115.150 ms | 167.242 ms | Identical price and quantity checksums; coherent physical/order/discount evaluation |
| Catalogue quantity, 25,000 lookups / 500 cart rows | 941.616 ms through raw `Item` lookup | 9.112 ms through precomputed `ProductView.catalogKey` | Identical 112,500 quantity checksum; presentation conversion outside timing |
| 2000 × 2000 thumbnail, 176 logical-pixel card / DPR 2.5 | 16,000,000 decoded RGBA bytes | 400 × 400 / 640,000 bytes | Actual `ImageInfo` dimensions; detail heroes unchanged |
| Same source, narrow product row / DPR 2.5 | 16,000,000 decoded RGBA bytes | 176 × 176 / 123,904 bytes | Actual row image width 70.4 logical pixels |
| Ten cart increments on home | 10 page/header rebuilds and 300 unrelated card rebuilds | 0 page/header and 0 unrelated; affected card rebuilt 10 times | Actual keyed rebuild callbacks; category/promotion headers also stayed unchanged |

The first quantity-index change alone did **not** improve the raw-Item lookup loop:
it still reconstructed selection/default identity. Hot presentation paths now carry
their structural catalogue key. The host probe separately checked keyed and raw
lookup checksums. Promotion-sensitive money retains one captured operation time.
At 2× text / DPR 3, actual decoded card and row sizes were 792 × 792 and 252 × 252
respectively, preserving geometry while following the larger physical image budget.

The new exact solver matched independent exhaustive small inputs and large modular
cases. Twelve solver tests and eleven real harness subprocess cases passed together.
The combined post-cutover allocation/cart/business/repeat/save-recovery run passed
62 checks, including the temporary performance cases; this is not the final suite count.

An isolated Node execution of the tracked web bridge with a reject-once fake provider
passed retry, single-flight and listener-ownership checks. It made no live SDK call;
the disposable probe was removed after execution.

A fresh whole-change review identified two additional recovery gaps. Reject-once
provider login after a successful anonymous sync now retries identity binding rather
than publishing attempted ownership. Corrupt cart storage now offers a confirmed,
checked discard; cancellation/refused storage preserves original bytes and typed
input. A cold corrupt cart can reset to an unbound empty cart and use normal store
selection afterward. Both review regressions failed before correction and passed
afterward. No automatic reset, backend retry or production mutation was introduced.

Review limits remain explicit: source review does not establish test/build success,
benchmark speedups, physical/native rendering, external financial/push acceptance,
deployment/service-worker acceptance or generated-bundle parity. Integration evidence
must come from the parent-owned runs below, not reviewer confidence.

The release visual gate exposed two additional renderer defects absent from the
host shopping run. Raw sampled page pixels outside the glass could overwrite the
upright page; the shader now composites premultiplied glass/shadow over Flutter's
page painter without resampling that exterior. CanvasKit's installed WASM allocator
also leaves unwritten float slots uncleared: the probe initialized only size, leaving
bounds/flip undefined. Isolated actual-web RGBA showed correct source/reference but
transparent raw-shader output, then matching red/blue output after initializing all
application slots. The original 2 × 2 source / 4 × 2 read-back is retained. Larger
patches, timing changes and diagnostic logs were removed; no opaque fallback,
saturation boost, renderer substitution or per-frame CPU read-back was introduced.

The last compact recovery smoke reproduced a focused form with no usable height
at 320 px, 2× text and a 300 px keyboard inset. Recovery notices now have a bounded,
independently scrollable area; confirmation content scrolls without shrinking text.
The real-font regression reaches the clear action, cancels it, and preserves both
typed input and unread bytes. Recovery text/actions use the theme's high-contrast
foreground. Normal saved-cart layout is unchanged.

The production corrupt-cart startup rendered correctly, but Navigator route semantics
pruned both global recovery actions from the reachable accessibility tree. An explicit
semantics boundary around Navigator content confines route blocking without replacing
the child or losing typed input. The retained recovery test failed on an empty reachable
action set before the fix, then passed by invoking the actual semantic tap and verifying
cancel/refused-write/success outcomes. All four focused recovery tests and analysis pass.

### Final integrated evidence — 1.2.116+12116

- `CMAKE_BUILD_PARALLEL_LEVEL=1 CL=/MP1 dart run tool/design_harness.dart check --full --native`:
  **601 retained tests passed**; `dart analyze lib test integration_test tool` reported
  **no issues**. Fresh LCOV: **15,474 / 18,494 lines = 83.67%**, across 107 recorded
  source files. These are the final report's counts, not the earlier probe-inclusive LCOV.
- The strict Windows journey passed through the active wrapper, store/category/product,
  cart, synthetic login, pickup checkout/payment and paid history, asserting no unexpected
  requests/native HTTP escapes. The unchanged actual-renderer orientation suite separately
  passed **2 tests**.
- Tracked production web and signed universal/three-ABI APK builds passed after the
  semantic-boundary fix. `aapt`/`apksigner` confirmed version **1.2.116**, package
  `kz.gradusy24.app`, minSdk **24**, expected ABIs, codes **12116/13116/14116/16116**
  and signer continuity with 1.2.115. All three existing `FIXED-*` copies match their
  original output hashes. The user's existing splash-registration block was restored
  after external Flutter generation, without restoring obsolete/unrelated plugin entries.
- The actual final web bundle rendered healthy guest home in both persisted themes at
  375 × 812 / DPR 2: **5 GET / 0 OPTIONS** per navigation versus the measured old
  **5 GET / 5 OPTIONS**. Anonymous GETs carry no JSON Content-Type or Authorization.
  No page or console errors occurred.
- Final corrupt-cart web proof reached both recovery actions at 320 px. The light-theme
  cancel/confirmed-clear/home-retry/reload journey preserved bytes before consent,
  persisted `{business_id: 1, items: []}` afterward and retained it across reload.
  Its **13 known synthetic GETs** had no unknown requests, mutations, page or console
  errors. All application API requests were intercepted; no live account mutation occurred.
- **72 inspected release-fixture captures** and actual browse/cart/form/footer interactions
  are detailed in [`STATUS.md`](redesign/STATUS.md#app-wide-correctness-ownership-and-performance--2026-11-02).
  Temporary benchmark/diagnostic source files were removed. Owned browser tabs, web
  services and the release Gradle daemon were stopped.

Final evidence: `.figma_cache/harness/runs/2026-11-02T01-10-01.894312Z_5224.log`,
`.figma_cache/render/probe/quality116_coverage.json`, `quality116_apks.json`,
`quality116_network.json` and `quality116_production_final.json`.

Limits: host timings/fixtures and signatures are not physical Huawei/S25 Ultra,
Apple-native glass, handset permissions/GPS, real bank/push, authenticated production,
Linux Docker or deployed service-worker acceptance. No exhaustive-edge-case or
production recovery guarantee is claimed. No commits, resets, dependency upgrades,
signing changes or production mutations were performed.



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


## Configuration hygiene audit — 2026-10-29

The new audit added precise ignore guards for local caches/build output and restricted
Docker's context to the prebuilt static release plus nginx/control files. These changes
do **not** remove already tracked files. No index cleanup, unrelated deletion or platform
identity change has been applied.

| Approval-required candidate | Tracked files | Evidence / decision |
|---|---:|---|
| `ios/build/` | 325 | 63,811,157 bytes of Xcode build databases, manifests and module caches; untrack generated output, not native source or lockfiles |
| `.tmp-appdata/` | 4 | Local tool telemetry state |
| `.firebase/` | 2 | Historical Hosting upload caches, not Firebase project registrations |
| `.VSCodeCounter/` | 9 | Historical editor statistics |
| `coverage/` | 1 | Regenerated LCOV; retain published evidence separately if wanted |
| `.flutter-plugins` | 1 | Obsolete generated inventory with another machine's paths; already ignored |
| `android/local.properties` | 1 | Local SDK/Flutter paths and stale separator; already ignored. Keep the working local file when untracking |
| Root `flutter` gitlink | 1 | Git mode `160000`, empty working directory, no `.gitmodules` mapping; owner must confirm accidental pointer versus intended SDK pin |

If approved, prefer removing generated/machine-specific entries **from Git while keeping
their local files**, then retain the ignore guards. Do not blanket-untrack Gradle wrapper
scripts/JAR, native plugin registrants or tracked `build/web`; the latter remains the
intentional deployment artifact and is rebuilt after code settles.

Dormant Android/iOS/macOS Firebase registration files and historical FlutterFire generation
metadata also need an owner decision before retirement. The current Dart runtime uses
OneSignal, not FlutterFire; Android's local Google Services JSON is for another package
and is not consumed by the current Gradle configuration. This is stale configuration,
not evidence that public Firebase client keys are privileged secrets or that credentials
were disclosed. Firebase Hosting and provider-side FCM/APNs configuration remain relevant.

Keep Cupertino icons: the SDK birthday picker still uses the font. Keep the real
Geolocator location/permission path. The uncalled `permission_handler` method, import,
direct package and five platform packages were removed together after LSP reference
verification; this was not a mass dependency upgrade. Broader major-version upgrades,
R8/resource shrinking and notification icon/provider changes require their own concrete
compatibility/device evidence.

Desktop release identity remains a product/account prerequisite: macOS `naliv_delivery`
contains an invalid bundle-ID underscore; Linux's same GApplication ID lacks a period;
placeholder publisher metadata needs the approved legal publisher. Do not invent or
silently rename registered identities. Existing iOS Team/bundle/App Group/AASA values
agree and are intentionally preserved.

