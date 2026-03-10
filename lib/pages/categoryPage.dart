import 'package:flutter/material.dart';
import 'package:naliv_delivery/utils/cartFloatingButton.dart';
import '../utils/api.dart';
import '../shared/product_card.dart';
import '../model/item.dart' as ItemModel;
import 'package:naliv_delivery/shared/app_theme.dart';

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
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      _loadMoreItems();
    }
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
      final categoryId = _selectedSubcategory?.categoryId ?? _selectedCategory!.categoryId;
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
            final convertedItems = response.data.items.map((categoryItem) => ItemModel.Item.fromCategoryItem(categoryItem)).toList();
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
      }
    } catch (e) {
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

  void _onSubcategorySelected(Category? subcategory) {
    if (_selectedSubcategory == subcategory) return;

    setState(() {
      _selectedSubcategory = subcategory;
    });

    _loadCategoryItems();
  }

  @override
  Widget build(BuildContext context) {
    final hasSubcategories = _selectedCategory != null && _selectedCategory!.hasSubcategories;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      floatingActionButton: const CartFloatingButton(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        title: Text(
          _selectedCategory?.name ?? 'Каталог',
          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildCategoryBadge(),
                  if (hasSubcategories) ...[
                    const SizedBox(height: 12),
                    _buildSubcategoryChips(),
                  ],
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

  Widget _buildCategoryBadge() {
    final subtitle = _selectedSubcategory?.name ?? _selectedCategory?.name ?? 'Каталог';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(radius: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: AppDecorations.pill(color: AppColors.blue),
            child: const Icon(Icons.category, color: AppColors.orange, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedCategory?.name ?? 'Каталог',
                  style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryChips() {
    final subs = _selectedCategory?.subcategories ?? [];
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: subs.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedSubcategory == null;
            return ChoiceChip(
              selected: isSelected,
              onSelected: (_) => _onSubcategorySelected(null),
              label: const Text('Все товары'),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : AppColors.text,
                fontWeight: FontWeight.w700,
              ),
              backgroundColor: AppColors.card,
              selectedColor: AppColors.orange,
              side: BorderSide(color: isSelected ? AppColors.orange.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08)),
            );
          }

          final sub = subs[index - 1];
          final isSelected = _selectedSubcategory == sub;
          return ChoiceChip(
            selected: isSelected,
            onSelected: (_) => _onSubcategorySelected(sub),
            label: Text(sub.name),
            labelStyle: TextStyle(
              color: isSelected ? Colors.black : AppColors.text,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: AppColors.card,
            selectedColor: AppColors.orange,
            side: BorderSide(color: isSelected ? AppColors.orange.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08)),
          );
        },
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
                onPressed: () => _loadCategoryItems(),
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

    if (_items.isEmpty) {
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
            const SizedBox(height: 8),
            Text(
              _selectedSubcategory != null
                  ? 'В подкатегории "${_selectedSubcategory!.name}" нет товаров'
                  : 'В категории "${_selectedCategory!.name}" нет товаров',
              style: TextStyle(color: AppColors.textMute, fontSize: 14),
              textAlign: TextAlign.center,
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
      physics: const BouncingScrollPhysics(),
    );
  }
}
