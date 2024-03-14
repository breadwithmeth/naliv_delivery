import 'dart:math';

import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';

class SearchResultPage extends StatefulWidget {
  const SearchResultPage({super.key, required this.search});
  final String search;
  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  Widget itemsList = Container();
  int snapshotLenght = 0;

  @override
  Widget build(BuildContext context) {
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
          //         itemsList = Container();
          //       });
          //     },
          //   ),
          // ],
          title: TextField(
            decoration: InputDecoration(
                floatingLabelAlignment: FloatingLabelAlignment.start,
                floatingLabelBehavior: FloatingLabelBehavior.never,
                label: IconButton(
                  icon: Icon(
                    Icons.search,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    setState(() {});
                  },
                ),
                fillColor: Colors.black12,
                filled: true,
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(60)),
                    borderSide: BorderSide(color: Colors.white, width: 0)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(60)),
                    borderSide: BorderSide(color: Colors.white, width: 0)),
                border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white, width: 0))),
          ),
        ),
        body: ListView.builder(
            // itemCount: snapshotLenght,
            itemBuilder: (context, index) {
             
              return KeepAliveFutureBuilder(
                future: getItemsMain(index, widget.search),
                builder: (context, snapshot) {
                  List? items = snapshot.data;
                  if (items!.length < index) {
                    
                  }
                  if (snapshot.hasError) {
                    return Container();
                  } else if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Container(
                      height: MediaQuery.of(context).size.height,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [CircularProgressIndicator()],
                        mainAxisSize: MainAxisSize.max,
                      ),
                    );
                  } else {
                    return ListView.builder(
                      shrinkWrap: true,
                      primary: false,
                      itemCount: items!.length,
                      prototypeItem: ListTile(
                        title: Text(items[1]["name"]),
                      ),
                      itemBuilder: (context, index1) {
                        return ListTile(
                          title: Text(items[index1]["name"]),
                        );
                      },
                    );
                  }
                },
              );
            }));
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
