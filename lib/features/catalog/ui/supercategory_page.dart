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
import '../../../ui/surfaces.dart';
import '../../../utils/cart_provider.dart';
import '../../product/product_navigation.dart';
import '../catalog_data_source.dart';
import '../catalog_view_data.dart';
import 'category_products_page.dart';
import 'category_strip.dart';

/// A supercategory with navigable category sections and a featured product rail.
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
          title: ref.label,
          businessId: widget.businessId,
          categories: _data?.leaves ?? const [],
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
                  total: count == 0 ? null : cart.getTotalPrice(),
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
    if (data.leaves.isEmpty) {
      return const AppEmptyState(title: 'В этой категории пока нет товаров');
    }
    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: AppCartButton.clearanceFor(context) +
            MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: data.leaves.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            child: CategoryStrip(
              categories: data.leaves,
              onCategory: _openSubcategory,
            ),
          );
        }
        final ref = data.leaves[index - 1];
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: _SectionHeader(
              title: widget.category.label,
              onOpen: open,
            ),
          ),
          AppErrorState(
            message: 'Не удалось загрузить товары',
            onRetry: _load,
          ),
        ],
      );
    }
    if (widget.featured) {
      return _PromoPanel(
        category: widget.category,
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
          child: _SectionHeader(title: widget.category.label, onOpen: open),
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
          AppGlassChip(label: 'Все', onTap: onOpen),
        ],
      );
}

class _PromoPanel extends StatelessWidget {
  const _PromoPanel({
    required this.category,
    required this.items,
    required this.onProductTap,
    this.onOpen,
  });

  final CategoryRef category;
  final List<ProductView>? items;
  final ValueChanged<ProductView> onProductTap;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cart = context.watch<CartProvider>();
    final products = items;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.gutter),
      child: AppSurface(
        key: const ValueKey('catalog-featured-panel'),
        fill: palette.brandRed,
        padding: const EdgeInsets.all(AppSpacing.xl),
        clip: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final cardWidth =
                106.0 + (scale - 1).clamp(0, double.infinity) * 100;
            final artUrl = category.imageUrl ??
                (products?.isNotEmpty == true ? products!.first.imageUrl : null);
            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                  onPressed: onOpen,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                    minimumSize:
                        const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.label,
                          style: AppTypography.headline.copyWith(color: Colors.white),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                ),
                if (category.description?.isNotEmpty == true)
                  Text(
                    category.description!,
                    style: AppTypography.label.copyWith(color: Colors.white),
                  ),
                if (artUrl?.isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.md),
                  AspectRatio(
                    aspectRatio: .8,
                    child: Image.network(
                      artUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],
            );
            final rail = products == null
                ? const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                : products.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          'В этой категории пока нет товаров',
                          style: AppTypography.bodySmall.copyWith(color: Colors.white),
                        ),
                      )
                    : SizedBox(
                        height: ProductCard.heightFor(
                          context,
                          width: cardWidth,
                          products: products,
                        ),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: products.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: AppSpacing.md),
                          itemBuilder: (context, index) {
                            final item = products[index];
                            return SizedBox(
                              width: cardWidth,
                              child: ProductCard.fromView(
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
                              ),
                            );
                          },
                        ),
                      );
            if (constraints.maxWidth < 300 || scale > 1.35) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: heading),
                      TextButton(
                        onPressed: onOpen,
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        child: const Text('Все'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  rail,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: constraints.maxWidth * .42, child: heading),
                const SizedBox(width: AppSpacing.xl),
                Expanded(child: rail),
              ],
            );
          },
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
          final cardWidth =
              (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: AppSpacing.xl,
              crossAxisSpacing: AppSpacing.md,
              mainAxisExtent: ProductCard.heightFor(
                context,
                width: cardWidth,
                products: items.take(previewCount),
              ),
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
