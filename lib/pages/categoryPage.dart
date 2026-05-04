import 'package:flutter/material.dart';
import 'package:naliv_delivery/utils/cartFloatingButton.dart';
import '../utils/api.dart';
import '../utils/responsive.dart';
import '../shared/product_card.dart';
import '../model/item.dart' as ItemModel;
import 'search_page.dart';

class _CategoryItemsCacheEntry {
  const _CategoryItemsCacheEntry({
    required this.items,
    required this.pagination,
    required this.storedAt,
  });

  final List<ItemModel.Item> items;
  final PaginationInfo? pagination;
  final DateTime storedAt;
}

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
  static const Duration _cacheTtl = Duration(minutes: 5);
  static final Map<String, _CategoryItemsCacheEntry> _categoryItemsCache =
      <String, _CategoryItemsCacheEntry>{};

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
  int _selectionVersion = 0;

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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      _loadMoreItems();
    }
  }

  String _cacheKey({
    required int businessId,
    required int categoryId,
    required int page,
  }) {
    return '$businessId:$categoryId:$page';
  }

  _CategoryItemsCacheEntry? _getCachedCategoryItems(String key) {
    final cached = _categoryItemsCache[key];
    if (cached == null) return null;

    if (DateTime.now().difference(cached.storedAt) > _cacheTtl) {
      _categoryItemsCache.remove(key);
      return null;
    }

    return cached;
  }

  void _storeCachedCategoryItems({
    required String key,
    required List<ItemModel.Item> items,
    required PaginationInfo? pagination,
  }) {
    _categoryItemsCache[key] = _CategoryItemsCacheEntry(
      items: List<ItemModel.Item>.from(items),
      pagination: pagination,
      storedAt: DateTime.now(),
    );
  }

  bool _matchesSelectionSnapshot({
    required int version,
    required int categoryId,
    required int? subcategoryId,
  }) {
    return version == _selectionVersion &&
        _selectedCategory?.categoryId == categoryId &&
        _selectedSubcategory?.categoryId == subcategoryId;
  }

  // ─── Data Loading ────────────────────────────────────────
  Future<void> _loadCategoryItems({bool isLoadMore = false}) async {
    if (!mounted) return;

    final selectedCategory = _selectedCategory;
    if (selectedCategory == null) return;

    final requestedCategoryId = selectedCategory.categoryId;
    final requestedSubcategoryId = _selectedSubcategory?.categoryId;
    final requestVersion = _selectionVersion;
    final requestedPage = isLoadMore ? (_pagination?.page ?? 0) + 1 : 1;
    final businessId = widget.businessId;
    final effectiveCategoryId = requestedSubcategoryId ?? requestedCategoryId;

    if (businessId == null) {
      if (!isLoadMore) {
        setState(() {
          _isLoading = false;
          _error =
              'Ошибка загрузки товаров: businessId is required to load categories';
        });
      }
      return;
    }

    final cacheKey = _cacheKey(
      businessId: businessId,
      categoryId: effectiveCategoryId,
      page: requestedPage,
    );
    final cached = _getCachedCategoryItems(cacheKey);

    if (!isLoadMore) {
      setState(() {
        _isLoading = true;
        _error = null;
        _items = [];
        _pagination = null;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    if (cached != null) {
      if (mounted &&
          _matchesSelectionSnapshot(
            version: requestVersion,
            categoryId: requestedCategoryId,
            subcategoryId: requestedSubcategoryId,
          )) {
        setState(() {
          if (isLoadMore) {
            _items.addAll(List<ItemModel.Item>.from(cached.items));
          } else {
            _items = List<ItemModel.Item>.from(cached.items);
          }
          _pagination = cached.pagination;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
      return;
    }

    try {
      final response = await ApiService.getCategoryItemsTyped(
        effectiveCategoryId,
        businessId: businessId,
        page: requestedPage,
        limit: 5000,
      );

      if (mounted &&
          _matchesSelectionSnapshot(
            version: requestVersion,
            categoryId: requestedCategoryId,
            subcategoryId: requestedSubcategoryId,
          )) {
        setState(() {
          if (response != null) {
            final convertedItems = response.data.items
                .map((categoryItem) =>
                    ItemModel.Item.fromCategoryItem(categoryItem))
                .toList();
            _storeCachedCategoryItems(
              key: cacheKey,
              items: convertedItems,
              pagination: response.data.pagination,
            );
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
      if (mounted &&
          _matchesSelectionSnapshot(
            version: requestVersion,
            categoryId: requestedCategoryId,
            subcategoryId: requestedSubcategoryId,
          )) {
        setState(() {
          _error = 'Ошибка загрузки товаров: $e';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoading ||
        _isLoadingMore ||
        _pagination == null ||
        !_pagination!.hasNextPage) return;
    await _loadCategoryItems(isLoadMore: true);
  }

  void _onCategoryChanged(Category cat) {
    if (_selectedCategory?.categoryId == cat.categoryId) return;
    setState(() {
      _selectionVersion++;
      _selectedCategory = cat;
      _selectedSubcategory = null;
      _showCategorySidebar = false;
      _items = [];
      _pagination = null;
      _error = null;
    });
    _scrollToTop();
    _loadCategoryItems();
  }

  void _onSubcategorySelected(Category? subcategory) {
    if (_selectedSubcategory == subcategory) return;
    setState(() {
      _selectionVersion++;
      _selectedSubcategory = subcategory;
      _items = [];
      _pagination = null;
      _error = null;
    });
    _scrollToTop();
    _loadCategoryItems();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  U I
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final hasSubcategories =
        _selectedCategory != null && _selectedCategory!.hasSubcategories;
    final hasMultipleCategories = widget.allCategories.length > 1;

    return Scaffold(
      backgroundColor: _bgDeep,
      extendBodyBehindAppBar: true,
      floatingActionButton: CartFloatingButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
              colors: [
                Colors.white.withValues(alpha: 0.03),
                Colors.transparent
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Top bar ─────────────────────────────────────────────
  Widget _topBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.s, 4.s, 7.s, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: _text, size: 18.s),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              widget.sectionTitle ?? _selectedCategory?.name ?? 'Каталог',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: _text, fontSize: 18.sp, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            icon: Icon(Icons.search_rounded, color: _textMute, size: 20.s),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SearchPage())),
          ),
        ],
      ),
    );
  }

  // ─── Category switcher row ───────────────────────────────
  Widget _categorySwitcherRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.s, 7.s, 14.s, 4.s),
      child: GestureDetector(
        onTap: () =>
            setState(() => _showCategorySidebar = !_showCategorySidebar),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 10.s),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12.s),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 25.s,
                height: 25.s,
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7.s),
                ),
                child: Icon(Icons.category_rounded, color: _orange, size: 14.s),
              ),
              SizedBox(width: 10.s),
              Expanded(
                child: Text(
                  _selectedCategory?.name ?? 'Каталог',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: _text,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${widget.allCategories.length} кат.',
                style: TextStyle(
                    color: _textMute.withValues(alpha: 0.7),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(width: 7.s),
              AnimatedRotation(
                turns: _showCategorySidebar ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more_rounded,
                    color: _textMute, size: 18.s),
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
                padding: EdgeInsets.fromLTRB(14.s, 100.s, 14.s, 0),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.55,
                    ),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16.s),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 24,
                            offset: const Offset(0, 12))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.s),
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 7.s),
                        shrinkWrap: true,
                        itemCount: widget.allCategories.length,
                        itemBuilder: (_, i) {
                          final cat = widget.allCategories[i];
                          final selected =
                              cat.categoryId == _selectedCategory?.categoryId;
                          return InkWell(
                            onTap: () => _onCategoryChanged(cat),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.s, vertical: 12.s),
                              color: selected
                                  ? _orange.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              child: Row(
                                children: [
                                  Container(
                                    width: 7.s,
                                    height: 7.s,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? _orange
                                          : Colors.white
                                              .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 12.s),
                                  Expanded(
                                    child: Text(
                                      cat.name,
                                      style: TextStyle(
                                        color: selected ? _orange : _text,
                                        fontSize: 14.sp,
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (cat.hasSubcategories)
                                    Padding(
                                      padding: EdgeInsets.only(left: 7.s),
                                      child: Text(
                                        '${cat.subcategories.length}',
                                        style: TextStyle(
                                            color: _textMute.withValues(
                                                alpha: 0.6),
                                            fontSize: 11.sp),
                                      ),
                                    ),
                                  if (cat.itemsCount > 0)
                                    Padding(
                                      padding: EdgeInsets.only(left: 7.s),
                                      child: Text(
                                        '${cat.getTotalItemsCount()}',
                                        style: TextStyle(
                                            color: _textMute.withValues(
                                                alpha: 0.5),
                                            fontSize: 11.sp),
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
      padding: EdgeInsets.only(top: 7.s),
      child: SizedBox(
        height: 38.s,
        child: ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 14.s),
          scrollDirection: Axis.horizontal,
          itemCount: subs.length + 1,
          separatorBuilder: (_, __) => SizedBox(width: 7.s),
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

  Widget _chip(
      {required String label,
      required bool selected,
      required VoidCallback onTap,
      int? count}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 9.s),
        decoration: BoxDecoration(
          color: selected ? _orange : _card,
          borderRadius: BorderRadius.circular(11.s),
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
                fontSize: 12.sp,
              ),
            ),
            if (count != null) ...[
              SizedBox(width: 5.s),
              Text(
                '$count',
                style: TextStyle(
                  color: selected
                      ? Colors.black.withValues(alpha: 0.6)
                      : _textMute.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                  fontSize: 10.sp,
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
      padding: EdgeInsets.fromLTRB(14.s, 10.s, 14.s, 7.s),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _selectedSubcategory?.name ??
                  _selectedCategory?.name ??
                  'Все товары',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: _text, fontSize: 15.sp, fontWeight: FontWeight.w800),
            ),
          ),
          if (!_isLoading && _items.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9.s, vertical: 4.s),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(7.s),
              ),
              child: Text(
                '${_items.length} шт.',
                style: TextStyle(
                    color: _textMute.withValues(alpha: 0.8),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600),
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
            Text('Загрузка...',
                style: TextStyle(
                    color: _textMute.withValues(alpha: 0.7), fontSize: 14)),
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
        padding: EdgeInsets.fromLTRB(14.s, 4.s, 14.s, 120.s),
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.56,
          crossAxisSpacing: 9.s,
          mainAxisSpacing: 9.s,
        ),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child:
                    CircularProgressIndicator(color: _orange, strokeWidth: 2.5),
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
        padding: EdgeInsets.all(28.s),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58.s,
              height: 58.s,
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, color: _red, size: 28.s),
            ),
            SizedBox(height: 16.s),
            Text(
              _error!,
              style: TextStyle(
                  color: _text, fontSize: 14.sp, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.s),
            ElevatedButton.icon(
              onPressed: () => _loadCategoryItems(),
              icon: Icon(Icons.refresh_rounded, size: 16.s),
              label: const Text('Повторить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11.s)),
                padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 10.s),
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
    final label =
        _selectedSubcategory?.name ?? _selectedCategory?.name ?? 'категории';
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.s),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58.s,
              height: 58.s,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inventory_2_outlined,
                  color: _textMute.withValues(alpha: 0.5), size: 27.s),
            ),
            SizedBox(height: 16.s),
            Text(
              'Товары не найдены',
              style: TextStyle(
                  color: _text, fontSize: 15.sp, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 7.s),
            Text(
              'В "$label" пока нет товаров',
              style: TextStyle(
                  color: _textMute.withValues(alpha: 0.7), fontSize: 13.sp),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
