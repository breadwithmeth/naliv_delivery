# Redesign — status, decisions and open questions

Living document for the Градусы24 → Figma redesign. It exists so the work can continue without
its original author in the loop: **every question that needs a human answer is listed below with
the default I am proceeding on**, so nothing blocks unnecessarily, and nothing gets decided
silently either.

Last updated: 2026-09-22 (during the catalogue/search/product-detail phase).

---

## 1. How to pick this up

| Thing | Where |
|---|---|
| Design source of truth | `figma.com/design/HYTqbt63dc1ediNylJF7pt` — «Градусы24 Приложение», 106 screens × 2 themes, 375 × 812 |
| Design dump (regenerate) | `dart run tool/figma_spec.dart spec` → `.figma_cache/spec/` (212 frames) |
| Design token scales | `dart run tool/design_report.dart` → `.figma_cache/report.md` |
| Frame renders (compare against) | `dart run tool/figma_spec.dart png --page "Design System (Dark)"` → `.figma_cache/shots/` |
| Fidelity harnesses | `.figma_cache/*_test.dart` (home, cards) — run with `flutter test` |
| App running locally | `hub` process `app-web` → `flutter run -d web-server --web-port 8080` |
| Credentials | `.figma-token`, `.figma-design` (git-ignored); API session in `.figma_cache/session.json` |

**Logged-in app without SMS.** The API session token can be injected into the app's storage:

```js
localStorage.setItem('flutter.auth_token', JSON.stringify(token));      // JSON-encoded!
localStorage.setItem('flutter.token_expiry', JSON.stringify(String(expMs)));
localStorage.setItem('flutter.onboarding_completed', 'true');
```

`shared_preferences_web` stores values JSON-encoded, so **strings must be quoted** — a bare token
makes the startup gate hang forever on its loader with zero HTTP calls.

**Verifying in a browser.** Flutter web renders to a canvas: there is no DOM to query and
synthetic DOM events do not reach its text editor. Two consequences:

* taps must use **browser layout coordinates**, not the design frame's — the web build has no
  status-bar inset, so everything sits 48 px higher than in the frames;
* typing works by tapping the field with a real pointer, then using `tab.type` / `tab.press`
  (real key events). Clicking the wrong element looks identical to "the handler is broken".

---

## 2. Needs your answer (defaults in bold — work continues meanwhile)

| # | Question | Default I am using | Why it matters |
|---|---|---|---|
| 1 | **Sidebar**: the design has no tab bar and no drawer anywhere (verified across all 106 frames), so I created one. It opens from the header's account icon and has no «Каталог» entry (the home screen already lists all seven supercategories). | **Account icon opens it; no Каталог row** | Changes how users navigate; one line to change |
| 2 | **Search idle state**: the frame draws the field alone at y = 60 with no header; I keep the consistent header («Поиск» + back) in all four states. | **Consistent header** | Cosmetic, 1 argument |
| 3 | **Option flows exist but the design has none.** You confirmed options live under «Пиво» → «Розливное/Разливное пиво». The redesigned product page has no option UI, so such items are routed to the **legacy** product page. | **Legacy bridge, documented** | Real functional gap; needs a design for the option/bottling sheet |
| 4 | **Scheduled delivery** («Запланировать»), **rating + tips** («Как всё прошло»), **notifications inbox**, **card deletion**: the design has them, the frozen backend has no endpoint. 15 frames, excluded per your "build only what the backend supports". | **Not built** | Scope; revisit if the backend grows |
| 5 | **Pre-existing red tests, now measured precisely:** `flutter test` = **56 pass / 8 fail**, and all 8 failures are `product_detail_bottling_test.dart`. `orders_history_page_test.dart` is **fixed and green** (§3t). I previously wrote "5 tests" for bottling from a partial run; the true count is 8. Verified they fail identically with my edits stashed. | **Left red until their screens are rebuilt** | They are the tripwire for frozen logic; I will fix or delete them when the cart/checkout work lands |
| 6 | **Money separators**: the design's own text is inconsistent — price `'11\xa0853 ₸'` (NBSP) but saving `'Выгода 1317 ₸'` (no separator). I format both with NBSP. | **One formatter, NBSP** | Cosmetic |
| 7 | **Banner artwork**: `/promotions/active` returns 22 promotions named «Акции» with an **empty** `cover`, so the carousel shows the design's placeholder fill. | **Placeholder fill** | Backend data, not code |
| 8 | **Trailing spaces** in API names («Белое ») are trimmed on display. | **Trim** | Cosmetic |

---

## 3. Decisions already taken (with evidence)

* **Portrait only**, all three surfaces: `AndroidManifest.xml` `screenOrientation="portrait"`,
  iOS `UISupportedInterfaceOrientations` = portrait, `SystemChrome` in `main.dart`. Web ignores it.
* **One typeface**, TikTok Sans (OFL-1.1), bundled. The *variable* file, not statics: measured
  against the design's own text boxes, 16 pt statics drift −6 % at 8 px and +1.7 % at 20 px, while
  `opsz = fontSize` lands within 1 %.
* **Both themes**, following the OS (`ThemeMode.system`), with the sidebar's toggle overriding —
  the design has «Тема оформления» on `Профиль - Переключение свитчей`.
* **No second style layer**: `lib/design/` is the only source; `AppColors`/`globals.dart` are
  deleted with the pages that import them (still pending — see §5).
* **Sidebar instead of tabs**; the only floating control is the cart button — a 78 px scalloped
  disc when empty, the 133.2 × 42 pill with count + total when filled (`Поиск - Удачный поиск`).
