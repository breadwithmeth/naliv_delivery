import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:naliv_delivery/pages/selectAddressPage.dart';
import 'package:naliv_delivery/pages/webViewCardPayPage.dart';
import '../globals.dart' as globals;
import 'package:flutter/cupertino.dart';

import 'package:naliv_delivery/pages/orderConfirmation.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';

import '../misc/api.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({
    super.key,
    required this.business,
    required this.currentAddress,
    required this.addresses,
    required this.items,
    required this.localSum,
    required this.price,
    required this.taxes,

    // required this.itemsAmount,
  });

  final Map<dynamic, dynamic> business;
  final Map currentAddress;
  final List addresses;
  final List items;
  final int localSum;
  final int price;
  final int taxes;

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage>
    with SingleTickerProviderStateMixin {
  bool delivery = true;

  late AnimationController _controller;
  String paymentDescText = "";
  int _selectedCard = 0;
  List cards = [
    {"card_id": 0, "card_number": "Новая карта"},
  ];

  void _getSavedCards() async {
    List t_cards = await getSavedCards();
    List _cards = [];
    for (var card in t_cards) {
      _cards.add({
        "card_id": int.parse(card["card_id"]),
        "card_number": card["mask"],
      });
    }

    setState(() {
      cards.addAll(_cards);
    });
  }

  List? items = [];
  int localSum = 0;
  int price = 0;
  int taxes = 0;

  @override
  void initState() {
    super.initState();
    _getSavedCards();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        // floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        // floatingActionButton: Padding(
        //   padding: EdgeInsets.symmetric(horizontal: 30 * globals.scaleParam),
        //   child: Row(
        //     children: [
        //       MediaQuery.sizeOf(context).width >
        //               MediaQuery.sizeOf(context).height
        //           ? Flexible(
        //               flex: 2,
        //               fit: FlexFit.tight,
        //               child: SizedBox(),
        //             )
        //           : SizedBox(),
        //       Flexible(
        //         fit: FlexFit.tight,
        //         child: ElevatedButton(
        //           onPressed: isAddressesLoading || isCartLoading
        //               ? null
        //               : () {
        //                   Navigator.push(
        //                     context,
        //                     CupertinoPageRoute(
        //                       builder: (context) => OrderConfirmation(
        //                         card_id: _selectedCard,
        //                         delivery: delivery,
        //                         items: widget.items,
        //                         address: currentAddress,
        //                         cartInfo: cartInfo,
        //                         business: widget.business,
        //                         user: widget.user,
        //                         finalSum: delivery
        //                             ? double.parse(((widget.finalSum - 0) +
        //                                         _deliveryInfo["price"] +
        //                                         _deliveryInfo["taxes"])
        //                                     .toString())
        //                                 .round()
        //                             : double.parse(
        //                                     ((widget.finalSum - 0)).toString())
        //                                 .round(),
        //                       ),
        //                     ),
        //                   );
        //                 },
        //           child: Row(
        //             mainAxisAlignment: MainAxisAlignment.center,
        //             crossAxisAlignment: CrossAxisAlignment.center,
        //             children: [
        //               Flexible(
        //                 fit: FlexFit.tight,
        //                 child: Text(
        //                   "Подтвердить заказ",
        //                   textAlign: TextAlign.center,
        //                   style: TextStyle(
        //                     color: Colors.white,
        //                     fontVariations: <FontVariation>[
        //                       FontVariation('wght', 800)
        //                     ],
        //                     fontSize: 42 * globals.scaleParam,
        //                   ),
        //                 ),
        //               ),
        //             ],
        //           ),
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              centerTitle: false,
              backgroundColor: Colors.black,
              title: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${widget.business["name"]}",
                    style: TextStyle(fontSize: 24),
                  ),
                  Text(
                    "${widget.business["address"]}",
                    style: TextStyle(fontSize: 14),
                  )
                ],
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.all(10),
              sliver: SliverToBoxAdapter(
                  child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    color: Color(0xFF121212)),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
                          width: constraints.maxWidth,
                          child: CheckboxListTile(
                            checkColor: Colors.white,
                            activeColor: Colors.orange,
                            // fillColor: MaterialStateProperty.all(Colors.orange),

                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
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
                            padding: EdgeInsets.all(10),
                            child: Column(
                              children: [
                                AspectRatio(
                                    aspectRatio: 21 / 9,
                                    child: Container(
                                      clipBehavior: Clip.hardEdge,
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(10))),
                                      child: FlutterMap(
                                        options: MapOptions(
                                          interactionOptions:
                                              InteractionOptions(
                                                  flags: InteractiveFlag.none),
                                          initialZoom: 18,
                                          initialCenter: LatLng(
                                              double.parse(
                                                  widget.currentAddress["lat"]),
                                              double.parse(widget
                                                  .currentAddress["lon"])),
                                        ),
                                        children: [
                                          TileLayer(
                                            tileBuilder: _darkModeTileBuilder,
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
                                          //         color: Colors.orangeAccent,
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                        flex: 2,
                                        child: Text(
                                          widget.currentAddress["address"],
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16),
                                        )),
                                    Flexible(
                                        child: TextButton(
                                            style: TextButton.styleFrom(
                                                backgroundColor: Colors.black),
                                            onPressed: () {
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
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold),
                                            )))
                                  ],
                                ),
                                Divider(
                                  color: Colors.transparent,
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
                                      widget.currentAddress["floor"].toString(),
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
                                      widget.currentAddress["other"].toString(),
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12),
                                    ))
                                  ],
                                ),
                              ],
                            )),
                        secondChild: Container(
                            padding: EdgeInsets.all(10),
                            child: Column(
                              children: [
                                AspectRatio(
                                    aspectRatio: 21 / 9,
                                    child: Container(
                                      clipBehavior: Clip.hardEdge,
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(10))),
                                      child: FlutterMap(
                                        options: MapOptions(
                                          interactionOptions:
                                              InteractionOptions(
                                                  flags: InteractiveFlag.none),
                                          initialZoom: 18,
                                          initialCenter: LatLng(
                                              double.parse(
                                                  widget.business["lat"]),
                                              double.parse(
                                                  widget.business["lon"])),
                                        ),
                                        children: [
                                          TileLayer(
                                            tileBuilder: _darkModeTileBuilder,
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
                                          //         color: Colors.orangeAccent,
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
              sliver: SliverList.builder(
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  return RadioListTile(
                    activeColor: Colors.orangeAccent,
                    dense: true,
                    title: Text(
                      cards[index]["card_number"],
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
              ),
            ),
            SliverPadding(
                padding: EdgeInsets.all(10),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(
                              "Корзина",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(
                              "${widget.localSum.toString()} ₸",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(
                              "Доставка",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(
                              delivery ? "${widget.price.toString()} ₸" : "0 ₸",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(
                              "Тариф за сервис",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(
                              delivery ? "${widget.taxes.toString()} ₸" : "0 ₸",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(),
                      Row(
                        children: [
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(
                              "Итого",
                              style: TextStyle(
                                fontSize: 24,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Flexible(
                            fit: FlexFit.tight,
                            child: Text(
                              //! TODO: Add bonuses instead of hardcoded zero!
                              delivery
                                  ? "${(widget.localSum + widget.price + widget.taxes).toString()} ₸"
                                  : "${widget.localSum.toString()} ₸",
                              style: TextStyle(
                                fontSize: 24,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
            SliverPadding(
              padding: EdgeInsets.all(10),
              sliver: SliverToBoxAdapter(
                child: Text(
                  "Продолжая оформление заказа, я подтверждаю, что продавец имеет право заменить товар на альтернативный в случае отсутствия заказанной позиции или позиций.",
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            SliverPadding(
                padding: EdgeInsets.all(10),
                sliver: SliverToBoxAdapter(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => OrderConfirmation(
                            card_id: _selectedCard,
                            delivery: delivery,
                            items: widget.items,
                            address: widget.currentAddress,
                            business: widget.business,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          fit: FlexFit.tight,
                          child: Text(
                            "Подтвердить заказ",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 500,
              ),
            )
          ],
        ));
  }
}

Widget _darkModeTileBuilder(
  BuildContext context,
  Widget tileWidget,
  TileImage tile,
) {
  return ColorFiltered(
    colorFilter: const ColorFilter.matrix(<double>[
      -0.2126, -0.7152, -0.0722, 0, 255, // Red channel
      -0.2126, -0.7152, -0.0722, 0, 255, // Green channel
      -0.2126, -0.7152, -0.0722, 0, 255, // Blue channel
      0, 0, 0, 1, 0, // Alpha channel
    ]),
    child: tileWidget,
  );
}
