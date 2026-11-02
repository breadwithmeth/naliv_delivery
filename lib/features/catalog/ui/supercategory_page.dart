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
import 'category_products_page.dart';

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
                  title: 'Каталог',
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
      padding: EdgeInsets.only(
        bottom: AppCartButton.clearanceFor(context) +
            MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: 1 + (state == null ? data!.leaves.length : 1),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.md,
              AppSpacing.gutter,
              AppSpacing.huge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  data?.name ?? widget.title ?? 'Каталог',
                  style: AppTypography.displayBold
                      .copyWith(color: context.palette.textPrimary),
                ),
                if (data?.description?.isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    data!.description!,
                    style: AppTypography.bodySmall
                        .copyWith(color: context.palette.textSecondary),
                  ),
                ],
              ],
            ),
          );
        }
        if (state != null) return state;
        final ref = data!.leaves[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.huge),
          child: _Section(
            key: ValueKey(ref.id),
            category: ref,
            businessId: widget.businessId,
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
    this.onOpen,
    this.onCart,
    super.key,
  });

  final CategoryRef category;
  final int businessId;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: _SectionHeader(
            key: ValueKey('catalog-open-${widget.category.id}'),
            title: widget.category.label,
            description: widget.category.description,
            onOpen: open,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_failed)
          AppErrorState(
            message: 'Не удалось загрузить товары',
            onRetry: _load,
          )
        else if (items == null)
          const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          const AppEmptyState(title: 'В этой категории пока нет товаров')
        else
          _Grid(items: items, onProductTap: _openProduct),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.description,
    this.onOpen,
    super.key,
  });

  final String title;
  final String? description;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onOpen,
        style: TextButton.styleFrom(
          foregroundColor: context.palette.textPrimary,
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.zero,
          minimumSize:
              const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.headline),
                  if (description?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description!,
                      style: AppTypography.bodySmall
                          .copyWith(color: context.palette.textSecondary),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Все товары',
                    style: AppTypography.label
                        .copyWith(color: context.palette.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(Icons.chevron_right, color: context.palette.accent),
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
