import 'package:flutter/cupertino.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/shared/ItemCard2.dart';
import 'package:naliv_delivery/shared/cartButton.dart';

class SearchResultPage extends StatefulWidget {
  const SearchResultPage(
      {super.key, required this.business, required this.search});

  final Map<dynamic, dynamic> business;
  final String search;

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  List _items = [];

  Future<void> _getItems() async {
    await getItemsSearch(
      widget.business["business_id"],
      widget.search,
    ).then((value) {
      setState(() {
        _items = value["items"];
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
      navigationBar: CupertinoNavigationBar(
        middle: Text('Результаты поиска'),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: CustomScrollView(
              physics: BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.all(16),
                  sliver: _items.isEmpty
                      ? SliverToBoxAdapter(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.search,
                                  size: 48,
                                  color: CupertinoColors.systemGrey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "Ничего не найдено",
                                  style: TextStyle(
                                    color: CupertinoColors.secondaryLabel,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => ItemCard2(
                              item: _items[index],
                              business: widget.business,
                            ),
                            childCount: _items.length,
                          ),
                        ),
                ),
                // Отступ для CartButton
                SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),
          // CartButton
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: CartButton(
              business: widget.business,
              user: {},
            ),
          ),
        ],
      ),
    );
  }
}
