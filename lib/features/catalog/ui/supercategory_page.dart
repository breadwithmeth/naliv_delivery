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
import '../../../ui/surfaces.dart';
import '../../../utils/cart_provider.dart';
import '../../product/product_navigation.dart';
import '../catalog_data_source.dart';
import '../catalog_view_data.dart';
import 'category_products_page.dart';
import 'category_switcher.dart';

/// A supercategory with one navigable header and a compact preview per category.
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
  final _scroll = ScrollController();
  final _previews = <int, (List<ProductView>, bool)>{};
  SupercategoryView? _data;
  bool _failed = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _previews.clear();
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
    final preview = _previews[ref.id];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryProductsPage(
          categoryId: ref.id,
          title: ref.label,
          businessId: widget.businessId,
          categories: _data?.leaves ?? const [],
          initialItems: initialItems ?? preview?.$1,
          initialHasMore: initialHasMore ?? preview?.$2,
          onSearch: widget.onSearch,
          onCart: widget.onCart,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
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
                  title: data?.name ?? widget.title ?? 'Каталог',
                  onBack: () => Navigator.of(context).maybePop(),
                  onSearch: widget.onSearch,
                ),
              ),
              const SizedBox(height: AppSpacing.huge),
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

  Widget _body(SupercategoryView? data) {
    Widget? state;
    if (_failed) {
      state = AppErrorState(
        message: 'Не удалось загрузить категорию',
        onRetry: _load,
      );
    } else if (data == null) {
      state = _loaded
          ? const AppEmptyState(title: 'В этой категории пока нет товаров')
          : const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
    } else if (data.leaves.isEmpty) {
      state = const AppEmptyState(title: 'В этой категории пока нет товаров');
    }
    return ListView.builder(
      key: const ValueKey('catalog-overview'),
      controller: _scroll,
      padding: EdgeInsets.only(
        bottom: AppCartButton.clearanceFor(context) +
            MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: state == null ? data!.leaves.length + 1 : 1,
      itemBuilder: (context, index) {
        if (state != null) return state;
        final loaded = data!;
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CategorySwitcher(
                  categories: loaded.leaves,
                  selectedCategoryId: loaded.leaves.first.id,
                  selectedLabel: loaded.leaves.first.label,
                  onCategory: _openSubcategory,
                  onOverview: () => _scroll.animateTo(
                    0,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                  ),
                ),
                if (loaded.description?.isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    loaded.description!,
                    style: AppTypography.bodySmall
                        .copyWith(color: context.palette.textSecondary),
                  ),
                ],
              ],
            ),
          );
        }
        final ref = loaded.leaves[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.huge),
          child: _Section(
            key: ValueKey(ref.id),
            category: ref,
            businessId: widget.businessId,
            featured: index == 1,
            initialPreview: _previews[ref.id],
            onLoaded: (items, hasMore) => _previews[ref.id] = (items, hasMore),
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

class _Section extends StatefulWidget {
  const _Section({
    required this.category,
    required this.businessId,
    this.featured = false,
    this.initialPreview,
    this.onLoaded,
    this.onOpen,
    this.onCart,
    super.key,
  });

  final CategoryRef category;
  final int businessId;
  final bool featured;
  final (List<ProductView>, bool)? initialPreview;
  final void Function(List<ProductView>, bool)? onLoaded;
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
    final preview = widget.initialPreview;
    if (preview == null) {
      _load();
    } else {
      _items = preview.$1;
      _hasMore = preview.$2;
    }
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
      widget.onLoaded?.call(result.items, result.hasMore);
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
    final Widget content;
    if (_failed) {
      content = AppErrorState(
        message: 'Не удалось загрузить товары',
        onRetry: _load,
      );
    } else if (items == null) {
      content = const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (items.isEmpty) {
      content = const AppEmptyState(title: 'В этой категории пока нет товаров');
    } else if (widget.featured) {
      return _FeaturedPanel(
        category: widget.category,
        items: items,
        cardBuilder: _card,
        onOpen: open,
      );
    } else {
      content = _Grid(items: items, onProductTap: _openProduct);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: _SectionHeader(
            key: ValueKey('catalog-open-${widget.category.id}'),
            title: widget.category.label,
            onOpen: open,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        content,
      ],
    );
  }

  Widget _card(ProductView item) => Selector<CartProvider, double>(
        selector: (_, cart) => cart.getCatalogQuantityForKey(item.catalogKey),
        builder: (context, quantity, _) => ProductCard.fromView(
          item,
          onTap: () => _openProduct(item),
          quantity: quantity,
          onIncrement: () =>
              context.read<CartProvider>().incrementCatalogItem(item.source),
          onDecrement: () =>
              context.read<CartProvider>().decrementCatalogItem(item.source),
        ),
      );
}

/// The featured category: a red panel with the category title row on top, then one
/// horizontal row of equal-height product cards ending in a "see all" card.
///
/// The panel spans the page gutters, so a category with a single product (or none of the
/// optional artwork) is still filled by the title, the subtitle and the card row. The
/// category artwork is decoration: it joins the card row at the left when the text scale
/// leaves room and vanishes without a trace when it is missing or fails to load.
class _FeaturedPanel extends StatelessWidget {
  const _FeaturedPanel({
    required this.category,
    required this.items,
    required this.cardBuilder,
    this.onOpen,
  });

  final CategoryRef category;
  final List<ProductView> items;
  final Widget Function(ProductView item) cardBuilder;
  final VoidCallback? onOpen;

  static const double _inset = AppSpacing.xxxl;
  static const double _maxArtWidth = 120;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final flags = ProductCardLayout.flagsOf(items);
    final cardWidth = ProductCard.widthFor(context);
    final extent = ProductCard.extentFor(
      context,
      cardWidth,
      hasOldPrice: flags.hasOldPrice,
      hasSaving: flags.hasSaving,
    );
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final showArt = category.imageUrl?.isNotEmpty == true && scale <= 1.3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: ProductCardLayout(
        hasOldPrice: flags.hasOldPrice,
        hasSaving: flags.hasSaving,
        child: AppSurface(
          fill: palette.brandRed,
          radius: AppRadii.xxl,
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _inset,
                  AppSpacing.md,
                  _inset,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: ValueKey('catalog-open-${category.id}'),
                        onPressed: onOpen,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          minimumSize: const Size(
                            AppSpacing.touchTarget,
                            AppSpacing.touchTarget,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                category.label,
                                style: AppTypography.headline
                                    .copyWith(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            const Icon(Icons.arrow_circle_right, size: 22),
                          ],
                        ),
                      ),
                    ),
                    if (category.description?.isNotEmpty == true)
                      Text(
                        category.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall
                            .copyWith(color: Colors.white),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                height: extent,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: _inset),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showArt) ...[
                        SizedBox(
                          width: _maxArtWidth,
                          height: extent,
                          child: ClipRRect(
                            borderRadius: AppRadii.lgAll,
                            child: Image.network(
                              category.imageUrl!,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      for (final item in items) ...[
                        SizedBox(
                          width: cardWidth,
                          height: extent,
                          child: cardBuilder(item),
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      SizedBox(
                        width: cardWidth * .85,
                        height: extent,
                        child: _SeeAllCard(onTap: onOpen),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: _inset),
            ],
          ),
        ),
      ),
    );
  }
}

