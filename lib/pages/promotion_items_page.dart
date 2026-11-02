import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/like_action.dart';
import '../core/product_view.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../features/cart/ui/cart_page.dart';
import '../features/product/product_navigation.dart';
import '../model/item.dart' as item_model;
import '../ui/app_cart_button.dart';
import '../ui/app_icon.dart';
import '../ui/app_icon_button.dart';
import '../ui/app_states.dart';
import '../ui/app_top_bar.dart';
import '../ui/liquid_glass_dock.dart';
import '../ui/product_card.dart';
import '../ui/product_grid.dart';
import '../utils/api.dart';
import '../utils/cart_provider.dart';
import '../utils/liked_items_provider.dart';
import 'checkout_page.dart';

/// Страница с товарами конкретной акции
class PromotionItemsPage extends StatefulWidget {
  final int promotionId;
  final String? promotionName;
  final int businessId;
  final List<item_model.Item>? initialItems;
  final VoidCallback? onCart;

  const PromotionItemsPage({
    super.key,
    required this.promotionId,
    this.promotionName,
    required this.businessId,
    this.initialItems,
    this.onCart,
  });

  @override
  State<PromotionItemsPage> createState() => _PromotionItemsPageState();
}

class _PromotionItemsPageState extends State<PromotionItemsPage> {
  List<ProductView>? _items;
  String? _terms;
  bool _isLoading = false;
  bool _failed = false;
  int _loadGeneration = 0;
  final _liking = <(int, int)>{};

  String get _title {
    final name = widget.promotionName?.trim();
    return name == null || name.isEmpty ? 'Товары акции' : name;
  }

  @override
  void initState() {
    super.initState();
    _useInitialItemsOrLoad();
  }

