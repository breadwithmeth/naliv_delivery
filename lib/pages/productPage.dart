import 'dart:async';
import 'dart:convert';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vibration/vibration.dart';

class ProductPage extends StatefulWidget {
  const ProductPage(
      {super.key,
      required this.item,
      required this.index,
      required this.business,
      this.returnDataAmount,
      this.returnDataAmountSearchPage,
      this.cartPageExclusiveCallbackFunc,
      this.cartItemId,
      this.openedFromCart = false,
      this.dontClearOptions = false,
      required this.promotions});
  final Map<String, dynamic> item;
  final int index;
  final Function(List)? returnDataAmount; // NEW_AMOUNT, INDEX, MAP of cart item
  final Function(int, int)? returnDataAmountSearchPage; // NEW_AMOUNT, INDEX
  final Function(int, double)? cartPageExclusiveCallbackFunc;
  final Map<dynamic, dynamic> business;
  final int? cartItemId;
  final bool openedFromCart;
  final bool dontClearOptions;
  final List promotions;
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late Map<String, dynamic> item = widget.item;
  List<Widget> groupItems = [];
  List<TableRow> properties = [];
  List<Widget> propertiesWidget = [];

  int currentTab = 0;
  String? amount;
  List<String> TabText = ["", "", ""];
  List options = [];
  // bool isDescriptionLoaded = false;

  Future<void> _getItem() async {
    await getItem(widget.item["item_id"], widget.business["business_id"])
        .then((value) {
      // // print(value);
      if (value.isNotEmpty) {
        setState(() {
          options = value["item_options"] ?? [];
          TabText[0] = value["description"];
        });
      }
    });
  }

  // BUTTON VARIABLES/FUNCS START

  double amountInCart = 0;
  double actualCartAmount = 0;
  double optionsAddedCost = 0;
  double actualOptionsAddedCost = 0;
  double parentItemMultiplier = 1;
  double actualItemMultiplier = 1;
  double quantity = 1;
  int? actualRequiredSelected;
  int? requiredSelected;
  // int lastReturnedDataAmount = 0;

  bool isServerCallOnGoing = false;
  bool isLastServerCallWasSucceed = false;
  bool isRequiredSelected = false;

  Map<String, String> buyButtonActionTextMap = {
    "add": "Добавить",
    "remove": "Убрать всё",
    "update": "Обновить",
    "loading": "Загружаю.."
  };
  late String buyButtonActionText;
  late Color buyButtonActionColor;
  double inStock = 0.0;
  List newCart = [];

  Widget optionSelector = Container();

  Future<bool> _deleteFromCart(String itemId) async {
    bool? result = await deleteFromCart(itemId);
    result ??= false;

    // // print(result);
    return Future(() => result!);
  }

  void _checkOptions() {
    for (var i = 0; i < options.length; i++) {
      if (options[i]["selection"] == "SINGLE") {
        if (options[i]["selected_relation_id"] != null) {
          setState(() {
            isRequiredSelected = true;
          });
          return;
        }
        // if (!widget.dontClearOptions) {
        //   setState(() {
        //     options[i]["selected_relation_id"] = null;
        //   });
        // }
      } else {
        // if (!widget.dontClearOptions) {
        //   setState(() {
        //     options[i]["selected_relation_id"] = [];
        //   });
        // }
      }
    }
    setState(() {
      isRequiredSelected = false;
    });
    return;
  }

  initOptionSelector() {
    setState(() {
      options = widget.item["options"];
    });
    print("HELLO");

    if (widget.dontClearOptions) {
      amountInCart = widget.item["cart"][widget.cartItemId!]["amount"];
    }

    for (var i = 0; i < options.length; i++) {
      if (options[i]["selection"] == "SINGLE") {
        if (!widget.dontClearOptions) {
          setState(() {
            options[i]["selected_relation_id"] = null;
            optionsAddedCost = 0;
            actualOptionsAddedCost = double.parse(optionsAddedCost.toString());
          });
        } else {
          if (options[i]["selected_relation_id"] != null) {
            setState(() {
              requiredSelected = options[i]["selected_relation_id"];
              actualRequiredSelected = requiredSelected;
              isRequiredSelected = true;
            });
          }
        }
      } else {
        if (!widget.dontClearOptions) {
          setState(() {
            options[i]["selected_relation_id"] = [];
          });
        }
      }
    }
  }

