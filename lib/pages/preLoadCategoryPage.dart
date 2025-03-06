import 'package:flutter/cupertino.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/categoryPage2.dart';

class PreLoadCategoryPage extends StatefulWidget {
  const PreLoadCategoryPage({
    super.key,
    required this.business,
    this.categoryId,
    required this.category,
    required this.subcategories,
    required this.user,
  });

  final Map<dynamic, dynamic> business;
  final String? categoryId;
  final Map category;
  final List subcategories;
  final Map<String, dynamic> user;

  @override
  State<PreLoadCategoryPage> createState() => _PreLoadCategoryPageState();
}

class _PreLoadCategoryPageState extends State<PreLoadCategoryPage> {
  @override
  void initState() {
    super.initState();
    pushCategoryPage();
  }

  pushCategoryPage() {
    getItemsMain3(
            widget.business["business_id"], widget.category["c_id"].toString())
        .then((value) {
      print(value);
      Navigator.pushReplacement(context, CupertinoPageRoute(
        builder: (context) {
          return CategoryPage2(
            categoryId: widget.category["c_id"].toString(),
            business: widget.business,
            category: widget.category,
            subcategories: widget.subcategories,
            items: value["items"] ?? [],
            user: widget.user,
            priceIncrease: false,
          );
        },
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.category["name"] ?? "Загрузка"),
      ),
      // child: Text(widget.subcategories.toString()),
      child: Center(
        child: CupertinoActivityIndicator(
          radius: 15,
        ),
      ),
    );
  }
}
