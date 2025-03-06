import 'package:flutter/cupertino.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/shared/ItemCard2.dart';

class NewItemsPage extends StatefulWidget {
  const NewItemsPage({super.key, required this.business});
  final Map<dynamic, dynamic> business;

  @override
  State<NewItemsPage> createState() => _NewItemsPageState();
}

class _NewItemsPageState extends State<NewItemsPage> {
  List _items = [];

  Future<void> _getItems() async {
    await getItemsNew(
      widget.business["business_id"],
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
        middle: Text('Новинки'),
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
            // Отступ для безопасной зоны внизу
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
