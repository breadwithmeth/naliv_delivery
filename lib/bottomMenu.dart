import 'dart:ui';
import 'package:geolocator/geolocator.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:naliv_delivery/misc.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/colors.dart';
import 'package:naliv_delivery/pages/businessSelectStartPage.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:naliv_delivery/pages/favPage.dart';
import 'package:naliv_delivery/pages/homePage.dart';
import 'package:naliv_delivery/pages/profilePage.dart';
import 'package:naliv_delivery/shared/commonAppBar.dart';

import 'main.dart';

class BottomMenu extends StatefulWidget {
  BottomMenu({super.key, required this.page});
  final int page;
  @override
  State<BottomMenu> createState() => _BottomMenuState();
}

class _BottomMenuState extends State<BottomMenu> {
  late final Position _location;

  final List<BottomNavigationBarItem> _bottomNavigationBarItems = [
    BottomNavigationBarItem(
        activeIcon: ImageIcon(AssetImage("assets/icons/home_active.png")),
        icon: ImageIcon(AssetImage("assets/icons/home.png")),

        // icon: SizedBox(
        //   child: Image.asset("assets/icons/home_filled.png"),
        //   width: 25,
        //   height: 25,
        // ),
        label: "Каталог"),
    BottomNavigationBarItem(
        activeIcon: ImageIcon(AssetImage("assets/icons/like_active.png")),
        icon: ImageIcon(AssetImage("assets/icons/like.png")),

        // icon: SizedBox(
        //   child: Image.asset("assets/icons/fav_outlined.png"),
        //   width: 25,
        //   height: 25,
        // ),
        label: "Любимое"),
    BottomNavigationBarItem(
        activeIcon: ImageIcon(AssetImage("assets/icons/cart_active.png")),
        icon: ImageIcon(AssetImage("assets/icons/cart.png")),

        // icon: SizedBox(
        //   child: Image.asset("assets/icons/shop_outlined.png"),
        //   width: 25,
        //   height: 25,
        // ),
        label: "Корзина"),
    BottomNavigationBarItem(
        activeIcon: ImageIcon(AssetImage("assets/icons/profile_active.png")),
        icon: ImageIcon(AssetImage("assets/icons/profile.png")),

        // icon: SizedBox(
        //   child: Image.asset("assets/icons/person_outlined.png"),
        //   width: 25,
        //   height: 25,
        // ),
        label: "Профиль"),
  ];

  String businessName = "";
  String businessAddress = "";
  String businessCity = "";

  Widget _stores = Container();

  Widget minimizedAppBar = AppBar();
  Widget maximizedAppBar = AppBar();

  Widget _currentAppBar = AppBar();

  bool _isMinimized = false;
  List<String> list = <String>['One', 'Two', 'Three', 'Four'];

  List<Widget> menuItems = [HomePage(), FavPage(), CartPage(), ProfilePage()];

  double _toolbarheight = 80;

  List<Widget> appbars = [];
  int appbarIndex = 0;

  Map<String, dynamic>? currentBusiness = {};

  void changeAppBar() {
    if (!_isMinimized) {
      setState(() {
        _isMinimized = true;
        _currentAppBar = minimizedAppBar;
        _toolbarheight = 80;
      });
    } else {
      setState(() {
        _isMinimized = false;
        _currentAppBar = maximizedAppBar;
        _toolbarheight = MediaQuery.of(context).size.height * 1;
      });
    }
  }

  void getCurrentStore() {}

