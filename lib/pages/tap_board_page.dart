import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradusy24/utils/cartFloatingButton.dart';

import '../globals.dart' as globals;
import '../model/item.dart' as item_model;
import '../models/cart_item.dart';
import '../shared/app_theme.dart';
import '../utils/api.dart';
import '../utils/bonus_rules.dart';
import '../utils/business_provider.dart';
import '../utils/cart_provider.dart';
import '../utils/item_name_presentation.dart';
import '../utils/liked_items_provider.dart';
import '../utils/liked_storage_service.dart';
import '../utils/responsive.dart';
import 'product_detail_page.dart';
import 'search_page.dart';

class _TapBoardItemsCacheEntry {
  const _TapBoardItemsCacheEntry({
    required this.items,
    required this.pagination,
    required this.storedAt,
  });

  final List<item_model.Item> items;
  final PaginationInfo? pagination;
  final DateTime storedAt;
}

class TapBoardPage extends StatefulWidget {
  final Category category;
  final List<Category> allCategories;
  final int? businessId;
  final String? sectionTitle;

  const TapBoardPage({
    super.key,
    required this.category,
    required this.allCategories,
    this.businessId,
    this.sectionTitle,
  });

  @override
  State<TapBoardPage> createState() => _TapBoardPageState();
}

class _TapBoardPageState extends State<TapBoardPage> {
  static const Duration _cacheTtl = Duration(minutes: 5);
  static final Map<String, _TapBoardItemsCacheEntry> _categoryItemsCache = <String, _TapBoardItemsCacheEntry>{};

  List<item_model.Item> _items = <item_model.Item>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  PaginationInfo? _pagination;

  Category? _selectedCategory;
  Category? _selectedSubcategory;
  int _selectionVersion = 0;
  bool _showCategorySidebar = false;

  final ScrollController _scrollController = ScrollController();

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

  String _cacheKey({
    required int businessId,
    required int categoryId,
    required int page,
  }) {
    return '$businessId:$categoryId:$page';
  }

