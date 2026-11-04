# Client flow overhaul — design and plan (2026-11-04)

The owner rejected the current gift messaging, cart deletion, routing, checkout benefits,
notification onboarding and the catalog header as confusing. This document fixes each by
what the customer sees and does, not by tokens.

## Principles

1. **The price is the message.** A promotion is shown by the struck-through price and the real
   price. No «в подарок» chips, captions or boxes repeating it.
2. **One sentence per screen, only where a decision is made.** The rule («Возьмите 4 — платите
   за 3») appears once, on the product/configurator page. At the exact threshold one actionable
   nudge appears, worded by its *real* cost (a bottled litre still pays its bottle).
3. **Predictable navigation.** Back always goes to the screen you came from, except after an
   order exists: then you land on that order, and back from it goes home.
4. **Primary first.** Bonuses are the checkout benefit; promo code and certificate fold into one row.
5. **Defaults like every app.** Notifications are on; the OS is asked for permission once, at
   the end of a one-screen onboarding.

## 1. Promotions and gifts

Facts (code-verified): the 4th litre of a bottled 3+1 at 1 000 ₸/л with a 100 ₸ bottle costs
**+100 ₸** (bottle charged on gift litres); a packaged 4th unit costs 0 ₸.

| Surface | Before | After |
|---|---|---|
| Configurator dock (bottled) | «3 л · 3 бутылки» + outlined «+1 л в подарок»; at 4 l a «1 л в подарок» pill + «До следующего подарка: 4 л»; at 7 l pill and button together | «4 л · 4 бутылки» and the price (struck-through when a gift exists). At the threshold only: one line «Ещё 1 л — только бутылка, 100 ₸» + «Добавить». No hints at other quantities. |
| Configurator page | no rule anywhere | one compact line under the price: «Акция 3+1 · 4-й литр бесплатно, бутылка оплачивается» |
| Product page (packaged) | card: name, chip, rule, progress bar, state line, outlined button | card: name + «3+1» chip + rule. Threshold: «Ещё 1 шт — бесплатно» + «Добавить». With a gift: «Выгода 1 000 ₸». No progress bar, no «До подарка». |
| Cart row | pour: «1 л в подарок» pill; packaged: red box «Подарок · 1 шт / rule / 0 ₸»; at 3: «+1 л в подарок» button | struck-through + real price only. Threshold nudge line identical to the configurator's, priced by the real increment. |
| Checkout row | struck-through price + «1 л в подарок · 0 ₸» line | struck-through price only. |

Increment cost is computed, not assumed: `CartGroupEvaluation.nextStepCost` = total after one
more step − total now (pour: the next batch of bottles; packaged: one step). The nudge shows
only when `bonusQuantity == incrementStep` and the step can be added; the copy is «бесплатно»
when the cost is 0, else «только бутылка, N ₸» (pour) / «за N ₸».

Edge cases: 7 l (gift 1 and the next gift reachable) shows the struck price and the nudge; a
3+1 with only 1.5 l bottles never offers an exact free litre → no nudge; stock exhausted or
unresolved store → no nudge; several promotions → best one; reduced motion respected.

## 2. Cart: details and deletion

- **Tap a cart row** (image + name) → the product: options/bottled items open the configurator
  with the row's exact configuration; plain items open the product page; its cart button returns
  to this cart. Rows without a snapshot (legacy) stay inert.
- **Outside the cart** (cards, product page, checkout stepper) decrementing the last unit removes
  the item completely; no zero rows linger. The minus becomes a trash icon at the last unit.
- **Inside the cart** the last-unit trash keeps the row in place as «Удалено · Вернуть» (undo with
  the exact bottle mix); the total ignores it; leaving the cart purges it.

## 3. Navigation

- One cart: opening the cart when a cart route is already in the stack pops back to it.
- Checkout back → the cart it came from.
- Order created → payment. Back from that payment → the order (Home underneath), so the unpaid
  order and its «Оплатить» are in front of the customer, never an empty cart. Back from payment
  opened from an order → that order.
- System back is blocked while a payment is running.
- Success: «Отслеживать заказ» → order (Home underneath); system back → Home.
- Cancel order: there is no cancel API; not invented. The FAQ promise is reported to the owner.

## 4. Checkout benefits

- One bonus card: «Списать бонусы» switch with the amount (−X ₸) and «Доступно X» line; logged
  out → «Войдите, чтобы списать бонусы».
- One folded row «Промокод или сертификат». Expanded: a two-way switch (Промокод | Сертификат),
  one field, «Применить». Applied: the row reads «Промокод SUMMER · −500 ₸» with «Убрать».
- A code may be applied while bonuses are on; success turns bonuses off (one hint line says so).
- Keys used by tests are kept.

## 5. Notifications and onboarding

- Topics default **on**; whenever the device gets permission, enabled topics are tagged.
- Onboarding: one screen — city (with «Определить город»), one primary «Продолжить». After it,
  the OS notification prompt is requested once. Telemetry and location permission leave
  onboarding (telemetry stays opt-in in Settings; the address is chosen at checkout).

## 6. Catalog header

- The category switcher row sits on the page colour (solid) inside the header; the fade starts
  below it, so products never pass behind the words.
- Unselected tabs are chips with a surface fill, like the selected one, so they read as buttons.

## Order of work

1 → 2 → 3 → 4 → 5 → 6, each: implement, focused tests, look at it in both themes with the edge
states, then the next. Finish with the full native gate, release build, live walk, push.
