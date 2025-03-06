import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/globals.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/databaseapi.dart';
import 'package:naliv_delivery/shared/itemPage.dart';
import 'package:vibration/vibration.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

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
  void initState() {
    super.initState();
    getCurrentAmount();
    dbm.cartUpdates.listen((onData) {
      if (onData != null) {
        if (onData["item_id"] == widget.item["item_id"]) {
          getCurrentAmount();
        }
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showCupertinoModalPopup(
          context: context,
          builder: (context) => ItemPage(
            item: widget.item,
            business: widget.business,
          ),
        );
      },
      child: AspectRatio(
        aspectRatio: 0.75,
        child: Container(
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemGrey.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  // Изображение и значки
                  Expanded(
                    flex: 4,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(12)),
                          child: CachedNetworkImage(
                            imageUrl: widget.item["img"] ?? "/",
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CupertinoActivityIndicator(),
                            ),
                            errorWidget: (context, url, error) =>
                                Icon(CupertinoIcons.exclamationmark_triangle),
                          ),
                        ),
                        if (widget.item["promotions"] != null)
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemBackground,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                CupertinoIcons.gift,
                                color: CupertinoColors.activeOrange,
                                size: 16,
                              ),
                            ),
                          ),
                        if (currentAmount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: CupertinoColors.activeOrange,
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                              ),
                              child: Text(
                                formatQuantity(
                                    currentAmount, widget.item["unit"]),
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Информация о товаре
                  Container(
                    padding: EdgeInsets.all(8),
                    width: double.infinity, // Добавляем полную ширину
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch, // Растягиваем по ширине
                      children: [
                        Text(
                          formatPrice(widget.item["price"]),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          widget.item["name"],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // if (currentAmount > 0)
              //   Positioned(
              //     right: 8,
              //     bottom: 8,
              //     child: Container(
              //       decoration: BoxDecoration(
              //         color: CupertinoColors.activeOrange,
              //         borderRadius: BorderRadius.circular(8),
              //       ),
              //       child: Row(
              //         mainAxisSize: MainAxisSize.min,
              //         children: [
              //           CupertinoButton(
              //             padding: EdgeInsets.zero,
              //             onPressed: () {
              //               if (parentItemAmoint == null) {
              //                 updateAmount(currentAmount - quantity);
              //               } else {
              //                 updateAmount(currentAmount -
              //                     (quantity * parentItemAmoint!));
              //               }
              //             },
              //             child: Icon(
              //               CupertinoIcons.minus,
              //               color: CupertinoColors.white,
              //               size: 20,
              //             ),
              //           ),
              //           Text(
              //             currentAmount.toString(),
              //             style: TextStyle(
              //               color: CupertinoColors.white,
              //               fontWeight: FontWeight.w600,
              //             ),
              //           ),
              //           CupertinoButton(
              //             padding: EdgeInsets.zero,
              //             onPressed: () {
              //               if (parentItemAmoint == null) {
              //                 updateAmount(currentAmount + quantity);
              //               } else {
              //                 updateAmount(currentAmount +
              //                     (quantity * parentItemAmoint!));
              //               }
              //             },
              //             child: Icon(
              //               CupertinoIcons.plus,
              //               color: CupertinoColors.white,
              //               size: 20,
              //             ),
              //           ),
              //         ],
              //       ),
              //     ),
              //   ),
            ],
          ),
        ),
      ),
    );
  }
}
