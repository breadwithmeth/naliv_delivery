import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/shared/itemCards.dart';
import '../globals.dart' as globals;
import 'package:naliv_delivery/pages/searchResultPage.dart';
import 'package:flutter/cupertino.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.business, this.category_id = ""});

  final Map<dynamic, dynamic> business;
  final String category_id;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _keyword = TextEditingController();
  bool isTextInField = false;
  bool isSearchEverywhere = false;

  List _items = [];
  void updateDataAmount(List newCart, int index) {
    _items[index]["cart"] = newCart;
  }

  Future<void> _getItems() async {
    await getItemsPopular(
      widget.business["business_id"],
    ).then((value) {
      setState(() {
        _items = value["items"];
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
        body: CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.black,
          surfaceTintColor: Colors.black,
          title: Text("Поиск"),
          centerTitle: false,
        ),
        SliverPadding(
          padding: EdgeInsets.all(10),
          sliver: SliverToBoxAdapter(
            child: Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Color(0xFF121212)),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        onFieldSubmitted: (value) {
                          Navigator.push(context,
                              CupertinoPageRoute(builder: (context) {
                            return SearchResultPage(
                              search: _keyword.text,
                              business: widget.business,
                            );
                          }));
                        },
                        style: TextStyle(color: Colors.black),
                        controller: _keyword,
                        onChanged: (value) {
                          setState(() {
                            isTextInField = value.isNotEmpty;
                          });
                        },
                        decoration: InputDecoration(
                          fillColor: Colors.grey.shade200,
                          filled: true,
                          hintText: "Поиск",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    IconButton(onPressed: () {}, icon: Icon(Icons.search))
                  ],
                )),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(10),
          sliver: SliverToBoxAdapter(
            child: Text(
              "Рекомендуемые товары",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.circular(20)),
            child: ListView.builder(
              primary: false,
              shrinkWrap: true,
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
            ),
          ),
        )
      ],
    ));
  }
}
