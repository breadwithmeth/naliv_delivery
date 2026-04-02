class ItemNameCountryRule {
  final String label;
  final String flag;
  final List<String> aliases;

  const ItemNameCountryRule({
    required this.label,
    required this.flag,
    required this.aliases,
  });
}

const List<ItemNameCountryRule> kItemNameCountryRules = <ItemNameCountryRule>[
  ItemNameCountryRule(label: 'США', flag: '🇺🇸', aliases: <String>['сша', 'usa', 'u.s.a.', 'соединенные штаты', 'соединённые штаты']),
  ItemNameCountryRule(label: 'Испания', flag: '🇪🇸', aliases: <String>['испания', 'spain']),
  ItemNameCountryRule(label: 'Италия', flag: '🇮🇹', aliases: <String>['италия', 'italy']),
  ItemNameCountryRule(label: 'Чехия', flag: '🇨🇿', aliases: <String>['чехия', 'czech', 'czech republic', 'чешская республика']),
  ItemNameCountryRule(label: 'Франция', flag: '🇫🇷', aliases: <String>['франция', 'france']),
  ItemNameCountryRule(label: 'Германия', flag: '🇩🇪', aliases: <String>['германия', 'germany']),
  ItemNameCountryRule(label: 'Бельгия', flag: '🇧🇪', aliases: <String>['бельгия', 'belgium']),
  ItemNameCountryRule(label: 'Ирландия', flag: '🇮🇪', aliases: <String>['ирландия', 'ireland']),
  ItemNameCountryRule(label: 'Шотландия', flag: '🏴', aliases: <String>['шотландия', 'scotland']),
  ItemNameCountryRule(label: 'Англия', flag: '🏴', aliases: <String>['англия', 'england']),
  ItemNameCountryRule(
      label: 'Великобритания', flag: '🇬🇧', aliases: <String>['великобритания', 'британия', 'uk', 'united kingdom', 'great britain']),
  ItemNameCountryRule(label: 'Нидерланды', flag: '🇳🇱', aliases: <String>['нидерланды', 'голландия', 'netherlands', 'holland']),
  ItemNameCountryRule(label: 'Мексика', flag: '🇲🇽', aliases: <String>['мексика', 'mexico']),
  ItemNameCountryRule(label: 'Япония', flag: '🇯🇵', aliases: <String>['япония', 'japan']),
  ItemNameCountryRule(label: 'Китай', flag: '🇨🇳', aliases: <String>['китай', 'china']),
  ItemNameCountryRule(label: 'Южная Корея', flag: '🇰🇷', aliases: <String>['южная корея', 'корея', 'south korea', 'korea']),
  ItemNameCountryRule(label: 'Сербия', flag: '🇷🇸', aliases: <String>['сербия', 'serbia']),
  ItemNameCountryRule(label: 'Грузия', flag: '🇬🇪', aliases: <String>['грузия', 'georgia']),
  ItemNameCountryRule(label: 'Армения', flag: '🇦🇲', aliases: <String>['армения', 'armenia']),
  ItemNameCountryRule(label: 'Казахстан', flag: '🇰🇿', aliases: <String>['казахстан', 'kazakhstan']),
  ItemNameCountryRule(label: 'Россия', flag: '🇷🇺', aliases: <String>['россия', 'russia']),
  ItemNameCountryRule(label: 'Беларусь', flag: '🇧🇾', aliases: <String>['беларусь', 'belarus']),
  ItemNameCountryRule(label: 'Украина', flag: '🇺🇦', aliases: <String>['украина', 'ukraine']),
  ItemNameCountryRule(label: 'Польша', flag: '🇵🇱', aliases: <String>['польша', 'poland']),
  ItemNameCountryRule(label: 'Литва', flag: '🇱🇹', aliases: <String>['литва', 'lithuania']),
  ItemNameCountryRule(label: 'Латвия', flag: '🇱🇻', aliases: <String>['латвия', 'latvia']),
  ItemNameCountryRule(label: 'Эстония', flag: '🇪🇪', aliases: <String>['эстония', 'estonia']),
  ItemNameCountryRule(label: 'Австрия', flag: '🇦🇹', aliases: <String>['австрия', 'austria']),
  ItemNameCountryRule(label: 'Португалия', flag: '🇵🇹', aliases: <String>['португалия', 'portugal']),
  ItemNameCountryRule(label: 'Чили', flag: '🇨🇱', aliases: <String>['чили', 'chile']),
  ItemNameCountryRule(label: 'Аргентина', flag: '🇦🇷', aliases: <String>['аргентина', 'argentina']),
  ItemNameCountryRule(label: 'Австралия', flag: '🇦🇺', aliases: <String>['австралия', 'australia']),
  ItemNameCountryRule(label: 'Новая Зеландия', flag: '🇳🇿', aliases: <String>['новая зеландия', 'new zealand']),
  ItemNameCountryRule(label: 'Дания', flag: '🇩🇰', aliases: <String>['дания', 'denmark']),
  ItemNameCountryRule(label: 'Финляндия', flag: '🇫🇮', aliases: <String>['финляндия', 'finland']),
  ItemNameCountryRule(label: 'Швеция', flag: '🇸🇪', aliases: <String>['швеция', 'sweden']),
  ItemNameCountryRule(label: 'Норвегия', flag: '🇳🇴', aliases: <String>['норвегия', 'norway']),
  ItemNameCountryRule(label: 'Турция', flag: '🇹🇷', aliases: <String>['турция', 'turkey']),
];
