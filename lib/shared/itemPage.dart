import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/databaseapi.dart';
import 'package:naliv_delivery/shared/ItemCard2.dart';

class ItemPage extends StatefulWidget {
  const ItemPage({super.key, required this.item, required this.business});
  final Map item;
  final Map business;

  @override
  State<ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends State<ItemPage> {
  Map<String, dynamic>? cartItem = null;
  double currentAmount = 0;
  DatabaseManager dbm = DatabaseManager();

  List? options = null;

  double? parentItemAmoint = null;
  double quantity = 1;
  bool? liked = null;
  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  updateOptions() {
    setState(() {
      quantity = widget.item["quantity"];
    });

    if (widget.item["options"] != null) {
      setState(() {
        options = widget.item["options"];
      });
    }
  }

  getCurrentAmount() async {
    await dbm
        .getCartItemByItemId(
            int.parse(widget.business["business_id"]), widget.item["item_id"])
        .then((v) {
      setState(() {
        if (v == null) {
          currentAmount = 0;
          parentItemAmoint = null;
        } else {
          currentAmount = v["amount"];
          parentItemAmoint = v["parent_amount"];
        }
        cartItem = v;
      });
    });
  }

  updateAmount(double newAmount) async {
    await dbm
        .updateAmount(int.parse(widget.business["business_id"]),
            widget.item["item_id"], newAmount)
        .then((v) {
      print(v);
      setState(() {
        if (v == null) {
          currentAmount = 0;
          parentItemAmoint = null;
        } else {
          currentAmount = v["amount"];
          parentItemAmoint = v["parent_amount"];
        }
        cartItem = v;
      });
    });
  }

  addToCart({Map? option = null}) async {
    if (option == null) {
      await dbm
          .addToCart(
              int.parse(widget.business["business_id"]),
              widget.item["item_id"],
              widget.item["quantity"],
              widget.item["in_stock"],
              widget.item["price"],
              widget.item["name"],
              widget.item["quantity"],
              widget.item["img"] ?? "/")
          .then((v) {
        setState(() {
          print(v);
          if (v == null) {
            currentAmount = 0;
            parentItemAmoint = null;
          } else {
            currentAmount = v["amount"];
            parentItemAmoint = v["parent_amount"];
          }
          cartItem = v;
        });
      });
    } else {
      await dbm.addToCart(
          int.parse(widget.business["business_id"]),
          widget.item["item_id"],
          option["parent_item_amount"],
          widget.item["in_stock"],
          widget.item["price"],
          widget.item["name"],
          widget.item["quantity"],
          widget.item["img"] ?? "/",
          options: [option!]).then((v) {
        setState(() {
          print(v);
          if (v == null) {
            currentAmount = 0;
            parentItemAmoint = null;
          } else {
            currentAmount = v["amount"];
            parentItemAmoint = v["parent_amount"];
          }
          cartItem = v;
        });
      });
    }
  }

  List recItems = [];

  _getRecItems() {
    getItemsRecs(
            widget.business["business_id"], widget.item["item_id"].toString())
        .then((value) {
      setState(() {
        recItems = value["items"] ?? [];
      });
    });
  }

  List addItems = [];

  _getAdditions() {
    getAdditions(widget.business["business_id"],
            widget.item["category_id"].toString())
        .then((value) {
      print("===========");
      print(value);
      setState(() {
        addItems = value["items"] ?? [];
        addItems.shuffle();
      });
    });
  }

  List _properties = [];
  _getProperties() {
    getProperties(widget.item["item_id"].toString()).then((value) {
      setState(() {
        _properties = value;
      });
    });
  }

  _isLiked() async {
    await isLiked(widget.item["item_id"]).then((v) {
      setState(() {
        liked = v;
      });
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    dbm.cartUpdates.listen((onData) {
      if (onData != null) {
        if (onData!["item_id"] == widget.item["item_id"]) {
          print(onData);
          getCurrentAmount();
        }
      }
    });
    updateOptions();
    getCurrentAmount();
    _getRecItems();
    _getAdditions();
    _getProperties();
    _isLiked();
  }

  bool imageZoom = false;
  double wOffset = 0;
  double hOffset = 0;
  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      shouldCloseOnMinExtent: true,
      minChildSize: 0.7,
      initialChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          color: Colors.black,
          child: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                Radius.circular(30),
              )),
              child: Scaffold(
                floatingActionButton: Container(
                  decoration: BoxDecoration(
                      color: Color(0xFFEE7203),
                      borderRadius: BorderRadius.all(Radius.circular(15))),
                  child: AnimatedCrossFade(
                      firstChild: TextButton(
                        onPressed: () {
                          if (options == null) {
                            addToCart();
                          } else {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) {
                                return Container(
                                  color: Colors.black,
                                  height:
                                      MediaQuery.of(context).size.height * 0.6,
                                  child: ListView.builder(
                                    primary: false,
                                    shrinkWrap: true,
                                    itemCount: options!.length,
                                    itemBuilder: (context, index) {
                                      List suboptions =
                                          options![index]["options"];
                                      return ListView.builder(
                                        shrinkWrap: true,
                                        primary: false,
                                        itemCount: suboptions.length,
                                        itemBuilder: (context, index2) {
                                          return GestureDetector(
                                            onTap: () {
                                              Navigator.pop(context);
                                              addToCart(
                                                  option: suboptions[index2]);
                                            },
                                            child: Container(
                                              padding: EdgeInsets.all(15),
                                              margin: EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                  color: Color(0xFF121212),
                                                  borderRadius:
                                                      BorderRadius.all(
                                                          Radius.circular(15))),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(suboptions[index2]
                                                      ["name"]),
                                                  Text(suboptions[index2]
                                                          ["price"]
                                                      .toString()),
                                                ],
                                              ),
                                              // tileColor: Colors.white,
                                              // title: Text(suboptions[index2]["name"]),
                                              // trailing: Text(suboptions[index2]["price"]
                                              //     .toString()),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                );
                              },
                            );
                          }
                        },
                        child: Text("Добавить в корзину",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                      secondChild: cartItem == null
                          ? Container()
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    onPressed: () {
                                      if (parentItemAmoint == null) {
                                        updateAmount(currentAmount - quantity);
                                      } else {
                                        updateAmount(currentAmount -
                                            (quantity * parentItemAmoint!));
                                      }
                                    },
                                    icon: Icon(
                                      Icons.remove,
                                      color: Colors.grey.shade300,
                                    )),
                                Text(
                                  currentAmount.toString(),
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                                IconButton(
                                    onPressed: () {
                                      if (parentItemAmoint == null) {
                                        updateAmount(currentAmount + quantity);
                                      } else {
                                        updateAmount(currentAmount +
                                            (quantity * parentItemAmoint!));
                                      }
                                    },
                                    icon: Icon(
                                      Icons.add,
                                      color: Colors.white,
                                    )),
                              ],
                            ),
                      crossFadeState: cartItem == null
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: Durations.medium1),
                ),
                body: Container(
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(30)),
                      color: Color(0xFF121212)),
                  child: ListView(
                    controller: scrollController,
                    physics: ClampingScrollPhysics(),
                    shrinkWrap: true,
                    primary: false,
                    children: [
                      GestureDetector(
                        onDoubleTap: () {
                          setState(() {
                            imageZoom = !imageZoom;
                          });
                          // print(details.globalPosition);
                          // print(MediaQuery.of(context).size);
                        },
                        onLongPressMoveUpdate: (details) {
                          print(details.localPosition);
                          setState(() {
                            wOffset = details.localOffsetFromOrigin.dx;
                            hOffset = details.localOffsetFromOrigin.dy;
                          });
                        },
                        onTapDown: (details) {
                          print(details.globalPosition);
                        },
                        // onVerticalDragUpdate: (details) {
                        //   print(details.);
                        // },
                        child: Container(
                          decoration: BoxDecoration(),
                          clipBehavior: Clip.antiAliasWithSaveLayer,
                          child: AspectRatio(
                            aspectRatio: imageZoom ? 0.6 : 1,
                            child: Transform.scale(
                              origin: Offset(wOffset, hOffset),
                              scale: imageZoom ? 2 : 1,
                              child: CachedNetworkImage(
                                // alignment: Alignment(wOffset, ),
                                fit: BoxFit.cover,
                                imageUrl: widget.item["img"] ?? "/",
                                placeholder: (context, url) => Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    Icon(Icons.error),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          widget.item["name"],
                          style: GoogleFonts.roboto(
                              fontWeight: FontWeight.bold, fontSize: 24),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.only(left: 10),
                        margin: EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                  color: Color(0xFFEE7203),
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(30))),
                              padding: EdgeInsets.all(10),
                              child: Text(
                                widget.item["price"].toString() + "₸",
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800, fontSize: 20),
                              ),
                            ),
                            liked == null
                                ? Container()
                                : IconButton(
                                    color: liked! ? Colors.orange : Colors.grey,
                                    onPressed: () {
                                      if (liked == false) {
                                        likeItem(widget.item["item_id"]
                                                .toString())
                                            .then((v) {
                                          _isLiked();
                                        });
                                      } else {
                                        dislikeItem(widget.item["item_id"]
                                                .toString())
                                            .then((v) {
                                          _isLiked();
                                        });
                                      }
                                    },
                                    icon: Icon(liked!
                                        ? Icons.favorite
                                        : Icons.favorite_border))
                          ],
                        ),
                      ),
                      ExpansionTile(
                        iconColor: Colors.white,
                        textColor: Colors.white,
                        title: Text("Подробнее"),
                        children: [
                          _properties.isNotEmpty
                              ? Container(
                                  padding: EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Text(
                                      //   "Характеристики",
                                      //   style: TextStyle(
                                      //     color: Theme.of(context)
                                      //         .colorScheme
                                      //         .onSurface,
                                      //     fontWeight: FontWeight.bold,
                                      //     fontSize: 24,
                                      //   ),
                                      // ),
                                      ListView.builder(
                                        primary: false,
                                        shrinkWrap: true,
                                        itemCount: _properties.length,
                                        itemBuilder: (context, index) {
                                          return Container(
                                            alignment: Alignment.bottomCenter,
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: _properties[index]
                                                                ["name"] ==
                                                            null ||
                                                        _properties[index]
                                                                ["value"] ==
                                                            null
                                                    ? BorderSide.none
                                                    : BorderSide(
                                                        color: Colors
                                                            .grey.shade200,
                                                        width: 1),
                                              ),
                                            ),
                                            child: _properties[index]["name"] ==
                                                        null ||
                                                    _properties[index]
                                                            ["value"] ==
                                                        null
                                                ? Container()
                                                : Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                            _properties[index]
                                                                ["name"]),
                                                      ),
                                                      Flexible(
                                                        child: Text(
                                                          _properties[index]
                                                              ["value"],
                                                          textAlign:
                                                              TextAlign.end,
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                          );
                                        },
                                      )
                                    ],
                                  ),
                                )
                              : Container(),
                        ],
                      ),
                      addItems.length == 0
                          ? Container()
                          : Column(
                              children: [
                                Container(
                                    padding: EdgeInsets.all(10),
                                    child: Row(
                                      children: [
                                        Text(
                                          "Рекомендуем",
                                          style: GoogleFonts.roboto(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18),
                                        ),
                                      ],
                                    )),
                                Container(
                                    padding: EdgeInsets.all(10),
                                    child: GridView.builder(
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                                childAspectRatio: 8 / 12,
                                                mainAxisSpacing: 10,
                                                crossAxisSpacing: 10,
                                                crossAxisCount: 2),
                                        primary: false,
                                        shrinkWrap: true,
                                        itemCount: addItems.length,
                                        itemBuilder: (context, index2) {
                                          final Map<String, dynamic> item =
                                              addItems[index2];
                                          return ItemCard2(
                                            item: item,
                                            business: widget.business,
                                          );
                                        })),
                              ],
                            ),
                      recItems.length == 0
                          ? Container()
                          : Column(
                              children: [
                                Container(
                                    padding: EdgeInsets.all(10),
                                    child: Row(
                                      children: [
                                        Text(
                                          "Также берут",
                                          textAlign: TextAlign.start,
                                          style: GoogleFonts.roboto(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18),
                                        ),
                                      ],
                                    )),
                                Container(
                                    padding: EdgeInsets.all(10),
                                    child: GridView.builder(
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                                childAspectRatio: 8 / 12,
                                                mainAxisSpacing: 10,
                                                crossAxisSpacing: 10,
                                                crossAxisCount: 2),
                                        primary: false,
                                        shrinkWrap: true,
                                        itemCount: recItems.length,
                                        itemBuilder: (context, index2) {
                                          final Map<String, dynamic> item =
                                              recItems[index2];
                                          return ItemCard2(
                                            item: item,
                                            business: widget.business,
                                          );
                                        })),
                              ],
                            ),
                      SizedBox(
                        height: 1000,
                      )
                    ],
                  ),
                ),
              )),
        );
      },
    );
  }
}
