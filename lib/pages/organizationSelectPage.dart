import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/agreements/offer.dart';
import 'package:naliv_delivery/pages/bonusesPage.dart';
import 'package:naliv_delivery/pages/createProfilePage.dart';
import 'package:naliv_delivery/pages/pickOnMap.dart';
import 'package:naliv_delivery/pages/preLoadDataPage.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/homePage.dart';
import 'package:naliv_delivery/pages/orderHistoryPage.dart';
import 'package:naliv_delivery/pages/pickAddressPage.dart';
import 'package:naliv_delivery/pages/settingsPage.dart';
import 'package:naliv_delivery/pages/supportPage.dart';
import 'package:google_fonts/google_fonts.dart';

class OrganizationSelectPage extends StatefulWidget {
  const OrganizationSelectPage({super.key, required this.addresses, required this.currentAddress, required this.user, required this.businesses});
  final List addresses;
  final Map currentAddress;
  final Map<String, dynamic> user;
  final List<Map> businesses;
  @override
  State<OrganizationSelectPage> createState() => _OrganizationSelectPageState();
}

class _OrganizationSelectPageState extends State<OrganizationSelectPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  double _lat = 0;
  double _lon = 0;
  String? _currentAddressName;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void toggleDrawer() async {
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      _scaffoldKey.currentState!.openEndDrawer();
    } else {
      _scaffoldKey.currentState!.openDrawer();
    }
  }

  // ! TODO: TAKE THIS DATA FROM BACKEND
  List<Map> _carouselItems = [
    {"name": "Алкоголь", "image": "https://status-k.ru/wp-content/uploads/2021/06/alkogol-440x440.png"},
    {"name": "Восточная кухня", "image": "https://hameleone.ru/wp-content/uploads/b/d/8/bd82d2a87e536da74b742da3ee8cc058.jpeg"},
    {"name": "Какая-то еще кухня", "image": "https://hameleone.ru/wp-content/uploads/b/d/8/bd82d2a87e536da74b742da3ee8cc058.jpeg"},
    {"name": "Надо будет написать бэк для этого", "image": "https://hameleone.ru/wp-content/uploads/b/d/8/bd82d2a87e536da74b742da3ee8cc058.jpeg"},
    {"name": "Потому что здесь", "image": "https://hameleone.ru/wp-content/uploads/b/d/8/bd82d2a87e536da74b742da3ee8cc058.jpeg"},
    {"name": "просто массив", "image": "https://hameleone.ru/wp-content/uploads/b/d/8/bd82d2a87e536da74b742da3ee8cc058.jpeg"},
  ];

  void _initData() {
    setState(() {
      print(widget.businesses);
      // widget.currentAddress = widget.currentAddress;
      // user = widget.user;
      // widget.addresses = widget.addresses;
    });
  }

  double collapsedBarHeight = 200 * globals.scaleParam;
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
      if (value != null) {
        List objects = value;

        double lat = double.parse(objects.first["GeoObject"]["Point"]["pos"].toString().split(' ')[1]);
        double lon = double.parse(objects.first["GeoObject"]["Point"]["pos"].toString().split(' ')[0]);
        if (mounted) {
          setState(() {
            _currentAddressName = objects.first["GeoObject"]["name"] ?? "";
            _lat = lat;
            _lon = lon;
          });
        }
      }
    });
  }

  Future<void> _getPosition() async {
    await determinePosition(context).then((v) {
      if (globals.addressSelectPopUpDone == false) {
        searchGeoData(v.longitude, v.latitude).then((vv) {
          if (_currentAddressName != widget.currentAddress["address"]) {
            bool isAddressAlreadyExist = false;
            for (var address in widget.addresses) {
              print(address["name"]);
              if (address["address"] == _currentAddressName) {
                isAddressAlreadyExist = true;
                showModalBottomSheet(
                  backgroundColor: Colors.white,
                  context: context,
                  builder: (context) {
                    return Container(
                      padding: EdgeInsets.all(50 * globals.scaleParam),
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                    child: Text(
                                  "Изменить адрес доставки?",
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 76 * globals.scaleParam, color: Colors.black),
                                )),
                                SizedBox(
                                  height: 10 * globals.scaleParam,
                                ),
                                Flexible(
                                    child: Text(
                                  _currentAddressName!,
                                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 48 * globals.scaleParam, color: Colors.black),
                                )),
                                SizedBox(
                                  height: 10 * globals.scaleParam,
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "Подъезд/Вход: ",
                                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 32 * globals.scaleParam),
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        address["entrance"] ?? "-",
                                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 32 * globals.scaleParam),
                                      ),
                                    )
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "Этаж: ",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 32 * globals.scaleParam,
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        address["floor"] ?? "-",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 32 * globals.scaleParam,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "Квартира/Офис: ",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 32 * globals.scaleParam,
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        address["apartment"] ?? "-",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 32 * globals.scaleParam,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        address["other"] ?? "-",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 32 * globals.scaleParam,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(
                                  style: IconButton.styleFrom(
                                      backgroundColor: Colors.tealAccent.shade700, padding: EdgeInsets.all(20 * globals.scaleParam)),
                                  onPressed: () {
                                    selectAddressClient(address["address_id"], widget.user["user_id"]).then((q) {
                                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
                                        builder: (context) {
                                          return PreLoadDataPage(
                                              // business: widget.business,
                                              // client: widget.client,
                                              // customAddress: _addresses[index],
                                              );
                                        },
                                      ), (Route<dynamic> route) => false);
                                    });
                                  },
                                  icon: Icon(
                                    Icons.done_sharp,
                                    size: 76 * globals.scaleParam,
                                    color: Colors.white,
                                  )),
                              SizedBox(
                                height: 10 * globals.scaleParam,
                              ),
                              IconButton(
                                  style: IconButton.styleFrom(
                                      backgroundColor: Colors.redAccent.shade700, padding: EdgeInsets.all(20 * globals.scaleParam)),
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  icon: Icon(
                                    Icons.close_sharp,
                                    size: 76 * globals.scaleParam,
                                    color: Colors.white,
                                  )),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                );
              }
            }
            if (!isAddressAlreadyExist) {
              showModalBottomSheet(
                backgroundColor: Colors.white,
                context: context,
                builder: (context) {
                  return Container(
                    padding: EdgeInsets.all(50 * globals.scaleParam),
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                  child: Text(
                                "Изменить адрес доставки?",
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 76 * globals.scaleParam, color: Colors.black),
                              )),
                              SizedBox(
                                height: 10 * globals.scaleParam,
                              ),
                              Flexible(
                                  child: Text(
                                _currentAddressName!,
                                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 48 * globals.scaleParam, color: Colors.black),
                              )),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            IconButton(
                                style: IconButton.styleFrom(
                                    backgroundColor: Colors.tealAccent.shade700, padding: EdgeInsets.all(20 * globals.scaleParam)),
                                onPressed: () {
                                  globals.addressSelectPopUpDone = true;

                                  showModalBottomSheet(
                                    backgroundColor: Colors.white,
                                    barrierColor: Colors.black45,
                                    isScrollControlled: true,
                                    context: context,
                                    useSafeArea: true,
                                    builder: (context) {
                                      return CreateAddressPage(
                                        lat: _lat,
                                        lon: _lon,
                                        addressName: _currentAddressName!,
                                        isFromCreateOrder: false,
                                      );
                                    },
                                  );
                                },
                                icon: Icon(
                                  Icons.done_sharp,
                                  size: 76 * globals.scaleParam,
                                  color: Colors.white,
                                )),
                            SizedBox(
                              height: 10 * globals.scaleParam,
                            ),
                            IconButton(
                                style: IconButton.styleFrom(
                                    backgroundColor: Colors.redAccent.shade700, padding: EdgeInsets.all(20 * globals.scaleParam)),
                                onPressed: () {
                                  globals.addressSelectPopUpDone = true;
                                  Navigator.pop(context);
                                },
                                icon: Icon(
                                  Icons.close_sharp,
                                  size: 76 * globals.scaleParam,
                                  color: Colors.white,
                                )),
                          ],
                        )
                      ],
                    ),
                  );
                },
              );
            }
          } else {}
        });
      }
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
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
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
  final GlobalKey<ScaffoldState> _key =
      GlobalKey(debugLabel: "вот это ключ, всем ключам ключ, надеюсь он тут не потеряется"); // lol, за что он отвечает?
  @override
  Widget build(BuildContext context) {
    super.build(context);

    // TextStyle titleStyle = TextStyle(
    //   fontSize: 50 * globals.scaleParam,
    //   fontWeight: FontWeight.w500,
    //   color: Theme.of(context).colorScheme.onSurface,
    // );

    // TextStyle plainStyle = TextStyle(
    //   fontSize: 32 * globals.scaleParam,
    //   fontWeight: FontWeight.w500,
    //   color: Theme.of(context).colorScheme.onSurface,
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
                      Text(
                        "НАЛИВ/ГРАДУСЫ24",
                        style: GoogleFonts.montserratAlternates(
                          textStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 48 * globals.scaleParam),
                        ),
                      ),
                      Icon(
                        Icons.local_dining_outlined,
                        color: Colors.black,
                        size: 48 * globals.scaleParam,
                      )
                    ],
                  ),
                ),
              ),
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
                        addresses: widget.addresses,
                      ),
                    ),
                    const DrawerMenuItem(
                      name: "Поддержка",
                      icon: Icons.support_agent_rounded,
                      route: SupportPage(),
                    ),
                    const DrawerMenuItem(
                      name: "Бонусы",
                      icon: Icons.card_membership_rounded,
                      route: BonusesPage(),
                    ),
                    const DrawerMenuItem(
                      name: "Оферта",
                      icon: Icons.list_alt,
                      route: OfferPage(
                        path: "assets/agreements/offer.md",
                      ),
                    ),
                    const DrawerMenuItem(
                      name: "Настройки",
                      icon: Icons.settings_outlined,
                      route: SettingsPage(),
                    ),
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
                    position: Tween<Offset>(begin: const Offset(0, -1), end: const Offset(0, -0.16)).animate(animation),
                    child: child,
                  );
                },
                duration: Durations.medium2,
                child: isCollapsed
                    ? Container(
                        key: ValueKey<bool>(isCollapsed),
                        decoration: BoxDecoration(borderRadius: const BorderRadius.all(Radius.circular(20))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) {
                                    return PickAddressPage(
                                      client: widget.user,
                                      addresses: widget.addresses,
                                    );
                                  },
                                ));
                              },
                              child: Container(
                                padding: EdgeInsets.all(40 * globals.scaleParam),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.all(Radius.circular(20))),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.currentAddress.isNotEmpty ? widget.currentAddress["address"] : "Нет адреса",
                                        style: TextStyle(fontSize: 32 * globals.scaleParam, fontWeight: FontWeight.w700),
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
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        height: 80,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Flexible(
                              fit: FlexFit.tight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (context) {
                                      return PickAddressPage(
                                        client: widget.user,
                                        addresses: widget.addresses,
                                      );
                                    },
                                  ));
                                },
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.currentAddress["city_name"] ?? "",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 36 * globals.scaleParam,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.black,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Flexible(
                              fit: FlexFit.tight,
                              child: TextButton(
                                onPressed: () {
                                  _key.currentState!.openEndDrawer();
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Flexible(
                                      flex: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                        ),
                                        child: Text(
                                          widget.user["name"] ?? "",
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 30 * globals.scaleParam,
                                            color: Colors.black,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Flexible(child: CircleAvatar()),
                                  ],
                                ),
                              ),
                            ),

                            // IconButton(
                            //     onPressed: () {},
                            //     icon: Icon(Icons.settings, color: Colors.black,)),
                          ],
                        ),
                      ),
              ),
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
                    padding: EdgeInsets.symmetric(horizontal: 60 * globals.scaleParam),
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
                              return PickAddressPage(
                                client: widget.user,
                                addresses: widget.addresses,
                              );
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
                              widget.currentAddress.isNotEmpty ? widget.currentAddress["address"] : "Нет адреса",
                              style: TextStyle(
                                  fontSize: 32 * globals.scaleParam,
                                  fontWeight: FontWeight.w500,
                                  color: !isCollapsed ? Colors.black : Colors.transparent),
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
              padding: EdgeInsets.symmetric(horizontal: 50 * globals.scaleParam, vertical: 20 * globals.scaleParam),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      "Категории",
                      style: TextStyle(fontSize: 48 * globals.scaleParam, fontWeight: FontWeight.w900, color: Colors.black),
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
                          margin: EdgeInsets.only(top: 5 * globals.scaleParam, bottom: 5 * globals.scaleParam, left: 25 * globals.scaleParam),
                          decoration: BoxDecoration(
                              boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5 * globals.scaleParam)],
                              color: Colors.grey.shade100,
                              borderRadius: const BorderRadius.all(Radius.circular(10))),
                          child: Stack(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10 * globals.scaleParam),
                                child: Image.network(
                                  _carouselItems[index]["image"],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              // Container(
                              //   width: double.infinity,
                              //   height: double.infinity,
                              //   decoration: const BoxDecoration(
                              //       gradient: LinearGradient(
                              //           transform: GradientRotation(pi / -2),
                              //           colors: [
                              //         Colors.black,
                              //         Colors.transparent
                              //       ])),
                              // ),
                              Container(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                        alignment: Alignment.topLeft,
                                        color: Colors.white,
                                        height: 80 * globals.scaleParam,
                                        padding: EdgeInsets.all(10 * globals.scaleParam),
                                        child: Row(
                                          children: [
                                            Flexible(
                                                child: Text(
                                              _carouselItems[index]["name"],
                                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 24 * globals.scaleParam),
                                            )),
                                          ],
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
              child: SizedBox(
                height: 50 * globals.scaleParam,
              ),
            ),
            BusinessSelectCarousel(
              businesses: widget.businesses,
              user: widget.user,
              currentAddress: widget.currentAddress,
            ),
            SliverToBoxAdapter(
              child: Container(
                height: 800 * globals.scaleParam,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class DrawerMenuItem extends StatefulWidget {
  const DrawerMenuItem({super.key, required this.name, required this.icon, required this.route});
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
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(bottomRight: Radius.circular(15)),
          color: Colors.white,
          boxShadow: [BoxShadow(offset: Offset(5, 3), blurRadius: 5, color: Colors.black12)],
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
                    size: 58 * globals.scaleParam,
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
  const BusinessItem({
    super.key,
    required this.business,
    required this.user,
  });
  final Map business;
  final Map user;
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
          MaterialPageRoute(
            builder: (context) {
              return HomePage(
                business: widget.business,
                user: widget.user,
              );
            },
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.all(10 * globals.scaleParam),
        // width: 650 * globals.scaleParam,
        // height: 600 * globals.scaleParam,

        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(offset: Offset(2, 2), blurRadius: 2, color: Colors.black12),
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
                      padding: EdgeInsets.symmetric(horizontal: 10 * globals.scaleParam),
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
                        ],
                      ),
                    ),
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
                                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 30 * globals.scaleParam),
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
                                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 30 * globals.scaleParam),
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
    );
  }
}

class BusinessSelectCarousel extends StatefulWidget {
  const BusinessSelectCarousel({super.key, required this.businesses, required this.user, required this.currentAddress});
  final List<Map> businesses;
  final Map user;
  final Map currentAddress;

  @override
  State<BusinessSelectCarousel> createState() => _BusinessSelectCarouselState();
}

class _BusinessSelectCarouselState extends State<BusinessSelectCarousel> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        mainAxisSpacing: 5 * globals.scaleParam,
        crossAxisSpacing: 5 * globals.scaleParam,
        maxCrossAxisExtent: MediaQuery.sizeOf(context).shortestSide / 2,
        mainAxisExtent: MediaQuery.sizeOf(context).shortestSide / 2,
      ),
      itemCount: widget.businesses.length,
      itemBuilder: (context, index) {
        return BusinessItem(
          business: widget.businesses[index],
          user: widget.user,
        );
      },
    );
  }
}
