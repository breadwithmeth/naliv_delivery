import 'package:flutter/material.dart';
import 'package:naliv_delivery/utils/cartFloatingButton.dart';
import '../utils/api.dart';
import '../shared/product_card.dart';
import '../model/item.dart' as ItemModel;
import 'search_page.dart';

class CategoryPage extends StatefulWidget {
  final Category category;
  final List<Category> allCategories;
  final int? businessId;
  final String? sectionTitle;

  const CategoryPage({
    super.key,
    required this.category,
    required this.allCategories,
    this.businessId,
    this.sectionTitle,
  });

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  // ─── Palette (matches mainPage) ──────────────────────────
  static const Color _bgDeep = Color(0xFF121212);
  static const Color _bgTop = Color(0xFF161616);
  static const Color _card = Color(0xFF1E1E1E);
  static const Color _orange = Color(0xFFF6A10C);
  static const Color _red = Color(0xFFC23B30);
  static const Color _text = Colors.white;
  static const Color _textMute = Color(0xFF9FB0C8);

  Category? _selectedCategory;
  Category? _selectedSubcategory;
  List<ItemModel.Item> _items = [];
  bool _isLoading = false;
  String? _error;
  PaginationInfo? _pagination;

  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  // Category sidebar state
  bool _showCategorySidebar = false;

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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 240) {
      _loadMoreItems();
    }
  }

  // ─── Data Loading ────────────────────────────────────────
  Future<void> _loadCategoryItems({bool isLoadMore = false}) async {
    if (!mounted) return;

    if (!isLoadMore) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final categoryId = _selectedSubcategory?.categoryId ?? _selectedCategory!.categoryId;
      if (widget.businessId == null) {
        throw Exception('businessId is required to load categories');
      }
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
            if (!isLoadMore) _items = [];
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
    if (_isLoading || _isLoadingMore || _pagination == null || !_pagination!.hasNextPage) return;
    await _loadCategoryItems(isLoadMore: true);
  }

  void _onCategoryChanged(Category cat) {
    if (_selectedCategory?.categoryId == cat.categoryId) return;
    setState(() {
      _selectedCategory = cat;
      _selectedSubcategory = null;
      _showCategorySidebar = false;
    });
    _scrollToTop();
    _loadCategoryItems();
  }

  void _onSubcategorySelected(Category? subcategory) {
    if (_selectedSubcategory == subcategory) return;
    setState(() => _selectedSubcategory = subcategory);
    _scrollToTop();
    _loadCategoryItems();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  U I
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final hasSubcategories = _selectedCategory != null && _selectedCategory!.hasSubcategories;
    final hasMultipleCategories = widget.allCategories.length > 1;

    return Scaffold(
      backgroundColor: _bgDeep,
      extendBodyBehindAppBar: true,
      floatingActionButton: const CartFloatingButton(),
      body: Stack(
        children: [
          _background(),
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──
                _topBar(),
                // ── Category switch row (if multiple) ──
                if (hasMultipleCategories) _categorySwitcherRow(),
                // ── Subcategory chips ──
                if (hasSubcategories) _subcategoryChips(),
                // ── Items count + info ──
                _infoRow(),
                // ── Grid body ──
                Expanded(child: _body()),
              ],
            ),
          ),
          // ── Category sidebar overlay ──
          if (_showCategorySidebar) _categorySidebar(),
        ],
      ),
    );
  }

  // ─── Background ──────────────────────────────────────────
  Widget _background() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgDeep],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.5, -0.8),
              radius: 1.6,
              colors: [Colors.white.withValues(alpha: 0.03), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Top bar ─────────────────────────────────────────────
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              widget.sectionTitle ?? _selectedCategory?.name ?? 'Каталог',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: _textMute, size: 22),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchPage())),
          ),
        ],
      ),
    );
  }

  // ─── Category switcher row ───────────────────────────────
  Widget _categorySwitcherRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: GestureDetector(
        onTap: () => setState(() => _showCategorySidebar = !_showCategorySidebar),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.category_rounded, color: _orange, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedCategory?.name ?? 'Каталог',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${widget.allCategories.length} кат.',
                style: TextStyle(color: _textMute.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _showCategorySidebar ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more_rounded, color: _textMute, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Category sidebar (dropdown overlay) ─────────────────
  Widget _categorySidebar() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showCategorySidebar = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 110, 16, 0),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.55,
                    ),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 12))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shrinkWrap: true,
                        itemCount: widget.allCategories.length,
                        itemBuilder: (_, i) {
                          final cat = widget.allCategories[i];
                          final selected = cat.categoryId == _selectedCategory?.categoryId;
                          return InkWell(
                            onTap: () => _onCategoryChanged(cat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              color: selected ? _orange.withValues(alpha: 0.1) : Colors.transparent,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: selected ? _orange : Colors.white.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      cat.name,
                                      style: TextStyle(
                                        color: selected ? _orange : _text,
                                        fontSize: 15,
                                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (cat.hasSubcategories)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(
                                        '${cat.subcategories.length}',
                                        style: TextStyle(color: _textMute.withValues(alpha: 0.6), fontSize: 12),
                                      ),
                                    ),
                                  if (cat.itemsCount > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(
                                        '${cat.getTotalItemsCount()}',
                                        style: TextStyle(color: _textMute.withValues(alpha: 0.5), fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Subcategory chips ───────────────────────────────────
  Widget _subcategoryChips() {
    final subs = _selectedCategory?.subcategories ?? [];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: subs.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            if (i == 0) {
              return _chip(
                label: 'Все',
                selected: _selectedSubcategory == null,
                onTap: () => _onSubcategorySelected(null),
              );
            }
            final sub = subs[i - 1];
            return _chip(
              label: sub.name,
              selected: _selectedSubcategory?.categoryId == sub.categoryId,
              onTap: () => _onSubcategorySelected(sub),
              count: sub.itemsCount > 0 ? sub.itemsCount : null,
            );
          },
        ),
      ),
    );
  }

  Widget _chip({required String label, required bool selected, required VoidCallback onTap, int? count}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _orange : _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _orange : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : _text,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.black.withValues(alpha: 0.6) : _textMute.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Info row ────────────────────────────────────────────
  Widget _infoRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _selectedSubcategory?.name ?? _selectedCategory?.name ?? 'Все товары',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          if (!_isLoading && _items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_items.length} шт.',
                style: TextStyle(color: _textMute.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Main body ───────────────────────────────────────────
  Widget _body() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(color: _orange, strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text('Загрузка...', style: TextStyle(color: _textMute.withValues(alpha: 0.7), fontSize: 14)),
          ],
        ),
      );
    }

    if (_error != null) {
      return _errorState();
    }

    if (_items.isEmpty) {
      return _emptyState();
    }

    return RefreshIndicator(
      color: _orange,
      backgroundColor: _card,
      onRefresh: () => _loadCategoryItems(),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.56,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: _orange, strokeWidth: 2.5),
              ),
            );
          }
          return ProductCard(item: _items[index]);
        },
      ),
    );
  }

  // ─── Error state ─────────────────────────────────────────
  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: _red, size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              _error!,
              style: const TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => _loadCategoryItems(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Повторить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty state ─────────────────────────────────────────
  Widget _emptyState() {
    final label = _selectedSubcategory?.name ?? _selectedCategory?.name ?? 'категории';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inventory_2_outlined, color: _textMute.withValues(alpha: 0.5), size: 30),
            ),
            const SizedBox(height: 18),
            const Text(
              'Товары не найдены',
              style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'В "$label" пока нет товаров',
              style: TextStyle(color: _textMute.withValues(alpha: 0.7), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
