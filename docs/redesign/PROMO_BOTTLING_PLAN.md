# Promotions, bottling and the item page — research and plan

Requested: promotions currently have no dedicated item cards and no trustworthy calculation, the
bottling (розлив) flow is not good, and the item configuration page is chaos. This document is the
research, the measured evidence, the general plan, and a self-contained implementation plan for every
step.

Nothing here changes money semantics on its own: M1 and M2 are the calculation and its presentation,
M3–M4 are the surface rebuilds, M5 is verification. Every step names the contracts that must stay
green, the frames that decide geometry, and the risk it carries.

Current cutover: M1 promotion/stock/container invariants remain protected; M2 cards, cart gift
lines and item-scoped active campaign terms are implemented. M3 configurable item composition
uses the existing design primitives; M4 moves the live paid/gift litres, physical mix and
ADD/REPLACE price explanation ahead of the picker, with the actual gift-container allocation
on each affected row. REPLACE prices are labelled as combined tariffs, not free containers.
Fresh three-litre selection/increase stays withdrawn; saved relations, gifts, litres and tariffs
remain reducible/removable, including at zero stock. Other capacities, including 30 L, remain.
M5 client commands/actual journeys are in `STATUS.md`; bank/loyalty/1C production acceptance is
not established. The findings and pending labels below are the original audit, not current code.


---

## 1. What the user reports

| Report | Where it lands today |
|---|---|
| "no promotion special item cards" | No surface in the app renders an `N+M` (SUBTRACT) promotion: cards, rows, the promotion page and the cart carry no promo chip, gift line or progress |
| "no promotion calculation no good" | The gift *count* is right, but only the first SUBTRACT promotion is used, restored rows keep stale promos, the client total is sent to the server without reconciliation, and the progress/next-gift helpers are unwired |
| "no good bottling" | The pour flow is a stack of stepper rows under three lines of policy prose; the resulting mix, gift bottles and tariffs are below the fold and duplicated |
| "item detailed page is just chaos" | `ProductDetailPage` mixes Material defaults (`CheckboxListTile`, `FilledButton`, `TextButton`) with the app's design system and repeats the same numbers in four places |

---

## 2. R&D findings (evidence)

### 2.1 Data and contracts as they exist

Product-level promotion payload (`test/fixtures/public_bottling_catalog.json`, item 1186):

```json
"promotions": [{
  "detail_id": 8692, "type": "SUBTRACT", "base_amount": 2, "add_amount": 1,
  "discount": null, "name": "2+1",
  "promotion": {"marketing_promotion_id": 355, "name": "Выгодный розлив",
                "start_promotion_date": "…", "end_promotion_date": "…"}
}]
```

- `ItemPromotion` (`lib/model/item.dart:455`) maps API `DISCOUNT` → internal `PERCENT` and keeps
  `FIXED`, `SUBTRACT`, dates and `isActive`.
- `CategoryItemPromotion` (`lib/utils/api.dart:3315`) is the older twin with the same fields; both
  parse the same server payload.
- Shelf-level promotions exist and are wired: `GET /promotions/active` → home banners, and
  `GET /promotions/{id}/items` → `PromotionItemsPage` (`lib/utils/api.dart:1915`, `:1974`).
- There is **no** gift-item reference anywhere in the payload. The design's cross-item gift
  ("Лёд весовой" free with 2 Aperol) can therefore only be rendered as a same-item gift until the
  backend exposes a link (see §5 Q1).

### 2.2 What the calculation does today

`lib/utils/subtract_promotion_math.dart` + `lib/model/cart_item.dart:226`:

- Rule in force: **buy `base_amount` paid units → `add_amount` free**. Pinned by tests:
  `3+1` with 3 paid litres → `freeQuantity 1`, `totalOrderQuantity 4`
  (`test/regression/bottling_contract_test.dart:154`), `2+1` with 2 paid litres → 3 physical
  (`:203`), and stepping snaps to multiples of `base_amount`
  (`test/regression/promotion_pricing_test.dart:105`).
- Forward and inverse agree: `subtractPromotionFreeQuantityForConfig` uses `floor(paid / base)`;
  `subtractPromotionPaidQuantityForPhysicalQuantity` uses `floor(physical / (base + add))`, which is
  algebraically its exact inverse — for `physical = paid + add·k` with `k = floor(paid / base)`,
  `floor(physical / (base + add)) = k` — and its validation guard rejects unattainable values such as
  `3` physical for `3+1`. So the gift *count* is not wrong. (Verified by hand for `2+1` at 6/9 and
  `3+1` at 5/6/8/9/11/12; §5 Q4 fixes the intended reading.)
