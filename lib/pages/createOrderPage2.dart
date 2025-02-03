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
import 'package:naliv_delivery/pages/paymentMethods.dart';
import 'package:naliv_delivery/pages/selectAddressPage.dart';
import 'package:naliv_delivery/shared/ItemCard2.dart';
import 'package:naliv_delivery/shared/changeAmountButton.dart';
import 'package:naliv_delivery/shared/openMainPageButton.dart';

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
  int deliveryPrice = 0;
  bool delivery = true;
  bool createButtonEnabled = true;
  bool useBonuses = false;
  int bonuses = 0;
  bool bonusesAvailabale = false;
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
      print("============");
      print(v);
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
      print(v);
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

  getCartSum() async {
    await dbm.getCartTotal(int.parse(widget.business["business_id"])).then((v) {
      setState(() {
        sum = v;
      });
    });
  }

  _createOrder() async {
    String extra = "По заменам и возвратам:";

    itemsForReplacements.forEach((i) {
      extra = extra +
          i["name"] +
          "-" +
          (i["replace"]
              ? "Разрешена замена"
              : "Вернуть деньги за данную позицию") +
          "\n";
    });

    extra = extra + "\n\n\n";
    extra = extra + _message.text;
    print(extra);
    setState(() {
      createButtonEnabled = false;
    });
    dbm.updateCartStatusByBusinessId(int.parse(widget.business["business_id"]));
    await createOrder3(widget.business["business_id"], delivery ? "1" : "0",
            _selectedCard, items, useBonuses, extra)
        .then((value) {
      if (value["status"] == "insufficent funds") {
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(
                "Нехватает средств",
              ),
              content: Text("Вернитесь на главный экран для повторной оплаты"),
              actions: [OpenMainPage()],
            );
          },
        );
      } else if (value["code"].toString() == "0") {
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(
                "Платеж принят в обработку",
              ),
              content:
                  Text("Вернитесь на главный экран для отслеживания заказа"),
              actions: [OpenMainPage()],
            );
          },
        );
      } else if (value["status"] == "unknown") {
        showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(
                "Ожидаем подтверждение платежа от банка",
              ),
              content: Text(
                  "Вернитесь на главный экран для просмотра статуса оплаты"),
              actions: [OpenMainPage()],
            );
          },
        );
      }
      return value;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getCartItems();
    getCartSum();
    _getSavedCards();
    _getDeliveryPrice();
    _getBonuses();
    dbm.cartUpdates.listen((onData) {
      if (onData != null) {
        print("========================");
        print(onData);
        getCartItems();
        getCartSum();
        generateItemsFromReplacement();
      }
    });
  }

  List itemsForReplacements = [];

  generateItemsFromReplacement() {
    items.forEach((item) {
      if (itemsForReplacements
              .where((vv) {
                return vv["item_id"] == item["item_id"];
              })
              .toList()
              .length ==
          0) {
        item["replace"] = true;
        setState(() {
          itemsForReplacements.add(item);
        });
      }
      ;
    });
  }

  TextEditingController _message = TextEditingController();

  List recItems = [];

  _getItemsRescByItems() {
    List ids = [];
    items.forEach((v) {
      print("some successssss");
      print(v);
      print(v["item_id"]);
      ids.add(v["item_id"]);
    });

    getItemsRescByItems(
            widget.business["business_id"], ids.join(',').toString())
        .then((v) {
      print(v);
      setState(() {
        recItems = v["items"] ?? [];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            centerTitle: false,
            title: Text(
              widget.business["name"],
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SliverToBoxAdapter(
            child: ExpansionTile(
              onExpansionChanged: (value) {
                generateItemsFromReplacement();
              },
              children: [
                ListView.builder(
                  primary: false,
                  shrinkWrap: true,
                  physics: ClampingScrollPhysics(),
                  itemCount: itemsForReplacements.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: EdgeInsets.all(5),
                      padding: EdgeInsets.all(5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  itemsForReplacements[index]["replace"]
                                      ? Text(
                                          "Замена",
                                          style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.w900),
                                        )
                                      : Text("Возврат",
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w900)),
                                  Text(itemsForReplacements[index]["name"]
                                      .toString())
                                ],
                              )),
                          Flexible(
                              child: Switch(
                            activeColor: Color(0xFFEE7203),
                            value: itemsForReplacements[index]["replace"],
                            onChanged: (value) {
                              setState(() {
                                itemsForReplacements[index]["replace"] = value;
                              });
                            },
                          ))
                        ],
                      ),
                    );
                  },
                ),
              ],
              leading: Icon(
                Icons.published_with_changes,
                color: Color(0xFFEE7203),
              ),
              title: Text(
                "Пожелания по замене продукции",
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 12),
              ),
              subtitle: Text(
                "Отсутствующие товары заменяются аналогами, либо производится возврат денег.",
                style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    fontSize: 12),
              ),
              // trailing: Icon(Icons.arrow_forward_ios_sharp),
            ),
          ),
          SliverToBoxAdapter(
            child: ListTile(
              onTap: () {
                showModalBottomSheet(
                  useSafeArea: true,
                  backgroundColor: Color(0xFF121212),
                  context: context,
                  isScrollControlled: true,
                  builder: (context) {
                    return DraggableScrollableSheet(
                      initialChildSize: 0.7,
                      minChildSize: 0.7,
                      maxChildSize: 0.8,
                      builder: (context, scrollController) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    icon: Icon(Icons.close))
                              ],
                            ),
                            Container(
                              padding: EdgeInsets.all(10),
                              child: TextField(
                                decoration: InputDecoration(
                                    border: OutlineInputBorder()),
                                maxLines: 10,
                                controller: _message,
                              ),
                            )
                          ],
                        );
                      },
                    );
                  },
                );
              },
              leading: Icon(
                Icons.comment,
                color: Color(0xFFEE7203),
              ),
              title: Text(
                "Сообщение для заведения",
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 12),
              ),
              subtitle: Text(
                "Специальные пожелания, особенности доставки.",
                style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    fontSize: 12),
              ),
              trailing: Icon(Icons.arrow_forward_ios_sharp),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(left: 10, top: 20, bottom: 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Товары в заказе",
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 24),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.all(10),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Colors.white, width: 0.3))),
                  child: ListTile(
                      contentPadding: EdgeInsets.all(0),
                      dense: false,
                      title: Text(
                        items[index]["name"],
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        items[index]["option_name"] ?? "",
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        formatQuantity(items[index]["amount"], "ед"),
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontSize: 16),
                      )),
                );
              },
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.all(10),
            sliver: SliverToBoxAdapter(
                child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                  color: Color(0xFF121212)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        width: constraints.maxWidth,
                        child: CheckboxListTile(
                          checkColor: Colors.white,
                          activeColor: Color(0xFFEE7203),
                          // fillColor: MaterialStateProperty.all(Colors.orange),

                          contentPadding: EdgeInsets.all(0),
                          title: Text(
                            delivery ? "Доставка" : "Самовывоз",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 24),
                          ),
                          value: delivery,
                          onChanged: (bool? value) {
                            setState(() {
                              delivery = value!;
                            });
                          },
                          checkboxShape: CircleBorder(),
                          // secondary: delivery
                          //     ? Icon(
                          //         Icons.delivery_dining,
                          //         size: 24,
                          //       )
                          //     : Icon(Icons.directions_walk_outlined),
                        ),
                      );
                    },
                  ),
                  AnimatedCrossFade(
                      firstChild: Container(
                          child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                              child: Container(
                                  clipBehavior: Clip.hardEdge,
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(10))),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: FlutterMap(
                                      options: MapOptions(
                                        interactionOptions: InteractionOptions(
                                            flags: InteractiveFlag.none),
                                        initialZoom: 18,
                                        initialCenter: LatLng(
                                            double.parse(
                                                widget.currentAddress["lat"]),
                                            double.parse(
                                                widget.currentAddress["lon"])),
                                      ),
                                      children: [
                                        TileLayer(
                                          // Display map tiles from any source
                                          urlTemplate:
                                              'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                                          subdomains: [
                                            'tile0',
                                            'tile1',
                                            'tile2',
                                            'tile3'
                                          ],
                                          // And many more recommended properties!
                                        ),
                                        // MarkerLayer(markers: [
                                        //   Marker(
                                        //       width: 80.0,
                                        //       height: 80.0,
                                        //       point: LatLng(
                                        //           double.parse(
                                        //               currentAddress["lat"]),
                                        //           double.parse(
                                        //               currentAddress["lon"])),
                                        //       child: Icon(
                                        //         Icons.location_on,
                                        //         color: Color(0xFFEE7203),
                                        //         size: 40,
                                        //       ))
                                        // ]),
                                      ],
                                    ),
                                  ))),
                          Flexible(
                            flex: 2,
                            child: Container(
                                padding: EdgeInsets.only(left: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                        onTap: () {
                                          Navigator.pushReplacement(context,
                                              CupertinoPageRoute(
                                            builder: (context) {
                                              return SelectAddressPage(
                                                addresses: widget.addresses,
                                                currentAddress:
                                                    widget.currentAddress,
                                                createOrder: true,
                                                business: widget.business,
                                              );
                                            },
                                          ));
                                        },
                                        child: Text(
                                          "Изменить",
                                          style: TextStyle(
                                              color: Color(0xFFEE7203),
                                              fontWeight: FontWeight.bold),
                                        )),
                                    Text(
                                      widget.currentAddress["address"],
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Flexible(
                                            child: Text(
                                          "Квартира/Офис: ",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w400,
                                              fontSize: 12),
                                        )),
                                        Flexible(
                                            child: Text(
                                          widget.currentAddress["apartment"]
                                              .toString(),
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12),
                                        ))
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Flexible(
                                            child: Text(
                                          "Подъезд/Вход: ",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w400,
                                              fontSize: 12),
                                        )),
                                        Flexible(
                                            child: Text(
                                          widget.currentAddress["entrance"]
                                              .toString(),
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12),
                                        ))
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Flexible(
                                            child: Text(
                                          "Этаж: ",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w400,
                                              fontSize: 12),
                                        )),
                                        Flexible(
                                            child: Text(
                                          widget.currentAddress["floor"]
                                              .toString(),
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12),
                                        ))
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Flexible(
                                            child: Text(
                                          "Прочее: ",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w400,
                                              fontSize: 12),
                                        )),
                                        Flexible(
                                            child: Text(
                                          widget.currentAddress["other"]
                                              .toString(),
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12),
                                        ))
                                      ],
                                    ),
                                  ],
                                )),
                          )
                        ],
                      )),
                      secondChild: Container(
                          child: Column(
                        children: [
                          AspectRatio(
                              aspectRatio: 21 / 9,
                              child: Container(
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10))),
                                child: FlutterMap(
                                  options: MapOptions(
                                    interactionOptions: InteractionOptions(
                                        flags: InteractiveFlag.none),
                                    initialZoom: 18,
                                    initialCenter: LatLng(
                                        double.parse(widget.business["lat"]),
                                        double.parse(widget.business["lon"])),
                                  ),
                                  children: [
                                    TileLayer(
                                      // Display map tiles from any source
                                      urlTemplate:
                                          'https://{s}.maps.2gis.com/tiles?x={x}&y={y}&z={z}',
                                      subdomains: [
                                        'tile0',
                                        'tile1',
                                        'tile2',
                                        'tile3'
                                      ],
                                      // And many more recommended properties!
                                    ),
                                    // MarkerLayer(markers: [
                                    //   Marker(
                                    //       width: 80.0,
                                    //       height: 80.0,
                                    //       point: LatLng(
                                    //           double.parse(
                                    //               widget.business["lat"]),
                                    //           double.parse(widget
                                    //               .business["lon"])),
                                    //       child: Icon(
                                    //         Icons.location_on,
                                    //         color: Color(0xFFEE7203),
                                    //         size: 40,
                                    //       ))
                                    // ]),
                                  ],
                                ),
                              )),
                          Divider(
                            color: Colors.transparent,
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  "${widget.business["name"]} ${widget.business["address"]}",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              )
                            ],
                          ),
                        ],
                      )),
                      crossFadeState: delivery
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: Durations.medium1)
                ],
              ),
            )),
          ),
          SliverPadding(
              padding: EdgeInsets.all(10),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Метод оплаты",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 24),
                        ),
                        GestureDetector(
                          onTap: () {
                            _getSavedCards();
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                "Обновить",
                                style: TextStyle(color: Colors.orangeAccent),
                              ),
                              Icon(
                                Icons.replay_outlined,
                                color: Colors.orangeAccent,
                                size: 14,
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, CupertinoPageRoute(
                          builder: (context) {
                            return AddNewCardPage(
                              createOrder: true,
                            );
                          },
                        ));
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_card,
                            color: Colors.white,
                            size: 24,
                          ),
                          Text(
                            " Добавить карту",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              )),
          SliverPadding(
              padding: EdgeInsets.all(10),
              sliver: SliverList.builder(
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  return RadioListTile(
                    contentPadding: EdgeInsets.all(0),
                    activeColor: Color(0xFFEE7203),
                    dense: false,
                    title: Text(
                      cards[index]["mask"],
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    groupValue: _selectedCard,
                    value: cards[index]["card_id"],
                    onChanged: (value) {
                      setState(() {
                        _selectedCard = value;
                      });
                    },
                  );
                },
              )),
          SliverPadding(
            padding: EdgeInsets.all(0),
            sliver: SliverToBoxAdapter(
              child: SwitchListTile(
                activeColor: Colors.amber,
                value: useBonuses,
                onChanged: bonusesAvailabale
                    ? (value) {
                        setState(() {
                          useBonuses = value;
                        });
                      }
                    : null,
                title: Text(
                  "Использовать бонусы",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text("Доступно для оплаты " +
                    ((sum / 100 * 30).toInt() > bonuses
                            ? bonuses
                            : (sum / 100 * 30).toInt())
                        .toString() +
                    " б."),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.all(10),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        border: Border(
                            bottom:
                                BorderSide(color: Colors.white, width: 0.5))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Корзина",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          formatPrice(sum.toInt()),
                          style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  delivery
                      ? Container(
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: Colors.white, width: 0.5))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Доставка, комиссия",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                formatPrice(deliveryPrice.toInt()),
                                style: GoogleFonts.inter(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : Container(),
                  Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        border: Border(
                            bottom:
                                BorderSide(color: Colors.white, width: 0.5))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Итого",
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        delivery
                            ? Text(
                                "~" +
                                    formatPrice(
                                        sum.toInt() + deliveryPrice.toInt()),
                                style: GoogleFonts.inter(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                              )
                            : Text(
                                "~" + formatPrice(sum.toInt()),
                                style: GoogleFonts.inter(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.all(10),
            sliver: SliverToBoxAdapter(
              child: ElevatedButton(
                onPressed: createButtonEnabled && _selectedCard != null
                    ? () {
                        _createOrder();
                      }
                    : null,
                child: Text(
                  "Перейти к оплате",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20),
                ),
              ),
            ),
          ),
          SliverPadding(
              padding: EdgeInsets.only(top: 20, left: 10),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "На основе вашего заказа",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                    ),
                  ],
                ),
              )),
          SliverPadding(
            padding: EdgeInsets.only(top: 0, left: 10, right: 10, bottom: 10),
            sliver: SliverToBoxAdapter(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    childAspectRatio: 8 / 12,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    crossAxisCount: 2),
                primary: false,
                shrinkWrap: true,
                itemCount: recItems.length,
                itemBuilder: (context, index2) {
                  final Map<String, dynamic> item = recItems[index2];
                  return ItemCard2(
                    item: item,
                    business: widget.business,
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 500,
            ),
          ),
        ],
      ),
    );
  }
}
