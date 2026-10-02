import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/product_view.dart';
import '../../../design/tokens.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_states.dart';
import '../../../ui/app_top_bar.dart';
import '../../../ui/product_card.dart';
import '../../../utils/cart_provider.dart';
import '../../product/product_navigation.dart';
import '../catalog_data_source.dart';

/// A complete leaf category with prefetched items and scroll-driven pagination.
///
/// Columns adapt to viewport width and inherited text scaling. The floating
/// cart button carries the running total without a persistent navigation bar.
class CategoryProductsPage extends StatefulWidget {
  const CategoryProductsPage({
    required this.categoryId,
    required this.title,
    required this.businessId,
    this.initialItems,
    this.initialHasMore,
    this.onSearch,
    this.onCart,
    super.key,
  });

  final int categoryId;
  final String title;
  final int businessId;

  /// Items already fetched by a parent screen, so opening a section does not refetch.
  final List<ProductView>? initialItems;

  /// Whether a prefetched first page continues. Without this metadata,
  /// caller-supplied items are treated as a complete list.
  final bool? initialHasMore;

  final VoidCallback? onSearch;

  /// Opens the cart.
  final VoidCallback? onCart;

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  final _scroll = ScrollController();
  List<ProductView>? _items;
  bool _failed = false;
  bool _loadingMore = false;
  bool _moreFailed = false;
  bool _hasMore = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems;
    _hasMore = widget.initialHasMore ?? false;
    _page = _items == null ? 1 : 2;
    _scroll.addListener(_onScroll);
    if (_items == null) {
      _load();
    } else {
      _checkForMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_hasMore &&
        !_loadingMore &&
        !_moreFailed &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  void _checkForMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || !_hasMore || _moreFailed) return;
      _onScroll();
    });
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _items = null;
      _hasMore = false;
      _page = 1;
    });
    try {
      final result = await CatalogDataSource(businessId: widget.businessId)
          .itemsPage(widget.categoryId);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _hasMore = result.hasMore;
        _page = 2;
      });
      _checkForMore();
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });
    try {
      final result = await CatalogDataSource(businessId: widget.businessId)
          .itemsPage(widget.categoryId, page: _page);
      if (!mounted) return;
      setState(() {
        _items = [...?_items, ...result.items];
        _hasMore = result.hasMore;
        _page++;
        _loadingMore = false;
      });
      _checkForMore();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _moreFailed = true;
      });
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
                      const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                  child: AppTopBar(
                    title: widget.title,
                    onBack: () => Navigator.of(context).maybePop(),
                    onSearch: widget.onSearch,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final usableWidth = constraints.maxWidth - AppSpacing.gutter * 2;
            final columns = ProductCard.columnsFor(context, usableWidth);
            return GridView.builder(
              key: const ValueKey('category-products-grid'),
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                0,
                AppSpacing.gutter,
                AppCartButton.clearanceFor(context) +
                    MediaQuery.paddingOf(context).bottom,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: AppSpacing.xl,
                crossAxisSpacing: AppSpacing.md,
                mainAxisExtent: ProductCard.heightFor(context,
                    hasOldPrice: items.any((item) => item.oldPrice != null)),
              ),
              itemCount: items.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == items.length) {
                  return Center(
                    child: _moreFailed
                        ? TextButton(
                            onPressed: _loadMore,
                            child: const Text('Повторить загрузку'),
                          )
                        : const CircularProgressIndicator(),
                  );
                }
                final item = items[index];
                return ProductCard.fromView(
                  item,
                  key: ValueKey('category-product-$index'),
                  onTap: () => openProduct(
                    context,
                    item,
                    businessId: widget.businessId,
                    onCart: widget.onCart,
                  ),
                  quantity: context
                      .watch<CartProvider>()
                      .getCatalogQuantity(item.source),
                  onIncrement: () => context
                      .read<CartProvider>()
                      .incrementCatalogItem(item.source),
                  onDecrement: () => context
                      .read<CartProvider>()
                      .decrementCatalogItem(item.source),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
