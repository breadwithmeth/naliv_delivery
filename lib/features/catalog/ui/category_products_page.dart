import 'package:flutter/material.dart';

import '../../../ui/app_states.dart';
import 'package:provider/provider.dart';

import '../../../core/product_view.dart';
import '../../../design/tokens.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_top_bar.dart';
import '../../../ui/product_card.dart';
import '../../../utils/cart_provider.dart';
import '../catalog_data_source.dart';
import '../../product/product_navigation.dart';

/// A single leaf category's products — the design's `Каталог - Все товары` frame.
///
/// Geometry: a 343 × 57 top bar 24 px under the status bar, then a 24 px gap and the grid —
/// 3 columns of 110 px cards with 6 px gutters (row pitch 246 for the 240 px card). The floating
/// cart button carries the running total, as everywhere else.
class CategoryProductsPage extends StatefulWidget {
  const CategoryProductsPage({
    required this.categoryId,
    required this.title,
    required this.businessId,
    this.initialItems,
    this.onSearch,
    this.onCart,
    super.key,
  });

  final int categoryId;
  final String title;
  final int businessId;

  /// Items already fetched by a parent screen, so opening a section does not refetch.
  final List<ProductView>? initialItems;

  final VoidCallback? onSearch;

  /// Opens the cart.
  final VoidCallback? onCart;

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  List<ProductView>? _items;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems;
    if (_items == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _items = null;
    });
    try {
      final items = await CatalogDataSource(businessId: widget.businessId)
          .items(widget.categoryId);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = context.watch<CartProvider>();
    final count = tabs.displayItemCount;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: AppTopBar(
                    title: widget.title,
                    onBack: () => Navigator.of(context).maybePop(),
                    onSearch: widget.onSearch,
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
                Expanded(child: _body()),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
              child: Center(
                child: AppCartButton(
                  itemCount: count,
                  total: count == 0 ? null : tabs.getTotalPrice().round(),
                  onTap: widget.onCart,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_failed) {
      return AppErrorState(
        message: 'Не удалось загрузить товары',
        onRetry: _load,
      );
    }
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      // No designed empty state exists for an empty category; kept plain on purpose.
      return const AppEmptyState(title: 'В этой категории пока нет товаров');
    }
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        0,
        AppSpacing.xxxl,
        AppCartButton.clearance + MediaQuery.paddingOf(context).bottom,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 110 / ProductCard.height,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ProductCard.fromView(
          item,
          onTap: () => openProduct(context, item),
          quantity:
              context.watch<CartProvider>().getCatalogQuantity(item.source),
          onIncrement: () =>
              context.read<CartProvider>().incrementCatalogItem(item.source),
          onDecrement: () =>
              context.read<CartProvider>().decrementCatalogItem(item.source),
        );
      },
    );
  }
}
