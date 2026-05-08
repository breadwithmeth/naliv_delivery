import 'package:flutter/material.dart';

import '../model/item.dart' as item_model;
import '../pages/product_detail_page.dart';

class ItemOptionsDialog extends StatelessWidget {
  final item_model.Item item;

  const ItemOptionsDialog({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: ProductDetailPage(item: item),
    );
  }
}
