import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../../core/product_view.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_states.dart';
import '../../../ui/app_top_bar.dart';
import '../../../ui/frosted_dock.dart';
import '../../../ui/product_card.dart';
import '../../../ui/product_grid.dart';
import '../../../ui/surfaces.dart';
import '../../../utils/cart_provider.dart';
import '../../product/product_navigation.dart';
import '../catalog_data_source.dart';
import '../catalog_view_data.dart';
import 'category_products_page.dart';
import 'category_switcher.dart';

/// A supercategory organised by its parent categories.
///
/// Each parent is one section: its name with «Все», a row of its child categories, and a
/// rail previewing its products. The tabs on top name the parents (never the leaves) and jump
/// to their sections; the sheet beside them lists every parent with its children beneath.
class SupercategoryPage extends StatefulWidget {
  const SupercategoryPage({
    required this.supercategoryId,
    required this.businessId,
    this.title,
    this.onSearch,
    this.onCart,
    super.key,
  });

  final int supercategoryId;
  final int businessId;

  /// Title to show immediately, before the API answers.
  final String? title;

  final VoidCallback? onSearch;

  /// Opens the cart.
  final VoidCallback? onCart;

  @override
  State<SupercategoryPage> createState() => _SupercategoryPageState();
}

class _SupercategoryPageState extends State<SupercategoryPage> {
  /// How far below the viewport's top edge a section counts as the current one.
  static const double _spyInset = 64;

  /// The product preview of a section is this long at most; «Все» opens the rest.
  static const int _previewLimit = 12;

  final _scroll = ScrollController();
  final _previews = <int, (List<ProductView>, bool)>{};
  final _sectionKeys = <int, GlobalKey>{};

  /// Parents the store has no products for: hidden from the page and from the navigation.
  final _empty = <int>{};
  final _active = ValueNotifier<int?>(null);
  SupercategoryView? _data;
  bool _failed = false;
  bool _loaded = false;
  bool _jumping = false;
  bool _spyQueued = false;

