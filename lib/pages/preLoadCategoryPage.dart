import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/misc/api.dart';
import 'package:naliv_delivery/pages/categoryPage2.dart';
import 'package:naliv_delivery/shared/loadingScreen.dart';

class PreLoadCategoryPage extends StatefulWidget {
  const PreLoadCategoryPage(
      {super.key,
      required this.business,
      this.categoryId,
      required this.category,
      required this.subcategories,
      required this.user});
  final Map<dynamic, dynamic> business;
  final String? categoryId;
  final Map category;
  final List subcategories;
  final Map<String, dynamic> user;

  @override
  State<PreLoadCategoryPage> createState() => _PreLoadCategoryPageState();
}

class _PreLoadCategoryPageState extends State<PreLoadCategoryPage> {
  pushCategoryPage() {
    getItemsMain3(
            widget.business["business_id"], widget.category["category_id"])
        .then((value) {
      print(value);
      Navigator.pushReplacement(context, CupertinoPageRoute(
        builder: (context) {
          return CategoryPage2(
            categoryId: widget.category["category_id"],
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
  void initState() {
    // TODO: implement initState
    super.initState();
    pushCategoryPage();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingScrenn();
  }
}
