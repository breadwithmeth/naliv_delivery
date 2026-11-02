import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/surfaces.dart';
import '../catalog_view_data.dart';

/// A single category-switch control with a complete, contextual destination sheet.
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
    return AppSurface(
      child: TextButton(
        key: const ValueKey('category-switch-control'),
        onPressed: _showCategories,
        style: TextButton.styleFrom(
          foregroundColor: palette.textPrimary,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(AppSpacing.lg),
          minimumSize:
              const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Сменить категорию',
                    style: AppTypography.label
                        .copyWith(color: palette.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.selectedLabel,
                    style: AppTypography.headline
                        .copyWith(color: palette.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const Icon(Icons.unfold_more),
          ],
        ),
      ),
    );
  }
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
