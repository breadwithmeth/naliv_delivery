# Сначала исправления, затем дизайн целых экранов

План принят 2026-10-08. Клиентские F1–F11, композиция D1–D4 и доступная клиентская проверка D5 выполнены; команды, actual runtime и границы приёмки — в `STATUS.md`/`FIDELITY.md`. Реальные банк, loyalty/1С и push не объявлены исправленными без их sandbox-приёмки.

## Приоритет и границы

Этот план задаёт новый порядок работ после последнего сообщения пользователя. Его наблюдения
считаются дефектами, а не опровергаются прежними тестами или синтетическими скриншотами.
Сначала исправляем поведение и деньги; затем приводим приложение к полным экранам Figma.
Старые отметки «implemented/verified» в `PLAN.md` и `STATUS.md` — история, не приёмка этих проблем.

Активная цепочка: `AuthenticationWrapper` → home/catalog → product → cart → `CheckoutPage` →
`PaymentMethodPage`; cards, support, orders и часть форм по-прежнему находятся в `lib/pages/*`.
Используем существующие providers, `lib/features/*`, `lib/design/*`, `lib/ui/*` и строгую галерею
`tool/dev_surface.dart`; новый router, второй UI-kit или отдельное preview-приложение не нужны.

Проверки production/account — только чтение. Никаких реальных SMS, сообщений оператору,
изменений карт/адресов, заказов, возвратов и платежей. Клиентские сценарии — на strict fixtures;
реальные банковские/push/1С цепочки — только в изолированном согласованном sandbox.

Сохраняем существующие границы: неизвестный результат создания/оплаты не разрешает повторную
мутацию; успешный возврат из банка не равен оплаченности; история заказа не очищает новую корзину;
тара, включая тару подарочного напитка, оплачивается обычно. Ровно 3 л не возвращаются в продажу;
старые количества читаются без потери литров/тарифа и могут быть уменьшены/удалены. Денежные
инварианты M1 сохраняются; презентация акций, configurable item и розлив M2–M4 интегрированы
во второй этап. M5 разделяет клиентские доказательства и внешнюю банковскую/учётную приёмку.

## Результат клиентской реализации

| Пакет | Выполнено | Что не доказывает fixture |
|---|---|---|
| F1/F2/F3 | Возврат после OTP в тот же checkout; business в сохранённой корзине; явное подтверждение смены магазина; обязательный bag по `KR-00002264` | Реальная отправка SMS/создание заказа запрещены при проверке |
| F4/F5 | Общая eligible-база/точность, актуальный баланс, фактические signed ledger/return states | Авторитетная loyalty policy и reversal в 1С |
| F6/F7 | Поддерживаемая Halyk collection и отдельная full-info summary, masked-only display, только проверенный charge ID; повторное открытие принятой ссылки без новой оплаты; durable unknown-result locks | Проблемный личный аккаунт, реальный банк и platform/scheme lifecycle |
| F8/F9/F10 | Дробные кг/stock/шаг, каноническая identity metadata, полные категории и выбранные leaf/“Все” destinations | Отсутствующие в API master-data атрибуты не выдумываются |
| F11 | Identity isolation, allowlisted payload, cold-click/login continuation, foreground deduplication | Развёрнутый publisher, HTTPS worker и signed-device push |
| D1–D4 | 212 сохранённых полных Figma frames; единые glass layers; обе темы; все семейства активных экранов, включая конфигурацию/розлив | Синтетические фото/карта/тексты не равны production или pixel parity |

Ниже сохранены исходные дефекты и критерии принятого плана. Разделы «Факт» описывают состояние
на момент исследования, а не текущие номера строк/реализацию. Новые команды, runtime journeys
и точные остаточные prerequisites — в `STATUS.md`; измерения — в `FIDELITY.md`.


## Часть 1 — исправить все заявленные проблемы

### F1. Вход из оформления возвращает на главную — P0, клиент

**Факт.** `checkout_page.dart:839–846` открывает `LoginPage` без режима продолжения.
По умолчанию это `replaceRoot` (`login_page.dart:73–88`); после проверки кода
`pushAndRemoveUntil(..., false)` удаляет checkout (`:320–330`). Режим
`returnAuthenticated` и сохранение исходного маршрута уже реализованы (`:354–374`).

**Работа.** Использовать существующее возвращение результата в тот же checkout, включая
обязательное заполнение профиля. Сохранить корзину, магазин, доставку/самовывоз, адрес, поля и
введённые коды. После входа обновить auth/account и перечитать зависимые денежные данные;
не применять старую неподтверждённую льготу автоматически. Не создавать новую оболочку
приложения вместо продолжения. Отмена и поздний ответ на закрытом login не меняют draft.