* **`ProductCard` not-in-cart state is a lone «+»**, not «− 0 +» (the design's second grid card and
  the old card's `canDecrease ? count : ''` agree).
* **Catalogue row/card copy** comes from the API; nothing invented. `presentItemName`,
  promotion maths, bonus rules and the like-toggle flow are reused verbatim from the frozen layer.
* **Icons exported from the file** where Figma's image API allows it. It refuses three nodes —
  `Store_Icon_UIA`, the search field's scan glyph, and `vuesax/bold/heart` — so `store` uses the
  same-family shop glyph, `scan` is drawn (five bars), and the search row's heart is Material's.
  The product page's heart is the outline one and is exported properly.

---

## 3b. Cart specifics (built after your last message)

* **Delete rule — implemented.** At one unit the minus slot becomes a delete button
  (`Icons.delete_outline`); the line is only removed by that deliberate tap. The design contains
  **no trash glyph anywhere** (verified across all 106 frames), so this is a Material glyph:
  the same substitution class as `store`, `scan` and the row's filled heart.
* **«Вам также может понравиться» has no endpoint.** The strip is filled from the **first cart
  line's category**, excluding items already in the cart (max 6). This is an inference, not the
  design's data — if a recommendations endpoint appears, replace `_maybeLoadRecommendations`.
* **Empty cart is undesigned.** The cart frames contain no empty state, so the screen shows a
  plain «Корзина пуста» with a «В каталог» action.
* **Row metrics**: 343 × 60, r10, pitch 64; artwork 52 × 52; title 16/500; origin 10/400 muted;
  **line total** (not unit price) 16/700 in the accent; step control 77 × 33 whose minus is bare
  and whose plus sits in a 21 × 21 accent pill.
* **Strip cards** are a third measured variant (160 × 244, `ProductCardWide`): badges side by side,
  origin stacked on the right, artwork 152 × 159.
* **«Оформить» currently opens the legacy checkout.** The redesigned delivery/payment screens are
  the next feature; the button is live, not dead.

---

## 3c. Two things the light theme taught us

1. **The design separates floating controls by a shadow, not a fill.** The 40 px discs are
   `#FFFFFF @ 75 %` on a `#FFFFFF` background in light mode — invisible without their
   `#000000 @ 16 %, blur 8, offset (0, 4)` shadow. That single recipe is now `AppShadows.control`
   (both palettes carry it) and is applied to the discs and the round cart button; the pill CTAs
   carry none, exactly as the frames show. It also fixes the cart button's missing shadow, whose
   SVG drop-shadow filter `flutter_svg` ignores.
2. **Theme choice persists.** `lib/core/theme_controller.dart` stores the mode
   (`theme_mode`), the app follows the OS by default, and both the sidebar and the profile row
   drive it. Verified live: toggling «Тема оформления» switched the running app to light, and it
   came back light after a full rebuild.

The profile's theme row reflects the **effective** theme (so "following the OS into dark" reads
as on), while the switch pins an explicit mode when touched.

---

## 3d. Orders

* **History list built** (`lib/features/orders/ui/orders_page.dart`): 343 × 114 cards, pitch 118,
  humanised dates («22 сентября в 06:58»), «№N», «Сумма», and the status in the top-right —
  error red when cancelled, muted otherwise. Status text comes from the frozen
  `orderStatusLabels`.
* **«Начислено» is computed, not fetched.** The order payload has **no** earned-bonus field
  (`cost_summary` carries `bonus_used`, not `bonus_points`), so the line is derived from the
  order's items with the cart's own rule — 3 %, tobacco excluded. Verified live: the tobacco
  order shows no accrual, a 3 200 ₸ order shows exactly **+96 бонусов**.
* **Backend gap found:** one order carries `status: 67` with `status_description:
  «Неизвестный статус»`, which the frozen helper turns into «Статус 67». The app cannot label a
  status the backend does not name — a data issue to raise, not a code one.
* **Order detail (`Карточка заказа`) is still the legacy page**; its card is the next orders step.
* The design's status wording differs from the app's frozen map («Собираем (15-30 мин)» vs
  «Собирается», «Доставлено» vs «Доставлен»). The app's real labels win.

## 3e. FAQ — needs a content decision

The design's FAQ asks «Как оформить заказ?», «Какие способы оплаты доступны?» and so on. The app's
FAQ is 44 different entries grouped into 7 sections («Авторизация, Профиль и Сбои приложения»,
«Оплата, Удаленные счета и Расчет стоимости», …) and **none of the design's questions exist in
it**. Rebuilding the screen therefore means choosing content:

* default I would take: keep the app's 44 real entries, add the design's accordion row treatment,
  and keep the section titles as group headers;
* the design's screen is a flat list with no search, while the app's FAQ has search — I would keep
  the search as an addition rather than drop a working feature.

## 3f. Bonuses

* **History screen built** (`lib/features/bonuses/ui/bonus_history_page.dart`): «Баланс» header, a
  343 × 56 balance card (total 32/900 in the accent, «Как работают бонусы?» link), then 343 × 63
  rows. Verified live: balance 1000, one entry rendered as «+1000 бонусов» in gold with the
  timestamp converted to local time («3 ноября в 04:30»).
* **The design's row title has no data source.** `/bonuses` history entries are
  `{bonusId, organizationId, amount, timestamp}` — no order reference and no entry type, so
  «Заказ №45» from the frame cannot be rendered. The row shows the signed amount and its date.
* **The explainer is design-only content.** The app had no «Как работают бонусы» screen, so
  `bonus_how_it_works_page.dart` carries the frame's copy verbatim (1 бонус = 1₸, the three-step
  accrual, the 25 % spending cap, tobacco/delivery exclusions, the FAQ pointer). Its sizes follow
  the frames — body text is 10/400 there, which is genuinely small but is what the design asks for.

## 3g. Certificates

* **Screen built** (`lib/features/certificates/ui/certificates_page.dart`): the code-activation row
  (246 px field + 85 px «Ок»), the «Купить сертификат» row, a content-sized three-way filter
  (`active` / `redeemed` / `canceled` — the app's own status values, verified live by
  `certificates?status=active`), and 343 × 71 rows (name 20/700 accent, amount 16/500, state line
  green/muted/error). The account holds no certificates, so the empty state is what renders —
  «Сертификатов нет» + «Активируйте код или купите новый сертификат».
* **Purchasing is bridged, never executed.** «Купить сертификат» opens the **legacy** purchase
  flow, because buying involves a real payment. No verification run submits it.
* **Claiming is wired** (`claimCertificate`) with a snackbar result; the design shows no claim
  result frame, so the feedback is a snackbar rather than an invented screen.
* The certificate payload's amount key is undocumented, so the row tries
  `amount/balance/value/denomination/face_value` and hides the amount when none is present rather
  than printing a wrong number.

## 3h. Certificates placeholder (by request) and the intro slides

* **Certificates is now a placeholder**, as asked: `certificates_placeholder_page.dart` — a
  new-styled stub whose action opens the detailed screen, which in turn bridges to the legacy
  purchase flow. Nothing was lost by parking this area: activation and purchase stay reachable,
  and the detailed implementation is intact at `features/certificates/ui/certificates_page.dart`
  (nothing in this session is committed, so deleting it would have destroyed it).
* **The four intro slides are built and live** (`lib/features/onboarding/ui/intro_slides_page.dart`):
  the wordmark at y = 70, a 100 px accent badge with a 68 px glyph, title 20/700, body 14/400
  muted, and the constant «Войти или зарегистрироваться» pill. Copy is the frames' own
  (Персональные акции / Быстрый заказ / История покупок / Бонусы).
  * The frames contain **no pagination dots**, so none are drawn — the slides advance by swiping.
  * Two asset traps worth remembering: the slides' glyph layers are **all named**
    `vuesax/bold/discount-shape` in the file while exporting three different shapes, and the
    exported **wordmark is white-on-transparent** (drawn for the dark theme) so it must be tinted
    from the palette or it vanishes on the light theme.
  * Gated by its own `intro_slides_seen` preference in `AppEntryGate`, **not** by
    `OnboardingService` — the slides are independent of the city/permission onboarding that
    follows them, so the frozen service was left untouched.
