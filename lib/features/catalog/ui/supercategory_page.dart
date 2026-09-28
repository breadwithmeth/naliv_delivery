import 'package:flutter/material.dart';

import '../../../ui/app_states.dart';
import 'package:provider/provider.dart';

import '../../../core/product_view.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_top_bar.dart';
import '../../../ui/product_card.dart';
import '../../../utils/cart_provider.dart';
import '../catalog_data_source.dart';
import '../catalog_view_data.dart';
import 'category_products_page.dart';
import '../../product/product_navigation.dart';

/// A supercategory screen — the design's `Каталог` frame.
///
/// Structure measured from the frame: top bar at y = 70, a 27 px chip strip at y = 151, a 245 px
/// promo panel at y = 202, then one section per subcategory (header row plus a 3-up card grid),
/// each 24 px apart. The first subcategory is presented as the promo panel; the rest are grids.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _data = null;
    });
    try {
      final data = await CatalogDataSource(businessId: widget.businessId)
          .supercategory(widget.supercategoryId);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _openSubcategory(CategoryRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryProductsPage(
          categoryId: ref.id,
          title: ref.name,
          businessId: widget.businessId,
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
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: AppTopBar(
                    title: data?.name ?? widget.title ?? '',
                    onBack: () => Navigator.of(context).maybePop(),
                    onSearch: widget.onSearch,
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
                Expanded(child: _body(data)),
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
      return const Center(child: CircularProgressIndicator());
    }
    if (data.subcategories.isEmpty) {
      return const AppEmptyState(title: 'В этой категории пока нет товаров');
    }
    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: AppCartButton.clearance + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: data.subcategories.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: _ChipStrip(
              categories: data.subcategories,
              onTap: _openSubcategory,
            ),
          );
        }
        final ref = data.subcategories[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _Section(
            key: ValueKey(ref.id),
            category: ref,
            businessId: widget.businessId,
            // The first subcategory is the featured panel, as in the frame.
            featured: index == 1,
            onOpen: () => _openSubcategory(ref),
          ),
        );
      },
    );
  }
}

/// Horizontally scrolling jump-to strip: 29 px pills, 20 px side padding, selected one filled.
class _ChipStrip extends StatelessWidget {
  const _ChipStrip({required this.categories, this.onTap});

  final List<CategoryRef> categories;
  final ValueChanged<CategoryRef>? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      key: const ValueKey('catalog-chip-strip'),
      height: 29,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final ref = categories[index];
          return GestureDetector(
            onTap: onTap == null ? null : () => onTap!(ref),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color:
                    index == 0 ? palette.surface.withValues(alpha: 0.75) : null,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                ref.name.trim(),
                style: AppTypography.titleRegular
                    .copyWith(color: palette.textPrimary),
              ),
            ),
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
    super.key,
  });

  final CategoryRef category;
  final int businessId;
  final bool featured;
  final VoidCallback? onOpen;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  List<ProductView>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await CatalogDataSource(businessId: widget.businessId)
        .items(widget.category.id);
    if (!mounted) return;
    setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (widget.featured) {
      return _PromoPanel(
        title: widget.category.name.trim(),
        items: items ?? const [],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
          child: _SectionHeader(
              title: widget.category.name.trim(), onOpen: widget.onOpen),
        ),
        const SizedBox(height: 24),
        if (items == null)
          const SizedBox(
              height: 240, child: Center(child: CircularProgressIndicator()))
        else
          _Grid(items: items),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onOpen});

  final String title;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTypography.headline.copyWith(color: palette.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: onOpen,
            child: Container(
              width: 46,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                'Все',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The featured subcategory: a brand-red panel whose cards scroll horizontally.
///
/// The frame draws the panel wider than the screen (left gutter 16, running off the right edge),
/// with the title, subtitle and artwork pinned at its left and 110 × 213 cards scrolling past
/// them.
class _PromoPanel extends StatelessWidget {
  const _PromoPanel({required this.title, required this.items});

  final String title;
  final List<ProductView> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cart = context.watch<CartProvider>();
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xxxl),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadii.lg),
          bottomLeft: Radius.circular(AppRadii.lg),
        ),
        child: Container(
          key: const ValueKey('catalog-featured-panel'),
          height: 245,
          color: palette.brandRed,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: AppSpacing.xxxl),
            itemCount: items.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _PromoLead(title: title);
              }
              final item = items[index - 1];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                child: SizedBox(
                  key: ValueKey('catalog-featured-product-${index - 1}'),
                  width: 110,
                  child: ProductCard.fromView(
                    item,
                    dense: true,
                    quantity: cart.getCatalogQuantity(item.source),
                    onTap: () => openProduct(context, item),
                    onIncrement: () => context
                        .read<CartProvider>()
                        .incrementCatalogItem(item.source),
                    onDecrement: () => context
                        .read<CartProvider>()
                        .decrementCatalogItem(item.source),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Panel lead-in: 20/700 title, 10/400 subtitle and the category artwork behind them.
class _PromoLead extends StatelessWidget {
  const _PromoLead({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 154,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -8,
            top: 65,
            child: Image.asset(
              'assets/icons/design/catalog_aperitif_lead.png',
              width: 134,
              height: 172,
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            left: 16,
            top: 16,
            width: 131,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headline.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Начало идеального ужина',
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: AppTypography.label.copyWith(
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items});

  final List<ProductView> items;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xxxl,
        right: AppSpacing.xxxl + 1,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 110 / ProductCard.height,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return ProductCard.fromView(
            item,
            onTap: () => openProduct(context, item),
            quantity: cart.getCatalogQuantity(item.source),
            onIncrement: () =>
                context.read<CartProvider>().incrementCatalogItem(item.source),
            onDecrement: () =>
                context.read<CartProvider>().decrementCatalogItem(item.source),
          );
        },
      ),
    );
  }
}
