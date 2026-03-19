import 'package:flutter/material.dart';

import '../model/item.dart' as ItemModel;
import '../pages/product_detail_page.dart';

class ItemOptionsDialog extends StatelessWidget {
  final ItemModel.Item item;

  const ItemOptionsDialog({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: ProductDetailPage(item: item),
    );
  }
}
