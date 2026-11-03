import 'package:flutter/material.dart';

import '../core/product_view.dart';
import '../design/tokens.dart';
import 'product_card.dart';

/// A lazy product collection in which every row has one fixed height.
///
/// The column count and the row height come from the available width and the text scaler
/// (see [ProductCard.columnsFor] / [ProductCard.extentFor]), never from the content of a
/// particular card, so long names cannot make a row ragged.
///
/// Pass [products] — the views behind [itemBuilder] — so the rows reserve an old-price or
/// saving line only when some card shows one. Without it the tallest layout is assumed.
class ProductGrid extends StatelessWidget {
  const ProductGrid({
    required this.itemCount,
    required this.itemBuilder,
    this.products,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.header,
    this.footer,
    this.maxRows,
    this.shrinkWrap = false,
    this.physics,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Iterable<ProductView>? products;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;
  final Widget? header;
  final Widget? footer;
  final int? maxRows;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  static const double _columnSpacing = AppSpacing.sm;
  static const double _rowSpacing = AppSpacing.md;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final insets = padding.resolve(Directionality.of(context));
          final available = constraints.maxWidth - insets.horizontal;
          final columns = ProductCard.columnsFor(
            context,
            available,
            spacing: _columnSpacing,
          );
          final cardWidth =
              (available - _columnSpacing * (columns - 1)) / columns;
          final flags = ProductCardLayout.flagsOf(products);
          final rowHeight = ProductCard.extentFor(
            context,
            cardWidth,
            hasOldPrice: flags.hasOldPrice,
            hasSaving: flags.hasSaving,
          );
          final visibleCount = maxRows == null
              ? itemCount
              : itemCount.clamp(0, columns * maxRows!).toInt();
          final rowCount = (visibleCount / columns).ceil();
          final headerCount = header == null ? 0 : 1;
          return ProductCardLayout(
            hasOldPrice: flags.hasOldPrice,
            hasSaving: flags.hasSaving,
            child: ListView.builder(
              controller: controller,
              padding: padding,
              shrinkWrap: shrinkWrap,
              physics: physics,
              itemCount: headerCount + rowCount + (footer == null ? 0 : 1),
              itemBuilder: (context, index) {
                if (header != null && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    child: header,
                  );
                }
                final row = index - headerCount;
                if (row == rowCount) return footer!;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        row < rowCount - 1 || footer != null ? _rowSpacing : 0,
                  ),
                  child: SizedBox(
                    height: rowHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var column = 0; column < columns; column++) ...[
                          if (column > 0) const SizedBox(width: _columnSpacing),
                          Expanded(
                            child: row * columns + column < visibleCount
                                ? itemBuilder(context, row * columns + column)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
}

/// A horizontal product rail of fixed-width, fixed-height cards, left-aligned.
///
/// One card sits at the left edge like the first of many; the rail scrolls only when its
/// cards overflow. See [ProductGrid] for [products].
class ProductRail extends StatelessWidget {
  const ProductRail({
    required this.itemCount,
    required this.itemBuilder,
    this.products,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
    this.spacing = AppSpacing.md,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Iterable<ProductView>? products;
  final EdgeInsetsGeometry padding;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final insets = padding.resolve(Directionality.of(context));
          final availableWidth = constraints.maxWidth - insets.horizontal;
          final width = ProductCard.widthFor(context)
              .clamp(AppSpacing.touchTarget * 2, availableWidth)
              .toDouble();
          final flags = ProductCardLayout.flagsOf(products);
          final height = ProductCard.extentFor(
            context,
            width,
            hasOldPrice: flags.hasOldPrice,
            hasSaving: flags.hasSaving,
          );
          return ProductCardLayout(
            hasOldPrice: flags.hasOldPrice,
            hasSaving: flags.hasSaving,
            child: SizedBox(
              width: double.infinity,
              height: height + insets.vertical,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: padding,
                itemCount: itemCount,
                separatorBuilder: (_, __) => SizedBox(width: spacing),
                itemBuilder: (context, index) => SizedBox(
                  width: width,
                  height: height,
                  child: itemBuilder(context, index),
                ),
              ),
            ),
          );
        },
      );
}
