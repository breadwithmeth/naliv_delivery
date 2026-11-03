---
name: naliv-real-data-ui-pass
description: Use when changing how any Naliv screen looks (catalogue, product, cart, checkout, address, orders, profile, bonuses), when a screen looks messy, cheap, cluttered or unlike Figma, when the user rejects a UI pass, or before calling a visual change finished.
---

# Naliv real-data UI pass

**Core principle:** a screen is finished when it looks deliberate *with the live catalogue*, in both themes, and every control visibly does something. Fixture captures and pixel diffs are inputs, not the verdict: the single short «Aperol» fixture once passed every check while real names broke every card.

**REQUIRED BACKGROUND:** naliv-design-loop (harness commands, safety, fixtures).

## 1. Look at the real thing first

Serve the tracked bundle and render real stores. The helper installs a guard before the app loads that rejects every write (non-GET fetch/XHR/beacon) for the tab's whole life:

```js
const real = await import('./tool/design/real_data_browser.js');
// bash: python -m http.server 8794 --bind 127.0.0.1 --directory build/web
const tab = await real.openRealStore(browser, {name: 'r9', store: real.STORES.temirtau});
await real.tapWhere(tab, (e) => e.name === 'Слабоалкогольные напитки');
await real.shot(tab, '.figma_cache/render/probe/before_catalog_b9.png');
await real.assertReadOnly(tab); // throws if any write reached the network
await tab.close();
```

Capture **before** shots of the affected screens, light and dark, at least two stores (store 11 sells «Кухня»; others must not).

| Real data as a guest (helper) | Fixtures only (`openFixture`, never production accounts) |
|---|---|
| home, catalogue, category, product, search, cart, store/address pickers | favorites, orders and order detail, profile, addresses, cards, certificates, bonuses, checkout submit and payment |

For fixture-only screens, stress the fixture with real-shaped data (long Russian names, missing images, many lines) before judging.

## 2. Measure Figma, then adapt it

- Read sizes from `.figma_cache/spec/Design_System__<Theme>_/<frame>.json` (`x,y,w,h`, `text.size`, `fill`, `r`), not by eye from PNGs.
- Keep the composition; override only for real constraints, and name each override: text ≥ 11 px (Figma uses 8 px), hit targets ≥ 44 px (visual may be smaller), contrast (white on 75 % orange fails → solid accent), real data (no invented prices, bonuses, art).

## 3. Design for real data

| Real-data case | Required behaviour |
|---|---|
| 60-character product names | 2-line clamp + full name in semantics; never 5-line cards |
| Rows/rails of cards | One computed extent per row; prices and actions on one baseline |
| One item in a rail | Starts at the left, not centred |
| Parent with 24 children | One scrollable chip row or grouped sheet, never a wall |
| Missing/placeholder data (`img: ""`, description `"."`) | Hide the slot, no dead space or stray glyphs |
| 320 px, 2× text, 300 px keyboard | Reflow, primary action reachable |

## 4. Interact, not just screenshot

Exercise every changed control in a real or fixture tab and check the visible result: add → state changes; a second press does something meaningful; notices clear the floating cart; scroll-to lands on the target; disabled states explain why.

## 5. Review like a user

1. Build once (`build --tracked`, plus `build` for fixtures), recapture the same **after** set.
2. `real.contactSheet(browser, files, out, {labels})`; read the sheet, then open every suspect screen at full size.
3. Write concrete defects ("cart rows: name in a 90 px column"), fix the root cause, recapture. Stop only when a pass yields no defect you would accept from a colleague.

## 6. Parallel work

Split by file ownership (card/grid, rows, page body, dock, data policy). Give each worker the measured Figma facts, real-data cases, keys/semantics to keep, and "no Flutter runs". The parent integrates, then runs `check <affected tests>` → `check --full --native` → builds → real-data recapture.

## Report contract

Before/after image per changed screen (both themes) · stores/data used · interactions exercised and results · named Figma overrides with reason · test/analysis/build results · what was not verifiable (sign-in screens, physical phones).

## Common mistakes

| Mistake | Fix |
|---|---|
| Declaring done from fixture captures or pixel diff | Real-store before/after, step 1 and 5 |
| Old UI after rebuild | Cache: helper disables it; reopen tab |
| `Page.captureScreenshot timed out` | Close and reopen the tab |
| Clicking stale handles | `tapWhere` observes fresh each time |
| Copying Figma 8 px text / translucent CTA | Name the override in the report |
| Refactors or motion "while here" | Only what the screen needs |
