import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/like_action.dart';
import '../core/product_view.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../features/cart/ui/cart_page.dart';
import '../features/product/product_navigation.dart';
import '../model/item.dart' as item_model;
import '../ui/app_cart_button.dart';
import '../ui/app_icon.dart';
import '../ui/app_icon_button.dart';
import '../ui/app_states.dart';
import '../ui/app_top_bar.dart';
import '../ui/product_card.dart';
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
      _useInitialItemsOrLoad();
    }
  }

  void _useInitialItemsOrLoad() {
    final initial = widget.initialItems;
    if (initial != null) {
      // A supplied list is complete. Keep its models, order and missing fields intact.
      _items = initial.map(ProductView.fromItem).toList(growable: false);
    } else {
      _loadItems();
    }
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
        title: _title,
        onBack: () => Navigator.of(context).maybePop(),
      );

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final count = cart.displayItemCount;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxxl,
                  ),
                  child: _header(),
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
                  total: count == 0 ? null : cart.getTotalPrice().round(),
                  onTap: _openCart,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_isLoading) return const AppLoading();
    if (_failed) {
      return AppErrorState(
        message: 'Не удалось загрузить товары акции',
        onRetry: _loadItems,
      );
    }
    final items = _items;
    if (items == null || items.isEmpty) {
      return const AppEmptyState(
        title: 'В этой акции пока нет товаров',
        muted: true,
      );
    }
    final cart = context.watch<CartProvider>();
    final liked = context.watch<LikedItemsProvider>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final usableWidth = constraints.maxWidth - AppSpacing.xxxl * 2;
        final columns = ProductCard.columnsFor(context, usableWidth,
            spacing: AppSpacing.xl);
        return GridView.builder(
          key: const ValueKey('promotion-products-grid'),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xxxl,
            0,
            AppSpacing.xxxl,
            AppCartButton.roundSize +
                AppSpacing.huge +
                MediaQuery.paddingOf(context).bottom,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.xl,
            crossAxisSpacing: AppSpacing.xl,
            mainAxisExtent: ProductCard.heightFor(context,
                hasOldPrice: items.any((item) => item.oldPrice != null)),
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isLiked = liked.isLiked(widget.businessId, item.itemId);
            final busy = _liking.contains((widget.businessId, item.itemId));
            final quantity = cart.getCatalogQuantity(item.source);
            final card = ProductCard.fromView(
              item,
              quantity: quantity,
              onTap: () => _openItem(item),
              onIncrement:
                  item.source.amount != null && quantity >= item.source.amount!
                      ? null
                      : () => cart.incrementCatalogItem(item.source),
              onDecrement: () => cart.decrementCatalogItem(item.source),
            );
            return Stack(
              key: ValueKey('promotion-product-$index'),
              children: [
                Positioned.fill(child: card),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Semantics(
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
                            ? context.palette.brandRed.withValues(alpha: 0.75)
                            : context.palette.surface.withValues(alpha: 0.75),
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
                ),
              ],
            );
          },
        );
      },
    );
  }
}