  _TapBoardItemsCacheEntry? _getCachedCategoryItems(String key) {
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
    required List<item_model.Item> items,
    required PaginationInfo? pagination,
  }) {
    _categoryItemsCache[key] = _TapBoardItemsCacheEntry(
      items: List<item_model.Item>.from(items),
      pagination: pagination,
      storedAt: DateTime.now(),
    );
  }

  bool _matchesSelectionSnapshot({
    required int version,
    required int categoryId,
    required int? subcategoryId,
  }) {
    return version == _selectionVersion && _selectedCategory?.categoryId == categoryId && _selectedSubcategory?.categoryId == subcategoryId;
  }

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
          _error = 'Ошибка загрузки товаров: businessId is required to load categories';
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
        _isLoadingMore = false;
        _error = null;
        _items = <item_model.Item>[];
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
            _items.addAll(List<item_model.Item>.from(cached.items));
          } else {
            _items = List<item_model.Item>.from(cached.items);
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
            final convertedItems = response.data.items.map((categoryItem) => item_model.Item.fromCategoryItem(categoryItem)).toList();
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
          } else if (!isLoadMore) {
            _items = <item_model.Item>[];
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
    if (_isLoading || _isLoadingMore || _pagination == null || !_pagination!.hasNextPage) return;
    await _loadCategoryItems(isLoadMore: true);
  }

  void _onCategoryChanged(Category category) {
    if (_selectedCategory?.categoryId == category.categoryId) return;
    setState(() {
      _selectionVersion++;
      _selectedCategory = category;
      _selectedSubcategory = null;
      _showCategorySidebar = false;
      _items = <item_model.Item>[];
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
      _items = <item_model.Item>[];
      _pagination = null;
      _error = null;
    });
    _scrollToTop();
    _loadCategoryItems();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  bool _hasActivePromotions(item_model.Item item) {
    return (item.promotions ?? const <item_model.ItemPromotion>[]).any((promotion) => promotion.isActive);
  }

  bool _isItemAvailable(item_model.Item item) {
    return item.amount == null || item.amount! > 0;
  }

  int _maxDiscountPercent(item_model.Item item) {
    var best = 0;
    for (final promotion in item.promotions ?? const <item_model.ItemPromotion>[]) {
      if (!promotion.isActive) continue;
      final isDiscountType = promotion.discountType == 'PERCENT' || promotion.discountType == 'FIXED';
      if (!isDiscountType || promotion.discountValue <= 0) continue;
      final effective = promotion.calculateEffectiveDiscountPercent(item.price);
      if (effective > best) best = effective;
    }
    return best;
  }

  List<item_model.Item> _orderedItems() {
    final indexed = _items.asMap().entries.toList(growable: false);
    indexed.sort((a, b) {
      final aHasPromo = _hasActivePromotions(a.value);
      final bHasPromo = _hasActivePromotions(b.value);
      if (aHasPromo != bHasPromo) {
        return aHasPromo ? -1 : 1;
      }

      final aAvailable = _isItemAvailable(a.value);
      final bAvailable = _isItemAvailable(b.value);
      if (aAvailable != bAvailable) {
        return aAvailable ? -1 : 1;
      }

      final discountCompare = _maxDiscountPercent(b.value).compareTo(_maxDiscountPercent(a.value));
      if (discountCompare != 0) {
        return discountCompare;
      }

      return a.key.compareTo(b.key);
    });

    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final hasSubcategories = _selectedCategory != null && _selectedCategory!.hasSubcategories;
    final hasMultipleCategories = widget.allCategories.length > 1;
    final orderedItems = _orderedItems();

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      floatingActionButton: const CartFloatingButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                if (hasMultipleCategories) _categorySwitcherRow(),
                if (hasSubcategories) _subcategoryChips(),
                Expanded(child: _body(orderedItems)),
              ],
            ),
          ),
          if (_showCategorySidebar) _categorySidebar(),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.s, 4.s, 7.s, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.text, size: 18.s),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              widget.sectionTitle ?? 'Сегодня на кране',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.text, fontSize: 18.sp, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            icon: Icon(Icons.search_rounded, color: AppColors.textMute, size: 20.s),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchPage())),
          ),
        ],
      ),
    );
  }

  Widget _categorySwitcherRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.s, 7.s, 14.s, 4.s),
      child: GestureDetector(
        onTap: () => setState(() => _showCategorySidebar = !_showCategorySidebar),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 10.s),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12.s),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 25.s,
                height: 25.s,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7.s),
                ),
                child: Icon(Icons.sports_bar_rounded, color: AppColors.orange, size: 14.s),
              ),
              SizedBox(width: 10.s),
              Expanded(
                child: Text(
                  _selectedCategory?.name ?? 'Сегодня на кране',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.text, fontSize: 14.sp, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${widget.allCategories.length} раздела',
                style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.7), fontSize: 11.sp, fontWeight: FontWeight.w600),
              ),
              SizedBox(width: 7.s),
              AnimatedRotation(
                turns: _showCategorySidebar ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more_rounded, color: AppColors.textMute, size: 18.s),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16.s),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 12))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.s),
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 7.s),
                        shrinkWrap: true,
                        itemCount: widget.allCategories.length,
                        itemBuilder: (_, index) {
                          final category = widget.allCategories[index];
                          final selected = category.categoryId == _selectedCategory?.categoryId;
                          return InkWell(
                            onTap: () => _onCategoryChanged(category),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 12.s),
                              color: selected ? AppColors.orange.withValues(alpha: 0.1) : Colors.transparent,
                              child: Row(
                                children: [
                                  Container(
                                    width: 7.s,
                                    height: 7.s,
                                    decoration: BoxDecoration(
                                      color: selected ? AppColors.orange : Colors.white.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 12.s),
                                  Expanded(
                                    child: Text(
                                      category.name,
                                      style: TextStyle(
                                        color: selected ? AppColors.orange : AppColors.text,
                                        fontSize: 14.sp,
                                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (category.hasSubcategories)
                                    Padding(
                                      padding: EdgeInsets.only(left: 7.s),
                                      child: Text(
                                        '${category.subcategories.length}',
                                        style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.6), fontSize: 11.sp),
                                      ),
                                    ),
                                  if (category.itemsCount > 0)
                                    Padding(
                                      padding: EdgeInsets.only(left: 7.s),
                                      child: Text(
                                        '${category.getTotalItemsCount()}',
                                        style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.5), fontSize: 11.sp),
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

  Widget _subcategoryChips() {
    final subcategories = _selectedCategory?.subcategories ?? <Category>[];
    return Padding(
      padding: EdgeInsets.only(top: 7.s),
      child: SizedBox(
        height: 38.s,
        child: ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: 14.s),
          scrollDirection: Axis.horizontal,
          itemCount: subcategories.length + 1,
          separatorBuilder: (_, __) => SizedBox(width: 7.s),
          itemBuilder: (_, index) {
            if (index == 0) {
              return _chip(
                label: 'Все',
                selected: _selectedSubcategory == null,
                onTap: () => _onSubcategorySelected(null),
              );
            }

            final subcategory = subcategories[index - 1];
            return _chip(
              label: subcategory.name,
              selected: _selectedSubcategory?.categoryId == subcategory.categoryId,
              onTap: () => _onSubcategorySelected(subcategory),
              count: subcategory.itemsCount > 0 ? subcategory.itemsCount : null,
            );
          },
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int? count,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 9.s),
        decoration: BoxDecoration(
          color: selected ? AppColors.orange : AppColors.card,
          borderRadius: BorderRadius.circular(11.s),
          border: Border.all(color: selected ? AppColors.orange : Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : AppColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 12.sp,
              ),
            ),
            if (count != null) ...[
              SizedBox(width: 5.s),
              Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.black.withValues(alpha: 0.6) : AppColors.textMute.withValues(alpha: 0.6),
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

  Widget _body(List<item_model.Item> orderedItems) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text('Загружаем витрину...', style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.7), fontSize: 14)),
          ],
        ),
      );
    }

    if (_error != null) {
      return _errorState();
    }

    if (orderedItems.isEmpty) {
      return _emptyState();
    }

    return RefreshIndicator(
      color: AppColors.orange,
      backgroundColor: AppColors.card,
      onRefresh: () => _loadCategoryItems(),
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(0, 6.s, 0, 120.s),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: orderedItems.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => Divider(
          color: Colors.white.withValues(alpha: 0.06),
          height: 1,
          indent: 14.s,
          endIndent: 14.s,
        ),
        itemBuilder: (context, index) {
          if (index == orderedItems.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 18.s),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 2.5),
              ),
            );
          }

          return _TapBoardItemRow(item: orderedItems[index]);
        },
      ),
    );
  }

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
                color: AppColors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, color: AppColors.red, size: 28.s),
            ),
            SizedBox(height: 16.s),
            Text(
              _error!,
              style: TextStyle(color: AppColors.text, fontSize: 14.sp, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.s),
            ElevatedButton.icon(
              onPressed: () => _loadCategoryItems(),
              icon: Icon(Icons.refresh_rounded, size: 16.s),
              label: const Text('Повторить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11.s)),
                padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 10.s),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    final label = _selectedSubcategory?.name ?? _selectedCategory?.name ?? 'категории';
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
              child: Icon(Icons.sports_bar_rounded, color: AppColors.textMute.withValues(alpha: 0.5), size: 27.s),
            ),
            SizedBox(height: 16.s),
            Text(
              'Пока пусто',
              style: TextStyle(color: AppColors.text, fontSize: 15.sp, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 7.s),
            Text(
              'В "$label" пока нет товаров',
              style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.7), fontSize: 13.sp),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TapBoardItemRow extends StatefulWidget {
  final item_model.Item item;

  const _TapBoardItemRow({
    required this.item,
  });

  @override
  State<_TapBoardItemRow> createState() => _TapBoardItemRowState();
}

class _TapBoardItemRowState extends State<_TapBoardItemRow> {
  bool _likeInProgress = false;
  bool? _isLikedOverride;
  int? _businessId;

  bool get _isLiked => _isLikedOverride ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final businessId = businessProvider.selectedBusinessId;
    if (businessId != null && businessId != _businessId) {
      _businessId = businessId;
      _initLikeState(businessId);
    }
  }

  Future<void> _initLikeState(int businessId) async {
    final likedProvider = Provider.of<LikedItemsProvider>(context, listen: false);
    final providerLiked = likedProvider.isLiked(businessId, widget.item.itemId);
    if (providerLiked) {
      _isLikedOverride = true;
      setState(() {});
      return;
    }

    final liked = await LikedStorageService.isLiked(
      businessId: businessId,
      itemId: widget.item.itemId,
    );
    if (mounted) {
      setState(() => _isLikedOverride = liked);
      if (liked) {
        likedProvider.updateLike(businessId, widget.item.itemId, true);
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_likeInProgress) return;
    setState(() => _likeInProgress = true);
    final likedProvider = Provider.of<LikedItemsProvider>(context, listen: false);
    try {
      final newValue = await ApiService.toggleLikeItem(widget.item.itemId);
      if (newValue != null && mounted) {
        setState(() => _isLikedOverride = newValue);
        if (_businessId != null) {
          LikedStorageService.setLiked(
            businessId: _businessId!,
            itemId: widget.item.itemId,
            liked: newValue,
          );
          likedProvider.updateLike(_businessId!, widget.item.itemId, newValue);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _likeInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final itemTitle = presentItemName(
      rawName: item.name,
      categoryName: item.category?.name,
    );
    final isWeightItem = _isWeightUnit(item.unit);
    final portionWeight = _resolvePortionWeight(item);
    final activePromotions = _activePromotions(item);
    final discountPromo = _primaryDiscountPromo(activePromotions);
    final subtractPromotions = _subtractPromotions(activePromotions);
    final hasDiscount = discountPromo != null;
    final discountedPrice = discountPromo?.calculateDiscountedPrice(item.price) ?? item.price;
    final discountPercent = discountPromo?.calculateEffectiveDiscountPercent(item.price) ?? 0;
    final isOutOfStock = item.amount != null && item.amount! <= 0;
    final isLowStock = !isOutOfStock && item.amount != null && item.amount! > 0 && item.amount! <= 5;
    final bonusPoints = isOutOfStock ? 0 : _calculateBonusPoints(item, discountedPrice);
    final portionPrice = isWeightItem && portionWeight > 0 ? discountedPrice * portionWeight : null;
    final oldPrice = hasDiscount ? (portionPrice != null ? item.price * portionWeight : item.price) : null;
    final mainPrice = portionPrice ?? discountedPrice;
    final savingsAmount = hasDiscount ? (item.price - discountedPrice) * (isWeightItem && portionWeight > 0 ? portionWeight : 1) : 0.0;
    final portionLabel = isWeightItem && portionWeight > 0 ? globals.formatQuantity(portionWeight, item.unit ?? 'кг') : null;

    final subtitleParts = <String>[];
    if (itemTitle.type != null) subtitleParts.add(itemTitle.type!);
    if (itemTitle.countryName != null) {
      subtitleParts.add(itemTitle.countryName!);
    }
    if (itemTitle.pricingAttributes.isNotEmpty) {
      subtitleParts.add(itemTitle.pricingAttributes.first);
    }
    final subtitle = subtitleParts.join(' · ');

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailPage(item: item)),
      ),
      child: Opacity(
        opacity: isOutOfStock ? 0.5 : 1.0,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 10.s),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _imageTile(
                item,
                size: 72.s,
                hasDiscount: hasDiscount,
                discountPercent: discountPercent,
              ),
              SizedBox(width: 12.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            itemTitle.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                        SizedBox(width: 10.s),
                        _priceBlock(
                          mainPrice: mainPrice,
                          oldPrice: oldPrice,
                          hasDiscount: hasDiscount,
                          portionLabel: portionLabel,
                          isWeightItem: isWeightItem,
                          discountedPrice: discountedPrice,
                          savingsAmount: savingsAmount,
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 3.s),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textMute.withValues(alpha: 0.65),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    SizedBox(height: 8.s),
                    Row(
                      children: [
                        Expanded(
                          child: _tagLine(
                            hasDiscount: hasDiscount,
                            discountPercent: discountPercent,
                            subtractPromotions: subtractPromotions,
                            isOutOfStock: isOutOfStock,
                            isLowStock: isLowStock,
                            bonusPoints: bonusPoints,
                            hasOptions: item.hasOptions,
                            item: item,
                          ),
                        ),
                        SizedBox(width: 8.s),
                        SizedBox(
                          width: 104.s,
                          child: _cartSection(item),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageTile(
    item_model.Item item, {
    required double size,
    required bool hasDiscount,
    required int discountPercent,
  }) {
    return SizedBox(
      width: size,
      height: size + 8.s,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14.s),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors:
                        item.hasImage ? const [Color(0xFFF4F1ED), Color(0xFFE2D7CA)] : [AppColors.cardDark, AppColors.blue.withValues(alpha: 0.9)],
                  ),
                ),
                child: item.hasImage
                    ? Image.network(
                        item.image!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(Icons.inventory_2_outlined, color: AppColors.textMute, size: 28.s),
                        ),
                      )
                    : Center(
                        child: Icon(Icons.inventory_2_outlined, color: AppColors.textMute, size: 28.s),
                      ),
              ),
            ),
          ),
          if (hasDiscount && discountPercent > 0)
            Positioned(
              top: 5.s,
              left: 5.s,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.s, vertical: 3.s),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(7.s),
                ),
                child: Text(
                  '-$discountPercent%',
                  style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.w900, height: 1.0),
                ),
              ),
            ),
          Positioned(
            top: 5.s,
            right: 5.s,
            child: GestureDetector(
              onTap: _toggleLike,
              child: Container(
                width: 26.s,
                height: 26.s,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 13.s,
                  color: _isLiked ? AppColors.red : Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceBlock({
    required double mainPrice,
    required double? oldPrice,
    required bool hasDiscount,
    required String? portionLabel,
    required bool isWeightItem,
    required double discountedPrice,
    required double savingsAmount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasDiscount && oldPrice != null)
          Text(
            '${_formatPrice(oldPrice)} ₸',
            style: TextStyle(
              fontSize: 10.sp,
              color: AppColors.textMute.withValues(alpha: 0.5),
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.textMute.withValues(alpha: 0.4),
              height: 1.1,
            ),
          ),
        Text(
          '${_formatPrice(mainPrice)} ₸',
          style: TextStyle(
            color: hasDiscount ? AppColors.orange : AppColors.text,
            fontSize: 16.sp,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        if (portionLabel != null)
          Text(
            'за $portionLabel',
            style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.7), fontSize: 9.sp, fontWeight: FontWeight.w600),
          ),
        if (isWeightItem)
          Text(
            '${_formatPrice(discountedPrice)} ₸/кг',
            style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.6), fontSize: 9.sp, fontWeight: FontWeight.w600),
          ),
        if (hasDiscount && savingsAmount >= 1)
          Text(
            '−${_formatPrice(savingsAmount)} ₸',
            style: TextStyle(color: AppColors.orange, fontSize: 9.sp, fontWeight: FontWeight.w700),
          ),
      ],
    );
  }

  Widget _tagLine({
    required bool hasDiscount,
    required int discountPercent,
    required List<item_model.ItemPromotion> subtractPromotions,
    required bool isOutOfStock,
    required bool isLowStock,
    required int bonusPoints,
    required bool hasOptions,
    required item_model.Item item,
  }) {
    final spans = <InlineSpan>[];

    if (hasDiscount && discountPercent > 0) {
      spans.add(TextSpan(
        text: '-$discountPercent%',
        style: TextStyle(color: AppColors.red, fontSize: 10.sp, fontWeight: FontWeight.w800),
      ));
    }

    for (final promo in subtractPromotions) {
      _appendSeparator(spans);
      spans.add(TextSpan(
        text: _subtractPromoLabel(promo),
        style: TextStyle(color: AppColors.orange, fontSize: 10.sp, fontWeight: FontWeight.w800),
      ));
    }

    if (isOutOfStock) {
      _appendSeparator(spans);
      spans.add(TextSpan(
        text: 'Нет в наличии',
        style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.7), fontSize: 10.sp, fontWeight: FontWeight.w600),
      ));
    } else if (isLowStock) {
      _appendSeparator(spans);
      spans.add(TextSpan(
        text: 'Мало',
        style: TextStyle(color: AppColors.orange, fontSize: 10.sp, fontWeight: FontWeight.w700),
      ));
    }

    if (bonusPoints > 0) {
      _appendSeparator(spans);
      spans.add(TextSpan(
        text: '★ $bonusPoints',
        style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.7), fontSize: 10.sp, fontWeight: FontWeight.w600),
      ));
    }

    if (hasOptions) {
      _appendSeparator(spans);
      spans.add(TextSpan(
        text: _compactOptionsLabel(item),
        style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.7), fontSize: 10.sp, fontWeight: FontWeight.w600),
      ));
    }

    if (spans.isEmpty) return const SizedBox.shrink();

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }

  void _appendSeparator(List<InlineSpan> spans) {
    if (spans.isNotEmpty) {
      spans.add(TextSpan(
        text: ' · ',
        style: TextStyle(color: AppColors.textMute.withValues(alpha: 0.35), fontSize: 10.sp),
      ));
    }
  }

  String _compactOptionsLabel(item_model.Item item) {
    if (!item.hasOptions) return '';
    final firstOption = item.options!.first.name.trim();
    if (firstOption.isEmpty) return 'Опции';
    return firstOption;
  }

  List<item_model.ItemPromotion> _activePromotions(item_model.Item item) {
    return (item.promotions ?? const <item_model.ItemPromotion>[]).where((promotion) => promotion.isActive).toList(growable: false);
  }

  item_model.ItemPromotion? _primaryDiscountPromo(List<item_model.ItemPromotion> promotions) {
    for (final promotion in promotions) {
      final isDiscountType = promotion.discountType == 'PERCENT' || promotion.discountType == 'FIXED';
      if (isDiscountType && promotion.discountValue > 0) {
        return promotion;
      }
    }
    return null;
  }

  List<item_model.ItemPromotion> _subtractPromotions(List<item_model.ItemPromotion> promotions) {
    return promotions
        .where((promotion) => promotion.discountType == 'SUBTRACT' && promotion.baseAmount > 0 && promotion.addAmount > 0)
        .toList(growable: false);
  }

  String _subtractPromoLabel(item_model.ItemPromotion promotion) {
    if (promotion.baseAmount > 0 && promotion.addAmount > 0) {
      return '${promotion.baseAmount}+${promotion.addAmount}';
    }
    final fallback = (promotion.description?.trim().isNotEmpty ?? false) ? promotion.description!.trim() : promotion.name.trim();
    return fallback.isEmpty ? 'Промо' : fallback;
  }

  int _calculateBonusPoints(item_model.Item item, double price) {
    if (BonusRules.isBonusExcludedText(
      name: item.name,
      description: item.description,
      categoryName: item.category?.name,
      code: item.code,
    )) {
      return 0;
    }

    return BonusRules.calculateEarnedBonuses(price);
  }

  bool _isWeightUnit(String? unit) {
    final normalized = unit?.toLowerCase().trim();
    if (normalized == null) return false;
    if (normalized.contains('кг') || normalized.contains('kg')) return true;
    if (normalized.contains('шт') || normalized.contains('л')) return false;
    return false;
  }

  double _resolvePortionWeight(item_model.Item item) {
    if (item.quantity != null && item.quantity! > 0) return item.quantity!;
    if (item.stepQuantity != null && item.stepQuantity! > 0) {
      return item.stepQuantity!;
    }
    return item.effectiveStepQuantity;
  }

  Widget _cartSection(item_model.Item item) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        final totalQuantity = cartProvider.getTotalQuantityForItem(item.itemId);
        final isInCart = totalQuantity > 0;
        final num? maxAmount = item.amount;
        final bool canIncrease = maxAmount == null || totalQuantity < maxAmount.toDouble();

        if (isInCart) {
          return _quantityControls(item, cartProvider, totalQuantity, maxAmount, canIncrease);
        }
        return _addToCartButton(item, cartProvider, maxAmount);
      },
    );
  }

  Widget _quantityControls(
    item_model.Item item,
    CartProvider cartProvider,
    double totalQuantity,
    num? maxAmount,
    bool canIncrease,
  ) {
    return Row(
      children: [
        _ctrlButton(
          icon: Icons.remove,
          onPressed: () {
            final variants = cartProvider.getItemVariants(item.itemId);
            if (variants.isNotEmpty) {
              final variant = variants.first;
              double step = variant.stepQuantity;
              for (final selectedVariant in variant.selectedVariants) {
                if (selectedVariant.containsKey('parent_item_amount')) {
                  step = (selectedVariant['parent_item_amount'] as num).toDouble();
                  break;
                }
              }
              cartProvider.updateQuantityWithVariants(item.itemId, variant.selectedVariants, variant.quantity - step);
            }
          },
        ),
        SizedBox(width: 5.s),
        Expanded(
          child: Container(
            height: 32.s,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8.s),
            ),
            child: Center(
              child: Text(
                item.effectiveStepQuantity == 1.0 ? totalQuantity.toStringAsFixed(0) : totalQuantity.toStringAsFixed(2),
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: AppColors.orange),
              ),
            ),
          ),
        ),
        SizedBox(width: 5.s),
        _ctrlButton(
          icon: item.hasOptions ? Icons.settings : Icons.add,
          enabled: canIncrease,
          onPressed: canIncrease
              ? () {
                  if (item.hasOptions) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailPage(item: item)));
                  } else {
                    final variants = cartProvider.getItemVariants(item.itemId);
                    if (variants.isNotEmpty) {
                      final variant = variants.first;
                      double step = variant.stepQuantity;
                      for (final selectedVariant in variant.selectedVariants) {
                        if (selectedVariant.containsKey('parent_item_amount')) {
                          step = (selectedVariant['parent_item_amount'] as num).toDouble();
                          break;
                        }
                      }
                      final target = variant.quantity + step;
                      if (maxAmount != null && target > maxAmount.toDouble()) {
                        cartProvider.updateQuantityWithVariants(item.itemId, variant.selectedVariants, maxAmount.toDouble());
                      } else {
                        cartProvider.updateQuantityWithVariants(item.itemId, variant.selectedVariants, target);
                      }
                    }
                  }
                }
              : null,
        ),
      ],
    );
  }

  Widget _ctrlButton({
    required IconData icon,
    VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return SizedBox(
      width: 32.s,
      height: 32.s,
      child: Material(
        color: enabled ? AppColors.orange : AppColors.cardDark,
        borderRadius: BorderRadius.circular(8.s),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.s),
          onTap: onPressed,
          child: Center(
            child: Icon(icon, size: 15.s, color: enabled ? Colors.black : AppColors.textMute),
          ),
        ),
      ),
    );
  }

  Widget _addToCartButton(
    item_model.Item item,
    CartProvider cartProvider,
    num? maxAmount,
  ) {
    final itemTitle = presentItemName(
      rawName: item.name,
      categoryName: item.category?.name,
    );
    final canAdd = maxAmount == null || maxAmount.toDouble() > 0;
    final buttonLabel = canAdd ? (item.hasOptions ? 'Опции' : 'В корзину') : 'Нет';
    final buttonIcon = canAdd ? (item.hasOptions ? Icons.tune_rounded : Icons.shopping_bag_outlined) : Icons.remove_shopping_cart_outlined;

    return SizedBox(
      height: 32.s,
      child: Material(
        color: canAdd ? AppColors.orange : AppColors.cardDark,
        borderRadius: BorderRadius.circular(10.s),
        child: InkWell(
          borderRadius: BorderRadius.circular(10.s),
          onTap: canAdd
              ? () {
                  if (item.hasOptions) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailPage(item: item)));
                  } else {
                    final stepQuantity = item.effectiveStepQuantity;
                    cartProvider.addItem(CartItem(
                      itemId: item.itemId,
                      name: itemTitle.name,
                      price: item.price,
                      quantity: stepQuantity,
                      stepQuantity: stepQuantity,
                      image: item.image,
                      itemType: itemTitle.type,
                      packagingType: itemTitle.packagingType,
                      selectedVariants: const <Map<String, dynamic>>[],
                      promotions:
                          (item.promotions ?? const <item_model.ItemPromotion>[]).map((promotion) => promotion.toJson()).toList(growable: false),
                      maxAmount: item.amount?.toDouble(),
                    ));
                  }
                }
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(buttonIcon, size: 14.s, color: canAdd ? Colors.black : AppColors.textMute),
              SizedBox(width: 5.s),
              Text(
                buttonLabel,
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: canAdd ? Colors.black : AppColors.textMute),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatPrice(double price) {
    if (price >= 10000) {
      final whole = price.truncate();
      final frac = price - whole;
      final parts = <String>[];
      var number = whole;
      while (number >= 1000) {
        parts.insert(0, (number % 1000).toString().padLeft(3, '0'));
        number = number ~/ 1000;
      }
      parts.insert(0, number.toString());
      final formatted = parts.join(' ');
      return frac > 0.005 ? '$formatted.${(frac * 100).round().toString().padLeft(2, '0')}' : formatted;
    }

    return price == price.roundToDouble() ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
  }
}