  @override
  void didUpdateWidget(covariant PromotionItemsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId ||
        oldWidget.promotionId != widget.promotionId ||
        !identical(oldWidget.initialItems, widget.initialItems)) {
      _loadGeneration++;
      _failed = false;
      _isLoading = false;
      _items = null;
      _terms = null;
      _useInitialItemsOrLoad();
    }
  }

  void _useInitialItemsOrLoad() {
    final initial = widget.initialItems;
    if (initial != null) {
      // A supplied list is complete. Keep its models, order and missing fields intact.
      _items = initial.map(ProductView.fromItem).toList(growable: false);
      _terms = _itemTerms(_items!);
    } else {
      _loadItems();
    }
  }

  String? _itemTerms(List<ProductView> items) {
    final terms = <String>{};
    for (final item in items) {
      if (item.promo != null) terms.add(item.promo!);
      if (item.discount != null) terms.add(item.discount!);
    }
    return terms.isEmpty
        ? null
        : 'Условия отдельных товаров: ${terms.join(' · ')}';
  }

  Future<void> _loadItems() async {
    final generation = ++_loadGeneration;
    final promotionId = widget.promotionId;
    final businessId = widget.businessId;
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final items = <ProductView>[];
      var page = 1;
      var totalPages = 1;
      do {
        final response = await ApiService.getPromotionItems(
          promotionId: promotionId,
          businessId: businessId,
          page: page,
          limit: 50,
        );
        if (!mounted || generation != _loadGeneration) return;
        final data = response?['data'];
        if (data is! Map || data['items'] is! List) {
          throw StateError('Invalid promotion items response');
        }
        for (final raw in data['items'] as List) {
          if (raw is! Map) {
            throw StateError('Invalid promotion item');
          }
          final item = item_model.Item.fromJson(
            Map<String, dynamic>.from(raw),
          );
          if (_isSellablePromotionItem(item)) {
            items.add(ProductView.fromItem(item));
          }
        }
        final pagination = data['pagination'];
        if (pagination is Map) {
          final rawPages =
              pagination['totalPages'] ?? pagination['total_pages'];
          final pages = rawPages is num
              ? rawPages.toInt()
              : int.tryParse('${rawPages ?? ''}');
          totalPages = pages != null && pages > 0 ? pages : page;
        } else {
          totalPages = page;
        }
        page++;
      } while (page <= totalPages);
      setState(() {
        _items = items;
        _terms = _itemTerms(items);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _failed = true;
        _isLoading = false;
      });
    }
  }

  bool _isSellablePromotionItem(item_model.Item item) {
    final hasStock = (item.amount ?? 0) > 0;
    final visible = item.visible == null || item.visible == 1;
    final hasPriceSignal = item.price > 0 || item.hasOptions;
    return visible && hasStock && hasPriceSignal;
  }

  Future<void> _toggleLike(ProductView item) async {
    final businessId = widget.businessId;
    final key = (businessId, item.itemId);
    if (_liking.contains(key)) return;
    setState(() => _liking.add(key));
    bool? changed;
    try {
      changed = await toggleItemLike(
        context,
        businessId: businessId,
        itemId: item.itemId,
      );
    } catch (_) {
      changed = null;
    }
    if (!mounted) return;
    setState(() => _liking.remove(key));
    if (changed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить избранное')),
      );
    }
  }

  void _openCart() {
    final callback = widget.onCart;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (cartContext) => CartPage(
          businessId: widget.businessId,
          onCheckout: () => Navigator.of(cartContext).push(
            MaterialPageRoute(builder: (_) => const CheckoutPage()),
          ),
          onCatalog: () => Navigator.of(cartContext).maybePop(),
        ),
      ),
    );
  }

  void _openItem(ProductView item) {
    openProduct(
      context,
      item,
      liked: context
          .read<LikedItemsProvider>()
          .isLiked(widget.businessId, item.itemId),
      onLike: () => _toggleLike(item),
      onCart: _openCart,
      businessId: widget.businessId,
    );
  }

  Widget _header() => AppTopBar(
        title: 'Акции',
        onBack: () => Navigator.of(context).maybePop(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LiquidGlassDock(
          content: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxxl,
                ),
                child: _header(),
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
              onTap: _openCart,
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final items = _items;
    Widget? footer;
    if (_isLoading) {
      footer = const SizedBox(height: 200, child: AppLoading());
    } else if (_failed) {
      footer = AppErrorState(
        message: 'Не удалось загрузить товары акции',
        onRetry: _loadItems,
      );
    } else if (items == null || items.isEmpty) {
      footer = const AppEmptyState(
        title: 'В этой акции пока нет товаров',
        muted: true,
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: ProductGrid(
          key: const ValueKey('promotion-products-grid'),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppCartButton.clearanceFor(context) +
                MediaQuery.paddingOf(context).bottom,
          ),
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _title,
                style: AppTypography.displayBold
                    .copyWith(color: context.palette.textPrimary),
              ),
              if (!_isLoading && !_failed && items != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Товары акции · ${items.length}',
                  style: AppTypography.bodySmall
                      .copyWith(color: context.palette.textSecondary),
                ),
                if (_terms != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _terms!,
                    style: AppTypography.bodySmall
                        .copyWith(color: context.palette.textSecondary),
                  ),
                ],
              ],
            ],
          ),
          footer: footer,
          itemCount: _isLoading || _failed ? 0 : items?.length ?? 0,
          itemBuilder: (context, index) {
            final item = items![index];
            final busy = _liking.contains((widget.businessId, item.itemId));
            return Selector2<CartProvider, LikedItemsProvider, (double, bool)>(
              selector: (_, cart, likes) => (
                cart.getCatalogQuantityForKey(item.catalogKey),
                likes.isLiked(widget.businessId, item.itemId),
              ),
              builder: (context, state, _) {
                final quantity = state.$1;
                final isLiked = state.$2;
                return ProductCard.fromView(
                  item,
                  key: ValueKey('promotion-product-$index'),
                  quantity: quantity,
                  onTap: () => _openItem(item),
                  onIncrement: item.source.amount != null &&
                          quantity >= item.source.amount!
                      ? null
                      : () => context
                          .read<CartProvider>()
                          .incrementCatalogItem(item.source),
                  onDecrement: () => context
                      .read<CartProvider>()
                      .decrementCatalogItem(item.source),
                  trailingAction: Semantics(
                    button: true,
                    toggled: isLiked,
                    enabled: !busy,
                    label: isLiked
                        ? 'Убрать из избранного'
                        : 'Добавить в избранное',
                    child: Opacity(
                      opacity: busy ? 0.5 : 1,
                      child: AppIconButton(
                        key: ValueKey('promotion-like-$index'),
                        asset: AppIcons.heart,
                        size: AppSpacing.touchTarget,
                        glyphSize: 20,
                        fill: isLiked
                            ? context.palette.brandRed
                            : context.palette.surfaceMuted,
                        color: isLiked
                            ? Colors.white
                            : context.palette.textPrimary,
                        onTap: busy ? null : () => _toggleLike(item),
                        tooltip: isLiked
                            ? 'Убрать из избранного'
                            : 'Добавить в избранное',
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
