---
name: naliv-design-loop
description: Use when changing Naliv screens, Figma fidelity, adaptive layouts, rendering effects, or the fixture/design harness in this repository.
---

# Naliv design loop

Use the existing active-route fixtures; visual similarity is not interaction proof.
Read `.omp/AGENTS.md` for shared safety rules and `README.md` for harness/platform details. Run commands from the repository root.

## Scope the change

1. Inspect `lib/widgets/authentication_wrapper.dart`; `lib/pages/` is not uniformly legacy.
2. List visible controls/destinations, loading/empty/error/disabled states, data sources and purchasing/auth invariants.
3. Identify the exact Figma frame/node and intentional departures. Read only the relevant companion skill.
4. Reuse `lib/design`, `lib/ui`, `tool/dev_surface.dart` and `test/support/design_surfaces.dart`. One owner per shared layout; integrate before running checks.

## Quick reference

Prefix commands below with `dart run tool/design_harness.dart`:

| Need | Arguments |
| --- | --- |
| SDK/cache availability | `doctor` |
| Offline Figma lookup | `refs --page "Design System (Light)" --frame "Каталог"` |
| Native hot reload | `preview` |
| Focused regression | `check test/regression/design_harness_test.dart` (substitute the affected file) |
| Full tests, coverage, analysis, Windows journey | `check --full --native` |
| Canonical capture | `capture catalog --theme both` |
| Adaptive capture | `capture catalog --theme both --capture-only --width 320 --text-scale 2 --keyboard 300` |
| Fixture release | `build`, then `serve --port 8790` |

`refs --refresh` explicitly accesses Figma; use `--node` for duplicate names. Missing/mismatched references stay missing. Brand exports use `.figma_cache/issue_brand_assets.json`.

## Safety and verification

- Production/account verification is read-only: no SMS, orders, payments, certificates, card/address changes, returns or support messages. Never expose credentials.
- Fixtures reject unknown requests/selectors; no production fallthrough or catch-all success.
- Stop owned previews before checks/builds. Run Flutter processes serially; the harness lock cannot coordinate external commands. Low-memory native builds also need `CMAKE_BUILD_PARALLEL_LEVEL=1` and `CL=/MP1` in the invoking shell; test concurrency does not limit compiler jobs.
- Preserve both themes, inherited text scaling, >=44 px controls and floating cart-only navigation. Canonical geometry: 375 × 812, DPR 2, 48/34 px insets. Adaptive captures are capture-only.
- Runtime MCP requires a running debug fixture; it cannot inspect release web. Use LSP for code intelligence. Avoid the previously failing Chrome DDC launch.

## Runtime example

In OMP Eval, resolve the helper from the repository root (use an absolute file URL if Eval has another working directory):

```js
const fixtures = await import('./tool/design/fixture_browser.js');
const tab = await fixtures.openFixture(browser, {
  name: 'owned-catalog-320', surface: 'catalog', theme: 'light',
  width: 320, scale: 2,
});
try {
  await tab.observe();
  // Act with fresh observed handles; observe the resulting state.
  await fixtures.capture(tab, '.figma_cache/harness/catalog-320.png', {width: 320});
} finally {
  await tab.close();
}
```

`capture` resets viewport geometry: pass adaptive width again. Repeat for dark; inspect controls and reflow. Review logs/JSON evidence, not stale artifacts. Shader refraction, blur and Apple-native glass require distinct renderer proof; see README's floating-material limits.

After smoke proof, update existing `docs/redesign/STATUS.md` evidence. Fixture captures never establish authenticated production acceptance; deployment output requires a separate `build --tracked` and guarded smoke. Stop only owned services and remove only owned probes.
