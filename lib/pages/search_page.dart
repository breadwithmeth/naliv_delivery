import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/api.dart';
import '../utils/business_provider.dart';
import '../shared/product_card.dart';
import '../model/item.dart' as ItemModel;

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();

  List<ItemModel.Item> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  PaginationInfo? _pagination;

  // для бесконечной прокрутки
  final ScrollController _scrollController = ScrollController();

  // текущие параметры поиска
  String _currentQuery = '';
  int? _currentBusinessId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_isLoadingMore &&
        _pagination != null &&
        _pagination!.hasNextPage &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) return;

    final businessProvider =
        Provider.of<BusinessProvider>(context, listen: false);
    final businessId = businessProvider.selectedBusinessId;

    setState(() {
      _isLoading = true;
      _error = null;
      _items = [];
      _pagination = null;
      _currentQuery = query;
      _currentBusinessId = businessId;
    });

    try {
      final resp = await ApiService.searchItemsTyped(
        query,
        businessId: businessId,
        page: 1,
        limit: 40,
      );

      if (!mounted) return;

      if (resp == null) {
        setState(() {
          _items = [];
          _pagination = null;
        });
        return;
      }

      final mapped = resp.data.items
          .map((ci) => ItemModel.Item.fromCategoryItem(ci))
          .toList();

      setState(() {
        _items = mapped;
        _pagination = resp.data.pagination;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_currentQuery.isEmpty ||
        _pagination == null ||
        !_pagination!.hasNextPage) {
      return;
    }

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _pagination!.page + 1;

      final resp = await ApiService.searchItemsTyped(
        _currentQuery,
        businessId: _currentBusinessId,
        page: nextPage,
        limit: _pagination!.limit,
      );

      if (!mounted) return;

      if (resp != null) {
        final mapped = resp.data.items
            .map((ci) => ItemModel.Item.fromCategoryItem(ci))
            .toList();

        setState(() {
          _items.addAll(mapped);
          _pagination = resp.data.pagination;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Можно показать снэкбар/ошибку догрузки, но основной экран не ломаем
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Загрузка товаров...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _search(_controller.text),
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty && _controller.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Товары не найдены',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoadingMore && index == _items.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final item = _items[index];
        return ProductCard(item: item);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'Поиск товаров...',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _search(_controller.text),
            tooltip: 'Поиск',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
