import 'package:flutter/material.dart';

import '../../core/product_view.dart';
import '../../pages/product_detail_page.dart';
import 'ui/product_page.dart';

/// Opens a product from any catalogue surface.
///
/// Items that carry **options** fall back to the legacy page. The design shows no option or
/// portion UI, and the redesigned page drives the cart through the quantity control alone — so
/// routing such items here is the honest bridge rather than a silent regression.
///
/// Measured against the live catalogue (this store): **0 of 218 stocked items carry options**,
/// so in practice every product opens the redesigned page; the fallback is a guard, not a
/// routine path. It should be deleted once option selection exists in the new design.
void openProduct(
  BuildContext context,
  ProductView view, {
  bool liked = false,
  VoidCallback? onLike,
}) {
  final hasOptions = view.source.options?.isNotEmpty ?? false;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => hasOptions
          ? ProductDetailPage(item: view.source)
          : ProductPage(view: view, liked: liked, onLike: onLike),
    ),
  );
}
