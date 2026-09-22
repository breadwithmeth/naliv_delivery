import 'package:flutter/material.dart';

import '../../../ui/app_states.dart';
import 'package:provider/provider.dart';

import '../../../core/product_view.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_search_field.dart';
import '../../../ui/app_top_bar.dart';
import '../../../ui/product_row.dart';
import '../../../core/like_action.dart';
import '../../../utils/cart_provider.dart';
import '../../../utils/liked_items_provider.dart';
import '../../catalog/catalog_data_source.dart';
import '../../product/product_navigation.dart';

/// Product search — the design's four `Поиск` states.
///
/// Geometry: top bar at y = 70, the 46 px field 12 px beneath it, results 24 px below that as
/// 114 px rows 4 px apart, and the floating cart pill at the bottom. The empty and no-result
/// states centre their message in the list area.
///
/// Search runs on **submit**, matching the frames: `Поиск - Текст в поле поиска` shows text in
/// the field with no results yet, and only `Удачный поиск` lists them.
class SearchPage extends StatefulWidget {
  const SearchPage({this.businessId, this.onCart, super.key});

  /// Store to search in; null means "any store".
  final int? businessId;

  /// Opens the cart; the floating button is present on every catalogue screen.
  final VoidCallback? onCart;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  List<ProductView>? _results;
  bool _loading = false;
  bool _failed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = null;
        _failed = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final results =
          await CatalogDataSource(businessId: widget.businessId ?? 0)
              .search(trimmed);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _openProduct(ProductView item, bool liked) {
    openProduct(context, item, liked: liked, onLike: () => _toggleLike(item));
  }

  Future<void> _toggleLike(ProductView item) async {
    final businessId = widget.businessId;
    if (businessId == null) return;
    await toggleItemLike(context, businessId: businessId, itemId: item.itemId);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cart = context.watch<CartProvider>();
    final liked = context.watch<LikedItemsProvider>();
    final count = cart.displayItemCount;
    final businessId = widget.businessId;

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
                    title: 'Поиск',
                    onBack: () => Navigator.of(context).maybePop(),
                    showBack: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: AppSearchField(
                    controller: _controller,
                    autofocus: true,
                    onSubmitted: _search,
                    onChanged: (value) {
                      // Clearing the field returns to the idle state; typing keeps the last
                      // results until the next submit, as the frames show.
                      if (value.trim().isEmpty) _search('');
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
                Expanded(
                  child: _list(palette, liked, businessId),
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

  Widget _list(AppPalette palette, LikedItemsProvider liked, int? businessId) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return AppErrorState(
        message: 'Не удалось выполнить поиск',
        onRetry: () => _search(_controller.text),
      );
    }
    final results = _results;
    if (results == null) return const SizedBox.shrink();
    if (results.isEmpty) {
      return const AppEmptyState(title: 'Товары не найдены', muted: true);
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        0,
        AppSpacing.xxxl,
        AppCartButton.clearance + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final item = results[index];
        final isLiked =
            businessId != null && liked.isLiked(businessId, item.itemId);
        return ProductRow.fromView(
          item,
          liked: isLiked,
          onTap: () => _openProduct(item, isLiked),
          quantity:
              context.watch<CartProvider>().getCatalogQuantity(item.source),
          onLike: () => _toggleLike(item),
          onIncrement: () =>
              context.read<CartProvider>().incrementCatalogItem(item.source),
          onDecrement: () =>
              context.read<CartProvider>().decrementCatalogItem(item.source),
        );
      },
    );
  }
}
