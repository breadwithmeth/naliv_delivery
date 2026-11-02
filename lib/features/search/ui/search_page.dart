import 'package:flutter/material.dart';

import '../../../ui/app_states.dart';
import 'package:provider/provider.dart';

import '../../../core/product_view.dart';
import '../../../design/tokens.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_search_field.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/app_icon_button.dart';
import '../../../ui/liquid_glass_dock.dart';
import '../../../ui/product_row.dart';
import '../../../core/like_action.dart';
import '../../../utils/cart_provider.dart';
import '../../../utils/liked_items_provider.dart';
import '../../catalog/catalog_data_source.dart';
import '../../product/product_navigation.dart';

/// Product search — the design's four `Поиск` states.
///
/// Search and back navigation share the top row; results scroll above the cart.
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
  final _scroll = ScrollController();
  int _generation = 0;
  String? _query;
  int _nextPage = 1;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _moreFailed = false;
  List<ProductView>? _results;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) {
      _search(_controller.text);
    }
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 240 &&
        _hasMore &&
        !_loadingMore &&
        !_moreFailed) {
      _loadMore();
    }
  }

  void _checkForMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  void _textChanged(String value) {
    _generation++;
    setState(() {
      _loading = false;
      _loadingMore = false;
      _failed = false;
      _moreFailed = false;
      _hasMore = false;
      _query = null;
      if (value.trim().isEmpty) _results = null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _textChanged('');
      return;
    }
    if (_scroll.hasClients) _scroll.jumpTo(0);
    final generation = ++_generation;
    setState(() {
      _query = trimmed;
      _results = null;
      _nextPage = 1;
      _hasMore = false;
      _loadingMore = false;
      _moreFailed = false;
      _loading = true;
      _failed = false;
    });
    await _loadPage(generation, trimmed, append: false);
  }

  Future<void> _loadMore() async {
    final query = _query;
    if (query == null || !_hasMore || _loadingMore) return;
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });
    await _loadPage(_generation, query, append: true);
  }

  Future<void> _loadPage(int generation, String query,
      {required bool append}) async {
    try {
      final result = await CatalogDataSource(businessId: widget.businessId ?? 0)
          .search(query, page: _nextPage);
      if (!mounted || generation != _generation) return;
      setState(() {
        final known = <int>{
          for (final item in _results ?? <ProductView>[]) item.itemId
        };
        _results = [
          if (append) ...?_results,
          for (final item in result.items)
            if (known.add(item.itemId)) item,
        ];
        _nextPage = result.page + 1;
        _hasMore = result.hasNextPage;
        _loading = false;
        _loadingMore = false;
      });
      _checkForMore();
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = !append;
        _moreFailed = append;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _openProduct(ProductView item, bool liked) {
    openProduct(
      context,
      item,
      liked: liked,
      onLike: () => _toggleLike(item),
      onCart: widget.onCart,
      businessId: widget.businessId,
    );
  }

  Future<void> _toggleLike(ProductView item) async {
    final businessId = widget.businessId;
    if (businessId == null) return;
    await toggleItemLike(context, businessId: businessId, itemId: item.itemId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LiquidGlassDock(
          content: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, AppSpacing.xl, AppSpacing.gutter, 0),
                child: Row(
                  children: [
                    AppIconButton(
                      asset: AppIcons.back,
                      onTap: () => Navigator.of(context).maybePop(),
                      tooltip: 'Назад',
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppSearchField(
                        controller: _controller,
                        autofocus: true,
                        onSubmitted: _search,
                        onChanged: _textChanged,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.huge),
              Expanded(
                child: _list(),
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

  Widget _list() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return AppErrorState(
        message: 'Не удалось выполнить поиск',
        onRetry: () => _search(_controller.text),
      );
    }
    final results = _results;
    if (results == null) return const SizedBox.shrink();
    if (results.isEmpty && !_hasMore) {
      return const AppEmptyState(title: 'Товары не найдены', muted: true);
    }
    return ListView.separated(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        0,
        AppSpacing.xxxl,
        AppCartButton.clearanceFor(context) +
            MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: results.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        if (index == results.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: _loadMore,
                      child: Text(
                          _moreFailed ? 'Повторить загрузку' : 'Показать ещё'),
                    ),
            ),
          );
        }
        final item = results[index];
        return Selector2<CartProvider, LikedItemsProvider, (double, bool)>(
          selector: (_, cart, likes) => (
            cart.getCatalogQuantityForKey(item.catalogKey),
            widget.businessId != null &&
                likes.isLiked(widget.businessId!, item.itemId),
          ),
          builder: (context, state, _) => ProductRow.fromView(
            item,
            liked: state.$2,
            onTap: () => _openProduct(item, state.$2),
            quantity: state.$1,
            onLike: () => _toggleLike(item),
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
