# Naliv delivery

Flutter delivery app. Production entry: `lib/main.dart` → `AppEntryGate` → `AuthenticationWrapper`. Active feature screens live in `lib/features/`; some reachable checkout/account/product screens still live in `lib/pages/`.

## Setup

Install Flutter with the platform toolchain you need; check it with `flutter doctor -v`. Windows development and native end-to-end tests require Visual Studio's desktop C++ workload.

```sh
flutter pub get
```

Keep signing keys, Figma credentials and account tokens local. Android signing configuration has an example at `android/key.properties.example`. Do not commit credentials.

## Safe local development

```sh
flutter run -d windows -t tool/dev_surface.dart
```

The gallery uses synthetic preferences and a strict HTTP fixture. Unexpected requests are rejected, never forwarded to production. Its controls select the surface, theme, width, text scaling and keyboard inset. VS Code's **Design fixtures (Windows)** launch configuration uses this entry point and supports hot reload.

The production API and personal account are read-only during verification: never send SMS, change addresses/cards, create real orders, buy certificates or execute real payments. Fixture checkout/payment is synthetic and does not establish authenticated production or bank/device acceptance.

## Tests and analysis

- `test/integration/`: multi-component widget/transport flows.
- `test/regression/`: important money, stock, storage, auth and concurrency boundaries.
- `test/support/`, `test/fixtures/`: shared strict fixtures and test data.
- `integration_test/`: native chained shopping journey through the active route.

```sh
flutter test --concurrency=1
flutter test integration_test/shopping_e2e_test.dart -d windows
dart analyze lib test integration_test tool
```

Run the affected file first, then the retained suite. Keep tests serial: default-concurrency coverage previously exhausted memory on this workstation. The native journey includes product-page add, catalog quantity changes, pickup checkout, a saved-card fixture payment and paid order history; it does not launch the production bootstrap. Configurable-product, gift and mixed-bottle failures remain covered by retained integration/financial regressions.

## Visual review and release

Optional Figma capture/diff uses the same fixture architecture:

```sh
dart run tool/verify_surface.dart all --theme both
```

The design reference is 375 × 812 logical pixels with 48 px top / 34 px bottom insets and DPR 2. A fixture diff measures synthetic content, not usability or production behavior. Review interactions and both themes; preserve inherited text scaling and floating cart-only navigation.

Build the fixture gallery separately from the tracked deployment output:

```sh
flutter build web --release --no-wasm-dry-run -t tool/dev_surface.dart -o .figma_cache/quality_gallery_web
flutter build web --release --no-wasm-dry-run
```

Serve `.figma_cache/quality_gallery_web` for safe interactive fixture review. Serve tracked `build/web` for the real release entry/onboarding smoke; guard production requests against mutations. Debug Chrome DDC previously failed on this Windows workstation, so use native fixtures or release web instead.

## Plans and evidence

- [Repository cleanup](docs/CLEANUP_PLAN.md): scope, decisions and measured reductions.
- [Whole-app redesign plan](docs/redesign/PLAN.md): active-route controls and acceptance gates.
- [Current implementation evidence](docs/redesign/STATUS.md): exercised paths and limitations.
- [Figma measurements](docs/redesign/FIDELITY.md): diagnostic comparisons, not pixel-parity acceptance.