  /// The section the customer jumped to; kept at the top while sections above it finish
  /// loading and change height, until the customer scrolls by hand.
  int? _anchor;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_queueSpy);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _active.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _previews.clear();
    _empty.clear();
    _sectionKeys.clear();
    _active.value = null;
    setState(() {
      _failed = false;
      _data = null;
      _loaded = false;
    });
    try {
      final data = await CatalogDataSource(businessId: widget.businessId)
          .supercategory(widget.supercategoryId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  List<CategoryRef> get _parents => [
        for (final parent in _data?.categories ?? const <CategoryRef>[])
          if (!_empty.contains(parent.id)) parent,
      ];

  GlobalKey _keyFor(int id) => _sectionKeys.putIfAbsent(id, GlobalKey.new);

  CategoryRef? _parentOf(CategoryRef child) {
    for (final parent in _data?.categories ?? const <CategoryRef>[]) {
      if (parent.id == child.parentId) return parent;
    }
    return null;
  }

  void _onPreview(CategoryRef parent, List<ProductView> items, bool hasMore) {
    _previews[parent.id] = (items, hasMore);
    if (!mounted) return;
    if (items.isEmpty) setState(() => _empty.add(parent.id));
    _holdAnchor();
  }

  void _holdAnchor() {
    if (_anchor == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = _anchor;
      if (!mounted || id == null || _isAligned(id)) return;
      final target = _sectionKeys[id]?.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(target);
      }
    });
  }

  void _openParent(
    CategoryRef parent, {
    List<ProductView>? initialItems,
    bool? initialHasMore,
  }) {
    final preview = _previews[parent.id];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryProductsPage(
          categoryId: parent.id,
          title: parent.name,
          businessId: widget.businessId,
          group: parent,
          initialItems: initialItems ?? preview?.$1,
          initialHasMore: initialHasMore ?? preview?.$2,
          onSearch: widget.onSearch,
          onCart: widget.onCart,
        ),
      ),
    );
  }

  void _openChild(CategoryRef child) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryProductsPage(
          categoryId: child.id,
          title: child.name,
          businessId: widget.businessId,
          group: _parentOf(child),
          onSearch: widget.onSearch,
          onCart: widget.onCart,
        ),
      ),
    );
  }

  void _queueSpy() {
    if (_spyQueued || _jumping) return;
    _spyQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _spyQueued = false;
      if (mounted) _updateActive();
    });
  }

  /// Marks the section under the top edge of the list as the current one.
  void _updateActive() {
    if (_jumping || !_scroll.hasClients) return;
    final parents = _parents;
    if (parents.isEmpty) return;
    final position = _scroll.position;
    int? next;
    if (position.pixels <= position.minScrollExtent + 1) {
      next = parents.first.id;
    } else if (position.pixels >= position.maxScrollExtent - 1) {
      next = parents.last.id;
    } else {
      final viewport = position.context.storageContext.findRenderObject();
      if (viewport is! RenderBox || !viewport.attached) return;
      final top = viewport.localToGlobal(Offset.zero).dy;
      for (final parent in parents) {
        final box = _sectionKeys[parent.id]?.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.attached || !box.hasSize) continue;
        if (box.localToGlobal(Offset.zero).dy - top <= _spyInset) {
          next = parent.id;
        } else if (next != null) {
          break;
        }
      }
      next ??= parents.first.id;
    }
    _active.value = next;
  }

  /// Brings [parent]'s section to the top. Sections are built lazily, so a far one is first
  /// approached by the average section height and then aligned once it exists.
  Future<void> _scrollTo(CategoryRef parent) async {
    _jumping = true;
    _anchor = parent.id;
    _active.value = parent.id;
    try {
      for (var attempt = 0; attempt < 8 && mounted; attempt++) {
        final target = _sectionKeys[parent.id]?.currentContext;
        if (target != null && target.mounted) {
          await Scrollable.ensureVisible(
            target,
            duration: attempt == 0
                ? const Duration(milliseconds: 280)
                : Duration.zero,
            curve: Curves.easeOutCubic,
          );
          await WidgetsBinding.instance.endOfFrame;
          // Sections built on the way load their previews and change height,
          // which can shift the target after the scroll; align again until it
          // stays at the top of the list.
          if (!mounted || _isAligned(parent.id)) return;
          continue;
        }
        if (!_scroll.hasClients) return;
        final parents = _parents;
        final index = parents.indexWhere((entry) => entry.id == parent.id);
        if (index < 0) return;
        var built = 0;
        var total = 0.0;
        for (final entry in parents) {
          final box =
              _sectionKeys[entry.id]?.currentContext?.findRenderObject();
          if (box is RenderBox && box.hasSize) {
            built++;
            total += box.size.height;
          }
        }
        final average = built == 0 ? 520.0 : total / built;
        final position = _scroll.position;
        _scroll.jumpTo(
          (index * average).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
        await WidgetsBinding.instance.endOfFrame;
      }
    } finally {
      _jumping = false;
      if (mounted) _queueSpy();
    }
  }

  bool _isAligned(int id) {
    final box = _sectionKeys[id]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    if (!_scroll.hasClients) return true;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 1) return true;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return true;
    final revealed = viewport.getOffsetToReveal(box, 0).offset;
    return (revealed - position.pixels).abs() <= 1;
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FrostedDock(
          content: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                child: AppTopBar(
                  title: data?.name ?? widget.title ?? 'Каталог',
                  onBack: () => Navigator.of(context).maybePop(),
                  onSearch: widget.onSearch,
                ),
              ),
              const SizedBox(height: AppSpacing.huge),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 840),
                    child: _body(data),
                  ),
                ),
              ),
            ],
          ),
          dock: Selector<CartProvider, (int, double?)>(
            selector: (_, cart) => (
              cart.displayItemCount,
              cart.displayItemCount == 0 ? null : cart.getTotalPrice(),
            ),
            builder: (_, summary, __) => AppCartButton(
              itemCount: summary.$1,
              total: summary.$2,
              onTap: widget.onCart,
            ),
          ),
        ),
      ),
    );
  }

  EdgeInsets get _listPadding => EdgeInsets.only(
        bottom: AppCartButton.clearanceFor(context) +
            MediaQuery.paddingOf(context).bottom,
      );

  Widget _body(SupercategoryView? data) {
    Widget? state;
    if (_failed) {
      state = AppErrorState(
        message: 'Не удалось загрузить категорию',
        onRetry: _load,
      );
    } else if (data == null) {
      state = _loaded
          ? const AppEmptyState(title: 'В этой категории пока нет товаров')
          : const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
    } else if (data.categories.isEmpty || _parents.isEmpty) {
      state = const AppEmptyState(title: 'В этой категории пока нет товаров');
    }
    if (state != null) {
      return ListView(
        key: const ValueKey('catalog-overview'),
        controller: _scroll,
        padding: _listPadding,
        children: [state],
      );
    }
    final loaded = data!;
    final parents = _parents;
    final hasDescription = loaded.description?.isNotEmpty == true;
    final offset = hasDescription ? 1 : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (parents.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: ValueListenableBuilder<int?>(
              valueListenable: _active,
              builder: (_, active, __) => CategorySwitcher(
                parents: parents,
                selectedId: parents.any((parent) => parent.id == active)
                    ? active!
                    : parents.first.id,
                onParent: _scrollTo,
                onChild: _openChild,
              ),
            ),
          ),
        Expanded(
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (notification) {
              if (notification.dragDetails != null) _anchor = null;
              return false;
            },
            child: ListView.builder(
              key: const ValueKey('catalog-overview'),
              controller: _scroll,
              padding: _listPadding,
              itemCount: parents.length + offset,
              findChildIndexCallback: (key) {
                if (key is! ValueKey<int>) return null;
                final index = parents.indexWhere((p) => p.id == key.value);
                return index < 0 ? null : index + offset;
              },
              itemBuilder: (context, index) {
                if (hasDescription && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.md,
                      AppSpacing.gutter,
                      AppSpacing.xl,
                    ),
                    child: Text(
                      loaded.description!,
                      style: AppTypography.bodySmall
                          .copyWith(color: context.palette.textSecondary),
                    ),
                  );
                }
                final parent = parents[index - offset];
                return Padding(
                  key: ValueKey<int>(parent.id),
                  padding: const EdgeInsets.only(
                    top: AppSpacing.md,
                    bottom: AppSpacing.huge,
                  ),
                  child: KeyedSubtree(
                    key: _keyFor(parent.id),
                    child: _ParentSection(
                      parent: parent,
                      businessId: widget.businessId,
                      previewLimit: _previewLimit,
                      initialPreview: _previews[parent.id],
                      onLoaded: (items, hasMore) =>
                          _onPreview(parent, items, hasMore),
                      onOpen: (items, hasMore) => _openParent(
                        parent,
                        initialItems: items,
                        initialHasMore: hasMore,
                      ),
                      onOpenChild: _openChild,
                      onCart: widget.onCart,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// One parent category: header, its children as a chip row, and a product rail.
class _ParentSection extends StatefulWidget {
  const _ParentSection({
    required this.parent,
    required this.businessId,
    required this.previewLimit,
    this.initialPreview,
    this.onLoaded,
    this.onOpen,
    this.onOpenChild,
    this.onCart,
  });

  final CategoryRef parent;
  final int businessId;
  final int previewLimit;
  final (List<ProductView>, bool)? initialPreview;
  final void Function(List<ProductView>, bool)? onLoaded;
  final void Function(List<ProductView>?, bool?)? onOpen;
  final ValueChanged<CategoryRef>? onOpenChild;
  final VoidCallback? onCart;

  @override
  State<_ParentSection> createState() => _ParentSectionState();
}

class _ParentSectionState extends State<_ParentSection> {
  List<ProductView>? _items;
  bool? _hasMore;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final preview = widget.initialPreview;
    if (preview == null) {
      _load();
    } else {
      _items = preview.$1;
      _hasMore = preview.$2;
    }
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _items = null;
    });
    try {
      // A parent's products already include those of its children.
      final result = await CatalogDataSource(businessId: widget.businessId)
          .itemsPage(widget.parent.id);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _hasMore = result.hasMore;
      });
      widget.onLoaded?.call(result.items, result.hasMore);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _openProduct(ProductView item) {
    openProduct(
      context,
      item,
      businessId: widget.businessId,
      onCart: widget.onCart,
    );
  }

  void _openChild(CategoryChipItem chip) {
    for (final child in widget.parent.children) {
      if (child.id == chip.id) {
        widget.onOpenChild?.call(child);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items != null && items.isEmpty) return const SizedBox.shrink();
    final open =
        widget.onOpen == null ? null : () => widget.onOpen!(items, _hasMore);
    final Widget content;
    if (_failed) {
      content = AppErrorState(
        message: 'Не удалось загрузить товары',
        onRetry: _load,
      );
    } else if (items == null) {
      content = SizedBox(
        height: ProductCard.extentFor(context, ProductCard.widthFor(context)),
        child: const Center(child: CircularProgressIndicator()),
      );
    } else {
      final shown = items.take(widget.previewLimit).toList(growable: false);
      content = ProductRail(
        products: shown,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        itemCount: shown.length + 1,
        itemBuilder: (context, index) => index == shown.length
            ? _SeeAllTile(parent: widget.parent, onTap: open)
            : _card(shown[index]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: _SectionHeader(
            actionKey: ValueKey('catalog-open-${widget.parent.id}'),
            title: widget.parent.name,
            onOpen: open,
          ),
        ),
        if (widget.parent.hasChildren) ...[
          const SizedBox(height: AppSpacing.sm),
          CategoryChipRow(
            items: [
              for (final child in widget.parent.children)
                CategoryChipItem.fromCategory(child),
            ],
            onSelected: _openChild,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        content,
      ],
    );
  }

  Widget _card(ProductView item) => Selector<CartProvider, double>(
        selector: (_, cart) => cart.getCatalogQuantityForKey(item.catalogKey),
        builder: (context, quantity, _) => ProductCard.fromView(
          item,
          onTap: () => _openProduct(item),
          quantity: quantity,
          onIncrement: () =>
              context.read<CartProvider>().incrementCatalogItem(item.source),
          onDecrement: () =>
              context.read<CartProvider>().decrementCatalogItem(item.source),
        ),
      );
}

/// A parent's name with the shared «Все» action. The name wraps rather than truncates.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionKey,
    this.onOpen,
  });

  final String title;
  final Key actionKey;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              borderRadius: AppRadii.lgAll,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(minHeight: AppSpacing.touchTarget),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    title,
                    style: AppTypography.headline
                        .copyWith(color: context.palette.textPrimary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppSectionAction(key: actionKey, label: 'Все', onTap: onOpen),
        ],
      );
}

/// The last card of a preview rail: same size as the products, opening the whole parent.
class _SeeAllTile extends StatelessWidget {
  const _SeeAllTile({required this.parent, this.onTap});

  final CategoryRef parent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      borderRadius: AppRadii.lgAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: AppSpacing.touchTarget,
                    child: Icon(
                      Icons.arrow_forward,
                      color: palette.textOnAccent,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Все товары',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.base(size: 14, weight: 600)
                      .copyWith(color: palette.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
