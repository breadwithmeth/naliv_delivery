import 'package:flutter/material.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/model/item.dart' as ItemModel;
import 'package:naliv_delivery/shared/product_card.dart';
import '../utils/responsive.dart';

/// Страница с товарами конкретной акции
class PromotionItemsPage extends StatefulWidget {
  final int promotionId;
  final String? promotionName;
  final int businessId;

  const PromotionItemsPage({
    Key? key,
    required this.promotionId,
    this.promotionName,
    required this.businessId,
  }) : super(key: key);

  @override
  State<PromotionItemsPage> createState() => _PromotionItemsPageState();
}

class _PromotionItemsPageState extends State<PromotionItemsPage> {
  List<ItemModel.Item>? _items;
  bool _isLoading = false;
  String? _error;
  int _page = 1;
  final int _limit = 20;
  int? _totalPages;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Запрос полной информации с товарами и пагинацией
      final resp = await ApiService.getPromotionItems(
        promotionId: widget.promotionId,
        businessId: widget.businessId,
        page: _page,
        limit: _limit,
      );
      if (resp == null) throw Exception('Пустой ответ');
      final data = resp['data'] as Map<String, dynamic>;
      final itemsJson = data['items'] as List<dynamic>;
      final items = itemsJson.cast<Map<String, dynamic>>().map((e) => ItemModel.Item.fromJson(e)).toList();
      final pagination = data['pagination'] as Map<String, dynamic>?;
      setState(() {
        _items = items;
        _totalPages = pagination?['totalPages'] as int?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки товаров: $e';
        _isLoading = false;
      });
    }
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
                  : Column(
                      children: [
                        Expanded(
                          child: Padding(
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
                        ),
                        // Навигация по страницам
                        if (_totalPages != null && _totalPages! > 1)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 7.s),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: _page > 1
                                      ? () {
                                          setState(() => _page--);
                                          _loadItems();
                                        }
                                      : null,
                                  child: const Text('Назад'),
                                ),
                                SizedBox(width: 14.s),
                                Text('Страница $_page из $_totalPages'),
                                SizedBox(width: 14.s),
                                TextButton(
                                  onPressed: _page < _totalPages!
                                      ? () {
                                          setState(() => _page++);
                                          _loadItems();
                                        }
                                      : null,
                                  child: const Text('Вперёд'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
    );
  }
}