**Приёмка.** Гость → товары → оформление → fixture-login → тот же checkout и те же товары/поля;
назад из login, незаполненный профиль, отказ/задержка авторизации не теряют состояние.
Расширить реальные consumer-сценарии `checkout_page_test.dart`/`card_reauthentication_test.dart`,
а не тестировать только наличие enum или копирование параметра.

### F2. Магазин на главной и в оформлении расходится; корзина исчезает — P0, клиент

**Факт.** `HomeDataSource` выбирает первый business при отсутствии сохранённого
(`home_data_source.dart:204–212`) и показывает его `storeId`; это не сохраняет выбор в
`BusinessProvider`. Каталог/корзина открываются с `homeData.storeId`
(`authentication_wrapper.dart:348–374`), а checkout читает только provider
(`checkout_page.dart:111`). Выбор магазина там заканчивается `clearCart()` (`:513–564`).
Нынешние fixture preferences заранее содержат `selected_business`, поэтому скрывают первый запуск.

**Работа.** Один выбранный business в provider и persistence до открытия магазинного каталога.
При восстановлении учитывать магазин существующих cart rows; не приписывать неизвестную старую
корзину произвольному первому магазину. Автовыбор отображаемого магазина не является сменой
магазина и не очищает корзину. При выборе того же ID — no-op, включая нормализованные строковые ID.
Для другого магазина не переносить локальные item/relation IDs вслепую: оставить исходный cart
сохранённым и объяснить несовместимость. Только отдельное явное подтверждение удаления разрешает
начать корзину другого магазина; отмена/ошибка сохранения сохраняет старую полностью. Если нужен
перенос, он допустим лишь после существующего серверного сопоставления/пересчёта, не по имени.

**Приёмка.** Чистые preferences → home shop A → добавить → checkout уже A; повторный выбор A,
login, перезапуск и отказ записи не меняют строки, количество, опции и сумму. Смена A→B без
явного согласия на удаление не теряет cart. Проверить actual wrapper route, не только вручную
смонтированный checkout с заранее выбранным магазином. Использовать
`business_provider_test.dart`, `checkout_page_test.dart`, native journey.

### F3. Всегда фирменный пакет-майка, не чёрный — P0, клиент + каталог/API

«Майка» здесь — **пакет-майка для заказа**, не одежда.

**Факт.** `_bagIds` и цена 30 ₸ захардкожены (`checkout_page.dart:60–74`).
Любая позиция с текстом `пакет`/`bag` подавляет автоматический пакет (`:716–737`). В коде нет
проверенного признака фирменного пакета; по одному ID нельзя доказать цвет/бренд. Сообщение
пользователя о чёрном пакете принимается, а существующий mapping не считается корректным.

**Работа.** Получить подтверждённые item IDs фирменного пакета для каждого business, цену,
доступность и правило участия в списании бонусов. Использовать существующую серверную
конфигурацию/каталог, если она содержит этот контракт; иначе исправить контракт у владельца API.
Убрать подавление пакета по свободному имени. Автоматическая упаковка должна разрешаться по
точной идентичности фирменного SKU, добавляться один раз и быть видна в preview/итоге/заказе.
Другой купленный пакет не должен незаметно подменять обязательную фирменную упаковку; отделить
его как товар от упаковки заказа. Нет фирменного SKU/остатка — объяснимая ошибка, не молчаливая
подстановка чёрного и не исчезновение кнопки бонусов.

**Приёмка.** Delivery/pickup во всех магазинах сериализуют правильный фирменный SKU ×1;
неправильный пакет и повторное открытие checkout не отменяют/дублируют его. Сервер принимает
списание бонусов с этим составом. Проверить mapping/цену по реальным read-only данным;
fixture SKU 48044 сам по себе не доказывает фирменность. Затем sandbox-order и бонусы.

### F4. Бонусы не работают / рассчитываются неверно — P0, клиент + владелец loyalty API

**Факты.** `BonusRules.earnRate` = 3% (`bonus_rules.dart:4`); карточки округляют на единицу,
корзина/checkout — по сумме. Списание в checkout — `min(balance, cartTotal * 0.3)` без исключения
табака из базы и без согласованной точности (`checkout_page.dart:742–744`). FAQ говорит 25%
(`faq_repository.dart:195,209`), клиентская API-документация — 30%. Home/checkout/history читают
`GET /bonuses` отдельно; wrapper не обновляет home после возврата из дочернего маршрута.
Карточка заказа вычисляет «Начислено» даже для возвращённых/отменённых заказов
(`orders_page.dart:192–196,279–302`), а не показывает подтверждённую проводку.

