---
name: flutter-setup-declarative-routing
description: Use when changing Flutter navigation, browser history, deep links, or an explicitly requested declarative router configuration.
---
# Flutter routing and deep links

## Trace the current route first

This is an existing app, not a routing scaffold. Inspect:

- `lib/main.dart`: `MaterialApp`, `AppEntryGate`, navigator key and observers.
- `lib/widgets/authentication_wrapper.dart`: active feature destinations, auth/store state and Navigator push/pop behavior.
- `lib/core/destinations.dart`, `lib/utils/app_navigator.dart` and `lib/utils/browser_history*`: destination intent and existing browser-history ownership.
- The actual caller and destination: `lib/features/*` is active; some reachable routes remain in `lib/pages/*`.

For an ordinary destination or return-navigation fix, reuse these mechanisms. Push detail screens on the existing stack and pop back to the originating category; do not reconstruct the category or create a new cart provider. Preserve result/refresh behavior, scroll state, guest-login continuation and route observers. Do not run `flutter create`, add `go_router`, switch to `MaterialApp.router`, or introduce a sidebar/bottom navigation as incidental setup. The current design uses floating cart-only navigation.

## If declarative routing is explicitly in scope

Record the URL contract, target platforms, auth redirects, unknown/invalid links, direct-entry fallback and back-stack/state expectations before selecting an API. Read the installed SDK and package documentation before changing dependencies.

- A router migration must preserve the entry gate, shared providers, themes, telemetry observers and guest checkout continuation. Replace existing history ownership in the same migration; never run two independent history systems.
- With `go_router`, `GoRoute` maps paths; `ShellRoute` wraps routes and `StatefulShellRoute` preserves parallel branches. A shell is justified by actual navigation requirements, not a large viewport.
- Hash URLs can be valid. Path URLs require hosting rewrites to the Flutter entry document and correct deployment base paths; removing `#` alone does not enable deep links.
- Android verified App Links require matching intent filters and hosted `assetlinks.json` with real package/signing identities. iOS Universal Links require associated domains and matching AASA data. Do not invent domains/IDs or enable conflicting deep-link handlers.

## Prove route behavior safely

Extend `test/integration/catalog_flow_test.dart` or the relevant active-route test using existing strict fixtures. Check detail/back returns, category/cart preservation, repeated navigation and guest/auth transitions. Explicit deep-link work also needs cold/warm entry, refresh, browser Back/Forward and malformed-link checks on each target.

Use `DesignSurfaceApp(surface: 'active_route', brightness: ...)` with the fixture setup in `test/support/design_surfaces.dart`; never exercise real account mutations. Run affected tests via `dart run tool/design_harness.dart check <existing-test-path>`.

Reference: [Flutter navigation and routing](https://docs.flutter.dev/ui/navigation).
