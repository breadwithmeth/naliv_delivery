import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/product_view.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_states.dart';
import '../../../ui/app_top_bar.dart';
import '../../../ui/product_card.dart';
import '../../../utils/cart_provider.dart';
import '../../product/product_navigation.dart';
import '../catalog_data_source.dart';
import '../catalog_view_data.dart';
import 'category_products_page.dart';

/// A supercategory screen — the design's `Каталог` frame.
///
/// Structure measured from the frame: top bar, category chips, a 245 px promo panel, then
/// subcategory sections (header plus a 3-up card grid at 375 px), each 24 px apart.
/// The first subcategory is presented as the promo panel; the rest are grids.
///
/// Only visible sections load: the list is a `ListView.builder`, so a subcategory's items are
/// fetched when its section is first built rather than on page open.
class SupercategoryPage extends StatefulWidget {
  const SupercategoryPage({
    required this.supercategoryId,
    required this.businessId,
    this.title,
    this.onSearch,
    this.onCart,
    super.key,
  });

  final int supercategoryId;
  final int businessId;

  /// Title to show immediately, before the API answers.
  final String? title;

  final VoidCallback? onSearch;

  /// Opens the cart.
  final VoidCallback? onCart;

  @override
  State<SupercategoryPage> createState() => _SupercategoryPageState();
}

class _SupercategoryPageState extends State<SupercategoryPage> {
  SupercategoryView? _data;
  bool _failed = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _data = null;
      _loaded = false;
    });
    try {
      final data = await CatalogDataSource(businessId: widget.businessId)
          .supercategory(widget.supercategoryId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _openSubcategory(
    CategoryRef ref, {
    List<ProductView>? initialItems,
    bool? initialHasMore,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryProductsPage(
          categoryId: ref.id,
          title: ref.name,
          businessId: widget.businessId,
          initialItems: initialItems,
          initialHasMore: initialHasMore,
          onSearch: widget.onSearch,
          onCart: widget.onCart,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final count = cart.displayItemCount;
    final data = _data;
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
                    title: data?.name ?? widget.title ?? '',
                    onBack: () => Navigator.of(context).maybePop(),
                    onSearch: widget.onSearch,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 840),
                      child: _body(data),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
              child: Center(
                child: AppCartButton(
                  itemCount: count,
                  total: count == 0 ? null : cart.getTotalPrice().round(),
                  onTap: widget.onCart,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(SupercategoryView? data) {
    if (_failed) {
      return AppErrorState(
        message: 'Не удалось загрузить категорию',
        onRetry: _load,
      );
    }
    if (data == null) {
      return _loaded
          ? const AppEmptyState(title: 'В этой категории пока нет товаров')
          : const Center(child: CircularProgressIndicator());
    }
    if (data.subcategories.isEmpty) {
      return const AppEmptyState(title: 'В этой категории пока нет товаров');
    }
    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: AppCartButton.clearanceFor(context) +
            MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: data.subcategories.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            child: _ChipStrip(
              categories: data.subcategories,
              onTap: _openSubcategory,
            ),
          );
        }
        final ref = data.subcategories[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.huge),
          child: _Section(
            key: ValueKey(ref.id),
            category: ref,
            businessId: widget.businessId,
            // The first subcategory is the featured panel, as in the frame.
            featured: index == 1,
            onOpen: (items, hasMore) => _openSubcategory(
              ref,
              initialItems: items,
              initialHasMore: hasMore,
            ),
            onCart: widget.onCart,
          ),
        );
      },
    );
  }
}

class _ChipStrip extends StatelessWidget {
  const _ChipStrip({required this.categories, this.onTap});

  final List<CategoryRef> categories;
  final ValueChanged<CategoryRef>? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      key: const ValueKey('catalog-chip-strip'),
      height: AppSpacing.touchTarget +
          (MediaQuery.textScalerOf(context).scale(14) - 14)
                  .clamp(0, double.infinity) *
              1.3,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final ref = categories[index];
          return TextButton(
            onPressed: onTap == null ? null : () => onTap!(ref),
            style: TextButton.styleFrom(
              foregroundColor: palette.textPrimary,
              backgroundColor:
                  index == 0 ? palette.surface : palette.surfaceMuted,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
              shape:
                  const RoundedRectangleBorder(borderRadius: AppRadii.pillAll),
            ),
            child: Text(ref.name.trim(), style: AppTypography.bodySmallMedium),
          );
        },
      ),
    );
  }
}

