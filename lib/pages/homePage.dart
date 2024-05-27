// ignore_for_file: file_names

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:naliv_delivery/pages/categoryPage.dart';
import 'package:naliv_delivery/pages/orderHistoryPage.dart';
import 'package:naliv_delivery/pages/supportPage.dart';
import 'package:naliv_delivery/shared/activeOrderButton.dart';
import 'package:naliv_delivery/shared/loadingScreen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/colors.dart';
import 'package:naliv_delivery/pages/addressesPage.dart';
import 'package:naliv_delivery/pages/businessSelectStartPage.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:naliv_delivery/pages/favPage.dart';
import 'package:naliv_delivery/pages/loginPage.dart';
import 'package:naliv_delivery/pages/searchPage.dart';
import 'package:naliv_delivery/pages/settingsPage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.setCurrentBusiness = ""});

  final String setCurrentBusiness;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin<HomePage> {
  @override
  bool get wantKeepAlive => true;
  final PageController _pageController =
      PageController(viewportFraction: 0.7, initialPage: 0);

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map> images = [
    // {
    //   "text":
    //       "Очень длинный текст акции 123 123 123 123 123 12312312312312313213",
    //   "image":
    //       "https://podacha-blud.com/uploads/posts/2022-12/1670216296_41-podacha-blud-com-p-zhenskie-kokteili-alkogolnie-foto-55.jpg"
    // },
    {
      "text": "123",
      "image": "https://pogarchik.com/wp-content/uploads/2019/03/5-1.jpg"
    },
    {
      "text":
          "Очень длинный текст акции 123 123 123 123 123 12312312312312313213",
      "image":
          "https://podacha-blud.com/uploads/posts/2022-12/1670216296_41-podacha-blud-com-p-zhenskie-kokteili-alkogolnie-foto-55.jpg"
    },
    {
      "text": "123",
      "image": "https://pogarchik.com/wp-content/uploads/2019/03/5-1.jpg"
    },
  ];

  List<Widget> indicators(imagesLength, currentIndex) {
    return List<Widget>.generate(
      imagesLength,
      (index) {
        return Container(
          margin: const EdgeInsets.all(3),
          width: 5,
          height: 5,
          decoration: BoxDecoration(
              color: currentIndex == index ? gray1 : Colors.black12,
              shape: BoxShape.circle),
        );
      },
    );
  }

  List categories = [];

  int activePage = 0;

  List _addresses = [];

  Map _currentAddress = {};

  bool categoryIsLoading = true;

  // Must be true if there is an active order, other wise false, for test purposes it's true
  bool isThereActiveOrder = true;

  bool isPageLoading = true;

  List<dynamic> businesses = [];

  Map<String, dynamic>? user;
  late Position _location;

  Future<void> _getCategories() async {
    setState(() {
      categoryIsLoading = true;
    });
    await getCategories().then((value) {
      setState(() {
        categories = value;
        categoryIsLoading = false;
      });
    });
  }

  Map<String, dynamic>? _business = {};
  Future<void> _getCurrentBusiness() async {
    await getLastSelectedBusiness().then((value) {
      if (value != null) {
        setState(() {
          _business = value;
        });
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (context) {
            return const BusinessSelectStartPage();
          },
        ));
      }
    });
  }

  Future<void> _getAddresses() async {
    List addresses = await getAddresses();
    print(addresses);
    setState(() {
      _addresses = addresses;
      _currentAddress = _addresses.firstWhere(
        (element) => element["is_selected"] == "1",
        orElse: () {
          return null;
        },
      );
    });
  }

  void toggleDrawer() async {
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      _scaffoldKey.currentState!.openEndDrawer();
    } else {
      _scaffoldKey.currentState!.openDrawer();
    }
  }

  void _getUser() async {
    await getUser().then((value) {
      setState(() {
        user = value;
      });
    });
  }

  _getCurrentAddress() {}

  Future<void> getPosition() async {
    Position location = await determinePosition(context);
    print(location.latitude);
    print(location.longitude);
    setCityAuto(location.latitude, location.longitude);
    setState(() {
      _location = location;
    });
  }

  void _getBusinesses() {
    getBusinesses().then((value) {
      if (value != null) {
        businesses = value;
      }
    });
  }

  void _getAddressPickDialog(double screenSize) {
    showDialog(
      useSafeArea: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "Ваши адреса",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10))),
          insetPadding: const EdgeInsets.all(0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            height: MediaQuery.of(context).size.height * 0.4,
            child: _addresses.isNotEmpty
                ? ListView.builder(
                    itemCount: _addresses.length,
                    itemBuilder: (context, index) {
                      print(_addresses);
                      return Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Future.delayed(const Duration(milliseconds: 0),
                                  () async {
                                await selectAddress(
                                    _addresses[index]["address_id"]);
                              });
                              setState(() {
                                _currentAddress = _addresses[index];
                              });
                              Navigator.pop(context);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Flexible(
                                  child: Text(
                                    "${_addresses[index]["name"] != null ? '${_addresses[index]["name"]} -' : ""} ${_addresses[index]["address"]}",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 28 * (screenSize / 720),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: 15,
                          ),
                        ],
                      );
                    },
                  )
                : const Text("У вас нет сохраненных адресов"),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return AddressesPage(
                    addresses: _addresses,
                    isExtended: false,
                  );
                }));
              },
              child: Text(
                "Добавить новый адрес",
                style: TextStyle(
                    fontSize: 28 * (screenSize / 720),
                    fontWeight: FontWeight.w700),
              ),
            )
          ],
          actionsAlignment: MainAxisAlignment.center,
        );
      },
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      isPageLoading = true;
    });
    if (widget.setCurrentBusiness.isNotEmpty) {
      setCurrentStore(widget.setCurrentBusiness).then((value) {
        if (value) {
          Future.delayed(Duration.zero).then((value) async {
            await _getCurrentBusiness();
            _getBusinesses();
            _getUser();
          });
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            _getAddresses();
            getPosition();
            _getCategories().whenComplete(() {
              setState(() {
                isPageLoading = false;
              });
            });
          });
        }
      });
    } else {
      Future.delayed(Duration.zero).then((value) async {
        await _getCurrentBusiness();
        _getBusinesses();
        _getUser();
      });
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _getAddresses();
        getPosition();
        _getCategories().whenComplete(() {
          setState(() {
            isPageLoading = false;
          });
        });
      });
    }
    // _checkForActiveOrder(); Someting like this idk
  }

  @override
  Widget build(BuildContext context) {
    double screenSize = MediaQuery.of(context).size.width;

    super.build(context);
    return isPageLoading
        ? const LoadingScreen()
        : Scaffold(
            key: _scaffoldKey,
            floatingActionButton: SizedBox(
              width: 65,
              height: 65,
              child: FloatingActionButton(
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                child: Icon(
                  Icons.shopping_basket_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return const CartPage();
                      },
                    ),
                  );
                },
              ),
            ),
            drawer: Drawer(
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 20),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: MediaQuery.of(context).size.width * 0.10,
                              backgroundImage: const CachedNetworkImageProvider(
                                "https://air-fom.com/wp-content/uploads/2018/06/real_1920.jpg",
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            // TODO: activate this code in production
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.3,
                              child: user != null
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user!["name"] ?? "Нет имени",
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w500,
                                              fontSize:
                                                  32 * (screenSize / 720)),
                                        ),
                                        Text(
                                          user!["login"] ?? "",
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w400,
                                              fontSize:
                                                  28 * (screenSize / 720)),
                                        ),
                                        Text(
                                          user!["user_id"] ?? "",
                                          style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontWeight: FontWeight.w400,
                                              fontSize:
                                                  28 * (screenSize / 720)),
                                        )
                                      ],
                                    )
                                  : Container(),
                            )
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 20),
                      child: Column(
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20)),
                            onPressed: () {
                              toggleDrawer();
                              setState(() {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) {
                                    return const OrderHistoryPage();
                                  },
                                ));
                              });
                            },
                            child: Row(
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
                                      fontSize: 40 * (screenSize / 720)),
                                )
                              ],
                            ),
                          ),
                          const Divider(),
                          TextButton(
                            style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20)),
                            onPressed: () {
                              setState(() {
                                toggleDrawer();
                              });
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => AddressesPage(
                                          addresses: _addresses,
                                          isExtended: true,
                                        )),
                              ).then((value) => print(_getAddresses()));
                            },
                            child: Row(
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
                                      fontSize: 40 * (screenSize / 720)),
                                )
                              ],
                            ),
                          ),
                          const Divider(),
                          TextButton(
                            style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20)),
                            onPressed: () {
                              setState(() {
                                toggleDrawer();
                              });
                            },
                            child: Row(
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
                                      fontSize: 40 * (screenSize / 720)),
                                )
                              ],
                            ),
                          ),
                          const Divider(),
                          TextButton(
                            style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20)),
                            onPressed: () {
                              setState(() {
                                toggleDrawer();
                              });
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) {
                                  return const FavPage();
                                },
                              ));
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.favorite_border_rounded,
                                  size: 24,
                                  color: Colors.black,
                                ),
                                SizedBox(
                                  width: 10,
                                ),
                                Text(
                                  "Избранное",
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w400,
                                      fontSize: 40 * (screenSize / 720)),
                                )
                              ],
                            ),
                          ),
                          const Divider(),
                          TextButton(
                            style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20)),
                            onPressed: () {
                              setState(() {
                                toggleDrawer();
                              });
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) {
                                  return const SettingsPage();
                                },
                              ));
                            },
                            child: Row(
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
                                      fontSize: 40 * (screenSize / 720)),
                                )
                              ],
                            ),
                          ),
                          const Divider(),
                          TextButton(
                            style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20)),
                            onPressed: () {
                              setState(() {
                                toggleDrawer();
                                Navigator.push(context,
                                    MaterialPageRoute(builder: (context) {
                                  return const SupportPage();
                                }));
                              });
                            },
                            child: Row(
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
                                      fontSize: 40 * (screenSize / 720)),
                                )
                              ],
                            ),
                          ),
                          const Divider(),
                          TextButton(
                            style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20)),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog.adaptive(
                                    shape: const RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(10)),
                                    ),
                                    title: Text(
                                      "Вы точно хотите выйти из аккаунта?",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onBackground,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    actionsAlignment: MainAxisAlignment.center,
                                    actions: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5),
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  logout();
                                                  Navigator.pushAndRemoveUntil(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            const LoginPage(),
                                                      ),
                                                      (route) => false);
                                                },
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        "Да",
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onPrimary,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Flexible(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5),
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                },
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        "Нет",
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onPrimary,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              );
                              // setState(() {
                              //   toggleDrawer();
                              // });
                              // print(123);
                              // logout();
                              // Navigator.pushReplacement(context, MaterialPageRoute(
                              //   builder: (context) {
                              //     return const LoginPage();
                              //   },
                              // ));
                            },
                            child: Row(
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
                                      fontSize: 40 * (screenSize / 720)),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            // appBar: AppBar(
            //     titleSpacing: 10,
            //     // scrolledUnderElevation: 100,
            //     automaticallyImplyLeading: true,
            //     // leading: IconButton(
            //     //   icon: Icon(Icons.menu),
            //     //   onPressed: () {},
            //     // ),

            //     title:),
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  toolbarHeight: 120,
                  automaticallyImplyLeading: false,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  stretch: true,
                  // stretchTriggerOffset: 300.0,
                  pinned: true,
                  // floating: true,
                  // snap: true,
                  titleSpacing: 0,
                  title: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  toggleDrawer();
                                },
                                icon: const Icon(Icons.menu_rounded),
                              ),
                            ),
                            Flexible(
                              flex: 4,
                              fit: FlexFit.tight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (context) {
                                      return const SearchPage();
                                    },
                                  ));
                                },
                                style: TextButton.styleFrom(
                                    foregroundColor:
                                        Colors.white.withOpacity(0)),
                                child: Container(
                                  decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.1),
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(10))),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      const Spacer(
                                        flex: 3,
                                      ),
                                      const Text(
                                        "Найти",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black),
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
                                        padding: const EdgeInsets.all(10),
                                        child: const Icon(
                                          Icons.search,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        isThereActiveOrder
                            ? const ActiveOrderButton()
                            : Container(),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Image.network(
                      //   _business!["logo"],
                      //   fit: BoxFit.cover,
                      // ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _getAddressPickDialog(screenSize);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                              color: Colors.black12,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _addresses.firstWhere(
                                        (element) =>
                                            element["is_selected"] == "1",
                                        orElse: () {
                                          return null;
                                        },
                                      ) !=
                                      null
                                  ? Column(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              _currentAddress["name"] ?? "",
                                              style: const TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w700),
                                            )
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              _currentAddress["address"] ?? "",
                                              style: const TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w700),
                                            )
                                          ],
                                        )
                                      ],
                                    )
                                  : const Column(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              "Выберите ваш адрес",
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w700),
                                            )
                                          ],
                                        ),
                                      ],
                                    ),
                              const Icon(Icons.arrow_forward_ios)
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.pushReplacement(context, MaterialPageRoute(
                            builder: (context) {
                              return BusinessSelectStartPage(
                                businesses: businesses,
                              );
                            },
                          ));
                        },
                        child: Container(
                            margin: const EdgeInsets.all(10),
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                                color: Colors.black12,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10))),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _business?["name"] ?? "",
                                          style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w700),
                                        )
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          _business?["address"] ?? "",
                                          style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w700),
                                        )
                                      ],
                                    )
                                  ],
                                ),
                                const Icon(Icons.arrow_forward_ios)
                              ],
                            )),
                      ),
                      // SizedBox(
                      //     height: 150,
                      //     width: MediaQuery.of(context).size.width,
                      //     child: PageView.builder(
                      //       onPageChanged: (value) {
                      //         setState(
                      //           () {
                      //             activePage = value;
                      //           },
                      //         );
                      //       },
                      //       itemCount: images.length,
                      //       itemBuilder: (context, index) {
                      //         return Container(
                      //           decoration: BoxDecoration(
                      //               borderRadius:
                      //                   const BorderRadius.all(Radius.circular(10)),
                      //               image: DecorationImage(
                      //                   opacity: 0.5,
                      //                   image: NetworkImage(images[index]["image"]),
                      //                   fit: BoxFit.cover)),
                      //           margin: const EdgeInsets.all(10),
                      //           padding: const EdgeInsets.all(10),
                      //           child: TextButton(
                      //             style: TextButton.styleFrom(
                      //                 alignment: Alignment.topLeft),
                      //             child: Text(
                      //               images[index]["text"],
                      //               style: const TextStyle(
                      //                   fontSize: 20,
                      //                   fontWeight: FontWeight.w700,
                      //                   color: Colors.black),
                      //             ),
                      //             onPressed: () {
                      //               print("object");
                      //             },
                      //           ),
                      //         );
                      //       },
                      //       controller: _pageController,
                      //       padEnds: false,
                      //       pageSnapping: false,
                      //     )),
                      // Row(
                      //     mainAxisAlignment: MainAxisAlignment.center,
                      //     children: indicators(images.length, activePage)),
                      const SizedBox(
                        height: 10,
                      ),
                      // SizedBox(
                      //   width: MediaQuery.of(context).size.width,
                      //   // height: 170,
                      //   child: GridView(
                      //     primary: false,
                      //     shrinkWrap: true,
                      //     gridDelegate:
                      //         const SliverGridDelegateWithFixedCrossAxisCount(
                      //             crossAxisCount: 4),
                      //     children: [
                      //       Container(
                      //         width: MediaQuery.of(context).size.width * 0.25,
                      //         height: MediaQuery.of(context).size.width * 0.25,
                      //         margin: const EdgeInsets.all(5),
                      //         child: Column(
                      //           children: [
                      //             Container(
                      //               decoration: BoxDecoration(
                      //                   color:
                      //                       Theme.of(context).colorScheme.primary,
                      //                   borderRadius: const BorderRadius.all(
                      //                       Radius.circular(10))),
                      //               width: MediaQuery.of(context).size.width * 0.15,
                      //               height:
                      //                   MediaQuery.of(context).size.width * 0.15,
                      //             ),
                      //             const Text(
                      //               "Новинки",
                      //               style: TextStyle(fontSize: 12),
                      //             )
                      //           ],
                      //         ),
                      //       ),
                      //       Container(
                      //         width: MediaQuery.of(context).size.width * .25,
                      //         height: MediaQuery.of(context).size.width * .25,
                      //         margin: const EdgeInsets.all(5),
                      //         child: Column(
                      //           children: [
                      //             Container(
                      //               decoration: BoxDecoration(
                      //                   color:
                      //                       Theme.of(context).colorScheme.primary,
                      //                   borderRadius: const BorderRadius.all(
                      //                       Radius.circular(10))),
                      //               width: MediaQuery.of(context).size.width * 0.15,
                      //               height:
                      //                   MediaQuery.of(context).size.width * 0.15,
                      //             ),
                      //             const Text(
                      //               "Со скидкой",
                      //               style: TextStyle(fontSize: 12),
                      //             )
                      //           ],
                      //         ),
                      //       ),
                      //       Container(
                      //         width: MediaQuery.of(context).size.width * .25,
                      //         height: MediaQuery.of(context).size.width * .25,
                      //         margin: const EdgeInsets.all(5),
                      //         child: Column(
                      //           children: [
                      //             Container(
                      //               decoration: BoxDecoration(
                      //                   color:
                      //                       Theme.of(context).colorScheme.primary,
                      //                   borderRadius: const BorderRadius.all(
                      //                       Radius.circular(10))),
                      //               width: MediaQuery.of(context).size.width * 0.15,
                      //               height:
                      //                   MediaQuery.of(context).size.width * 0.15,
                      //             ),
                      //             const Text(
                      //               "Хит продаж",
                      //               style: TextStyle(fontSize: 12),
                      //             )
                      //           ],
                      //         ),
                      //       ),
                      //       Container(
                      //         width: MediaQuery.of(context).size.width * .25,
                      //         height: MediaQuery.of(context).size.width * 0.33,
                      //         margin: const EdgeInsets.all(5),
                      //         child: Column(
                      //           children: [
                      //             Container(
                      //               decoration: BoxDecoration(
                      //                   color:
                      //                       Theme.of(context).colorScheme.primary,
                      //                   borderRadius: const BorderRadius.all(
                      //                       Radius.circular(10))),
                      //               width: MediaQuery.of(context).size.width * 0.15,
                      //               height:
                      //                   MediaQuery.of(context).size.width * 0.15,
                      //             ),
                      //             const Text(
                      //               "Вы покупали",
                      //               style: TextStyle(fontSize: 12),
                      //             )
                      //           ],
                      //         ),
                      //       )
                      //     ],
                      //   ),
                      // ),
                      categoryIsLoading
                          ? Padding(
                              padding: const EdgeInsets.all(10),
                              child: GridView.builder(
                                padding: const EdgeInsets.all(0),
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 150,
                                        childAspectRatio: 1,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10),
                                itemCount: 9,
                                itemBuilder: (BuildContext ctx, index) {
                                  return Shimmer.fromColors(
                                    baseColor: Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withOpacity(0.05),
                                    highlightColor:
                                        Theme.of(context).colorScheme.secondary,
                                    child: Container(
                                      width: MediaQuery.of(context).size.width,
                                      height: 50,
                                      decoration: const BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(10)),
                                        color: Colors.white,
                                      ),
                                      child: null,
                                    ),
                                  );
                                },
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(10),
                              child: GridView.builder(
                                padding: const EdgeInsets.all(0),
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 150,
                                        childAspectRatio: 1,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10),
                                itemCount: categories.length,
                                itemBuilder: (BuildContext ctx, index) {
                                  return CategoryItem(
                                    category_id: categories[index]
                                        ["category_id"],
                                    name: categories[index]["name"],
                                    image: categories[index]["photo"],
                                    categories: categories,
                                  );
                                },
                              ),
                            ),
                      const SizedBox(
                        height: 200,
                      )
                    ],
                  ),
                )
              ],
            ),
          );
  }
}

