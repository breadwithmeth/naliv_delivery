import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/productPage.dart';
import 'package:naliv_delivery/shared/itemCards.dart';

class SearchResultPage extends StatefulWidget {
  const SearchResultPage(
      {super.key,
      required this.search,
      required this.page,
      this.result,
      this.categoryId = ""});
  final String search;
  final int page;
  final Widget? result;
  final String categoryId;
  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  late bool _isLastPage;
  late int _pageNumber;
  late bool _error;
  late bool _loading;
  final int _numberOfPostsPerRequest = 30;
  late List<Item> _items;
  final int _nextPageTrigger = 3;

  Future<void> _getItems() async {
    try {
      List? responseList = await getItemsMain(_pageNumber, widget.search);
      if (responseList != null) {
        List<Item> itemList = responseList.map((data) => Item(data)).toList();

        setState(() {
          _isLastPage = itemList.length < _numberOfPostsPerRequest;
          _loading = false;
          _pageNumber = _pageNumber + 1;
          _items.addAll(itemList);
        });
        if (itemList.length == 0) {
          setState(() {
            _isLastPage = true;
          });
        }
      }
    } catch (e) {
      print("error --> $e");
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void updateDataAmount(String newDataAmount, int index) {
    setState(() {
      _items[index].data["amount"] = newDataAmount;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _pageNumber = 0;
    _items = [];
    _isLastPage = false;
    _loading = true;
    _error = false;
    _getItems();
  }

  Widget buildPostsView() {
    if (_items.isEmpty) {
      if (_loading) {
        return const Center(
            child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ));
      } else if (_error) {
        return Center(child: errorDialog(size: 20));
      }
    }
    return ListView.builder(
      itemCount: _items.length + (_isLastPage ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == _items.length - _nextPageTrigger) {
          _getItems();
        }
        if (index == _items.length) {
          if (_error) {
            return Center(child: errorDialog(size: 15));
          } else {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ));
          }
        }
        final Item item = _items[index];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          key: Key(item.data["item_id"]),
          onTap: () {
            showModalBottomSheet(
              context: context,
              clipBehavior: Clip.antiAlias,
              useSafeArea: true,
              isScrollControlled: true,
              builder: (context) {
                return ProductPage(
                  item: item.data,
                  index: index,
                  returnDataAmount: updateDataAmount,
                );
              },
            );
          },
          child: Column(
            children: [
              ItemCard(
                item_id: item.data["item_id"],
                element: item.data,
                category_id: "",
                category_name: "",
                scroll: 0,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget errorDialog({required double size}) {
    return SizedBox(
      height: 180,
      width: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'An error occurred when fetching the posts.',
            style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w500,
                color: Colors.black),
          ),
          const SizedBox(
            height: 10,
          ),
          ElevatedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = false;
                  _getItems();
                });
              },
              child: const Text(
                "Retry",
                style: TextStyle(fontSize: 20, color: Colors.purpleAccent),
              )),
        ],
      ),
    );
  }

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
          //         _itemsist = Container();
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
        body: buildPostsView());
  }
}

class Item {
  final Map<String, dynamic> data;

  Item(this.data);
}
