import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/destinations.dart';
import '../../../core/theme_controller.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../services/auth_service.dart';
import '../../../services/telemetry_consent_service.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/app_top_bar.dart';
import '../../../ui/frosted_controls.dart';
import '../../../ui/frosted_surface.dart';
import '../../../ui/settings_widgets.dart';

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

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  static const double _maxWidth = 520;
  bool? _consent;
  bool _consentSaving = false;
  bool _consentLoadFailed = false;
  bool _themeSaving = false;
  ProfileAccount? _account;
  bool _accountLoading = false;
  bool _accountFailed = false;
  bool _signingIn = false;
  bool _loggingOut = false;
  bool _logoutFailed = false;
  late int _credentialRevision;
  int _accountLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _credentialRevision = AuthService.credentialRevision;
    WidgetsBinding.instance.addObserver(this);
    AuthService.sessionRevision.addListener(_onSessionChanged);
    _account = widget.account;
    _refreshAccount();
    _loadConsent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthService.sessionRevision.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAccount();
  }

  void _onSessionChanged() {
    final revision = AuthService.credentialRevision;
    if (!mounted || revision == _credentialRevision) return;
    _credentialRevision = revision;
    _accountLoadGeneration++;
    setState(() {
      _account = null;
      _accountLoading = false;
      _accountFailed = false;
    });
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
    final revision = AuthService.credentialRevision;
    final generation = ++_accountLoadGeneration;
    bool current() =>
        mounted &&
        generation == _accountLoadGeneration &&
        revision == AuthService.credentialRevision &&
        !AuthService.isEndingSession;
    setState(() {
      _accountLoading = true;
      _accountFailed = false;
    });
    try {
      final session = await AuthService.captureSession();
      if (!current()) return;
      final account = await load();
      if (current() && (session == null || session.isCurrent)) {
        setState(() => _account = account);
      }
    } catch (_) {
      if (current()) setState(() => _accountFailed = true);
    } finally {
      if (current()) setState(() => _accountLoading = false);
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
      if (mounted) setState(() => _logoutFailed = false);
    } catch (_) {
      if (mounted) {
        setState(() => _logoutFailed = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Не удалось завершить выход. Повторите попытку.'),
        ));
      }
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
    final navigate = widget.onNavigate;
    VoidCallback? open(AppDestination destination) =>
        navigate == null ? null : () => _openDestination(destination);
    final showLogout =
        (_account != null || _logoutFailed) && widget.onLogout != null;

    final sections = <Widget>[
      SettingsSection(
        title: 'Заказы и покупки',
        children: [
          SettingsRow(
            key: const ValueKey('profile-row-orders'),
            iconAsset: AppIcons.orders,
            title: 'История заказов',
            subtitle: 'Активные и завершённые заказы',
            chevron: true,
            onTap: open(AppDestination.orders),
          ),
          SettingsRow(
            key: const ValueKey('profile-row-certificates'),
            iconAsset: AppIcons.certificates,
            title: 'Сертификаты',
            subtitle: 'Покупка и активация по коду',
            chevron: true,
            onTap: open(AppDestination.certificates),
          ),
        ],
      ),
      SettingsSection(
        title: 'Оплата и доставка',
        children: [
          SettingsRow(
            key: const ValueKey('profile-row-addresses'),
            iconAsset: AppIcons.addresses,
            title: 'Адреса',
            subtitle: _summary(
                _account?.addressSummary, 'Войдите, чтобы сохранить адрес'),
            subtitleSemantics: _account?.addressSummary,
            chevron: true,
            onTap: open(AppDestination.addresses),
          ),
          SettingsRow(
            key: const ValueKey('profile-row-cards'),
            iconAsset: AppIcons.cards,
            title: 'Карты',
            subtitle: _summary(
                _account?.cardsSummary, 'Войдите, чтобы управлять картами'),
            chevron: true,
            onTap: open(AppDestination.cards),
          ),
        ],
      ),
      SettingsSection(
        title: 'Приложение',
        footer: 'Если сбор включён, приложение отправляет разработчикам отчёты '
            'о сбоях, чтобы ошибки исправлялись быстрее. По умолчанию он '
            'выключен, настройку можно изменить в любой момент.',
        children: [
          SettingsRow(
            key: const ValueKey('profile-row-theme'),
            iconAsset: AppIcons.theme,
            title: 'Тема оформления',
            subtitle: _themeSaving
                ? 'Сохраняем тему…'
                : switch (theme.mode) {
                    ThemeMode.light => 'Всегда светлая',
                    ThemeMode.dark => 'Всегда тёмная',
                    ThemeMode.system => 'Как на устройстве',
                  },
            below: SettingsChoice<ThemeMode>(
              key: const ValueKey('profile-theme-choice'),
              groupLabel: 'Тема оформления',
              value: theme.mode,
              onChanged: _themeSaving ? null : (mode) => _setTheme(theme, mode),
              options: const [
                SettingsChoiceOption(
                  key: ValueKey('profile-theme-light'),
                  value: ThemeMode.light,
                  label: 'Светлая',
                  icon: Icons.light_mode_outlined,
                ),
                SettingsChoiceOption(
                  key: ValueKey('profile-theme-dark'),
                  value: ThemeMode.dark,
                  label: 'Тёмная',
                  icon: Icons.dark_mode_outlined,
                ),
                SettingsChoiceOption(
                  key: ValueKey('profile-theme-system'),
                  value: ThemeMode.system,
                  label: 'Авто',
                  icon: Icons.brightness_auto_outlined,
                ),
              ],
            ),
          ),
          SettingsRow(
            key: const ValueKey('profile-row-notifications'),
            iconAsset: AppIcons.bell,
            title: 'Уведомления',
            subtitle: 'Заказы, акции и доставка',
            chevron: true,
            onTap: open(AppDestination.notifications),
          ),
          SettingsRow(
            key: const ValueKey('profile-row-telemetry'),
            iconAsset: AppIcons.analytics,
            title: 'Сбор информации',
            subtitle: _consentLoadFailed
                ? 'Ошибка настройки · повторить'
                : _consent == null
                    ? 'Загрузка настройки…'
                    : _consentSaving
                        ? 'Сохраняем настройку…'
                        : _consent!
                            ? 'Отправляем отчёты об ошибках'
                            : 'Отчёты об ошибках не отправляются',
            switchKey: const ValueKey('profile-telemetry-switch'),
            switchValue: _consent ?? false,
            onSwitch: _consent == null || _consentSaving ? null : _setConsent,
            onTap: _consentLoadFailed ? _loadConsent : null,
          ),
        ],
      ),
      SettingsSection(
        title: 'Помощь',
        children: [
          SettingsRow(
            key: const ValueKey('profile-row-support'),
            iconAsset: AppIcons.support,
            title: 'Поддержка',
            subtitle: 'Вопросы по заказам и оплате',
            chevron: true,
            onTap: open(AppDestination.support),
          ),
          SettingsRow(
            key: const ValueKey('profile-row-faq'),
            iconAsset: AppIcons.faq,
            title: 'FAQ',
            subtitle: 'Вход, доставка, оплата и бонусы',
            chevron: true,
            onTap: open(AppDestination.faq),
          ),
        ],
      ),
      if (showLogout)
        SettingsSection(
          children: [
            SettingsRow(
              key: const ValueKey('profile-logout'),
              iconAsset: AppIcons.logout,
              title: _loggingOut ? 'Выходим…' : 'Выйти',
              destructive: true,
              onTap: _loggingOut ? null : _logout,
            ),
          ],
        ),
    ];

    return Scaffold(
      backgroundColor: palette.background,
      body: FrostedHeaderLayout(
        header: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
              child: AppTopBar(
                title: 'Профиль',
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ),
        body: (context, topInset) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: RefreshIndicator(
              edgeOffset: topInset,
              onRefresh: _refreshAccount,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xxxl,
                  topInset + AppSpacing.xxxl,
                  AppSpacing.xxxl,
                  AppSpacing.huge + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _accountHeader(palette),
                    if (_accountLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.xl),
                        child: LinearProgressIndicator(),
                      ),
                    if (_accountFailed)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _refreshAccount,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Не удалось обновить · повторить'),
                        ),
                      ),
                    for (final section in sections) ...[
                      const SizedBox(height: AppSpacing.huge),
                      section,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Who is signed in, or an invitation to sign in. Left-aligned so the name reads as the
  /// page's title block, with the sign-in action directly beneath it for guests.
  Widget _accountHeader(AppPalette palette) {
    final account = _account;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final name =
        account == null ? 'Вы не вошли' : account.name ?? 'Личный кабинет';
    final detail = account == null
        ? 'Войдите, чтобы пользоваться заказами и картами'
        : account.phone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration:
                  reduced ? Duration.zero : const Duration(milliseconds: 200),
              key: const ValueKey('profile-avatar'),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Center(child: AppIcon(AppIcons.avatar, size: 38)),
            ),
            const SizedBox(width: AppSpacing.xxxl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    key:
                        account == null ? null : const ValueKey('profile-name'),
                    style: AppTypography.headlineMedium
                        .copyWith(color: palette.textPrimary),
                  ),
                  if (detail != null)
                    Text(
                      detail,
                      style: AppTypography.bodySmall
                          .copyWith(color: palette.textSecondary),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (account == null && widget.onSignIn != null) ...[
          const SizedBox(height: AppSpacing.xxxl),
          FrostedButton(
            buttonKey: const ValueKey('profile-sign-in'),
            onPressed: _signingIn ? null : _signIn,
            borderRadius: AppRadii.pillAll,
            minHeight: 49,
            child: Text(_signingIn
                ? 'Открываем вход…'
                : 'Войти или зарегистрироваться'),
          ),
        ],
      ],
    );
  }

  Future<void> _setTheme(ThemeController theme, ThemeMode mode) async {
    setState(() => _themeSaving = true);
    try {
      await theme.setMode(mode);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить тему')),
        );
      }
    } finally {
      if (mounted) setState(() => _themeSaving = false);
    }
  }

  Future<void> _setConsent(bool value) async {
    setState(() {
      _consent = value;
      _consentSaving = true;
    });
    try {
      await TelemetryConsentService.setConsent(value);
    } catch (_) {
      await _loadConsent();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Не удалось сохранить настройку'),
      ));
    } finally {
      if (mounted) setState(() => _consentSaving = false);
    }
  }
}