  Future<void> _finalizeCartAmount() async {
    setState(() {
      isServerCallOnGoing = true;
      isLastServerCallWasSucceed = false;
    });
    await changeCartItem(
            item["item_id"], amountInCart, widget.business["business_id"],
            options: options)
        .then(
      (value) {
        if (value != null) {
          if (options.isEmpty) {
            setState(() {
              newCart = [
                value.firstWhere(
                  (el) => el["item_id"] == widget.item["item_id"],
                  orElse: () => [],
                )
              ];
              if (newCart[0].isEmpty) {
                actualCartAmount = 0;
              } else {
                actualCartAmount =
                    double.parse(newCart[0]["amount"].toString());
              }
            });
          } else {
            setState(() {
              newCart = value
                  .where((el) => el["item_id"] == widget.item["item_id"])
                  .toList();
            });
            print("asdasd");
          }
          if (widget.returnDataAmount != null) {
            widget.returnDataAmount!(newCart);
          }
          getBuyButtonCurrentActionText();
          Navigator.pop(context);
          // if (options.isNotEmpty) {
          // }
        }
      },
    );
    // ).onError(
    //   (error, stackTrace) {
    //     // print(int.parse(widget.item["amount"]));
    //     widget.returnDataAmount!(
    //         int.parse(widget.item["amount"]), widget.index);
    //     if (widget.cartPageExclusiveCallbackFunc != null) {
    //       widget.cartPageExclusiveCallbackFunc!(
    //           widget.index, int.parse(widget.item["amount"]));
    //     }
    //     throw Exception("Ошибка в _finalizeCartAmount ProductPage");
    //   },
    // );
    if (mounted) {
      setState(() {
        isServerCallOnGoing = false;
      });
    }
  }

  void _removeFromCart() {
    setState(() {
      if (((amountInCart * parentItemMultiplier) -
              (quantity * parentItemMultiplier)) >
          0) {
        amountInCart -= quantity;
        amountInCart = double.parse(amountInCart.toStringAsFixed(3));
        getBuyButtonCurrentActionText();
      } else {
        amountInCart = 0;
        getBuyButtonCurrentActionText();
      }
    });
  }

  void _addToCart() {
    setState(() {
      if (((amountInCart * parentItemMultiplier) +
              (quantity * parentItemMultiplier)) <=
          widget.item["in_stock"]) {
        amountInCart += quantity;
        amountInCart = double.parse(amountInCart.toStringAsFixed(3));
        getBuyButtonCurrentActionText();
      }
    });
  }

  void getBuyButtonCurrentActionText() {
    if (actualCartAmount == 0) {
      setState(() {
        buyButtonActionText =
            "${buyButtonActionTextMap["add"]!} ${globals.formatCost(((amountInCart * item["price"] * parentItemMultiplier) + (optionsAddedCost * amountInCart)).toString())} ₸";
        buyButtonActionColor = Colors.black;
      });
    } else if ((amountInCart > 0) && (actualCartAmount != amountInCart)) {
      setState(() {
        buyButtonActionText =
            "${buyButtonActionTextMap["update"]!} ${globals.formatCost(((amountInCart * item["price"] * parentItemMultiplier) + (optionsAddedCost * amountInCart)).toString())} ₸";
        buyButtonActionColor = Colors.blueGrey;
      });
    } else if ((actualCartAmount == amountInCart &&
            requiredSelected == actualRequiredSelected) ||
        amountInCart == 0) {
      setState(() {
        buyButtonActionText =
            "${buyButtonActionTextMap["remove"]!} ${globals.formatCost(((actualCartAmount * item["price"] * actualItemMultiplier) + (actualOptionsAddedCost * amountInCart)).toString())} ₸";
        buyButtonActionColor = Colors.red;
      });
    } else {
      setState(() {
        buyButtonActionText =
            "${buyButtonActionTextMap["update"]!} ${globals.formatCost(((amountInCart * item["price"] * parentItemMultiplier) + (optionsAddedCost * amountInCart)).toString())} ₸";
        buyButtonActionColor = Colors.blueGrey;
      });
    }
  }

  double _startPositionY = 0;

