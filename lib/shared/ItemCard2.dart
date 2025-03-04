import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:naliv_delivery/globals.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/databaseapi.dart';
import 'package:naliv_delivery/shared/itemPage.dart';
import 'package:vibration/vibration.dart';
import 'package:vibration/vibration_presets.dart';

class ItemCard2 extends StatefulWidget {
  const ItemCard2({super.key, required this.item, required this.business});
  final Map item;
  final Map business;
  @override
  State<ItemCard2> createState() => _ItemCard2State();
}

class _ItemCard2State extends State<ItemCard2> {
  Map<String, dynamic>? cartItem = null;
  double currentAmount = 0;
  DatabaseManager dbm = DatabaseManager();

  List? options = null;

  double? parentItemAmoint = null;
  double quantity = 1;

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
    print(widget.item);
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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    updateOptions();
    getCurrentAmount();
    dbm.cartUpdates.listen((onData) {
      if (onData != null) {
        if (onData!["item_id"] == widget.item["item_id"]) {
          print(onData);
          getCurrentAmount();
        }
      }
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridTile(
        header: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Container(
              margin: EdgeInsets.only(left: 10, bottom: 10),
              decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.only(
                      topRight: Radius.circular(15),
                      bottomLeft: Radius.circular(10))),
              child: AnimatedCrossFade(
                  firstChild: IconButton(
                    onPressed: () async {
                      if (await Vibration.hasVibrator()) {
                        Vibration.vibrate(duration: 50, amplitude: 255);
                      }
                      if (options == null) {
                        addToCart();
                      } else {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) {
                            return Container(
                              color: Colors.black,
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: ListView.builder(
                                primary: false,
                                shrinkWrap: true,
                                itemCount: options!.length,
                                itemBuilder: (context, index) {
                                  List suboptions = options![index]["options"];
                                  return ListView.builder(
                                    shrinkWrap: true,
                                    primary: false,
                                    itemCount: suboptions.length,
                                    itemBuilder: (context, index2) {
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.pop(context);
                                          addToCart(option: suboptions[index2]);
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(15),
                                          margin: EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                              color: Color(0xFF121212),
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(15))),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                suboptions[index2]["name"],
                                                style: GoogleFonts.roboto(),
                                              ),
                                              Text(suboptions[index2]["price"]
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
                        ).then((v) {
                          getCurrentAmount();
                        });
                      }
                    },
                    icon: Icon(
                      Icons.add,
                      color: Colors.black,
                    ),
                  ),
                  secondChild: cartItem == null
                      ? Container()
                      : Row(
                          children: [
                            IconButton(
                                onPressed: () async {
                                  if (parentItemAmoint == null) {
                                    updateAmount(currentAmount - quantity);
                                  } else {
                                    updateAmount(currentAmount -
                                        (quantity * parentItemAmoint!));
                                  }
                                  if (await Vibration.hasVibrator()) {
                                    Vibration.vibrate(
                                        duration: 50, amplitude: 255);
                                  }
                                },
                                icon: Icon(
                                  Icons.remove,
                                  color: Colors.black,
                                )),
                            Text(
                              formatQuantity(
                                  currentAmount, widget.item["unit"]),
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black),
                            ),
                            IconButton(
                                onPressed: () async {
                                  if (parentItemAmoint == null) {
                                    updateAmount(currentAmount + quantity);
                                  } else {
                                    print(parentItemAmoint);
                                    updateAmount(currentAmount +
                                        (quantity * parentItemAmoint!));
                                  }
                                  if (await Vibration.hasVibrator()) {
                                    Vibration.vibrate(
                                        duration: 50, amplitude: 255);
                                  }
                                },
                                icon: Icon(
                                  Icons.add,
                                  color: Colors.black,
                                )),
                          ],
                        ),
                  crossFadeState: cartItem == null
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: Durations.medium1))
        ]),

        // footer: Text("data2"),
        child: GestureDetector(
            onTap: () {
              showModalBottomSheet(
                  isDismissible: true,
                  enableDrag: true,
                  barrierColor: Colors.black.withValues(alpha: 0.8),
                  useSafeArea: true,
                  isScrollControlled: true,
                  context: context,
                  builder: (context) {
                    return ItemPage(
                      item: widget.item,
                      business: widget.business,
                    );
                  });
            },
            child: GestureDetector(
              // onHorizontalDragUpdate: (details) {
              //   print(details);
              // },
              child: Container(
                decoration: BoxDecoration(
                    color: Color(0xFF121212),
                    borderRadius: BorderRadius.all(Radius.circular(15))),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      clipBehavior: Clip.antiAliasWithSaveLayer,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(15))),
                      child: Stack(
                        children: [
                          kIsWeb
                              ? Container()
                              : AspectRatio(
                                  aspectRatio: 1,
                                  child: CachedNetworkImage(
                                    imageUrl: widget.item["img"] ?? "/",
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.error,
                                      color: Colors.red,
                                    ),
                                  )),
                          AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                padding: EdgeInsets.all(10),
                                alignment: Alignment.bottomLeft,
                                child: widget.item["promotions"] == null
                                    ? Container()
                                    : Container(
                                        padding: EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                            boxShadow: [
                                              BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 5,
                                                  offset: Offset(5, 5))
                                            ],
                                            color: Colors.white,
                                            borderRadius: BorderRadius.all(
                                                Radius.circular(500))),
                                        child: Icon(
                                          Icons.card_giftcard,
                                          color: Colors.amber,
                                        ),
                                      ),
                              ))
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.only(left: 10, top: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(),
                          Text(
                            formatPrice(widget.item["price"]),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start,
                            maxLines: 2,
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            widget.item["name"],
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style:
                                GoogleFonts.roboto(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ))
        // title: Text(widget.item["name"]),
        // subtitle: Text(widget.item["price"].toString()),
        // trailing: AspectRatio(
        //   aspectRatio: 1,
        //   child: Image.network(widget.item["img"] ?? "/"),
        // ),
        );
  }
}