**Работа.**
1. Зафиксировать серверное правило: начисление, лимит/база списания, табак, подарки, тара/пакет,
   доставка/сбор, применение promo/certificate, момент начисления и точность/округление.
   **Не выбирать 25% или 30% по предпочтению** и не считать текущий unit test бизнес-правилом.
2. Один расчёт по подтверждённому правилу для card/cart/checkout; оценка до завершения заказа
   явно является оценкой. Учитывать платные строки, бесплатный товар и обычную стоимость всей
   тары отдельно. Списываемое значение не превышает актуальный баланс/допустимую базу.
3. Перед отправкой проверять свежесть льготы; сервер остаётся источником принятой суммы и
   проводки. Изменение состава/магазина/пакета инвалидирует расчёт, не историю пользователя.
4. Обновлять баланс/history/home при завершении оплаты, возврате на экран и relevant status
   update/resume. Не подменять ошибку чтения нулём и не показывать локально придуманное начисление.
5. Устранить расхождения пользовательских условий/FAQ после подтверждения правила. Применять
   существующую политику взаимоисключения льгот до установления другого серверного контракта.

**Приёмка.** Смешанная eligible/tobacco корзина, дробный вес, скидка/подарок/тара/фирменный пакет,
нулевой/малый/изменившийся баланс, граница округления, переключение льгот, отказ/успех сервера.
Сумма списания, payable и фактическая запись ledger согласованы; card/cart/checkout не обещают
разные бонусы для одного состава. Старые `checkout_page_test.dart`/certificate/financial
регрессии сохраняют защиты, но меняют ожидания только по доказанному правилу.

### F5. Возврат в 1С не откатывает бонусы — P0, 1С + backend ledger; клиент отображает результат

**Граница доказательства.** В этом Flutter-репозитории нет обработчика возвратов/1С, бонусной
записи или webhook. Есть чтение `/bonuses`, заказов и подписи статусов 7/71
(`order_ui_helpers.dart:21–22`). Смена подписи/локальный минус из баланса не исправят учёт.

**Работа владельца 1С/backend.** Проследить событие возврата до исходного заказа и ledger;
для полного/частичного возврата сторнировать исходное начисление по возвращённым строкам и
восстановить списанные бонусы по подтверждённой политике. Не пересчитывать историческую
проводку по сегодняшним ценам/акциям. Повторная доставка одного return/document/line события
не создаёт второй откат; частичные события в сумме не превышают исходные суммы. Зафиксировать
политику, если начисленные баллы уже потрачены, и порядок возврата денег/бонусов.
Экспортировать read-only результат: тип/сумма/ссылка на заказ и возврат, актуальный баланс.
Это требование к существующей интеграции, а не выдуманное имя нового endpoint.

**Работа клиента.** Показывать подтверждённое сторно/восстановление в истории и деталях заказа;
не утверждать «Начислено» по первоначальной стоимости после возврата. Перечитывать серверный
баланс при возвращении/resume/status update. Не разрешать повторно оплачивать закрытый/возвращённый
заказ из-за отсутствия старого payment flag. Сохранять нетронутую новую корзину.

**Приёмка.** Sandbox 1С: полный возврат; два частичных; повтор того же события; расход бонусов
между продажей и возвратом; заказ без начисления/со списанием. Проверяем ledger и баланс
через API, затем видимый результат в приложении. **Без этой внешней цепочки F5 не закрывается**,
даже если все Flutter tests зелёные.

### F6. Банковские карты не показываются — P0, клиент + банк/API

**Факт.** Profile/payment/certificates читают `/user/cards?source=halyk`. Парсер API принимает
только `{success:true,data:{cards:List}}` (`api.dart:2137–2172`). `SavedCard.parse`
(`card_flow.dart:30–63`) требует chargeable ID и безопасную mask; full-info summary отдельно.
Фикстуры заранее выдают нужную форму — это не доказательство реального банковского ответа.
Причина production-невидимости пока не установлена.

**Работа.** Сопоставить обезличенные read-only ответы full-info и card collection для того же
аккаунта/источника с ID, mask, статусом и source. Исправить подтверждённый envelope/field/source
mismatch у всех потребителей сразу, не добавлять произвольные fallback-пути. Разделить
«сохранённая карта для отображения» и «идентичность, которой сервер разрешает платить»;
не выдавать local row ID/PAN за bank token. Если банк использует длинный цифровой ID, правило
PAN-подобного ID проверять по контракту, а не безусловно обходить безопасность.
Сохранить distinct loading/empty/error/partial/auth и retry, обновление после bank return/resume;
новая mask/возврат из вкладки не подтверждают новую привязку.

