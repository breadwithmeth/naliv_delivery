import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/colors.dart';
import 'package:naliv_delivery/pages/addressesPage.dart';
import 'package:naliv_delivery/pages/businessSelectStartPage.dart';
import 'package:naliv_delivery/pages/cartPage.dart';
import 'package:naliv_delivery/pages/categoryPage.dart';
import 'package:naliv_delivery/pages/loginPage.dart';
import 'package:naliv_delivery/pages/searchPage.dart';
import 'package:naliv_delivery/pages/settingsPage.dart';
import 'package:palette_generator/palette_generator.dart';

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

  Future<void> _getCategories() async {
    List categories1 = await getCategories();
    setState(() {
      categories = categories1;
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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getCategories();
    _getCurrentBusiness();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButton: FloatingActionButton(
            child: Icon(Icons.shopping_basket_rounded),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) {
                  return CartPage();
                },
              ));
            }),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
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
        )),
        appBar: AppBar(
          titleSpacing: 10,
          // scrolledUnderElevation: 100,
          automaticallyImplyLeading: true,
          // leading: IconButton(
          //   icon: Icon(Icons.menu),
          //   onPressed: () {},
          // ),

          title: TextButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) {
                  return const SearchPage();
                },
              ));
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(10))),
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
        body: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              GestureDetector(
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
                        borderRadius: BorderRadius.all(Radius.circular(10))),
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
                                const BorderRadius.all(Radius.circular(10)),
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
              SizedBox(
                width: MediaQuery.of(context).size.width,
                // height: 170,
                child: GridView(
                  primary: false,
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4),
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width * 0.25,
                      height: MediaQuery.of(context).size.width * 0.25,
                      margin: const EdgeInsets.all(5),
                      child: Column(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                                color: Colors.amber,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10))),
                            width: MediaQuery.of(context).size.width * 0.15,
                            height: MediaQuery.of(context).size.width * 0.15,
                          ),
                          const Text(
                            "Новинки",
                            style: TextStyle(fontSize: 12),
                          )
                        ],
                      ),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * .25,
                      height: MediaQuery.of(context).size.width * .25,
                      margin: const EdgeInsets.all(5),
                      child: Column(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                                color: Colors.amber,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10))),
                            width: MediaQuery.of(context).size.width * 0.15,
                            height: MediaQuery.of(context).size.width * 0.15,
                          ),
                          const Text(
                            "Со скидкой",
                            style: TextStyle(fontSize: 12),
                          )
                        ],
                      ),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * .25,
                      height: MediaQuery.of(context).size.width * .25,
                      margin: const EdgeInsets.all(5),
                      child: Column(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                                color: Colors.amber,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10))),
                            width: MediaQuery.of(context).size.width * 0.15,
                            height: MediaQuery.of(context).size.width * 0.15,
                          ),
                          const Text(
                            "Хит продаж",
                            style: TextStyle(fontSize: 12),
                          )
                        ],
                      ),
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * .25,
                      height: MediaQuery.of(context).size.width * 0.33,
                      margin: const EdgeInsets.all(5),
                      child: Column(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                                color: Colors.amber,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10))),
                            width: MediaQuery.of(context).size.width * 0.15,
                            height: MediaQuery.of(context).size.width * 0.15,
                          ),
                          const Text(
                            "Вы покупали",
                            style: TextStyle(fontSize: 12),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: GridView.builder(
                  padding: const EdgeInsets.all(0),
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
  Color FirstColor = Colors.white;
  Color SecondColor = Colors.blueGrey;
  Color textBG = Colors.black;
  Future<void> _getColors() async {
    if (widget.image!.isNotEmpty) {
      PaletteGenerator paletteGenerator =
          await PaletteGenerator.fromImageProvider(
        NetworkImage(
          widget.image!,
        ),
      );
      setState(
        () {
          FirstColor = paletteGenerator.vibrantColor!.color;
          SecondColor = paletteGenerator.darkVibrantColor!.color;
          textBG = paletteGenerator.darkMutedColor!.color;
        },
      );
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
      style: TextButton.styleFrom(padding: const EdgeInsets.all(0)),
      onPressed: () {
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
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                    colors: [FirstColor, SecondColor],
                    transform: const GradientRotation(2))),
          ),
          Container(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.bottomCenter,
            child: Transform.rotate(
              // origin: Offset(-50, 0),
              alignment: Alignment.bottomCenter,
              angle: 0.5,
              child: widget.image!.isNotEmpty
                  ? Image.network(
                      widget.image!,
                      fit: BoxFit.fitHeight,
                      width: 500,
                      height: 500,
                    )
                  : Container(),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.2,
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
