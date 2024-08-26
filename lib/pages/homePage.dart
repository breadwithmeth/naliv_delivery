// ignore_for_file: file_names

import 'dart:async';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/paintLogoPage.dart';
import '../globals.dart' as globals;
import 'package:google_fonts/google_fonts.dart';
import 'package:naliv_delivery/pages/categoryPage.dart';
import 'package:naliv_delivery/shared/cartButton.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/searchPage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.business, required this.user});

  final Map<dynamic, dynamic> business;
  final Map user;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin<HomePage> {
  @override
  bool get wantKeepAlive => true;

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int activePage = 0;

  bool categoryIsLoading = true;

  // Must be true if there is an active order, other wise false, for test purposes it's true
  bool isThereActiveOrder = true;

  bool isPageLoading = true;

  List<dynamic> businesses = [];

  Map<String, dynamic>? user;

  bool isLogoPainted = false;

  Future<List> _getCategories() async {
    List cats = await getCategories(widget.business["business_id"]);
    return cats;
  }

  void toggleDrawer() async {
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      _scaffoldKey.currentState!.openEndDrawer();
    } else {
      _scaffoldKey.currentState!.openDrawer();
    }
  }

  @override
  void initState() {
    super.initState();

    Timer(Duration(seconds: 1), () {
      setState(() {
        isLogoPainted = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder(
      future: _getCategories(),
      builder: (context, snapshot) {
        if (snapshot.hasData && isLogoPainted) {
          return Scaffold(
            backgroundColor: Colors.grey.shade100,
            key: _scaffoldKey,
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: SizedBox(
              child: CartButton(
                business: widget.business,
                user: widget.user,
              ),
            ),
            appBar: AppBar(
              toolbarHeight: 115 * globals.scaleParam,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20 * globals.scaleParam),
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
                                style: TextStyle(fontSize: 40 * globals.scaleParam),
                              ),
                              Text(
                                widget.business["address"],
                                maxLines: 1,
                                style: TextStyle(fontSize: 32 * globals.scaleParam),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          flex: 4,
                          fit: FlexFit.tight,
                          child: TextButton(
                            onPressed: () {
                              // Navigator.push(context, MaterialPageRoute(
                              //   builder: (context) {
                              //     return SearchPage(
                              //       business: widget.business,
                              //     );
                              //   },
                              // ));
                              Navigator.push(
                                context,
                                globals.getPlatformSpecialRoute(
                                  SearchPage(
                                    business: widget.business,
                                  ),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(foregroundColor: Colors.white.withOpacity(0)),
                            child: Container(
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.all(Radius.circular(10))),
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
                                      fontSize: 30 * globals.scaleParam,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.all(20 * globals.scaleParam),
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
                    SizedBox(
                      height: 10 * globals.scaleParam,
                    ),
                  ],
                ),
              ),
            ),
            body: Column(
              children: [
                SizedBox(
                  height: 10 * globals.scaleParam,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20 * globals.scaleParam,
                      vertical: 10 * globals.scaleParam,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            physics: ClampingScrollPhysics(),
                            child: GridView.builder(
                              padding: EdgeInsets.all(0),
                              physics: NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                // maxCrossAxisExtent: 650 * globals.scaleParam,
                                crossAxisCount: MediaQuery.of(context).size.aspectRatio > 1 ? 4 : 2,
                                childAspectRatio: 1,
                                crossAxisSpacing: 0,
                                mainAxisSpacing: 0,
                              ),
                              itemCount: snapshot.data!.length % 2 != 0 ? snapshot.data!.length + 1 + 2 : snapshot.data!.length + 2,
                              itemBuilder: (BuildContext ctx, index) {
                                return (snapshot.data!.length % 2 != 0 && index >= snapshot.data!.length) ||
                                        (index >= snapshot.data!.length && snapshot.data!.length % 2 == 0)
                                    ? Container(
                                        margin: EdgeInsets.all(8 * globals.scaleParam),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.all(Radius.circular(15)),
                                        ),
                                      )
                                    : CategoryItem(
                                        category_id: snapshot.data![index]["category_id"],
                                        name: snapshot.data![index]["name"],
                                        image: snapshot.data![index]["photo"],
                                        categories: snapshot.data!,
                                        business: widget.business,
                                        user: widget.user,
                                      );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                )
              ],
            ),
          );
        } else {
          return PaintLogoPage(
            city: widget.user["city_name"],
          );
        }
      },
    );
  }
}

class CategoryItem extends StatefulWidget {
  const CategoryItem(
      {super.key,
      required this.category_id,
      required this.name,
      required this.image,
      required this.categories,
      required this.business,
      required this.user});
  final String category_id;
  final String name;
  final String? image;
  final List<dynamic> categories;
  final Map<dynamic, dynamic> business;
  final Map user;

  @override
  State<CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<CategoryItem> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.all(0)),
          onPressed: () {
            print("CATEGORY_ID IS ${widget.category_id}");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryPage(
                  categoryId: widget.category_id,
                  categoryName: widget.name,
                  categories: widget.categories,
                  business: widget.business,
                  user: widget.user,
                ),
              ),
            );
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                margin: EdgeInsets.all(8 * globals.scaleParam),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                      ),
                    ),
                    //* VERY SCARY AND PRECISE SHT, PLS DON'T CHANGE
                    Container(
                      alignment: Alignment.bottomCenter,
                      // padding: EdgeInsets.all(10 * globals.scaleParam),
                      child: Container(
                        height: constraints.maxHeight * 0.665,
                        width: constraints.maxWidth * 0.65,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ShaderMask(
                            blendMode: BlendMode.overlay,
                            shaderCallback: (bounds) {
                              Rect newBounds = Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height);
                              return LinearGradient(
                                colors: [Colors.orange, Colors.yellow],
                              ).createShader(newBounds);
                            },
                            child: OverflowBox(
                              maxWidth: constraints.maxWidth * 0.8,
                              maxHeight: constraints.maxHeight * 0.667,
                              child: Container(
                                color: Colors.white,
                                padding: EdgeInsets.all(10 * globals.scaleParam),
                                child: ExtendedImage.network(
                                  widget.image!,
                                  color: Colors.grey.shade400,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      alignment: Alignment.topLeft,
                      child: Container(
                        margin: EdgeInsets.all(10 * globals.scaleParam),
                        // color: Colors.red,
                        height: constraints.maxHeight * 0.28,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                widget.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 3,
                                style: GoogleFonts.montserratAlternates(
                                  textStyle: TextStyle(
                                    fontSize: 46 * globals.scaleParam,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                    height: 2 * globals.scaleParam,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
