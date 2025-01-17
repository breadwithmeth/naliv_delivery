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
      required this.category});
  final Map<dynamic, dynamic> business;
  final String? categoryId;
  final Map category;
  @override
  State<PreLoadCategoryPage> createState() => _PreLoadCategoryPageState();
}

class _PreLoadCategoryPageState extends State<PreLoadCategoryPage> {
  pushCategoryPage() {
    getItemsMain3(
            widget.business["business_id"], widget.category["category_id"])
        .then((value) {
      Navigator.pushReplacement(context, CupertinoPageRoute(
        builder: (context) {
          return CategoryPage2(
              categoryId: widget.category["category_id"],
              business: widget.business,
              category: widget.category,
              subcategories: value!["c_children"],
              items: value!["items"]);
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