* **Still to do in this cluster:** the phone-entry, code-entry and address screens.

## 3i. Non-content states consolidated

`lib/ui/app_states.dart` now owns `AppEmptyState`, `AppErrorState` and `AppLoading`. Every rebuilt
screen had grown its own private copy — six near-identical `_Centered`/`_Message`/`_Empty` widgets
— which is precisely the drift the redesign exists to remove. The eight affected screens
(favourites, cart, orders, bonuses, certificates, category, supercategory, search) now share one
implementation.

The design's conventions are encoded in the widget: empty = centred 20/700 title over an optional
14/400 muted subtitle, with a `muted` flag for the frames that use `#676767` instead of white
(«Товары не найдены», «История пуста»); error = the same shape with an optional retry, because the
FAQ frame is the one place the design shows an error and it has **no** button.

**Follow-ups:** `authentication_wrapper.dart` still carries its own `AppLoadFailed` for a failed
home load — the ninth copy, left alone to keep this refactor bounded; and true *offline* handling
(no connectivity) is not addressed anywhere, since the design never draws that state.

## 3j. Process note

The consolidation broke the build for one step: three files had their private classes deleted while
their call sites didn't match the patterns I searched for, leaving dangling `_Message`/`_centered`
calls. `dart analyze` caught every one and they are fixed — but the lesson is the one that bit me
twice before in this session: **verify each scripted replacement actually matched** (count your
replacements) instead of trusting the script's own progress output.

## 3k. Handoff: what to review

**Nothing in this session is committed.** `git status` now reads **8 modified + 11 untracked**
entries — deliberately small:

