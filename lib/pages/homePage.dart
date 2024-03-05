import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/colors.dart';
import 'package:naliv_delivery/pages/categoryPage.dart';
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
  PageController _pageController =
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
    return List<Widget>.generate(imagesLength, (index) {
      return Container(
        margin: EdgeInsets.all(3),
        width: 5,
        height: 5,
        decoration: BoxDecoration(
            color: currentIndex == index ? gray1 : Colors.black12,
            shape: BoxShape.circle),
      );
    });
  }

  List categories = [];

  int activePage = 0;

  Future<void> _getCategories() async {
    List _categories = await getCategories();
    setState(() {
      categories = _categories;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getCategories();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          SizedBox(
            height: 10,
          ),
          Container(
            width: MediaQuery.of(context).size.width,
            // height: 170,
            child: GridView(
              primary: false,
              shrinkWrap: true,
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.25,
                  height: MediaQuery.of(context).size.width * 0.25,
                  margin: EdgeInsets.all(5),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius:
                                BorderRadius.all(Radius.circular(15))),
                        width: MediaQuery.of(context).size.width * 0.15,
                        height: MediaQuery.of(context).size.width * 0.15,
                      ),
                      Text("Новинки")
                    ],
                  ),
                ),
                Container(
                  width: MediaQuery.of(context).size.width * .25,
                  height: MediaQuery.of(context).size.width * .25,
                  margin: EdgeInsets.all(5),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius:
                                BorderRadius.all(Radius.circular(15))),
                        width: MediaQuery.of(context).size.width * 0.15,
                        height: MediaQuery.of(context).size.width * 0.15,
                      ),
                      Text("Новинки")
                    ],
                  ),
                ),
                Container(
                  width: MediaQuery.of(context).size.width * .25,
                  height: MediaQuery.of(context).size.width * .25,
                  margin: EdgeInsets.all(5),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius:
                                BorderRadius.all(Radius.circular(15))),
                        width: MediaQuery.of(context).size.width * 0.15,
                        height: MediaQuery.of(context).size.width * 0.15,
                      ),
                      Text("Новинки")
                    ],
                  ),
                ),
                Container(
                  width: MediaQuery.of(context).size.width * .25,
                  height: MediaQuery.of(context).size.width * 0.33,
                  margin: EdgeInsets.all(5),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius:
                                BorderRadius.all(Radius.circular(15))),
                        width: MediaQuery.of(context).size.width * 0.15,
                        height: MediaQuery.of(context).size.width * 0.15,
                      ),
                      Text("Новинки")
                    ],
                  ),
                )
              ],
            ),
            // child: PageView.builder(
            //   onPageChanged: (value) {
            //     setState(() {
            //       activePage = value;
            //     });
            //   },
            //   itemCount: images.length,
            //   itemBuilder: (context, index) {
            //     return Container(
            //         decoration: BoxDecoration(
            //             borderRadius: BorderRadius.all(Radius.circular(10)),
            //             image: DecorationImage(
            //                 opacity: 0.5,
            //                 image: NetworkImage(images[index]["image"]),
            //                 fit: BoxFit.cover)),
            //         margin: EdgeInsets.all(10),
            //         padding: EdgeInsets.all(10),
            //         child: TextButton(
            //           style:
            //               TextButton.styleFrom(alignment: Alignment.topLeft),
            //           child: Text(
            //             images[index]["text"],
            //             style: TextStyle(
            //                 fontSize: 20,
            //                 fontWeight: FontWeight.w700,
            //                 color: Colors.black),
            //           ),
            //           onPressed: () {
            //             print("object");
            //           },
            //         ));
            //   },
            //   controller: _pageController,
            //   padEnds: false,
            //   pageSnapping: false,
            // )
          ),
          // Row(
          //     mainAxisAlignment: MainAxisAlignment.center,
          //     children: indicators(images.length, activePage)),
          Padding(
            padding: EdgeInsets.all(10),
            child: GridView.builder(
              padding: EdgeInsets.all(0),
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
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
          SizedBox(
            height: 200,
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
          await PaletteGenerator.fromImageProvider(NetworkImage(
        widget.image!,
      ));
      setState(() {
        FirstColor = paletteGenerator.dominantColor!.color;
        SecondColor = paletteGenerator.vibrantColor!.color;
        textBG = paletteGenerator.darkMutedColor!.color;
      });
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
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => CategoryPage(
                      category_id: widget.category_id,
                      category_name: widget.name,
                      scroll: 0,
                    )),
          );
        },
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                      colors: [FirstColor, SecondColor],
                      transform: GradientRotation(2))),
            ),
            Container(
              clipBehavior: Clip.antiAliasWithSaveLayer,
              decoration:
                  BoxDecoration(borderRadius: BorderRadius.circular(15)),
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
                      : Container()),
            ),
            Container(
              padding: EdgeInsets.all(15),
              alignment: Alignment.topLeft,
              decoration:
                  BoxDecoration(borderRadius: BorderRadius.circular(15)),
              child: Text(
                widget.name,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    // backgroundColor: Colors.amber,
                    height: 1.2,
                    background: Paint()..color = textBG),
              ),
            )
          ],
        ));
  }
}