- `calculatePrice` takes the promotion list from the **first** row of the group
  (`promotions ??= item.promotions`) and applies FIXED/PERCENT per paid unit; `subtotalBeforePromotions`
  values the gift at list price, `totalPrice` charges only paid units plus options.

Real gaps the research found:

1. **Only the first SUBTRACT promotion is honoured** (`firstSubtractPromotion`, `:21`). An item
   carrying both `2+1` and `3+1` silently applies whichever the server listed first, which may be the
   worse deal for the customer.
2. **One row's promotion list decides for the whole group** (`cart_item.dart:233`). Rows are stored
   in `cart_items` with the promotions that were live when they were added, so a group assembled
   before a promotion change keeps the old list until the item is touched again from the catalogue;
   a mixed group resolves arbitrarily to its first row.
3. **The client total is authoritative and unverified.** `checkout_page._submitOrder` sends
   `'items': _orderItems()` (physical amounts, gift included) and `'total_amount': _total` computed
   in Dart by `CartItem.calculatePrice`; the server returns a `cost_summary`
   (`lib/utils/order_ui_helpers.dart:91`) that the app never compares against the client total.
   Any promo divergence silently changes what the customer pays.
4. **Gift/tariff rules live in UI prose.** "Тара для подарка добавляется отдельно и оплачивается по
   обычному тарифу" is a paragraph in `product_detail_page._bottles`; nothing computes a per-bottle
   paid/gift split where the customer chooses bottles.
5. **Promo helpers are unwired.** `subtractPromotionProgress`, `subtractPromotionAmountToNextGift`
   and `subtractPromotionBundleTargetQuantity` have no UI caller; only `subtractPromotionBundleLabel`
   is used, in checkout (`checkout_page.dart:1218`). Nothing tells the customer how far they are from
   the gift.
6. **The same rule is implemented twice** (forward and inverse, `:35` and `:59`) plus a second
   selector in `firstSubtractPromotion`; three places must agree for the money to stay consistent.
7. **Promotion validity was never read.** `ItemPromotion.fromJson` looked only at flat
   `start_date`/`end_date`, while the server nests the window under
   `promotion.{start,end}_promotion_date` (see the payload above). Both dates stayed null, `isActive`
   always returned true, and a promotion kept gifting after its end date — in the cart, on restored
   rows and in every price calculation.

**M1 status — implemented.** `lib/utils/promotion_engine.dart` now owns the rule: `PromotionAward`,
`selectSubtractPromotion` (customer-best, deterministic ties), `isPromotionActive` (flat and nested
windows), `evaluatePromotion` (paid/free/physical, `nextGiftIn`, `progress`, `unlocked`, campaign
name), the forward/inverse pair with its validity guard, price application and the bundle helpers.
`subtract_promotion_math.dart` is gone and all seven callers plus two test files import the engine.
`ItemPromotion` parses and re-emits the nested campaign name and window; `CartProvider._addItemInternal`
replaces a row's stored promotions with the catalogue's live ones; `checkoutAmountNotice` in
`checkout_contract.dart` compares the client total with the server's `cost_summary` and
`PaymentMethodPage` shows the warning under the amount (`payment-amount-notice`). Evidence:
`test/regression/promotion_engine_test.dart` (13 cases: selection, ties, expiry, nested window,
round trips 0…12 for `2+1`/`3+1`/`2+2`, unattainable values, progress, two freshness cases),
`test/regression/checkout_contract_test.dart` (3 reconciliation cases), full suite green.

### 2.3 What the design asks for

Re-dumped light page (`dart run tool/figma_spec.dart spec --page "Design System (Light)"`, 105 frames)
and the reference PNGs.

`Корзина - Акционный товар` — the promotion frames:

- Cart row: 343 × 60 `surface` card, radius 10, 52 × 52 thumbnail, name 16/500, category · country
  10/400, price 16/700 in accent, stepper 77 × 33 with a 21 × 21 glass accent `+`.
- **Gift row**: title `Лёд весовой` 16/500, metadata `Лёд` 10/400, price **0 ₸**, and the trigger
  caption `При заказе 2 Aperol и более этот товар в подарок!` 10/400 — a first-class line, not a
  suffix.
- `Вам также может понравиться` strip: 160 × 244 cards carrying a `-10%` chip (brandRed, radius 4,
  46 × 17), a `+100` chip (gold, 45 × 17), the struck `13 170 ₸` and `Выгода 1317 ₸`.
