import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:naliv_delivery/globals.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/databaseapi.dart';
import 'package:naliv_delivery/pages/addNewCardPage.dart';
import 'package:naliv_delivery/pages/orderProcessingPage.dart';
import 'package:naliv_delivery/pages/paymentMethods.dart';
import 'package:naliv_delivery/pages/selectAddressPage.dart';
import 'package:naliv_delivery/shared/ItemCard2.dart';
import 'package:naliv_delivery/shared/changeAmountButton.dart';
import 'package:naliv_delivery/shared/openMainPageButton.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:math';

class CreateOrderPage2 extends StatefulWidget {
  const CreateOrderPage2({
    super.key,
    required this.business,
    required this.currentAddress,
    required this.addresses,
  });
  final Map<dynamic, dynamic> business;
  final Map currentAddress;
  final List addresses;
  @override
  State<CreateOrderPage2> createState() => _CreateOrderPage2State();
}

class _CreateOrderPage2State extends State<CreateOrderPage2> {
  DatabaseManager dbm = DatabaseManager();
  List items = [];
  double sum = 0;
  double sum2 = 0;

  int discount = 0;
  int deliveryPrice = 0;
  bool delivery = true;
  bool createButtonEnabled = true;
  bool useBonuses = false;
  int bonuses = 0;
  bool bonusesAvailabale = false;
  bool recPopulated = false;
  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  List cards = [];
  String? _selectedCard = null;

  void _getSavedCards() async {
    await getSavedCards().then((v) {
      setState(() {
        cards = v;
      });
    });
  }

  _getBonuses() {
    getBonuses().then((v) {
      //print("============");
      //print(v);
      setState(() {
        bonuses = int.parse(v["amount"]);
        bonusesAvailabale = v["use_bonuses"] == "1" ? true : false;
      });
    });
  }

  getCartItems() async {
    await dbm
        .getAllItemsInCart(int.parse(widget.business["business_id"]))
        .then((v) {
      //print(v);
      List _items = [];
      v.forEach((e) {
        _items.add(Map.from(e));
      });
      setState(() {
        items.clear();
        items = _items;
        ;
      });
    }).then((items_t) {
      _getItemsRescByItems();
      _getCartPrice();
      // getTotalCartPrice(items);
    });
  }

  Function? update() {
    // getCartItems();
  }

  _getDeliveryPrice() async {
    await getDeliveyPrice(widget.business["business_id"]).then((v) {
      setState(() {
        deliveryPrice = double.parse(v["price"]).toInt();
      });
    });
  }

  String extra = "";

