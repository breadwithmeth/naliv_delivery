import 'dart:async';

import 'package:flutter/material.dart';
import 'package:naliv_delivery/design/tokens.dart';
import 'package:naliv_delivery/services/app_update_service.dart';

class AppUpdateNotice extends StatefulWidget {
  const AppUpdateNotice({super.key, required this.child, this.service});

  final Widget child;
  final AppUpdateService? service;

  @override
  State<AppUpdateNotice> createState() => _AppUpdateNoticeState();
}

class _AppUpdateNoticeState extends State<AppUpdateNotice>
    with WidgetsBindingObserver {
  late final AppUpdateService _service =
      widget.service ?? AppUpdateService.production();
  AppLifecycleState? _lifecycle;
  bool _routeCurrent = false;
  bool _showing = false;
  int _visit = 0;

  bool get _eligible =>
      mounted &&
      (_lifecycle == null || _lifecycle == AppLifecycleState.resumed) &&
      ModalRoute.of(context)?.isCurrent == true;

  @override
  void initState() {
    super.initState();
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent == true;
    if (_routeCurrent && !current) _visit++;
    _routeCurrent = current;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state != AppLifecycleState.resumed) {
      _visit++;
    } else {
      unawaited(_check());
    }
  }

  Future<void> _check() async {
    if (_showing || !_eligible) return;
    // Each foreground opportunity keeps its own visit guard. The service shares
    // pending I/O; an earlier visit must not swallow a later resume.
    final visit = _visit;
    final offer = await _service.check();
    if (!mounted ||
        !_eligible ||
        visit != _visit ||
        offer == null ||
        _showing) {
      return;
    }
    _showing = true;
    var snoozed = false;
    void snooze() {
      if (snoozed) return;
      snoozed = true;
      unawaited(_service.snooze(offer));
    }

    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: false,
        builder: (_) =>
            _UpdateDialog(offer: offer, service: _service, onDismiss: snooze),
      );
    } finally {
      snooze(); // Barrier and system back have the same release-specific cooldown.
      _showing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.offer,
    required this.service,
    required this.onDismiss,
  });

  final AppUpdateOffer offer;
  final AppUpdateService service;
  final VoidCallback onDismiss;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _opening = false;
  bool _failed = false;
  bool _closed = false;

  String get _store => widget.offer.platform == AppUpdatePlatform.android
      ? 'Google Play'
      : 'App Store';

  void _dismiss() {
    if (_closed) return;
    _closed = true;
    widget.onDismiss();
    Navigator.of(context).pop();
  }

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _failed = false;
    });
    final opened = await widget.service.openStore(widget.offer);
    if (!mounted || _closed || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    if (opened) {
      _dismiss();
    } else {
      setState(() {
        _opening = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('app-update-notice'),
    scrollable: true,
    title: const Text('Доступно обновление'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Версия ${widget.offer.version} уже доступна в $_store. '
          'Обновите приложение, когда будет удобно.',
        ),
        if (_failed) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Не удалось открыть $_store. Попробуйте ещё раз или '
            'обновите приложение позже.',
            key: const ValueKey('app-update-open-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        key: const ValueKey('app-update-later'),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.standard,
          minimumSize: const Size(
            AppSpacing.touchTarget,
            AppSpacing.touchTarget,
          ),
        ),
        onPressed: _dismiss,
        child: const Text('Позже'),
      ),
      FilledButton(
        key: const ValueKey('app-update-now'),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.standard,
          minimumSize: const Size(
            AppSpacing.touchTarget,
            AppSpacing.touchTarget,
          ),
        ),
        onPressed: _opening ? null : _open,
        child: const Text('Обновить'),
      ),
    ],
  );
}