- Totals bar (glass): `Итого:` 12/400, total 24/700, `+1400 бонусов` 14/700 accent with an info dot,
  `Оформить` 179 × 49 glass pill.

`Корзина - Доставка - Акционный товар` — the same gift line inside the order summary, plus a
separate `Пакет 30 ₸` row and a `Бонусы за заказ +1 900 ₸` row: tariffs and bonuses are lines, not
prose.

`Описание товара` (+ 3 scroll states) — the item page geometry the simple product already follows:
hero, `Аперитив · Италия` 12/400, title 24/700, `13 170 ₸` 16/400 struck → `11 853 ₸` 32/700,
`Выгода 1317 ₸` 16/500 gold, `-10%`/`+100` chips at the title's right, `Количество` 16/400 with the
value 20/500, `Описание` 16/700 + body 14/500 with `Читать далее` / `Свернуть`, and the glass action
bar with the total 24/700 and a 175 × 49 accent pill.

**There is no frame for the pour/bottling configurator** — the frames only cover the simple item
page. The configurator therefore has to be designed inside the existing system (same typography,
`AppSurface`/`AppGlassPanel`, 44 px controls, inherited text scaling), which is exactly what M3/M4 do.

### 2.4 What the app shows today (measured)

Captured from the strict fixture at 375 × 812 / DPR 2 (`?surface=product_pour_gift`, light):

- First screen: 320 px empty grey hero with a placeholder icon, `Бархатное Павлодар темное` title,
  `890 ₸` + `Базовая цена · за 1 л` + `Доступно: 77.72 л`, then the `Объём и тара` heading and three
  lines of policy prose — the **bottle picker itself is below the fold**.
- Bottle rows are `AppSurface` shells with `Пластиковая бутылка 1л`, `1 л · тара + 110 ₸` and a bare
  `− 1 +`; the next row is cut off by the always-visible footer.
- The footer repeats the total (`Итого 1000 ₸`) while the header shows `890 ₸ · за 1 л` — two prices
  with no reconciliation, plus `Открыть корзину` underneath.
- Gift information appears twice: as prose under the picker and again inside `Состав цены`.

### 2.5 How production does it

- **Gift lines, not suffixes.** Buy-X-get-Y engines auto-add the gift as its own 0-price cart line and
  remove it when the cart stops qualifying, so the customer sees exactly what they receive
  (BOGOS *Buy X Get Y*, *Free Gift Selection*; WooCommerce BOGO plugins).
- **Progress toward the next reward** is the standard qualification device: "add 1 more to unlock"
  beats a static badge (BOGOS *Progress Bar*; Baymard's grocery add-to-cart research on immediate,
  explicit feedback).
- **Margin-safe rules are explicit**: cross-item promos gift the *cheapest* qualifying unit
  (BOGOS *Discount Features*), which is what a same-item `N+M` reduces to.
- **One engine, server-authoritative totals.** Promotion engines compute the award in one pass with a
  defined precedence and the checkout total is the authoritative figure; clients mirror it for
  display and reconcile at order creation. Our client computes the total that is sent to the server
  and never reconciles the answer — the opposite of that rule.
- **Container tariffs are explicit money.** Container/deposit pricing is modelled as its own
  chargeable component, never folded into the drink price. In this app containers are the
  `optionsTotal` part of a row (`CartItem.optionsTotal`) and the gift's container is charged at its
  ordinary tariff — pinned by `bottling_contract_test.dart:203`/`:424` and stated in the
  configurator's own copy. The FAQ (entry "Как добавить пустую тару…") tells customers the tariff is
  already included in the position's total, so the UI must make that split visible rather than
  leaving it to prose. The design mirrors this with its separate `Пакет 30 ₸` line.

---

## 3. General plan

| Step | Outcome | Depends on | Evidence of done |
|---|---|---|---|
| **M1 Promotion kernel** | One promotion evaluation for the whole app: best-promotion choice, one home for the forward and inverse gift rules, promotion refresh for restored rows, and order reconciliation | — | Regressions for multi-promo choice, forward/inverse round trips, stale-promo refresh, and client/server total reconciliation |
| **M2 Promotion presentation** | Promo chips on cards and rows, a promo card with progress on the item page, gift lines in cart and checkout, a promotion page that explains itself | M1 | Fixture surfaces + integration tests for chip/gift-line/progress states |
| **M3 Item page shell** | One item-page skeleton (hero → title → price → quantity → promo → price composition → description → glass footer) shared by simple and configurable products, in design-system components only | — | Redesigned `ProductPage`/`ProductDetailPage` in the fixture, both themes and 1×/1.6×/2× text |
| **M4 Bottling** | Container-first pour picker: bottles with tariffs and images, live mix/gift summary next to the picker, stock with sane precision, separate paid/gift bottle lines | M3 | Pour fixtures covering 1+1, 2+1, 3+1, mixed bottles, fractional litres, stock limits |
| **M5 Verification** | States, accessibility, theme/scale coverage, e2e journey, docs and rollout notes | M1–M4 | `flutter test --concurrency=1`, `dart analyze`, native e2e, capture/diff review, status doc |

