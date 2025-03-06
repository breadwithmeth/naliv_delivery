import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:naliv_delivery/agreements/offer.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/databaseapi.dart';

import 'package:naliv_delivery/misc/databaseapi.dart';
import 'package:naliv_delivery/pages/newItemsPage.dart';
import 'package:naliv_delivery/pages/orderHistoryPage.dart';
import 'package:naliv_delivery/pages/paymentMethods.dart';
import 'package:naliv_delivery/pages/popularItemsPage.dart';
import 'package:naliv_delivery/pages/preLoadCategoryPage.dart';
import 'package:naliv_delivery/pages/selectAddressPage.dart';
import 'package:naliv_delivery/pages/selectBusinessesPage.dart';
import 'package:naliv_delivery/pages/settingsPage.dart';
import 'package:naliv_delivery/pages/storiesPage.dart';
import 'package:naliv_delivery/pages/supportPage.dart';
import 'package:naliv_delivery/shared/bonus.dart';
import 'package:naliv_delivery/shared/bottomBar.dart';
import 'package:naliv_delivery/shared/cartButton.dart';
import 'package:naliv_delivery/shared/itemCard2mini.dart';
import 'package:naliv_delivery/shared/searchWidget.dart';
import 'package:naliv_delivery/shared/navBarWidgets.dart';

