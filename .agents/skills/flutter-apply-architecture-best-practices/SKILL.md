---
name: flutter-apply-architecture-best-practices
description: Use when assigning Flutter feature responsibilities, reducing coupling, or performing an explicitly requested architecture refactor.
---
# Flutter architecture within the existing app

## Start with the actual ownership

This project already uses Provider/ChangeNotifier and manual models. Read the affected feature and callers; do not impose a new directory tree or a mandatory MVVM/repository stack.

| Existing location | Responsibility to inspect/reuse |
| --- | --- |
| `lib/features/*` | Active feature widgets, feature state and presentation data |
| `lib/widgets/authentication_wrapper.dart` | Active navigation, account/store coordination and feature wiring |
| `lib/services/`, `lib/utils/api.dart` | Existing external-service and HTTP boundaries |
| `lib/utils/` | Existing providers, cart/store state and shared utilities |
| `lib/model/`, feature-local model files | Existing manual data models |
| `lib/core/` | Shared contracts/value operations |
| `lib/design/`, `lib/ui/` | Existing theme/tokens and shared presentation |
| `lib/pages/*` | Remaining reachable legacy destinations; verify reachability before moving anything |

For a single cart-validation rule, extend its existing state/policy owner and caller tests. Keep the authoritative rule out of rendering code; enforce it at the command boundary before side effects, even if the button is disabled. A local widget's layout, animation and ephemeral interaction state do not require a ViewModel.

## Add boundaries only where needed

- Keep views focused on presentation and user intent; reuse existing providers/controllers for state. Expose meaningful loading/error/empty/success states without duplicating the same source of truth.
- Reuse existing service/repository APIs and injection. Extract a repository only when shared data ownership or source coordination needs one; add a domain/use-case layer only for genuinely complex/shared orchestration.
- Do not automatically add `freezed`, `built_value`, `get_it`, a Result framework, code generation, caching, retries or new state management. None is a prerequisite for one feature rule.
- An architecture migration must be explicitly scoped and migrate affected callers/tests coherently; do not create parallel old/new paths or move unrelated files.
- If existing caching is touched, key it by every relevant identity/context and preserve invalidation. A single `_cachedUser` returned for any requested ID is incorrect: requests for A then B must not return A. Do not introduce a cache just to demonstrate layering.
- Preserve provider lifetimes, disposal and in-flight state semantics. Moving ownership must not recreate the cart on navigation or allow stale async work to overwrite newer state.

## Test the changed boundary

Use `test/regression/business_provider_test.dart`, the affected provider/model test, and relevant `test/integration/` flow tests. For validation, assert valid/invalid/boundary inputs, visible recovery and **zero mutation requests** when invalid. Reuse strict HTTP fixtures and synthetic preferences; never use real account mutations, orders or payments for proof.

Run focused tests through `dart run tool/design_harness.dart check <existing-test-path>`; preserve the existing harness rather than adding another test scaffold.
