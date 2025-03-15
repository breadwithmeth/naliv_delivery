import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
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
      //print("===========");
      //print(value);
      setState(() {
        addItems = value["items"] ?? [];
        addItems.shuffle();
      });
    });
  }

  Map details = {};
  _getProperties() {
    getItemDetails(widget.item["item_id"].toString()).then((value) {
      setState(() {
        details = value;
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
          //print(onData);
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
    return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Stack(
            children: [
              // Индикатор свайпа

              // Основной контент
              CustomScrollView(
                physics: ClampingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Изображение товара
                        AspectRatio(
                          aspectRatio: imageZoom ? 0.6 : 1,
                          child: Stack(
                            children: [
                              AspectRatio(
                                aspectRatio: imageZoom ? 0.6 : 1,
                                child: CachedNetworkImage(
                                  alignment: Alignment.center,
                                  fit: BoxFit.cover,
                                  imageUrl: widget.item["img"] ?? "/",
                                  placeholder: (context, url) => Center(
                                    child: CupertinoActivityIndicator(),
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                      CupertinoIcons.exclamationmark_triangle),
                                ),
                              ),
                              if (widget.item["promotions"] != null)
                                Positioned(
                                  left: 16,
                                  bottom: 16,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemBackground,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          CupertinoIcons.gift,
                                          color: CupertinoColors.activeOrange,
                                          size: 16,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Акция ${widget.item["promotions"][0]["base_amount"]} + ${widget.item["promotions"][0]["add_amount"]}',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Название товара
                              Expanded(
                                child: Text(
                                  widget.item["name"],
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // Кнопка нравится
                              if (liked != null)
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    if (liked == false) {
                                      likeItem(
                                              widget.item["item_id"].toString())
                                          .then((v) => _isLiked());
                                    } else {
                                      dislikeItem(
                                              widget.item["item_id"].toString())
                                          .then((v) => _isLiked());
                                    }
                                  },
                                  child: Icon(
                                    liked!
                                        ? CupertinoIcons.heart_fill
                                        : CupertinoIcons.heart,
                                    color: liked!
                                        ? CupertinoColors.systemRed
                                        : CupertinoColors.systemGrey,
                                    size: 28,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Цена
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.activeOrange,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${widget.item["price"]}₸',
                                  style: TextStyle(
                                    color: CupertinoColors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (widget.item["old_price"] != null) ...[
                                SizedBox(width: 8),
                                Text(
                                  '${widget.item["old_price"]}₸',
                                  style: TextStyle(
                                    color: CupertinoColors.secondaryLabel,
                                    fontSize: 15,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Описание, если есть
                        if (widget.item["description"] != null)
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              widget.item["description"],
                              style: TextStyle(
                                color: CupertinoColors.secondaryLabel,
                                fontSize: 15,
                              ),
                            ),
                          ),

                        // Описание и характеристики
                        if (details["properties"] != null)
                          _buildPropertiesSection(),

                        if (addItems.isNotEmpty) _buildRecommendedSection(),

                        if (recItems.isNotEmpty) _buildAlsoBuySection(),

                        SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),

              // Кнопка добавления в корзину
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                child: _buildAddToCartButton(),
              ),
            ],
          ),
        ));
  }

  Widget _buildAddToCartButton() {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.activeOrange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: cartItem == null
          ? CupertinoButton(
              onPressed: () =>
                  options == null ? addToCart() : _showOptionsSheet(),
              padding: EdgeInsets.zero,
              child: Text(
                'Добавить в корзину',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    if (parentItemAmoint == null) {
                      updateAmount(currentAmount - quantity);
                    } else {
                      updateAmount(
                          currentAmount - (quantity * parentItemAmoint!));
                    }
                  },
                  child: Icon(
                    CupertinoIcons.minus,
                    color: CupertinoColors.white,
                  ),
                ),
                Text(
                  currentAmount.toString(),
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    if (parentItemAmoint == null) {
                      updateAmount(currentAmount + quantity);
                    } else {
                      updateAmount(
                          currentAmount + (quantity * parentItemAmoint!));
                    }
                  },
                  child: Icon(
                    CupertinoIcons.plus,
                    color: CupertinoColors.white,
                  ),
                ),
              ],
            ),
    );
  }

  void _showOptionsSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          children: [
            // Индикатор свайпа
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey4.resolveFrom(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Заголовок
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Выберите опцию',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: CupertinoColors.systemGrey2.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
            // Список опций
            Expanded(
              child: ListView.builder(
                physics: BouncingScrollPhysics(),
                itemCount: options?.length ?? 0,
                itemBuilder: (context, index) {
                  List suboptions = options![index]["options"];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          options![index]["name"] ?? "Варианты",
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: suboptions.length,
                        itemBuilder: (context, index2) {
                          final option = suboptions[index2];
                          return Column(
                            children: [
                              CupertinoButton(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  addToCart(option: option);
                                },
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            option["name"],
                                            style: TextStyle(
                                              color: CupertinoColors.label
                                                  .resolveFrom(context),
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (option["description"] !=
                                              null) ...[
                                            SizedBox(height: 4),
                                            Text(
                                              option["description"],
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: CupertinoColors
                                                    .secondaryLabel
                                                    .resolveFrom(context),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.systemGrey6
                                            .resolveFrom(context),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${option["parent_item_amount"]} шт',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: CupertinoColors.secondaryLabel
                                              .resolveFrom(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesSection() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Характеристики',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: details["properties"]?.length ?? 0,
            itemBuilder: (context, index) {
              final property = details["properties"][index];
              return Container(
                padding: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      property["name"],
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    Text(
                      property["value"],
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedSection() {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Рекомендуем добавить',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              itemCount: addItems.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 160,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  child: ItemCard2(
                    item: addItems[index],
                    business: widget.business,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlsoBuySection() {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'С этим также покупают',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
              itemCount: recItems.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 160,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  child: ItemCard2(
                    item: recItems[index],
                    business: widget.business,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
