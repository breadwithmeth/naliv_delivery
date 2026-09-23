import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/like_action.dart';
import '../../../core/product_view.dart';
import '../../../ui/app_states.dart';
import '../../../design/tokens.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_top_bar.dart';
import '../../../ui/product_row.dart';
import '../../../utils/cart_provider.dart';
import '../../../utils/liked_items_provider.dart';
import '../../catalog/catalog_data_source.dart';
import '../../product/product_navigation.dart';

/// Favourites — the design's `Избранное` frames.
///
/// Geometry: the standard top bar (back + title, **no** search action), rows 343 × 114 starting
/// at y = 151 with a 4 px gap (pitch 118, the same row as search), an unavailable item drawn at
/// 50 % opacity, and the empty state as centred text at y = 369 — «Список пуст» 20/700 white
/// over «Добавляйте товары в избранное, чтобы быстро находить их позже» 14/400 muted.
///
/// The list is the API's liked-items page, but a row the user unlikes is removed immediately
/// rather than waiting for a refetch.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    required this.businessId,
    this.onCart,
    super.key,
  });

  final int businessId;
  final VoidCallback? onCart;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final _scroll = ScrollController();
  final _removed = <int>{};
  List<ProductView>? _items;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _failed = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _page = 1;
        _items = null;
        _failed = false;
        _removed.clear();
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final result = await CatalogDataSource(businessId: widget.businessId)
          .likedItems(page: _page);
      if (!mounted) return;
      setState(() {
        _items = [...?_items, ...result.items];
        _hasMore = result.hasMore;
        _loadingMore = false;
        if (result.hasMore) _page++;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loadingMore = false;
      });
    }
  }

  Future<void> _unlike(ProductView item) async {
    setState(() => _removed.add(item.itemId));
    final changed = await toggleItemLike(
      context,
      businessId: widget.businessId,
      itemId: item.itemId,
    );
    // The row comes back if the server refused the change.
    if (changed == false && mounted) {
      setState(() => _removed.remove(item.itemId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final liked = context.watch<LikedItemsProvider>();
    final count = cart.displayItemCount;
    final visible = (_items ?? const <ProductView>[])
        .where((item) => !_removed.contains(item.itemId))
        .toList();

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
                    title: 'Избранное',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
                Expanded(
                  child: _body(visible, liked),
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

  Widget _body(List<ProductView> visible, LikedItemsProvider liked) {
    if (_failed) {
      return AppErrorState(
        message: 'Не удалось загрузить избранное',
        onRetry: () => _load(reset: true),
      );
    }
    if (_items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (visible.isEmpty) {
      return const AppEmptyState(
        title: 'Список пуст',
        subtitle:
            'Добавляйте товары в избранное, чтобы быстро находить их позже',
      );
    }
    return ListView.separated(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        0,
        AppSpacing.xxxl,
        AppCartButton.clearance + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: visible.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        if (index >= visible.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.huge),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = visible[index];
        final row = ProductRow.fromView(
          item,
          liked: liked.isLiked(widget.businessId, item.itemId),
          quantity:
              context.watch<CartProvider>().getCatalogQuantity(item.source),
          onTap: () => openProduct(
            context,
            item,
            liked: liked.isLiked(widget.businessId, item.itemId),
            onLike: () => _unlike(item),
          ),
          onLike: () => _unlike(item),
          onIncrement: () =>
              context.read<CartProvider>().incrementCatalogItem(item.source),
          onDecrement: () =>
              context.read<CartProvider>().decrementCatalogItem(item.source),
        );
        // Unavailable favourites stay in the list, drawn at half opacity like the frame.
        return item.available ? row : Opacity(opacity: 0.5, child: row);
      },
    );
  }
}
