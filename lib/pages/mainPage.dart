import 'dart:ui';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:naliv_delivery/agreements/offer.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/bonusesPage.dart';
import 'package:naliv_delivery/pages/categoryPage.dart';
import 'package:naliv_delivery/pages/orderHistoryPage.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';
import 'package:naliv_delivery/pages/settingsPage.dart';
import 'package:naliv_delivery/pages/supportPage.dart';
import 'package:naliv_delivery/shared/bonus.dart';
import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:carousel_slider/carousel_slider.dart';

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
  List _items = [];

  CarouselController _carouselController = CarouselController();

  List<dynamic> addresses = [];

  _getItems() {
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

  void updateDataAmount(List newCart, int index) {
    _items[index]["cart"] = newCart;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getItems();
    _getAddresses();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _carouselController.(duration: Duration(milliseconds: 2000));
    });
  }

  _getAddresses() {
    getAddresses().then((value) {
      setState(() {
        addresses = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      route: PickAddressPage(
                        client: widget.user,
                        addresses: addresses,
                        fromDrawer: true,
                      ),
                    ),
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
                          expandedHeight: kToolbarHeight,
                          centerTitle: true,
                          backgroundColor: Colors.transparent,
                          surfaceTintColor: Colors.transparent,
                          leading: IconButton(
                              onPressed: () {
                                Scaffold.of(context).openDrawer();
                              },
                              icon: Icon(Icons.menu)),
                          title: Text(
                            widget.currentAddress["address"] ?? "",
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            softWrap: true,
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                            ),
                          ),
                          actions: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                AspectRatio(
                                    aspectRatio: 1,
                                    child: Container(
                                        alignment: Alignment.center,
                                        child: CircleAvatar(
                                          child: Icon(
                                            Icons.person,
                                            size: 32,
                                          ),
                                        ))),
                              ],
                            )
                          ],
                          pinned: true,
                          automaticallyImplyLeading: false,
                        )),
                    SliverToBoxAdapter(
                      child: Container(
                        height: kToolbarHeight,
                      ),
                    ),
                    SliverToBoxAdapter(child: BonusWidget()),
                    SliverToBoxAdapter(
                        child: Container(
                      // height: 400,
                      // width: 200,
                      child: CarouselSlider(
                        options: CarouselOptions(
                            autoPlay: true,
                            height: MediaQuery.of(context).size.width /
                                16 *
                                9 *
                                0.9,
                            aspectRatio: 16 / 9,
                            viewportFraction: 0.9),
                        items: [1, 2, 3, 4, 5].map((i) {
                          return Builder(
                            builder: (BuildContext context) {
                              return Stack(
                                children: [
                                  Container(
                                    alignment: Alignment.bottomLeft,
                                    padding: EdgeInsets.all(15),
                                    width:
                                        MediaQuery.of(context).size.width * 0.9,
                                    margin:
                                        EdgeInsets.symmetric(horizontal: 5.0),
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Colors.black
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter),
                                        borderRadius: BorderRadius.circular(30),
                                        image: DecorationImage(
                                            fit: BoxFit.cover,
                                            image: NetworkImage(
                                                "https://i.ytimg.com/vi/jPFQfAKvNks/maxresdefault.jpg")),
                                        color: Colors.amber),
                                  ),
                                  Container(
                                      alignment: Alignment.bottomLeft,
                                      padding: EdgeInsets.all(15),
                                      width: MediaQuery.of(context).size.width *
                                          0.9,
                                      margin:
                                          EdgeInsets.symmetric(horizontal: 5.0),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Colors.black54
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Text(
                                        'Какой то длинный рекламный текст $i',
                                        style: GoogleFonts.roboto(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ))
                                ],
                              );
                            },
                          );
                        }).toList(),
                      ),
                    )),
                    SliverToBoxAdapter(
                        child: Container(
                      margin: EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Flexible(
                              child: TextButton(
                                  style: TextButton.styleFrom(
                                      backgroundColor: Colors.grey.shade900),
                                  onPressed: () {},
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Container(
                                          child: Image.asset(
                                              "assets/icons/fire.png"),
                                        ),
                                      ),
                                      Flexible(
                                          child: Text("Популярное",
                                              style: GoogleFonts.roboto(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
                                                color: Colors.white,
                                              )))
                                    ],
                                  ))),
                          Flexible(
                              child: TextButton(
                                  style: TextButton.styleFrom(
                                      backgroundColor: Colors.grey.shade900),
                                  onPressed: () {},
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Container(
                                          child: Image.asset(
                                              "assets/icons/flash.png"),
                                        ),
                                      ),
                                      Flexible(
                                          child: Text("Новинки",
                                              style: GoogleFonts.roboto(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
                                                color: Colors.white,
                                              )))
                                    ],
                                  ))),
                        ],
                      ),
                    )),
                  ];
                },
                body: Scaffold(
                  body: SafeArea(
                      // top: true,
                      child: Container(
                    margin: EdgeInsets.only(top: kToolbarHeight + 5),
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.all(Radius.circular(30))),
                    child: Builder(
                      builder: (context) {
                        return CustomScrollView(
                          // physics: NeverScrollableScrollPhysics(),
                          slivers: [
                            SliverGrid.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3),
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedCategory = int.parse(
                                          categories[index]["category_id"]);
                                      _items.clear();
                                    });
                                    print(selectedCategory);
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (context) {
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
        Navigator.push(context, MaterialPageRoute(
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
