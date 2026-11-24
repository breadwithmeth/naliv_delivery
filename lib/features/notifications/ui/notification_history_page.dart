import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../services/auth_service.dart';
import '../../../ui/app_states.dart';
import '../../../ui/app_top_bar.dart';
import '../../../ui/settings_widgets.dart';
import '../notification_history.dart';

/// Shows notifications saved on this device for the active account.
class NotificationHistoryPage extends StatefulWidget {
  const NotificationHistoryPage({super.key, required this.onSettings});

  final VoidCallback onSettings;

  @override
  State<NotificationHistoryPage> createState() => _NotificationHistoryPageState();
}

class _NotificationHistoryPageState extends State<NotificationHistoryPage> {
  final _history = NotificationHistory.instance;
  List<HistoryNotification>? _entries;
  bool _loadFailed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    AuthService.sessionRevision.addListener(_sessionChanged);
    _history.addListener(_historyChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    AuthService.sessionRevision.removeListener(_sessionChanged);
    _history.removeListener(_historyChanged);
    super.dispose();
  }

  void _sessionChanged() {
    setState(() {
      _entries = null;
      _loadFailed = false;
    });
    unawaited(_load());
  }

  void _historyChanged() => unawaited(_load());

  void _retry() {
    setState(() => _loadFailed = false);
    unawaited(_load());
  }

  Future<void> _load() async {
    final request = ++_request;
    final identity = AuthService.verifiedIdentity;
    if (identity == null) return;
    final revision = AuthService.sessionRevision.value;
    List<HistoryNotification>? entries;
    try {
      entries = await _history.read(identity);
    } catch (_) {
      // A failed local read is not an empty inbox.
    }
    if (!mounted ||
        request != _request ||
        revision != AuthService.sessionRevision.value ||
        identity != AuthService.verifiedIdentity) {
      return;
    }
    setState(() {
      _entries = entries;
      _loadFailed = entries == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppTopBar(title: 'Уведомления'),
                  const SizedBox(height: AppSpacing.xl),
                  Material(
                    color: palette.surface,
                    borderRadius: AppRadii.lgAll,
                    clipBehavior: Clip.antiAlias,
                    child: SettingsRow(
                      title: MediaQuery.textScalerOf(context).scale(16) > 24
                          ? 'Настройки'
                          : 'Настройки уведомлений',
                      icon: Icons.settings_outlined,
                      chevron: true,
                      onTap: widget.onSettings,
                    ),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      key: ValueKey(AuthService.sessionRevision.value),
                      primary: true,
                      slivers: [_content(context)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final entries = _entries;
    if (AuthService.verifiedIdentity == null) {
      return _status(const AppEmptyState(
        title: 'Войдите, чтобы увидеть уведомления',
        muted: true,
      ));
    }
    if (_loadFailed) {
      return _status(AppEmptyState(
        title: 'Не удалось загрузить уведомления',
        action: OutlinedButton(
          onPressed: _retry,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: context.palette.textSecondary),
          ),
          child: const Text('Повторить'),
        ),
      ));
    }
    if (entries == null) {
      return _status(Semantics(
        label: 'Загрузка уведомлений',
        child: const AppLoading(),
      ));
    }
    if (entries.isEmpty) {
      return _status(const AppEmptyState(title: 'Уведомлений нет', muted: true));
    }

    final thisYear = DateTime.now().year;
    final currentDate = DateFormat.MMMMd('ru');
    final earlierDate = DateFormat.yMMMMd('ru');
    return SliverPadding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
      sliver: SliverList.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) => const Divider(height: AppSpacing.huge + 1),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final date = entry.receivedAt.toLocal();
          return _NotificationRow(
            entry: entry,
            dateLabel: (date.year == thisYear ? currentDate : earlierDate)
                .format(date),
          );
        },
      ),
    );
  }

  // The empty Figma message is centered within the screen, above the center
  // of the area below the settings row. Keep that bias without a fixed offset.
  Widget _status(Widget child) => SliverFillRemaining(
        hasScrollBody: false,
        child: Align(
          alignment: const Alignment(0, -.3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Semantics(liveRegion: true, child: child)],
          ),
        ),
      );
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.entry, required this.dateLabel});

  final HistoryNotification entry;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final primary = palette.textPrimary;
    final secondary = palette.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.title.isNotEmpty) ...[
          Text(entry.title, style: AppTypography.titleMedium.copyWith(color: primary)),
          const SizedBox(height: AppSpacing.md),
        ],
        if (entry.body.isNotEmpty) ...[
          Text(entry.body, style: AppTypography.bodySmall.copyWith(color: secondary)),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(dateLabel, style: AppTypography.caption.copyWith(color: secondary)),
      ],
    );
  }
}
