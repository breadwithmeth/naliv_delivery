import 'package:flutter/material.dart';

import '../shared/app_theme.dart';
import '../utils/responsive.dart';

enum FaqSection {
  profile(1, Icons.person_rounded),
  payment(2, Icons.credit_card_rounded),
  delivery(3, Icons.local_shipping_rounded),
  age(4, Icons.verified_user_rounded),
  bonuses(5, Icons.stars_rounded),
  orderChanges(6, Icons.inventory_2_rounded),
  orderProblems(7, Icons.support_agent_rounded);

  const FaqSection(this.number, this.icon);

  final int number;
  final IconData icon;

  static FaqSection? fromNumber(int? number) {
    if (number == null) return null;
    for (final section in values) {
      if (section.number == number) return section;
    }
    return null;
  }
}

class FaqEntry {
  const FaqEntry({
    required this.number,
    required this.question,
    required this.answer,
  });

  final int number;
  final String question;
  final String answer;
}

class FaqSectionData {
  const FaqSectionData({
    required this.number,
    required this.title,
    required this.entries,
  });

  final int number;
  final String title;
  final List<FaqEntry> entries;

  FaqSection? get key => FaqSection.fromNumber(number);

  FaqSectionData copyWith({
    String? title,
    List<FaqEntry>? entries,
  }) {
    return FaqSectionData(
      number: number,
      title: title ?? this.title,
      entries: entries ?? this.entries,
    );
  }
}

class FaqRepository {
  static String normalizeForSearch(String value) {
    return _normalizeWhitespace(value.toLowerCase().replaceAll('ё', 'е'));
  }

