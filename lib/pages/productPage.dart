import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:shimmer/shimmer.dart';

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
      this.dontClearOptions = false});
  final Map<String, dynamic> item;
  final int index;
  final Function(List)? returnDataAmount; // NEW_AMOUNT, INDEX, MAP of cart item
  final Function(int, int)? returnDataAmountSearchPage; // NEW_AMOUNT, INDEX
  final Function(int, int)? cartPageExclusiveCallbackFunc;
  final Map<dynamic, dynamic> business;
  final int? cartItemId;
  final bool openedFromCart;
  final bool dontClearOptions;
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late Map<String, dynamic> item = widget.item;
  List<Widget> groupItems = [];
  List<TableRow> properties = [];
  bool isRequired = false;
  List<Widget> propertiesWidget = [];

  int currentTab = 0;
  String? amount;
  List<String> TabText = ["", "", ""];
  List options = [];
  // bool isDescriptionLoaded = false;

  Future<void> _getItem() async {
    await getItem(widget.item["item_id"], widget.business["business_id"]).then((value) {
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

  int amountInCart = 0;
  int actualCartAmount = 0;
  // int lastReturnedDataAmount = 0;

  bool isServerCallOnGoing = false;
  bool isLastServerCallWasSucceed = false;
  bool isRequiredSelected = false;

  Map<String, String> buyButtonActionTextMap = {"add": "Добавить", "remove": "Убрать всё", "update": "Обновить заказ", "loading": "Загружаю.."};
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
    if (options.isEmpty) {
      setState(() {
        isRequired = false;
      });
    } else {
      setState(() {
        isRequired = true;
      });
    }
    print("HELLO");

    if (widget.dontClearOptions) {
      amountInCart = widget.item["cart"][widget.cartItemId!]["amount"];
    }

    for (var i = 0; i < options.length; i++) {
      if (options[i]["selection"] == "SINGLE") {
        if (!widget.dontClearOptions) {
          setState(() {
            options[i]["selected_relation_id"] = null;
          });
        } else {
          if (options[i]["selected_relation_id"] != null) {
            setState(() {
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
    await changeCartItem(item["item_id"], amountInCart, widget.business["business_id"], options: options).then(
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
            });
          } else {
            setState(() {
              newCart = value.where((el) => el["item_id"] == widget.item["item_id"]).toList();
            });
            print("asdasd");
          }
          // setState(() {
          //   newCart = value;
          //   // List newOptions = [];
          //   // for (Map selection in options) {
          //   //   if (selection["selection"] == "SINGLE") {
          //   //     newOptions.add(
          //   //       selection["options"].firstWhere(
          //   //         (element) => element["relation_id"] == selection["selected_relation_id"],
          //   //         orElse: () => null,
          //   //       ),
          //   //     );
          //   //   } else {
          //   //     for (int selected_relation_id in selection["selected_relation_id"]) {
          //   //       newOptions.add(
          //   //         selection["options"].firstWhere(
          //   //           (element) => element["relation_id"] == selected_relation_id,
          //   //           orElse: () => null,
          //   //         ),
          //   //       );
          //   //     }
          //   //   }
          //   // }
          //   // newCartItem["selected_options"] = newOptions;
          // });
          widget.returnDataAmount!(newCart);
        }
        // // print(value);
        // if (value != null) {
        //   if (mounted) {
        //     setState(() {
        //       actualCartAmount = int.parse(value);
        //     });
        //   } else {
        //     actualCartAmount = int.parse(value);
        //   }
        // } else {
        //   if (mounted) {
        //     setState(() {
        //       actualCartAmount = 0;
        //     });
        //   } else {
        //     actualCartAmount = 0;
        //   }
        // }
        // if (mounted) {
        //   setState(() {
        //     isLastServerCallWasSucceed = true;
        //   });
        //   getBuyButtonCurrentActionText();
        // }
        // // print("TRIGGERED WIDGET.RETURNDATAAMOUNT!");
        // widget.returnDataAmount!(actualCartAmount, widget.index);
        // if (widget.cartPageExclusiveCallbackFunc != null) {
        //   widget.cartPageExclusiveCallbackFunc!(widget.index, actualCartAmount);
        // }
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
      if (amountInCart > 0) {
        amountInCart--;
        getBuyButtonCurrentActionText();
      }
    });
  }

  void _addToCart() {
    setState(() {
      if (amountInCart < widget.item["in_stock"]) {
        amountInCart++;
        getBuyButtonCurrentActionText();
      }
    });
  }

  void getBuyButtonCurrentActionText() {
    if (actualCartAmount == 0) {
      setState(() {
        buyButtonActionText = buyButtonActionTextMap["add"]!;
        buyButtonActionColor = Colors.black;
      });
    } else if (isRequired && isRequiredSelected && amountInCart > 0) {
      setState(() {
        buyButtonActionText = buyButtonActionTextMap["update"]!;
        buyButtonActionColor = Colors.blueGrey;
      });
    } else if (actualCartAmount == amountInCart || amountInCart == 0) {
      setState(() {
        buyButtonActionText = buyButtonActionTextMap["remove"]!;
        buyButtonActionColor = Colors.red;
      });
    } else {
      setState(() {
        buyButtonActionText = buyButtonActionTextMap["update"]!;
        buyButtonActionColor = Colors.blueGrey;
      });
    }
  }
// if (isRequired && isRequiredSelected && amountInCart > 0)
  // BUTTON VARIABLES/FUNCS END

  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   setState(() {
    //     isOptionsLoaded = false;
    //   });
    //   _getItem().then((value) {
    //     initOptionSelector();
    //     setState(
    //       () {
    //         if (options.isNotEmpty || widget.item["cart"] == null) {
    //           amountInCart = 0;
    //         } else {
    //           amountInCart = widget.item["cart"][0]["amount"] ?? 0;
    //           actualCartAmount = amountInCart;
    //         }
    //         if (widget.item["in_stock"] != null) {
    //           inStock = widget.item["in_stock"];
    //         } else {
    //           inStock = 0.0;
    //         }
    //         isOptionsLoaded = true;
    //       },
    //     );
    //   });
    // });
    if (widget.item["options"] != null) {
      initOptionSelector();
    } else {
      // amountInCart = widget.item["cart"].firstWhere((el) => el["item_id"] == widget.item["item_id"])["amount"];
      if (widget.item["cart"] != [] && widget.item["cart"] != null) {
        if (widget.item["cart"].isNotEmpty) {
          setState(() {
            amountInCart = widget.item["cart"][0]["amount"];
          });
        }
      }
    }

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
          decoration: BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            children: [
              Container(
                width: 80 * globals.scaleParam,
                height: 16 * globals.scaleParam,
                margin: EdgeInsets.symmetric(vertical: 35 * globals.scaleParam),
                decoration: BoxDecoration(
                  color: Colors.black, // Change this color to your desired color
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

  Scaffold _productPage(BuildContext context, ScrollController scrollController) {
    return Scaffold(
      // color: Colors.white,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SlideTransition(
        position: AlwaysStoppedAnimation(Offset(0, -0.25)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (isRequired && !isRequiredSelected && amountInCart == 0) {
              return Container(
                decoration: BoxDecoration(
                    color: Colors.black,
                    boxShadow: const [
                      BoxShadow(
                        offset: Offset(3, 5),
                        color: Colors.black38,
                        blurRadius: 5,
                      )
                    ],
                    borderRadius: BorderRadius.all(Radius.circular(30 * globals.scaleParam))),
                alignment: Alignment.center,
                width: constraints.maxWidth * 0.95,
                height: 125 * globals.scaleParam,
                child: Text(
                  "Выберите опцию",
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 48 * globals.scaleParam),
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
                          flex: 5,
                          fit: FlexFit.tight,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10 * globals.scaleParam),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                disabledBackgroundColor: Colors.grey.shade200,
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: null,
                              child: Container(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.all(Radius.circular(8)),
                                  clipBehavior: Clip.antiAliasWithSaveLayer,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        fit: FlexFit.tight,
                                        child: IconButton(
                                          padding: const EdgeInsets.all(0),
                                          onPressed: () {
                                            _removeFromCart();
                                          },
                                          icon: Container(
                                            padding: EdgeInsets.all(5 * globals.scaleParam),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(100),
                                              ),
                                              color: Colors.grey.shade400,
                                            ),
                                            child: Icon(
                                              Icons.remove_rounded,
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        fit: FlexFit.tight,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              amountInCart.toString(),
                                              textHeightBehavior: const TextHeightBehavior(
                                                applyHeightToFirstAscent: false,
                                              ),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 34 * globals.scaleParam,
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Flexible(
                                        fit: FlexFit.tight,
                                        child: IconButton(
                                          padding: const EdgeInsets.all(0),
                                          onPressed: () {
                                            _addToCart();
                                          },
                                          icon: Container(
                                            padding: EdgeInsets.all(5 * globals.scaleParam),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(100),
                                              ),
                                              color: Colors.grey.shade400,
                                            ),
                                            child: Icon(
                                              Icons.add_rounded,
                                              color: Theme.of(context).colorScheme.onSurface,
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
                          flex: 7,
                          fit: FlexFit.tight,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10 * globals.scaleParam),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buyButtonActionColor,
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () {
                                if (actualCartAmount == 0) {
                                  _finalizeCartAmount();
                                } else if (actualCartAmount == amountInCart || amountInCart == 0) {
                                  setState(() {
                                    amountInCart = 0;
                                  });
                                  _finalizeCartAmount();
                                } else {
                                  _finalizeCartAmount();
                                }
                              },
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
                                            fontSize: 38 * globals.scaleParam,
                                            color: Theme.of(context).colorScheme.onPrimary,
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
                      ],
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
      body: ListView(
        controller: scrollController,
        children: [
          SizedBox(
            height: 10 * globals.scaleParam,
          ),
          Container(
            width: MediaQuery.sizeOf(context).width * 0.5,
            height: MediaQuery.sizeOf(context).height * 0.5,
            alignment: Alignment.center,
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.circular(10),
                ),
              ),
              clipBehavior: Clip.none,
              child: ExtendedImage.network(
                item["img"],
              ),
            ),
          ),
          item.isNotEmpty
              ? Container(
                  // color: Colors.grey.shade50,
                  padding: EdgeInsets.symmetric(
                    horizontal: 30 * globals.scaleParam,
                    vertical: 10 * (MediaQuery.sizeOf(context).height / 1080),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        item["name"] ?? "",
                        style: TextStyle(
                          fontSize: 42 * globals.scaleParam,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(
                        height: 20 * globals.scaleParam,
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 15 * globals.scaleParam),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    "${globals.formatCost((item['price'] ?? '').toString())}",
                                    style: TextStyle(
                                      fontSize: 44 * globals.scaleParam,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    "₸",
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 44 * globals.scaleParam,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    "${item["in_stock"]} ${item["unit"]} в наличии",
                                    style: TextStyle(
                                      fontSize: 28 * globals.scaleParam,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              // TODO: Maybe not even needed anymore, content inside productPage loads immediately because data recieved from categoryPage
              : Shimmer.fromColors(
                  baseColor: Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                  highlightColor: Theme.of(context).colorScheme.secondary,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: 40,
                    color: Colors.white,
                  ),
                ),
          // Container(
          //   width: MediaQuery.of(context).size.width,
          //   padding: EdgeInsets.symmetric(
          //       horizontal: 30 * globals.scaleParam,
          //       vertical: 10 * (MediaQuery.sizeOf(context).height / 1080)),
          //   child: Wrap(
          //     children: propertiesWidget,
          //   ),
          // ),

          //! Options
          ListView.builder(
            primary: false,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, indexOption) {
              return Container(
                padding: EdgeInsets.all(30 * globals.scaleParam),
                margin: EdgeInsets.all(15 * globals.scaleParam),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          options[indexOption]["name"],
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 48 * globals.scaleParam),
                        ),
                        options[indexOption]["required"] == 1
                            ? Container(
                                color: Colors.white,
                                child: Text(
                                  "Обязательно",
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 36 * globals.scaleParam),
                                ),
                              )
                            : Container(),
                      ],
                    ),
                    ListView.builder(
                      primary: false,
                      shrinkWrap: true,
                      itemCount: options[indexOption]["options"].length,
                      itemBuilder: (context, index) {
                        return options[indexOption]["selection"] == "SINGLE"
                            ? Row(
                                children: [
                                  ChoiceChip(
                                      selectedColor: Colors.amberAccent.shade200,
                                      disabledColor: Colors.white,
                                      backgroundColor: Colors.white,
                                      label: Text(
                                        options[indexOption]["options"][index]["name"],
                                        style: TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      selected: options[indexOption]["selected_relation_id"] == options[indexOption]["options"][index]["relation_id"],
                                      onSelected: (v) {
                                        // print(v);
                                        print(options);
                                        if (v) {
                                          setState(() {
                                            options[indexOption]["selected_relation_id"] = options[indexOption]["options"][index]["relation_id"];
                                          });
                                        } else {
                                          setState(() {
                                            options[indexOption]["selected_relation_id"] = null;
                                          });

                                          // setState(() {
                                          //   amountInCart = 0;
                                          // });
                                          // _finalizeCartAmount();
                                        }
                                        _checkOptions();
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
                                      )
                                ],
                              )
                            : Container(
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                    // boxShadow: [
                                    //   BoxShadow(
                                    //       offset: Offset(2, 2),
                                    //       blurRadius: 5,
                                    //       color: Colors.grey.shade400)
                                    // ],
                                    // color: Colors.white,
                                    borderRadius: BorderRadius.all(Radius.circular(15))),
                                // margin: EdgeInsets.all(10 * globals.scaleParam),
                                child: Row(
                                  children: [
                                    FilterChip(
                                      backgroundColor: Colors.white,
                                      deleteIcon: Container(),
                                      deleteIconBoxConstraints: BoxConstraints(),
                                      label: Text(
                                        options[indexOption]["options"][index]["name"],
                                        style: TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      selected: List.castFrom(options[indexOption]["selected_relation_id"])
                                          .contains(options[indexOption]["options"][index]["relation_id"]),
                                      onSelected: (v) {
                                        if (v) {
                                          setState(() {
                                            options[indexOption]["selected_relation_id"].add(options[indexOption]["options"][index]["relation_id"]);
                                          });
                                        } else {
                                          setState(() {
                                            options[indexOption]["selected_relation_id"]
                                                .removeWhere((item) => item == options[indexOption]["options"][index]["relation_id"]);
                                          });
                                        }
                                        _checkOptions();
                                      },
                                      onDeleted: () {},
                                      // value: isCheckBoxSelected,
                                      // onChanged: (v) {}
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
                  padding: EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam),
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
                              color: currentTab == 0 ? Colors.black : Colors.grey.shade200,
                            ),
                          ),
                        ),
                        child: Text(
                          "Описание",
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(color: Colors.black, fontSize: 32 * globals.scaleParam),
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
                              color: currentTab == 1 ? Colors.black : Colors.grey.shade200,
                            ),
                          ),
                        ),
                        child: Text(
                          "О бренде",
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(color: Colors.black, fontSize: 32 * globals.scaleParam),
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
                              color: currentTab == 2 ? Colors.black : Colors.grey.shade200,
                            ),
                          ),
                        ),
                        child: Text(
                          "Производитель",
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(color: Colors.black, fontSize: 32 * globals.scaleParam),
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
            child: Text(TabText[currentTab],
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w400, fontSize: 32 * globals.scaleParam)),
          ),
          Container(
            padding: EdgeInsets.all(30 * globals.scaleParam),
            child: Table(
              columnWidths: const {0: FlexColumnWidth(), 1: FlexColumnWidth()},
              border: TableBorder(
                  horizontalInside: BorderSide(width: 1, color: Colors.grey.shade400), bottom: BorderSide(width: 1, color: Colors.grey.shade400)),
              children: properties,
            ),
          ),
          const SizedBox(
            height: 100,
          )
        ],
      ),
    );
  }
}
