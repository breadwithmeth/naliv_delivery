import 'package:flutter/material.dart';

import '../../core/product_view.dart';
import '../../pages/product_detail_page.dart';
import 'ui/product_page.dart';

// Opens either the simple-product frame or the complete themed configuration
// editor. Both routes use the same supported cart and scoped likes.
void openProduct(
  BuildContext context,
  ProductView view, {
  VoidCallback? onCart,
  int? businessId,
}) {
  final hasOptions = view.source.options?.isNotEmpty ?? false;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => hasOptions
          ? ProductDetailPage(
              item: view.source,
              businessId: businessId,
              onCart: onCart,
            )
          : ProductPage(
              view: view,
              businessId: businessId,
              onCart: onCart,
            ),
    ),
  );
}