  void generateMaximizedAppBar() {
    print(123);
    _getBusinesses();
    Widget _maximizedAppBar = Container(
        height: MediaQuery.of(context).size.height,
        child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.white,
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: Column(
                children: [
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 10,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            child: Container(
                              margin: EdgeInsets.symmetric(vertical: 5),
                              padding: EdgeInsets.symmetric(
                                  vertical: 7, horizontal: 5),
                              color: Colors.black,
                              child: Text(
                                currentBusiness!["name"] ?? "",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17),
                              ),
                            ),
                            onTap: () {},
                          ),
                          SizedBox(
                            height: 5,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              // Text(
                              //   currentBusiness!["city"] ?? "",
                              //   style: TextStyle(fontSize: 12, color: gray1),
                              // ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 6,
                              ),
                              Text(
                                currentBusiness!["address"] ?? "",
                                style: TextStyle(fontSize: 12, color: gray1),
                              )
                            ],
                          )
                        ],
                      ),
                      Spacer(),
                      Row(children: [
                        IconButton(
                            onPressed: () {
                              setState(() {
                                _toolbarheight = 80;
                                initAppBar();
                              });
                            },
                            icon: Icon(Icons.close))
                      ]),
                      SizedBox(
                        width: 10,
                      ),
                    ],
                  ),
                  _stores
                ],
              ),
            )));
    setState(() {
      _currentAppBar = _maximizedAppBar;
      _toolbarheight = MediaQuery.of(context).size.height;
    });
  }

  Future<void> _getBusinesses() async {
    List? businesses = await getBusinesses();
    if (businesses == null) {
      print("");
    } else {
      List<Widget> _businessesWidget = [];
      businesses.forEach((element) {
        double dist = getDisc(
            double.parse(element["lat"]),
            double.parse(element["lon"]),
            double.parse(element["user_lat"]),
            double.parse(element["user_lon"]));
        print(dist);
        _businessesWidget.add(TextButton(
          onPressed: () async {
            if (await setCurrentStore(element["business_id"])) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Main()),
              );
            }
          },
          child: Container(
            padding: EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.pin_drop_outlined,
                      color: Colors.black,
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          element["name"] ?? "",
                          style: TextStyle(fontSize: 14, color: Colors.black),
                        ),
                        Text(
                          element["address"] ?? "",
                          style: TextStyle(fontSize: 14, color: Colors.black),
                        ),
                      ],
                    ),
                    Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        dist >= 1
                            ? Text(
                                dist.toStringAsPrecision(1) + "км",
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey.shade400),
                              )
                            : Text(
                                (dist * 1000).toStringAsFixed(0) + "м",
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey.shade400),
                              ),
                        SizedBox(
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
                SizedBox(
                  height: 10,
                )
              ],
            ),
          ),
        ));
      });
      setState(() {
        _stores = Column(
          children: _businessesWidget,
        );
      });
      print(_businessesWidget);
    }
  }

  String dropdownValue = "Two";
  int _curentIndex = 0;
  Widget _dropDownButtonStore = Container();
  PageController _pageController = PageController();

  Future<void> initAppBar() async {
    Map<String, dynamic>? business = await getLastSelectedBusiness();
    if (business == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BusinessSelectStartPage()),
      );
    }

    setState(() {
      print(_stores);

      minimizedAppBar = Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white70,
        ),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 10,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 5),
                      padding: EdgeInsets.symmetric(vertical: 7, horizontal: 5),
                      color: Colors.black,
                      child: Text(
                        business!["name"],
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 17),
                      ),
                    ),
                    onTap: () {
                      generateMaximizedAppBar();
                      // changeAppBar();
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //       builder: (context) => BusinessSelectStartPage()),
                      // );
                    },
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        business!["city"],
                        style: TextStyle(fontSize: 12, color: gray1),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 6,
                      ),
                      Text(
                        business!["address"],
                        style: TextStyle(fontSize: 12, color: gray1),
                      )
                    ],
                  )
                ],
              ),
              Spacer(),
              Row(children: [
                IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.search,
                      size: 28,
                    )),
                IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.notifications_outlined,
                      size: 28,
                    ))
              ]),
              SizedBox(
                width: 10,
              ),
            ],
          ),
        ),
      );
      appbars = [
        minimizedAppBar,
        CommonAppBar(
            business: business,
            title: "ЛЮБИМОЕ",
            titleIcon: Icon(Icons.favorite_outline),
            options: []),
        CommonAppBar(
            business: business,
            title: "КОРЗИНА",
            titleIcon: Icon(Icons.shopping_bag_outlined),
            options: []),
        CommonAppBar(
            business: business,
            title: "ПРОФИЛЬ",
            titleIcon: Icon(Icons.person_outlined),
            options: []),
      ];
      _currentAppBar = minimizedAppBar;
    });
  }

  void initDropDownButton() {
    setState(() {
      _dropDownButtonStore = DropdownButton(
          isDense: true,
          value: dropdownValue,
          icon: const Icon(Icons.arrow_downward),
          elevation: 16,
          style: const TextStyle(color: Colors.deepPurple),
          underline: Container(
            height: 2,
            color: Colors.deepPurpleAccent,
          ),
          onChanged: (value) {
            setState(() {
              dropdownValue = value!;
            });
          },
          items: [
            DropdownMenuItem(
              child: Text("One"),
              value: "One",
            ),
            DropdownMenuItem(
              child: Text("Two"),
              value: "Two",
            ),
          ]);
    });
  }

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
    Map<String, dynamic>? business = await getLastSelectedBusiness();
    if (business == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BusinessSelectStartPage()),
      );
    }
    setState(() {
      businessName = business!['name'];
      currentBusiness = business;
      _currentAppBar = appbars[widget.page];
      _pageController.animateToPage(widget.page,
          duration: Duration(seconds: 1), curve: Curves.easeInCirc);
      appbarIndex = widget.page;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getPosition();

    initAppBar();
    changeAppBar();
    _getLastSelectedBusiness();
    _getBusinesses();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        top: true,
        child: Scaffold(
          backgroundColor: Colors.white,
          extendBodyBehindAppBar: false,
          extendBody: false,
          bottomNavigationBar: BottomNavigationBar(
            showSelectedLabels: true,
            showUnselectedLabels: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            unselectedLabelStyle: TextStyle(fontSize: 12, color: Colors.black),
            selectedLabelStyle: TextStyle(
                fontSize: 12, color: Colors.black, fontWeight: FontWeight.w500),
            selectedItemColor: Color(0xFFEE7203),
            // unselectedItemColor: Colors.black,
            iconSize: 24,
            type: BottomNavigationBarType.fixed,
            currentIndex: _curentIndex,
            items: _bottomNavigationBarItems,
            onTap: (value) {
              setState(() {
                _curentIndex = value;
                _pageController.jumpToPage(value);
                _currentAppBar = appbars[_curentIndex];
              });
            },
          ),
          appBar: AppBar(
            leading: Container(),
            automaticallyImplyLeading: false,
            systemOverlayStyle: SystemUiOverlayStyle(
                statusBarBrightness: Brightness.light,
                statusBarColor: Colors.white,
                statusBarIconBrightness: Brightness.dark),
            bottomOpacity: 0.5,
            toolbarHeight: _toolbarheight,
            flexibleSpace: _currentAppBar,
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
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
          body: PageView(
            controller: _pageController,
            physics: NeverScrollableScrollPhysics(),
            children: menuItems,
          ),
        ));
  }
}
