import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../utils/api.dart';
import '../utils/responsive.dart';
import 'categoryPage.dart';
import 'search_page.dart';

class Catalog extends StatefulWidget {
  final int? businessId;

  const Catalog({
    super.key,
    this.businessId,
  });

  @override
  State<Catalog> createState() => _CatalogState();
}

class _CatalogState extends State<Catalog> {
  // ─── Palette (matches mainPage) ──────────────────────────
  static const Color _bgDeep = Color(0xFF121212);
  static const Color _bgTop = Color(0xFF161616);
  static const Color _card = Color(0xFF1E1E1E);
  static const Color _cardDark = Color(0xFF181818);
  static const Color _orange = Color(0xFFF6A10C);
  static const Color _red = Color(0xFFC23B30);
  static const Color _text = Colors.white;
  static const Color _textMute = Color(0xFF9FB0C8);

  List<Map<String, dynamic>> _superCategories = [];
  bool _isLoading = false;
  String? _error;

  // Scroll-linked navigation
  final ScrollController _chipScrollController = ScrollController();
  final List<GlobalKey> _chipKeys = [];
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  int _activeSuperIndex = 0;
  int? _pendingSuperIndex;
  bool _isAutoScrolling = false;
  static const double _slowUpdateDeltaThreshold = 1.5;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_handleVisibleSectionsChanged);
    _loadCategories();
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_handleVisibleSectionsChanged);
    _chipScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(Catalog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.businessId != oldWidget.businessId) {
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supercats = await ApiService.getSuperCategories();
      if (mounted) {
        setState(() {
          _superCategories = supercats ?? [];
          _chipKeys.clear();
          for (var i = 0; i < _superCategories.length; i++) {
            _chipKeys.add(GlobalKey());
          }
          _activeSuperIndex = 0;
          _pendingSuperIndex = _superCategories.isEmpty ? null : 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка загрузки категорий: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ─── Scroll tracking ────────────────────────────────────
  void _handleVisibleSectionsChanged() {
    if (_superCategories.isEmpty) return;

    final positions = _itemPositionsListener.itemPositions.value.where((position) {
      return position.itemTrailingEdge > 0 && position.itemLeadingEdge < 1;
    }).toList();

    if (positions.isEmpty) return;

    positions.sort((a, b) {
      final visibilityCompare = _visibleFraction(b).compareTo(_visibleFraction(a));
      if (visibilityCompare != 0) return visibilityCompare;
      return a.itemLeadingEdge.abs().compareTo(b.itemLeadingEdge.abs());
    });

    final nextIndex = positions.first.index;
    if (nextIndex < 0 || nextIndex >= _superCategories.length) return;
    _pendingSuperIndex = nextIndex;
  }

  double _visibleFraction(ItemPosition position) {
    final leadingEdge = position.itemLeadingEdge.clamp(0.0, 1.0);
    final trailingEdge = position.itemTrailingEdge.clamp(0.0, 1.0);
    return trailingEdge - leadingEdge;
  }

  void _commitActiveSection() {
    final nextIndex = _pendingSuperIndex;
    if (nextIndex == null || nextIndex == _activeSuperIndex) return;

    setState(() => _activeSuperIndex = nextIndex);
    _scrollChipIntoView(nextIndex);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isAutoScrolling || _superCategories.isEmpty) {
      return false;
    }

    if (notification is ScrollEndNotification) {
      _commitActiveSection();
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final scrollDelta = notification.scrollDelta?.abs() ?? 0;
      if (scrollDelta <= _slowUpdateDeltaThreshold) {
        _commitActiveSection();
      }
      return false;
    }

    if (notification is UserScrollNotification && notification.direction == ScrollDirection.idle) {
      _commitActiveSection();
    }

    return false;
  }

  void _scrollChipIntoView(int index) {
    if (index < 0 || index >= _chipKeys.length) return;
    final ctx = _chipKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.4,
      );
    }
  }

  void _scrollToSection(int index) async {
    if (index < 0 || index >= _superCategories.length || !_itemScrollController.isAttached) {
      return;
    }

    setState(() {
      _activeSuperIndex = index;
      _pendingSuperIndex = index;
      _isAutoScrolling = true;
    });

    await _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.0,
    );

    _isAutoScrolling = false;
    _scrollChipIntoView(index);
  }

  // ═══════════════════════════════════════════════════════════
  //  U I
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      body: Stack(
        children: [
          _background(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title row ──
                Padding(
                  padding: EdgeInsets.fromLTRB(18.s, 10.s, 10.s, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'каталог',
                          style: TextStyle(color: _text, fontSize: 25.sp, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.search_rounded, color: _text, size: 22.s),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchPage())),
                      ),
                    ],
                  ),
                ),
                // ── Pinned nav chips ──
                if (_superCategories.length > 1) _navChips(),
                // ── Body ──
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _background() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bgTop, _bgDeep]),
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

  // ─── Navigation chips ────────────────────────────────────
  Widget _navChips() {
    return Padding(
      padding: EdgeInsets.only(top: 10.s),
      child: SizedBox(
        height: 36.s,
        child: ListView.separated(
          controller: _chipScrollController,
          padding: EdgeInsets.symmetric(horizontal: 14.s),
          scrollDirection: Axis.horizontal,
          itemCount: _superCategories.length,
          separatorBuilder: (_, __) => SizedBox(width: 7.s),
          itemBuilder: (_, i) {
            final isActive = i == _activeSuperIndex;
            final label = _superCategories[i]['name']?.toString() ?? 'Раздел';
            return GestureDetector(
              key: _chipKeys.length > i ? _chipKeys[i] : null,
              onTap: () => _scrollToSection(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 8.s),
                decoration: BoxDecoration(
                  color: isActive ? _orange : _card,
                  borderRadius: BorderRadius.circular(11.s),
                  border: Border.all(color: isActive ? _orange : Colors.white.withValues(alpha: 0.03)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.black : _text,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Body ────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: _orange, strokeWidth: 3)),
            SizedBox(height: 14),
            Text('Загрузка каталога...', style: TextStyle(color: _textMute, fontSize: 13)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(28.s),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58.s,
                height: 58.s,
                decoration: BoxDecoration(color: _red.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.error_outline_rounded, color: _red, size: 28.s),
              ),
              SizedBox(height: 16.s),
              Text(_error!, style: TextStyle(color: _text, fontSize: 14.sp, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              SizedBox(height: 16.s),
              ElevatedButton.icon(
                onPressed: _loadCategories,
                icon: Icon(Icons.refresh_rounded, size: 16.s),
                label: const Text('Повторить'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
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

    if (_superCategories.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(28.s),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58.s,
                height: 58.s,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), shape: BoxShape.circle),
                child: Icon(Icons.category_outlined, color: _textMute.withValues(alpha: 0.5), size: 27.s),
              ),
              SizedBox(height: 16.s),
              Text('Категории не найдены', style: TextStyle(color: _text, fontSize: 15.sp, fontWeight: FontWeight.w800)),
              SizedBox(height: 7.s),
              Text(
                widget.businessId != null ? 'Для выбранного магазина нет категорий' : 'Выберите магазин для просмотра каталога',
                style: TextStyle(color: _textMute.withValues(alpha: 0.7), fontSize: 13.sp),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Build all sections in one scrollable list
    return RefreshIndicator(
      color: _orange,
      backgroundColor: _card,
      onRefresh: _loadCategories,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          padding: EdgeInsets.fromLTRB(0, 10.s, 0, 90.s),
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          itemCount: _superCategories.length,
          itemBuilder: (_, sectionIndex) {
            final superCat = _superCategories[sectionIndex];
            final title = superCat['name']?.toString() ?? 'Раздел';
            final List<Map<String, dynamic>> cats = (superCat['categories'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

            return _section(
              key: ValueKey('catalog-section-$sectionIndex'),
              title: title,
              cats: cats,
            );
          },
        ),
      ),
    );
  }

  // ─── Section (title + grid) ──────────────────────────────
  Widget _section({Key? key, required String title, required List<Map<String, dynamic>> cats}) {
    return Container(
      key: key,
      padding: EdgeInsets.only(bottom: 7.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Padding(
            padding: EdgeInsets.fromLTRB(16.s, 10.s, 16.s, 10.s),
            child: Text(
              title,
              style: TextStyle(color: _text, fontSize: 18.sp, fontWeight: FontWeight.w900),
            ),
          ),
          // Grid of category tiles
          if (cats.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16.s, 0, 16.s, 14.s),
              child: Text('Категории пока не добавлены', style: TextStyle(color: _textMute.withValues(alpha: 0.6), fontSize: 12.sp)),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.s),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Always 3 columns – keeps tiles compact on small phones
                  final crossCount = 3;
                  final spacing = 6.s;
                  final tileWidth = (constraints.maxWidth - (crossCount - 1) * spacing - 10.s) / crossCount;
                  final tileHeight = tileWidth / 0.95;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: cats.map((cat) {
                      return SizedBox(
                        width: tileWidth,
                        height: tileHeight,
                        child: _categoryTile(cat: cat, allCats: cats, sectionTitle: title),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ─── Category tile ───────────────────────────────────────
  Widget _categoryTile({required Map<String, dynamic> cat, required List<Map<String, dynamic>> allCats, required String sectionTitle}) {
    final name = cat['name']?.toString() ?? 'Категория';
    final img = cat['img']?.toString();
    final hasImage = img != null && img.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryPage(
              category: Category.fromJson(cat),
              allCategories: allCats.map((c) => Category.fromJson(c)).toList(),
              businessId: widget.businessId,
              sectionTitle: sectionTitle,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11.s),
          color: _cardDark,
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: hasImage
                  ? Image.network(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _tilePlaceholder(),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return _tilePlaceholder(showLoader: true);
                      },
                    )
                  : _tilePlaceholder(),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.35, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.12),
                      Colors.black.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 7.s,
              top: 7.s,
              right: 7.s,
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _text,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tilePlaceholder({bool showLoader = false}) {
    return Container(
      color: _cardDark,
      child: Center(
        child: showLoader
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _orange, strokeWidth: 2))
            : Icon(Icons.liquor_rounded, color: _textMute.withValues(alpha: 0.2), size: 32.s),
      ),
    );
  }
}
