import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:story_time/story_time.dart';
import 'package:visibility_detector/visibility_detector.dart';

class StoriesPage extends StatefulWidget {
  const StoriesPage(
      {super.key,
      required this.stories,
      required this.business,
      required this.initialIndex,
      required this.type,
      required this.t_id});
  final List stories;
  final Map<dynamic, dynamic> business;
  final int initialIndex;
  final String type;
  final String t_id;
  @override
  State<StoriesPage> createState() => _StoriesPageState();
}

class _StoriesPageState extends State<StoriesPage> {
  String currentStoryTitle = "";
  int currentStoryIndex = 0;
  String type = "";
  String t_id = "";

  _open() {
    if (type == "MRKTNG") {
      Navigator.pushReplacement(context, CupertinoPageRoute(
        builder: (context) {
          return PromotionItemsPage(
              business: widget.business, promotion_id: t_id);
        },
      ));
    }
    if (type == "CLCT") {
      Navigator.pushReplacement(context, CupertinoPageRoute(
        builder: (context) {
          return CollectionItemsPage(
              business: widget.business, collection_id: t_id);
        },
      ));
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      type = widget.type;
      t_id = widget.t_id;
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        bottomNavigationBar: GestureDetector(
          onVerticalDragEnd: (details) {
            print("object");
            _open();
          },
          onTap: () {
            _open();
          },
          child: Container(
              color: Color(0xFF121212),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Открыть",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    height: 30,
                  )
                ],
              )),
        ),
        appBar: widget.stories.length == 0
            ? null
            : AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                surfaceTintColor: Colors.black,
              ),
        body: Stack(
          children: [
            Container(
              padding: EdgeInsets.only(bottom: 20, top: 10),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Colors.black, Color(0xFF121212)],
                      begin: Alignment.center,
                      end: Alignment.bottomCenter)),
              // padding: EdgeInsets.all(5),
              child: Container(
                clipBehavior: Clip.antiAliasWithSaveLayer,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                ),
                child: StoryPageView(
                  initialPage: widget.initialIndex,
                  // onStoryIndexChanged: (newStoryIndex) {
                  //   widget.stories.firstWhere((element) {
                  //     List pgs = element["pages"];
                  //     pgs.forEach((v) {
                  //       if(v["id"] == ){}
                  //     });
                  //   });
                  // },
                  backgroundColor: Colors.transparent,

                  onPageLimitReached: () {
                    Navigator.pop(context);
                  },
                  itemBuilder: (context, pageIndex, storyIndex) {
                    Map page = widget.stories[pageIndex]["pages"][storyIndex];
                    return Stack(
                      children: [
                        Container(
                          clipBehavior: Clip.antiAliasWithSaveLayer,
                          alignment: Alignment.bottomLeft,
                          padding: EdgeInsets.all(0),
                          foregroundDecoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(30)),
                            gradient: page["title"].length == 0
                                ? null
                                : LinearGradient(
                                    colors: [Colors.transparent, Colors.black],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                          ),
                          decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(30)),
                              image: DecorationImage(
                                  fit: BoxFit.cover,
                                  image: NetworkImage(page["file"]))),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              vertical: 40, horizontal: 10),
                          child: Text(widget.stories[pageIndex]["name"]),
                        ),
                        Container(
                            alignment: Alignment.bottomLeft,
                            padding: EdgeInsets.only(bottom: 15, left: 10),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(30)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                VisibilityDetector(
                                    key: Key(
                                      page["id"].toString(),
                                    ),
                                    child: Text(
                                      page["title"],
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 24),
                                    ),
                                    onVisibilityChanged: (vi) {
                                      print(widget.stories[pageIndex]);
                                      if (mounted) {
                                        setState(() {
                                          type =
                                              widget.stories[pageIndex]["type"];
                                          t_id = widget.stories[pageIndex]
                                                  ["t_id"]
                                              .toString();
                                        });
                                      }
                                    }),
                                Text(
                                  page["desc"],
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 18),
                                ),
                                SizedBox(
                                  height: 50,
                                ),
                              ],
                            )),
                      ],
                    );
                  },
                  storyLength: (pageIndex) {
                    List pages = widget.stories[pageIndex]["pages"];
                    return pages.length;
                  },
                  pageLength: widget.stories.length,
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 100),
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.velocity.pixelsPerSecond.direction < 0) {
                    _open();
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            )
          ],
        ));
  }
}

class PromotionItemsPage extends StatefulWidget {
  const PromotionItemsPage(
      {super.key, required this.business, required this.promotion_id});
  final Map<dynamic, dynamic> business;
  final String promotion_id;
  @override
  State<PromotionItemsPage> createState() => _PromotionItemsPageState();
}

class _PromotionItemsPageState extends State<PromotionItemsPage> {
  List _items = [];
  void updateDataAmount(List newCart, int index) {
    _items[index]["cart"] = newCart;
  }

  Future<void> _getItems() async {
    await getItemsPromotion(widget.business["business_id"], widget.promotion_id)
        .then((value) {
      setState(() {
        _items = value["items"] ?? [];
      });
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.black,
            floating: false,
            pinned: true,
            centerTitle: false,
            title: Text("Акция"),
          ),
          SliverList.builder(
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final Map<String, dynamic> item = _items[index];

              return ItemCardListTile(
                itemId: item["item_id"],
                element: item,
                categoryId: "",
                categoryName: "",
                scroll: 0,
                business: widget.business,
                index: index,
                categoryPageUpdateData: updateDataAmount,
              );
            },
          )
        ],
      ),
    );
  }
}

class CollectionItemsPage extends StatefulWidget {
  const CollectionItemsPage(
      {super.key, required this.business, required this.collection_id});
  final Map<dynamic, dynamic> business;
  final String collection_id;
  @override
  State<CollectionItemsPage> createState() => _CollectionItemsPageState();
}

class _CollectionItemsPageState extends State<CollectionItemsPage> {
  List _items = [];
  void updateDataAmount(List newCart, int index) {
    _items[index]["cart"] = newCart;
  }

  Future<void> _getItems() async {
    await getItemsCollection(
            widget.business["business_id"], widget.collection_id)
        .then((value) {
      setState(() {
        _items = value["items"] ?? [];
      });
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.black,
            floating: false,
            pinned: true,
            centerTitle: false,
            title: Text("Подборка"),
          ),
          SliverList.builder(
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final Map<String, dynamic> item = _items[index];

              return ItemCardListTile(
                itemId: item["item_id"],
                element: item,
                categoryId: "",
                categoryName: "",
                scroll: 0,
                business: widget.business,
                index: index,
                categoryPageUpdateData: updateDataAmount,
              );
            },
          )
        ],
      ),
    );
  }
}