Sequencing notes:

- M1 first: M2's gift lines and progress read the same numbers, and the reconciliation decision changes
  what checkout displays.
- M3 before M4: the pour controls are a section of the shared shell, not a second page.
- M2 and M3 can run in parallel on disjoint files (`lib/ui/product_card.dart`, `lib/ui/product_row.dart`,
  `lib/features/cart/ui/cart_page.dart`, `lib/pages/promotion_items_page.dart` vs
  `lib/pages/product_detail_page.dart`, `lib/features/product/ui/product_page.dart`).
- Invariants that must not change: physical stock still reserves paid **and** gift bottles
  (`bottling_contract_test.dart:344`), gift containers are charged their ordinary tariff
  (`:203`, `:424`), replacement variants stay outside base discounts (`:424`), the order payload keeps
  physical amounts plus options, and the cart keeps its floating control and clearance.

---

## 4. Per-step implementation plans

### 4.1 M1 — one promotion kernel

**Goal.** A single promotion evaluator that every surface and the checkout agree on, with the gift
rule stated once, the best promotion chosen deterministically, and the client total reconciled
against the server's `cost_summary` before payment.

**Data contract.** No payload change. `ItemPromotion`/`CartItem.promotions` stay the input. The
evaluator returns, per display group: `paidQuantity`, `freeQuantity`, `paidTotal`, `listTotal`,
`optionsTotal`, `total`, `nextGiftIn`, `progress`, `promotionLabel` (`2+1`), `promotionName`
(`Выгодный розлив`).

**Steps.**

1. Add `lib/utils/promotion_engine.dart` with one `PromotionEvaluation evaluate(...)`:
   - filter `isActive` (flat or nested window), drop malformed entries. **Selection applies to the
     `SUBTRACT` award only** — price promotions all apply, in phase order: every `FIXED` discount per
     unit first, then `DISCOUNT`/`PERCENT` on the remainder. Picking a single discount would silently
     drop stacked promotions;
   - **one home for the gift rule**: the forward `free = floor(paid / base) * add` kept exactly as
     pinned, plus its single inverse `paidForPhysical(physical)` that walks the candidate awards in
     order (so a basket one award cannot explain exactly is still restored) with the validity guard,
     so cart, preview, repeat order and checkout all call the same pair;
   - choose the **customer-best** SUBTRACT when several exist (most free units for the current
     quantity, ties by larger `add_amount`, then smaller `base_amount`, then `detail_id`);
   - expose `nextGiftIn`/`progress` from the same evaluation so the UI never re-derives them.
2. Point `CartItem.calculatePrice`, `CartDisplayGroup`, `RepeatOrderService`,
   `checkout._orderItems/_total` and `product_detail_page` at the engine; delete the duplicated
   helpers once every caller is migrated (`subtract_promotion_math.dart` keeps only thin
   re-exports for callers still outside the engine, or is removed).
3. Promotion freshness: refresh a group's promotion list from the live `Item` **only on
   catalogue-sourced merges** (`CartProvider.addItem`), never on the repeat-order path
   (`addDisplayGroupItems`), whose rows carry historical promotions and would otherwise resurrect an
   expired gift or drop a discount. Untouched restored rows keep their stored promotions until then.
4. Reconciliation: after `createUserOrder`, compare the server's own figure — `cost_summary` /
   `payable_amount` / `final_amount` (`resolveServerChargedAmount`), never the `total_amount` the
   client itself sent — with the client evaluation; on a mismatch above 1 ₸ show an explicit warning
   on the payment screen ("Сумма заказа отличается от расчёта: <server> вместо <client>") and never
   silently charge the server figure without surfacing it. Reuse `order_ui_helpers` readers.
5. Persist nothing new; keep `cart_items` JSON shape (gift fields as today).

**Tests.**

- Extend `test/regression/bottling_contract_test.dart`: `3+1` at 3/4/6/9 paid litres, `2+1` at
  2/3/4/6, `add_amount > 1` (`2+2`), weight items (`кг`, fractional 0.25 steps), zero and
  below-threshold quantities.
