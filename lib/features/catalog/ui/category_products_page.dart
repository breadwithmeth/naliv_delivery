import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/product_view.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_states.dart';
import '../../../ui/app_top_bar.dart';
import '../../../ui/liquid_glass_dock.dart';
import '../../../ui/product_card.dart';
import '../../../ui/product_grid.dart';
import '../../../utils/cart_provider.dart';
import '../../product/product_navigation.dart';
import '../catalog_data_source.dart';

import '../catalog_view_data.dart';
import 'category_switcher.dart';

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
    this.categories = const [],
    this.onCart,
    super.key,
  });

  final int categoryId;
  final String title;
  final int businessId;
  final List<CategoryRef> categories;

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

  void _openCategory(CategoryRef category) {
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) => CategoryProductsPage(
          categoryId: category.id,
          title: category.label,
          businessId: widget.businessId,
          categories: widget.categories,
          onSearch: widget.onSearch,
          onCart: widget.onCart,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LiquidGlassDock(
          content: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                child: AppTopBar(
                  title: 'Товары',
                  onBack: () => Navigator.of(context).maybePop(),
                  onSearch: widget.onSearch,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(child: _body()),
            ],
          ),
          dock: Selector<CartProvider, (int, double?)>(
            selector: (_, cart) => (
              cart.displayItemCount,
              cart.displayItemCount == 0 ? null : cart.getTotalPrice(),
            ),
            builder: (_, summary, __) => AppCartButton(
              itemCount: summary.$1,
              total: summary.$2,
              onTap: widget.onCart,
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final items = _items;
    var selectedLabel = widget.title;
    for (final category in widget.categories) {
      if (category.id == widget.categoryId) {
        selectedLabel = category.label;
        break;
      }
    }
    Widget? footer;
    if (_failed) {
      footer = AppErrorState(
        message: 'Не удалось загрузить товары',
        onRetry: _load,
      );
    } else if (items == null) {
      footer = const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (items.isEmpty && !_hasMore) {
      footer = const AppEmptyState(title: 'В этой категории пока нет товаров');
    } else if (_hasMore) {
      footer = Center(
        child: _loadingMore
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.huge),
                child: CircularProgressIndicator(),
              )
            : TextButton(
                onPressed: _loadMore,
                style: TextButton.styleFrom(
                  minimumSize: const Size(
                      AppSpacing.touchTarget, AppSpacing.touchTarget),
                ),
                child: Text(
                  _moreFailed ? 'Повторить загрузку' : 'Показать ещё',
                ),
              ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: ProductGrid(
          key: const ValueKey('category-products-grid'),
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppCartButton.clearanceFor(context) +
                MediaQuery.paddingOf(context).bottom,
          ),
          header: widget.categories.isEmpty
              ? Text(
                  selectedLabel,
                  style: AppTypography.displayBold
                      .copyWith(color: context.palette.textPrimary),
                )
              : CategorySwitcher(
                  categories: widget.categories,
                  selectedCategoryId: widget.categoryId,
                  selectedLabel: selectedLabel,
                  onCategory: _openCategory,
                  onOverview: () => Navigator.of(context).maybePop(),
                ),
          footer: footer,
          itemCount: items?.length ?? 0,
          itemBuilder: (context, index) {
            final item = items![index];
            return Selector<CartProvider, double>(
              selector: (_, cart) =>
                  cart.getCatalogQuantityForKey(item.catalogKey),
              builder: (context, quantity, _) => ProductCard.fromView(
                item,
                key: ValueKey('category-product-$index'),
                onTap: () => openProduct(
                  context,
                  item,
                  businessId: widget.businessId,
                  onCart: widget.onCart,
                ),
                quantity: quantity,
                onIncrement: () => context
                    .read<CartProvider>()
                    .incrementCatalogItem(item.source),
                onDecrement: () => context
                    .read<CartProvider>()
                    .decrementCatalogItem(item.source),
              ),
            );
          },
        ),
      ),
    );
  }
}