**Приёмка.** Один подтверждённый snapshot карточек виден в profile/payment/certificate;
существующая карта не исчезает из-за одной плохой записи. Mask-only записи нельзя списывать.
Проверить expired auth, таймаут/partial, повторный read и подтверждённый новый bank ID.
Расширить `saved_card_api_test.dart`, `card_flow_test.dart`, `card_pages_test.dart` фактической
формой ответа; sandbox binding — отдельно от fixture-доказательства.

### F7. Иногда не открывается платёжный шлюз — P0, клиент + platform/bank

**Факт.** Kaspi web-вкладка резервируется до await (`payment_method_page.dart:214–219`),
но native запускается только после `canLaunchUrl` (`:463–482`). Android queries объявляет
CustomTabs, не VIEW схемы платёжной ссылки; iOS `LSApplicationQueriesSchemes` отсутствует.
Это **кандидат причины**, не доказательство каждого сбоя. После принятого платежа и ошибки
launch guard остаётся unconfirmed; ссылки для явного повторного открытия в UI нет.
Основной payable display использует другую приоритетность полей (`:582–605`), чем
`resolveServerChargedAmount`, поэтому предупреждение может расходиться с крупной суммой.

**Работа.** Разделить создание payment attempt, открытие уже полученной ссылки, возврат и
server status. Зафиксировать точный ответ/схему/платформу для Kaspi и bank/card challenge,
если последний реально предусмотрен контрактом. Сохранить синхронное reserve на web;
проверить закрытую/заблокированную вкладку, поздний ответ и отказ навигации. Native launch
должен поддерживать подтверждённую схему/HTTPS и существующий bank lifecycle, без ложного
отказа из-за preflight. Видимая кнопка «Открыть оплату» повторно открывает тот же действующий
attempt/link, **не отправляет второй pay/create**; expiry решается по серверному состоянию.
Success только от сервера, pending/unknown lock сохраняется после reload/resume.
Один server amount resolver для основного итога и notice; echoed client total не означает пересчёт.

**Приёмка.** Slow response, popup-block/закрытие, банк установлен/не установлен, cancel,
foreground/resume/reload, pending/refused/completed/unknown. Один платёжный запрос;
неудавшееся открытие не превращается ни в success, ни в невидимое вечное ожидание.
`order_payment_recovery_test.dart`/`order_payment_guard_test.dart` плюс реальный browser launch
на synthetic provider и Android/iOS sandbox. Windows не доказывает mobile bank launch.

### F8. Позиции продаются по кг — P1, клиент + каталог/API для отсутствующих правил

**Факт.** `Item.amount` уже double, но typed `CategoryItem.amount` — int и использует `_parseInt`
(`api.dart:3036,3090–3091`). `effectiveStepQuantity` допускает дробный шаг, иначе берёт quantity/1
(`item.dart:207–212`). Shared cards выводят цену без `/кг`; форматирование quantity/unit
расходится между card/row/detail/cart/checkout/orders. Наличие `кг` не делает товар розливом.

**Работа.** Сохранить дробные stock/quantity/step во всех DTO и persistence путях, единица и
price basis — данные товара, а не название категории. Явно показывать ₸/кг и выбранные кг;
шаг/минимум брать из подтверждённого каталога, не назначать всем 0,1 кг. Если quantity — вес
фасовки, а не шаг продажи, не смешивать эти значения. Полностью провести units через search,
favorites, detail, cart, checkout и repeat/history; сериализовать точное базовое amount.
Если магазин продаёт фактически взвешиваемый товар с предварительной ценой, сначала подтвердить
серверный контракт финального веса/стоимости; не обещать фиксированную сумму без него.

**Приёмка.** Synthetic item 1000 ₸/кг с подтверждённым шагом 0,25: 0,25 кг = 250 ₸,
0,75 кг = 750 ₸ и `amount:0.75`, reload/edit/repeat сохраняют вес. Остаток 0,75 не становится 0;
stock boundary/подарочные количества не продают лишнее. Отдельные шт./л не меняют семантику.
Дополним существующие quantity/stock/payload consumer-тесты, не матрицу слов/виджет-типов.

### F9. Названия, банка/бутылка/материал, крепость и детали расходятся — P1, клиент + master data

