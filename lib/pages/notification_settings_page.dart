import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../services/notification_service.dart';
import '../ui/app_top_bar.dart';

/// Notification preferences, not an inbox without a backing history API.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
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

  static String _preferenceKey(String topic) => 'notification_topic_$topic';

  final Map<String, bool> _values = {};
  final Set<String> _pendingTopics = {};
  SharedPreferences? _preferences;
  String? _subscriptionId;
  bool _loading = true;
  bool _loadFailed = false;
  bool _subscriptionFailed = false;
  bool _subscriptionRefreshing = false;
  bool _actionRunning = false;

  bool get _supportsPush =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
              preferences.getBool(_preferenceKey(option.topic)) ?? false;
        }
        _loading = false;
      });
      if (_supportsPush) await _refreshSubscriptionId();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _refreshSubscriptionId() async {
    if (_subscriptionRefreshing) return;
    setState(() => _subscriptionRefreshing = true);
    try {
      final subscriptionId =
          await NotificationService.instance.getCurrentSubscriptionId();
      if (!mounted) return;
      setState(() {
        _subscriptionId = subscriptionId;
        _subscriptionFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subscriptionId = null;
        _subscriptionFailed = true;
      });
    } finally {
      if (mounted) setState(() => _subscriptionRefreshing = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggle(String topic, bool value) async {
    final preferences = _preferences;
    if (!_supportsPush || preferences == null || _pendingTopics.contains(topic)) {
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
      await _refreshSubscriptionId();
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
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: AppTopBar(title: 'Настройки уведомлений'),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _loadFailed
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Не удалось загрузить настройки',
                                      style: AppTypography.title.copyWith(
                                          color: palette.textPrimary)),
                                  const SizedBox(height: AppSpacing.xl),
                                  TextButton(
                                    onPressed: _loadSettings,
                                    child: const Text('Повторить'),
                                  ),
                                ],
                              ),
                            )
                          : ListView(
                              padding: EdgeInsets.fromLTRB(
                                AppSpacing.xxxl,
                                AppSpacing.huge,
                                AppSpacing.xxxl,
                                AppSpacing.huge +
                                    MediaQuery.paddingOf(context).bottom,
                              ),
                              children: [
                                Text(
                                    'Выберите, о чём получать push-уведомления',
                                    style: AppTypography.body.copyWith(
                                        color: palette.textSecondary)),
                                const SizedBox(height: AppSpacing.huge),
                                for (final option in _options) ...[
                                  _NotificationPreference(
                                    title: option.title,
                                    detail: option.detail,
                                    icon: option.icon,
                                    value: _values[option.topic]!,
                                    onChanged: !_supportsPush ||
                                            _pendingTopics.contains(option.topic)
                                        ? null
                                        : (value) =>
                                            _toggle(option.topic, value),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                ],
                                const SizedBox(height: AppSpacing.xl),
                                if (_supportsPush) ...[
                                  Text('Управление',
                                      style: AppTypography.title.copyWith(
                                          color: palette.textPrimary)),
                                  const SizedBox(height: AppSpacing.xl),
                                  _ActionRow(
                                    icon: Icons.notifications_active_outlined,
                                    title: 'Включить push-уведомления',
                                    onTap: _actionRunning ? null : _enablePush,
                                  ),
                                  if (!kIsWeb &&
                                      (defaultTargetPlatform ==
                                              TargetPlatform.android ||
                                          defaultTargetPlatform ==
                                              TargetPlatform.iOS)) ...[
                                    const SizedBox(height: AppSpacing.md),
                                    _ActionRow(
                                      icon: Icons.clear_all,
                                      title: 'Очистить текущие уведомления',
                                      onTap: _actionRunning
                                          ? null
                                          : _clearNotifications,
                                    ),
                                  ],
                                ] else
                                  Text(
                                      'На этом устройстве push-уведомления недоступны',
                                      style: AppTypography.body.copyWith(
                                          color: palette.textSecondary)),
                                if (_supportsPush) ...[
                                  const SizedBox(height: AppSpacing.huge),
                                  Text('Подписка',
                                      style: AppTypography.title.copyWith(
                                          color: palette.textPrimary)),
                                  const SizedBox(height: AppSpacing.xl),
                                  _ActionRow(
                                    icon: Icons.info_outline,
                                    title: _subscriptionRefreshing
                                        ? 'Обновление ID подписки…'
                                        : _subscriptionId ??
                                            (_subscriptionFailed
                                                ? 'Не удалось получить ID подписки · повторить'
                                                : 'ID подписки не получен · обновить'),
                                    onTap: _subscriptionRefreshing
                                        ? null
                                        : _subscriptionId == null
                                            ? _refreshSubscriptionId
                                            : () async {
                                                final id = _subscriptionId!;
                                                try {
                                                  await Clipboard.setData(
                                                      ClipboardData(text: id));
                                                  if (mounted) {
                                                    _showMessage('ID скопирован');
                                                  }
                                                } catch (_) {
                                                  if (mounted) {
                                                    _showMessage(
                                                        'Не удалось скопировать ID');
                                                  }
                                                }
                                              },
                                    trailing: _subscriptionId == null
                                        ? null
                                        : const Icon(Icons.copy_outlined),
                                  ),
                                ],
                              ],
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

class _NotificationPreference extends StatelessWidget {
  const _NotificationPreference({
    required this.title,
    required this.detail,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String detail;
  final IconData icon;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        secondary: Icon(icon, color: palette.accent),
        title: Text(title,
            style:
                AppTypography.titleMedium.copyWith(color: palette.textPrimary)),
        subtitle: Text(detail,
            style:
                AppTypography.bodySmall.copyWith(color: palette.textSecondary)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: ListTile(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg)),
        leading: Icon(icon, color: palette.accent),
        title: Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                AppTypography.bodyMedium.copyWith(color: palette.textPrimary)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