/// The trailing card of the featured row: same height as the products, translucent white,
/// opening the category's full list.
class _SeeAllCard extends StatelessWidget {
  const _SeeAllCard({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: AppRadii.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_circle_right,
                      size: 28, color: Colors.white),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Все товары',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.base(size: 14, weight: 600)
                        .copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.onOpen,
    super.key,
  });

  final String title;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onOpen,
        style: TextButton.styleFrom(
          foregroundColor: context.palette.textPrimary,
          padding: EdgeInsets.zero,
          minimumSize:
              const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTypography.headline
                    .copyWith(color: context.palette.textPrimary),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppSurface(
              radius: AppRadii.pill,
              fill: context.palette.accent,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                'Все',
                style: AppTypography.bodySmall
                    .copyWith(color: context.palette.textOnAccent),
              ),
            ),
          ],
        ),
      );
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items, required this.onProductTap});

  final List<ProductView> items;
  final ValueChanged<ProductView> onProductTap;
  @override
  Widget build(BuildContext context) {
    return ProductGrid(
      products: items,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      maxRows: 2,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Selector<CartProvider, double>(
          selector: (_, cart) => cart.getCatalogQuantityForKey(item.catalogKey),
          builder: (context, quantity, _) => ProductCard.fromView(
            item,
            onTap: () => onProductTap(item),
            quantity: quantity,
            onIncrement: () =>
                context.read<CartProvider>().incrementCatalogItem(item.source),
            onDecrement: () =>
                context.read<CartProvider>().decrementCatalogItem(item.source),
          ),
        );
      },
    );
  }
}