**Факт.** `ItemTitlePresentation` уже содержит type/packaging/volume/alcohol
(`item_name_presentation.dart:5–72`). `ProductView.fromItem` передаёт только очищенное имя,
country/volume/category/unit (`product_view.dart:112–142`); ABV/packaging теряются.
Search/favorites rows, cart, product и history показывают разные подмножества атрибутов.

**Работа.** Один identity projection: бренд/вариант, тип, упаковка, объём/масса, ABV и известные
детали. Приоритет — структурированные данные; существующий разбор явных токенов названия —
только подтверждённый legacy источник. Если убрали «жб», «бут», объём или процент из заголовка,
они обязаны остаться видимой metadata, а не исчезнуть. «Бутылка» не доказывает стекло; материал
и отсутствующий процент не выдумывать. Исторические заказы сохраняют фактический snapshot,
не подменяются сегодняшней номенклатурой.

**Приёмка.** Garage Hard Lemon и отдельный can SKU различимы на home/catalog/search/favorites,
product/cart/checkout/orders. Название бренда/варианта одинаково, упаковка, объём и реальный ABV
не теряются и не повторяются дважды. Raw name и order item IDs не меняются от презентации.
Проверить long Cyrillic/Latin, отсутствующие атрибуты, вес и исторические строки.

### F10. Категории плохо видны и неоднозначны — P1, клиент

**Факт.** `_ChipStrip` различает selected/unselected главным образом близкими muted fills и
всегда выделяет индекс 0 (`supercategory_page.dart:226–239`). `CatalogDataSource` расплющивает
leaf categories, теряя parent label (`catalog_data_source.dart:121–146`); одинаковые названия
разных категорий становятся неоднозначными.

**Работа.** Сохранить иерархию/ID; нормализовать whitespace и добавить родительский контекст
там, где одинаковые названия иначе неразличимы. Выбранное состояние отражает реальный экран,
не индекс. В первом этапе исправить читаемость подписей, контраст/границы и видимый доступ ко
всем категориям, including offscreen, empty/error/retry; каждый target ≥44 px. Полная композиция,
арт и glass затем D2, но использовать один shared component, не временный второй дизайн.

**Приёмка.** Пользователь читает названия и понимает выбранную категорию в обеих темах;
одинаковые leaf names ведут к правильным IDs; горизонтальная прокрутка/назад/«Все» и
pagination доступны. 375 px и увеличенный текст не отрезают название/действия.
`catalog_flow_test.dart`/home active journeys и фактический visual review.

### F11. Нет уведомлений от поддержки — P1, клиент + support backend/push provider

**Факт.** Chat polling/Socket.IO живут в page-owned `ChatApiService`; после закрытия страницы
они не дают background push (`chat_api_service.dart:314–325`, `help_chat_page.dart:64,75–80`).
OneSignal click router поддерживает orders/promotions/delivery, остальные payloads ведут домой
(`notification_service.dart:291–336`). Subscription payload не содержит связанного chat/session
(`:349–380`); web bridge не имеет chat click path. Публикация operator-message push находится
за пределами клиента и в этом репозитории не доказана.

**Работа.** Подтвердить operator-message event, recipient mapping между support session и
авторизованным user, payload schema, permission/subscription и backend publishing.
Не заменять push постоянным фоновым polling. Добавить client routing именно в нужный chat,
включая foreground/background/cold start и login continuation без потери checkout/cart.
Синхронизировать историю сообщения при открытии, дедуплицировать push/socket одного message.
Chat session сейчас device-wide: разграничить её при logout/account switch, чтобы не открыть
чужую переписку и не послать сообщение предыдущему пользователю. Никакого session token в push.
Согласовать support notification preference с транзакционными уведомлениями, не marketing tag.
Проверить web service worker/click bridge и подписанные iOS capabilities/App Groups.

**Приёмка.** Trusted sandbox operator reply: открытый чат; home; background; terminated;
разрешение denied→granted; logout/другой аккаунт; expired auth. Нажатие открывает правильный
разговор и новое сообщение ровно один раз; другая учётная запись его не видит. Нужны реальные
Android/iOS и поддерживаемый web; fixture click/navigation не доказывают доставку push.
`chat_api_service_test.dart`/`help_chat_page_test.dart` сохраняются; добавить лишь нужные
state/identity/route регрессии. Production chat send/push registration в ходе проверки запрещены.

### Порядок выполнения первой части

1. Начать read-only контрактную сверку F3/F4/F5/F6/F7/F8/F9/F11 и запрос внешних sandbox данных
   у владельцев через точный перечень ниже; это не блокирует доказанные клиентские F1/F2.
