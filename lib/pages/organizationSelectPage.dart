import 'dart:math';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/addressesPage.dart';
import 'package:naliv_delivery/pages/favPage.dart';
import 'package:naliv_delivery/pages/homePage.dart';
import 'package:naliv_delivery/pages/loginPage.dart';
import 'package:naliv_delivery/pages/orderHistoryPage.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';
import 'package:naliv_delivery/pages/settingsPage.dart';
import 'package:naliv_delivery/pages/supportPage.dart';
import 'package:google_fonts/google_fonts.dart';

class OrganizationSelectPage extends StatefulWidget {
  OrganizationSelectPage(
      {super.key,
      required this.addresses,
      required this.currentAddress,
      required this.user,
      required this.businesses});
  final List addresses;
  final Map currentAddress;
  final Map<String, dynamic> user;
  final List businesses;
  @override
  State<OrganizationSelectPage> createState() => _OrganizationSelectPageState();
}

class _OrganizationSelectPageState extends State<OrganizationSelectPage>
    with AutomaticKeepAliveClientMixin {
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> bars = [
    {"organization_id": "1", "name": "НАЛИВ"},
    {"organization_id": "2", "name": "Название бизнеса"},
    {"organization_id": "3", "name": "Название бизнеса"},
    {"organization_id": "4", "name": "Название бизнеса"},
    {"organization_id": "5", "name": "Название бизнеса"},
    {"organization_id": "6", "name": "Название бизнеса"},
    {"organization_id": "7", "name": "Название бизнеса"},
    {"organization_id": "8", "name": "Название бизнеса"},
    {"organization_id": "9", "name": "Название бизнеса"},
    {"organization_id": "2", "name": "Название бизнеса"},
    {"organization_id": "3", "name": "Название бизнеса"},
    {"organization_id": "4", "name": "Название бизнеса"},
    {"organization_id": "5", "name": "Название бизнеса"},
    {"organization_id": "6", "name": "Название бизнеса"},
    {"organization_id": "7", "name": "Название бизнеса"},
    {"organization_id": "8", "name": "Название бизнеса"},
    {"organization_id": "9", "name": "Название бизнеса"},
    {"organization_id": "2", "name": "Название бизнеса"},
    {"organization_id": "3", "name": "Название бизнеса"},
    {"organization_id": "4", "name": "Название бизнеса"},
    {"organization_id": "5", "name": "Название бизнеса"},
    {"organization_id": "6", "name": "Название бизнеса"},
    {"organization_id": "7", "name": "Название бизнеса"},
    {"organization_id": "8", "name": "Название бизнеса"},
    {"organization_id": "9", "name": "Название бизнеса"},
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // List widget.addresses = [];

  // Map currentAddress = {};

  // Map<String, dynamic> user = {};

  void toggleDrawer() async {
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      _scaffoldKey.currentState!.openEndDrawer();
    } else {
      _scaffoldKey.currentState!.openDrawer();
    }
  }

  // Future<void> _getAddresses() async {
  //   List addresses = await getAddresses();
  //   print(addresses);
  //   setState(() {
  //     widget.addresses = addresses;
  //     widget.currentAddress = widget.addresses.firstWhere(
  //       (element) => element["is_selected"] == "1",
  //       orElse: () {
  //         return null;
  //       },
  //     );
  //   });
  // }

  // void _getUser() async {
  //   await getUser().then((value) {
  //     setState(() {
  //       if (value != null) {
  //         user = value;
  //       }
  //     });
  //   });
  // }

  void _initData() {
    setState(() {
      print(widget.businesses);
      // widget.currentAddress = widget.currentAddress;
      // user = widget.user;
      // widget.addresses = widget.addresses;
    });
  }

  double collapsedBarHeight = 100.0;
  double expandedBarHeight = 200.0;
  _scrollListener() {
    if (_sc.position.minScrollExtent + 200 < _sc.offset) {
      if (!isCollapsed) {
        setState(() {
          isCollapsed = true;
        });
      }
    } else {
      if (isCollapsed) {
        _sc.animateTo(0, duration: Durations.medium1, curve: Curves.easeIn);
        setState(() {
          isCollapsed = false;
        });
      }
    }
    if (_sc.position.minScrollExtent + 10 < _sc.offset) {
      if (!isStartingToCollapse) {
        _sc.animateTo(scrollExtent + collapsedBarHeight * 2,
            duration: Durations.medium1, curve: Curves.easeIn);
        setState(() {
          isMenuOpen = false;
          isStartingToCollapse = true;
        });
      }
    } else {
      if (isStartingToCollapse) {
        setState(() {
          isStartingToCollapse = false;
        });
      }
    }

    /// 2
    // isCollapsed.value = scrollController.hasClients &&
    //     scrollController.offset >
    //         (expandedBarHeight - collapsedBarHeight);
  }

  @override
  void initState() {
    super.initState();
    _sc.addListener(_scrollListener);

    // Future.delayed(Duration.zero).then((value) async {
    //   _getUser();
    // });
    // WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
    //   _getAddresses();
    // });
    // _initData();
  }

  ScrollController _sc = ScrollController();
  bool isCollapsed = false;
  bool isStartingToCollapse = false;
  double scrollExtent = 0;
  bool isMenuOpen = false;
  final GlobalKey<ScaffoldState> _key = GlobalKey(
      debugLabel:
          "вот это ключ, всем ключам ключ, надеюсь он тут не потеряется");
  @override
  Widget build(BuildContext context) {
    double screenSize = MediaQuery.of(context).size.width;

    TextStyle titleStyle = TextStyle(
      fontSize: 50 * (screenSize / 720),
      fontWeight: FontWeight.w500,
      color: Theme.of(context).colorScheme.onBackground,
    );

    TextStyle plainStyle = TextStyle(
      fontSize: 32 * (screenSize / 720),
      fontWeight: FontWeight.w500,
      color: Theme.of(context).colorScheme.onBackground,
    );

    // final scrollController = useScrollController();
    // final isCollapsed = useState(false);

    return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // if (expandedBarHeight - collapsedBarHeight <
          //     notification.metrics.atEdge) {
          //   print(true);
          // } else {
          //   print(false);
          // }
          // if (notification.metrics.minScrollExtent + 200 <
          //     notification.metrics.pixels) {
          //   if (!isCollapsed) {
          //     setState(() {
          //       isCollapsed = true;
          //     });
          //   }
          // } else {
          //   if (isCollapsed) {
          //     _sc.animateTo(0,
          //         duration: Durations.medium1, curve: Curves.easeIn);
          //     setState(() {
          //       isCollapsed = false;
          //     });
          //   }
          // }
          // if (notification.metrics.minScrollExtent + 10 <
          //     notification.metrics.pixels) {
          //   if (!isStartingToCollapse) {
          //     _sc.animateTo(scrollExtent + collapsedBarHeight * 2,
          //         duration: Durations.medium1, curve: Curves.easeIn);
          //     setState(() {
          //       isMenuOpen = false;
          //       isStartingToCollapse = true;
          //     });
          //   }
          // } else {
          //   if (isStartingToCollapse) {
          //     setState(() {
          //       isStartingToCollapse = false;
          //     });
          //   }
          // }

          // /// 2
          // // isCollapsed.value = scrollController.hasClients &&
          // //     scrollController.offset >
          // //         (expandedBarHeight - collapsedBarHeight);
          return false;
        },
        child: Scaffold(
            key: _key,
            drawerEnableOpenDragGesture: false,
            drawerScrimColor: Colors.white,
            endDrawer: SafeArea(
                child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: () {
                                _key.currentState!.closeEndDrawer();
                              },
                              icon: Container(
                                padding: EdgeInsets.all(20),
                                child: Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                        Flexible(
                            child: Container(
                          alignment: Alignment.center,
                          height: MediaQuery.of(context).size.height / 5,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text("НАЗВАНИЕ",
                                  style: GoogleFonts.montserratAlternates(
                                    textStyle: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 48 *
                                            (MediaQuery.of(context).size.width /
                                                720)),
                                  )),
                              Icon(
                                Icons.local_dining_outlined,
                                color: Colors.black,
                                size: 48 *
                                    (MediaQuery.of(context).size.width / 720),
                              )
                            ],
                          ),
                        )),
                        Flexible(
                            child: Container(
                                child: GridView.count(
                          padding: EdgeInsets.all(10),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2 / 1,
                          crossAxisCount: 2,
                          children: [
                            DrawerMenuItem(
                              name: "История заказов",
                              icon: Icons.book_outlined,
                              route: OrderHistoryPage(),
                            ),
                            DrawerMenuItem(
                              name: "Адреса доставки",
                              icon: Icons.map_outlined,
                              route: PickAddressPage(
                                client: widget.user,
                              ),
                            ),
                            DrawerMenuItem(
                              name: "Поддержка",
                              icon: Icons.support_agent_rounded,
                              route: SupportPage(),
                            ),
                            DrawerMenuItem(
                              name: "Настройки",
                              icon: Icons.settings_outlined,
                              route: SettingsPage(),
                            )
                          ],
                        )))
                      ],
                    ))),
            backgroundColor: Colors.blueGrey.shade50,
            // !isCollapsed ? const Colors.deepOrangeAccent : Colors.white,
            body: SafeArea(
                child: CustomScrollView(
              controller: _sc,
              slivers: <Widget>[
                SliverAppBar(
                  actions: [Container()],
                  automaticallyImplyLeading: false,
                  elevation: 0,
                  forceElevated: true,
                  shape: LinearBorder(bottom: LinearBorderEdge(size: 1)),
                  shadowColor: Colors.transparent,
                  backgroundColor: !isCollapsed
                      ? Colors.deepOrangeAccent
                      : Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  foregroundColor: Colors.transparent,
                  // scrolledUnderElevation: collapsedBarHeight,
                  toolbarHeight: collapsedBarHeight,
                  snap: true,
                  centerTitle: false,
                  // stretch: true,
                  // Provide a standard title.
                  // title: ,
                  pinned: true,
                  // Allows the user to reveal the app bar if they begin scrolling
                  // back up the list of items.
                  floating: true,
                  expandedHeight: 0,
                  flexibleSpace: Container(),
                  title: AnimatedSwitcher(
                      duration: Durations.medium1,
                      child: isCollapsed
                          ? Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.blueGrey.shade200,
                                        offset: const Offset(5, 5),
                                        blurRadius: 5)
                                  ],
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(20))),
                              child: TextButton(
                                  onPressed: () {
                                    Navigator.push(context, CupertinoPageRoute(
                                      builder: (context) {
                                        return PickAddressPage(
                                          client: widget.user,
                                        );
                                      },
                                    ));
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          widget.currentAddress.isNotEmpty
                                              ? widget.currentAddress["address"]
                                              : "Нет адреса",
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ),
                                      const Icon(Icons.edit_outlined),
                                    ],
                                  )))
                          : Container(
                              alignment: Alignment.center,
                              color: Colors.deepOrangeAccent,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      TextButton(
                                          onPressed: () {
                                            Navigator.push(context,
                                                CupertinoPageRoute(
                                              builder: (context) {
                                                return PickAddressPage(
                                                  client: widget.user,
                                                );
                                              },
                                            ));
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    widget.currentAddress[
                                                            "city_name"] ??
                                                        "",
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 24,
                                                        color: Colors.white),
                                                  ),
                                                  const Icon(
                                                    Icons.arrow_drop_down,
                                                    color: Colors.white,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          )),
                                      Row(
                                        children: [
                                          IconButton(
                                              onPressed: () {},
                                              icon: Icon(
                                                Icons.favorite,
                                                color: Colors.white,
                                                size: 24,
                                              )),
                                          IconButton(
                                              onPressed: () {
                                                _key.currentState!
                                                    .openEndDrawer();
                                              },
                                              icon: Icon(
                                                Icons.menu,
                                                color: Colors.white,
                                                size: 24,
                                              )),
                                        ],
                                      )

                                      // IconButton(
                                      //     onPressed: () {},
                                      //     icon: Icon(Icons.settings, color: Colors.black,)),
                                    ],
                                  )
                                ],
                              ),
                            )),
                ),
                SliverLayoutBuilder(
                  builder: (context, constraints) {
                    if (scrollExtent == 0) {
                      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                        setState(() {
                          scrollExtent = constraints.precedingScrollExtent;
                        });
                      });
                    }
                    return SliverToBoxAdapter(
                      child: AnimatedContainer(
                          duration: Durations.medium2,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                spreadRadius: 5,
                                offset: Offset(0, -100),
                                color: !isStartingToCollapse
                                    ? Colors.deepOrangeAccent
                                    : Colors.blueGrey.shade50,
                              )
                            ],
                            color: !isStartingToCollapse
                                ? Colors.deepOrangeAccent
                                : Colors.blueGrey.shade50,
                          ),
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              AnimatedContainer(
                                duration: Durations.medium1,
                                height: 100,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                    boxShadow: [
                                      !isStartingToCollapse
                                          ? const BoxShadow(
                                              offset: Offset(0, -10),
                                              color: Colors.black26,
                                              blurRadius: 20)
                                          : const BoxShadow(
                                              color: Colors.white),
                                      BoxShadow(
                                          color: Colors.blueGrey.shade50,
                                          offset: Offset(0, 5),
                                          blurRadius: 5)
                                    ],
                                    color: Colors.blueGrey.shade50,
                                    borderRadius: !isCollapsed
                                        ? const BorderRadius.only(
                                            topLeft: Radius.elliptical(100, 50),
                                            topRight:
                                                Radius.elliptical(100, 50))
                                        : const BorderRadius.all(Radius.zero)),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    foregroundDecoration: BoxDecoration(
                                        color: !isStartingToCollapse
                                            ? Colors.deepOrangeAccent
                                                .withOpacity(0)
                                            : Colors.blueGrey.shade50),
                                    duration: Durations.medium1,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        AnimatedContainer(
                                            duration: Durations.medium1,
                                            // foregroundDecoration: BoxDecoration(color: isCollapsed ? Colors.deepOrangeAccent : Colors.transparent),
                                            width: double.infinity,
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height /
                                                4,
                                            margin: const EdgeInsets.all(15),
                                            decoration: const BoxDecoration(
                                                // color: Colors.pinkAccent,

                                                ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Spacer(
                                                      flex: 2,
                                                    ),
                                                    CircleAvatar(
                                                      radius:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .height /
                                                              16,
                                                    ),
                                                    const Spacer(),
                                                    Flexible(
                                                        flex: 3,
                                                        child: Text(
                                                            widget.user["name"],
                                                            style: GoogleFonts
                                                                .mulish(
                                                              textStyle: TextStyle(
                                                                  letterSpacing:
                                                                      1,
                                                                  fontSize: 24,
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900),
                                                            ))),
                                                    const Spacer(
                                                      flex: 2,
                                                    )
                                                  ],
                                                ),
                                                const Spacer(),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Flexible(
                                                      child: TextButton(
                                                          onPressed: () {},
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .max,
                                                            children: [
                                                              Flexible(
                                                                child: Text(
                                                                  widget.currentAddress
                                                                          .isNotEmpty
                                                                      ? widget.currentAddress[
                                                                          "address"]
                                                                      : "Нет адреса",
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          16,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 10,
                                                              ),
                                                              const Icon(
                                                                Icons
                                                                    .edit_outlined,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ],
                                                          )),
                                                    )
                                                  ],
                                                ),
                                                const Spacer(
                                                  flex: 2,
                                                )
                                              ],
                                            ))
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: double.infinity,
                                    height:
                                        MediaQuery.of(context).size.height / 5,
                                    margin: const EdgeInsets.all(15),
                                    padding: const EdgeInsets.all(30),
                                    decoration: const BoxDecoration(
                                      color: Colors.blueGrey,
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(30)),
                                      boxShadow: [
                                        BoxShadow(
                                            offset: Offset(0, -1),
                                            color: Colors.black26,
                                            blurRadius: 5)
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Flexible(
                                                fit: FlexFit.tight,
                                                child: Text(
                                                  "ALLCO",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 136 *
                                                        (screenSize / 720),
                                                    fontWeight: FontWeight.w700,
                                                    fontFamily: "montserrat",
                                                    // shadows: [
                                                    //   Shadow(
                                                    //     color: Colors.black26,
                                                    //     blurRadius: 15,
                                                    //     offset: Offset(0, 0),
                                                    //   ),
                                                    // ],
                                                    height: 1,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              )
                            ],
                          )),
                    );
                  },
                ),
                SliverToBoxAdapter(
                    child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: 200,
                  child: SingleChildScrollView(
                    controller: ScrollController(),
                    scrollDirection: Axis.horizontal,
                    child: ListView.builder(
                      padding: EdgeInsets.all(5),
                      primary: false,
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.businesses.length,
                      itemBuilder: (context, index) {
                        return BusinessItem(business: widget.businesses[index]);
                      },
                    ),
                  ),
                )),
                SliverToBoxAdapter(
                  child: Container(
                    height: MediaQuery.of(context).size.height,
                  ),
                )
              ],
            ))));
  }
}

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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(bottomRight: Radius.circular(15)),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                offset: Offset(5, 3), blurRadius: 5, color: Colors.black12)
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
                flex: 1,
                child: Container(
                  margin: EdgeInsets.all(10),
                  child: Icon(
                    widget.icon,
                    size: 48 * (MediaQuery.of(context).size.width / 720),
                  ),
                )),
            Flexible(
                flex: 2,
                child: Text(widget.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize:
                            36 * (MediaQuery.of(context).size.width / 720))))
          ],
        ),
      ),
    );
  }
}

class BusinessItem extends StatefulWidget {
  const BusinessItem({super.key, required this.business});
  final Map business;
  @override
  State<BusinessItem> createState() => BusinessItemState();
}

class BusinessItemState extends State<BusinessItem> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) {
              return HomePage(
                business: widget.business,
              ); //! TOOD: Change to redirect page to a different organizations or do this right here.
            },
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.all(5),
        width: 300,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                offset: Offset(2, 2), blurRadius: 2, color: Colors.black12),
          ],
          borderRadius: const BorderRadius.all(
            Radius.circular(10),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                  height: double.infinity,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: widget.business["img"],
                    errorWidget: (context, url, error) {
                      return const SizedBox();
                    },
                  )),
            ),
            Expanded(
                child: Container(
                    padding: EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                widget.business["name"],
                                style: TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              widget.business["address"],
                              style: TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 14),
                            )
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                "Короткое описание",
                                style: TextStyle(
                                    fontWeight: FontWeight.w500, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ))),
          ],
        ),
      ),
    );
  }
}
