import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/surfaces.dart';
import '../catalog_view_data.dart';

/// Category destinations with an explicit current selection and a complete list.
class CategoryStrip extends StatefulWidget {
  const CategoryStrip({
    required this.categories,
    required this.onCategory,
    this.selectedCategoryId,
    this.onAll,
    super.key,
  });

  final List<CategoryRef> categories;
  final int? selectedCategoryId;
  final ValueChanged<CategoryRef> onCategory;
  final VoidCallback? onAll;

  @override
  State<CategoryStrip> createState() => _CategoryStripState();
}

class _CategoryStripState extends State<CategoryStrip> {
  final _scroll = ScrollController();
  final _selected = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealSelection();
  }

  @override
  void didUpdateWidget(covariant CategoryStrip oldWidget) {
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
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                child: Text('Категории', style: AppTypography.title),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      title: const Text('Все'),
                      selected: widget.selectedCategoryId == null,
                      trailing: widget.selectedCategoryId == null
                          ? const Icon(Icons.check)
                          : null,
                      onTap: widget.onAll == null
                          ? null
                          : () => Navigator.of(sheetContext).pop(-1),
                    ),
                    for (final category in widget.categories)
                      ListTile(
                        key: ValueKey('category-menu-${category.id}'),
                        title: Text(category.label),
                        selected: widget.selectedCategoryId == category.id,
                        trailing: widget.selectedCategoryId == category.id
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () =>
                            Navigator.of(sheetContext).pop(category.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || categoryId == null) return;
    if (categoryId == -1) {
      widget.onAll?.call();
      return;
    }
    for (final category in widget.categories) {
      if (category.id == categoryId) {
        if (category.id != widget.selectedCategoryId) {
          widget.onCategory(category);
        }
        return;
      }
    }
  }

  Widget _chip({
    required String label,
    required bool selected,
    required Key key,
    VoidCallback? onTap,
  }) {
    final palette = context.palette;
    final content = TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: palette.textPrimary,
        disabledForegroundColor: palette.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        minimumSize: const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
        shape: const StadiumBorder(),
        side: BorderSide(
          color: selected ? palette.accent : palette.divider,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(label, style: AppTypography.bodySmallMedium),
    );
    return MergeSemantics(
      key: key,
      child: Semantics(
        selected: selected,
        child: selected
            ? AppGlassPanel(
                radius: AppRadii.pill,
                tint: palette.surface,
                child: content,
              )
            : content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = AppSpacing.touchTarget +
        (MediaQuery.textScalerOf(context).scale(14) - 14)
            .clamp(0, double.infinity) *
            1.4;
    return SizedBox(
      key: const ValueKey('catalog-chip-strip'),
      height: height,
      child: Row(
        children: [
          Expanded(
            child: Scrollbar(
              controller: _scroll,
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                child: Row(
                  children: [
                    _chip(
                      key: widget.selectedCategoryId == null
                          ? _selected
                          : const ValueKey('category-chip-all'),
                      label: 'Все',
                      selected: widget.selectedCategoryId == null,
                      onTap: widget.onAll,
                    ),
                    for (final category in widget.categories) ...[
                      const SizedBox(width: AppSpacing.md),
                      _chip(
                        key: category.id == widget.selectedCategoryId
                            ? _selected
                            : ValueKey('category-chip-${category.id}'),
                        label: category.label,
                        selected: category.id == widget.selectedCategoryId,
                        onTap: category.id == widget.selectedCategoryId
                            ? null
                            : () => widget.onCategory(category),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.gutter),
            child: AppGlassPanel(
              radius: AppRadii.pill,
              width: AppSpacing.touchTarget,
              height: AppSpacing.touchTarget,
              child: IconButton(
                tooltip: 'Все категории',
                onPressed: _showCategories,
                icon: const Icon(Icons.list, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
