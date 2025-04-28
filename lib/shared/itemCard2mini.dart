import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:naliv_delivery/globals.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/databaseapi.dart';
import 'package:naliv_delivery/shared/itemPage.dart';
import 'package:vibration/vibration.dart';

class ItemCard2mini extends StatefulWidget {
  const ItemCard2mini({super.key, required this.item, required this.business});
  final Map item;
  final Map business;
  @override
  State<ItemCard2mini> createState() => _ItemCard2miniState();
}

class _ItemCard2miniState extends State<ItemCard2mini> {
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
      //print(v);
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
          //print(v);
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
          //print(v);
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
          //print(onData);
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
    return GestureDetector(
      onTap: () {
        Navigator.push(context, CupertinoPageRoute(builder: (context) {
          return ItemPage(
            item: widget.item,
            business: widget.business,
          );
        }));
      },
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(15),
              ),
              margin: EdgeInsets.all(5),
              child: Column(
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 11,
                        child: CachedNetworkImage(
                          fit: BoxFit.cover,
                          imageUrl: widget.item["img"] ?? "/",
                          placeholder: (context, url) => Center(
                            child: CupertinoActivityIndicator(),
                          ),
                          errorWidget: (context, url, error) =>
                              Icon(CupertinoIcons.exclamationmark_triangle),
                        ),
                      ),
                      AspectRatio(
                        aspectRatio: 16 / 11,
                        child: Container(
                          padding: EdgeInsets.all(10),
                          alignment: Alignment.bottomLeft,
                          child: widget.item["promotions"] == null
                              ? Container()
                              : Container(
                                  padding: EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemBackground,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    CupertinoIcons.gift,
                                    color: CupertinoColors.activeOrange,
                                  ),
                                ),
                        ),
                      ),
                      if (currentAmount > 0)
                        Container(
                          alignment: Alignment.topRight,
                          child: Container(
                            padding: EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: CupertinoColors.activeOrange,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(10),
                              ),
                            ),
                            child: Text(
                              formatQuantity(
                                  currentAmount, widget.item["unit"]),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  AspectRatio(
                    aspectRatio: 16 / 5,
                    child: Container(
                      padding: EdgeInsets.all(5),
                      child: Text(
                        widget.item["name"],
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
