import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/destinations.dart';
import '../../../core/theme_controller.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../services/telemetry_consent_service.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/app_top_bar.dart';

/// Profile — the design's `Профиль` and `Профиль - Переключение свитчей` frames.
///
/// Geometry: the standard top bar, an 80 px avatar disc (accent @50 %, 47.5 px glyph) centred at
/// y = 139, then eight 343 × 58 rows from y = 231 at a 62 px pitch, separated by 1 px lines —
/// except between the two switch rows, which read as one group. Each row is transparent with a
/// radius-10 hit area: icon 24 at x = 32, title 16/500 at x = 72, subtitle 10/400 muted beneath
/// it, and either a chevron (24, x = 319) or a 50 × 30 switch (x = 297). «Выйти» sits centred at
/// y = 733 in error red.
///
/// The switch states are real: «Сбор информации» is `TelemetryConsentService` and «Тема
/// оформления» is [ThemeController] — the design draws the switch, this wires it.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    this.addressSummary,
    this.cardsSummary,
    this.onNavigate,
    this.onLogout,
    super.key,
  });

  /// Row subtitles that reflect the account: «Нет сохранённых адресов», «Добавленных карт нет»…
  final String? addressSummary;
  final String? cardsSummary;

  final ValueChanged<AppDestination>? onNavigate;
  final VoidCallback? onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool? _consent;

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final allowed = await TelemetryConsentService.loadConsent();
    if (!mounted) return;
    setState(() => _consent = allowed);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = context.watch<ThemeController>();
    final rows = <_RowSpec>[
      const _RowSpec(
          AppIcons.orders, 'История заказов', 'Активные и завершённые заказы',
          destination: AppDestination.orders),
      const _RowSpec(
          AppIcons.certificates, 'Сертификаты', 'Покупка, активация и подарки',
          destination: AppDestination.certificates),
      const _RowSpec(
          AppIcons.support, 'Поддержка', 'Вопросы по заказам и оплате',
          destination: AppDestination.support),
      const _RowSpec(
          AppIcons.faq, 'FAQ', 'Вход, карты, доставка, бонусы и возвраты',
          destination: AppDestination.faq),
      _RowSpec(AppIcons.addresses, 'Адреса',
          widget.addressSummary ?? 'Нет сохранённых адресов',
          destination: AppDestination.addresses),
      _RowSpec(AppIcons.cards, 'Карты',
          widget.cardsSummary ?? 'Добавленных карт нет',
          destination: AppDestination.cards),
      _RowSpec(
          AppIcons.analytics, 'Сбор информации', 'Анонимные отчёты об ошибках',
          switchValue: _consent, onSwitch: (value) async {
        setState(() => _consent = value);
        await TelemetryConsentService.setConsent(value);
      }),
      _RowSpec(AppIcons.theme, 'Тема оформления',
          'Переключение светлой и тёмной темы',
          // The design's switch is binary and shows the *effective* theme: following the OS into
          // dark reads as on, and toggling pins an explicit mode.
          switchValue: Theme.of(context).brightness == Brightness.dark,
          onSwitch: (value) =>
              theme.setMode(value ? ThemeMode.dark : ThemeMode.light)),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
              child: AppTopBar(
                title: 'Профиль',
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: Container(
                key: const ValueKey('profile-avatar'),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child:
                    const Center(child: AppIcon(AppIcons.avatar, size: 47.5)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(
                  top: AppSpacing.xs,
                  bottom:
                      AppSpacing.huge + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    _ProfileRow(
                      rowKey: ValueKey('profile-row-$i'),
                      spec: rows[i],
                      onTap: rows[i].destination == null
                          ? null
                          : () => widget.onNavigate?.call(rows[i].destination!),
                    ),
                    if (i < rows.length - 1) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      if (i < 6) ...[
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: AppSpacing.xxxl,
                          endIndent: AppSpacing.xxxl,
                          color: palette.divider,
                        ),
                        const SizedBox(height: 1),
                      ],
                    ],
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: GestureDetector(
                      onTap: widget.onLogout,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        key: const ValueKey('profile-logout'),
                        width: 94,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          'Выйти',
                          style:
                              AppTypography.body.copyWith(color: palette.error),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowSpec {
  const _RowSpec(
    this.icon,
    this.title,
    this.subtitle, {
    this.destination,
    this.switchValue,
    this.onSwitch,
  });

  final String icon;
  final String title;
  final String subtitle;
  final AppDestination? destination;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitch;
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.spec, this.onTap, this.rowKey});

  final _RowSpec spec;
  final VoidCallback? onTap;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        child: Container(
          key: rowKey,
          height: 58,
          padding: const EdgeInsets.only(
            left: AppSpacing.xxxl,
            right: AppSpacing.xl,
          ),
          decoration:
              BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.lg)),
          child: Row(
            children: [
              AppIcon(spec.icon, size: 24, color: palette.accent),
              const SizedBox(width: AppSpacing.xxxl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      spec.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium
                          .copyWith(color: palette.textPrimary),
                    ),
                    Text(
                      spec.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label
                          .copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              if (spec.onSwitch != null)
                _ProfileSwitch(
                  key: ValueKey(
                    spec.icon == AppIcons.theme
                        ? 'profile-theme-switch'
                        : 'profile-telemetry-switch',
                  ),
                  value: spec.switchValue ?? false,
                  onChanged: spec.onSwitch!,
                  themeIcon: spec.icon == AppIcons.theme,
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: Transform.flip(
                        flipX: true,
                        child: AppIcon(
                          AppIcons.back,
                          width: 6,
                          height: 13,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSwitch extends StatelessWidget {
  const _ProfileSwitch({
    required this.value,
    required this.onChanged,
    required this.themeIcon,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool themeIcon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 50,
          height: 30,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color:
                themeIcon || value ? palette.accentSoft : palette.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 150),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: SizedBox(
              width: 22,
              height: 22,
              child: themeIcon
                  ? DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CustomPaint(
                        painter: _ThemeGlyphPainter(
                          dark: value,
                          color: palette.accentSoft,
                        ),
                      ),
                    )
                  : const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeGlyphPainter extends CustomPainter {
  const _ThemeGlyphPainter({required this.dark, required this.color});

  final bool dark;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const center = Offset(11, 11);
    if (dark) {
      final crescent = Path()
        ..moveTo(15.5, 15.4)
        ..cubicTo(10.1, 16.9, 5.3, 12.8, 6.1, 7.4)
        ..cubicTo(6.5, 4.8, 8.1, 3.1, 10.2, 2.4)
        ..cubicTo(8.8, 7.7, 12.5, 12.4, 17.3, 12.6)
        ..cubicTo(16.9, 13.8, 16.3, 14.7, 15.5, 15.4)
        ..close();
      canvas.drawPath(crescent, paint..style = PaintingStyle.fill);
      return;
    }

    paint.style = PaintingStyle.stroke;
    canvas.drawCircle(center, 3.5, paint);
    canvas
      ..drawLine(const Offset(11, 2.5), const Offset(11, 5), paint)
      ..drawLine(const Offset(11, 17), const Offset(11, 19.5), paint)
      ..drawLine(const Offset(2.5, 11), const Offset(5, 11), paint)
      ..drawLine(const Offset(17, 11), const Offset(19.5, 11), paint)
      ..drawLine(const Offset(5, 5), const Offset(6.7, 6.7), paint)
      ..drawLine(const Offset(15.3, 15.3), const Offset(17, 17), paint)
      ..drawLine(const Offset(5, 17), const Offset(6.7, 15.3), paint)
      ..drawLine(const Offset(15.3, 6.7), const Offset(17, 5), paint);
  }

  @override
  bool shouldRepaint(_ThemeGlyphPainter oldDelegate) =>
      dark != oldDelegate.dark || color != oldDelegate.color;
}
