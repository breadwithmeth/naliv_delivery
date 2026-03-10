import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/api.dart';
import '../utils/business_provider.dart';
import '../shared/product_card.dart';
import '../model/item.dart' as ItemModel;
import 'package:naliv_delivery/shared/app_theme.dart';

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
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) return;

    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
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

      final mapped = resp.data.items.map((ci) => ItemModel.Item.fromCategoryItem(ci)).toList();

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
    if (_currentQuery.isEmpty || _pagination == null || !_pagination!.hasNextPage) {
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
        final mapped = resp.data.items.map((ci) => ItemModel.Item.fromCategoryItem(ci)).toList();

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
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.orange)),
            SizedBox(height: 16),
            Text('Загрузка товаров...', style: TextStyle(color: AppColors.text)),
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
                color: AppColors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _search(_controller.text),
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.black,
                ),
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
              color: AppColors.textMute,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Товары не найдены',
              style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoadingMore && index == _items.length) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.orange),
            ),
          );
        }
        final item = _items[index];
        return ProductCard(item: item);
      },
      physics: const BouncingScrollPhysics(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Поиск', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              child: Column(
                children: [
                  _buildSearchField(),
                  const SizedBox(height: 12),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: AppDecorations.card(radius: 16),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.textMute),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                hintText: 'Найти товары...',
                hintStyle: TextStyle(color: AppColors.textMute),
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
            ),
          ),
          IconButton(
            onPressed: () => _search(_controller.text),
            icon: const Icon(Icons.tune, color: AppColors.textMute),
          ),
        ],
      ),
    );
  }
}
