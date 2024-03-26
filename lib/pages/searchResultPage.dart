import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/productPage.dart';
import 'package:naliv_delivery/shared/buyButton.dart';
import 'package:naliv_delivery/shared/itemCards.dart';
import 'package:naliv_delivery/shared/likeButton.dart';

class SearchResultPage extends StatefulWidget {
  const SearchResultPage({super.key, required this.search});
  final String search;
  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  ScrollController _sc = ScrollController();
  Widget itemsist = Container();
  int snapshotLenght = 0;
  bool _isSearchDone = false;
  int _itemCount = 0;

  Future<List?> _getEmptyList() async {
    print(123);
    return null;
  }

  Future<List> _getItems(int page) async {
    List items = await getItemsMain(page, widget.search);
    if (items.isEmpty) {
      _sc.dispose();
      setState(() {
        _isSearchDone = true;
      });
      return [];
    } else {
      setState(() {
        _itemCount++;
      });
      print(_itemCount);
      return items;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isSearchDone = false;

    return Scaffold(
        appBar: AppBar(
          // actions: [
          //   IconButton(
          //     icon: Icon(
          //       Icons.search,
          //       color: Colors.black,
          //     ),
          //     onPressed: () {
          //       setState(() {
          //         itemsist = Container();
          //       });
          //     },
          //   ),
          // ],
          title: TextField(
            decoration: InputDecoration(
                floatingLabelAlignment: FloatingLabelAlignment.start,
                floatingLabelBehavior: FloatingLabelBehavior.never,
                label: IconButton(
                  icon: const Icon(
                    Icons.search,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    setState(() {});
                  },
                ),
                fillColor: Colors.black12,
                filled: true,
                focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(60)),
                    borderSide: BorderSide(color: Colors.white, width: 0)),
                enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(60)),
                    borderSide: BorderSide(color: Colors.white, width: 0)),
                border: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white, width: 0))),
          ),
        ),
        body: ListView.builder(
            controller: _sc,
            shrinkWrap: true,
            primary: false,
            itemCount: 1,
            itemBuilder: ((context, index) {
              print(isSearchDone);

              return KeepAliveFutureBuilder(
                  future: _getItems(index),
                  builder: ((context, snapshot) {
                    List? items = snapshot.data;

                    // if (items!.length < index) {
                    //   return Container();
                    // }
                    if (snapshot.hasError) {
                      return Container();
                    } else if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return SizedBox(
                        height: MediaQuery.of(context).size.height,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [CircularProgressIndicator()],
                        ),
                      );
                    } else if (snapshot.connectionState ==
                        ConnectionState.done) {
                      if (snapshot.data == null) {
                        isSearchDone = true;
                        return Container();
                      } else if (items == null) {
                        return Container();
                      } else if (items.isEmpty) {
                        isSearchDone = true;
                        return Container();
                      } else {
                        return ListView.builder(
                          controller: _sc,
                          itemCount: items.length,
                          primary: false,
                          shrinkWrap: true,
                          itemBuilder: (context, index) => GestureDetector(
                            key: Key(items[index]["item_id"]),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                clipBehavior: Clip.antiAlias,
                                useSafeArea: true,
                                isScrollControlled: true,
                                builder: (context) {
                                  return ProductPage(
                                      item_id: items[index]["item_id"]);
                                },
                              );
                            },
                            child: Column(
                              children: [
                                ItemCardMedium(
                                  item_id: items[index]["item_id"],
                                  category_id: "",
                                  category_name: "",
                                  element: items[index],
                                  scroll: 0,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Divider(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    } else {
                      return Container();
                    }
                  }));
            }))
        // body: ListView.builder(
        //   // itemCount: snapshotLenght,
        //   itemBuilder: (context, index) {
        //     return KeepAliveFutureBuilder(
        //       future: getItemsMain(index, widget.search),
        //       builder: (context, snapshot) {
        //         List? items = snapshot.data;
        //         if (items!.length < index) {}
        //         if (snapshot.hasError) {
        //           return Container();
        //         } else if (snapshot.connectionState == ConnectionState.waiting) {
        //           return SizedBox(
        //             height: MediaQuery.of(context).size.height,
        //             child: const Column(
        //               mainAxisAlignment: MainAxisAlignment.start,
        //               mainAxisSize: MainAxisSize.max,
        //               children: [CircularProgressIndicator()],
        //             ),
        //           );
        //         } else {
        //           return ListView.builder(
        //             shrinkWrap: true,
        //             primary: false,
        //             itemCount: items!.length,
        //             prototypeItem: ListTile(
        //               title: Text(items[1]["name"]),
        //             ),
        //             itemBuilder: (context, index1) {
        //               return ListTile(
        //                 title: Text(items[index1]["name"]),
        //               );
        //             },
        //           );
        //         }
        //       },
        //     );
        //   },
        // ),
        );
  }
}

class KeepAliveFutureBuilder extends StatefulWidget {
  final Future future;
  final AsyncWidgetBuilder builder;

  KeepAliveFutureBuilder({required this.future, required this.builder});

  @override
  _KeepAliveFutureBuilderState createState() => _KeepAliveFutureBuilderState();
}

class _KeepAliveFutureBuilderState extends State<KeepAliveFutureBuilder>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder(
      future: widget.future,
      builder: widget.builder,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
