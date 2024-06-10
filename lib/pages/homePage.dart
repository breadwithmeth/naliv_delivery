// ignore_for_file: file_names

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:naliv_delivery/pages/categoryPage.dart';
import 'package:naliv_delivery/pages/orderHistoryPage.dart';
import 'package:naliv_delivery/pages/organizationSelectPage.dart';
import 'package:naliv_delivery/pages/preLoadDataPage.dart';
import 'package:naliv_delivery/pages/supportPage.dart';
import 'package:naliv_delivery/shared/activeOrderButton.dart';
import 'package:naliv_delivery/shared/cartButton.dart';
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
  HomePage({super.key, required this.business, required this.user});

  final Map<dynamic, dynamic> business;
  final Map user;
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
          margin: EdgeInsets.all(3),
          width: 5,
          height: 5,
          decoration: BoxDecoration(
              color: currentIndex == index ? gray1 : Colors.black12,
              shape: BoxShape.circle),
        );
      },
    );
  }

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

  Future<List> _getCategories() async {
    List cats = await getCategories(widget.business["business_id"]);
    return cats;
  }

  Map<String, dynamic>? _business = {};

  void toggleDrawer() async {
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      _scaffoldKey.currentState!.openEndDrawer();
    } else {
      _scaffoldKey.currentState!.openDrawer();
    }
  }

  // _getCurrentAddress() {}

  // Future<void> preloadData() async {

  //   WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
  //     _getAddresses().then((v) {
  //       getPosition().then((vv) {
  //         _getCategories().then((vvv) {
  //           return true;
  //         });
  //       });
  //     });
  //   });
  // }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // if (widget.setCurrentBusiness.isNotEmpty) {
    // setCurrentStore(widget.setCurrentBusiness).then((value) {
    //   if (value) {
    //     Future.delayed(Duration.zero).then((value) async {
    //       await _getCurrentBusiness();
    //       _getBusinesses();
    //       _getUser();
    //     });
    //     WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
    //       _getAddresses();
    //       getPosition();
    //       _getCategories().whenComplete(() {
    //         setState(() {
    //           isPageLoading = false;
    //         });
    //       });
    //     });
    //   }
    // });
    // } else {
    //   // Future.delayed(Duration.zero).then((value) async {
    //   //   await _getCurrentBusiness();
    //   //   _getBusinesses();
    //   //   _getUser();
    //   // });

    // }
    // _checkForActiveOrder(); Someting like this idk
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;

    super.build(context);
    return FutureBuilder(
      future: _getCategories(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Scaffold(
            key: _scaffoldKey,
            floatingActionButton: CartButton(
              business: widget.business,
            ),
            appBar: AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: 240 * globals.scaleParam,
              titleSpacing: 0,
              title: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam),
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
                              Navigator.pop(context);
                            },
                            icon: Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                        Flexible(
                          flex: 3,
                          fit: FlexFit.tight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.business["name"],
                                maxLines: 1,
                                style: TextStyle(
                                    fontSize: 28 * globals.scaleParam),
                              ),
                              Text(
                                widget.business["address"],
                                maxLines: 1,
                                style: TextStyle(
                                    fontSize: 28 * globals.scaleParam),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          flex: 4,
                          fit: FlexFit.tight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(context, CupertinoPageRoute(
                                builder: (context) {
                                  return SearchPage(
                                    business: widget.business,
                                  );
                                },
                              ));
                            },
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.white.withOpacity(0)),
                            child: Container(
                              decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(10))),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Spacer(
                                    flex: 3,
                                  ),
                                  Text(
                                    "Найти",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 28 * globals.scaleParam,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Container(
                                    padding:
                                        EdgeInsets.all(20 * globals.scaleParam),
                                    child: Icon(
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
                        ? ActiveOrderButton(
                            business: widget.business,
                          )
                        : Container(),
                  ],
                ),
              ),
            ),
            body: Column(
              children: [
                Flexible(
                  flex: 20,
                  fit: FlexFit.tight,
                  child: Padding(
                    padding: EdgeInsets.all(20 * globals.scaleParam),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        child: GridView.builder(
                          padding: EdgeInsets.all(0),
                          physics: NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent:
                                      MediaQuery.sizeOf(context).shortestSide *
                                          0.5,
                                  childAspectRatio: 10 / 8,
                                  crossAxisSpacing: 0,
                                  mainAxisSpacing: 0),
                          itemCount: snapshot.data!.length % 2 != 0
                              ? snapshot.data!.length + 1
                              : snapshot.data!.length,
                          itemBuilder: (BuildContext ctx, index) {
                            return snapshot.data!.length % 2 != 0 &&
                                    index == snapshot.data!.length
                                ? Container(color: Colors.white)
                                : CategoryItem(
                                    category_id: snapshot.data![index]
                                        ["category_id"],
                                    name: snapshot.data![index]["name"],
                                    image: snapshot.data![index]["photo"],
                                    categories: snapshot.data!,
                                    business: widget.business,
                                  );
                          },
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          );
        } else {
          return LoadingScreen();
        }
      },
    );
  }
}

