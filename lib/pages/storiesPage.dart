import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/shared/ItemCard2.dart';
import 'package:story_time/story_time.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:path/path.dart' as path;

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

  String _determineFileType(String url) {
    try {
      // Get the file extension from the URL
      String extension = path.extension(Uri.parse(url).path).toLowerCase();

      // Determine the file type based on the extension
      switch (extension) {
        case '.jpg':
        case '.jpeg':
        case '.png':
        case '.gif':
          return "Image";
        case '.mp4':
        case '.mkv':
        case '.avi':
          return "Video";
        case '.mp3':
        case '.wav':
          return "Audio";
        case '.pdf':
        case '.doc':
        case '.docx':
          return "Document";
        case '.zip':
        case '.rar':
          return "Archive";
        default:
          return "Unknown type";
      }
    } catch (e) {
      return "Invalid URL";
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
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: widget.stories.isEmpty
          ? null
          : CupertinoNavigationBar(
              backgroundColor: CupertinoColors.black,
            ),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.only(bottom: 20, top: 10),
            child: Container(
              clipBehavior: Clip.antiAliasWithSaveLayer,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
              ),
              child: StoryPageView(
                initialPage: widget.initialIndex,
                backgroundColor: CupertinoColors.black,
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
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          image: DecorationImage(
                            fit: BoxFit.cover,
                            image: NetworkImage(page["file"]),
                          ),
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(vertical: 40, horizontal: 10),
                        child: Text(
                          widget.stories[pageIndex]["name"],
                          style: TextStyle(
                            color: CupertinoColors.white,
                            shadows: [
                              Shadow(
                                color: CupertinoColors.black.withOpacity(0.5),
                                offset: Offset(0, 1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        alignment: Alignment.bottomLeft,
                        padding: EdgeInsets.only(bottom: 15, left: 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            VisibilityDetector(
                              key: Key(page["id"].toString()),
                              child: Text(
                                page["title"],
                                style: CupertinoTheme.of(context)
                                    .textTheme
                                    .navLargeTitleTextStyle
                                    .copyWith(
                                  color: CupertinoColors.white,
                                  shadows: [
                                    Shadow(
                                      color: CupertinoColors.black
                                          .withOpacity(0.5),
                                      offset: Offset(0, 2),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              onVisibilityChanged: (vi) {
                                if (mounted) {
                                  setState(() {
                                    type = widget.stories[pageIndex]["type"];
                                    t_id = widget.stories[pageIndex]["t_id"]
                                        .toString();
                                  });
                                }
                              },
                            ),
                            Text(
                              page["desc"],
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .copyWith(
                                color: CupertinoColors.white,
                                shadows: [
                                  Shadow(
                                    color:
                                        CupertinoColors.black.withOpacity(0.5),
                                    offset: Offset(0, 1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 50),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                storyLength: (pageIndex) =>
                    widget.stories[pageIndex]["pages"].length,
                pageLength: widget.stories.length,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if (details.velocity.pixelsPerSecond.dy < 0) {
                  _open();
                }
              },
              onTap: _open,
              child: Container(
                  color: CupertinoColors.black.withAlpha(150),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                    top: 16,
                  ),
                  child: Row(
                    children: [
                      Text(
                        "Открыть",
                        style: CupertinoTheme.of(context)
                            .textTheme
                            .textStyle
                            .copyWith(color: CupertinoColors.white),
                      ),
                    ],
                  )),
            ),
          ),
        ],
      ),
    );
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
    setState(() {
      _items[index]["cart"] = newCart;
    });
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
    super.initState();
    _getItems();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black,
        middle: Text(
          "Акция",
          style: TextStyle(color: CupertinoColors.white),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final Map<String, dynamic> item = _items[index];
                  return ItemCard2(
                    item: item,
                    business: widget.business,
                  );
                },
                childCount: _items.length,
              ),
            ),
          ],
        ),
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
    setState(() {
      _items[index]["cart"] = newCart;
    });
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
    super.initState();
    _getItems();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black,
        middle: Text(
          "Подборка",
          style: TextStyle(color: CupertinoColors.white),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final Map<String, dynamic> item = _items[index];
                  return ItemCard2(
                    item: item,
                    business: widget.business,
                  );
                },
                childCount: _items.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
