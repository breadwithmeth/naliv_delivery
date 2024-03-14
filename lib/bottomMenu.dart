import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:naliv_delivery/misc.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/colors.dart';
import 'package:naliv_delivery/pages/addressesPage.dart';
import 'package:naliv_delivery/pages/businessSelectStartPage.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:naliv_delivery/pages/favPage.dart';
import 'package:naliv_delivery/pages/homePage.dart';
import 'package:naliv_delivery/pages/loginPage.dart';
import 'package:naliv_delivery/pages/profilePage.dart';
import 'package:naliv_delivery/pages/searchPage.dart';
import 'package:naliv_delivery/pages/settingsPage.dart';
import 'package:naliv_delivery/shared/commonAppBar.dart';

import 'main.dart';

class BottomMenu extends StatefulWidget {
  const BottomMenu({super.key});
  @override
  State<BottomMenu> createState() => _BottomMenuState();
}

class _BottomMenuState extends State<BottomMenu> {
  bool _loaded = false;

  late final Position _location;

  Widget _searchAppBar = AppBar();

  final List<BottomNavigationBarItem> _bottomNavigationBarItems = [
    const BottomNavigationBarItem(
        activeIcon: ImageIcon(AssetImage("assets/icons/home_active.png")),
        icon: ImageIcon(AssetImage("assets/icons/home.png")),

        // icon: SizedBox(
        //   child: Image.asset("assets/icons/home_filled.png"),
        //   width: 25,
        //   height: 25,
        // ),
        label: "Каталог"),
    const BottomNavigationBarItem(
        activeIcon: ImageIcon(AssetImage("assets/icons/like_active.png")),
        icon: ImageIcon(AssetImage("assets/icons/like.png")),

        // icon: SizedBox(
        //   child: Image.asset("assets/icons/fav_outlined.png"),
        //   width: 25,
        //   height: 25,
        // ),
        label: "Любимое"),
    const BottomNavigationBarItem(
        activeIcon: ImageIcon(AssetImage("assets/icons/cart_active.png")),
        icon: ImageIcon(AssetImage("assets/icons/cart.png")),

        // icon: SizedBox(
        //   child: Image.asset("assets/icons/shop_outlined.png"),
        //   width: 25,
        //   height: 25,
        // ),
        label: "Корзина"),
  ];

  String businessName = "";
  String businessAddress = "";
  String businessCity = "";
  late Image businessLogo;
  Widget _stores = Container();

  bool _isMinimized = false;

  List<Widget> menuItems = [
    const HomePage(),
    const FavPage(),
    const CartPage(),
  ];

  List<AppBar> appbars = [];

