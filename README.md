# Naliv delivery

Flutter delivery app. Production entry: `lib/main.dart` → `AppEntryGate` → `AuthenticationWrapper`. Active feature screens live in `lib/features/`; some reachable checkout/account/product screens still live in `lib/pages/`.

## Setup

Use Flutter **3.41+ / Dart 3.11+**; this checkout was exercised with Flutter 3.44.8 / Dart 3.12.2. Check the platform toolchain with `flutter doctor -v`. Windows development and native end-to-end tests require Visual Studio's desktop C++ workload.

```sh
flutter pub get
```

Keep signing keys, Figma credentials and account tokens local. Android signing configuration has an example at `android/key.properties.example`. Do not commit credentials.

Android release versions come from `pubspec.yaml` (`1.2.116+12116`), not a second Gradle constant. The build uses Gradle 8.14.3, AGP 8.11.1, Kotlin 2.2.20 and Java/Kotlin target 17; AGP 9 migration is intentionally separate.

```sh
flutter build apk --release
flutter build apk --release --split-per-abi
```

Current production outputs are **1.2.116** under `build/app/outputs/flutter-apk/`. Use the same ABI as an earlier split install: ARMv7/ARM64/x86_64 splits have version codes **13116/14116/16116**, higher than the universal APK's **12116**. All four signatures were verified against the previous delivery; package `kz.gradusy24.app` and minSdk 24 are unchanged. A same-signature matching update preserves app data; do not uninstall just to bypass a downgrade. The three existing `build/fixed_apks/FIXED-*` copies were refreshed to 1.2.116 and hash-checked against the standard outputs.

## Safe local development

```sh
flutter run -d windows -t tool/dev_surface.dart
```

The gallery uses synthetic preferences and a strict HTTP fixture. Unexpected requests are rejected, never forwarded to production. Its controls select the surface, theme, width, text scaling and keyboard inset. A fixture web URL may use `?surface=active_route&guest=1` to remove only the synthetic auth token and exercise guest checkout/login continuation. Card/payment scenario names are the existing enums in `test/support/design_surfaces.dart`. VS Code's **Design fixtures (Windows)** launch configuration uses this entry point and supports hot reload.

The production API and personal account are read-only during verification: never send SMS, change addresses/cards, create real orders, buy certificates or execute real payments. Fixture checkout/payment is synthetic and does not establish authenticated production or bank/device acceptance.

## State ownership and recovery

- `AuthService` publishes credentials only after checked persistence. Capture an
  immutable token/revision with `captureSession()` for private async work; identity
  binding alone is not a credential change. Optional push startup/login failures
  remain retryable and cannot hold up local login/logout.
  Card consumers wait for their own verified login/profile return; merely publishing
  a new token cannot bypass a cancelled or incomplete reauthentication flow.
- `CartProvider.saveStatus` separates content changes from persistence progress.
  `ensureSaved()` gates checkout on the latest durable revision. Failed writes
  offer explicit retry. Unreadable saved carts remain untouched until explicit
  reload or a confirmed, checked clear; clearing an unknown-store cart leaves it
  unbound for normal store selection. The global notice scrolls independently under
  large text/keyboard constraints; its actions stay outside Navigator route semantics
  blocking, and notice transitions preserve the route and typed input.
- Cart/group pricing is evaluated once per operation with a captured time, never
  cached across promotion expiry. Presentation models carry structural catalogue
  keys for indexed quantity reads; exact bottle allocation preserves minimum
  count and input-order tie preference without microlitre-sized arrays.
- Financial creation reserves an account-owned durable intent before POST.
  Storage refusal sends nothing. Transport/parsing errors, HTTP 408 and 5xx remain
  unresolved across route/app recreation. Known IDs use existing read/status
  recovery; unknown without ID must not issue a second charge/order. An explicit
  server refusal permits a deliberate retry only after checked local settlement.
- Search pages own query generations and continuation; favorites/private address
  caches reject prior-session responses. Failed address drafts retain explicit
  retry/discard. Device-local addresses are distinct from account-derived data.
