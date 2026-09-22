import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_top_bar.dart';

/// Placeholder for the certificates area.
///
/// Requested explicitly: the redesigned certificates screen is **not** to be built for now, so
/// this stub stands in its place. It is deliberately not a dead end — its action opens the
/// detailed screen (already implemented and verified at
/// `lib/features/certificates/ui/certificates_page.dart`), which in turn bridges to the legacy
/// purchase flow. That keeps the "activate by code" and "buy" capabilities reachable while the
/// redesign of this area is parked, instead of removing working functionality.
///
/// Replace this with the real screen (or delete both) once the certificates design is settled.
class CertificatesPlaceholderPage extends StatelessWidget {
  const CertificatesPlaceholderPage({this.onOpenDetails, super.key});

  /// Opens the detailed certificates screen mentioned above.
  final VoidCallback? onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
              child: AppTopBar(
                title: 'Сертификаты',
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.huge),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Раздел в разработке',
                        textAlign: TextAlign.center,
                        style: AppTypography.headline
                            .copyWith(color: palette.textPrimary),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Сертификаты скоро появятся в новом оформлении',
                        textAlign: TextAlign.center,
                        style: AppTypography.body
                            .copyWith(color: palette.textSecondary),
                      ),
                      if (onOpenDetails != null) ...[
                        const SizedBox(height: AppSpacing.huge),
                        GestureDetector(
                          onTap: onOpenDetails,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            'Открыть текущий экран',
                            style: AppTypography.bodyMedium
                                .copyWith(color: palette.accent),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