  void _onLongPressStart(LongPressStartDetails details) {
    _startPositionY = details.globalPosition.dy;
    Vibration.vibrate(duration: 100);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) async {
    double dy = details.globalPosition.dy - _startPositionY;

    if (dy.abs() >= 50 * globals.scaleParam) {
      setState(() {
        if (dy > 0 &&
            ((amountInCart * parentItemMultiplier) -
                    (quantity * parentItemMultiplier)) >=
                0) {
          HapticFeedback.lightImpact();
          amountInCart -= quantity; // Swiping down decrements
          amountInCart = double.parse(amountInCart.toStringAsFixed(3));
        } else if (dy < 0 &&
            ((amountInCart * parentItemMultiplier) +
                    (quantity * parentItemMultiplier)) <=
                item["in_stock"]) {
          HapticFeedback.lightImpact();
          amountInCart += quantity; // Swiping up increments
          amountInCart = double.parse(amountInCart.toStringAsFixed(3));
        }
        _startPositionY = details.globalPosition.dy;
        getBuyButtonCurrentActionText();
      });

      // HapticFeedback.heavyImpact();
      // HapticFeedback.lightImpact();
      // HapticFeedback.mediumImpact();
      // HapticFeedback.selectionClick();
      // HapticFeedback.vibrate();
    }
  }

  // BUTTON VARIABLES/FUNCS END

  @override
  void initState() {
    super.initState();
    if (widget.item["options"] != null) {
      if (!widget.dontClearOptions) {
        setState(() {
          amountInCart = widget.item["amount"] ?? 1;
          actualCartAmount = 0;
        });
      } else {
        setState(() {
          amountInCart = widget.item["amount"] ?? 1;
          actualCartAmount = amountInCart;

          //! TODO: VERY UNSTABLE IF FIRST OPTION IS NOT REQUIRED ONE, THEN PRICE WOULD BE CALCULATED WRONG!!!!!!!!!!
          optionsAddedCost = widget.item["cart"][widget.cartItemId]
              ["selected_options"][0]["price"];
          actualOptionsAddedCost = double.parse(optionsAddedCost.toString());

          parentItemMultiplier = widget.item["cart"][widget.cartItemId]
                  ["selected_options"][0]["parent_item_amount"] ??
              1;
          actualItemMultiplier = parentItemMultiplier;
        });
      }
      initOptionSelector();
    } else {
      // amountInCart = widget.item["cart"].firstWhere((el) => el["item_id"] == widget.item["item_id"])["amount"];
      if (widget.item["cart"] != [] && widget.item["cart"] != null) {
        if (widget.item["cart"].isNotEmpty) {
          setState(() {
            amountInCart = widget.item["cart"][0]["amount"];
            actualCartAmount = amountInCart;
          });
        }
      } else {
        amountInCart = 1;
        actualCartAmount = 0;
      }
    }
    TabText[0] = widget.item["description"];

    setState(() {
      quantity = item["quantity"];
      if (quantity != 1 &&
          (widget.item["cart"] == [] ||
              widget.item["cart"] == null ||
              widget.item["cart"].isEmpty)) {
        amountInCart = quantity;
      }
    });

    getBuyButtonCurrentActionText();
  }

