import 'dart:math';

import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  Future<List> _getItems(int index) async {
    await getItemsMain(index).then((value) {
      print(index);

      return value;
    });

    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          width: double.infinity,
          margin: EdgeInsets.all(10),
          child: TextField(
            decoration: InputDecoration(
                fillColor: Colors.black12,
                filled: true,
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: Colors.white, width: 0)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    borderSide: BorderSide(color: Colors.white, width: 0)),
                border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white, width: 0))),
          ),
        ),
      ),
      body: ListView.builder(itemBuilder: (context, index) {
        return KeepAliveFutureBuilder(
          future: getItemsMain(index),
          builder: (context, snapshot) {
            List? items = snapshot.data;
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
          },
        );
      }),
    );
  }
}



class KeepAliveFutureBuilder extends StatefulWidget {

  final Future future;
  final AsyncWidgetBuilder builder;

  KeepAliveFutureBuilder({
    required this.future,
    required this.builder
  });

  @override
  _KeepAliveFutureBuilderState createState() => _KeepAliveFutureBuilderState();
}

class _KeepAliveFutureBuilderState extends State<KeepAliveFutureBuilder> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: widget.future,
      builder: widget.builder,
    );
  }

  @override
  bool get wantKeepAlive => true;
}