2. F1 → F2: сохранить checkout draft и единый магазин, устранить потерю корзины.
3. F3 → F4: правильный фирменный SKU и согласованный денежный/bonus расчёт; F6 → F7 параллельно
   независимой веткой после фиксации банковских контрактов.
4. F8 → F9 → F10: единицы, идентичность товара, однозначная навигация/читаемые категории.
5. F11 и внешняя ветка F5: получение/маршрутизация сообщений, сквозное сторно 1С.
6. Интеграция: гость → магазин → кг/шт. товары → checkout/login → фирменный пакет → bonus →
   bank sandbox → server-confirmed status; отдельно 1С return → ledger/history и operator push.

**Gate 1.** Каждый F1–F11 имеет наблюдаемую проверку своей приёмки. Внешняя зависимость остаётся
явно незакрытой, а не считается «fixed in UI». Переход к дизайну не переименовывает незавершённый
backend defect в визуальный. Можно готовить PNG inventory заранее, но не принимать визуальный
этап вместо функциональных исправлений.

## Часть 2 — восстановить дизайн по полным изображениям Figma

### D1. Полный экран — единица сравнения

Источник: [полный дизайн Градусы24](https://www.figma.com/design/HYTqbt63dc1ediNylJF7pt).
Обе страницы: `Design System (Dark)` и `Design System (Light)`. Перед работой экспортировать
**все полные screen frames в PNG ×2**, включая scroll, sheets, формы, успех/ошибку/empty.
Не собирать макет из JSON координат, отдельных компонентов или инспекции одного элемента.

Использовать `dart run tool/figma_spec.dart png --force`, `.figma_cache/shots/` и manifest
с page/frame/node ID/version. Одноимённые frames сохранять отдельно по ID: обычный exporter
обрезает trailing space, и два варианта «Главная - Без входа в аккаунт» иначе перезаписываются.
Сначала посмотреть весь экран, его визуальную иерархию и фон под стеклом; только потом выбирать
existing primitives для реализации. Screenshot не становится неподвижной картинкой UI.

Для каждого активного маршрута: reference full PNG + actual full viewport + тот же scroll/modal/
keyboard state + список работающих controls/destinations/data/loading/empty/error. Сравнение
при 375×812, 48/34 fixture insets, DPR2; в браузере явно `page.setViewport` с deviceScaleFactor:2.
Production использует device insets, не нарисованную status bar.

### D2. Целая композиция и liquid glass, не несколько оранжевых кнопок

Переоткрываем прежнюю visual acceptance. Наличие `AppGlassChip`/blur в отдельных контролах
не устанавливает сходство экрана. На текущем whole-screen baseline видны другие пропорции
каталога/карточек, другой item layout и матовые footer blocks; Figma рисует единое плавающее
стеклянное покрытие поверх продолжающегося контента.

Порядок: фон/арт и content scale → header/section rhythm → информационная иерархия → scrolling
и overlays → glass material/свет/границы/тени → состояния/transition. Стекло должно показывать
реальный фон с размытием/прозрачностью и соответствующей reference формой; solid fill или blur
на пустом фоне не доказывают liquid glass. Если reference требует дополнительного эффекта,
прототипировать его на существующей shared surface и принимать по полному кадру, не по названию.

Применить композицию к header discs, store control, category/«Все» actions, floating cart,
product confirmation, checkout footer, sheets/forms/account controls по тому, где она есть на
полном reference. Не делать всю страницу стеклянной вопреки кадру и не добавлять отдельный
BackdropFilter на каждую карточку без измерения. Проверить scroll/keyboard/resizing на реальном
renderer и native профилировании; старый удалённый shader не возвращать автоматически.

Сохранять OS text scaling, темы и ≥44 px target. При 375 px сначала добиваться reference
пропорций/порядка, а не заранее объявлять произвольную 2-column замену/уменьшенный арт
«допустимым отклонением». Адаптивные departures при 320/800 и 1,6×/2× документировать отдельно,
если они действительно нужны читаемости. Проверять реальные длинные названия/единицы/цены из F8/F9.

### D3. Последовательность экранных семейств

| Пакет | Полные reference frames/состояния | Активные маршруты и результат |
|---|---|---|
| D3.1 Главная и выбор магазина | «Главная», guest/auth, address sheet, scroll 1/2, bonus overlay, active-order statuses | `HomePage/HomeScreen`, `HomeStoreSheet`; восстановить header/store/search/banner/kitchen/categories/bonus/product rhythm и cart overlay |
| D3.2 Каталог и выдачи | «Каталог», «Все товары», scroll, search idle/results/empty, favorites unavailable | catalog/search/favorites/promotion; согласованная category strip, арт/metadata/card proportions, shared glass controls и полный доступ к спискам |
| D3.3 Товар и розлив | «Описание товара», описание свернуто/раскрыто, added-to-cart | `ProductPage` и живой `ProductDetailPage`; единая hierarchy, варианты/вес/тары видны до главного action, live subtotal/paid/gift/container summary; завершить M2–M4 |
| D3.4 Корзина, оформление, оплата | cart/gift, delivery/pickup scroll 1–3, store sheet, promo/certificate fields, payment pending/error/success | cart/checkout/payment; правильные строки/пакет/бонусы/итоги F1–F8, rounded glass footer поверх контента без clipping и второго total |
| D3.5 Профиль и карты | profile/switches, cards empty/loaded/success, addresses/map/details, certificates filters/forms | активные account pages; единый full-screen layout, meaningful states, keyboard-safe actions и bank identity F6 |
| D3.6 Бонусы, заказы, помощь | history empty/loaded/explainer scroll, order list/detail/status, support/composer keyboard, FAQ error/content, notifications reference | bonus/orders/chat/FAQ/settings; F4/F5/F11 данные и правильные destinations, coherent type/spacing/material |
| D3.7 Вход и onboarding | slides 1–4, phone/code, address/loading/complete | entry/login/profile-setup/onboarding; формы по целому кадру, видимые controls, сохранённое продолжение F1 |

Для конфигуратора/розлива, notification preferences и ряда payment/account состояний нет точного
эквивалентного frame: применить язык целых соседних экранов, пометить capture-only, не заявлять
pixel parity. Figma inbox не является notification settings. Figma delete-card, scheduled delivery,
tips/rating и cross-item gift не создают отсутствующий API: reference сохраняется, несоответствие
явно фиксируется, не вставляется неработающий control или ложная сумма. Official Kaspi visuals
из `docs/kaspi.txt` остаются отдельным обязательным контрактом, не заменяются общей кнопкой.

### D4. Приёмка дизайна

Для каждого семейства просмотреть full PNG пары light/dark на одинаковом content/state; для
динамических полей использовать truthfully matched fixtures или маску только для метрики,
не прятать визуальные дефекты. Ни diff score, ни число component tests не заменяют просмотр.
Проверить foreground/background contrast, реальное glass over moving content, artwork scale,
число/ширину колонок, gutters, scroll anchors, fixed controls и читаемые длинные названия.
Затем 320/800, 1,6×/2× text, resize и 300 px keyboard: no clipping/overlap, все actions доступны.
Каждый видимый control должен пройти actual fixture interaction; disabled/empty/error states
не выдают success. До закрытия второй части — актуальные screenshot пары, route/state evidence,
список действительно отсутствующих backend контрактов и никакой прежней app-wide «DONE».

### D5. Уже выполненное исследование, не приёмка исправлений

- Figma экспорт завершился `rendered 212/212`: **106 полных frames каждой темы**. Проверены
  наличие и размер всех **212 разных PNG: 750×1624**. Версия Figma, source lastModified,
  node IDs и пути записаны в
  `.figma_cache/issue_plan_figma_manifest.json`. Обе коллизии имён сохранены отдельно:
  dark `2093:14635`/`2093:14858`, light `2098:32279`/`2098:32504`.
- Просмотрены **все 36 contact sheets с целыми кадрами без кропа**, плюс отдельные полные
  изображения главной, каталога, товара и акционного оформления. Original PNG остаются
  источником реализации; обзорные sheets не заменяют их. Локальные файлы:
  `.figma_cache/issue_plan_figma_{dark|light}_01…18.png`.
- Собран текущий strict fixture release:
  `flutter build web --release --no-wasm-dry-run -t tool/dev_surface.dart -o .figma_cache/quality_gallery_web`
  — успешно. В Chromium при 375×812/DPR2 просмотрены home light/dark, catalog, actual product
  destination, checkout delivery, cards, bonus history, support и настоящий pour configurator.
  Отдельно выполнен actual wrapper → category переход. Сохранены **10 full viewport baseline PNG**
  `.figma_cache/issue_plan_*_light.png` и `issue_plan_home_dark.png`.
- Это synthetic read-only baseline: без production API/chat запросов, SMS, bank/card/order
  мутаций. Mock cards/balance и missing artwork не доказывают production работу или content parity.
  Full-suite/analysis/native-bank/push/1С проверки в этом исследовании **не запускались**.
  Пользовательская splash registration восстановлена после SDK generation.

Конкретные whole-screen расхождения, определяющие D2/D3:

| Поверхность | Полный Figma кадр | Текущий fixture baseline / работа |
|---|---|---|
| Главная | Компактная строка logo/phone/account, соседние края carousel, единое нижнее glass покрытие; sticky blur при scroll | Иная высота header/промоблока; плавающий cart disc без общего reference покрытия — восстановить целую композицию |
| Каталог | Featured panel с category artwork и заголовком слева, потом 3 узких колонки; selected chip и glass overlays | Featured только с cards, preview в 2 широкие колонки, другая плотность/метаданные — не закрывать разницу поправкой одного padding |
| Товар | Выраженный hero, контрастная информационная зона, цельная quantity surface, rounded glass confirmation над продолжающимся описанием | Другая hierarchy/фон и матовый прямоугольный footer — исправлять слои, не только цвет CTA |
| Оформление | Компактные store/address rows, bonus panel, позднее order summary, общий glass footer с подтверждением | Крупные muted cards/поля и другой footer; визуальные суммы допустимы только из F3/F4/F7, не из скопированных Figma цифр |
| Карты и бонусы | В loaded cards FAQ перед rows; history объединяет balance/help и связывает проводки с заказом | FAQ после cards, отдельный крупный help block, ledger без order context — привести hierarchy после подтверждения данных F4/F6 |

Figma также содержит примеры противоречивого контента: 25% в bonus explainer, разные объёмы
в атрибутах/описании товара, cross-item gift без доказанного API. Это не разрешает вставить
несуществующие данные ради картинки; принять настоящую информацию в reference композиции.


## Внешние prerequisites — точный перечень

| Владелец | Что нужно получить безопасно | Разблокирует |
|---|---|---|
| API/банк | Обезличенный card response для существующей карты в проблемном аккаунте, source/status/ID semantics; failing payment-link response + platform/scheme; sandbox bank lifecycle | F6/F7; реальная банковская приёмка |
| Магазины/каталог/1С | Bag master code `KR-00002264` подтверждён анонимным чтением; store-specific ID/stock/price разрешаются динамически. Осталась authoritative bonus eligibility | F3/F4; fixture SKU/цена не production mapping |
| Loyalty backend | Действующее правило 25% vs 30%, earn rate/base/precision/exclusions/moment; original charge+ledger snapshot; fresh `/bonuses` data | F4; не угадываем бухгалтерское правило |
| 1С + backend | Код существующей return integration или её владелец; sandbox sale/return events, IDs/line amounts, ledger reversals и правила spent-points deficit | F5; фронтенд сам не исправляет ledger |
| Каталог/master data | Weight step/minimum/price basis и фактическое взвешивание, если оно есть; packaging/material/ABV/volume для спорных SKU | F8/F9; не выдумываем граммы/стекло/% |
| Support + push backend | Operator-event recipient mapping/payload, session↔user binding, sandbox subscription/delivery и корректно подписанные Android/iOS app capabilities | F11; локальный socket не заменяет push |

Эти сведения не запрашиваются у пользователя как информация, уже доступная в репозитории.
Недоступные здесь backend/sandbox артефакты — отдельные задачи владельцев с указанной приёмкой;
достижимые клиентские исправления F1/F2/metadata/route/read-state выполняются без ожидания их всех.

## Проверка и доставка после реализации

- До UI-пакета инвентаризировать visible controls, destination, источник и loading/empty/error.
  Исправление бага получает focused consumer regression, который ловит исходный state/денежный
  дефект; никаких source-text/wording-only/widget-type тестов или чрезмерной layout матрицы.
- После стабилизации исходников: focused tests, `flutter test --coverage --concurrency=1`,
  `flutter test integration_test/shopping_e2e_test.dart -d windows --concurrency=1`,
  `dart analyze lib test integration_test tool`. Тесты запускать последовательно.
- Actual strict fixture journeys + full-screen screenshots и sandbox-only bank/push/1С acceptance.
  Непокрытый внешний этап явно незакрыт; fixture card не является доказательством production cards.
- Собрать fixture release и затем tracked release `flutter build web --release --no-wasm-dry-run`,
  smoke safe entry at 375×812/DPR2. Не повторять debug Chrome DDC без соответствующего изменения.
  Сохранить пользовательскую splash registration при Flutter generation.
- Обновить `STATUS.md`/`FIDELITY.md` только новой наблюдаемой приёмкой, удалить probes, закрыть
  только собственные tabs/services. Выполненные команды и границы приёмки записываются отдельно;
  успешные fixtures не закрывают реальный банк, 1С, loyalty policy или push delivery.