class MainPage extends StatefulWidget {
  const MainPage({
    super.key,
    required this.currentAddress,
    required this.user,
    required this.business,
    required this.businesses,
  });
  final Map currentAddress;
  final Map<String, dynamic> user;
  final Map business;
  final List businesses;
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {
  List categories = [];
  List items = [];
  int selectedCategory = 0;
  Map<String, dynamic> _items = {};
  CarouselController _carouselController = CarouselController();
  bool isLoading = true;
  List<dynamic> addresses = [];
  List parentCategories = [];
  List stories = [];
  List gigaCats = [];
  DatabaseManager dbm = DatabaseManager();

  _getCategories() {
    getCategories(widget.business["business_id"]).then((value) {
      setState(() {
        parentCategories = value.where((element) {
          return element["parent_category"] == "0";
        }).toList();
        categories = value;
        selectedCategory = int.parse(categories[0]["category_id"]);
      });
    });
    // getItems2(widget.business["business_id"]).then((value) {
    //   print(value);
    //   setState(() {
    //     categories = value["categories"];
    //   });
    // });
  }

  _getGigaCats() {
    getGigaCats(widget.business["business_id"]).then((v) {
      setState(() {
        print(v);
        gigaCats = v["categories"];
      });
    });
  }

  _getAddresses() {
    getAddresses().then((value) {
      setState(() {
        addresses = value;
      });
    });
  }

  _getItems() {
    getItems2(widget.business["business_id"]).then((value) {
      setState(() {
        _items = value;
      });
    });
  }

  _getStories() {
    getStories(widget.business["business_id"]).then((v) {
      setState(() {
        stories = v["stories"] ?? [];
      });
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    dbm.getCartId(int.parse(widget.business["business_id"]));
    _getStories();
    _getCategories();
    _getAddresses();
    _getGigaCats();
    WidgetsBinding.instance.addPostFrameCallback((_) {});
  }

  void _showActionSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          'Налив/Градусы24',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (context) => OrderHistoryPage()),
              );
            },
            child: Text('История заказов'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => SelectAddressPage(
                    addresses: addresses,
                    currentAddress: addresses.firstWhere(
                      (element) => element["is_selected"] == "1",
                      orElse: () => {},
                    ),
                    createOrder: false,
                    business: null,
                  ),
                ),
              );
            },
            child: Text('Адреса доставки'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => SupportPage(user: widget.user),
                ),
              );
            },
            child: Text('Поддержка'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (context) => PaymentMethods()),
              );
            },
            child: Text('Методы оплаты'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) =>
                      OfferPage(path: "assets/agreements/offer.md"),
                ),
              );
            },
            child: Text('Оферта'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (context) => SettingsPage()),
              );
            },
            child: Text('Управление аккаунтом'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('Отмена'),
        ),
      ),
    );
  }

  void _navigateToAddressSelection() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => SelectAddressPage(
          addresses: addresses,
          currentAddress: addresses.firstWhere(
            (element) => element["is_selected"] == "1",
            orElse: () => {},
          ),
          createOrder: false,
          business: null,
        ),
      ),
    );
  }

  Widget _buildStoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            "Истории",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: stories.length,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) => _buildStoryItem(
                context, stories[index], index, stories, widget.business),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Быстрые действия",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _buildActionButton(
                "Популярное",
                () => Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => PopularItemsPage(
                      business: widget.business,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              _buildActionButton(
                "Новинки",
                () => Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => NewItemsPage(
                      business: widget.business,
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

  Widget _buildCategorySection(BuildContext context, Map category, Map business,
      List<dynamic> categories, List<dynamic> gigacats, List subcategories) {
    if (category["items"] == null || (category["items"] as List).isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCategoryHeader(context, category, widget.user, business,
            categories, gigacats, subcategories),
        SizedBox(height: 12),
        _buildCategoryItems(category["items"], category, business),
        SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          padding:
              EdgeInsetsDirectional.only(start: 16, top: 5, bottom: 5, end: 16),
          middle: Container(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Searchwidget(business: widget.business),
          ),
          // backgroundColor:
          //     CupertinoColors.systemBackground.resolveFrom(context),
          border: null,
          trailing: _buildMenuButton(),
        ),
        child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Адрес
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6
                                .resolveFrom(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: GestureDetector(
                            onTap: () => _navigateToAddressSelection(),
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.location, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Адрес доставки',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        widget.currentAddress["address"] ??
                                            "Выберите адрес",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(CupertinoIcons.chevron_down, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Бонусы
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: BonusWidget(),
                      ),

                      // Карточка магазина
                      _buildCurrentShopCard(),
                      // Истории
                      if (stories.isNotEmpty) _buildStoriesSection(),
                      // Быстрые действия
                      _buildQuickActionsSection(),
                      // Категории
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: gigaCats.length,
                          itemBuilder: (context, index) {
                            return _buildCategorySection(
                              context,
                              gigaCats[index],
                              widget.business,
                              categories,
                              gigaCats,
                              categories.where((element) {
                                return element["parent_category"] ==
                                    gigaCats[index]["c_id"].toString();
                              }).toList(),
                            );
                          },
                        ),
                      ),
                      // Отступ внизу
                      SizedBox(height: 100),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  child: CartButton(
                    business: widget.business,
                    user: {},
                  ),
                ),
              ],
            )
            // bottomNavigationBar: CartButton(
            //   business: widget.business,
            //   user: widget.user,
            // ),
            ));
  }

  Widget _buildMenuButton() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _showActionSheet(context),
        child: Icon(
          CupertinoIcons.bars,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildCurrentShopCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => SelectBusinessesPage(
              businesses: widget.businesses,
              currentAddress: widget.currentAddress,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.all(16),
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: widget.business["img"],
                fit: BoxFit.cover,
                width: double.infinity,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      CupertinoColors.black.withOpacity(0),
                      CupertinoColors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.business["name"],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.business["address"],
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildStoryItem(
    BuildContext context, Map story, int index, List stories, Map business) {
  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (context) {
          return StoriesPage(
            stories: stories ?? [],
            business: business,
            initialIndex: index,
            t_id: stories[index]["t_id"].toString(),
            type: stories[index]["type"].toString(),
          );
        }),
      );
    },
    child: Container(
      width: 100,
      margin: EdgeInsets.only(right: 8),
      child: Column(
        children: [
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.activeOrange,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: story["cover"],
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: CupertinoActivityIndicator(),
                ),
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            story["name"],
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

Widget _buildActionButton(String title, VoidCallback onPressed) {
  return Expanded(
    child: CupertinoButton(
      padding: EdgeInsets.symmetric(vertical: 12),
      borderRadius: BorderRadius.circular(12),
      color: CupertinoColors.systemGrey6,
      onPressed: onPressed,
      child: Text(title),
    ),
  );
}

Widget _buildCategoryHeader(
    BuildContext context,
    Map category,
    Map<String, dynamic> user,
    Map<dynamic, dynamic> business,
    List<dynamic> categories,
    List<dynamic> gigacats,
    List subcategories) {
  print("==================");
  print(category);
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        category["c_name"] ?? "",
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
      CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => PreLoadCategoryPage(
                category: category,
                business: business,
                subcategories: subcategories,
                user: user,
              ),
            ),
          );
        },
        child: Row(
          children: [
            Text('Все'),
            Icon(CupertinoIcons.right_chevron),
          ],
        ),
      ),
    ],
  );
}

Widget _buildCategoryItems(List items, Map category, Map business) {
  return SizedBox(
    height: 150,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: items.length > 10 ? 10 : items.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(right: 8),
          child: ItemCard2mini(
            item: items[index],
            business: business,
          ),
        );
      },
    ),
  );
}

class DrawerMenuItem extends StatefulWidget {
  const DrawerMenuItem(
      {super.key,
      required this.name,
      required this.icon,
      required this.route,
      required this.business});
  final String name;
  final IconData icon;
  final Widget route;
  final Map business;
  @override
  State<DrawerMenuItem> createState() => _DrawerMenuItemState();
}

class _DrawerMenuItemState extends State<DrawerMenuItem> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => widget.route),
        );
      },
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(bottomRight: Radius.circular(15)),
          color: CupertinoColors.systemBackground,
        ),
        child: Text(
          widget.name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}