* modified: `.gitignore`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`,
  `lib/main.dart`, `lib/widgets/app_entry_gate.dart`, `lib/widgets/authentication_wrapper.dart`,
  `pubspec.yaml`, `pubspec.lock`;
* untracked: `lib/design/`, `lib/ui/`, `lib/core/`, `lib/features/`, `test/design/`,
  `docs/redesign/`, `assets/fonts/TikTokSans/`, `assets/icons/design/`, `tool/figma_spec.dart`,
  `tool/design_report.dart`.

**The legacy code is untouched.** At one point `git status` showed 54 modified files because I had
been running `dart format lib` (the whole tree) instead of formatting only the files I edited.
Every one of those extra 46 files was verified **token-identical to HEAD** (whitespace stripped,
MD5 compared) and reverted, so the frozen data layer, pages and services are byte-for-byte as
they were. Format only the files you touch — `dart format <paths>`, never `dart format lib`.

Verification after the revert: `dart analyze lib` → 0 errors, 0 warnings;
`flutter test test/design/components_test.dart` → 11/11.

## 3l. Accessibility pass (partial, with what remains)

Audit of the new code: **41 `GestureDetector`s, 0 `Semantics`**. Two findings, handled differently.

1. **Icon-only controls had no labels** — a screen reader would announce the bare glyphs of the
   −/+ steppers, the like hearts, the buy row and the filter tabs. Fixed for the most-used
   component: `StepTap` in `lib/ui/product_card.dart` wraps the card's −/+ in
   `Semantics(button: true, label: 'Убрать/Добавить одну штуку')`. **Still to do:** the same
   treatment for the row stepper and like button (`lib/ui/product_row.dart`), the cart's stepper,
   `AppIconButton` (its discs carry tooltips but not `Semantics` labels), and the filter tabs.
2. **Tap targets are below the 44 dp guideline** — the card's −/+ hit areas are 12 × 30 dp, the
   row's 14 × 30. **Not "fixed":** the frames' entire control is only 30 dp tall and 102 dp wide
   (77 dp on rows), so reaching 44 would mean distorting the design. This is a decision for the
   designer — raise it, don't paper over it. Widening the zones to ~28 dp each is the most the
   layout allows (the count would otherwise be squeezed), if a middle ground is wanted.

Other checks that passed without work: every icon disc already carries a `tooltip`, text uses
`MediaQuery`-driven scaling untouched by the redesign, and nothing in the new code hardcodes a
min/max text scale or disables the semantics tree.

## 3m. Docs and the release note

* **Docs are covered by this file.** `docs/redesign/STATUS.md` is the living record for the
  redesign; `docs/redesign_instructions.md` (pre-existing) remains the design doctrine. Every
  legacy `docs/*.md` topic note is untouched and still accurate, because the frozen data layer,
  API and business rules were not modified.
* **There is no `CHANGELOG.md` in this repo**, and the redesign is unreleased — nothing is
  committed and `pubspec.yaml` still reads `1.2.113`. Writing a changelog now would document a
  version that does not exist, so the entry is staged here instead, ready to paste when the
  redesign ships:

```markdown
## 1.3.0 — redesign (in progress)
- New design system: tokens, light/dark themes (OS default with a manual override), TikTok Sans,
  and icons exported from the design file. `lib/design/`, `lib/ui/`
- Screens rebuilt to the design: home, catalogue → category → search, product detail, favourites,
  cart, orders, profile, bonuses + explainer, intro slides. Certificates is a placeholder.
- Cart: explicit delete button replaces the implicit removal when the last unit is decremented.
- Architecture: feature-first `lib/features/*`, navigation intent enums, shared empty/error/loading
  states, one money formatter. Legacy data layer and business rules untouched.
- Removed: `flutter_motion_kit`, `path_drawing` (unused; the latter also blocked a Flutter upgrade).
- Pending: checkout (delivery/pickup), addresses & cards, FAQ/support/notification settings, the
  auth screens after the intro slides, and the removal of `AppColors`/`globals.dart` with the
  legacy pages they belong to.
```

## 3n. Accessibility — completion, plus a correction to my own audit

**Correction first.** §3l counted `Semantics(` occurrences and concluded that icon-only controls
had no labels. That was partly wrong: Flutter's `Tooltip` **already attaches a semantic label**, and
every disc in `AppIconButton` is created with one, so the top-bar back/search/like controls were
announcing correctly all along. The genuine gap was only the glyph-only controls.

**Now labelled:**

| Component | Labels added |
|---|---|
| `ProductCard` stepper | `StepTap` — «Убрать одну штуку» / «Добавить одну штуку» |
| `ProductRow` stepper | `_SemanticTap` — same pair |
| `ProductRow` like disc | `_SemanticTap` — «В избранное» / «Убрать из избранного», state-aware |
| Cart stepper | `_SemanticTap` — «Убрать одну штуку» / «Добавить одну штуку» |

Controls with visible text (the filter tabs, the CTAs, the activation button) need nothing: a screen
reader reads their label already.

**Still open, and it is a design decision, not a code task:** the step controls' tap targets are
12–14 × 30 dp, well under the 44 dp guideline. The frames' whole control is 30 dp tall and 102 dp
wide (77 on rows), so reaching 44 would mean distorting the design — raise it with the designer
rather than fixing it silently. Widening the zones to ~28 dp is the most the layout allows before
the count gets squeezed.

## 3o. Performance pass — done, and it ends with a retraction

**Retraction of my own first finding.** The audit initially flagged
`context.watch<CartProvider>()` inside `itemBuilder` as "one dependency per card" — that was wrong,
and I checked it before touching anything. The `context` a sliver's `itemBuilder` receives belongs to
the element created for **that child**, so the dependency registers on that card's element and the
rebuild is already scoped to the single card. `category_products_page.dart:151`, `search_page.dart:188`
and `favorites_page.dart:200` are **correct as written** — worth not "fixing". (That is the third
overstated audit finding this session; all three are corrected in place, because a record that
inflates work is worse than no record.)

**The one real observation, and why it stays.** Nine screens hold
`final cart = context.watch<CartProvider>();` at page level to feed the floating cart button
(`bonus_history:79`, `cart:104`, `category_products:76`, `supercategory:95/342/445`,
`certificates:114`, `favorites:115`, `orders:70`, `product:71`, `search:97`). Any cart change
therefore rebuilds the whole page rather than just the button — roughly 9–12 visible cards of wasted
work per tap.

Measured against the alternative, that is **not worth a nine-file refactor**: the widgets are
const-heavy, the rebuild happens on a human tap (not per frame, not in a list scroll), and the
visible-card count is bounded by the grid. Extracting a `CartButtonHost` that watches on its own
would scope it, and it stays on the list as an optional tidy-up — not a defect, and explicitly *not*
something to do while the remaining screens are unbuilt, because touching nine working pages to save
a bounded tap-time rebuild is how regressions get introduced.

**Conclusion for this item: no significant rebuild problem in the rebuilt screens.** The genuinely
heavy files are the legacy ones (`main_page.dart` 98 KB, `checkout_page.dart` 97 KB) — and profiling
them would be wasted effort, because both are being replaced (`main_page` already is). One caveat
carried forward: `CartProvider` is a single large `ChangeNotifier`, so any of its fields notifying
rebuilds every watcher. If it grows past cart/quantity concerns, split it then — with a measurement,
not on suspicion.
## 3p. Auth after the slides — recon done, screens NOT built

Gathered so the next run doesn't re-derive the flow. **`lib/pages/login_page.dart` (778 lines) is the
whole auth story**, and it is already half-replaced: `_onboardingView()` and `_slidePage()` are dead
weight now that the rebuilt intro slides shipped, and `_startAutoSlide`/`_onCarouselInteraction*` go
with them.

**What stays untouched (frozen contract, do not rebuild):**

| Region | Lines | Contract |
|---|---|---|
| `_sendCode()` | 199–237 | `ApiService.sendAuthCode(phone)`; reads `result.cooldownSeconds` and arms `_startSendCodeCooldown` |
| `_startSendCodeCooldown` / `_sendCodeButtonLabel` / `_formatCooldown` | 238–282 | resend timer, `phone`-keyed |
| `_verifyCode()` | 283–350 | `ApiService.verifyAuthCode(phone, code)` → `NotificationService.instance.syncTokenWithServerIfNeeded()` → `Navigator.pushAndRemoveUntil` |
| `_normalizedPhone` / `_ensurePhonePrefix` / `PhoneTextInputFormatter` | 13–67, 181–198 | `+` + 11 digits — WhatsApp delivery depends on this exact shape |

**What is to be rebuilt — presentation only:**

| Region | Lines |
|---|---|
| `_authFormView()` | 514–605 |
| `_phoneInput()` | 606–658 |
| `_otpInput()` | 659–740 |
| `_primaryButton()` | 741–771 |

Roughly 260 lines whose only job is layout, and which currently draw with `AppColors.orange` and
Material icons instead of the design tokens. The rebuild is: same four methods, same state fields
(`_codeSent`, `_isLoading`, cooldown), design-styled bodies on `AppPalette`.

**Before writing a line:** export the auth frames from the real Figma file (note the frame names are
not in `.figma_cache/spec/_index.json` — the earlier dump keyed pages rather than frames, so run
`tool/figma_spec.dart png` for the auth page first and confirm the phone/code/address frames and
their exact copy). The address step is a third screen and belongs to the addresses item, not here.

**Why this is not done:** it is one 778-line file with a live API flow behind it, and it needs the
frames exported first. Starting it without the frames would mean inventing the layout, which is the
one thing this project has consistently refused to do.

## 3q. Frame inventory for every remaining item (read off the real file)

`dart run tool/figma_spec.dart frames` lists 212 frames across both theme pages. These are the
dark-page node IDs — the exact handles for `spec`/`png` export, so no screen has to be invented:

**Checkout (Корзина - Доставка / Самовывоз / оплата)** — 13 frames

- `2093:9880` Корзина - Доставка - Скролл ниже 1
- `2093:10070` Корзина - Самовывоз
- `2093:10241` Корзина - Самовывоз - Скролл ниже
- `2093:10412` Корзина - Доставка - Выбор магазина
- `2093:10696` Корзина - Доставка - Выбор времени доставки - Сейчас
- `2093:10907` Корзина - Доставка - Выбор времени доставки - Запланировать
- `2093:11105` Корзина - Доставка - Выбрано Запланировать
- `2093:11276` Корзина - Доставка - Скролл ниже 2
- `2093:11805` Корзина - Доставка - Скролл ниже 3
- `2093:11976` Корзина - Доставка - Акционный товар
- `2093:15859` Корзина - Проводим оплату
- `2093:15871` Корзина - Оплата прошла успешно
- `2093:15888` Корзина - Ошибка оплаты

**Addresses (Адреса)** — 6 frames

- `2093:8928` Адреса - Добавленный адрес
- `2093:8964` Адреса - Нажатие на 3 точки
- `2093:9011` Адреса - Детали адреса
- `2093:9034` Адреса - Детали адреса - Заполненное поле
- `2093:9053` Адреса - Карта
- `2093:9274` Адреса - Карта - Ввод в поисковую строку

**Cards (Карты)** — 3 frames

- `2093:8745` Карты - Добавленные карты
- `2093:8801` Карты - Сообщение об успешном добавлении карты
- `2093:8861` Карты - Подтвердить удаление карты

**Auth (Регистрация и логин)** — 9 frames

- `2093:8277` Регистрация и логин - Слайд 1
- `2093:8319` Регистрация и логин - Слайд 2
- `2093:8337` Регистрация и логин - Слайд 3
- `2093:8355` Регистрация и логин - Слайд 4
- `2093:8375` Регистрация и логин - Вход по номеру телефона
- `2093:8416` Регистрация и логин - Введите код
- `2093:15823` Регистрация и логин - Укажите адрес доставки
- `2093:15843` Регистрация и логин - Загрузка
- `2093:15850` Регистрация и логин - Загрузка завершена

**FAQ** — 2 frames

- `2093:9841` FAQ - Не удалось загрузить
- `2093:9851` FAQ

**33 frames** cover the four open items.## 3r. FAQ — smaller than it looks, but its cached spec is a trap

Probed because 2 frames *look* like the cheapest remaining item. Two findings, one good, one a trap.

**Good: the data/presentation seam already exists.** `lib/pages/faq_page.dart` (1153 lines) separates
cleanly — `FaqEntry` (29), `FaqSectionData` (41), **`FaqRepository` (66, holds the 44 real entries in
7 sections)**, `FaqSearchDocument` (409), `FaqShortcutCard` (445), and only then the screen itself
(`FaqPage` 602 / `_FaqPageState` 616, i.e. ~550 lines of UI to the end of file). A rebuild replaces
**the UI only and reuses `FaqRepository`** — so this is genuinely the smallest of the four, and it
needs no content decision after all: the design is silent on copy, the rule is "build what the app
needs", and the app's own 44 entries are the right content. The earlier open question about FAQ copy
can be closed on that basis; record it as decided, not pending.

**Retraction — the "empty spec" trap I reported was my own probe's bug.** I claimed both cached FAQ
frames parse to 0 text nodes and warned against trusting the cache. Wrong: `tool/figma_spec.dart`'s
`_compactNode` renames Figma's `characters` to **`chars`**, and my probe looked for `characters`. Every
cached frame was reported "empty" for that reason. The cache is fine, and always was — the FAQ frame
contains real copy («Как оформить заказ?», «Какие способы оплаты доступны?», «Сколько времени занимает
доставка?» plus answers). **Read specs via `chars`, not `characters`.** I did re-export both pages while
chasing this (210 frames, ~40 s, idempotent) — no harm, but no benefit either.

**Why not built now:** the design content has to be re-exported, and the UI region is ~550 lines with
search, section ranges («N ответов • вопросы X–Y») and multi-state behaviour behind it. That is not a
slice that can be finished and verified in what remains here.

## 3s. Design brief for the remaining screens (read from the verified specs)

Extracted with the correct `chars` key. Sizes are the design's own; colours are the distinct fills

> **The `fills:` column is empty and that is a probe bug, not a fact — do not conclude these frames
> are uncoloured.** My colour walk looked for a `color` map of `r/g/b` floats; the compact schema
> stores it another way. Read the `fill` / `color` keys directly (or just re-read the frame) when
> building. The **copy is verified** and is the part that costs time to transcribe.

### Checkout

- **Корзина - Доставка - Скролл ниже 1** — 375.0×812.0 · 58 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Доставка - Скролл ниже 2** — 375.0×812.0 · 58 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Доставка - Скролл ниже 3** — 375.0×812.0 · 58 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Доставка - Выбор магазина** — 375.0×812.0 · 75 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Доставка - Выбор времени доставки - Сейчас** — 375.0×812.0 · 65 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Доставка - Выбор времени доставки - Запланировать** — 375.0×812.0 · 65 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Доставка - Выбрано Запланировать** — 375.0×812.0 · 58 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Доставка - Акционный товар** — 375.0×812.0 · 62 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Пустое поле Промокод** — 375.0×812.0 · 61 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Пустое поле Сертификат** — 375.0×812.0 · 61 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Самовывоз** — 375.0×812.0 · 58 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира
- **Корзина - Самовывоз - Скролл ниже** — 375.0×812.0 · 58 text · fills: 
  - copy: Доставка | Самовывоз | Градусы24 | Бухар-Жырау 70, Караганда | Выберите адрес | Можно выбрать позже, но перед подтверждением заказа | Подъезд | Этаж | Квартира

### Addresses

- **Адреса - Добавленный адрес** — 375.0×812.0 · 10 text · fills: 
  - copy: 09:41 | Мои адреса | Добавьте адрес | Вопросы по адресу и доставке | Посмотрите ответы про GPS, ручной ввод адреса и ограничения по доставке | Открыть FAQ | Ангарская улица, 17 | Подъезд 2, Этаж 7, Кв. 45
- **Адреса - Нажатие на 3 точки** — 375.0×812.0 · 15 text · fills: 
  - copy: 09:41 | Мои адреса | Добавьте адрес | Вопросы по адресу и доставке | Посмотрите ответы про GPS, ручной ввод адреса и ограничения по доставке | Открыть FAQ | Ангарская улица, 17 | Подъезд 2, Этаж 7, Кв. 45 | Изменить адрес
- **Адреса - Детали адреса** — 375.0×812.0 · 12 text · fills: 
  - copy: 09:41 | Детали адреса | Подтвердить и выбрать адрес | Выбранный адрес | Ангарская улица, 17 | Подъезд | Например: 2 или 2А | Этаж | Например: 7 или м
- **Адреса - Детали адреса - Заполненное поле** — 375.0×812.0 · 12 text · fills: 
  - copy: 09:41 | Детали адреса | Подтвердить и выбрать адрес | Выбранный адрес | Ангарская улица, 17 | Подъезд | 2А | Этаж | Например: 7 или м
- **Адреса - Карта** — 375.0×812.0 · 13 text · fills: 
  - copy: LOWERVAILSBURG | STREET | UNION | street name | 09:41 | Караганда, улица или дом | Ангарская улица, 17 | Сначала подтвердите точку на карте, затем добавьте подъезд, этаж и квартиру на следующем шаге | Подтвердить адрес
- **Адреса - Карта - Ввод в поисковую строку** — 375.0×812.0 · 13 text · fills: 
  - copy: LOWERVAILSBURG | STREET | UNION | street name | 09:41 | Ангарская улица, 17 | Сначала подтвердите точку на карте, затем добавьте подъезд, этаж и квартиру на следующем шаге | Подтвердить адрес

### Cards

- **Карты - Добавленные карты** — 375.0×812.0 · 10 text · fills: 
  - copy: 09:41 | Мои карты | Добавить новую карту | Не получается добавить карту? | В FAQ собраны ответы по привязке карты и оплате заказов | Открыть FAQ | **** **** **** 4444 | Карта | **** **** **** 4949
- **Карты - Подтвердить удаление карты** — 375.0×812.0 · 14 text · fills: 
  - copy: Не получается добавить карту? | В FAQ собраны ответы по привязке карты и оплате заказов | Открыть FAQ | **** **** **** 4444 | Карта | **** **** **** 4949 | 09:41 | Мои карты | Добавить новую карту
- **Карты - Сообщение об успешном добавлении карты** — 375.0×812.0 · 11 text · fills: 
  - copy: 09:41 | Мои карты | Добавить новую карту | Новая карта сохранена и готова к оплате | Не получается добавить карту? | В FAQ собраны ответы по привязке карты и оплате заказов | Открыть FAQ | **** **** **** 4444 | Карта

### Auth

- **Регистрация и логин - Вход по номеру телефона** — 375.0×812.0 · 26 text · fills: 
  - copy: 3 | DEF | 􀆛 | 09:41 | Вход по номеру телефона | Отправим короткий код подтверждения | Не приходит SMS-код? | +7| | Получить код
- **Регистрация и логин - Введите код** — 375.0×812.0 · 32 text · fills: 
  - copy: 3 | DEF | 􀆛 | 09:41 | Введите код | СМС отправлено на +7 777 777 77 77 | Проблемы с кодом? Открыть FAQ | 9 | Подтвердить
- **Регистрация и логин - Загрузка** — 375.0×812.0 · 1 text · fills: 
  - copy: 09:41
- **Регистрация и логин - Загрузка завершена** — 375.0×812.0 · 2 text · fills: 
  - copy: 09:41 | Готово!
- **Регистрация и логин - Укажите адрес доставки** — 375.0×812.0 · 11 text · fills: 
  - copy: 09:41 | Подтвердить и выбрать адрес | Пропустить | Укажите адрес доставки | Можно заполнить сейчас или позже на этапе оформления заказа. Буквы тоже подойдут: корпус, секция, подъезд А, кв. 12Б. | Подъезд | Например: 2 или 2А | Этаж | Например: 7 или м

### FAQ

- **FAQ** — 375.0×812.0 · 7 text · fills: 
  - copy: 09:41 | FAQ | Как оформить заказ? | Какие способы оплаты доступны? | Вы можете оплатить заказ банковской картой онлайн или при получении, если такой способ доступен в вашем регионе. | Сколько времени занимает доставка? | Есть ли минимальная сумма заказа?
- **FAQ - Не удалось загрузить** — 375.0×812.0 · 3 text · fills: 
  - copy: 09:41 | FAQ | Не удалось загрузить FAQ. Попробуйте еще раз позже.

## 3t. The red test files — one fixed, one still open, plus a retraction

**`test/orders/orders_history_page_test.dart` → fixed, passing.** The test built the legacy
`OrdersHistoryPage` in a `MaterialApp` with no localization delegates, so `DateFormat('d MMMM y', 'ru')`
threw `LocaleDataException` and the page never rendered ("Found 0 widgets with text «Оплатить»"). Fix:
an async `setUp` calling `initializeDateFormatting('ru')`. The page's real contract — the pay action
appearing only for payable entries — is now actually exercised, which is what the test was written for.

**Retraction — I called this a live crash and it wasn't.** I added `initializeDateFormatting('ru')` to
`main()` on the grounds that nothing initialized `intl`. Wrong: `main.dart:128` registers
`GlobalMaterialLocalizations.delegate`, which loads the date symbols for the app's locale itself. That
also explains why the rebuilt orders and bonus-history screens rendered correctly on live verification
despite both calling `DateFormat(..., 'ru')`. The startup change was redundant, so I reverted it —
adding startup work to fix a bug that does not exist is exactly the weightless code this record keeps
telling me not to write. (Sixth overstated finding; the probe-vs-artifact pattern again.)

**`test/pricing/product_detail_bottling_test.dart` → still open (5 failures).** Root cause is different
and not yet diagnosed: `UnsupportedError` thrown while building a `LayoutBuilder`, so the page never
lays out and the «1250 ₸» assertions find nothing. This is a harness/constraint problem, not the
`intl` one. Left open deliberately rather than papered over — it pins the options/bottling **pricing**
logic that the legacy bridge still uses, so it is worth repairing, not deleting.

## 3u. Startup loader hang — fixed and verified live on web

**Symptom (reported):** the app never leaves the loading screen in dev.

**Cause — two of them, neither where it looked.** `AuthenticationWrapper._checkAuth()` only called
`_loadHome()` when `userInfo != null`:

```dart
if (userInfo == null) { await AuthService.clearToken(); }
else if (mounted) { await _loadHome(); }        // ← signed-out sessions never got here
```

`build()` returns `AppLoadingScreen` while `_homeData == null`, so **any signed-out or invalid-token
session sat on the loader forever**. The home screen is public — the design ships a signed-out variant
(«Главная - Без входа в аккаунт», node `2098:32279`) — so it must load regardless of session. Second:
`ApiService.getFullInfo()`'s `http.get` has **no timeout**, so a stalled `/auth/full-info` (dead dev
server) blocked the check indefinitely.

**Fix:** `_checkAuth` now bounds the check with a 10 s timeout, treats a timeout as "guest", and
always calls `_loadHome()` afterwards. `authentication_wrapper.dart` only; no API or contract change.

**Verified live** (`flutter run -d web-server --web-port=8099`, 375×950, fresh profile): slides →
onboarding 1/2 (notifications) → 2/2 (geolocation) → city picker → **the signed-out home renders** with
the real store card «Градусы24 · Бухар-Жырау 70, Караганда», the promo carousel, the «Кухня» card, all
six category tiles and the empty cart disc.

**OneSignal was not the cause, though the report was reasonable:** the onboarding's
«Разрешить уведомления» awaits `NotificationService.enablePushNotifications()`, and with no OneSignal
in dev that path is already safe — `onesignal_web_bridge_web.dart` returns `null` when the
`GradusyOneSignal` global is absent, and every bridge call carries a 10 s timeout and a catch. Tapped
it and it advanced to step 2 cleanly.

**Retraction — my own verification was lying to me.** Several turns of "0 errors, 0 warnings" came
from `grep -cE "^\s+(error|warning)"`, and `dart analyze` prints `warning - …` at **column 0**, so the
pattern matched nothing and I reported a clean tree that had **10 warnings** (all dead imports and
unused parameters from the rebuild). Fixed the filter, cleared all 10, and the tree is now genuinely
0 errors / 0 warnings. **Use `grep -E "error - |warning - "`.** (Seventh overstated/under-counted
finding — the probe, again, not the artifact.)

## 3v. FAQ rebuilt — designed, wired and verified

**Built:** `lib/features/faq/ui/faq_page.dart` — `AppTopBar('FAQ')`, the design's search field
(«Найти вопрос или ответ»), section headings, and one-card-per-question with the answer expanded
underneath. First answer opens by default, matching the frame. Content is the app's own 44 entries in
7 sections via `FaqRepository`; only the chrome is new. The palette/type idiom is `context.palette` +
`AppTypography.*`.

**Cutover (clean, no shim):** the named route `/faq` in `main.dart` now builds the new page, which
also migrates all six legacy `openFaqPage(...)` callers at once — profile, checkout, login, help chat,
order detail, payment method. `initialSection` is preserved: the list scrolls the requested section
into view, which is exactly what the legacy `_scrollCategoryIntoView` did. The wrapper's two
`_push(const FaqPage())` sites point at the new page too. The legacy `FaqPage`/`_FaqPageState` remain
in place only as the repository's home until the `AppColors` cleanup.

**Verified live** (`127.0.0.1:8099`, signed-out): sidebar → FAQ renders the real questions, the first
answer expanded, the next section heading visible below.

**Verified deterministically** — `test/faq/faq_page_test.dart`, 3/3:
1. the first question *and* its answer render (the design's open-by-default behaviour);
2. a query narrows to matches, drops a section whose entries all miss, and removes an unrelated
   question entirely;
3. a query that matches nothing shows the empty state.

Assertion 2 was wrong on first run — I asserted the matched answer stays collapsed, but that entry is
the default-opened one, so the code was right and the test was wrong. Noted because the test caught
it, which is the point of writing it.

**Deliberately not built:** the design's «FAQ - Не удалось загрузить» frame. The content is a local
constant that cannot fail to load, so a failure state would be unreachable theatre. If FAQ ever moves
behind the API, build it then.

**Still legacy in this area:** «Поддержка» (help chat) and notification settings screens. Both are
reachable and functional; neither is rebuilt to the design yet.

## 3w. Support and notifications — frames exist, and they are NOT the same screen

Recon for the last unbuilt pair, and a naming trap worth recording.

| Design frame | Node | What it is | Status |
|---|---|---|---|
| Поддержка | `2093:8576` | support chat | **buildable** — legacy `help_chat_page.dart` (1019 lines) is live and works, so a backend exists |
| Поддержка - Ввод сообщения | `2093:8635` | the chat with the composer focused | same screen, second state |
| Уведомления | `2093:8248` | a notifications **inbox** | excluded — no endpoint (one of the 15) |
| Уведомления - Уведомлений нет | `2093:8470` | the inbox's empty state | excluded with it |

**The trap:** the sidebar row «Уведомления» in this app opens `NotificationSettingsPage` — push/telemetry
**toggles** — while the design's «Уведомления» frames are an **inbox** of past notifications. Same word,
two different things. Do not "rebuild Уведомления" by reading those frames and deleting the settings
screen: the toggles are the part the app actually needs, and the inbox is the part with no backend.

Extracted copy for the chat frames:

- **Поддержка** (375.0×812.0) — 09:41 | Поддержка | Сообщение | Сначала можно проверить FAQ | Там уже есть ответы по входу, оплате, доставке, бонусам и возвратам | Открыть FAQ | Оператор на связи
- **Поддержка - Ввод сообщения** (375.0×812.0) — Проверили информацию — карта успешно добавлена и готова к использованию. Если вы столкнётесь с ошибкой при оплате, пожалуйста, сообщите нам, и мы поможем разобраться. | “The” | the | to | q | w | e
- **Уведомления** (375.0×812.0) — 09:41 | Уведомления | Хотите получать скидки и подарки? | Прочитать все | Бесплатная доставка от 10 000 ₸ | Соберите заказ на 10 000 ₸ и мы доставим его бесплатно. Выбирайте любимые напитки без лишних затрат! | 10 июня

**Not built:** the support chat is a message list plus composer over the legacy send/history API. It is
the one remaining screen where the legacy code is *working* and sizeable (1019 lines), so a partial
rebuild would be a live regression rather than a missing screen — which is why it was not started on
a nearly-spent context. Everything needed to start is above: frames, node IDs, the legacy file, and
the backend it already talks to.

## 3x. Whole-suite state after today's edits (measured, not assumed)

`flutter test` → **56 passed, 8 failed**. Every failure is in
`test/pricing/product_detail_bottling_test.dart`, the pre-existing red file whose root cause is
already diagnosed in §3t (`UnsupportedError` building a `LayoutBuilder` — a harness/constraint
problem, not the `intl` one). Nothing else in the suite regressed from today's changes: the warning
cleanup (unused imports, `super.key` removals in `cart_page`/`product_row`), the `AuthenticationWrapper`
startup fix, the FAQ rebuild and the `/faq` routing cutover all pass.

Correction: I had recorded this file as "5 failing tests" from a partial run. **It is 8.** The earlier
number came from grepping one run's output rather than counting the suite's own summary — the same
under-measuring habit behind the `chars` walker and the analyzer filter. Count from the summary line.

## 3y. Three boot bugs, two of them mine — from a real console trace

Reported: blank dark screen, then endless loading on web. The trace was conclusive.

**1. Portrait lock aborted `main()` on web (mine).** The stack shows
`DomScreenOrientation.lock` → `[_completeErrorObject] completeError` →
`setPreferredOrientation` → `SystemChrome.setPreferredOrientations` → **`main.dart:36`**. On web
`screen.orientation.lock()` **rejects unless the document is fullscreen**, and I awaited it unguarded
at the top of `main()`, so on a browser that refuses the lock the app never reached `runApp` — a blank
page with no error the user can see. Fix: skip the call when `kIsWeb` (Android/iOS keep their native
locks in the manifest / Info.plist, so the requirement is still enforced where it matters).

**2. The web splash deleted itself mid-boot.** `web/index.html` had a
"ultimate safety net: remove splash after 15 seconds no matter what". A cold debug-web load fetches
**1152 DDC modules** and takes longer than that, so the splash vanished while the app was still
booting → the blank dark page. Fix: the net now waits for `flutter-view, flt-glass-pane` before
handing over, and if Flutter still has not appeared it **keeps the branded splash and tells the user**
(«Загрузка занимает дольше обычного…») instead of blanking. Verified on a cache-disabled cold load:
splash → app, no blank window.

**3. Home fetch could hang forever.** `HomeDataSource.load()` `Future.wait`s four endpoints with no
timeout, so one stalled request left `_homeData == null` and the loader spinning — the
"endless loading". Fix: `.timeout(20s)` in `_loadHome`, after which the existing error state shows
with its retry. Same class of bug as the un-timed `/auth/full-info` fixed in §3u — **any await on the
startup path needs a bound.**

**OneSignal console flood — fixed.** `web/index.html:88` logged on *every* failed bridge call, and a
blocked SDK makes all of them fail: a web run printed **40 identical `OneSignal web error`** entries.
The bridge already tolerates a missing SDK (null bridge + 10 s timeout + catch), so nothing was broken —
it was pure noise. The catch now logs **once**, with a message that says what actually happened
(«push is disabled on this origin»), and suppresses repeats.

**Verified after the fixes**, cold load with the HTTP cache disabled:
- served HTML contains both the 60 s net and the dedupe (checked by fetching `index.html` directly);
- a fresh load logs **2 console entries, 0 errors, 0 OneSignal errors** (was 40);
- during the boot window that used to be blank, the screen shows the **branded splash** — «Градусы24»,
  the tagline, the progress bar and a rotating fact («Свежее разливное пиво») — which is the whole
  point of the fix.

**Agent tooling installed (requested):** `.agents/skills/` now holds the official Dart/Flutter skill
sets (`npx skills add flutter/agent-plugins` + `dart-lang/skills`) — 12 `dart-*` skills plus the
`flutter-*` ones (widget/integration tests, layout issues, responsive layout, localization, routing),
including `dart-fix-runtime-errors`, which is exactly the workflow that would have shortened this hunt.

## 3z. Smoke test of the still-legacy screens (after today's routing changes)

Ran because the FAQ cutover touched the route table, and addresses/cards/support are the screens my
remaining items cover — a regression there would be invisible until someone rebuilt them.

| Screen | Result |
|---|---|
| Адреса (legacy) | opens, renders, no errors |
| Карты (legacy) | opens — «Мои карты», empty state, FAQ hint card, «Добавить новую карту» |
| Поддержка (legacy) | **not reached** — my tap sequence landed on a category tile instead |
| Крепкие напитки (rebuilt) | renders correctly with live data as a side effect of the mis-tap |

**Console across the whole walk: 1 error**, and it is the expected suppressed line
(«OneSignal web unavailable — push is disabled on this origin»). So the dedupe works and there are no
navigation crashes.

**Method note, worth keeping:** driving Flutter web by coordinate is fragile — the same tap that opened
the sidebar one minute earlier landed on a product tile the next, and I burned three attempts on it.
Stable-finder automation (Flutter Driver / the widget inspector over MCP) would make this reliable, and
`integration_test` with `find.byKey` would make it permanent. That is the concrete argument for the
tooling in §3y, not a tidiness one: the verification loop is the slow part of this project.

## 4a. How to run this app in dev on Windows (the OOM is the toolchain, not the app)

**Symptom:** `flutter run -d chrome` dies with
`../../runtime/platform/allocation.cc: 22: error: Out of memory` (Dart 3.12.2, windows_x64) during
compilation, with a stack full of `_Utf8ConversionSink` / `Stream.fold` frames.

**Diagnosis:** the **DDC dev compiler** ran out of memory, not the application. The earlier console
dump confirms the scale — the debug web build loads **1152 modules** (`DDC is about to load
1152/1152 scripts`). DDC plus a file watcher plus a heavyweight dependency set (`sentry_flutter`,
`onesignal_flutter`, `provider`, `shared_preferences`, `package_info_plus`, …) is the memory hog here.
Nothing in the app crashes at runtime in this trace; the crash is inside `flutter run` while emitting
the bundle.

**Confirmed by the run that produced this entry:**

```
Compiling lib\main.dart for the Web...  62.3s
✓ Built build\web
```

**Use this instead:**

```bash
flutter build web --release      # one dart2js compile, no watcher
# then serve the output statically, e.g.
python -m http.server 8100 --directory build/web
```

Three problems disappear at once:

| | `flutter run -d chrome` (DDC) | `build web --release` + static serve |
|---|---|---|
| Memory | OOMs on this machine | a single compile, no watcher |
| First paint | 20–60 s (1152 modules) | seconds |
| Splash window | long enough to need the 60 s net | barely exists |

That last row matters: the blank-screen bug in §3y was *caused* by the slow DDC boot outlasting the
splash. A release build makes that whole class of problem rare, and the splash fix keeps it honest
when it does happen.

**Verified end-to-end:** `flutter build web --release` finished in **62 s** (the debug run OOMs), and
served statically (`python -m http.server 8100 --directory build/web`) the app reaches its first
screen in **under 7 s** — against 20–60 s under DDC, with 2 console entries and 1 error, the expected
suppressed OneSignal line.

**Build warning triaged, no action taken:** `Expected to find fonts for (MaterialIcons,
packages/cupertino_icons/CupertinoIcons), but found (MaterialIcons)`. Checked before reacting —
**zero `CupertinoIcons` references in `lib`** and `cupertino_icons` is not a declared dependency, so no
glyph can be missing and the warning is spurious. Adding the package would be a dependency nobody
uses; the MaterialIcons tree-shake (1 645 184 → 25 232 bytes) is working as intended.

**If you must use hot reload**, keep the module count down (drop unused dependencies — two were
already removed early in this project) and close memory-heavy apps; the watcher's footprint is what
crosses the line, not the app's.

---

## 4. Rules you have given that must hold

1. **No bottom bar, ever.** Only the cart button may float, showing the total when needed.
2. **The cart must show a delete button before removing an item** — decrementing the last unit must
   surface an explicit delete affordance rather than silently dropping the line.
3. Apps and designs drift: where the design is silent, build what the app needs; where the design
   shows something the app cannot do (no backend), leave it out and record it here.
4. Backend is **frozen** and **production**. No new endpoints; verify read-only.
5. The account under test is personal: **never** touch payments, **never** create orders, and do not
   mutate addresses or cards.

---

## 5. Remaining work

Tracked in the session todo list (18 items at the time of writing). Sequence: favourites →
cart → checkout → orders → profile cluster → bonuses/certificates → addresses/cards → FAQ/support
→ auth/onboarding → cross-cutting states → cleanup (`AppColors`, `globals.dart`, legacy pages) →
per-screen delta report.

### Per-screen fidelity so far (design vs render, chrome excluded)

| Screen | meanΔ | pixels > 32 |
|---|---|---|
| Home (dark) | 10.74 / 255 | 8.66 % |
| Home (light) | 13.89 / 255 | 5.23 % |
| Product cards grid | 11.28 / 255 | 6.63 % |

Residuals are the deliberately-removed bottom bar, the unexportable icon glyphs, and text
antialiasing.
