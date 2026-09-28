# Grounded recovery plan

This plan supersedes the old screen-by-screen execution sequence in `STATUS.md`.
It deliberately keeps only one active engineering focus. Later milestones are queued context, not current work.

## Current repository state

Measured on the current `dev_new_ui` HEAD (`64ee2d5`):

- Git working tree was clean when the audit began; the completed milestones below are currently uncommitted for review.
- The latest commit combines the home/FAQ/startup work, installed agent skills, and a regenerated web bundle.
- `build/web` is intentionally unignored and tracked today: 126 generated files. Do not remove it or rewrite history until the deployment convention is explicitly changed.
- The app is in a transition between two structures:
  - new code: `lib/design`, `lib/ui`, and `lib/features`;
  - still-active legacy code: `lib/pages`, `lib/shared`, `lib/globals.dart`, and large parts of `lib/utils`.
- `AuthenticationWrapper` is the bridge between rebuilt and legacy screens. Removing legacy files now would break reachable routes.
- The rebuilt home page is committed and has a focused interaction/layout test.
- Static analysis reports no errors or warnings. It reports 33 info-level lints, mostly in legacy code and tests.
- Full test baseline: **90 pass, 0 fail**, after the reviewed stabilization and API-safety milestones.
  Before it the suite read 57 pass / 8 fail, all 8 in `test/pricing/product_detail_bottling_test.dart`, and
  they shared one upstream cause: `ImageFilter.shader` invoked by `RefractiveGlassContainer` under the
  non-Impeller widget-test renderer, which aborted the build and took the price/quantity assertions down with
  it. The pricing behavior itself was never broken — it simply never got to run.
- Before milestone 2, API-related coverage was only 5 tests:
  - 2 JWT/session persistence tests;
  - 3 payload/model normalization tests.
- Milestone 2 adds 24 mocked endpoint-contract tests; no production request is made.
- `lib/utils/api.dart` is 4,401 lines. It combines transport, token storage, response parsing, endpoint methods, and models. Its endpoint methods call top-level `http.*` functions directly.

## Decision

Freeze visual redesign work.

Do not perform an app-wide restructure. First restore a trustworthy green baseline. Then protect the frozen backend contract with mocked transport tests. Only after those two steps should one screen be selected for redesign.

## Milestone 1 — restore the green test baseline — DONE

`lib/shared/RefractiveGlassContainer.dart` now probes `ImageFilter.shader` and falls back to its existing
blurred surface when the renderer cannot build a shader filter, remembering the answer so later frames skip
the shader path entirely. Web keeps its up-front skip; Impeller keeps the shader unchanged.

Evidence:

- `flutter test test/pricing/product_detail_bottling_test.dart` → **8/8**.
- `flutter test` → **65/65**.
- `dart analyze lib test` → **0 errors, 0 warnings**; infos 41 → 33, the 8 removed being that file's
  deprecated `withOpacity` calls, switched to `withValues` on the exact lines being restructured.
- Scope: one source file, one focused regression test, and documentation. No screen, route, API method,
  model, theme, or generated artifact changed.

The one remaining info on that file is `file_names` (camel-case filename). Renaming it would touch the import
in `product_detail_page.dart` and is out of scope under the non-goals above — leave it.

## Milestone 2 — API contract safety — DONE

**The seam question is settled: `http.runWithClient` intercepts the existing top-level `http.*` calls.** The
static `ApiService` is therefore testable as-is, and **no transport extraction or architecture change is
needed** to protect the frozen backend. That was the main unknown in this plan, and it resolved cheaply.

`test/utils/api_contract_test.dart` — 24 cases, all against `MockClient`, no socket opened:

- **home**: businesses (path, `page`/`limit` query, `Accept` header, envelope unwrapping), promotions
  (`limit`/`offset` always, `business_id` only when known, envelope returned), supercategories (absent and
  singleton child collections normalized to lists), bonuses (no token ⇒ *zero* requests; with token ⇒
  `Bearer` header, raw body returned).
- **auth**: send-code (`phone_number` body, 200-only), verify-code (**202**-only, both body fields, token and
  its decoded expiry persisted), full-info (no session ⇒ zero requests; bearer + `data` unwrapping; 401 ⇒ null).
- **catalog**: category items (nested `/categories/{id}/items` path, business scoping, envelope returned).
- **failure contracts**: `success:false`, non-2xx, malformed JSON, and the 429 cooldown precedence —
  `retry-after` seconds, else the wording («2 минуты» → 120), else the 60-second default.

Two asymmetries are now pinned that previously existed only in code, and both are traps for future callers:

1. `sendAuthCode` accepts only HTTP 200 while `verifyAuthCode` accepts only HTTP 202.
2. Return shape is **not** uniform — `getBusinesses`, `getFullInfo` and `getSuperCategories` unwrap `data`;
   `getActivePromotions` and `getCategoryItems` return the whole envelope; `getUserBonuses` returns the raw
   decoded body that `HomeDataSource._payloadOf` then unwraps.

Evidence: `flutter test` → **90/90**; `dart analyze lib test` → 0 errors, 0 warnings, and the new files
add no infos.

## Milestone 3 — authentication presentation — DONE

`lib/pages/login_page.dart` now uses the shared palette, typography, radii, icons, and constraint-based
layout. The phone formatter, `_sendCode`, cooldown timers, `_verifyCode`, token persistence,
notification-token sync, checkout redirect, and `AuthenticationWrapper` navigation are unchanged.

Evidence:

- four widget tests cover dark/light phone entry, validation, 429 cooldown, and the successful transition
  to six-digit entry against `MockClient`;
- the 375 × 812 phone and code states were rendered in a temporary real-browser preview; the mock handled
  both CORS preflight and POST, so no SMS or production request occurred;
- browser review found and fixed two issues that widget presence assertions missed: the top bar
  shrink-wrapped around the wordmark (making the back control overlap it), and the scroll child centered
  the form vertically instead of matching the Figma top offset;
- the final browser frames have an isolated 40 px back target, centered 164 px wordmark, title near the
  design's 200 px vertical position, 54 px fields/code cells, and no console errors;
- `flutter test` → **94/94**; `dart analyze lib test` → 0 errors, 0 warnings.

## Conditional structure work

Architecture changes are justified only by evidence from the API-test milestone.

Known duplication to evaluate later, not remove now:

- `lib/design/theme.dart` and `lib/shared/app_theme.dart`;
- new `lib/features/*` screens and still-routed `lib/pages/*` screens;
- item models in `lib/model/item.dart` and API-local response/model classes;
- static transport, persistence, parsing, and domain models inside `ApiService`.

Decision rule:

- if the current structure is testable with a small seam, keep it during the redesign;
- if one dependency prevents isolated tests, extract only that dependency;
- never migrate unrelated callers in the same change;
- never keep old and new implementations after a route is fully cut over.

## Redesign work after stabilization

No next screen is active. Select exactly one before further production changes.

Remaining candidates:

- authentication presentation;
- addresses and cards;
- support chat;
- checkout under the existing no-POST verification boundary.

Each screen must be a separate reviewed change with its current behavior recorded before presentation changes begin.

## Deferred cleanup

These are not current TODO items:

- decide whether `build/web` should remain a tracked deployment artifact;
- reduce analyzer info lints in touched files only;
- delete legacy theme/globals/screens after their last route is migrated;
- split `ApiService` by domain only when incremental contract tests make that safe;
- revisit generated web-bundle commit strategy without rewriting existing history by default.
