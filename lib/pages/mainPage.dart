import 'dart:ui';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:naliv_delivery/agreements/offer.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/bonusesPage.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:naliv_delivery/pages/categoryPage.dart';
import 'package:naliv_delivery/pages/itemsPage.dart';
import 'package:naliv_delivery/pages/newItemsPage.dart';
import 'package:naliv_delivery/pages/orderHistoryPage.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';
import 'package:naliv_delivery/pages/popularItemsPage.dart';
import 'package:naliv_delivery/pages/searchPage.dart';
import 'package:naliv_delivery/pages/selectAddressPage.dart';
import 'package:naliv_delivery/pages/settingsPage.dart';
import 'package:naliv_delivery/pages/supportPage.dart';
import 'package:naliv_delivery/shared/bonus.dart';
import 'package:naliv_delivery/shared/bottomBar.dart';
import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:naliv_delivery/shared/searchWidget.dart';
import 'package:provider/provider.dart';

class MainPage extends StatefulWidget {
  const MainPage({
    super.key,
    required this.currentAddress,
    required this.user,
    required this.business,
  });
  final Map currentAddress;
  final Map<String, dynamic> user;
  final Map business;
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {
  List categories = [];
  List items = [];
  int selectedCategory = 0;
  Map<String, dynamic> _items = {};
  CarouselController _carouselController = CarouselController();

  List<dynamic> addresses = [];

  _getCategories() {
    getCategories(widget.business["business_id"]).then((value) {
      setState(() {
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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getCategories();
    _getAddresses();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _carouselController.(duration: Duration(milliseconds: 2000));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: EdgeInsets.all(10),
              child: FloatingActionButton(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) {
                        return CartPage(
                          business: widget.business,
                          user: widget.user,
                        );
                      },
                    ),
                  );
                },
                child: Icon(Icons.shopping_cart_checkout),
              ),
            ),
            context.mounted ? BottomBar() : Container(),
          ],
        ),
        drawer: Drawer(
            backgroundColor: Colors.black,
            child: SafeArea(
                child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(15),
                  child: FittedBox(
                    child: Text(
                      "Налив/Градусы24",
                      style: GoogleFonts.prostoOne(
                        fontSize: 50,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                ListView(
                  primary: false,
                  shrinkWrap: true,
                  children: [
                    const DrawerMenuItem(
                      name: "История заказов",
                      icon: Icons.book_outlined,
                      route: OrderHistoryPage(),
                    ),
                    DrawerMenuItem(
                        name: "Адреса доставки",
                        icon: Icons.map_outlined,
                        route: SelectAddressPage(
                          addresses: addresses,
                          currentAddress: addresses.firstWhere(
                            (element) => element["is_selected"] == "1",
                            orElse: () {
                              return {};
                            },
                          ),
                          createOrder: false,
                          business: null,
                        )),
                    DrawerMenuItem(
                      name: "Поддержка",
                      icon: Icons.support_agent_rounded,
                      route: SupportPage(
                        user: widget.user,
                      ),
                    ),
                    const DrawerMenuItem(
                      name: "Оферта",
                      icon: Icons.list_alt,
                      route: OfferPage(
                        path: "assets/agreements/offer.md",
                      ),
                    ),
                    const DrawerMenuItem(
                      name: "Управление аккаунтом",
                      icon: Icons.settings_outlined,
                      route: SettingsPage(),
                    ),
                  ],
                )
              ],
            ))),
        body: SafeArea(
            child: NestedScrollView(
                headerSliverBuilder:
                    (BuildContext context, bool innerBoxIsScrolled) {
                  return <Widget>[
                    SliverOverlapAbsorber(
                        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                            context),
                        sliver: SliverAppBar(
                          floating: true,
                          toolbarHeight: 80,
                          expandedHeight: 160,
                          centerTitle: false,
                          backgroundColor: Colors.transparent,
                          surfaceTintColor: Colors.transparent,
                          flexibleSpace: FlexibleSpaceBar(
                            expandedTitleScale: 1.2,
                            title: Searchwidget(
                              business: widget.business,
                            ),
                            background: Container(
                              padding: EdgeInsets.all(15),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        flex: 4,
                                        child: GestureDetector(
                                            onTap: () {
                                              Navigator.push(context,
                                                  CupertinoPageRoute(
                                                builder: (context) {
                                                  return SelectAddressPage(
                                                    addresses: addresses,
                                                    currentAddress:
                                                        addresses.firstWhere(
                                                      (element) =>
                                                          element[
                                                              "is_selected"] ==
                                                          "1",
                                                      orElse: () {
                                                        return {};
                                                      },
                                                    ),
                                                    createOrder: false,
                                                    business: null,
                                                  );
                                                },
                                              ));
                                            },
                                            child: Row(
                                              children: [
                                                Flexible(
                                                  flex: 3,
                                                  child: Text(
                                                    widget.currentAddress[
                                                            "address"] ??
                                                        "Адрес не выбран",
                                                  ),
                                                ),
                                                Icon(Icons.arrow_drop_down)
                                              ],
                                            )),
                                      ),
                                      Flexible(
                                        child: IconButton(
                                            onPressed: () {
                                              Scaffold.of(context).openDrawer();
                                            },
                                            icon: Icon(Icons.menu)),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                          actions: [
                            // Stack(
                            //   alignment: Alignment.center,
                            //   children: [
                            //     AspectRatio(
                            //         aspectRatio: 1,
                            //         child: Container(
                            //             alignment: Alignment.center,
                            //             child: CircleAvatar(
                            //               child: Icon(
                            //                 Icons.person,
                            //                 size: 32,
                            //               ),
                            //             ))),
                            //   ],
                            // )
                          ],
                          pinned: true,
                          automaticallyImplyLeading: false,
                        )),
                    SliverToBoxAdapter(
                      child: Container(
                        height: 100,
                      ),
                    ),

                    SliverToBoxAdapter(child: BonusWidget()),
                    SliverPadding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          alignment: Alignment.centerLeft,
                          height: 60,
                          decoration: BoxDecoration(),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            primary: false,
                            shrinkWrap: true,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(context, CupertinoPageRoute(
                                    builder: (context) {
                                      return PopularItemsPage(
                                          business: widget.business);
                                    },
                                  ));
                                },
                                child: Container(
                                  margin: EdgeInsets.all(5),
                                  padding: EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(5)),
                                      color: Color(0xFF121212)),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "Популярное",
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(context, CupertinoPageRoute(
                                    builder: (context) {
                                      return NewItemsPage(
                                          business: widget.business);
                                    },
                                  ));
                                },
                                child: Container(
                                  margin: EdgeInsets.all(5),
                                  padding: EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(5)),
                                      color: Color(0xFF121212)),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "Новое",
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // SliverToBoxAdapter(
                    //     child: Container(
                    //   // height: 400,
                    //   // width: 200,
                    //   child: CarouselSlider(
                    //     options: CarouselOptions(
                    //         autoPlay: true,
                    //         height: MediaQuery.of(context).size.width /
                    //             16 *
                    //             9 *
                    //             0.9,
                    //         aspectRatio: 16 / 9,
                    //         viewportFraction: 0.9),
                    //     items: [1, 2, 3, 4, 5].map((i) {
                    //       return Builder(
                    //         builder: (BuildContext context) {
                    //           return Stack(
                    //             children: [
                    //               Container(
                    //                 alignment: Alignment.bottomLeft,
                    //                 padding: EdgeInsets.all(15),
                    //                 width:
                    //                     MediaQuery.of(context).size.width * 0.9,
                    //                 margin:
                    //                     EdgeInsets.symmetric(horizontal: 5.0),
                    //                 decoration: BoxDecoration(
                    //                     gradient: LinearGradient(
                    //                         colors: [
                    //                           Colors.transparent,
                    //                           Colors.black
                    //                         ],
                    //                         begin: Alignment.topCenter,
                    //                         end: Alignment.bottomCenter),
                    //                     borderRadius: BorderRadius.circular(30),
                    //                     image: DecorationImage(
                    //                         fit: BoxFit.cover,
                    //                         image: NetworkImage(
                    //                             "https://i.ytimg.com/vi/jPFQfAKvNks/maxresdefault.jpg")),
                    //                     color: Colors.amber),
                    //               ),
                    //               Container(
                    //                   alignment: Alignment.bottomLeft,
                    //                   padding: EdgeInsets.all(15),
                    //                   width: MediaQuery.of(context).size.width *
                    //                       0.9,
                    //                   margin:
                    //                       EdgeInsets.symmetric(horizontal: 5.0),
                    //                   decoration: BoxDecoration(
                    //                     gradient: LinearGradient(
                    //                         colors: [
                    //                           Colors.transparent,
                    //                           Colors.black54
                    //                         ],
                    //                         begin: Alignment.topCenter,
                    //                         end: Alignment.bottomCenter),
                    //                     borderRadius: BorderRadius.circular(30),
                    //                   ),
                    //                   child: Text(
                    //                     'Какой то длинный рекламный текст $i',
                    //                     style: GoogleFonts.roboto(
                    //                       fontSize: 24,
                    //                       fontWeight: FontWeight.w500,
                    //                       color: Colors.white,
                    //                     ),
                    //                   ))
                    //             ],
                    //           );
                    //         },
                    //       );
                    //     }).toList(),
                    //   ),
                    // )),
                    // SliverToBoxAdapter(
                    //     child: Container(
                    //   margin: EdgeInsets.all(10),
                    //   child: Row(
                    //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    //     children: [
                    //       TextButton(
                    //         style: TextButton.styleFrom(
                    //             backgroundColor: Colors.grey.shade900),
                    //         onPressed: () {},
                    //         child: Image.asset(
                    //           "assets/icons/fire.png",
                    //           height: 64,
                    //         ),
                    //       ),
                    //       TextButton(
                    //         style: TextButton.styleFrom(
                    //             backgroundColor: Colors.grey.shade900),
                    //         onPressed: () {},
                    //         child: Image.asset(
                    //           "assets/icons/flash.png",
                    //           height: 64,
                    //         ),
                    //       )
                    //     ],
                    //   ),
                    // )),
                  ];
                },
                body: Scaffold(
                  body: SafeArea(
                      // top: true,
                      child: Container(
                    margin: EdgeInsets.only(top: 0 + 5),
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.all(Radius.circular(30))),
                    child: Builder(
                      builder: (context) {
                        return CustomScrollView(
                          slivers: [
                            SliverGrid.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3),
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(context, CupertinoPageRoute(
                                      builder: (context) {
                                        // return ItemsPage(
                                        //     categories: categories,
                                        //     items: _items,
                                        //     selectedCategory: int.parse(
                                        //         categories[index]
                                        //             ["category_id"]));
                                        return CategoryPage(
                                            categoryId: categories[index]
                                                ["category_id"],
                                            categoryName: categories[index]
                                                ["name"],
                                            categories: categories,
                                            business: widget.business,
                                            user: widget.user);
                                      },
                                    ));
                                    // setState(() {
                                    //   _items = categories[index]["items"];
                                    // });
                                  },
                                  child: Container(
                                      alignment: Alignment.topCenter,
                                      margin: EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                          color: Color(0xFF121212),
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(25))),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Container(
                                              decoration: BoxDecoration(
                                                  color: Colors.grey.shade900,
                                                  borderRadius:
                                                      BorderRadius.all(
                                                          Radius.circular(
                                                              100))),
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.2,
                                              height: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.2,
                                              clipBehavior: Clip.hardEdge,
                                              padding: EdgeInsets.all(2),
                                              child: AspectRatio(
                                                aspectRatio: 1,
                                                child: Image.network(
                                                    categories[index]["img"]),
                                              )
                                              // AssetImage("assets/icons/wine.png"),
                                              ),
                                          Text(
                                            categories[index]["name"],
                                            maxLines: 1,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.roboto(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: selectedCategory ==
                                                        int.parse(
                                                            categories[index]
                                                                ["category_id"])
                                                    ? Colors.white
                                                    : Colors.white),
                                          ),
                                        ],
                                      )),
                                );
                              },
                            ),

                            // SliverToBoxAdapter(
                            //   child: SizedBox(
                            //     height: 300,
                            //   ),
                            // )
                          ],
                        );
                      },
                    ),
                  )),
                ))));
  }
}