class CategoryItem extends StatefulWidget {
  const CategoryItem(
      {super.key,
      required this.category_id,
      required this.name,
      required this.image,
      required this.categories});
  final String category_id;
  final String name;
  final String? image;
  final List<dynamic> categories;
  @override
  State<CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<CategoryItem> {
  Color firstColor = Colors.white;
  Color secondColor = Colors.blueGrey;
  late Image imageBG = Image.asset(
    'assets/vectors/wine.png',
    width: 120,
    height: 120,
  );
  Alignment? _alignment;
  Offset _offset = const Offset(0.15, -0.05);
  double? _rotation;
  Color textBG = Colors.white.withOpacity(0);

  void _getColors() {
    switch (widget.category_id) {
      // Beer
      case '1':
      case '17':
        setState(() {
          firstColor = const Color(0xFFFFDE67);
          secondColor = const Color(0xFFF5A265);
          imageBG = Image.asset(
            'assets/vectors/beer.png',
            width: 130,
            height: 130,
          );
        });
        break;
      // Whiskey
      case '8':
        setState(() {
          firstColor = const Color(0xFF898989);
          secondColor = const Color(0xFF464343);
          imageBG = Image.asset(
            'assets/vectors/whiskey.png',
            width: 150,
            height: 150,
          );
          _offset = const Offset(0.15, 0.05);
        });
        break;
      // Wine
      case '13':
        setState(() {
          firstColor = const Color(0xFFFF8CB6);
          secondColor = const Color(0xFFE3427C);
          imageBG = Image.asset(
            'assets/vectors/wine.png',
            width: 120,
            height: 120,
          );
          _offset = const Offset(0.15, -0.05);
        });
        break;
      // Vodka
      case '14':
        setState(() {
          firstColor = const Color(0xFFC4DCDF);
          secondColor = const Color(0xFF8C9698);
          imageBG = Image.asset(
            'assets/vectors/vodka.png',
            width: 170,
            height: 170,
          );
          _offset = const Offset(0, -0.18);
        });
        break;
      case '20':
        setState(() {
          firstColor = const Color(0xFF92EAFD);
          secondColor = const Color(0xFF285B98);
          imageBG = Image.asset(
            'assets/vectors/drinks.png',
            width: 85,
            height: 85,
          );
          _offset = const Offset(0, 0);
        });
        break;
      case '23':
        setState(() {
          firstColor = const Color(0xFFC4DCDF);
          secondColor = const Color(0xFF8C9698);
          imageBG = Image.asset(
            'assets/vectors/snacks.png',
            width: 130,
            height: 130,
          );
          _offset = const Offset(0.18, 0.05);
          _rotation = -20 / 360;
        });
        break;
      default:
        print("Default switch case in gradient HomePage");
        break;
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getColors();
  }

  @override
  Widget build(BuildContext context) {
    double screenSize = MediaQuery.of(context).size.width;

    return TextButton(
      style: TextButton.styleFrom(padding: const EdgeInsets.all(0)),
      onPressed: () {
        print("CATEGORY_ID IS ${widget.category_id}");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryPage(
              categoryId: widget.category_id,
              categoryName: widget.name,
              categories: widget.categories,
            ),
          ),
        );
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [firstColor, secondColor],
                transform: const GradientRotation(2),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromARGB(255, 200, 200, 200),
                  offset: Offset(0, 3),
                ),
                BoxShadow(
                  color: Color.fromARGB(255, 220, 220, 220),
                  offset: Offset(0, 0),
                  blurRadius: 4,
                )
              ],
              // border: Border.all(
              //   color: firstColor,
              //   width: 2,
              //   strokeAlign: BorderSide.strokeAlignOutside,
              // ),
            ),
          ),
          _alignment == null
              ? Container(
                  alignment: Alignment.topCenter,
                  child: ClipRect(
                    child: OverflowBox(
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: RotationTransition(
                        turns: AlwaysStoppedAnimation(_rotation ?? 0),
                        child: SlideTransition(
                          position: AlwaysStoppedAnimation(_offset),
                          child: imageBG,
                        ),
                      ),
                    ),
                  ),
                )
              : Container(
                  alignment: _alignment,
                  child: imageBG,
                ),
          Container(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.bottomLeft,
            child: Transform.rotate(
                // origin: Offset(-50, 0),
                alignment: Alignment.bottomCenter,
                angle: 0.5,
                child: Stack(
                  children: <Widget>[
                    Transform.translate(
                      offset: const Offset(15.0, -6.0),
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaY: 14, sigmaX: 14),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.transparent,
                              width: 0,
                            ),
                          ),
                          child: Opacity(
                            opacity: 0.8,
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                  Colors.black, BlendMode.srcATop),
                              child: CachedNetworkImage(
                                imageUrl: widget.image!,
                                cacheManager: CacheManager(Config(
                                  "itemImage",
                                  stalePeriod: const Duration(days: 7),
                                  //one week cache period
                                )),
                                fit: BoxFit.fitHeight,
                                width: 500,
                                height: 500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    CachedNetworkImage(
                      imageUrl: widget.image!,
                      cacheManager: CacheManager(Config(
                        "itemImage",
                        stalePeriod: const Duration(days: 7),
                        //one week cache period
                      )),
                      fit: BoxFit.fitHeight,
                      width: 500,
                      height: 500,
                      errorWidget: (context, url, error) {
                        return Container(
                          alignment: Alignment.center,
                          width: 10,
                          height: 10,
                          child: const SizedBox(),
                        );
                      },
                    ),
                  ],
                )
                // child: widget.image!.isNotEmpty
                //     ? CachedNetworkImage(
                //         imageUrl: widget.image!,
                //         fit: BoxFit.fitHeight,
                //         width: 500,
                //         height: 500,
                //       )
                //     : Container(),
                ),
          ),
          Container(
            padding: const EdgeInsets.all(15),
            alignment: Alignment.topLeft,
            decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(5))),
            child: Container(
              decoration: BoxDecoration(
                  color: textBG,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(5),
                      bottomRight: Radius.circular(5))),
              child: Text(
                widget.name,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 28 * (screenSize / 720),
                    height: 1.2,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(0, 2),
                      )
                    ]
                    // background: Paint()..color = textBG)
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