  _createOrder() {
    setState(() {
      extra = "По заменам и возвратам:\n";
      for (var item in itemsForReplacements) {
        // Используем оператор ?? для установки значения по умолчанию
        final isReplaceAllowed = item['replace'] ?? true;

        extra +=
            "${item['name']} - ${isReplaceAllowed ? 'Разрешена замена' : 'Вернуть деньги за данную позицию'}\n";
      }
      extra += "\n\n${_message.text}";
    });

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => OrderProcessingPage(
          business: widget.business,
          delivery: delivery,
          selectedCard: _selectedCard!,
          items: items,
          useBonuses: useBonuses,
          extra: extra,
        ),
      ),
    );
  }

  // Добавьте новое поле класса для хранения максимальной суммы бонусов
  double maxBonusesAllowed = 0;

  Future<void> _getCartPrice() async {
    try {
      if (items.isEmpty) return; // Добавляем проверку на пустую корзину

      //print("Начало расчета цены корзины");
      //print("Товары: ${items.toString()}");

      final cartParams = await getCartPrice(items);

      if (!mounted) return; // Проверяем, что виджет все еще активен

      double totalSum = 0;

      // Обновляем данные для каждого товара
      for (var i = 0; i < items.length; i++) {
        // Находим параметры товара из ответа API
        final itemCartParam = cartParams.firstWhere(
          (element) =>
              element["item_id"].toString() == items[i]["item_id"].toString(),
          orElse: () => {},
        );

        if (itemCartParam != null) {
          print(
              "Параметры товара ${items[i]["name"]}: ${itemCartParam.toString()}");

          // Обновляем акции если они есть
          items[i]["promotion"] = itemCartParam["promotions"];

          final amount = items[i]["amount"] as double;
          final price = double.parse(itemCartParam["price"].toString());

          // Если есть акция, считаем с учетом акции
          if (itemCartParam["promotions"] != null) {
            final baseAmount =
                double.parse(itemCartParam["promotions"]["base_amount"]);
            final addAmount =
                double.parse(itemCartParam["promotions"]["add_amount"]);
            final setSize = baseAmount + addAmount;

            if (amount >= setSize) {
              final sets = (amount / setSize).floor();
              final remainder = amount % setSize;

              // Акционная цена
              final promoPrice =
                  (sets * baseAmount * price) + (remainder * price);
              totalSum += promoPrice;
              //print("Товар ${items[i]["name"]} с акцией: $promoPrice");
            } else {
              totalSum += price * amount;
              //print("Товар ${items[i]["name"]} без акции: ${price * amount}");
            }
          } else {
            totalSum += price * amount;
            //print("Товар ${items[i]["name"]} обычная цена: ${price * amount}");
          }

          // Добавляем стоимость опций
          if (items[i]["options"] != null) {
            for (var option in items[i]["options"]) {
              if (option["price"] != null) {
                final optionPrice = option["price"] as double;
                final parentAmount =
                    items[i]["parent_amount"] as double? ?? 1.0;
                final optionCount = amount / parentAmount;
                final optionTotal = (optionPrice * optionCount);
                totalSum += optionTotal;
                //print("Опция ${option["option_name"]}: $optionTotal");
              }
            }
          }
        }
      }

      //print("Итоговая сумма: $totalSum");

      setState(() {
        sum2 = totalSum;
        sum = totalSum; // Обновляем обе суммы
        // Рассчитываем максимальную сумму бонусов (20% от суммы корзины)
        maxBonusesAllowed = totalSum * 0.25;
      });
    } catch (e) {
      //print("Ошибка при расчете цены корзины: $e");
    }
  }

  @override
  void initState() {
    super.initState();

    // Изменяем порядок вызовов
    getCartItems().then((_) {
      generateItemsFromReplacement();
      _getCartPrice();
      _getItemsRescByItems();
    });

    _getSavedCards();
    _getDeliveryPrice();
    _getBonuses();

    // Обновляем прослушивание изменений корзины
    dbm.cartUpdates.listen((onData) {
      if (onData != null && mounted) {
        getCartItems().then((_) {
          generateItemsFromReplacement();
          _getCartPrice();
          generateItemsFromReplacement();
        });
      }
    });
  }

  List<Map<String, dynamic>> itemsForReplacements = [];

  void generateItemsFromReplacement() {
    setState(() {
      // Очищаем старый список если корзина пуста
      if (items.isEmpty) {
        itemsForReplacements.clear();
        return;
      }

      // Создаем новый список замен на основе текущих товаров
      List<Map<String, dynamic>> newReplacements = [];

      for (var item in items) {
        // Ищем существующую настройку замены
        var existingReplacement = itemsForReplacements.firstWhere(
          (replacement) => replacement['item_id'] == item['item_id'],
          orElse: () => {},
        );

        // Создаем новую запись для замены
        Map<String, dynamic> replacementItem = {
          ...item,
          'replace': existingReplacement != null
              ? existingReplacement['replace']
              : true, // По умолчанию разрешаем замену
        };

        newReplacements.add(replacementItem);
      }

      itemsForReplacements = newReplacements;
    });
  }

  TextEditingController _message = TextEditingController();

  List recItems = [];

  _getItemsRescByItems() {
    if (!recPopulated) {
      setState(() {
        recPopulated = true;
      });
      List ids = [];
      items.forEach((v) {
        //print("some successssss");
        //print(v);
        //print(v["item_id"]);
        ids.add(v["item_id"]);
      });

      getItemsRescByItems(
              widget.business["business_id"], ids.join(',').toString())
          .then((v) {
        //print(v);
        setState(() {
          recItems = v["items"] ?? [];
        });
      });
    }
  }

  Widget getCartItem(int index) {
    return Container();
  }

  Widget getItemPrice(Map item) {
    final amount = item['amount'] as double;
    final price = item['price'] as int;
    final optionPrice =
        item['option_price'] as int? ?? 0; // Цена опции, если она есть
    final parentAmount = item['parent_amount'] as double? ??
        1; // parent_amount, если он есть, по умолчанию 1

    // Количество опций для данного товара
    final optionCount = amount / parentAmount;
    final totalPrice = (price * amount + optionCount * optionPrice).toInt();
    if (item["promotion"] != null) {
      int base_amount = double.parse(item["promotion"]["base_amount"]).toInt();
      int add_amount = double.parse(item["promotion"]["add_amount"]).toInt();
      if ((amount / (base_amount + add_amount)).toInt() >= 1) {
        final newTotalPrice = totalPrice -
            (((amount / (base_amount + add_amount)).toInt() * price)).toInt();
        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              formatPrice(totalPrice),
              strutStyle: StrutStyle(),
              style: GoogleFonts.inter(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.normal),
            ),
            SizedBox(
              width: 5,
            ),
            Text(
              formatPrice(newTotalPrice),
              style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.bold),
            )
          ],
        );
      }
    }
    return Text(
      formatPrice(totalPrice),
      style:
          GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
    );
  }

  void getTotalCartPrice(List items1) {
    int totalSum = 0;
    int discountSum = 0;

    items1.forEach((item) {
      // Базовая цена и количество
      final amount = item['amount'] as double;
      final price = item['price'] as int;

      // Считаем базовую стоимость позиции
      int itemTotal = (price * amount).toInt();

      // Добавляем стоимость опций
      if (item["options"] != null) {
        (item["options"] as List).forEach((option) {
          if (option["price"] != null) {
            final optionPrice = option["price"] as int;
            final parentAmount = item["parent_amount"] as double? ?? 1.0;
            final optionCount = amount / parentAmount;
            itemTotal += (optionPrice * optionCount).toInt();
          }
        });
      }

      totalSum += itemTotal;

      // Считаем скидку по акции если она есть
      if (item["promotion"] != null) {
        final baseAmount = double.parse(item["promotion"]["base_amount"]);
        final addAmount = double.parse(item["promotion"]["add_amount"]);
        final setSize = baseAmount + addAmount;

        if (amount >= setSize) {
          final sets = (amount / setSize).floor();
          final remainder = amount % setSize;

          // Акционная цена
          final promoPrice = (sets * baseAmount * price) + (remainder * price);

          // Скидка - разница между обычной и акционной ценой
          discountSum += itemTotal - promoPrice.toInt();
        }
      }
    });

    setState(() {
      sum = totalSum.toDouble();
      discount = discountSum;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.business["name"]),
      ),
      child: CustomScrollView(
        physics: BouncingScrollPhysics(),
        slivers: [
          // Секция замены продукции
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              child: CupertinoListSection.insetGrouped(
                backgroundColor: CupertinoColors.systemBackground,
                children: [
                  CupertinoListTile(
                    leading: Icon(
                      CupertinoIcons.arrow_2_circlepath,
                      color: CupertinoColors.activeOrange,
                    ),
                    title: Text('Пожелания по замене'),
                    subtitle: Text('Отсутствующие товары заменяются аналогами'),
                    trailing: CupertinoListTileChevron(),
                    onTap: () {
                      // Показываем sheet с опциями замены
                      _showReplacementOptions();
                    },
                  ),
                ],
              ),
            ),
          ),

          // Секция комментария
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              child: CupertinoListSection.insetGrouped(
                backgroundColor: CupertinoColors.systemBackground,
                children: [
                  CupertinoListTile(
                    leading: Icon(
                      CupertinoIcons.chat_bubble_text,
                      color: CupertinoColors.activeOrange,
                    ),
                    title: Text('Сообщение для заведения'),
                    subtitle:
                        Text('Специальные пожелания, особенности доставки'),
                    trailing: CupertinoListTileChevron(),
                    onTap: () => _showMessageSheet(context),
                  ),
                ],
              ),
            ),
          ),

          // Секция товаров
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Товары в заказе',
                style:
                    CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: items.isEmpty
                ? Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.secondarySystemBackground
                          .resolveFrom(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.cart,
                          size: 48,
                          color: CupertinoColors.systemGrey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Корзина пуста',
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    child: CupertinoListSection.insetGrouped(
                      children: items
                          .map((item) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CupertinoListTile(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    title: Text(
                                      item["name"],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    trailing: Container(
                                      constraints:
                                          BoxConstraints(maxWidth: 110),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            formatQuantity(
                                                item["amount"], "ед"),
                                            style: TextStyle(
                                              color: CupertinoColors
                                                  .secondaryLabel,
                                              fontSize: 13,
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          if (item["promotion"] != null) ...[
                                            // Если есть акция, показываем старую и новую цену
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  formatPrice(item["price"] *
                                                      item["amount"].toInt()),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                    color: CupertinoColors
                                                        .secondaryLabel,
                                                  ),
                                                ),
                                                Text(
                                                  _calculatePromotionPrice(
                                                      item),
                                                  style: TextStyle(
                                                    color: CupertinoColors
                                                        .activeOrange,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ] else
                                            Text(
                                              formatPrice(item["price"] *
                                                  item["amount"].toInt()),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Отображаем все опции из массива options
                                  if (item["options"] != null)
                                    ...(item["options"] as List)
                                        .map((option) => Padding(
                                              padding: EdgeInsets.fromLTRB(
                                                  12, 0, 12, 8),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      option["option_name"],
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: CupertinoColors
                                                            .secondaryLabel
                                                            .resolveFrom(
                                                                context),
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (option["price"] != null)
                                                    Text(
                                                      "+ ${formatPrice((option["price"] * (item["amount"] / (item["parent_amount"] ?? 1))).toInt())}",
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: CupertinoColors
                                                            .secondaryLabel
                                                            .resolveFrom(
                                                                context),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                  if (item["promotion"] != null)
                                    Padding(
                                      padding:
                                          EdgeInsets.fromLTRB(12, 0, 12, 8),
                                      child: Text(
                                        "Акция ${item["promotion"]["name"]}",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: CupertinoColors.activeOrange,
                                        ),
                                      ),
                                    ),
                                ],
                              ))
                          .toList(),
                    ),
                  ),
          ),

          // Способ получения
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              child: CupertinoListSection.insetGrouped(
                header: Text('Способ получения'),
                children: [
                  CupertinoListTile(
                    leading: Icon(
                      delivery
                          ? CupertinoIcons.cube_box
                          : CupertinoIcons.person_crop_circle,
                      color: CupertinoColors.activeOrange,
                    ),
                    title: Text(delivery ? 'Доставка' : 'Самовывоз'),
                    trailing: CupertinoSwitch(
                      value: delivery,
                      onChanged: (value) => setState(() => delivery = value),
                      activeColor: CupertinoColors.activeOrange,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Адрес и карта
          if (delivery) _buildDeliverySection() else _buildPickupSection(),

          // Способ оплаты
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              child: CupertinoListSection.insetGrouped(
                header: Text('Способ оплаты'),
                footer: Text('Выберите карту для оплаты заказа'),
                children: [
                  ...cards
                      .map((card) => CupertinoListTile(
                            title: Text(card["mask"]),
                            trailing: _selectedCard == card["card_id"]
                                ? Icon(CupertinoIcons.checkmark_circle_fill,
                                    color: CupertinoColors.activeOrange)
                                : null,
                            onTap: () =>
                                setState(() => _selectedCard = card["card_id"]),
                          ))
                      .toList(),
                  CupertinoListTile(
                    leading: Icon(CupertinoIcons.plus_circle,
                        color: CupertinoColors.activeOrange),
                    title: Text('Добавить карту'),
                    onTap: () => Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => AddNewCardPage(createOrder: true),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Итоговая сумма
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              child: CupertinoListSection.insetGrouped(
                footer: Text(
                  'Итоговая сумма заказа, стоимость доставки и количество списываемых бонусов могут измениться после проверки заказа',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 13,
                  ),
                ),
                children: [
                  CupertinoListTile(
                    title: Text('Корзина'),
                    trailing: Text(formatPrice(sum2.toInt())),
                  ),
                  if (delivery)
                    CupertinoListTile(
                      title: Text('Доставка'),
                      trailing: Text(formatPrice(deliveryPrice)),
                    ),
                  if (bonusesAvailabale)
                    CupertinoListTile(
                      title: Text('Использовать бонусы'),
                      subtitle: Text(
                          'Доступно: ${formatPrice(min(bonuses, maxBonusesAllowed.toInt()))} (макс. 25% от суммы)'),
                      trailing: CupertinoSwitch(
                        value: useBonuses,
                        activeColor: CupertinoColors.activeOrange,
                        onChanged: (bool value) {
                          setState(() {
                            useBonuses = value;
                          });
                        },
                      ),
                    ),
                  CupertinoListTile(
                    title: Text(
                      'Итого',
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .navLargeTitleTextStyle,
                    ),
                    trailing: Text(
                      formatPrice(delivery
                          ? (useBonuses
                              ? sum2.toInt() +
                                  deliveryPrice -
                                  min(bonuses, maxBonusesAllowed.toInt())
                              : sum2.toInt() + deliveryPrice)
                          : (useBonuses
                              ? sum2.toInt() -
                                  min(bonuses, maxBonusesAllowed.toInt())
                              : sum2.toInt())),
                      style: CupertinoTheme.of(context)
                          .textTheme
                          .navLargeTitleTextStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Кнопка оплаты
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CupertinoButton.filled(
                onPressed: createButtonEnabled && _selectedCard != null
                    ? _createOrder
                    : null,
                child: Text('Перейти к оплате'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplacementOptions() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Настройки замены',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(CupertinoIcons.xmark_circle_fill),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Выберите действие для каждого товара при его отсутствии',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(height: 12),
          Expanded(
            child: itemsForReplacements.isEmpty
                ? Center(
                    child: Text(
                      'Нет товаров для настройки замен',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontSize: 15,
                      ),
                    ),
                  )
                : CupertinoListSection.insetGrouped(
                    backgroundColor: CupertinoColors.systemBackground,
                    children: itemsForReplacements
                        .map(
                          (item) => CupertinoListTile(
                            title: Row(
                              children: [
                                if (item["img"] != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      item["img"],
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                        width: 40,
                                        height: 40,
                                        color: CupertinoColors.systemGrey5,
                                        child: Icon(
                                          CupertinoIcons.photo,
                                          color: CupertinoColors.systemGrey2,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                SizedBox(width: item["img"] != null ? 12 : 0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item["name"],
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '${formatQuantity(item["amount"], "шт")} × ${formatPrice(item["price"])}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: CupertinoSlidingSegmentedControl<bool>(
                                groupValue: item['replace'],
                                children: {
                                  true: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 6),
                                    child: Text('Заменить'),
                                  ),
                                  false: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 6),
                                    child: Text('Вернуть'),
                                  ),
                                },
                                onValueChanged: (value) {
                                  setState(() {
                                    int index =
                                        itemsForReplacements.indexOf(item);
                                    itemsForReplacements[index]['replace'] =
                                        value;
                                  });
                                },
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CupertinoButton.filled(
                onPressed: () => Navigator.pop(context),
                child: Text('Готово'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => AnimatedPadding(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CupertinoActionSheet(
          title: Text('Сообщение'),
          message: Column(
            children: [
              CupertinoTextField(
                controller: _message,
                placeholder: 'Введите сообщение...',
                maxLines: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: Text('Готово'),
              isDefaultAction: true,
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
            isDestructiveAction: true,
          ),
        ),
      ),
    );
  }

  Widget _buildDeliverySection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        child: CupertinoListSection.insetGrouped(
          header: Text('Адрес доставки'),
          children: [
            CupertinoListTile(
              leading: Icon(
                CupertinoIcons.location_solid,
                color: CupertinoColors.activeOrange,
              ),
              title: Text(
                widget.currentAddress["address"] ?? "Выберите адрес",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15),
              ),
              subtitle: widget.currentAddress["comment"] != null &&
                      widget.currentAddress["comment"].toString().isNotEmpty
                  ? Text(
                      widget.currentAddress["comment"],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    )
                  : null,
              trailing: Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey3,
              ),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => SelectAddressPage(
                      addresses: widget.addresses,
                      currentAddress: widget.currentAddress,
                      createOrder: true,
                      business: widget.business,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    widget.currentAddress.clear();
                    widget.currentAddress.addAll(result);
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: CupertinoListSection.insetGrouped(
          header: Text('Адрес самовывоза'),
          children: [
            CupertinoListTile(
              leading: Icon(
                CupertinoIcons.building_2_fill,
                color: CupertinoColors.activeOrange,
              ),
              title: Text(widget.business["address"]),
            ),
          ],
        ),
      ),
    );
  }

  String _calculatePromotionPrice(Map item) {
    final amount = item["amount"].toDouble();
    final price = item["price"];
    final promotion = item["promotion"];

    if (promotion != null) {
      final baseAmount = double.parse(promotion["base_amount"]);
      final addAmount = double.parse(promotion["add_amount"]);
      final setSize = baseAmount + addAmount;

      if (amount >= setSize) {
        final sets = (amount / setSize).floor();
        final remainder = amount % setSize;

        // Цена с учетом акции
        final promotionPrice =
            (sets * baseAmount * price) + (remainder * price);
        return formatPrice(promotionPrice.toInt());
      }
    }

    return formatPrice((price * amount).toInt());
  }

  void _showReplacementOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Настройки замены',
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .navTitleTextStyle,
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(CupertinoIcons.xmark_circle_fill),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Выберите действие для каждого товара при его отсутствии',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Expanded(
                  child: itemsForReplacements.isEmpty
                      ? Center(
                          child: Text(
                            'Нет товаров для настройки замен',
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel,
                              fontSize: 15,
                            ),
                          ),
                        )
                      : CupertinoListSection.insetGrouped(
                          backgroundColor: CupertinoColors.systemBackground,
                          children: itemsForReplacements.map((item) {
                            return CupertinoListTile(
                              title: Row(
                                children: [
                                  if (item["img"] != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        item["img"],
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                          width: 40,
                                          height: 40,
                                          color: CupertinoColors.systemGrey5,
                                          child: Icon(
                                            CupertinoIcons.photo,
                                            color: CupertinoColors.systemGrey2,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  SizedBox(width: item["img"] != null ? 12 : 0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item["name"],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '${formatQuantity(item["amount"], "шт")} × ${formatPrice(item["price"])}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: CupertinoSlidingSegmentedControl<bool>(
                                  groupValue: item['replace'] ?? true,
                                  backgroundColor: CupertinoColors.systemGrey6,
                                  thumbColor: CupertinoColors.systemBackground,
                                  children: {
                                    true: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 6),
                                      child: Text(
                                        'Заменить',
                                        style: TextStyle(
                                          color: item['replace'] == true
                                              ? CupertinoColors.activeOrange
                                              : CupertinoColors.label,
                                          fontWeight: item['replace'] == true
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    false: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 6),
                                      child: Text(
                                        'Вернуть',
                                        style: TextStyle(
                                          color: item['replace'] == false
                                              ? CupertinoColors.destructiveRed
                                              : CupertinoColors.label,
                                          fontWeight: item['replace'] == false
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  },
                                  onValueChanged: (value) {
                                    setModalState(() {
                                      int index =
                                          itemsForReplacements.indexOf(item);
                                      itemsForReplacements[index]['replace'] =
                                          value;
                                    });
                                    setState(
                                        () {}); // Обновляем основной виджет
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CupertinoButton.filled(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Готово'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
