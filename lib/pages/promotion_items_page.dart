import 'package:flutter/material.dart';
import 'package:gradusy24/utils/api.dart';
import 'package:gradusy24/model/item.dart' as item_model;
import 'package:gradusy24/shared/product_card.dart';
import '../utils/responsive.dart';

/// Страница с товарами конкретной акции
class PromotionItemsPage extends StatefulWidget {
  final int promotionId;
  final String? promotionName;
  final int businessId;
  final List<item_model.Item>? initialItems;

  const PromotionItemsPage({
    super.key,
    required this.promotionId,
    this.promotionName,
    required this.businessId,
    this.initialItems,
  });

  @override
  State<PromotionItemsPage> createState() => _PromotionItemsPageState();
}

class _PromotionItemsPageState extends State<PromotionItemsPage> {
  List<item_model.Item>? _items;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialItems != null) {
      _items = List<item_model.Item>.from(widget.initialItems!);
    } else {
      _loadItems();
    }
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await ApiService.getAllPromotionItemsTyped(
        promotionId: widget.promotionId,
        businessId: widget.businessId,
        limit: 50,
      );
      if (items == null) throw Exception('Пустой ответ');
      final filteredItems = items.where(_isSellablePromotionItem).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _items = filteredItems;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки товаров: $e';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.promotionName != null ? 'Акция: ${widget.promotionName}' : 'Товары акции',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(
                        onPressed: _loadItems,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : (_items == null || _items!.isEmpty)
                  ? const Center(child: Text('Товары не найдены'))
                  : Padding(
                      padding: EdgeInsets.all(7.s),
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.56,
                          crossAxisSpacing: 7.s,
                          mainAxisSpacing: 7.s,
                        ),
                        itemCount: _items!.length,
                        itemBuilder: (context, index) {
                          final item = _items![index];
                          return ProductCard(item: item);
                        },
                      ),
                    ),
    );
  }
}
