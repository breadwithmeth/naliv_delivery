import 'dart:math';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:naliv_delivery/pages/createProfilePage.dart';
import '../globals.dart' as globals;

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
import 'package:intl/intl.dart';

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
  final List<Map> businesses;
  @override
  State<OrganizationSelectPage> createState() => _OrganizationSelectPageState();
}

class _OrganizationSelectPageState extends State<OrganizationSelectPage>
    with AutomaticKeepAliveClientMixin {
  bool get wantKeepAlive => true;

  double _lat = 0;
  double _lon = 0;
  String? _currentAddressName;

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

  void toggleDrawer() async {
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      _scaffoldKey.currentState!.openEndDrawer();
    } else {
      _scaffoldKey.currentState!.openDrawer();
    }
  }

  List<Map> _carouselItems = [
    {
      "name": "Алкоголь",
      "image":
          "https://hameleone.ru/wp-content/uploads/b/d/8/bd82d2a87e536da74b742da3ee8cc058.jpeg"
    },
    {
      "name": "Восточная кухня",
      "image":
          "https://hameleone.ru/wp-content/uploads/b/d/8/bd82d2a87e536da74b742da3ee8cc058.jpeg"
    },
    {
      "name": "Какая-то еще кухня",
      "image":
          "https://hameleone.ru/wp-content/uploads/b/d/8/bd82d2a87e536da74b742da3ee8cc058.jpeg"
    },
    {
      "name": "Надо будет написать бэк для этого",
      "image":
          "https://hameleone.ru/wp-content/uploads/b/d/8/bd82d2a87e536da74b742da3ee8cc058.jpeg"
    },
    {
      "name": "Потому что здесь",
      "image":
          "https://hameleone.ru/wp-content/uploads/b/d/8/bd82d2a87e536da74b742da3ee8cc058.jpeg"
    },
    {
      "name": "просто массив",
      "image":
          "https://hameleone.ru/wp-content/uploads/b/d/8/bd82d2a87e536da74b742da3ee8cc058.jpeg"
    },
  ];

  void _initData() {
    setState(() {
      print(widget.businesses);
      // widget.currentAddress = widget.currentAddress;
      // user = widget.user;
      // widget.addresses = widget.addresses;
    });
  }

  double collapsedBarHeight = 80.0;
  double expandedBarHeight = 200.0;
  _scrollListener() {
    if (_sc.position.minScrollExtent + collapsedBarHeight / 2 < _sc.offset) {
      if (!isCollapsed) {
        setState(() {
          isCollapsed = true;
        });
      }
    } else {
      if (isCollapsed) {
        // _sc.animateTo(0, duration: Durations.medium1, curve: Curves.easeIn);
        setState(() {
          isCollapsed = false;
        });
      }
    }
    if (_sc.position.minScrollExtent + 10 < _sc.offset) {
      if (!isStartingToCollapse) {
        // _sc.animateTo(scrollExtent + collapsedBarHeight * 2,
        //     duration: Durations.medium1, curve: Curves.easeIn);
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

  Future<void> searchGeoData(double lon, double lat) async {
    await getGeoData(lon.toString() + "," + lat.toString()).then((value) {
      print(value);
      List objects = value?["response"]["GeoObjectCollection"]["featureMember"];

      double lat = double.parse(
          objects.first["GeoObject"]["Point"]["pos"].toString().split(' ')[1]);
      double lon = double.parse(
          objects.first["GeoObject"]["Point"]["pos"].toString().split(' ')[0]);
      setState(() {
        _currentAddressName = objects.first["GeoObject"]["name"];
        _lat = lat;
        _lon = lon;
      });
    });
  }

  Future<void> _getPosition() async {
    await determinePosition(context).then((v) {
      searchGeoData(v.longitude, v.latitude).then((vv) {
        showModalBottomSheet(
          context: context,
          builder: (context) {
            return Container(
              width: double.infinity,
              child: Column(
                children: [Text(_currentAddressName!)],
              ),
            );
          },
        );
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _sc.addListener(_scrollListener);
    _getPosition();

    // Future.delayed(Duration.zero).then((value) async {
    //   _getUser();
    // });
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (widget.user["name"].toString().isEmpty) {
        Navigator.pushAndRemoveUntil(context, CupertinoPageRoute(
          builder: (context) {
            return const ProfileCreatePage();
          },
        ), (route) => false);
      }
    });
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
    super.build(context);

    // TextStyle titleStyle = TextStyle(
    //   fontSize: 50 * globals.scaleParam,
    //   fontWeight: FontWeight.w500,
    //   color: Theme.of(context).colorScheme.onBackground,
    // );

    // TextStyle plainStyle = TextStyle(
    //   fontSize: 32 * globals.scaleParam,
    //   fontWeight: FontWeight.w500,
    //   color: Theme.of(context).colorScheme.onBackground,
    // );

    // final scrollController = useScrollController();
    // final isCollapsed = useState(false);

    return Scaffold(
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
              Flexible(
                fit: FlexFit.tight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () {
                        _key.currentState!.closeEndDrawer();
                      },
                      icon: Container(
                        padding: EdgeInsets.all(20 * globals.scaleParam),
                        child: Icon(
                          Icons.close,
                          size: 48 * globals.scaleParam,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                  fit: FlexFit.tight,
                  child: Container(
                    alignment: Alignment.center,
                    height: 275 * globals.scaleParam,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text("НАЗВАНИЕ",
                            style: GoogleFonts.montserratAlternates(
                              textStyle: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 48 * globals.scaleParam),
                            )),
                        Icon(
                          Icons.local_dining_outlined,
                          color: Colors.black,
                          size: 48 * globals.scaleParam,
                        )
                      ],
                    ),
                  )),
              Flexible(
                flex: 8,
                fit: FlexFit.tight,
                child: GridView.count(
                  padding: EdgeInsets.all(10 * globals.scaleParam),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2 / 1,
                  crossAxisCount: 2,
                  children: [
                    DrawerMenuItem(
                      name: "История заказов",
                      icon: Icons.book_outlined,
                      route: const OrderHistoryPage(),
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
                      route: const SupportPage(),
                    ),
                    DrawerMenuItem(
                      name: "Настройки",
                      icon: Icons.settings_outlined,
                      route: const SettingsPage(),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.white,
      // !isCollapsed ?      globals.mainColor : Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          controller: _sc,
          slivers: <Widget>[
            SliverAppBar(
              actions: [Container()],
              automaticallyImplyLeading: false,
              elevation: 0,
              forceElevated: true,
              shape: const LinearBorder(bottom: LinearBorderEdge(size: 1)),
              shadowColor: Colors.transparent,
              backgroundColor: !isCollapsed ? Colors.white : Colors.transparent,
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
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, -1),
                              end: const Offset(0, 0))
                          .animate(animation),
                      child: child,
                    );
                  },
                  duration: Durations.medium2,
                  child: isCollapsed
                      ? Container(
                          key: ValueKey<bool>(isCollapsed),
                          decoration: BoxDecoration(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(20))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              TextButton(
                                  onPressed: () {
                                    Navigator.push(context, CupertinoPageRoute(
                                      builder: (context) {
                                        return PickAddressPage(
                                          client: widget.user,
                                        );
                                      },
                                    ));
                                  },
                                  child: Container(
                                    padding:
                                        EdgeInsets.all(30 * globals.scaleParam),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(20))),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            widget.currentAddress.isNotEmpty
                                                ? widget
                                                    .currentAddress["address"]
                                                : "Нет адреса",
                                            style: TextStyle(
                                                fontSize:
                                                    32 * globals.scaleParam,
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 10 * globals.scaleParam,
                                        ),
                                        Icon(
                                          Icons.edit_outlined,
                                          size: 48 * globals.scaleParam,
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ))
                      : Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(20))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.end,
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                widget.currentAddress[
                                                        "city_name"] ??
                                                    "",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize:
                                                        48 * globals.scaleParam,
                                                    color: Colors.black),
                                              ),
                                              const Icon(
                                                Icons.arrow_drop_down,
                                                color: Colors.black,
                                              ),
                                            ],
                                          ),
                                        ],
                                      )),
                                  TextButton(
                                      onPressed: () {
                                        _key.currentState!.openEndDrawer();
                                      },
                                      child: Container(
                                        width:
                                            MediaQuery.of(context).size.width /
                                                4,
                                        alignment: Alignment.centerRight,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              flex: 3,
                                              child: Text(
                                                widget.user["name"],
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                    fontSize:
                                                        30 * globals.scaleParam,
                                                    color: Colors.black,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 10,
                                            ),
                                            CircleAvatar(),
                                          ],
                                        ),
                                      )),

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
              builder: (context, raints) {
                if (scrollExtent == 0) {
                  WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                    setState(() {
                      scrollExtent = raints.precedingScrollExtent;
                    });
                  });
                }
                return SliverToBoxAdapter(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 50 * globals.scaleParam),
                    color: Colors.white,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.all(0),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              return PickAddressPage(client: widget.user);
                            },
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Flexible(
                            child: Text(
                              widget.currentAddress.isNotEmpty
                                  ? widget.currentAddress["address"]
                                  : "Нет адреса",
                              style: TextStyle(
                                  fontSize: 32 * globals.scaleParam,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black),
                            ),
                          ),
                          SizedBox(
                            width: 20 * globals.scaleParam,
                          ),
                          Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 48 * globals.scaleParam,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
                child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 50 * globals.scaleParam,
                  vertical: 20 * globals.scaleParam),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      "Категории",
                      style: TextStyle(
                          fontSize: 48 * globals.scaleParam,
                          fontWeight: FontWeight.w900,
                          color: Colors.black),
                    ),
                  ),
                ],
              ),
            )),
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                height: 200 * globals.scaleParam,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  // addRepaintBoundaries: false,
                  shrinkWrap: true,
                  primary: false,
                  // controller: PageController(viewportFraction: 0.8),
                  itemCount: _carouselItems.length,
                  itemBuilder: (context, index) {
                    return Row(
                      children: [
                        Container(
                          width: 200 * globals.scaleParam,
                          height: 200 * globals.scaleParam,
                          clipBehavior: Clip.antiAlias,
                          margin: EdgeInsets.only(
                              top: 5 * globals.scaleParam,
                              left: 25 * globals.scaleParam),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(10))),
                          child: Stack(
                            children: [
                              Image.network(
                                _carouselItems[index]["image"],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                              Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                        transform: GradientRotation(pi / -2),
                                        colors: [
                                      Colors.black,
                                      Colors.transparent
                                    ])),
                              ),
                              Container(
                                padding:
                                    EdgeInsets.all(20 * globals.scaleParam),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Flexible(
                                        child: Text(
                                      _carouselItems[index]["name"],
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 24 * globals.scaleParam),
                                    ))
                                  ],
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
                child: Column(
              children: [
                SizedBox(
                  height: 500 * globals.scaleParam,
                  child: BusinessSelectCarousel(
                    businesses: widget.businesses,
                    user: widget.user,
                    currentAddress: widget.currentAddress,
                  ),
                )
              ],
            )),
            SliverToBoxAdapter(
              child: Container(
                height: 5000,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class DrawerMenuItem extends StatefulWidget {
  DrawerMenuItem(
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
        decoration: const BoxDecoration(
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
                  margin: EdgeInsets.all(20 * globals.scaleParam),
                  child: Icon(
                    widget.icon,
                    size: 48 * globals.scaleParam,
                  ),
                )),
            Flexible(
              flex: 2,
              child: Text(
                widget.name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 36 * globals.scaleParam,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BusinessItem extends StatefulWidget {
  BusinessItem({
    super.key,
    required this.business,
    required this.user,
    required this.isClosest,
  });
  final Map business;
  final Map user;
  final bool isClosest;
  @override
  State<BusinessItem> createState() => BusinessItemState();
}

class BusinessItemState extends State<BusinessItem> {
  String formatCost(String costString) {
    int cost = int.parse(costString);
    return NumberFormat("###,###", "en_US").format(cost);
  }

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
                user: widget.user,
              ); //! TOOD: Change to redirect page to a different organizations or do this right here.
            },
          ),
        );
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          margin: EdgeInsets.all(10 * globals.scaleParam),
          width: 650 * globals.scaleParam,
          // height: 600 * globals.scaleParam,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  offset: Offset(2, 2), blurRadius: 2, color: Colors.black12),
            ],
            borderRadius: BorderRadius.all(
              Radius.circular(10),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(children: [
                  CachedNetworkImage(
                    imageUrl: widget.business["img"],
                    height: double.infinity,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) {
                      return const SizedBox();
                    },
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10 * globals.scaleParam),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delivery_dining_rounded,
                              size: 48 * globals.scaleParam,
                            ),
                            Text(
                              "${formatCost("4000000")} ₸", // ! CHANGE TO ACTUAL DELIVERY COST
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                  fontSize: 32 * globals.scaleParam),
                            ),
                          ],
                        ),
                      ),
                      widget.isClosest
                          ? Text(
                              "Быстрая доставка",
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontSize: 32 * globals.scaleParam,
                                  backgroundColor: Colors.green),
                            )
                          : SizedBox(),
                    ],
                  ),
                ]),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: constraints.maxWidth * 0.9,
                          height: constraints.maxHeight * 0.9,
                          child: Column(
                            children: [
                              Flexible(
                                fit: FlexFit.tight,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.business["name"],
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 38 * globals.scaleParam,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Flexible(
                                fit: FlexFit.tight,
                                child: Row(
                                  children: [
                                    Flexible(
                                      fit: FlexFit.tight,
                                      child: Text(
                                        widget.business["address"],
                                        style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 30 * globals.scaleParam),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              Flexible(
                                fit: FlexFit.tight,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "Короткое описание",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 30 * globals.scaleParam),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BusinessSelectCarousel extends StatefulWidget {
  const BusinessSelectCarousel(
      {super.key,
      required this.businesses,
      required this.user,
      required this.currentAddress});
  final List<Map> businesses;
  final Map user;
  final Map currentAddress;

  @override
  State<BusinessSelectCarousel> createState() => _BusinessSelectCarouselState();
}

class _BusinessSelectCarouselState extends State<BusinessSelectCarousel> {
  String? _closestBusinessId;
  List<Map> _businesses = [];
  findClosestBusiness() {
    List<Map> businesses = [];

    double storex = double.parse(widget.businesses.first["lat"]);
    double storey = double.parse(widget.businesses.first["lon"]);
    double userx = double.parse(widget.currentAddress["lat"]);
    double usery = double.parse(widget.currentAddress["lon"]);
    double dist = sqrt(pow((storex - userx), 2) + pow((storey - usery), 2));
    String closestBusinessId = widget.businesses.first["business_id"];
    for (var i = 0; i < widget.businesses.length; i++) {
      double storex = double.parse(widget.businesses[i]["lat"]);
      double storey = double.parse(widget.businesses[i]["lon"]);
      double userx = double.parse(widget.currentAddress["lat"]);
      double usery = double.parse(widget.currentAddress["lon"]);
      double temp = sqrt(pow((storex - userx), 2) + pow((storey - usery), 2));

      if (temp < dist) {
        closestBusinessId = widget.businesses[i]["business_id"];
        businesses.insert(0, widget.businesses[i]);
      } else {
        businesses.add(widget.businesses[i]);
      }

      print(temp);
      // businesses!.sort((a, b) => (b['dist']).compareTo(a['dist']));
    }

    setState(() {
      _closestBusinessId = closestBusinessId;
      _businesses = businesses;
    });
    print(dist);
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    findClosestBusiness();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(10),
      shrinkWrap: true,
      primary: false,
      scrollDirection: Axis.horizontal,
      // itemExtent: 650 * globals.scaleParam,
      physics: PageScrollPhysics(),
      // controller: PageController(viewportFraction: .6),
      itemCount: widget.businesses.length,
      itemBuilder: (context, index) {
        if (_businesses[index]["business_id"] == _closestBusinessId) {
          return BusinessItem(
            business: _businesses[index],
            user: widget.user,
            isClosest: true,
          );
        } else {
          return BusinessItem(
            business: _businesses[index],
            user: widget.user,
            isClosest: false,
          );
        }
        // return Container(height: 10, width: 1000, color: Colors.yellow, child: Text("data"),);
      },
    );
  }
}