//  CustomScrollView(
//         slivers: [
//           SliverOverlapAbsorber(
//             handle: SliverOverlapAbsorberHandle(),
//             sliver: SliverToBoxAdapter(
//               child: Row(
//                 children: [
//                   Flexible(
//                     flex: 2,
//                     child: Text(getSelectedAddress()["address"] ?? ""),
//                   ),
//                   Flexible(child: Text(widget.user["name"] ?? "")),
//                 ],
//               ),
//             ),
//           ),
//           SliverFillRemaining(
//               hasScrollBody: false,
//               fillOverscroll: false,
//               child: LayoutBuilder(
//                 builder: (context, constraints) {
//                   return Text(constraints.maxHeight.toString());
//                 },
//               ))
//         ],
//       )

class DrawerMenuItem extends StatefulWidget {
  const DrawerMenuItem(
      {super.key, required this.name, required this.icon, required this.route});
  final String name;
  final IconData icon;
  final Widget route;
  @override
  State<DrawerMenuItem> createState() => _DrawerMenuItemState();
}

class _DrawerMenuItemState extends State<DrawerMenuItem> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, CupertinoPageRoute(
          builder: (context) {
            return widget.route;
          },
        ));
      },
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(bottomRight: Radius.circular(15)),
          color: Colors.black,
          boxShadow: [
            BoxShadow(
                offset: Offset(5, 3), blurRadius: 5, color: Colors.black12)
          ],
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
