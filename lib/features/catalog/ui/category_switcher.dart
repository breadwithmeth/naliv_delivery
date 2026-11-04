import 'package:flutter/material.dart';

import '../../../design/motion.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../catalog_view_data.dart';

/// One entry of a [CategoryChipRow].
@immutable
class CategoryChipItem {
  const CategoryChipItem({
    required this.id,
    required this.label,
    this.semanticLabel,
  });

  CategoryChipItem.fromCategory(CategoryRef category)
      : id = category.id,
        label = category.name,
        semanticLabel = category.semanticLabel;

  final int id;
  final String label;
  final String? semanticLabel;
}

/// A single horizontally scrolling row of category chips.
///
/// The row never wraps, so a parent with two dozen children stays one tidy line. Chips are
/// plain type (category photos are sparse and load unreliably, so they are not mixed in);
/// the selected chip is filled with the accent and scrolled into view whenever it changes.
class CategoryChipRow extends StatefulWidget {
  const CategoryChipRow({
    required this.items,
    required this.onSelected,
    this.selectedId,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
    super.key,
  });

  final List<CategoryChipItem> items;
  final ValueChanged<CategoryChipItem> onSelected;
  final int? selectedId;
  final EdgeInsetsGeometry padding;

  @override
  State<CategoryChipRow> createState() => _CategoryChipRowState();
}

class _CategoryChipRowState extends State<CategoryChipRow> {
  final _selected = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealSelection();
  }

  @override
  void didUpdateWidget(CategoryChipRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) _revealSelection();
  }

  void _revealSelection() {
    if (widget.selectedId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selectedContext = _selected.currentContext;
      if (selectedContext != null) {
        Scrollable.ensureVisible(
          selectedContext,
          alignment: .5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final item in widget.items)
              Padding(
                key: item.id == widget.selectedId ? _selected : null,
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: _CategoryChip(
                  key: ValueKey('category-chip-${item.id}'),
                  item: item,
                  selected: item.id == widget.selectedId,
                  onTap: () => widget.onSelected(item),
                ),
              ),
          ],
        ),
      );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.item,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final CategoryChipItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = selected ? palette.textOnAccent : palette.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: item.semanticLabel ?? item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? palette.accent : palette.surface,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        animationDuration: AppMotion.of(context, AppMotion.state),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSpacing.touchTarget,
              minHeight: AppSpacing.touchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxxl,
                vertical: AppSpacing.md,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: AppMotion.of(context, AppMotion.state),
                    curve: AppMotion.out,
                    maxLines: 1,
                    softWrap: false,
                    style: AppTypography.base(
                      size: 14,
                      weight: selected ? 600 : 500,
                    ).copyWith(color: foreground),
                    child: Text(item.label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tabs for the parent categories of a supercategory, with a grouped sheet of every parent
/// and its children at the end of the rail.
///
/// A parent tab jumps to its section; a child in the sheet opens that child's products.
class CategorySwitcher extends StatefulWidget {
  const CategorySwitcher({
    required this.parents,
    required this.selectedId,
    required this.onParent,
    required this.onChild,
    super.key,
  });

  final List<CategoryRef> parents;
  final int selectedId;
  final ValueChanged<CategoryRef> onParent;
  final ValueChanged<CategoryRef> onChild;

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
    if (oldWidget.selectedId != widget.selectedId) _revealSelection();
  }

  void _revealSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selectedContext = _selected.currentContext;
      if (selectedContext != null) {
        Scrollable.ensureVisible(
          selectedContext,
          alignment: .5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String get _selectedName {
    for (final parent in widget.parents) {
      if (parent.id == widget.selectedId) return parent.name;
    }
    return '';
  }

  Future<void> _showCategories() async {
    final chosen = await showModalBottomSheet<CategoryRef>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategorySheet(
        parents: widget.parents,
        selectedId: widget.selectedId,
      ),
    );
    if (!mounted || chosen == null) return;
    final isParent = widget.parents.any((parent) => parent.id == chosen.id);
    if (isParent) {
      widget.onParent(chosen);
    } else {
      widget.onChild(chosen);
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
                for (final parent in widget.parents)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: Semantics(
                      key: parent.id == widget.selectedId ? _selected : null,
                      selected: parent.id == widget.selectedId,
                      button: true,
                      child: _CategoryTab(
                        key: ValueKey('category-tab-${parent.id}'),
                        label: parent.name,
                        selected: parent.id == widget.selectedId,
                        light: light,
                        palette: palette,
                        onTap: () => widget.onParent(parent),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('category-switch-control'),
          tooltip: 'Все категории: $_selectedName',
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
            child: AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.state),
              curve: AppMotion.out,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
                vertical: AppSpacing.md,
              ),
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
              child: AnimatedDefaultTextStyle(
                duration: AppMotion.of(context, AppMotion.state),
                curve: AppMotion.out,
                maxLines: 1,
                softWrap: false,
                style: (selected ? _selectedStyle : _plainStyle).copyWith(
                  color: selected ? palette.textPrimary : palette.textSecondary,
                ),
                child: Text(label),
              ),
            ),
          ),
        ),
      );
}

/// Every parent as a header with its children listed beneath, the current parent marked.
///
/// Children wrap onto as many lines as they need, so large text and long names never overflow
/// and a parent with two dozen children reads as a compact block rather than a tall list.
class _CategorySheet extends StatefulWidget {
  const _CategorySheet({
    required this.parents,
    required this.selectedId,
  });

  final List<CategoryRef> parents;
  final int selectedId;

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
        Scrollable.ensureVisible(selectedContext, alignment: .1);
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
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    0,
                    AppSpacing.gutter,
                    AppSpacing.huge,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, parent) in widget.parents.indexed) ...[
                        if (index > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xl),
                            child: Divider(
                                height: 1,
                                thickness: 1,
                                color: context.palette.divider),
                          ),
                        _SheetGroup(
                          key: parent.id == widget.selectedId
                              ? _selected
                              : ValueKey('category-group-${parent.id}'),
                          parent: parent,
                          selected: parent.id == widget.selectedId,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SheetGroup extends StatelessWidget {
  const _SheetGroup({
    required this.parent,
    required this.selected,
    super.key,
  });

  final CategoryRef parent;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          key: ValueKey('category-menu-${parent.id}'),
          button: true,
          selected: selected,
          child: Material(
            color: selected ? palette.accentFaint : Colors.transparent,
            borderRadius: AppRadii.xlAll,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(parent),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.touchTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          parent.name,
                          style: AppTypography.headline
                              .copyWith(color: palette.textPrimary),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      selected
                          ? Icon(Icons.check, color: palette.accent)
                          : Icon(Icons.chevron_right_rounded,
                              color: palette.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (parent.hasChildren)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, child) in parent.children.indexed) ...[
                  if (index > 0)
                    Divider(height: 1, thickness: 0.5, color: palette.divider),
                  _SheetRow(
                    key: ValueKey('category-menu-${child.id}'),
                    label: child.name,
                    onTap: () => Navigator.of(context).pop(child),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// One sub-category in the categories sheet: plain text, a quiet chevron, a
/// full-width 44 px tap target.
class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                0, AppSpacing.md, AppSpacing.xl, AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodyMedium
                        .copyWith(color: palette.textPrimary),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: palette.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
