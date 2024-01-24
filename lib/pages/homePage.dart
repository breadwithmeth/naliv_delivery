import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/misc/colors.dart';
import 'package:naliv_delivery/pages/categoryPage.dart';

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
    // {
    //   "text":
    //       "Очень длинный текст акции 123 123 123 123 123 12312312312312313213",
    //   "image":
    //       "https://podacha-blud.com/uploads/posts/2022-12/1670216296_41-podacha-blud-com-p-zhenskie-kokteili-alkogolnie-foto-55.jpg"
    // },
    // {
    //   "text": "123",
    //   "image": "https://pogarchik.com/wp-content/uploads/2019/03/5-1.jpg"
    // },
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
            height: 90,
          ),
          Container(
              width: MediaQuery.of(context).size.width,
              height: 170,
              child: PageView.builder(
                onPageChanged: (value) {
                  setState(() {
                    activePage = value;
                  });
                },
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Container(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          image: DecorationImage(
                              opacity: 0.5,
                              image: NetworkImage(images[index]["image"]),
                              fit: BoxFit.cover)),
                      margin: EdgeInsets.all(10),
                      padding: EdgeInsets.all(10),
                      child: TextButton(
                        style:
                            TextButton.styleFrom(alignment: Alignment.topLeft),
                        child: Text(
                          images[index]["text"],
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black),
                        ),
                        onPressed: () {
                          print("object");
                        },
                      ));
                },
                controller: _pageController,
                padEnds: false,
                pageSnapping: false,
              )),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: indicators(images.length, activePage)),
          // GridView.count(
          // addRepaintBoundaries: false,
          // shrinkWrap: true, crossAxisCount: 2, children: [
          //   Container(
          //     padding: EdgeInsets.all(15),
          //     alignment: Alignment.topLeft,
          //     decoration: BoxDecoration(
          //         color: Color(0xFFd8d8d8),
          //         borderRadius: BorderRadius.circular(15)),
          //     child: Text(
          //       "123123",
          //       style: TextStyle(color: Colors.black, fontSize: 14),
          //     ),
          //   ),
          //   Container(
          //     padding: EdgeInsets.all(15),
          //     alignment: Alignment.topLeft,
          //     decoration: BoxDecoration(
          //         color: Color(0xFFd8d8d8),
          //         borderRadius: BorderRadius.circular(15)),
          //     child: Text(
          //       "123123",
          //       style: TextStyle(color: Colors.black, fontSize: 14),
          //     ),
          //   ),
          //   Container(
          //     padding: EdgeInsets.all(15),
          //     alignment: Alignment.topLeft,
          //     decoration: BoxDecoration(
          //         color: Color(0xFFd8d8d8),
          //         borderRadius: BorderRadius.circular(15)),
          //     child: Text(
          //       "123123",
          //       style: TextStyle(color: Colors.black, fontSize: 14),
          //     ),
          //   ),
          //   Container(
          //     padding: EdgeInsets.all(15),
          //     alignment: Alignment.topLeft,
          //     decoration: BoxDecoration(
          //         color: Color(0xFFd8d8d8),
          //         borderRadius: BorderRadius.circular(15)),
          //     child: Text(
          //       "123123",
          //       style: TextStyle(color: Colors.black, fontSize: 14),
          //     ),
          //   ),
          // ]),
          Padding(
            padding: EdgeInsets.all(10),
            child: GridView.builder(
              padding: EdgeInsets.all(0),
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  childAspectRatio: 1,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10),
              itemCount: categories.length,
              itemBuilder: (BuildContext ctx, index) {
                return TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.all(0)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => CategoryPage(
                                  category_id: categories[index]["category_id"],
                                  category_name: categories[index]["name"],
                                  scroll: 0,
                                )),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(15),
                      alignment: Alignment.topLeft,
                      decoration: BoxDecoration(
                          color: Color(0xFFd8d8d8),
                          borderRadius: BorderRadius.circular(15)),
                      child: Text(
                        categories[index]["name"],
                        style: TextStyle(color: Colors.black, fontSize: 14),
                      ),
                    ));
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