- New `test/regression/promotion_engine_test.dart`: forward/inverse round trip
  (`paidForPhysical(paid + free(paid)) == paid`) and rejection of unattainable physical values,
  best-promotion choice with `2+1` and `3+1` on one item, inactive/expired promos, malformed
  payloads, and promotion refresh when the catalogue touches a stale row.
- `test/regression/checkout_contract_test.dart`: reconciliation warns on a divergent
  `cost_summary` and stays silent on an equal or ±1 ₸ one.
- Keep `promotion_pricing_test.dart` snapping expectations; re-run
  `flutter test test/regression --concurrency=1` and the integration cart/checkout files.

**Acceptance.** One module resolves promotions for cart, preview, repeat order and checkout; the
`3+1`/`2+1` gift counts are unchanged from the pinned tests; a divergent server total is visible to
the user and covered by a test.

**Risks.** Choosing the best promotion instead of the first changes money only for items with
several active SUBTRACT promos; the change must be reviewed against a real order's `cost_summary` in
the fixture before release. The reconciliation must never block an order on a rounding difference —
the ±1 ₸ tolerance and the "surface, do not auto-correct" rule keep it honest.

**Out of scope.** Server-side promotion changes; promo codes and certificates (already separate).

### 4.2 M2 — promotion presentation

**Goal.** Promotions become visible and explainable: chips on cards and rows, a promo card with
progress on the item page, gift lines in the cart and the order summary, and a promotion page that
states its terms.

**Design spec (measured).**

