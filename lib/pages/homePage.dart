import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:naliv_delivery/pages/categoryPage.dart';
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
  const HomePage({super.key});

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
    Map<String, dynamic>? business = await getLastSelectedBusiness();
    if (business != null) {
      setState(() {
        _business = business;
      });
    }
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

  toggleDrawer() async {
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      _scaffoldKey.currentState!.openEndDrawer();
    } else {
      _scaffoldKey.currentState!.openDrawer();
    }
  }

  _getCurrentAddress() {}

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getCategories();
    _getCurrentBusiness();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _getAddresses();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
        key: _scaffoldKey,
        floatingActionButton: SizedBox(
          width: 65,
          height: 65,
          child: FloatingActionButton(
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(3))),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                child: Column(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20)),
                      onPressed: () {
                        setState(() {
                          toggleDrawer();
                        });
                      },
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
                      onPressed: () {
                        setState(() {
                          toggleDrawer();
                        });
                      },
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
                        setState(() {
                          toggleDrawer();
                        });
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) {
                            return const FavPage();
                          },
                        ));
                      },
                      child: const Row(
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
                        setState(() {
                          toggleDrawer();
                        });
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
                      onPressed: () {
                        setState(() {
                          toggleDrawer();
                        });
                      },
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
                        setState(() {
                          toggleDrawer();
                        });
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
        )),
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
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              stretch: true,
              // stretchTriggerOffset: 300.0,
              pinned: true,
              // floating: true,
              // snap: true,
              title: TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) {
                      return const SearchPage();
                    },
                  ));
                },
                style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withOpacity(0)),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: const BorderRadius.all(Radius.circular(3))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Spacer(
                        flex: 3,
                      ),
                      const Text(
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
            SliverToBoxAdapter(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Image.network(
                  //   _business!["logo"],
                  //   fit: BoxFit.cover,
                  // ),
                  _addresses.firstWhere(
                            (element) => element["is_selected"] == "1",
                            orElse: () {
                              return null;
                            },
                          ) ==
                          null
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                              margin: const EdgeInsets.all(10),
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(3))),
                              child: const Row(
                                children: [
                                  Text(
                                    "Выберите адрес доставки",
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              )),
                        )
                      : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                              margin: const EdgeInsets.all(10),
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                  // color: Colors.black12,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(3))),
                              child: Row(
                                children: [
                                  Text(
                                    _currentAddress["address"],
                                    style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              )),
                        ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(
                        builder: (context) {
                          return const BusinessSelectStartPage();
                        },
                      ));
                    },
                    child: Container(
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.all(Radius.circular(3))),
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
                  SizedBox(
                      height: 150,
                      width: MediaQuery.of(context).size.width,
                      child: PageView.builder(
                        onPageChanged: (value) {
                          setState(
                            () {
                              activePage = value;
                            },
                          );
                        },
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          return Container(
                            decoration: BoxDecoration(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(3)),
                                image: DecorationImage(
                                    opacity: 0.5,
                                    image: NetworkImage(images[index]["image"]),
                                    fit: BoxFit.cover)),
                            margin: const EdgeInsets.all(10),
                            padding: const EdgeInsets.all(10),
                            child: TextButton(
                              style: TextButton.styleFrom(
                                  alignment: Alignment.topLeft),
                              child: Text(
                                images[index]["text"],
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black),
                              ),
                              onPressed: () {
                                print("object");
                              },
                            ),
                          );
                        },
                        controller: _pageController,
                        padEnds: false,
                        pageSnapping: false,
                      )),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: indicators(images.length, activePage)),
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
                  //                       Radius.circular(3))),
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
                  //                       Radius.circular(3))),
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
                  //                       Radius.circular(3))),
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
                  //                       Radius.circular(3))),
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
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(3)),
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
                                  category_id: categories[index]["category_id"],
                                  name: categories[index]["name"],
                                  image: categories[index]["photo"]);
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
        ));
  }
}

class CategoryItem extends StatefulWidget {
  const CategoryItem(
      {super.key,
      required this.category_id,
      required this.name,
      required this.image});
  final String category_id;
  final String name;
  final String? image;
  @override
  State<CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<CategoryItem> {
  Color firstColor = Colors.white;
  Color secondColor = Colors.blueGrey;
  late Image imageBG = Image.asset('assets/vectors/wine.png');
  Alignment? _alignment;
  Color textBG = Colors.white.withOpacity(0);
  Future<void> _getColors() async {
    switch (widget.category_id) {
      // Beer
      case '1':
        setState(() {
          firstColor = const Color(0xFFFFDE67);
          secondColor = const Color(0xFFF5A265);
          imageBG = Image.asset('assets/vectors/beer.png');
        });
        break;
      // Whiskey
      case '8':
        setState(() {
          firstColor = const Color(0xFF898989);
          secondColor = const Color(0xFF464343);
          imageBG = Image.asset('assets/vectors/whiskey.png');
          _alignment = Alignment.topLeft;
        });
        break;
      // Wine
      case '13':
        setState(() {
          firstColor = const Color(0xFFFF8CB6);
          secondColor = const Color(0xFFE3427C);
          imageBG = Image.asset('assets/vectors/wine.png');
        });
        break;
      // Vodka
      case '14':
        setState(() {
          firstColor = const Color(0xFFC4DCDF);
          secondColor = const Color(0xFF8C9698);
          imageBG = Image.asset('assets/vectors/vodka.png');
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
    Future.delayed(Duration.zero, () async {
      await _getColors();
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(padding: const EdgeInsets.all(0)),
      onPressed: () {
        print("CATEGORY_ID IS ${widget.category_id}");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryPage(
              category_id: widget.category_id,
              category_name: widget.name,
              scroll: 0,
            ),
          ),
        );
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                    colors: [firstColor, secondColor],
                    transform: const GradientRotation(2))),
          ),
          _alignment == null
              ? Container(
                  alignment: Alignment.topRight,
                  child: imageBG,
                )
              : Container(
                  alignment: _alignment,
                  child: imageBG,
                ),
          Container(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(3)),
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
                          child: const Text(
                            "Нет изображения",
                            style: TextStyle(color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
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
                    color: Colors.white,
                    fontSize: 14,
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
