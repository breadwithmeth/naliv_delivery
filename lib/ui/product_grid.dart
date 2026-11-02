import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'product_card.dart';

/// A lazy product collection whose rows grow to fit their actual card content.
class ProductGrid extends StatelessWidget {
  const ProductGrid({
    required this.itemCount,
    required this.itemBuilder,
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
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;
  final Widget? header;
  final Widget? footer;
  final int? maxRows;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final insets = padding.resolve(Directionality.of(context));
          final columns = ProductCard.columnsFor(
            context,
            constraints.maxWidth - insets.horizontal,
          );
          final visibleCount = maxRows == null
              ? itemCount
              : itemCount.clamp(0, columns * maxRows!).toInt();
          final rowCount = (visibleCount / columns).ceil();
          final headerCount = header == null ? 0 : 1;
          return ListView.builder(
            controller: controller,
            padding: padding,
            shrinkWrap: shrinkWrap,
            physics: physics,
            itemCount: headerCount + rowCount + (footer == null ? 0 : 1),
            itemBuilder: (context, index) {
              if (header != null && index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.huge),
                  child: header,
                );
              }
              final row = index - headerCount;
              if (row == rowCount) return footer!;
              return Padding(
                padding: EdgeInsets.only(
                  bottom:
                      row < rowCount - 1 || footer != null ? AppSpacing.xl : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: row * columns + column < visibleCount
                            ? itemBuilder(context, row * columns + column)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      );
}

/// A bounded recommendation rail with natural card heights and no text preflight.
class ProductRail extends StatelessWidget {
  const ProductRail({
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
    this.spacing = AppSpacing.md,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
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
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: padding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < itemCount; index++) ...[
                  if (index > 0) SizedBox(width: spacing),
                  SizedBox(width: width, child: itemBuilder(context, index)),
                ],
              ],
            ),
          );
        },
      );
}