class CategoryItem extends StatefulWidget {
  CategoryItem({
    super.key,
    required this.category_id,
    required this.name,
    required this.image,
    required this.categories,
    required this.business,
  });
  final String category_id;
  final String name;
  final String? image;
  final List<dynamic> categories;
  final Map<dynamic, dynamic> business;

  @override
  State<CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<CategoryItem> {
  Color firstColor = Color.fromARGB(255, 201, 201, 201);
  Color secondColor = Colors.blueGrey;
  late Image imageBG = Image.asset(
    'assets/vectors/wine.png',
    width: 120,
    height: 120,
  );
  Alignment? _alignment;
  Offset _offset = Offset(0.15, -0.05);
  double? _rotation;
  Color textBG = Colors.white.withOpacity(0);

  void _getColors() {
    switch (widget.category_id) {
      // Beer
      case '1':
      case '17':
      case '28':
        setState(() {
          firstColor = Color.fromARGB(255, 255, 228, 128);
          secondColor = Color(0xFFF5A265);
          imageBG = Image.asset(
            'assets/vectors/beer.png',
            width: 260 * globals.scaleParam,
            height: 260 * globals.scaleParam,
          );
        });
        break;
      // Whiskey
      case '8':
        setState(() {
          firstColor = Color(0xFF898989);
          secondColor = Color(0xFF464343);
          imageBG = Image.asset(
            'assets/vectors/whiskey.png',
            width: 300 * globals.scaleParam,
            height: 300 * globals.scaleParam,
          );
          _offset = Offset(0, 0);
        });
        break;
      // Wine
      case '13':
        setState(() {
          firstColor = Color.fromARGB(255, 255, 134, 178);
          secondColor = Color(0xFFE3427C);
          imageBG = Image.asset(
            'assets/vectors/wine.png',
            width: 240 * globals.scaleParam,
            height: 240 * globals.scaleParam,
          );
          _offset = Offset(0.15, -0.05);
        });
        break;
      // Vodka
      case '14':
        setState(() {
          firstColor = Color.fromARGB(255, 205, 222, 224);
          secondColor = Color(0xFF8C9698);
          imageBG = Image.asset(
            'assets/vectors/vodka.png',
            width: 340 * globals.scaleParam,
            height: 340 * globals.scaleParam,
          );
          _offset = Offset(0, -0.18);
        });
        break;
      case '20':
        setState(() {
          firstColor = Color.fromARGB(255, 132, 233, 255);
          secondColor = Color(0xFF285B98);
          imageBG = Image.asset(
            'assets/vectors/drinks.png',
            width: 170 * globals.scaleParam,
            height: 170 * globals.scaleParam,
          );
          _offset = Offset(0, 0);
        });
        break;
      case '23':
        setState(() {
          firstColor = Color.fromARGB(255, 255, 211, 129);
          secondColor = Color(0xFF8C9698);
          imageBG = Image.asset(
            'assets/vectors/snacks.png',
            width: 260 * globals.scaleParam,
            height: 260 * globals.scaleParam,
          );
          _offset = Offset(0.18, 0.05);
          _rotation = -20 / 360;
        });
        break;
      // Meat snacks
      case '24':
        setState(() {
          firstColor = Color.fromARGB(255, 218, 150, 161);
        });
        break;
      // Chocolate
      case '12':
        setState(() {
          firstColor = Color.fromARGB(255, 255, 158, 123);
        });
        break;
      // Cheese snakcs
      case '9':
      case '27':
        setState(() {
          firstColor = Color.fromARGB(255, 255, 192, 109);
        });
        break;
      // Peanut
      case '16':
        setState(() {
          firstColor = Color.fromARGB(255, 235, 228, 171);
        });
        break;
      // Seeds
      case '22':
      case '30':
        setState(() {
          firstColor = Color.fromARGB(255, 143, 143, 143);
        });
        break;
      case '31':
        setState(() {
          firstColor = Color.fromARGB(255, 207, 140, 140);
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
    return TextButton(
      style: TextButton.styleFrom(padding: EdgeInsets.all(0)),
      onPressed: () {
        print("CATEGORY_ID IS ${widget.category_id}");
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => CategoryPage(
              categoryId: widget.category_id,
              categoryName: widget.name,
              categories: widget.categories,
              business: widget.business,
            ),
          ),
        );
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: firstColor,
              // gradient: LinearGradient(
              //   colors: [firstColor, secondColor],
              //   transform:  GradientRotation(2),
              // ),
              // boxShadow:  [
              //   BoxShadow(
              //     color: Color.fromARGB(255, 200, 200, 200),
              //     offset: Offset(0, 3),
              //   ),
              //   BoxShadow(
              //     color: Color.fromARGB(255, 220, 220, 220),
              //     offset: Offset(0, 0),
              //     blurRadius: 4,
              //   )
              // ],
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
          // Container(
          //   clipBehavior: Clip.antiAliasWithSaveLayer,
          //   decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          //   width: double.infinity,
          //   height: double.infinity,
          //   alignment: Alignment.bottomLeft,
          //   child: Transform.rotate(
          //       // origin: Offset(-50, 0),
          //       alignment: Alignment.bottomCenter,
          //       angle: 0.5,
          //       child: Stack(
          //         children: <Widget>[
          //           widget.image != null
          //               ? Transform.translate(
          //                   offset:  Offset(15.0, -6.0),
          //                   child: ImageFiltered(
          //                     imageFilter:
          //                         ImageFilter.blur(sigmaY: 14, sigmaX: 14),
          //                     child: Container(
          //                       decoration: BoxDecoration(
          //                         border: Border.all(
          //                           color: Colors.transparent,
          //                           width: 0,
          //                         ),
          //                       ),
          //                       child: Opacity(
          //                         opacity: 0.8,
          //                         child: ColorFiltered(
          //                           colorFilter:  ColorFilter.mode(
          //                               Colors.black, BlendMode.srcATop),
          //                           child: CachedNetworkImage(
          //                             imageUrl: widget.image!,
          //                             cacheManager: CacheManager(Config(
          //                               "itemImage",
          //                               stalePeriod:  Duration(days: 7),
          //                               //one week cache period
          //                             )),
          //                             fit: BoxFit.fitHeight,
          //                             width: 500,
          //                             height: 500,
          //                           ),
          //                         ),
          //                       ),
          //                     ),
          //                   ),
          //                 )
          //               :  SizedBox(),
          //           // CachedNetworkImage(
          //           //   imageUrl: widget.image!,
          //           //   cacheManager: CacheManager(Config(
          //           //     "itemImage",
          //           //     stalePeriod:  Duration(days: 7),
          //           //     //one week cache period
          //           //   )),
          //           //   fit: BoxFit.fitHeight,
          //           //   width: 500,
          //           //   height: 500,
          //           //   errorWidget: (context, url, error) {
          //           //     return Container(
          //           //       alignment: Alignment.center,
          //           //       width: 10,
          //           //       height: 10,
          //           //       child:  SizedBox(),
          //           //     );
          //           //   },
          //           // ),
          //         ],
          //       )
          //       // child: widget.image!.isNotEmpty
          //       //     ? CachedNetworkImage(
          //       //         imageUrl: widget.image!,
          //       //         fit: BoxFit.fitHeight,
          //       //         width: 500,
          //       //         height: 500,
          //       //       )
          //       //     : Container(),
          //       ),
          // ),
          Container(
            padding: EdgeInsets.all(30 * globals.scaleParam),
            alignment: Alignment.topLeft,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(5))),
            child: Container(
              decoration: BoxDecoration(
                  color: textBG,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(5),
                      bottomRight: Radius.circular(5))),
              child: Text(
                widget.name,
                style: GoogleFonts.montserratAlternates(
                  textStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 42 * globals.scaleParam,
                      height: 2.4 * globals.scaleParam,
                      shadows: [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black.withOpacity(0.3),
                          offset: Offset(0, 2),
                        )
                      ]
                      // background: Paint()..color = textBG)
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
