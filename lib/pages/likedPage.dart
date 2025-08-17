import 'package:flutter/material.dart';
import '../utils/api.dart';
import '../model/item.dart' as model;

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

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemBuilder: (_, i) {
        if (i == _items.length) {
          return _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : const SizedBox.shrink();
        }
        final item = _items[i];
        return _ItemTile(item: item);
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: _items.length + 1,
    );
  }
}

class _ItemTile extends StatelessWidget {
  final model.Item item;
  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Icon(Icons.shopping_bag,
            color: Theme.of(context).colorScheme.primary),
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${item.price.toStringAsFixed(0)} ₸'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: перейти на страницу товара
        },
      ),
    );
  }
}
