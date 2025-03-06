import 'package:flutter/cupertino.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/searchResultPage.dart';
import 'package:naliv_delivery/shared/ItemCard2.dart';
import '../globals.dart' as globals;

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
  List _items = [];

  Future<void> _getItems() async {
    await getItemsPopular(widget.business["business_id"]).then((value) {
      setState(() => _items = value["items"]);
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
        middle: Text('Поиск'),
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CupertinoSearchTextField(
                  controller: _keyword,
                  placeholder: 'Поиск товаров',
                  onSubmitted: (value) {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => SearchResultPage(
                          search: value,
                          business: widget.business,
                        ),
                      ),
                    );
                  },
                  onChanged: (value) {
                    setState(() {
                      isTextInField = value.isNotEmpty;
                    });
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  "Рекомендуемые товары",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return ItemCard2(
                      item: _items[index],
                      business: widget.business,
                    );
                  },
                  childCount: _items.length,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(bottom: 16),
            ),
          ],
        ),
      ),
    );
  }
}