/// One subcategory: a promo panel for the featured one, otherwise a header plus a 3-up grid.
class _Section extends StatefulWidget {
  const _Section({
    required this.category,
    required this.businessId,
    required this.featured,
    this.onOpen,
    this.onCart,
    super.key,
  });

  final CategoryRef category;
  final int businessId;
  final bool featured;
  final void Function(List<ProductView>?, bool?)? onOpen;
  final VoidCallback? onCart;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  List<ProductView>? _items;
  bool? _hasMore;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _items = null;
    });
    try {
      final result = await CatalogDataSource(businessId: widget.businessId)
          .itemsPage(widget.category.id);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _hasMore = result.hasMore;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _openProduct(ProductView item) {
    openProduct(
      context,
      item,
      businessId: widget.businessId,
      onCart: widget.onCart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final open =
        widget.onOpen == null ? null : () => widget.onOpen!(items, _hasMore);
    if (_failed) {
      return AppErrorState(
        message: 'Не удалось загрузить товары',
        onRetry: _load,
      );
    }
    if (widget.featured) {
      return _PromoPanel(
        title: widget.category.name.trim(),
        items: items,
        onOpen: open,
        onProductTap: _openProduct,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child:
              _SectionHeader(title: widget.category.name.trim(), onOpen: open),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (items == null)
          const SizedBox(
              height: 240, child: Center(child: CircularProgressIndicator()))
        else if (items.isEmpty)
          const AppEmptyState(title: 'В этой категории пока нет товаров')
        else
          _Grid(items: items, onProductTap: _openProduct),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onOpen});

  final String title;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
              child: Text(title,
                  style: AppTypography.headline
                      .copyWith(color: context.palette.textPrimary))),
          TextButton(onPressed: onOpen, child: const Text('Все')),
        ],
      );
}

class _PromoPanel extends StatelessWidget {
  const _PromoPanel({
    required this.title,
    required this.items,
    required this.onProductTap,
    this.onOpen,
  });

  final String title;
  final List<ProductView>? items;
  final ValueChanged<ProductView> onProductTap;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cart = context.watch<CartProvider>();
    final products = items;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Container(
        key: const ValueKey('catalog-featured-panel'),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: palette.brandRed,
          borderRadius: AppRadii.lgAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onOpen,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(title,
                        style: AppTypography.headline
                            .copyWith(color: Colors.white)),
                  ),
                ),
                TextButton(
                  onPressed: onOpen,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Все'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (products == null)
              const SizedBox(
                height: 96,
                child: Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              )
            else if (products.isEmpty)
              Text('В этой категории пока нет товаров',
                  style: AppTypography.bodySmall.copyWith(color: Colors.white))
            else
              SizedBox(
                height: ProductCard.heightFor(context,
                    hasOldPrice: products.any((item) => item.oldPrice != null)),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: products.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final item = products[index];
                    return ProductCard.fromView(
                      item,
                      key: ValueKey('catalog-featured-product-$index'),
                      quantity: cart.getCatalogQuantity(item.source),
                      onTap: () => onProductTap(item),
                      onIncrement: () => context
                          .read<CartProvider>()
                          .incrementCatalogItem(item.source),
                      onDecrement: () => context
                          .read<CartProvider>()
                          .decrementCatalogItem(item.source),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items, required this.onProductTap});

  final List<ProductView> items;
  final ValueChanged<ProductView> onProductTap;
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = ProductCard.columnsFor(context, constraints.maxWidth);
          final previewCount = items.length.clamp(0, columns * 2);
          var hasOldPrice = false;
          for (var index = 0; index < previewCount; index++) {
            if (items[index].oldPrice != null) {
              hasOldPrice = true;
              break;
            }
          }
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: AppSpacing.xl,
              crossAxisSpacing: AppSpacing.md,
              mainAxisExtent:
                  ProductCard.heightFor(context, hasOldPrice: hasOldPrice),
            ),
            itemCount: previewCount,
            itemBuilder: (context, index) {
              final item = items[index];
              return ProductCard.fromView(
                item,
                onTap: () => onProductTap(item),
                quantity: cart.getCatalogQuantity(item.source),
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
    );
  }
}
