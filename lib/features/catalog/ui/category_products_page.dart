import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/product_view.dart';
import '../../../design/tokens.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_states.dart';
import '../../../ui/app_top_bar.dart';
import '../../../ui/frosted_dock.dart';
import '../../../ui/frosted_surface.dart';
import '../../../ui/product_card.dart';
import '../../../ui/product_grid.dart';
import '../../../utils/cart_provider.dart';
import '../../product/product_navigation.dart';
import '../catalog_data_source.dart';
import '../catalog_view_data.dart';
import 'category_switcher.dart';

/// The products of a parent category or of one of its children, with scroll-driven pagination.
///
/// [group] is the parent whose children are the filter chips. Opened for the parent the page
/// reads «Вино» with chips «Все · Аперитив · Белое …»; opened for a child it reads «Белое»
/// with the parent as context and the same chips, the child selected. Switching chips swaps
/// the grid in place and remembers every list already loaded, so going back never refetches.
///
/// Columns adapt to viewport width and inherited text scaling. The floating cart button carries
/// the running total without a persistent navigation bar.
class CategoryProductsPage extends StatefulWidget {
  const CategoryProductsPage({
    required this.categoryId,
    required this.title,
    required this.businessId,
    this.group,
    this.initialItems,
    this.initialHasMore,
    this.onSearch,
    this.onCart,
    super.key,
  });

  /// The category shown first: [group] itself, or one of its children.
  final int categoryId;

  /// Used while [categoryId] cannot be found in [group].
  final String title;
  final int businessId;

  /// The parent category; its children are the filter chips. Null shows a plain list.
  final CategoryRef? group;

  /// Items already fetched by a parent screen for [categoryId], so opening a section does not
  /// refetch.
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

/// The paginated list of one category.
class _Feed {
  List<ProductView>? items;
  bool failed = false;
  bool loadingMore = false;
  bool moreFailed = false;
  bool hasMore = false;
  int page = 1;
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  final _scroll = ScrollController();
  final _feeds = <int, _Feed>{};
  late int _selectedId;

  _Feed get _feed => _feeds[_selectedId]!;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.categoryId;
    final feed = _feeds[_selectedId] = _Feed();
    final initial = widget.initialItems;
    if (initial != null) {
      feed
        ..items = initial
        ..hasMore = widget.initialHasMore ?? false
        ..page = 2;
    }
    _scroll.addListener(_onScroll);
    if (initial == null) {
      _load(_selectedId);
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
    final feed = _feeds[_selectedId];
    if (feed != null &&
        feed.hasMore &&
        !feed.loadingMore &&
        !feed.moreFailed &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _loadMore(_selectedId);
    }
  }

  void _checkForMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final feed = _feeds[_selectedId];
      if (!mounted ||
          !_scroll.hasClients ||
          feed == null ||
          !feed.hasMore ||
          feed.moreFailed) {
        return;
      }
      _onScroll();
    });
  }

  Future<void> _load(int id) async {
    final feed = _feeds.putIfAbsent(id, _Feed.new);
    setState(() {
      feed
        ..failed = false
        ..items = null
        ..hasMore = false
        ..page = 1;
    });
    try {
      final result =
          await CatalogDataSource(businessId: widget.businessId).itemsPage(id);
      if (!mounted) return;
      setState(() {
        feed
          ..items = result.items
          ..hasMore = result.hasMore
          ..page = 2;
      });
      if (id == _selectedId) _checkForMore();
    } catch (_) {
      if (!mounted) return;
      setState(() => feed.failed = true);
    }
  }

  Future<void> _loadMore(int id) async {
    final feed = _feeds[id];
    if (feed == null || feed.loadingMore || !feed.hasMore) return;
    setState(() {
      feed
        ..loadingMore = true
        ..moreFailed = false;
    });
    try {
      final result = await CatalogDataSource(businessId: widget.businessId)
          .itemsPage(id, page: feed.page);
      if (!mounted) return;
      setState(() {
        feed
          ..items = [...?feed.items, ...result.items]
          ..hasMore = result.hasMore
          ..page += 1
          ..loadingMore = false;
      });
      if (id == _selectedId) _checkForMore();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        feed
          ..loadingMore = false
          ..moreFailed = true;
      });
    }
  }

  void _select(CategoryChipItem chip) {
    if (chip.id == _selectedId) return;
    setState(() => _selectedId = chip.id);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    final feed = _feeds[chip.id];
    if (feed == null) {
      _load(chip.id);
    } else {
      _checkForMore();
    }
  }

  /// The group's own entry, or one of its children, for the selected id.
  CategoryRef? get _selectedRef {
    final group = widget.group;
    if (group == null) return null;
    if (group.id == _selectedId) return group;
    for (final child in group.children) {
      if (child.id == _selectedId) return child;
    }
    return null;
  }

  String get _title => _selectedRef?.name ?? widget.title;

  /// A child reads under its parent; the parent itself under the supercategory.
  String? get _subtitle {
    final group = widget.group;
    final selected = _selectedRef;
    if (group == null || selected == null) return null;
    return selected.id == group.id ? group.parentName : group.name;
  }

  List<CategoryChipItem> get _chips {
    final group = widget.group;
    if (group == null || !group.hasChildren) return const [];
    return [
      CategoryChipItem(
        id: group.id,
        label: 'Все',
        semanticLabel: 'Все: ${group.name}',
      ),
      for (final child in group.children) CategoryChipItem.fromCategory(child),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final chips = _chips;
    return Scaffold(
      body: FrostedDock(
        content: FrostedHeaderLayout(
          // Top bar (79) + gap + chip row (44) + bottom gap.
          estimatedHeaderHeight:
              chips.isEmpty ? 79 : 79 + AppSpacing.md + 44 + AppSpacing.xl,
          header: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                child: AppTopBar(
                  title: _title,
                  subtitle: _subtitle,
                  onBack: () => Navigator.of(context).maybePop(),
                  onSearch: widget.onSearch,
                ),
              ),
              if (chips.isNotEmpty)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 840),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.md,
                        bottom: AppSpacing.xl,
                      ),
                      child: CategoryChipRow(
                        key: const ValueKey('category-chips'),
                        items: chips,
                        selectedId: _selectedId,
                        onSelected: _select,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: (context, topInset) => _body(topInset, chips.isNotEmpty),
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
    );
  }

  Widget _body(double topInset, bool hasChips) {
    final id = _selectedId;
    final feed = _feed;
    final items = feed.items;
    Widget? footer;
    if (feed.failed) {
      footer = AppErrorState(
        message: 'Не удалось загрузить товары',
        onRetry: () => _load(id),
      );
    } else if (items == null) {
      footer = const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (items.isEmpty && !feed.hasMore) {
      footer = const AppEmptyState(title: 'В этой категории пока нет товаров');
    } else if (feed.hasMore) {
      footer = Center(
        child: feed.loadingMore
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.huge),
                child: CircularProgressIndicator(),
              )
            : TextButton(
                onPressed: () => _loadMore(id),
                style: TextButton.styleFrom(
                  minimumSize: const Size(
                      AppSpacing.touchTarget, AppSpacing.touchTarget),
                ),
                child: Text(
                  feed.moreFailed ? 'Повторить загрузку' : 'Показать ещё',
                ),
              ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: ProductGrid(
          key: const ValueKey('category-products-grid'),
          products: items,
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            topInset + (hasChips ? 0 : AppSpacing.huge),
            AppSpacing.gutter,
            AppCartButton.clearanceFor(context) +
                MediaQuery.paddingOf(context).bottom,
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