- Pure catalogue DTOs live in `lib/model/category_items.dart`; shared payload
  normalization lives in `lib/core/json_payload.dart`, not HTTP transport helpers.

Measured host results and release/device limits are recorded in
[`docs/CLEANUP_PLAN.md`](docs/CLEANUP_PLAN.md) and
[`docs/redesign/STATUS.md`](docs/redesign/STATUS.md).


## Working harness

`tool/design_harness.dart` coordinates the existing tools, not another preview app.
It runs child checks serially, rejects a busy harness lock, keeps logs/status under
`.figma_cache/harness/runs/`, and preserves an existing Android splash registration
without replacing unrelated generated plugins. Stop external Flutter runs too:
the lock cannot coordinate commands launched outside the harness.

```sh
dart run tool/design_harness.dart doctor
dart run tool/design_harness.dart refs --page "Design System (Light)" --frame "Каталог"
```

Frame lookup is offline by default; `refs --refresh` explicitly uses Figma's read-only
API. Use `--node` for duplicate names. Missing/mismatched cache records are reported,
not substituted. Full exporter help: `dart run tool/figma_spec.dart --help`.
Project skills live in [`.agents/skills/`](.agents/skills/). Start with
[naliv-design-loop](.agents/skills/naliv-design-loop/SKILL.md) for UI/harness work;
load other skills only when their trigger matches the task. The Dart/Flutter skills
are locally tailored to this app, not instructions to install another architecture,
preview system or test stack. Longer specialist references load only when needed.
`skills-lock.json` retains upstream installation provenance, not hashes of these local
customizations; review upstream updates before replacing them. Shared conventions
live in [`.omp/AGENTS.md`](.omp/AGENTS.md). Global OMP model/approval preferences
are unchanged. Runtime MCP still requires a running debug fixture app.


## Tests and analysis

- `test/integration/`: multi-component widget/transport flows.
- `test/regression/`: important money, stock, storage, auth and concurrency boundaries.
- `test/support/`, `test/fixtures/`: shared strict fixtures and test data.
- `integration_test/`: native chained shopping journey through the active route.

```sh
dart run tool/design_harness.dart check test/regression/design_harness_test.dart
dart run tool/design_harness.dart check --full --native
```

Run the affected file first, then `check --full --native` for retained tests, LCOV, analysis and the Windows journey. `check --plan --full --native` prints the sequence without running it. Keep Flutter processes serial: default-concurrency coverage previously exhausted memory on this workstation. Every harness test command uses `--concurrency=1`; the Windows journey ignores this setting internally but runs as one native process. It boots the active fixture wrapper with an empty cart, selects a store, browses a category/product, commits quantity two, resumes pickup checkout after synthetic OTP, includes the resolved synthetic bag, pays with a verified fixture card and opens server-confirmed paid history. Configurable-product, gift, mixed-bottle, legacy 3 L and unknown-payment boundaries remain covered by retained regressions.

