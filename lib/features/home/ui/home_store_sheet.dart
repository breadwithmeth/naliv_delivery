import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_icon.dart';
import '../home_view_data.dart';

/// Selects the store that scopes prices and availability across the app.
class HomeStoreSheet extends StatelessWidget {
  const HomeStoreSheet({
    required this.stores,
    required this.selectedId,
    super.key,
  });

  final List<HomeStore> stores;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final grouped = <String, List<HomeStore>>{};
    for (final store in stores) {
      grouped.putIfAbsent(store.city ?? 'Другие магазины', () => []).add(store);
    }
    final cityNames = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'Другие магазины') return 1;
        if (b == 'Другие магазины') return -1;
        return a.compareTo(b);
      });

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Выберите магазин',
                      style: AppTypography.headline
                          .copyWith(color: palette.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Цены и ассортимент могут отличаться',
                      style: AppTypography.bodySmall
                          .copyWith(color: palette.textSecondary)),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  for (final city in cityNames) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                      child: Text(
                        '$city  ${grouped[city]!.length}',
                        style: AppTypography.bodySmallBold.copyWith(
                          color: grouped[city]!.any((store) => store.id == selectedId)
                              ? palette.accent
                              : palette.textPrimary,
                        ),
                      ),
                    ),
                    for (final store in grouped[city]!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: store.id == selectedId
                              ? palette.accent.withValues(alpha: .18)
                              : palette.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          child: InkWell(
                            key: ValueKey('home-store-${store.id}'),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            onTap: () => Navigator.of(context).pop(store),
                            child: Semantics(
                              selected: store.id == selectedId,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: AppSpacing.touchTarget,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const AppIcon(AppIcons.store, size: 18),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(store.name,
                                            style: AppTypography.bodySmallBold
                                                .copyWith(
                                                    color:
                                                        palette.textPrimary)),
                                        if (store.address.isNotEmpty)
                                          Text(store.address,
                                              style: AppTypography.label
                                                  .copyWith(
                                                      color: palette
                                                          .textSecondary)),
                                      ],
                                    ),
                                  ),
                                  if (store.id == selectedId)
                                    Icon(Icons.check,
                                        color: palette.accent, size: 20),
                                ],
                              ),
                            ),
                              ),
                              ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
