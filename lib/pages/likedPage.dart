import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/api.dart';
import '../model/item.dart' as model;
import '../shared/product_card.dart';
import '../utils/liked_items_provider.dart';

class LikedPage extends StatefulWidget {
  final int businessId;
  const LikedPage({super.key, required this.businessId});

  @override
  State<LikedPage> createState() => _LikedPageState();
}

class _LikedPageState extends State<LikedPage> {
  final ScrollController _scrollController = ScrollController();
  final List<model.Item> _items = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  bool _syncScheduled = false; // защищаемся от частых setState

  @override
  void initState() {
    super.initState();
    _loadPage(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_isLoading) return;
    if (reset) {
      setState(() {
        _isRefreshing = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _items.clear();
      });
    } else {
      if (!_hasMore) return;
      setState(() => _isLoading = true);
    }

    try {
      final data = await ApiService.getLikedItems(
        businessId: widget.businessId,
        page: _page,
        limit: 20,
      );

      if (!mounted) return;

      if (data == null) {
        setState(() {
          _error = 'Не удалось загрузить понравившиеся';
          _isLoading = false;
          _isRefreshing = false;
        });
        return;
      }

      final List<dynamic> list = data['items'] ?? data['liked_items'] ?? [];
      final newItems = list
          .cast<Map<String, dynamic>>()
          .map((json) => model.Item.fromJson(json))
          .toList();

      setState(() {
        _items.addAll(newItems);
        _page += 1;
        _hasMore = newItems.length >= 20;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка: $e';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadPage();
    }
  }

  Future<void> _onRefresh() async {
    await _loadPage(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Понравившиеся'),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isRefreshing && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 28),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _loadPage(reset: true),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.favorite_border, size: 32),
            SizedBox(height: 8),
            Text('Список пуст'),
          ],
        ),
      );
    }
    return Consumer<LikedItemsProvider>(
      builder: (context, likedProvider, child) {
        // Фильтруем по актуальному состоянию лайков
        final likedSet = likedProvider.likedItems(widget.businessId);
        // Удаляем локально те, что больше не лайкнуты
        if (!_syncScheduled) {
          _syncScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _items.removeWhere((it) => !likedSet.contains(it.itemId));
            _syncScheduled = false;
            setState(() {});
          });
        }

        return GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.60,
            ),
            itemCount: _items.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _items.length) {
                return const Center(child: CircularProgressIndicator());
              }
              final item = _items[index];
              return ProductCard(item: item);
            });
      },
    );
  }
}
// _ItemTile удалён – используем ProductCard