For low-memory Windows native builds, set
[`CMAKE_BUILD_PARALLEL_LEVEL=1`](https://cmake.org/cmake/help/latest/envvar/CMAKE_BUILD_PARALLEL_LEVEL.html)
and `CL=/MP1` in the invoking shell. Flutter's test concurrency does not constrain
MSBuild/compiler jobs; an unrestricted run here exhausted memory in the C++ task.

## Visual review and release

Optional Figma capture/diff uses the same fixture architecture:

```sh
dart run tool/design_harness.dart capture all --theme both
dart run tool/design_harness.dart capture catalog,checkout_pickup --theme both --capture-only --width 320 --text-scale 2 --keyboard 300
```

The design reference is 375 × 812 logical pixels with 48 px top / 34 px bottom insets and DPR 2. Adaptive captures use isolated variant directories; they cannot overwrite canonical captures or manufacture fixed-reference diff metrics. Completed runs publish JSON evidence with dimensions and any measured differences. A fixture diff measures synthetic content, not usability or production behavior. Review interactions and both themes; preserve inherited text scaling and floating cart-only navigation. Unknown fixture URL scenarios fail visibly rather than falling back to loaded states.

Build the fixture gallery separately from the tracked deployment output:

```sh
dart run tool/design_harness.dart build
dart run tool/design_harness.dart serve --port 8790
```

The server accepts only GET/HEAD, binds loopback, and serves only the fixture-marked `.figma_cache/harness/web` output with caching disabled. OMP browser automation reuses `tool/design/fixture_browser.js`: owned tabs, loopback/CDN allowlist, service-worker/cache bypass, explicit DPR 2 and screenshot dimensions checked. Close owned tabs/services after proof. Build deployment output only after changes settle with `dart run tool/design_harness.dart build --tracked`; smoke tracked `build/web` separately with production mutations blocked. Debug Chrome DDC previously failed on this Windows workstation, so use native fixtures or release web instead.

## Floating material

`LiquidGlassDock` surrounds the entire cart badge/icon/amount and keeps controls sharp
above its underlay. The page itself is drawn from its GPU snapshot by Flutter's own image
painter, so it cannot depend on a per-device orientation measurement; the shader runs
only over the glass and its 14 px shadow ring and samples that snapshot: a
per-pixel-rotated 21-tap frost, rim-concentrated Snell refraction, mild
dispersion, Fresnel with a crisp top streak, and dithering. A theme base tint plus
adaptive shadow-lift/highlight-crush keep text readable without flattening the scene.
There is no per-frame CPU readback. A single **4 × 2** paired probe at
`LiquidGlassDock.warmUp` compares the shader with Flutter's normal image painter in
the same image; a vertically reversed offscreen read-back cannot reverse the decision, and
a wrong measurement can at worst mirror the glass's refraction. The measured value is
logged once (`adb logcat -s flutter`).
`flutter test integration_test/liquid_glass_orientation_test.dart -d <android>`
compares the page and glass against an unsampled reference on the device's real renderer.
Release 1.2.116 also initializes every application uniform in that paired probe and
keeps pixels outside the glass/shadow transparent, preventing undefined CanvasKit probe
output or an exterior sampled page from overwriting the upright painter. Actual host
pixel regressions and the Windows renderer suite cover these boundaries. The
375/768/1280 px release-fixture review includes both themes; strict production-bundle
reads and cart recovery are recorded separately in
[current verification evidence](docs/redesign/STATUS.md#app-wide-correctness-ownership-and-performance--2026-11-02).
Neither the physical Huawei nor the S25 Ultra was retested.

Decorative headers/chips are ordinary
`AppSurface`/`AppSectionAction` controls, not imitation glass.

`AppCartButton` keeps the floating full-width capsule but uses a 56 px cart stamp
and 72 px minimum control height, excluding margins. Filled counts/amounts are
centered; large totals scale to one line. Scroll clearance follows inherited text
scaling, so the final page content remains reachable above the dock.

iOS 26+ selects Apple's actual `UIGlassEffect`; older iOS and other supported Flutter
renderers use the shader. The native bridge requires **Xcode 26+** to compile. Apple
composition/lifecycle acceptance remains unexercised on this Windows workstation;
required Apple commands and checks are in [the design plan](docs/redesign/PLAN.md).
Do not put platform views into the Flutter-sampled underlay. These renderer paths are
not a claim of pixel-identical output or Apple-native material on non-Apple targets.

The catalogue/category/card-space and confirmation cutover is implemented and exercised
in strict Windows and release-web fixtures, including narrow/large-text/keyboard states.
[Current evidence](docs/redesign/STATUS.md) records settled tests, coverage, builds,
calibrated live-canvas captures and guarded release-entry limits; Apple runtime acceptance
remains separate.

## Plans and evidence

- [Repository cleanup](docs/CLEANUP_PLAN.md): scope, decisions and measured reductions.
- [Whole-app redesign plan](docs/redesign/PLAN.md): active-route controls and acceptance gates.
- [Current implementation evidence](docs/redesign/STATUS.md): exercised paths and limitations.
- [Figma measurements](docs/redesign/FIDELITY.md): diagnostic comparisons, not pixel-parity acceptance.