  static String _normalizeWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const sections = <FaqSectionData>[
    FaqSectionData(
      number: 1,
      title: 'Авторизация, Профиль и Сбои приложения',
      entries: [
        FaqEntry(
          number: 1,
          question: 'Не приходит SMS-код для входа в приложение. Что делать?',
          answer:
              'Убедитесь, что на указанном номере установлено приложение WhatsApp. Убедитесь, что номер введен без ошибок. Если код не приходит в течение 2 минут, перезагрузите устройство. Если проблема сохраняется, напишите в техподдержку.',
        ),
        FaqEntry(
          number: 2,
          question: 'Как привязать банковскую карту в профиле?',
          answer:
              'Зайдите в «Профиль» - «Карты». Чтобы привязать карту, нажмите «Добавить новую карту», введите реквизиты и подтвердите тестовое списание (сумма вернется сразу).',
        ),
        FaqEntry(
          number: 3,
          question:
              'Почему приложение пишет «Доступ заблокирован» при авторизации?',
          answer:
              'Блокировка профиля происходит автоматически при нарушении условий Пользовательского соглашения (например, при частых необоснованных отменах заказов, агрессивном поведении в отношении курьеров или подозрений во фроде). Для выяснения деталей обратитесь в службу поддержки.',
        ),
        FaqEntry(
          number: 4,
          question:
              'Приложение не может определить мой адрес по GPS. Как ввести его вручную?',
          answer:
              'Разрешите приложению доступ к геолокации в настройках вашего смартфона. Если точка на карте отображается некорректно, нажмите на строку адреса вверху экрана корзины и введите город, улицу и номер дома вручную, выбрав нужный вариант из выпадающего списка подсказок.',
        ),
        FaqEntry(
          number: 5,
          question:
              'Что делать, если в приложении произошел сбой, деньги списались, а заказ пропал из истории?',
          answer:
              'Не паникуйте, система фиксирует все транзакции. Нажмите кнопку «Связаться с техподдержкой» и отправьте скриншот чека о списании из банковского приложения. Оператор вручную восстановит ваш заказ или инициирует возврат средств.',
        ),
      ],
    ),
    FaqSectionData(
      number: 2,
      title: 'Оплата, Удаленные счета и Расчет стоимости',
      entries: [
        FaqEntry(
          number: 7,
          question: 'Как оплатить заказ через удаленный счет Kaspi или Halyk?',
          answer:
              'При оформлении заказа выберите способ оплаты «Удаленный счет» и укажите банк. После сборки заказа вам в приложение Kaspi или Halyk придет уведомление о вы выставленном счете. Оплатите его в течение 10 минут, чтобы заказ автоматически передали курьеру.',
        ),
        FaqEntry(
          number: 8,
          question:
              'Почему в корзине была одна сумма за весовой товар (рыбу/снэки), а списалось больше?',
          answer:
              'Согласно п. 6.3 Пользовательского соглашения, стоимость весовых товаров в каталоге является предварительной. Окончательный расчет производится автоматической системой строго после фактического взвешивания товара комплектовщиком заказа.',
        ),
        FaqEntry(
          number: 9,
          question:
              'Мне не приходит удаленный счет на оплату в приложение банка. Как его получить?',
          answer:
              'Убедитесь, что номер телефона в приложении совпадает с номером, к которому привязан ваш банк. Счёт выставляется только после того, как комплектовщик полностью соберет и взвесит ваш заказ..',
        ),
        FaqEntry(
          number: 10,
          question:
              'Что делать, если при попытке оплатить удаленный счет возникает ошибка?',
          answer:
              'Проверьте наличие достаточной суммы на карте и лимиты на интернет-оплату в приложении вашего банка. Если лимиты в порядке, отмените текущий счет в корзине и запросите его повторно, либо выберите карту другого банка.',
        ),
        FaqEntry(
          number: 11,
          question: 'Можно ли оплатить заказ картой через терминал при получении?',
          answer:
              'Нет, курьеры не возят с собой переносные банковские терминалы. Все безналичные платежи осуществляются безопасно и бесконтактно прямо внутри приложения или через удаленные счета Kaspi/Halyk.',
        ),
        FaqEntry(
          number: 12,
          question:
              'Когда именно списываются деньги: в момент нажатия кнопки «Заказать» или после сборки?',
          answer:
              'При оплате картой в приложении сумма холдируется (замораживается) в момент заказа. Окончательное списание происходит только после сборки и взвешивания всех позиций. При оплате удаленным счетом деньги списываются в момент вашего подтверждения в приложении банка.',
        ),
      ],
    ),
    FaqSectionData(
      number: 3,
      title: 'Ограничения, Районы и Скорость доставки',
      entries: [
        FaqEntry(
          number: 15,
          question: 'Какая минимальная сумма заказа установлена для моего адреса?',
          answer:
              'Минимальная сумма заказа рассчитывается автоматически в корзине и зависит от удаленности вашего адреса от ближайшего маркет-бара. В среднем по городу минимальный чек для активации доставки составляет от 3 000 тенге.',
        ),
        FaqEntry(
          number: 16,
          question: 'Через сколько минут приедет курьер после оплаты счета?',
          answer:
              'Среднее время экспресс-доставки составляет 35 – 40 минут с момента подтверждения оплаты.',
        ),
        FaqEntry(
          number: 17,
          question: 'Почему доставка задерживается?',
          answer:
              'Согласно п. 10.1 оферты, среднее время доставки является ориентировочным. При заказе необходимо учитывать дорожные заторы, погодные условия и количество свободных курьеров на линии в вашем районе.',
        ),
        FaqEntry(
          number: 18,
          question:
              'Можно ли оформить предзаказ к определенному времени (например, на вечер)?',
          answer:
              'Да. При оформлении заказа в блоке «Когда доставить» переключите выбор с «Сейчас» на «Запланировать» и выберите нужный часовой интервал. Заказ будет собран и отправлен строго под указанное время.',
        ),
        FaqEntry(
          number: 19,
          question:
              'Можно ли отследить местоположение курьера на карте в режиме реального времени?',
          answer:
              'Да, в ночное время трекинг курьера доступен прямо в приложении во вкладке активного заказа. В дневное время при доставке через Яндекс вам придет SMS со ссылкой на карту отслеживания курьера.',
        ),
      ],
    ),
    FaqSectionData(
      number: 4,
      title: 'Возрастной контроль и Вскрытие продукции (Закон и Оферта)',
      entries: [
        FaqEntry(
          number: 22,
          question:
              'Почему приложение запрашивает подтверждение возраста (18+) при входе?',
          answer:
              'Согласно законодательству Республики Казахстан и п. 1.1 нашей оферты, наш сервис предназначен строго для лиц, достигших 18 лет, так как в каталоге присутствуют товары с возрастными ограничениями.',
        ),
        FaqEntry(
          number: 23,
          question:
              'Какие документы подходят для подтверждения совершеннолетия курьеру?',
          answer:
              'Только оригиналы государственных документов с фотографией: удостоверение личности гражданина РК, паспорт, либо водительское удостоверение. Фотографии документов с телефона или цифровые копии курьером не принимаются.',
        ),
        FaqEntry(
          number: 24,
          question:
              'Почему курьер вскрывает крышки/пробки на алкоголе при доставке в ночное время?',
          answer:
              'Наш сервис работает в формате бар-маркета. Согласно закону РК, реализация алкогольной продукции в ночное время разрешена только заведениям общественного питания на вынос, что юридически требует вскрытия тары при продаже.',
        ),
        FaqEntry(
          number: 25,
          question:
              'Можно ли отказаться от вскрытия алкогольной продукции курьером при получении?',
          answer:
              'Нет, в ночное время это обязательное условие продажи. В случае категорического отказа клиента от вскрытия бутылок курьер обязан аннулировать заказ и вернуть товар на склад. При этом стоимость доставки не возвращается.',
        ),
        FaqEntry(
          number: 26,
          question:
              'Можно ли заказать алкоголь или табак в подарок другому человеку на его адрес?',
          answer:
              'Можно, но получатель на адресе обязан быть старше 21 года. Курьер передаст заказ только после личной проверки оригинала удостоверения личности получателя. Если получатель не достиг 21 года, заказ будет аннулирован.',
        ),
        FaqEntry(
          number: 27,
          question:
              'Что произойдет с оплаченным заказом, если курьер откажет в выдаче из-за отсутствия документов?',
          answer:
              'Согласно п. 12.2 оферты, товар возвращается на склад. Стоимость товаров будет возвращена вам на карту, но из неё автоматически удержится стоимость доставки и разливных напитков.',
        ),
      ],
    ),
    FaqSectionData(
      number: 5,
      title: 'Бонусы, Промокоды и Акции (1+1, 2+1, 3+1)',
      entries: [
        FaqEntry(
          number: 28,
          question:
              'Как начисляется кешбэк и как работает программа лояльности в приложении?',
          answer:
              'С каждого выполненного заказа вам начисляются Бонусы Продавца в размере % от суммы покупки (указан в карточке товара). 1 бонус = 1 тенге. Бонусами можно оплачивать до 25% от стоимости последующих заказов (за исключением доставки и табачной продукции).',
        ),
        FaqEntry(
          number: 29,
          question:
              'Можно ли списать накопленные Бонусы Продавца без использования приложения (например, через оператора)?',
          answer:
              'Нет. Согласно п. 12.5 Пользовательского соглашения, управление бонусным балансом, их начисление и списание происходят в автоматическом режиме и строго внутри мобильного приложения при оформлении корзины.',
        ),
        FaqEntry(
          number: 30,
          question:
              'Можно ли оплатить один заказ бонусами и удаленным счетом одновременно?',
          answer:
              'Да. В корзине найдите раздел «Бонусы» и нажмите кнопку. Спишется максимальное количество бонусов, но не более 25% от стоимости товаров в корзине. Оставшаяся часть суммы за товары и доставка будут сформированы в удаленный счет для оплаты через банк.',
        ),
        FaqEntry(
          number: 31,
          question: 'Как активировать промокод в корзине и почему он может не сработать?',
          answer:
              'Скопируйте промокод, введите его в поле «Промокод» в корзине и нажмите «ОК». Он может не сработать, если: истек срок действия, не набрана минимальная сумма товаров для акции, данный промокод не распространяется на товары в вашей корзине или уже был использован вами ранее.',
        ),
        FaqEntry(
          number: 32,
          question:
              'Как технически работает акция «1+1 / 2+1 / 3+1» (как добавить бесплатный товар в корзину)?',
          answer:
              'Чтобы акция сработала, вам необходимо добавить в корзину полное количество товаров, участвующих в акции (например, для акции 2+1 нужно положить в корзину 3 бутылки). Система автоматически пересчитает стоимость, и цена третьей позиции станет равной 0 тенге.',
        ),
        FaqEntry(
          number: 33,
          question: 'Можно ли объединить списание бонусов и промокодов в одном заказе?',
          answer:
              'По правилам нашей платформы списание скидки по промокоду и накопленных бонусов в корзине суммируются. К одному заказу можно применить либо один промокод, либо списание бонусов.',
        ),
        FaqEntry(
          number: 34,
          question:
              'Почему акция отображается на баннере, но автоматически не применилась к моей корзине?',
          answer:
              'Проверьте условия акции, нажав на баннер. Скорее всего, в вашей корзине не выполнены обязательные требования: не достигнута минимальная сумма акционных товаров, либо вы добавили позиции, на которые действие этой акции не распространяется.',
        ),
      ],
    ),
    FaqSectionData(
      number: 6,
      title: 'Изменение, Комплектация и Отмена заказов',
      entries: [
        FaqEntry(
          number: 36,
          question:
              'Почему товар отображался в приложении как «В наличии», но после оплаты его не оказалось?',
          answer:
              'Остатки на складе обновляются с краткой задержкой. Если в пиковые часы несколько клиентов одновременно купят одну и ту же позицию, может возникнуть пересорт. В этом случае вам сразу предложат замену или оформят возврат денег.',
        ),
        FaqEntry(
          number: 37,
          question: 'Как работает функция автоматической замены отсутствующего товара на складе?',
          answer:
              'Если при сборке позиции не оказалось, а у вас включена «Автозамена»,             комплектовщик подберет максимально похожий товар по той же цене. Если автозамена выключена, система уберет позицию из чека, а деньги за неё автоматически вернутся на карту.',
        ),
        FaqEntry(
          number: 38,
          question:
              'Как добавить пустую тару (пластиковые бутылки/пакеты) в заказ, если я беру разливные напитки?',
          answer:
              'Вам не нужно добавлять тару вручную. При выборе разливных напитков в каталоге, стоимость необходимого количества ПЭТ-бутылок соответствующего объема уже автоматически включена системой в итоговую стоимость позиции.',
        ),
        FaqEntry(
          number: 39,
          question:
              'Как отменить заказ после его оплаты и в течение какого времени это можно сделать?',
          answer:
              'Согласно п. 4.1 и 4.3 оферты, отмена заказа с возвратом средств невозможна, если комплектовщик уже начал сборку скоропортящихся продуктов или разливных напитков. Если заказ еще не перешел в статус «Сборка», вы можете отменить его кнопкой в приложении.',
        ),
        FaqEntry(
          number: 40,
          question:
              'За что система может аннулировать мой заказ в автоматическом режиме (Правило ожидания 5 минут)?',
          answer:
              'Согласно п. 8.4 оферты, если курьер прибыл на адрес, ожидал вас более 5 минут и совершил не менее 2 звонков, на которые вы не ответили, заказ аннулируется. Деньги за разливные напитки и доставку в данном случае не возвращаются.',
        ),
      ],
    ),
    FaqSectionData(
      number: 7,
      title: 'Проблемы с заказом, Жалобы и Возврат денег',
      entries: [
        FaqEntry(
          number: 41,
          question: 'Что делать и куда обращаться, если курьер задерживается или не доставил заказ?',
          answer:
              'Откройте статус заказа в приложении. Если расчетное время вышло, нажмите кнопку «Связаться с техподдержкой» (или позвоните по номеру КЦ). Оператор мгновенно свяжется с курьером, выяснит его точное местоположение и сориентирует вас.',
        ),
        FaqEntry(
          number: 42,
          question:
              'В заказе не хватает позиций или привезли не тот товар. Каков алгоритм действий?',
          answer:
              'Согласно п. 13.2 оферты, сделайте фотографию доставленного заказа вместе с бумажным чеком и отправьте её в чат техподдержки приложения. Мы оперативно проведем проверку по камерам сборки и либо бесплатно довезем товар, либо вернем за него деньги.',
        ),
        FaqEntry(
          number: 43,
          question:
              'Что делать, если товар или его упаковка были повреждены в процессе транспортировки?',
          answer:
              'Сфотографируйте поврежденный товар в руках у курьера или сразу после получения и отправьте фото в чат поддержки. Мы зафиксируем порчу по вине службы доставки, аннулируем стоимость позиции и вернем деньги на ваш счет.',
        ),
        FaqEntry(
          number: 44,
          question:
              'Можно ли вернуть алкоголь, сигареты или разливное пиво обратно, если товар надлежащего качества?',
          answer:
              'Согласно Закону о защите прав потребителей РК и п. 4.2 нашей оферты, продукты питания, бытовая химия, алкогольная, табачная продукция и разливные напитки надлежащего качества возврату и обмену не подлежат.',
        ),
        FaqEntry(
          number: 45,
          question:
              'Что делать, если разливной напиток оказался ненадлежащего качества (осадок, хлопья, странный вкус)?',
          answer:
              'Срочно прекратите употребление, сделайте фото/видео дефекта (осадка) и напишите в поддержку. Мы снимем партию с продажи для проверки качества, а вам оформим полный возврат средств или замену на другую позицию.',
        ),
        FaqEntry(
          number: 46,
          question:
              'В каких случаях по закону и оферте возможен полный возврат денег за заказ?',
          answer:
              'Полный возврат возможен, если: заказ был отменен до начала его сборки; товар оказался ненадлежащего качества (испорчен); произошла ошибочная переплата; или маркет-бар не смог укомплектовать и отправить ваш заказ по техническим причинам.',
        ),
        FaqEntry(
          number: 47,
          question: 'Сколько времени занимает процедура возврата денег банком на карту Kaspi/Halyk?',
          answer:
              'С нашей стороны отмена и возврат производятся мгновенно. Далее скорость зависит от вашего банка. На карты Kaspi Gold деньги обычно возвращаются в течение от нескольких минут до 3-5 рабочих дней. На карты других банков — до 14 рабочих дней.',
        ),
        FaqEntry(
          number: 48,
          question:
              'Что делать, если техподдержка одобрила возврат, но деньги так и не поступили на карту?',
          answer:
              'Проверьте выписку по карте в банковском приложении за весь период с даты заказа (иногда банки отображают возврат не новым поступлением, а корректировкой старого списания). Если денег нет, напишите в чат поддержки, и мы предоставим вам ARN-код транзакции для вашего банка.',
        ),
        FaqEntry(
          number: 49,
          question: 'Как быстро связаться с живым оператором службы поддержки (контакты КЦ)?',
          answer:
              'Если виртуальный гид не смог решить вашу проблему, нажмите кнопку «Перевести на оператора» внизу экрана, либо позвоните по горячей линии службы поддержки: +77719290003(для Павлодара), +77719290005(для Караганды и Темиртау), +77719291001(для Астаны) или напишите напрямую на наш рабочий WhatsApp +77025834895. Мы работаем для вас 24/7!',
        ),
      ],
    ),
  ];
}