  void _setAppbars(context, String logourl) {
    appbars.add(
      AppBar(
          automaticallyImplyLeading: true,
          // leading: IconButton(
          //   icon: Icon(Icons.menu),
          //   onPressed: () {},
          // ),
          title: TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) {
                    return SearchPage();
                  },
                ));
              },
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 15),
                padding: EdgeInsets.all(5),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.all(Radius.circular(30))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Spacer(
                      flex: 3,
                    ),
                    Text(
                      "Найти",
                      style: TextStyle(
                          fontWeight: FontWeight.w500, color: Colors.black),
                    ),
                    // Expanded(
                    //   flex: 2,
                    //   child: Image.network(
                    //     logourl,
                    //     fit: BoxFit.contain,
                    //     frameBuilder: (BuildContext context, Widget child,
                    //         int? frame, bool? wasSynchronouslyLoaded) {
                    //       return Padding(
                    //         padding: const EdgeInsets.all(8.0),
                    //         child: child,
                    //       );
                    //     },
                    //     loadingBuilder: (BuildContext context, Widget child,
                    //         ImageChunkEvent? loadingProgress) {
                    //       return Center(child: child);
                    //     },
                    //   ),
                    // ),
                    Container(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.search,
                          color: Colors.black,
                        )),
                  ],
                ),
              ))),
    );
    appbars.add(
      AppBar(),
    );
    appbars.add(
      AppBar(),
    );
  }

  int appbarIndex = 0;

  Map<String, dynamic>? currentBusiness = {};

  void getCurrentStore() {}

  Future<void> _getBusinesses() async {
    List? businesses = await getBusinesses();
    if (businesses == null) {
      print("");
    } else {
      List<Widget> businessesWidget = [];
      for (var element in businesses) {
        double dist = getDisc(
            double.parse(element["lat"]),
            double.parse(element["lon"]),
            double.parse(element["user_lat"]),
            double.parse(element["user_lon"]));
        print(dist);
        businessesWidget.add(TextButton(
          onPressed: () async {
            if (await setCurrentStore(element["business_id"])) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Main()),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.pin_drop_outlined,
                      color: Colors.black,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          element["name"] ?? "",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black),
                        ),
                        Text(
                          element["address"] ?? "",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        dist >= 1
                            ? Text(
                                "${dist.toStringAsPrecision(1)}км",
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey.shade400),
                              )
                            : Text(
                                "${(dist * 1000).toStringAsFixed(0)}м",
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey.shade400),
                              ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          "Открыто",
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade400),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(
                  height: 10,
                )
              ],
            ),
          ),
        ));
      }
      setState(() {
        _stores = Column(
          children: businessesWidget,
        );
      });
      print(businessesWidget);
    }
  }

  void _getImage(String image) {
    Image businessImage = Image.network(image);

    businessImage.image
        .resolve(ImageConfiguration())
        .addListener(ImageStreamListener(
      (image, synchronousCall) {
        if (mounted) {
          setState(() {
            _loaded = true;
            businessLogo = businessImage;
            print(businessLogo);
            print("|||||||||");
          });
        }
      },
    ));
  }

  String dropdownValue = "Two";
  int _page = 0;
  Widget _dropDownButtonStore = Container();
  final PageController _pageController = PageController(
    onAttach: (position) {},
    onDetach: (position) {},
  );

  Future<void> getPosition() async {
    Position location = await determinePosition();
    print(location.latitude);
    print(location.longitude);
    setCityAuto(location.latitude, location.longitude);
    setState(() {
      _location = location;
    });
  }

  Future<void> _getLastSelectedBusiness() async {
    await getLastSelectedBusiness().then((value) {
      if (value == null) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const BusinessSelectStartPage()),
        );
      }
      _getImage(value!["logo"]);

      setState(() {
        // _pageController.animateToPage(widget.page,
        //     duration: const Duration(seconds: 1), curve: Curves.easeInCirc);
        _setAppbars(context, value["logo"]);
        businessName = value!['name'];
        businessAddress = value['address'];
        currentBusiness = value;
        // _currentAppBar = appbars[widget.page];
      });
    });
  }

  Map user = {};
  Future<void> _getUser() async {
    Map<String, dynamic>? user = await getUser();
    if (user != null) {
      setState(() {
        user = user;
      });
    }
  }

  StreamController _dataStreamController = StreamController();

  Future<void> loadData() async {
    await _getLastSelectedBusiness();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getLastSelectedBusiness();
    getPosition();
    _getBusinesses();
    _getUser();
    setState(() {});
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: false,
      extendBody: false,
      bottomNavigationBar: BottomNavigationBar(
        showSelectedLabels: true,
        showUnselectedLabels: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        unselectedLabelStyle:
            const TextStyle(fontSize: 12, color: Colors.black),
        selectedLabelStyle: const TextStyle(
            fontSize: 12, color: Colors.black, fontWeight: FontWeight.w500),
        selectedItemColor: const Color(0xFFEE7203),
        // unselectedItemColor: Colors.black,
        iconSize: 24,
        type: BottomNavigationBarType.fixed,
        currentIndex: _page,
        items: _bottomNavigationBarItems,
        onTap: (value) {
          _pageController.animateToPage(value,
              duration: Duration(microseconds: 200), curve: Curves.bounceIn);
        },
      ),
      appBar: appbars.isNotEmpty ? appbars[_page] : AppBar(),
      drawer: _drawer(),
      // appBar: AppBar(
      //   // leading: Container(),
      //   automaticallyImplyLeading: false,
      //   systemOverlayStyle: SystemUiOverlayStyle(
      //       statusBarColor: Colors.white,
      //       systemNavigationBarDividerColor: Colors.white,
      //       systemNavigationBarColor: Colors.white,
      //       statusBarBrightness: Brightness.light,
      //       statusBarIconBrightness: Brightness.dark),
      //   // bottomOpacity: 0.5,
      //   // toolbarHeight: _toolbarheight,
      //   // flexibleSpace: _currentAppBar,
      // ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // floatingActionButton: Container(
      //     clipBehavior: Clip.hardEdge,
      //     decoration: BoxDecoration(
      //       color: Colors.white70,
      //     ),
      //     padding: EdgeInsets.symmetric(horizontal: 10),
      //     margin: EdgeInsets.only(top: 10),
      //     child: BackdropFilter(
      //       filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      //       child: BottomNavigationBar(
      //         backgroundColor: Colors.transparent,
      //         elevation: 0,
      //         unselectedLabelStyle:
      //             TextStyle(fontSize: 12, color: Colors.black),
      //         selectedLabelStyle: TextStyle(
      //             fontSize: 12,
      //             color: Colors.black,
      //             fontWeight: FontWeight.w500),
      //         selectedItemColor: Colors.black,
      //         unselectedItemColor: Colors.black,
      //         iconSize: 24,
      //         type: BottomNavigationBarType.fixed,
      //         currentIndex: _curentIndex,
      //         items: _bottomNavigationBarItems,
      //         onTap: (value) {
      //           setState(() {
      //             _curentIndex = value;
      //             _pageController.jumpToPage(value);
      //             _currentAppBar = appbars[_curentIndex];
      //           });
      //         },
      //       ),
      //     )),
      // // bottomNavigationBar:
      // body: PageView.builder(
      //   controller: _pageController,
      //   physics: const NeverScrollableScrollPhysics(),
      //   children: menuItems,
      // ),

      body: PageView.builder(
        itemCount: menuItems.length,
        pageSnapping: true,
        onPageChanged: (value) {
          setState(() {
            _page = value;
          });
        },
        itemBuilder: (context, index) {
          return menuItems[index];
        },
        controller: _pageController,
      ),
    );
  }

  Drawer _drawer() {
    return Drawer(
        child: SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: MediaQuery.of(context).size.width * 0.10,
                    backgroundImage: const NetworkImage(
                        "https://air-fom.com/wp-content/uploads/2018/06/real_1920.jpg"),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  // TODO: activate this code in production
                  // SizedBox(
                  //   width: MediaQuery.of(context).size.width * 0.3,
                  //   child: Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       Text(
                  //         user["name"] ?? "",
                  //         style: const TextStyle(
                  //             color: Colors.black,
                  //             fontWeight: FontWeight.w500,
                  //             fontSize: 16),
                  //       ),
                  //       Text(
                  //         user["login"] ?? "",
                  //         style: const TextStyle(
                  //             color: Colors.black,
                  //             fontWeight: FontWeight.w400,
                  //             fontSize: 14),
                  //       ),
                  //       Text(
                  //         user["user_id"] ?? "",
                  //         style: TextStyle(
                  //             color: Colors.grey.shade400,
                  //             fontWeight: FontWeight.w400,
                  //             fontSize: 14),
                  //       )
                  //     ],
                  //   ),
                  // )
                ],
              ),
            ),
          ),
          const Divider(),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20)),
                  onPressed: () {},
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 24,
                        color: Colors.black,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        "История заказов",
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w400,
                            fontSize: 20),
                      )
                    ],
                  ),
                ),
                const Divider(),
                TextButton(
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AddressesPage()),
                    );
                  },
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.home_outlined,
                        size: 24,
                        color: Colors.black,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        "Адреса доставки",
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w400,
                            fontSize: 20),
                      )
                    ],
                  ),
                ),
                const Divider(),
                TextButton(
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20)),
                  onPressed: () {},
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.credit_card,
                        size: 24,
                        color: Colors.black,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        "Карты оплаты",
                        style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w400,
                            fontSize: 20),
                      )
                    ],
                  ),
                ),
                const Divider(),
                TextButton(
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20)),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) {
                        return const SettingsPage();
                      },
                    ));
                  },
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        size: 24,
                        color: Colors.black,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        "Настройки",
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w400,
                            fontSize: 20),
                      )
                    ],
                  ),
                ),
                const Divider(),
                TextButton(
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20)),
                  onPressed: () {},
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 24,
                        color: Colors.black,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        "Поддержка",
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w400,
                            fontSize: 20),
                      )
                    ],
                  ),
                ),
                const Divider(),
                TextButton(
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20)),
                  onPressed: () {
                    print(123);
                    logout();
                    Navigator.pushReplacement(context, MaterialPageRoute(
                      builder: (context) {
                        return const LoginPage();
                      },
                    ));
                  },
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.exit_to_app_outlined,
                        size: 24,
                        color: Colors.black,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        "Выйти",
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w400,
                            fontSize: 20),
                      )
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    ));
  }
}
