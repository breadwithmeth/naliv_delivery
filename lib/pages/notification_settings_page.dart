import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../services/notification_service.dart';
import '../ui/app_top_bar.dart';
import '../ui/frosted_surface.dart';
import '../ui/settings_widgets.dart';

/// Notification preferences, not an inbox without a backing history API.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with WidgetsBindingObserver {
  static const double _maxWidth = 520;
  static const _options = [
    (
      topic: 'orders',
      title: 'Заказы',
      detail: 'Статус, подтверждение и готовность',
      icon: Icons.receipt_long_outlined
    ),
    (
      topic: 'promotions',
      title: 'Акции и предложения',
      detail: 'Скидки и специальные предложения',
      icon: Icons.local_offer_outlined
    ),
    (
      topic: 'delivery',
      title: 'Доставка',
      detail: 'Курьер в пути и прибытие',
      icon: Icons.delivery_dining_outlined
    ),
  ];

  static String _preferenceKey(String topic) =>
      NotificationService.topicPreferenceKey(topic);

  final Map<String, bool> _values = {};
  final Set<String> _pendingTopics = {};
  SharedPreferences? _preferences;
  PushPermissionState? _permissionState;
  bool _loading = true;
  bool _loadFailed = false;
  bool _permissionRefreshing = false;
  bool _actionRunning = false;

  bool get _supportsPush =>
      _pushPlatform && (_permissionState?.supported ?? true);

  bool get _pushPlatform =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pushPlatform && !_loading) {
      _refreshPermission();
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        for (final option in _options) {
          _values[option.topic] =
              NotificationService.topicEnabled(preferences, option.topic);
        }
        _loading = false;
      });
      if (_pushPlatform) await _refreshPermission();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _refreshPermission() async {
    if (_permissionRefreshing) return;
    _permissionRefreshing = true;
    try {
      final permissionState =
          await NotificationService.instance.getPermissionState();
      if (mounted) setState(() => _permissionState = permissionState);
    } catch (_) {
      // The row keeps saying the status is unknown.
    } finally {
      _permissionRefreshing = false;
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggle(String topic, bool value) async {
    final preferences = _preferences;
    if (!_supportsPush ||
        preferences == null ||
        _pendingTopics.contains(topic)) {
      return;
    }
    final previous = _values[topic]!;
    setState(() {
      _values[topic] = value;
      _pendingTopics.add(topic);
    });
    try {
      final saved = await preferences.setBool(_preferenceKey(topic), value);
      if (!saved) throw StateError('Could not save notification preference');
      if (value) {
        await NotificationService.instance.subscribeToTopic(topic);
      } else {
        await NotificationService.instance.unsubscribeFromTopic(topic);
      }
    } catch (_) {
      await preferences
          .setBool(_preferenceKey(topic), previous)
          .catchError((_) => false);
      if (!mounted) return;
      setState(() => _values[topic] = previous);
      _showMessage('Не удалось сохранить настройку уведомлений');
    } finally {
      if (mounted) setState(() => _pendingTopics.remove(topic));
    }
  }

  Future<void> _clearNotifications() async {
    if (_actionRunning) return;
    setState(() => _actionRunning = true);
    try {
      await NotificationService.instance.clearAllNotifications();
      if (mounted) _showMessage('Текущие уведомления очищены');
    } catch (_) {
      if (mounted) _showMessage('Не удалось очистить уведомления');
    } finally {
      if (mounted) setState(() => _actionRunning = false);
    }
  }

  Future<void> _enablePush() async {
    if (_actionRunning) return;
    setState(() => _actionRunning = true);
    try {
      final granted =
          await NotificationService.instance.enablePushNotifications();
      await _refreshPermission();
      if (mounted) {
        _showMessage(granted
            ? 'Разрешение на push-уведомления получено'
            : 'Push-уведомления недоступны или разрешение не получено');
      }
    } catch (_) {
      if (mounted) _showMessage('Не удалось включить push-уведомления');
    } finally {
      if (mounted) setState(() => _actionRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: FrostedHeaderLayout(
        header: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
              child: AppTopBar(title: 'Уведомления'),
            ),
          ),
        ),
        body: (context, topInset) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: _loading
                ? Padding(
                    padding: EdgeInsets.only(top: topInset),
                    child: const Center(child: CircularProgressIndicator()),
                  )
                : _loadFailed
                    ? Padding(
                        padding: EdgeInsets.only(top: topInset),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Не удалось загрузить настройки',
                                  style: AppTypography.title
                                      .copyWith(color: palette.textPrimary)),
                              const SizedBox(height: AppSpacing.xl),
                              TextButton(
                                onPressed: _loadSettings,
                                child: const Text('Повторить'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _settings(palette, topInset),
          ),
        ),
      ),
    );
  }

  String get _permissionLine {
    final state = _permissionState;
    if (state == null) return 'Статус разрешения не получен';
    if (!state.supported) {
      return 'Браузер не поддерживает push на этом устройстве';
    }
    if (!state.permissionGranted) {
      return 'Разрешение на уведомления не получено';
    }
    if (!state.optedIn) return 'Разрешение есть, подписка выключена';
    return 'Уведомления разрешены, подписка включена';
  }

  bool get _mobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Widget _settings(AppPalette palette, double topInset) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        topInset + AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.huge + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        SettingsSection(
          title: 'Это устройство',
          children: [
            if (_supportsPush)
              SettingsRow(
                key: const ValueKey('notification-enable-push'),
                icon: Icons.notifications_active_outlined,
                title: 'Включить push-уведомления',
                subtitle: _permissionLine,
                onTap: _actionRunning ? null : _enablePush,
              )
            else
              SettingsRow(
                key: const ValueKey('notification-push-unavailable'),
                icon: Icons.notifications_off_outlined,
                title: 'Push-уведомления',
                subtitle: _pushPlatform
                    ? _permissionLine
                    : 'На этом устройстве push-уведомления недоступны',
              ),
            if (_supportsPush && _mobilePlatform)
              SettingsRow(
                key: const ValueKey('notification-clear'),
                icon: Icons.clear_all,
                title: 'Очистить текущие уведомления',
                onTap: _actionRunning ? null : _clearNotifications,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.huge),
        SettingsSection(
          title: 'Что присылать',
          children: [
            for (final option in _options)
              SettingsRow(
                key: ValueKey('notification-topic-${option.topic}'),
                icon: option.icon,
                title: option.title,
                subtitle: option.detail,
                switchValue: _values[option.topic] ?? false,
                onSwitch:
                    !_supportsPush || _pendingTopics.contains(option.topic)
                        ? null
                        : (value) => _toggle(option.topic, value),
              ),
          ],
        ),
      ],
    );
  }
}