  @override
  void dispose() {
    if (isServerCallOnGoing && !isLastServerCallWasSucceed) {
      Future.delayed(Duration.zero, () {
        if (widget.cartPageExclusiveCallbackFunc != null) {
          // TODO: Issue here, rewriting needed to work with options
          widget.cartPageExclusiveCallbackFunc!(widget.index, amountInCart);
        }
        // widget.returnDataAmount!(newCart);
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      snap: true,
      expand: false,
      initialChildSize: 0.95,
      maxChildSize: 0.95,
      minChildSize: 0.85,
      shouldCloseOnMinExtent: true,
      snapAnimationDuration: const Duration(milliseconds: 150),
      builder: ((context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            children: [
              Container(
                width: 80 * globals.scaleParam,
                height: 16 * globals.scaleParam,
                margin: EdgeInsets.symmetric(vertical: 35 * globals.scaleParam),
                decoration: BoxDecoration(
                  color:
                      Colors.black, // Change this color to your desired color
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
              // SizedBox(
              //   height: 20 * globals.scaleParam,
              // ),
              Expanded(
                child: _productPage(context, scrollController),
              ),
            ],
          ),
        );
        // return Container(
        //   decoration: BoxDecoration(
        //     borderRadius: BorderRadius.only(
        //       topLeft: Radius.circular(30),
        //       topRight: Radius.circular(30),
        //     ),
        //   ),
        // child: _productPage(context, scrollController),
        // );
      }),
    );
  }

  Widget buildPromotions() {
    return ListView.builder(
      primary: false,
      shrinkWrap: true,
      itemCount: widget.promotions.length,
      itemBuilder: (context, index) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              // color: Colors.black,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                      Radius.circular(15 * globals.scaleParam)),
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.purpleAccent,
                      Color(0xFFFFC837),
                    ],
                  )),
              padding: EdgeInsets.all(10 * globals.scaleParam),
              margin: EdgeInsets.all(0 * globals.scaleParam),
              child: Text(widget.promotions[index]["name"],
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 32 * globals.scaleParam)),
            )
          ],
        );
      },
    );
  }

  Scaffold _productPage(
      BuildContext context, ScrollController scrollController) {
    return Scaffold(
        backgroundColor: Colors.white,
        // color: Colors.white,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: SlideTransition(
          position: const AlwaysStoppedAnimation(Offset(0, -0.25)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (options.isNotEmpty && !isRequiredSelected) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: SizedBox(
                    width: constraints.maxWidth * 0.95,
                    height: 125 * globals.scaleParam,
                    child: Row(
                      children: [
                        MediaQuery.sizeOf(context).width >
                                MediaQuery.sizeOf(context).height
                            ? const Flexible(
                                flex: 8,
                                fit: FlexFit.tight,
                                child: SizedBox(),
                              )
                            : const SizedBox(),
                        Flexible(
                          flex: 5,
                          fit: FlexFit.tight,
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.black,
                                boxShadow: const [
                                  BoxShadow(
                                    offset: Offset(3, 5),
                                    color: Colors.black38,
                                    blurRadius: 5,
                                  )
                                ],
                                borderRadius: BorderRadius.all(
                                    Radius.circular(30 * globals.scaleParam))),
                            alignment: Alignment.center,
                            child: Text(
                              "Выберите опцию",
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontSize: 48 * globals.scaleParam),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                return Container(
                  width: constraints.maxWidth * 0.95,
                  height: 125 * globals.scaleParam,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            flex: 8,
                            fit: FlexFit.tight,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10 * globals.scaleParam),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  boxShadow: const [
                                    BoxShadow(
                                      offset: Offset(3, 5),
                                      color: Colors.black26,
                                      blurRadius: 5,
                                    )
                                  ],
                                  borderRadius: BorderRadius.all(
                                      Radius.circular(30 * globals.scaleParam)),
                                ),
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(8)),
                                  clipBehavior: Clip.antiAliasWithSaveLayer,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onLongPressStart: _onLongPressStart,
                                    onLongPressMoveUpdate:
                                        _onLongPressMoveUpdate,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          fit: FlexFit.tight,
                                          child: IconButton(
                                            padding: const EdgeInsets.all(0),
                                            onPressed: () {
                                              _removeFromCart();
                                            },
                                            icon: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    const BorderRadius.all(
                                                  Radius.circular(100),
                                                ),
                                                color: Colors.grey.shade400,
                                              ),
                                              child: Icon(
                                                Icons.remove_rounded,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Flexible(
                                          fit: FlexFit.tight,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      "${amountInCart.ceil() > amountInCart ? amountInCart : amountInCart.round()}",
                                                      textHeightBehavior:
                                                          const TextHeightBehavior(
                                                        applyHeightToFirstAscent:
                                                            false,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 36 *
                                                            globals.scaleParam,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface,
                                                        height: parentItemMultiplier !=
                                                                    1 ||
                                                                quantity != 1 ||
                                                                options
                                                                    .isNotEmpty
                                                            ? 2 *
                                                                globals
                                                                    .scaleParam
                                                            : null,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    widget.item["options"] !=
                                                            null
                                                        ? "бут"
                                                        : "",
                                                    textHeightBehavior:
                                                        const TextHeightBehavior(
                                                      applyHeightToFirstAscent:
                                                          false,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 32 *
                                                          globals.scaleParam,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface,
                                                      height:
                                                          parentItemMultiplier !=
                                                                      1 ||
                                                                  quantity !=
                                                                      1 ||
                                                                  options
                                                                      .isNotEmpty
                                                              ? 1 *
                                                                  globals
                                                                      .scaleParam
                                                              : null,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              parentItemMultiplier != 1 ||
                                                      quantity != 1 ||
                                                      options.isNotEmpty
                                                  ? Text(
                                                      "${amountInCart.ceil() > amountInCart ? amountInCart * parentItemMultiplier : amountInCart.round() * parentItemMultiplier} ${quantity != 1 ? "кг" : item["unit"]}",
                                                      textHeightBehavior:
                                                          const TextHeightBehavior(
                                                        applyHeightToFirstAscent:
                                                            false,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 26 *
                                                            globals.scaleParam,
                                                        color: Colors
                                                            .grey.shade600,
                                                        height: 1 *
                                                            globals.scaleParam,
                                                      ),
                                                    )
                                                  : const SizedBox(),
                                            ],
                                          ),
                                        ),
                                        Flexible(
                                          fit: FlexFit.tight,
                                          child: IconButton(
                                            padding: const EdgeInsets.all(0),
                                            // onPressed: null,
                                            onPressed: () {
                                              _addToCart();
                                            },
                                            icon: Container(
                                              padding: EdgeInsets.all(
                                                  5 * globals.scaleParam),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    const BorderRadius.all(
                                                  Radius.circular(100),
                                                ),
                                                color: Colors.grey.shade400,
                                              ),
                                              child: Icon(
                                                Icons.add_rounded,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Flexible(
                            flex: 10,
                            fit: FlexFit.tight,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10 * globals.scaleParam),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: buyButtonActionColor,
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed:
                                    (isRequiredSelected && amountInCart > 0) ||
                                            actualCartAmount > 0 ||
                                            options.isEmpty
                                        ? () {
                                            if (actualCartAmount == 0) {
                                              _finalizeCartAmount();
                                            } else if (actualCartAmount ==
                                                    amountInCart ||
                                                amountInCart == 0) {
                                              setState(() {
                                                amountInCart = 0;
                                              });
                                              _finalizeCartAmount();
                                            } else {
                                              _finalizeCartAmount();
                                            }
                                          }
                                        : null,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        offset: Offset(3, 5),
                                        color: Colors.black38,
                                        blurRadius: 5,
                                      )
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            fit: FlexFit.tight,
                                            child: Text(
                                              buyButtonActionText,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize:
                                                    38 * globals.scaleParam,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),
        body: Container(
          clipBehavior: Clip.antiAliasWithSaveLayer,
          // margin: EdgeInsets.only(left: 10, right: 10),
          decoration: BoxDecoration(
              color: Colors.grey.shade50,

              // color: Colors.amber,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30), topRight: Radius.circular(30))),
          child: ListView(
            controller: scrollController,
            children: [
              Container(
                margin: const EdgeInsets.only(
                  bottom: 5,
                ),
                clipBehavior: Clip.none,
                decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                          offset: const Offset(0, 2),
                          blurRadius: 10,
                          color: Colors.blueGrey.shade50)
                    ],
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30))),
                padding: EdgeInsets.all(20 * globals.scaleParam),
                child: Column(
                  children: [
                    Container(
                      clipBehavior: Clip.none,
                      // width: MediaQuery.sizeOf(context).width * 0.5,
                      // height: MediaQuery.sizeOf(context).height * 0.5,
                      alignment: Alignment.center,
                      child: GestureDetector(onTap: () {
                        showDialog(
                          useSafeArea: true,
                          context: context,
                          builder: (context) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              onDoubleTap: () {},
                              child: Dialog.fullscreen(
                                backgroundColor: Colors.black12,
                                child: LayoutBuilder(
                                    builder: (context, constraints) {
                                  return Stack(
                                    children: [
                                      Container(
                                        clipBehavior: Clip.none,
                                        alignment: Alignment.center,
                                        width:
                                            MediaQuery.of(context).size.width,
                                        height:
                                            MediaQuery.of(context).size.height,
                                        child: InteractiveViewer(
                                          // constrained: false,
                                          panEnabled: true,
                                          boundaryMargin: EdgeInsets.all(
                                              100 * globals.scaleParam),
                                          minScale: 1,
                                          maxScale: 5,
                                          child: ExtendedImage.network(
                                            item["img"],
                                            width: double.infinity,
                                            height: constraints.maxHeight,
                                            // mode: ExtendedImageMode.gesture,
                                            // initGestureConfigHandler: (state) {
                                            //   return GestureConfig(
                                            //     minScale: 0.8,
                                            //     maxScale: 3.0,
                                            //     speed: 1.0,
                                            //     inertialSpeed: 100.0,
                                            //   );
                                            // },
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.all(
                                            20 * globals.scaleParam),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              style: IconButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.white54),
                                              onPressed: () {
                                                Navigator.pop(context);
                                              },
                                              icon: const Icon(
                                                Icons.close_fullscreen_rounded,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            );
                          },
                        );
                      }, child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                              width: constraints.maxWidth,
                              height: constraints.maxWidth,
                              // margin: EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(15),
                                ),
                              ),
                              clipBehavior: Clip.antiAliasWithSaveLayer,
                              child: Stack(
                                children: [
                                  ExtendedImage.network(
                                    item["img"],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    // mode: ExtendedImageMode.gesture,
                                    // initGestureConfigHandler: (state) {
                                    //   return GestureConfig(
                                    //     minScale: 0.8,
                                    //     maxScale: 3.0,
                                    //     speed: 1.0,
                                    //     inertialSpeed: 100.0,
                                    //   );
                                    // },
                                  ),
                                ],
                              ));
                        },
                      )),
                    ),
                    item.isNotEmpty
                        ? Container(
                            // color: Colors.grey.shade50,
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 1 *
                                  (MediaQuery.sizeOf(context).height / 1080),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 5 * globals.scaleParam,
                                ),
                                buildPromotions(),
                                Text(
                                  item["name"] ?? "",
                                  style: GoogleFonts.inter(
                                      fontSize: 54 * globals.scaleParam,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                      letterSpacing: 0),
                                ),
                                SizedBox(
                                  height: 5 * globals.scaleParam,
                                ),
                                Padding(
                                  padding: EdgeInsets.only(
                                      left: 0 * globals.scaleParam),
                                  child: Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              globals.formatCost(
                                                  (item['price'] ?? '')
                                                      .toString()),
                                              style: GoogleFonts.inter(
                                                fontSize:
                                                    86 * globals.scaleParam,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                          Flexible(
                                            child: Text(
                                              "₸",
                                              style: GoogleFonts.inter(
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w900,
                                                fontSize:
                                                    86 * globals.scaleParam,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      //* NO MORE IN_STOCK CHANGE
                                      // Row(
                                      //   children: [
                                      //     Flexible(
                                      //       child: Text(
                                      //         // Automatically sets units of choice
                                      //         item["unit"] != "шт"
                                      //             ? "В наличии: ${(item['in_stock'] ?? "")} ${item["unit"]}"
                                      //             : item["quantity"] != 1
                                      //                 ? "В наличии: ${item["in_stock"]} кг"
                                      //                 : "В наличии: ${(item["in_stock"]).round()} ${item["unit"]}",
                                      //         style: TextStyle(
                                      //           fontSize: 28 * globals.scaleParam,
                                      //           fontWeight: FontWeight.w700,
                                      //           color: Theme.of(context).colorScheme.secondary,
                                      //         ),
                                      //       ),
                                      //     ),
                                      //   ],
                                      // ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        // TODO: Maybe not even needed anymore, content inside productPage loads immediately because data recieved from categoryPage
                        : Shimmer.fromColors(
                            baseColor: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withOpacity(0.05),
                            highlightColor:
                                Theme.of(context).colorScheme.secondary,
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.8,
                              height: 40,
                              color: Colors.white,
                            ),
                          ),
                  ],
                ),
              ),

              //! Options
              Container(
                padding: EdgeInsets.symmetric(
                    vertical: 5 * globals.scaleParam,
                    horizontal: 25 * globals.scaleParam),
                // color: Colors.grey.shade100,
                child: ListView(
                  primary: false,
                  shrinkWrap: true,
                  children: [
                    ListView.builder(
                      primary: false,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, indexOption) {
                        return Container(
                          // padding: EdgeInsets.only(
                          //     left: 30 * globals.scaleParam,
                          //     right: 30 * globals.scaleParam),
                          margin: EdgeInsets.only(
                              left: 15 * globals.scaleParam,
                              right: 15 * globals.scaleParam),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    options[indexOption]["name"],
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 48 * globals.scaleParam),
                                  ),
                                  options[indexOption]["required"] == 1
                                      ? Container(
                                          // color: Colors.white,
                                          child: Text(
                                            "Обязательно",
                                            style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.w700,
                                                fontSize:
                                                    36 * globals.scaleParam),
                                          ),
                                        )
                                      : Container(),
                                ],
                              ),
                              ListView.builder(
                                primary: false,
                                shrinkWrap: true,
                                itemCount:
                                    options[indexOption]["options"].length,
                                itemBuilder: (context, index) {
                                  return options[indexOption]["selection"] ==
                                          "SINGLE"
                                      ? Row(
                                          children: [
                                            Flexible(
                                                child: Theme(
                                              data: ThemeData(
                                                  canvasColor:
                                                      Colors.transparent),
                                              child: ChoiceChip(
                                                  showCheckmark: true,
                                                  // side: BorderSide.none,
                                                  shape: const StadiumBorder(
                                                    side: BorderSide(
                                                        color: Colors.grey,
                                                        width: 1),
                                                  ),
                                                  // avatar: const Icon(
                                                  //     Icons.circle_outlined),
                                                  // avatarBorder:
                                                  //     RoundedRectangleBorder(),

                                                  // selectedColor: Colors
                                                  //     .amberAccent.shade200,

                                                  disabledColor:
                                                      Colors.transparent,
                                                  backgroundColor:
                                                      Colors.grey.shade100,
                                                  checkmarkColor: Colors.black,
                                                  selectedColor: Colors.white,
                                                  surfaceTintColor:
                                                      Colors.white,
                                                  shadowColor: Colors.white,
                                                  color: WidgetStateColor
                                                      .transparent,
                                                  selectedShadowColor:
                                                      Colors.transparent,
                                                  
                                                  label: Text(
                                                    "${globals.formatCost(options[indexOption]["options"][index]["price"].toString())}₸  ${options[indexOption]["options"][index]["name"]}",
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700),
                                                  ),
                                                  selected: options[indexOption]
                                                          [
                                                          "selected_relation_id"] ==
                                                      options[indexOption]
                                                              ["options"][index]
                                                          ["relation_id"],
                                                  onSelected: (v) {
                                                    // print(v);
                                                    print(options);
                                                    if (v) {
                                                      setState(() {
                                                        options[indexOption][
                                                                "selected_relation_id"] =
                                                            options[indexOption]
                                                                        [
                                                                        "options"]
                                                                    [index]
                                                                ["relation_id"];
                                                        requiredSelected =
                                                            options[indexOption]
                                                                        [
                                                                        "options"]
                                                                    [index]
                                                                ["relation_id"];
                                                        optionsAddedCost =
                                                            options[indexOption]
                                                                    ["options"][
                                                                index]["price"];
                                                        parentItemMultiplier =
                                                            options[indexOption]
                                                                        [
                                                                        "options"]
                                                                    [index][
                                                                "parent_item_amount"];
                                                        if (amountInCart *
                                                                parentItemMultiplier >
                                                            widget.item[
                                                                "in_stock"]) {
                                                          amountInCart = (widget
                                                                          .item[
                                                                      "in_stock"] /
                                                                  parentItemMultiplier)
                                                              .truncateToDouble();
                                                        }
                                                      });
                                                    } else {
                                                      setState(() {
                                                        options[indexOption][
                                                                "selected_relation_id"] =
                                                            null;
                                                        requiredSelected = null;
                                                        optionsAddedCost = 0;
                                                        parentItemMultiplier =
                                                            1;
                                                      });

                                                      // setState(() {
                                                      //   amountInCart = 0;
                                                      // });
                                                      // _finalizeCartAmount();
                                                    }
                                                    _checkOptions();
                                                    getBuyButtonCurrentActionText();
                                                  }
                                                  // dense: true,
                                                  //   onChanged: (v) {

                                                  //   },
                                                  //   groupValue: options[index_option]
                                                  //       ["selected_relation_id"],
                                                  //   value: options[index_option]
                                                  //           ["options"][index]
                                                  //       ["relation_id"],
                                                  //
                                                  ),
                                            ))
                                          ],
                                        )
                                      : Container(
                                          alignment: Alignment.centerLeft,
                                          decoration: const BoxDecoration(
                                              // boxShadow: [
                                              //   BoxShadow(
                                              //       offset: Offset(2, 2),
                                              //       blurRadius: 5,
                                              //       color: Colors.grey.shade400)
                                              // ],
                                              // color: Colors.white,
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(15))),
                                          // margin: EdgeInsets.all(10 * globals.scaleParam),
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: FilterChip(
                                                  backgroundColor: Colors.white,
                                                  deleteIcon: Container(),
                                                  // deleteIconBoxConstraints: BoxConstraints(),
                                                  label: Text(
                                                    options[indexOption]["options"]
                                                                        [index]
                                                                    ["price"] !=
                                                                null &&
                                                            options[indexOption]
                                                                            [
                                                                            "options"]
                                                                        [index]
                                                                    ["price"] !=
                                                                0
                                                        ? "${globals.formatCost(options[indexOption]["options"][index]["price"].toString())}₸  ${options[indexOption]["options"][index]["name"]}"
                                                        : options[indexOption]
                                                                ["options"]
                                                            [index]["name"],
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700),
                                                  ),
                                                  selected: List.castFrom(options[
                                                              indexOption][
                                                          "selected_relation_id"])
                                                      .contains(options[
                                                                  indexOption]
                                                              ["options"][index]
                                                          ["relation_id"]),
                                                  onSelected: (v) {
                                                    if (v) {
                                                      setState(() {
                                                        options[indexOption][
                                                                "selected_relation_id"]
                                                            .add(options[indexOption]
                                                                        [
                                                                        "options"]
                                                                    [index][
                                                                "relation_id"]);
                                                      });
                                                    } else {
                                                      setState(() {
                                                        options[indexOption][
                                                                "selected_relation_id"]
                                                            .removeWhere((item) =>
                                                                item ==
                                                                options[indexOption]
                                                                            [
                                                                            "options"]
                                                                        [index][
                                                                    "relation_id"]);
                                                      });
                                                    }
                                                    _checkOptions();
                                                    getBuyButtonCurrentActionText();
                                                  },
                                                  onDeleted: () {},
                                                  // value: isCheckBoxSelected,
                                                  // onChanged: (v) {}
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                },
                              )
                            ],
                          ),
                        );
                      },
                    ),
                    item["group"] != null
                        ? Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20 * globals.scaleParam),
                            height: 50,
                            width: MediaQuery.of(context).size.width,
                            child: ListView(
                              primary: false,
                              shrinkWrap: true,
                              scrollDirection: Axis.horizontal,
                              children: groupItems,
                            ),
                          )
                        : Container(),
                    // const SizedBox(
                    //   height: 5,
                    // ),

                    Stack(
                      children: [
                        // Container(
                        //   height: 25,
                        //   padding: EdgeInsets.symmetric(
                        //       horizontal: 30 * scale_param),
                        //   decoration: BoxDecoration(
                        //     boxShadow: [
                        //       BoxShadow(
                        //           color: Colors.grey.withOpacity(0.15),
                        //           offset: const Offset(0, -1),
                        //           blurRadius: 15,
                        //           spreadRadius: 1)
                        //     ],
                        //     border: Border(
                        //       bottom: BorderSide(color: Colors.grey.shade200, width: 3),
                        //     ),
                        //   ),
                        //   child: const Row(
                        //     children: [],
                        //   ),
                        // ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Flexible(
                              fit: FlexFit.tight,
                              child: GestureDetector(
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        width: 3,
                                        color: currentTab == 0
                                            ? Colors.black
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    "Описание",
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 32 * globals.scaleParam),
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    currentTab = 0;
                                  });
                                },
                              ),
                            ),
                            Flexible(
                              fit: FlexFit.tight,
                              child: GestureDetector(
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        width: 3,
                                        color: currentTab == 1
                                            ? Colors.black
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    "О бренде",
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 32 * globals.scaleParam),
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    currentTab = 1;
                                  });
                                },
                              ),
                            ),
                            Flexible(
                              fit: FlexFit.tight,
                              child: GestureDetector(
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        width: 3,
                                        color: currentTab == 2
                                            ? Colors.black
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    "Производитель",
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 32 * globals.scaleParam),
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    currentTab = 2;
                                  });
                                },
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.all(30 * globals.scaleParam),
                      child: Text(
                        TabText[currentTab],
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w400,
                          fontSize: 34 * globals.scaleParam,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(30 * globals.scaleParam),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(),
                          1: FlexColumnWidth()
                        },
                        border: TableBorder(
                            horizontalInside: BorderSide(
                                width: 1, color: Colors.grey.shade400),
                            bottom: BorderSide(
                                width: 1, color: Colors.grey.shade400)),
                        children: properties,
                      ),
                    ),
                    const SizedBox(
                      height: 100,
                    )
                  ],
                ),
              )
            ],
          ),
        ));
  }
}
