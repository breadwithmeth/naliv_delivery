import 'dart:async';

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

import '../profile_account.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    this.account,
    this.loadAccount,
    this.onNavigate,
    this.onSignIn,
    this.onLogout,
    super.key,
  });

  final ProfileAccount? account;
  final Future<ProfileAccount?> Function()? loadAccount;
  final FutureOr<void> Function(AppDestination)? onNavigate;
  final Future<void> Function()? onSignIn;
  final Future<void> Function()? onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool? _consent;
  bool _consentSaving = false;
  bool _consentLoadFailed = false;
  bool _themeSaving = false;
  ProfileAccount? _account;
  bool _accountLoading = false;
  bool _accountFailed = false;
  bool _signingIn = false;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    _refreshAccount();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    setState(() {
      _consent = null;
      _consentLoadFailed = false;
    });
    try {
      final allowed = await TelemetryConsentService.loadConsent();
      if (!mounted) return;
      setState(() => _consent = allowed);
    } catch (_) {
      if (mounted) setState(() => _consentLoadFailed = true);
    }
  }

  Future<void> _refreshAccount() async {
    final load = widget.loadAccount;
    if (load == null || _accountLoading) return;
    setState(() {
      _accountLoading = true;
      _accountFailed = false;
    });
    try {
      final account = await load();
      if (mounted) setState(() => _account = account);
    } catch (_) {
      if (mounted) setState(() => _accountFailed = true);
    } finally {
      if (mounted) setState(() => _accountLoading = false);
    }
  }

  Future<void> _openDestination(AppDestination destination) async {
    final navigate = widget.onNavigate;
    if (navigate == null) return;
    await navigate(destination);
    if (mounted) await _refreshAccount();
  }

  Future<void> _signIn() async {
    if (_signingIn || widget.onSignIn == null) return;
    setState(() => _signingIn = true);
    try {
      await widget.onSignIn!();
      if (mounted) await _refreshAccount();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть вход в аккаунт')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut || widget.onLogout == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
            'Корзина сохранится. Для заказов и карт понадобится вход.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Остаться'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _loggingOut = true);
    try {
      await widget.onLogout!();
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  String _summary(String? saved, String emptyGuest) {
    if (_accountLoading && saved == null) return 'Загрузка…';
    if (_accountFailed && saved == null) return 'Не удалось загрузить';
    if (_account == null) return emptyGuest;
    return saved ?? 'Откройте, чтобы посмотреть';
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
          AppIcons.certificates, 'Сертификаты', 'Покупка и активация по коду',
          destination: AppDestination.certificates),
      const _RowSpec(
          AppIcons.support, 'Поддержка', 'Вопросы по заказам и оплате',
          destination: AppDestination.support),
      const _RowSpec(
          AppIcons.faq, 'FAQ', 'Вход, карты, доставка, бонусы и возвраты',
          destination: AppDestination.faq),
      _RowSpec(AppIcons.addresses, 'Адреса',
          _summary(_account?.addressSummary, 'Войдите, чтобы сохранить адрес'),
          destination: AppDestination.addresses),
      _RowSpec(AppIcons.cards, 'Карты',
          _summary(_account?.cardsSummary, 'Войдите, чтобы управлять картами'),
          destination: AppDestination.cards),
      _RowSpec(
          AppIcons.analytics,
          'Сбор информации',
          _consentLoadFailed
              ? 'Не удалось загрузить · нажмите, чтобы повторить'
              : _consent == null
                  ? 'Загрузка настройки…'
                  : _consentSaving
                      ? 'Сохраняем настройку…'
                      : 'Анонимные отчёты об ошибках',
          switchValue: _consent,
          onSwitch: _consent == null || _consentSaving
              ? null
              : (value) async {
                  setState(() {
                    _consent = value;
                    _consentSaving = true;
                  });
                  try {
                    await TelemetryConsentService.setConsent(value);
                  } catch (_) {
                    await _loadConsent();
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context)
                        .showSnackBar(const SnackBar(
                      content: Text('Не удалось сохранить настройку'),
                    ));
                  } finally {
                    if (mounted) setState(() => _consentSaving = false);
                  }
                }),
      _RowSpec(
          AppIcons.theme,
          'Тема оформления',
          _themeSaving
              ? 'Сохраняем тему…'
              : 'Переключение светлой и тёмной темы',
          // The design's switch is binary and shows the *effective* theme: following the OS into
          // dark reads as on, and toggling pins an explicit mode.
          switchValue: Theme.of(context).brightness == Brightness.dark,
          onSwitch: _themeSaving
              ? null
              : (value) async {
                  setState(() => _themeSaving = true);
                  try {
                    await theme
                        .setMode(value ? ThemeMode.dark : ThemeMode.light);
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                            content: Text('Не удалось сохранить тему')),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _themeSaving = false);
                  }
                }),
    ];

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: AppTopBar(
                    title: 'Профиль',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshAccount,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        top: AppSpacing.xl,
                        bottom: AppSpacing.huge +
                            MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        Center(
                          child: AnimatedContainer(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                            key: const ValueKey('profile-avatar'),
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: palette.accent.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: AppIcon(AppIcons.avatar, size: 47.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xxxl),
                          child: Column(
                            children: [
                              if (_account != null) ...[
                                Text(
                                  _account!.name ?? 'Личный кабинет',
                                  key: const ValueKey('profile-name'),
                                  textAlign: TextAlign.center,
                                  style: AppTypography.titleMedium
                                      .copyWith(color: palette.textPrimary),
                                ),
                                if (_account!.phone != null)
                                  Text(
                                    _account!.phone!,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.bodySmall
                                        .copyWith(color: palette.textSecondary),
                                  ),
                              ] else if (widget.onSignIn != null)
                                FilledButton(
                                  key: const ValueKey('profile-sign-in'),
                                  onPressed: _signingIn ? null : _signIn,
                                  child: Text(_signingIn
                                      ? 'Открываем вход…'
                                      : 'Войти или зарегистрироваться'),
                                ),
                              if (_accountLoading)
                                const Padding(
                                  padding: EdgeInsets.only(top: AppSpacing.md),
                                  child: LinearProgressIndicator(),
                                ),
                              if (_accountFailed)
                                TextButton.icon(
                                  onPressed: _refreshAccount,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text(
                                      'Не удалось обновить · повторить'),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (var i = 0; i < rows.length; i++) ...[
                          _ProfileRow(
                            rowKey: ValueKey('profile-row-$i'),
                            spec: rows[i],
                            onTap: rows[i].destination != null
                                ? widget.onNavigate == null
                                    ? null
                                    : () =>
                                        _openDestination(rows[i].destination!)
                                : i == 6 && _consentLoadFailed
                                    ? _loadConsent
                                    : rows[i].switchValue != null &&
                                            rows[i].onSwitch != null
                                        ? () => rows[i]
                                            .onSwitch!(!rows[i].switchValue!)
                                        : null,
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
                        if (_account != null && widget.onLogout != null) ...[
                          const SizedBox(height: AppSpacing.xl),
                          Center(
                            child: TextButton.icon(
                              key: const ValueKey('profile-logout'),
                              onPressed: _loggingOut ? null : _logout,
                              style: TextButton.styleFrom(
                                  foregroundColor: palette.error),
                              icon: AppIcon(AppIcons.logout,
                                  size: 19, color: palette.error),
                              label: Text(_loggingOut ? 'Выходим…' : 'Выйти'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    return Semantics(
      button: spec.destination != null,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
          child: Container(
            key: rowKey,
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxxl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            decoration:
                BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.lg)),
            child: Row(
              children: [
                AppIcon(spec.icon, size: 24, color: palette.accent),
                const SizedBox(width: AppSpacing.xxxl),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        spec.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium
                            .copyWith(color: palette.textPrimary),
                      ),
                      Text(
                        spec.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label
                            .copyWith(color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                if (spec.destination == null)
                  _ProfileSwitch(
                    key: ValueKey(
                      spec.icon == AppIcons.theme
                          ? 'profile-theme-switch'
                          : 'profile-telemetry-switch',
                    ),
                    label: spec.title,
                    value: spec.switchValue ?? false,
                    onChanged: spec.onSwitch,
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
      ),
    );
  }
}

class _ProfileSwitch extends StatelessWidget {
  const _ProfileSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.themeIcon,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool themeIcon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: label,
      toggled: value,
      enabled: onChanged != null,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: SizedBox(
          width: 50,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              width: 50,
              height: 30,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color:
                    themeIcon || value ? palette.accentSoft : palette.divider,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                    color: palette.textSecondary.withValues(alpha: 0.25)),
              ),
              child: AnimatedAlign(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
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
