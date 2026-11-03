import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'frosted_surface.dart';

/// A readable search input that grows with the inherited text scaler.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    this.controller,
    this.focusNode,
    this.hint = 'Найти любимый напиток...',
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return FrostedSurface(
      borderRadius: AppRadii.pillAll,
      shadow: false,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 30),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: palette.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: autofocus,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                cursorColor: palette.accent,
                style: AppTypography.bodyLight
                    .copyWith(color: palette.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: hint,
                  hintStyle: AppTypography.bodyLight
                      .copyWith(color: palette.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
