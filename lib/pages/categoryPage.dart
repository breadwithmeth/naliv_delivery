import 'package:flutter/material.dart';
import 'package:naliv_delivery/utils/cartFloatingButton.dart';
import '../utils/api.dart';
import '../shared/product_card.dart';
import '../model/item.dart' as ItemModel;

class CategoryPage extends StatefulWidget {
  final Category category;
  final List<Category> allCategories;
  final int? businessId;

  const CategoryPage({
    super.key,
    required this.category,
    required this.allCategories,
    this.businessId,
  });

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}


class _CategoryPageState extends State<CategoryPage> {
  Category? _selectedCategory;
  Category? _selectedSubcategory;
  List<ItemModel.Item> _items = [];
  bool _isLoading = false;
  String? _error;
  PaginationInfo? _pagination;

  // Для бесконечной прокрутки
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category;
    _loadCategoryItems();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreItems();
    }
  }

  // Получаем только основные категории (без родительских)
  List<Category> get _mainCategories {
    return widget.allCategories
        .where((category) => !category.isSubcategory)
        .toList();
  }

  Future<void> _loadCategoryItems({bool isLoadMore = false}) async {
    if (!mounted) return;

    if (!isLoadMore) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final categoryId =
          _selectedSubcategory?.categoryId ?? _selectedCategory!.categoryId;
      final currentPage = isLoadMore ? (_pagination?.page ?? 0) + 1 : 1;

      final response = await ApiService.getCategoryItemsTyped(
        categoryId,
        businessId: widget.businessId!,
        page: currentPage,
        limit: 5000,
      );

      if (mounted) {
        setState(() {
          if (response != null) {
            final convertedItems = response.data.items
                .map((categoryItem) =>
                    ItemModel.Item.fromCategoryItem(categoryItem))
                .toList();
            if (isLoadMore) {
              _items.addAll(convertedItems);
            } else {
              _items = convertedItems;
            }
            _pagination = response.data.pagination;
          } else {
            if (!isLoadMore) {
              _items = [];
            }
          }
          _isLoading = false;
          _isLoadingMore = false;
        });

        print(
            '✅ Загружено товаров категории ${_selectedCategory!.name}: ${_items.length}');
      }
    } catch (e) {
      print('❌ Ошибка загрузки товаров категории: $e');
      if (mounted) {
        setState(() {
          _error = 'Ошибка загрузки товаров: $e';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore || _pagination == null || !_pagination!.hasNextPage) {
      return;
    }
    await _loadCategoryItems(isLoadMore: true);
  }

  void _onCategorySelected(Category category) {
    if (_selectedCategory == category) return;

    setState(() {
      _selectedCategory = category;
      _selectedSubcategory = null; // Сбрасываем выбранную подкатегорию
    });

    _loadCategoryItems();
  }

  void _onSubcategorySelected(Category? subcategory) {
    if (_selectedSubcategory == subcategory) return;

    setState(() {
      _selectedSubcategory = subcategory;
    });

    _loadCategoryItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: CartFloatingButton(),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: Text(_selectedCategory?.name ?? 'Каталог'),
              pinned: true,
              floating: true,
              snap: true,
              // backgroundColor: Theme.of(context).colorScheme.surface,
              // foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Column(
                  children: [
                    // Горизонтальный список категорий
                    // Container(
                    //   height: 60,
                    //   color: Theme.of(context).colorScheme.surface,
                    //   child: ListView.builder(
                    //     scrollDirection: Axis.horizontal,
                    //     padding: const EdgeInsets.symmetric(horizontal: 16),
                    //     itemCount: _mainCategories.length,
                    //     itemBuilder: (context, index) {
                    //       final category = _mainCategories[index];
                    //       final isSelected = _selectedCategory == category;

                    //       return Padding(
                    //         padding: const EdgeInsets.only(right: 12),
                    //         child: FilterChip(
                    //           selected: isSelected,
                    //           onSelected: (_) => _onCategorySelected(category),
                    //           label: Text(category.name),
                    //           labelStyle: TextStyle(
                    //             color: isSelected
                    //                 ? Theme.of(context).colorScheme.onPrimary
                    //                 : Theme.of(context).colorScheme.onSurface,
                    //             fontWeight: isSelected
                    //                 ? FontWeight.w600
                    //                 : FontWeight.w500,
                    //           ),
                    //           backgroundColor: isSelected
                    //               ? Theme.of(context).colorScheme.primary
                    //               : Theme.of(context)
                    //                   .colorScheme
                    //                   .surfaceContainerHighest,
                    //           selectedColor:
                    //               Theme.of(context).colorScheme.primary,
                    //           checkmarkColor:
                    //               Theme.of(context).colorScheme.onPrimary,
                    //           side: BorderSide.none,
                    //         ),
                    //       );
                    //     },
                    //   ),
                    // ),

                    // Горизонтальный список подкатегорий
                    if (_selectedCategory != null &&
                        _selectedCategory!.hasSubcategories)
                      Container(
                        height: 60,
                        // color:
                        //     Theme.of(context).colorScheme.surfaceContainerLow,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _selectedCategory!.subcategories.length +
                              1, // +1 для "Все"
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              // Кнопка "Все товары"
                              final isSelected = _selectedSubcategory == null;
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: FilterChip(
                                  selected: isSelected,
                                  onSelected: (_) =>
                                      _onSubcategorySelected(null),
                                  label: const Text('Все товары'),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSecondary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                  backgroundColor: isSelected
                                      ? Theme.of(context).colorScheme.secondary
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                  selectedColor:
                                      Theme.of(context).colorScheme.secondary,
                                  checkmarkColor:
                                      Theme.of(context).colorScheme.onSecondary,
                                  side: BorderSide.none,
                                ),
                              );
                            }

                            final subcategory =
                                _selectedCategory!.subcategories[index - 1];
                            final isSelected =
                                _selectedSubcategory == subcategory;

                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: FilterChip(
                                selected: isSelected,
                                onSelected: (_) =>
                                    _onSubcategorySelected(subcategory),
                                label: Text(subcategory.name),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSecondary
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                                backgroundColor: isSelected
                                    ? Theme.of(context).colorScheme.secondary
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                selectedColor:
                                    Theme.of(context).colorScheme.secondary,
                                checkmarkColor:
                                    Theme.of(context).colorScheme.onSecondary,
                                side: BorderSide.none,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: _buildBody(),
      ),
    );
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
                onPressed: () => _loadCategoryItems(),
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
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
            const SizedBox(height: 8),
            Text(
              _selectedSubcategory != null
                  ? 'В подкатегории "${_selectedSubcategory!.name}" нет товаров'
                  : 'В категории "${_selectedCategory!.name}" нет товаров',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
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
        childAspectRatio: 0.6, // Делаем карточки вытянутыми вертикально
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          // Показываем индикатор загрузки в конце списка
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final item = _items[index];
        return ProductCard(
          item: item,
        );
      },
    );
  }
}
