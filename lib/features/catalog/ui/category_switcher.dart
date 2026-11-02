import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../catalog_view_data.dart';

/// Horizontal category tabs with a complete category sheet at the end of the rail.
class CategorySwitcher extends StatefulWidget {
  const CategorySwitcher({
    required this.categories,
    required this.selectedCategoryId,
    required this.selectedLabel,
    required this.onCategory,
    required this.onOverview,
    super.key,
  });

  final List<CategoryRef> categories;
  final int selectedCategoryId;
  final String selectedLabel;
  final ValueChanged<CategoryRef> onCategory;
  final VoidCallback onOverview;

  @override
  State<CategorySwitcher> createState() => _CategorySwitcherState();
}

class _CategorySwitcherState extends State<CategorySwitcher> {
  final _scroll = ScrollController();
  final _selected = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealSelection();
  }

  @override
  void didUpdateWidget(CategorySwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategoryId != widget.selectedCategoryId) {
      _revealSelection();
    }
  }

  void _revealSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selectedContext = _selected.currentContext;
      if (selectedContext != null) {
        Scrollable.ensureVisible(selectedContext, alignment: .5);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _showCategories() async {
    final categoryId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategorySheet(
        categories: widget.categories,
        selectedCategoryId: widget.selectedCategoryId,
      ),
    );
    if (!mounted || categoryId == null) return;
    if (categoryId == -1) {
      widget.onOverview();
      return;
    }
    if (categoryId == widget.selectedCategoryId) return;
    for (final category in widget.categories) {
      if (category.id == categoryId) {
        widget.onCategory(category);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final light = Theme.of(context).brightness == Brightness.light;
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            // Room for the selected pill's shadow, which the viewport would clip.
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                for (final category in widget.categories)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: Semantics(
                      key: category.id == widget.selectedCategoryId
                          ? _selected
                          : null,
                      selected: category.id == widget.selectedCategoryId,
                      button: true,
                      child: _CategoryTab(
                        key: ValueKey('category-tab-${category.id}'),
                        label: category.label,
                        selected: category.id == widget.selectedCategoryId,
                        light: light,
                        palette: palette,
                        onTap: () => widget.onCategory(category),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('category-switch-control'),
          tooltip: 'Все категории: ${widget.selectedLabel}',
          onPressed: _showCategories,
          constraints: const BoxConstraints(
            minWidth: AppSpacing.touchTarget,
            minHeight: AppSpacing.touchTarget,
          ),
          icon: const Icon(Icons.unfold_more),
        ),
      ],
    );
  }
}

/// One tab: plain secondary text, or a raised pill when selected (white with a soft
/// shadow on light, the surface colour on dark), inside a 44 px-tall hit area.
class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.label,
    required this.selected,
    required this.light,
    required this.palette,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final bool light;
  final AppPalette palette;
  final VoidCallback onTap;

  static final TextStyle _selectedStyle =
      AppTypography.base(size: 16, weight: 600);
  static final TextStyle _plainStyle =
      AppTypography.base(size: 16, weight: 500);

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSpacing.touchTarget,
            minHeight: AppSpacing.touchTarget,
          ),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected
                    ? (light ? Colors.white : palette.surface)
                    : Colors.transparent,
                borderRadius: AppRadii.pillAll,
                boxShadow: selected && light
                    ? [
                        BoxShadow(
                          color: palette.shadow,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                  vertical: AppSpacing.md,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: (selected ? _selectedStyle : _plainStyle).copyWith(
                    color:
                        selected ? palette.textPrimary : palette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({
    required this.categories,
    required this.selectedCategoryId,
  });

  final List<CategoryRef> categories;
  final int selectedCategoryId;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final _selected = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selectedContext = _selected.currentContext;
      if (selectedContext != null) {
        Scrollable.ensureVisible(selectedContext, alignment: .5);
      }
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Категории', style: AppTypography.title),
                    ),
                    IconButton(
                      tooltip: 'Закрыть категории',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ListTile(
                        key: const ValueKey('category-overview'),
                        leading: const Icon(Icons.arrow_back),
                        title: const Text('Обзор каталога'),
                        onTap: () => Navigator.of(context).pop(-1),
                      ),
                      for (final category in widget.categories)
                        Semantics(
                          key: category.id == widget.selectedCategoryId
                              ? _selected
                              : null,
                          selected: category.id == widget.selectedCategoryId,
                          child: ListTile(
                            key: ValueKey('category-menu-${category.id}'),
                            title: Text(category.label),
                            selected: category.id == widget.selectedCategoryId,
                            trailing: category.id == widget.selectedCategoryId
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () => Navigator.of(context).pop(category.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