- Card chip for `N+M`: the shared `AppPromoChip` recipe (radius 4, 12 px label with a 12 px glyph). A card shows **at most two chips, taking the first two of** `[-10% discount, 2+1 gift, +100 bonus]`: a discounted card keeps the frames' `-10%` + `+100` pair, an item with both a discount and a gift shows the two promotions and drops the bonus, and an item with a gift and no discount shows `2+1` + `+100`. The gift chip uses accent rather than brandRed so a gift cannot be mistaken for a price discount.
- Item page promo card (in-system, no frame exists): `AppSurface` with the campaign name 16/700 in
  gold (`promotion.name`, e.g. `Выгодный розлив`; the detail's own name is the chip label), the `2+1`
  chip, the rule line `За каждые 2 л — 1 л в подарок` 16/400, a `LinearProgressIndicator` in accent
  and the state line `Добавьте ещё 2 л, чтобы получить подарок` / `Подарок в корзине: 1 л`. Keys:
  `product-promotion`, `product-promotion-progress`, `product-promotion-state`. Placement: below the
  quantity control, above the description.
- Cart gift line (inside the group card): the free units as their own `surfaceMuted` line — label
  `Подарок · 1 л` 14/500 with a bonus-star glyph, the frame's rule caption
  `При заказе 2 л и более этот товар в подарок` 12/400 in secondary, and `0 ₸` 14/700 in accent; no
  stepper, because the quantity follows the paid units. Keys: `cart-gift-<group key>`,
  `cart-gift-label`, `cart-gift-price`. The frame names the gift product because its gift is a
  different article; for a same-item gift the row is the item, so the caption uses the frame's
  "этот товар" wording instead of repeating a long catalogue name. Groups without gifts keep today's
  single row.
- Checkout order summary: gift line with `0 ₸`, plus `Бонусы за заказ` and the package line already
  produced by the quote (design lists both).
- Promotion page (`PromotionItemsPage`): keep the `AppTopBar`; add a promo header block (promotion
  name, terms from the item payload — `2+1` / `-10%` — and `Выгода` when discount promos apply),
  keep the existing grid and heart overlay.

**M2 status — slices 1–3 implemented, 4–5 pending.** `ProductView.promo` projects the engine's label
and `ProductCard` shows it through the new shared `AppPromoChip` (which also replaced the card's
private badge helper); `ProductPage` renders the promo card with progress and the next-gift line;
`CartPage._GiftLine` renders the free units as a `0 ₸` line with the rule caption. Evidence:
`test/integration/promotion_presentation_test.dart` (9 cases: card chip states incl. expiry, item
page progress and unlocked state, ordinary products unaffected, cart gift line and its absence), plus
the card consumers (`catalog_flow`, `home_flow`) and cart suites green. Pending: the checkout summary
gift line, the promotion-page header block, and a fixture review of the chip and gift line (the
gallery's sample items carry no promotion today).

**Steps.**

1. `ProductView` (`lib/core/product_view.dart`): project `promoLabel` (`2+1`) and `promoActive` from
   the engine; keep `discount`/`saving`/`bonus` semantics and add the engine-derived gift fields the
   cards need. Update `ProductCard`/`ProductRow` chip row and their golden-free geometry tests.
2. `ProductPage`: add the promo card + progress above `_QuantityControl`. Stepping stays free, as
   Q6 says: the promotion is communicated through the chip, the progress bar and the
   `Добавьте ещё N` line, never by snapping a tap to a bundle threshold.
3. `CartPage`: render the gift line inside `_CartRow`, the chip in the header, and reuse
   `subtractPromotionBundleLabel` for the paid+gift label; keep stepper semantics
   (last-unit delete, batch repeats) untouched.
4. `checkout_page`: gift/savings lines in the order summary; keep the existing payload contract
   (physical amounts + options) and the M1 reconciliation.
5. `PromotionItemsPage`: promo header block; no change to loading/pagination/error handling.

**Tests.**

- `test/integration/product_detail_bottling_test.dart` and a new
  `test/integration/promotion_presentation_test.dart`: chip appears for `2+1`, progress text flips at
  the threshold, gift line appears with `0 ₸` and disappears when the quantity drops below the
  threshold, no chip for expired promos.
- `test/regression/promotion_pricing_test.dart`: label/progress/next-gift values for `2+1`, `3+1`,
  `2+2`, weight items.
- Keep `cart_interactions_test.dart` green (stepper semantics).

**Acceptance.** A customer can answer "why is this free?" and "what do I need to add?" from the card,
the item page and the cart without reading a paragraph.

**Risks.** Card space at 1.6×/2× text (chips must wrap, never clip); gift lines must not be counted as
paid rows anywhere (steppers, item counts, order payload).

**Out of scope.** Cross-item gift products until Q1 resolves; animated promo banners.

### 4.3 M3 — item page shell

**Goal.** One item-page skeleton used by both the simple product and the configurator, with the
design's hierarchy and only design-system components, so the page stops being a flat pile.

**Design spec.**

- Order: hero (0.85 × width, cap 320; `surface` fill, real image, honest placeholder) → metadata
  12/400 → title 24/700 (existing `presentItemName`) → price block (struck 16/400, current 32/700,
  `Выгода` 16/500 gold, unit caption 14/400) → **primary control** (quantity or bottle picker) →
  promotions → composition → description → glass footer.
- Two-column price/quantity header on ≥ 343 px, stacked under it (the existing `adaptive` rule in the
  footer becomes the page's rule).
- Radius/typography per tokens; no `CheckboxListTile`, `FilledButton`, `TextButton`, `IconButton`
  leftovers where the system has an equivalent (`AppSurface`, `AppGlassPanel`, `AppGlassChip`,
  `AppIconButton`, `_ConfigurationStepper` promoted to a shared `AppStepper`).
- Prose that explains money moves into the composition block as lines (see M1's per-bottle split).
- Description: `Описание` 16/700, body 14/400, `Читать далее`/`Свернуть` as a text button styled by
  the system; keep the 6-line clamp.
- Footer: `Итого` 16/400 + total 24/700 + struck subtotal when discounted + the design's 175 × 49
  accent pill (`AppGlassPanel`), plus the secondary `Открыть корзину` action; sticky, never covering
  the primary control (the current footer hides the second bottle row at 375 × 812).

**Steps.**

1. Extract the shared skeleton into `lib/features/product/ui/item_page_scaffold.dart` (hero, header,
   price block, section headings, promotion slot, composition slot, description, footer) with slots
   the two pages fill.
2. Move `_ConfigurationStepper` → `lib/ui/app_stepper.dart` (stepper + `AppSurface` recipes, 44 px
   controls) and use it in `ProductPage`, `ProductDetailPage`, `CartPage` rows and the bottle picker.
3. Rebuild `ProductPage` on the scaffold (keeps its design-faithful geometry and its test anchors:
   `find.bySemanticsLabel('Увеличить количество')`, the `В корзину`/`Добавлено в корзину` action-bar
   text and the `Назад` tooltip used by the integration tests and the native e2e).
4. Rebuild `ProductDetailPage`'s frame on the same scaffold: same hero/title/price/description/footer,
   configuration section from M4. The `configuration-*` keys are this page's contract with
   `test/integration/product_detail_bottling_test.dart` and the catalogue flows — keep every one
   (`configuration-quantity`, `configuration-quantity-plus`, `configuration-save`,
   `configuration-back`, `configuration-like`, `configuration-bottle-*`, `configuration-option-*`,
   `configuration-feedback`, `configuration-price-breakdown`, `configuration-volume`,
   `configuration-physical-bottles`, `configuration-cart`, `configuration-description-toggle`,
   `configuration-stock`). Two lookups there read `FilledButton` *by type* (`:217`, `:233`); when the
   footer moves to the design-system button those two lookups migrate to the new type — the keys and
   the enabled/disabled assertions stay.
5. Delete the duplicated typography/pricing blocks (`_unitPrice`, `_priceBreakdown` merge with M1's
   evaluation) and the ad-hoc `AppSurface` shells.

**Tests.**

- `test/integration/product_detail_bottling_test.dart` (keys and flows unchanged),
  `test/integration/checkout_page_test.dart`, native `integration_test/shopping_e2e_test.dart`
  must pass unchanged; add a shell test asserting section order and the footer not overlapping the
  last control at 375 × 812 with 2× text.
- Fixture surfaces `product_options`, `product_replacement`, `product_pour_real` reviewed at 1×/1.6×/2×,
  both themes.

**Acceptance.** Every number on the page appears once, the primary control is visible on the first
screen at 375 × 812, and no Material default widget styles are visible.

**Risks.** The configurator carries the cart contract; the rebuild must keep variant maps, gift
retention and stock checks byte-identical (all covered by existing regression files).

**Out of scope.** New imagery or a redesign of the simple product's hero content.

### 4.4 M4 — bottling (pour) experience

**Goal.** Choosing bottles becomes the primary, obvious interaction: pick containers, see litres and
money update next to the picker, understand which bottles are gifts and what their tariffs cost.

**Fixed input (do not re-open).** `PLAN.md` G4 records the user-confirmed policy: **all physical
bottles are charged normally, including the gift litres' containers**. M4 changes how that policy is
shown and operated, never what it charges; `bottling_contract_test.dart:203`/`:424` stay green
untouched.

**Implemented ahead of M4 (user request).** Three-litre bottles were withdrawn from the range:

- `SmartCartSelection.filteredBottles` drops exactly three-litre containers (every other capacity the
  store sends, including larger kegs, stays), so the picker never offers one and no new selection or
  gift allocation can use one.
- `SmartCartSelection.knownBottleRelationIds` keeps every container the store identifies, so a cart
  that already holds a three-litre bottle keeps its litres, its tariff, its gift allocation and its
  order rows; `litersForCounts` replaces the `filteredBottles`-only arithmetic in
  `CartProvider._syncPourFlowBottleCounts`, `giftBottleBreakdown` and `withGiftContainers`.
- The configurator lists such a row as `… · больше не продаётся` with the add button disabled and the
  remove button live, so a legacy row can be reviewed and removed instead of stranded.
- `isBottleVariant` and `_bottleVolumeForCartItem` resolve against every known container.
- Tests: the synthetic pour fixture now offers 1 l + 1.5 l (mixed-container coverage without a 3 l
  bottle); new regressions assert the three-litre container is not offered, that a cart holding one
  keeps its litres and tariff, and that re-saving that configuration still works. The captured
  catalogue keeps its real three-litre payload, which is what proves the legacy path.

**Design spec (in-system).**

- `Объём и тара` heading 20/700 with a one-line summary `2 л · 2 бутылки` 14/400 — no policy prose.
- Bottle rows: `AppSurface`, radius 12, 44 px stepper, bottle name 16/500, `1 л` chip, tariff line
  `тара + 110 ₸` 14/400, and the *paid/gift split* for the row when a gift applies
  (`1 оплачена · 1 в подарок` 12/400 gold).
- Live summary card directly under the picker: total drink litres (20/700), paid vs gift litres
  (14/400), bottle count, and the resulting money split `Напиток X ₸ · Тара Y ₸` — this replaces the
  prose and the separate `Состав цены` duplication (composition keeps only the final lines).
- Stock line: one decimal at most (`Доступно: 77,7 л`), formatted by `core/quantity.dart`, never raw
  floats; the availability check keeps using the exact value.
- Gift state: when the promo threshold is met, the summary shows `+1 л в подарок` with the tariff note
  `тара подарка оплачивается отдельно — Y ₸` computed per bottle, not written as prose.
- Empty stock, allocation failure and "no bottles selected" keep the existing error strings and the
  `configuration-feedback` key.

**Steps.**

1. Build the bottle picker on the M3 shell: rows with add/remove, a per-row paid/gift allocation from
   the engine, and the live summary card.
2. Keep `SmartCartSelection` as the source of bottle identity/volume; add only a presentation-level
   `BottleAllocation` view (paid count, gift count, tariff) computed from the engine + retained gifts.
3. Replace the policy prose and the duplicated breakdown with the summary lines; keep the
   `configuration-physical-bottles` and `configuration-volume` keys (tests and the native e2e assert
   them).
4. Quantity stepping for non-pour products continues to use `AppStepper`; pour products never show a
   litre stepper — the bottles are the quantity.

**Tests.**

- Extend `test/integration/product_detail_bottling_test.dart` with the summary card's numbers for
  `1+1`, `2+1`, `3+1`, mixed 1 L/2 L/3 L, and fractional replacement bottles; a regression for the
  paid/gift per-row split; a stock-limit test where the last bottle is refused.
- Keep every existing bottling regression green (mix identity, gift retention, tariffs, stock).
- Fixture surfaces `product_pour`, `product_pour_gift`, `product_pour_three_plus_one`,
  `product_pour_fractional`, `product_pour_real` reviewed at 375 × 812, 1×/1.6×/2×, both themes.

**Acceptance.** On the first screen at 375 × 812 the customer sees the picker and the live mix/money
summary without scrolling; no policy prose remains; the paid/gift split is visible per row and in the
summary.

**Risks.** Gift allocation is the most contract-heavy code in the app; the picker must not change
which bottles are retained (pinned by `bottling_contract_test.dart`), and stock must keep reserving
gift containers.

**Out of scope.** Bottle artwork (no assets exist); per-bottle barcode scanning.

### 4.5 M5 — states, accessibility, verification and rollout

**Goal.** The rebuilt surfaces hold up in every state and are proven the way this repo demands.

**Steps.**

1. States: loading/empty/error for the promotion page and promo card; out-of-stock, allocation-failed,
   below-threshold and above-stock states for the pour picker and the item page; each keeps its
   existing key or gets a documented one.
2. Accessibility: `Semantics` labels for the promo chip (`Акция 2+1`), the progress state
   (`Добавьте ещё 1 шт`), the gift line (`Подарок, 0 тенге`), and the bottle rows (name + litres +
   tariff); 44 px targets; verify with the fixture's semantics tree.
3. Theme and scale: dark/light and 1×/1.6×/2× text over all touched surfaces; no clipped chip, no
   footer overlap, no truncated price.
4. Verification: `flutter test --concurrency=1`, `dart analyze lib test integration_test tool`,
   native `flutter test integration_test/shopping_e2e_test.dart -d windows`, fixture capture/diff via
   `dart run tool/verify_surface.dart all --theme both`, and a read-only tracked-release smoke at
   375 × 812 / DPR 2 (no production mutations).
5. Docs: update `docs/redesign/STATUS.md` (what changed, measured geometry, limits) and
   `docs/redesign/FIDELITY.md` (which surfaces are stale), and note the backend questions from §5 in
   `PLAN.md`.

**Acceptance.** All checks green, evidence recorded with real numbers, and the remaining
authenticated-production limits stated explicitly.

---

## 5. Open questions and the defaults I would proceed on

| # | Question | Default I will use | Why |
|---|---|---|---|
| Q1 | Should cross-item gifts (design's "Лёд весовой") be supported? | Ship same-item gift lines now; ask the backend for `promotion.gift_item_id` / a promotion-items link and add cross-item gifts in a follow-up | The payload has no gift reference; inventing one would fabricate an API contract |
| Q2 | Which promotion wins when several SUBTRACT promos are active? | The one that gives the customer the most free units for the current quantity, ties broken by larger `add_amount` | Margin-safe and explainable; also matches the cross-item "cheapest free" convention |
| Q3 | Who computes the charged amount? | The client keeps sending its total (current contract) but must reconcile against the server's `cost_summary` and surface any divergence before payment | The server is authoritative in production; silent divergence is the worst outcome |
| Q4 | Is `2+1` "buy 2 paid, get 1 free" or "3 units, 1 cheapest free"? | Buy 2 paid → 1 free (the pinned semantics and the design's own caption "При заказе 2 … в подарок") | Matches tests, FAQ and the design caption |
| Q5 | Where does the pour configurator live in the design? | No frame exists: build it from the design system on the shared item shell | Inventing a Figma-parity claim would be false; the shell is what M3 defines |
| Q6 | Should stepping snap to gift thresholds? | Show the threshold and the "add N more" hint; stepping stays free (users may buy non-bundle quantities) | Snapping was already rejected as surprising by the existing pinned tests |