class FaqSearchDocument {
  const FaqSearchDocument({
    required this.section,
    required this.entry,
    required this.searchableText,
  });

  final FaqSectionData section;
  final FaqEntry entry;
  final String searchableText;

  static List<FaqSearchDocument> build(List<FaqSectionData> sections) {
    return [
      for (final section in sections)
        for (final entry in section.entries)
          FaqSearchDocument(
            section: section,
            entry: entry,
            searchableText: FaqRepository.normalizeForSearch(
              '${section.title} ${entry.question} ${entry.answer}',
            ),
          ),
    ];
  }
}

Future<void> openFaqPage(
  BuildContext context, {
  FaqSection? initialSection,
}) {
  return Navigator.of(context).pushNamed(
    FaqPage.routeName,
    arguments: initialSection,
  );
}

class FaqShortcutCard extends StatelessWidget {
  const FaqShortcutCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.initialSection,
    this.icon = Icons.help_center_rounded,
    this.actionLabel = 'Открыть FAQ',
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final FaqSection? initialSection;
  final IconData icon;
  final String actionLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return InkWell(
        onTap: () => openFaqPage(
          context,
          initialSection: initialSection,
        ),
        borderRadius: BorderRadius.circular(14.s),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 10.s),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14.s),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 30.s,
                height: 30.s,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.orange, size: 16.s),
              ),
              SizedBox(width: 9.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2.s),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMute,
                        fontSize: 11.sp,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.s),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMute.withValues(alpha: 0.8),
                size: 18.s,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.s),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.s),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.s,
            height: 40.s,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.orange, size: 21.s),
          ),
          SizedBox(width: 10.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.s),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textMute,
                    fontSize: 12.sp,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10.s),
                TextButton.icon(
                  onPressed: () => openFaqPage(
                    context,
                    initialSection: initialSection,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(actionLabel),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.orange,
                    padding: EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 4.s,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FaqPage extends StatefulWidget {
  static const routeName = '/faq';

  const FaqPage({
    super.key,
    this.initialSection,
  });

  final FaqSection? initialSection;

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  late FaqSection? _selectedSection;
  late final TextEditingController _searchController;
  late final ScrollController _categoryController;
  late final List<FaqSearchDocument> _searchIndex;
  String _searchQuery = '';
  String _normalizedSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialSection;
    _searchController = TextEditingController();
    _categoryController = ScrollController();
    _searchIndex = FaqSearchDocument.build(FaqRepository.sections);
    if (_selectedSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollCategoryIntoView(_selectedSection);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const allSections = FaqRepository.sections;
    final filteredSections = _filteredSections(allSections);
    final visibleAnswers = _countAnswers(filteredSections);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        title: const Text(
          'FAQ',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16.s, 8.s, 16.s, 24.s),
              children: [
                _searchField(),
                SizedBox(height: 12.s),
                _categoryRail(allSections),
                SizedBox(height: 18.s),
                _resultsHeader(allSections, visibleAnswers),
                SizedBox(height: 12.s),
                if (filteredSections.isEmpty)
                  _emptyState(allSections)
                else ...[
                  for (final section in filteredSections) _sectionBlock(section),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<FaqSectionData> _filteredSections(List<FaqSectionData> sections) {
    final selected = _selectedSection;
    final query = _normalizedSearchQuery;

    if (query.isEmpty) {
      if (selected == null) return sections;
      return sections
          .where((section) => section.key == selected)
          .toList(growable: false);
    }

    final entriesBySection = <int, List<FaqEntry>>{};
    for (final document in _searchIndex) {
      if (selected != null && document.section.key != selected) continue;
      if (!document.searchableText.contains(query)) continue;
      entriesBySection
          .putIfAbsent(document.section.number, () => <FaqEntry>[])
          .add(document.entry);
    }

    return sections
        .where((section) => entriesBySection.containsKey(section.number))
        .map(
          (section) => section.copyWith(
            entries: entriesBySection[section.number]!,
          ),
        )
        .toList(growable: false);
  }

  int _countAnswers(List<FaqSectionData> sections) {
    return sections.fold<int>(
      0,
      (sum, section) => sum + section.entries.length,
    );
  }

  Widget _searchField() {
    return Container(
      height: 52.s,
      padding: EdgeInsets.symmetric(horizontal: 14.s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16.s),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: Icon(
            Icons.search_rounded,
            color: AppColors.textMute.withValues(alpha: 0.9),
            size: 20.s,
          ),
          hintText: 'Найти вопрос или ответ',
          hintStyle: TextStyle(
            color: AppColors.textMute.withValues(alpha: 0.8),
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textMute,
                    size: 18.s,
                  ),
                ),
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _normalizedSearchQuery = FaqRepository.normalizeForSearch(value);
    });
  }

  Widget _categoryRail(List<FaqSectionData> sections) {
    final allCount = _countAnswers(sections);

    return SizedBox(
      height: 70.s,
      child: ListView.separated(
        controller: _categoryController,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: sections.length + 1,
        separatorBuilder: (_, __) => SizedBox(width: 8.s),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _categoryTab(
              label: 'Все',
              count: allCount,
              icon: Icons.apps_rounded,
              selected: _selectedSection == null,
              width: 98.s,
              onTap: () {
                setState(() => _selectedSection = null);
                _scrollCategoryIntoView(null);
              },
            );
          }

          final section = sections[index - 1];
          return _categoryTab(
            label: section.title,
            count: section.entries.length,
            icon: section.key?.icon ?? Icons.help_outline_rounded,
            selected: _selectedSection == section.key,
            width: 222.s,
            onTap: () {
              setState(() => _selectedSection = section.key);
              _scrollCategoryIntoView(section.key);
            },
          );
        },
      ),
    );
  }

  Widget _categoryTab({
    required String label,
    required int count,
    required IconData icon,
    required bool selected,
    required double width,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.s),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: width,
          padding: EdgeInsets.all(12.s),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.orange
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14.s),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 16.s,
                color: selected ? Colors.black : AppColors.text,
              ),
              SizedBox(width: 7.s),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.black : AppColors.text,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              SizedBox(width: 7.s),
              Text(
                '$count',
                style: TextStyle(
                  color: selected
                      ? Colors.black.withValues(alpha: 0.7)
                      : AppColors.textMute,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultsHeader(List<FaqSectionData> allSections, int visibleAnswers) {
    final hasSearch = _searchQuery.trim().isNotEmpty;
    final selectedTitle = _selectedSectionTitle(allSections);

    String text;
    if (hasSearch) {
      text = 'Найдено $visibleAnswers ответов';
      if (selectedTitle != null) {
        text += ' в разделе «$selectedTitle»';
      }
    } else if (selectedTitle != null) {
      text = selectedTitle;
    } else {
      text = '$visibleAnswers ответов';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textMute,
              fontSize: 11.sp,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (_selectedSection != null || hasSearch) ...[
          SizedBox(width: 10.s),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _selectedSection = null;
                _searchQuery = '';
                _normalizedSearchQuery = '';
              });
              _scrollCategoryIntoView(null);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.orange,
              padding: EdgeInsets.symmetric(horizontal: 8.s, vertical: 4.s),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Сбросить',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _scrollCategoryIntoView(FaqSection? section) {
    if (!_categoryController.hasClients) return;

    final index = section == null
        ? 0
        : FaqRepository.sections.indexWhere((entry) => entry.key == section) + 1;
    if (index < 0) return;

    final offset = index == 0 ? 0.0 : 98.s + 8.s + ((index - 1) * (222.s + 8.s));
    _categoryController.animateTo(
      offset.clamp(0.0, _categoryController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  String _sectionRangeLabel(FaqSectionData section) {
    final first = section.entries.first.number;
    final last = section.entries.last.number;
    return first == last ? '$first' : '$first-$last';
  }

  Widget _sectionMeta(FaqSectionData section) {
    return Text(
      '${section.entries.length} ответов • вопросы ${_sectionRangeLabel(section)}',
      style: TextStyle(
        color: AppColors.textMute,
        fontSize: 11.sp,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  String? _selectedSectionTitle(List<FaqSectionData> sections) {
    final selected = _selectedSection;
    if (selected == null) return null;
    for (final section in sections) {
      if (section.key == selected) return section.title;
    }
    return null;
  }

  Widget _sectionBlock(FaqSectionData section) {
    final key = section.key;

    return Padding(
      padding: EdgeInsets.only(bottom: 18.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34.s,
                height: 34.s,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  key?.icon ?? Icons.help_outline_rounded,
                  color: AppColors.orange,
                  size: 18.s,
                ),
              ),
              SizedBox(width: 10.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 4.s),
                    _sectionMeta(section),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.s),
          ClipRRect(
            borderRadius: BorderRadius.circular(20.s),
            child: ColoredBox(
              color: AppColors.cardDark.withValues(alpha: 0.92),
              child: Column(
                children: [
                  for (var i = 0; i < section.entries.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    _questionTile(section.entries[i]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionTile(FaqEntry entry) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.fromLTRB(14.s, 4.s, 10.s, 4.s),
        childrenPadding: EdgeInsets.fromLTRB(14.s, 0, 14.s, 16.s),
        iconColor: AppColors.orange,
        collapsedIconColor: AppColors.textMute,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${entry.number}.',
              style: TextStyle(
                color: AppColors.orange,
                fontSize: 12.sp,
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
            SizedBox(width: 7.s),
            Expanded(
              child: Text(
                entry.question,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              entry.answer,
              style: TextStyle(
                color: AppColors.textMute,
                fontSize: 12.sp,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(List<FaqSectionData> allSections) {
    final selectedTitle = _selectedSectionTitle(allSections);
    final label = selectedTitle == null ? 'этом FAQ' : 'разделе «$selectedTitle»';

    return Container(
      padding: EdgeInsets.all(18.s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20.s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ничего не найдено',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 15.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6.s),
          Text(
            'Совпадений нет в $label. Измените запрос или сбросьте фильтр.',
            style: TextStyle(
              color: AppColors.textMute,
              fontSize: 12.sp,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
