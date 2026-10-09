import 'dart:async';

import 'package:flutter/material.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/design/tokens.dart';
import 'package:naliv_delivery/design/typography.dart';
import 'package:naliv_delivery/features/faq/ui/faq_page.dart';
import 'package:naliv_delivery/features/faq/models/faq.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/services/notification_service.dart';
import 'package:naliv_delivery/services/chat_api_service.dart';
import 'package:naliv_delivery/ui/app_icon.dart';
import 'package:naliv_delivery/ui/app_top_bar.dart';
import 'package:naliv_delivery/ui/surfaces.dart';
import 'package:naliv_delivery/core/money.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/order_ui_helpers.dart' as order_ui;

class HelpChatPage extends StatefulWidget {
  final Map<String, dynamic>? order;
  final String entryPoint;
  final String? initialTopic;
  final String? paymentError;

  /// Optional transport owned and disposed by this page.
  ///
  /// Supply a fresh service for each mounted page, not a shared singleton.
  final ChatApiService? chatService;
  final String? sessionId;
  final int? messageId;
  final NotificationService? notificationService;
  final Future<String?> Function()? resolveIdentity;

  const HelpChatPage({
    super.key,
    this.order,
    required this.entryPoint,
    this.initialTopic,
    this.paymentError,
    this.chatService,
    this.sessionId,
    this.messageId,
    this.notificationService,
    this.resolveIdentity,
  });

  @override
  State<HelpChatPage> createState() => _HelpChatPageState();
}

class _HelpChatPageState extends State<HelpChatPage>
    with WidgetsBindingObserver {
  late final ChatApiService _chatService;
  late final NotificationService _notifications;
  final _messageController = TextEditingController();
  final _messageFocus = FocusNode();
  final _scrollController = ScrollController();
  final _messages = <ChatMessage>[];
  final _sentOrderContextKeys = <String>{};
  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<SupportNotificationTarget>? _pushSubscription;
  VoidCallback? _unregisterSupportPage;
  Map<String, dynamic>? _selectedOrder;
  WidgetConfig? _config;
  String? _conversationId;
  String? _historyError;
  String? _sendError;
  String? _contextError;
  bool _loading = true;
  bool _sessionFailed = false;
  bool _sending = false;
  bool _sendingContext = false;
  bool _profileSyncStarted = false;
  bool _connecting = false;
  bool _foreground = true;
  bool _routeVisible = true;
  bool _reconnectQueued = false;
  bool _refreshingHistory = false;
  bool _historyRefreshQueued = false;
  int _pageGeneration = 0;
  final _composerKey = GlobalKey();
  double _composerExtent = 90;
  bool _composerMeasureQueued = false;

  @override
  void initState() {
    super.initState();
    _chatService = widget.chatService ?? ChatApiService();
    _notifications = widget.notificationService ?? NotificationService.instance;
    _selectedOrder = widget.order;
    WidgetsBinding.instance.addObserver(this);
    _messageSubscription = _chatService.messages.listen(
      _onMessageReceived,
      onError: _onStreamError,
    );
    AuthService.sessionRevision.addListener(_onIdentityChanged);
    _pushSubscription = _notifications.supportUpdates.listen(_onSupportPush);
    _unregisterSupportPage = _notifications.registerSupportPage(
      (identity, sessionId) =>
          mounted &&
          _foreground &&
          ModalRoute.of(context)?.isCurrent == true &&
          _chatService.identity == identity &&
          _chatService.sessionId == sessionId,
    );
    unawaited(_tryConnect());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    final returned = visible && !_routeVisible;
    _routeVisible = visible;
    _chatService.setForeground(_foreground && visible);
    if (returned && _foreground) unawaited(_refreshHistory());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthService.sessionRevision.removeListener(_onIdentityChanged);
    _pushSubscription?.cancel();
    _unregisterSupportPage?.call();
    _messageSubscription?.cancel();
    _chatService.dispose();
    _messageController.dispose();
    _messageFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_messageFocus.hasFocus || _nearBottom) _scrollDown();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _chatService.setForeground(_foreground && _routeVisible);
    if (_foreground && _routeVisible) unawaited(_refreshHistory());
  }

  void _onIdentityChanged() {
    if (!mounted) return;
    _pageGeneration++;
    _chatService.setForeground(false);
    setState(() {
      _messages.clear();
      _messageController.clear();
      _selectedOrder = null;
      _conversationId = null;
      _sentOrderContextKeys.clear();
      _profileSyncStarted = false;
      _historyRefreshQueued = false;
      _sendError = null;
      _contextError = null;
      _sending = false;
      _sendingContext = false;
      _sessionFailed = true;
      _historyError = 'Учётная запись изменилась. Переписка закрыта.';
    });
    _reconnectQueued = !AuthService.isEndingSession;
    if (_reconnectQueued && !_connecting) {
      _reconnectQueued = false;
      unawaited(_tryConnect());
    }
  }

  void _onSupportPush(SupportNotificationTarget target) {
    if (!mounted ||
        !_foreground ||
        target.sessionId != _chatService.sessionId ||
        !target.acceptsIdentity(_chatService.identity ?? '') ||
        (ModalRoute.of(context)?.isCurrent != true)) {
      return;
    }
    unawaited(_refreshHistory());
  }

  Future<void> _refreshHistory() async {
    if (_refreshingHistory || _connecting) {
      _historyRefreshQueued = true;
      return;
    }
    if (!_chatService.hasSession || !_foreground || !_routeVisible) return;
    final generation = _pageGeneration;
    _refreshingHistory = true;
    try {
      final result = await _chatService.fetchHistory();
      if (!mounted || generation != _pageGeneration) return;
      setState(() {
        switch (result) {
          case FetchSuccess(:final messages):
            _historyError = null;
            for (final message in messages) {
              _mergeMessage(message);
            }
          case FetchSessionExpired():
            _sessionFailed = true;
            _historyError = 'Сессия чата истекла. Подключитесь заново.';
          case FetchFailure(:final error):
            _historyError = 'Не удалось загрузить сообщения: $error';
        }
      });
      if (result is FetchSuccess) _scrollDown();
    } finally {
      _refreshingHistory = false;
      if (_historyRefreshQueued && mounted) {
        _historyRefreshQueued = false;
        unawaited(_refreshHistory());
      }
    }
  }

  Future<void> _tryConnect() async {
    if (_connecting || AuthService.isEndingSession) return;
    _connecting = true;
    final generation = _pageGeneration;
    bool current() => mounted && generation == _pageGeneration;
    if (!_loading) {
      setState(() {
        _loading = true;
        _historyError = null;
      });
    }
    try {
      final identity = await (widget.resolveIdentity?.call() ??
          ApiService.getCurrentUserExternalId());
      if (!current()) return;
      _chatService.setForeground(_foreground && _routeVisible);
      await _chatService.init(identity: identity);
      if (!current()) return;
      final targetSession = widget.sessionId;
      if (targetSession != null &&
          (_chatService.sessionId != targetSession || identity == null)) {
        setState(() {
          _loading = false;
          _sessionFailed = true;
          _historyError = 'Это обращение недоступно в текущем аккаунте.';
        });
        return;
      }
      _config ??= await _chatService.fetchConfig();
      if (!current()) return;
      final connected = targetSession == null
          ? await _chatService.ensureSession()
          : _chatService.hasSession;
      if (!current()) return;
      if (!connected) {
        setState(() {
          _loading = false;
          _sessionFailed = true;
          _historyError = 'Не удалось подключиться к чату.';
        });
        return;
      }
      if (_conversationId != _chatService.sessionId) {
        _messages.clear();
        _sentOrderContextKeys.clear();
        _profileSyncStarted = false;
      }
      _conversationId = _chatService.sessionId;
      final result = await _chatService.fetchHistory();
      if (!current()) return;
      setState(() {
        _loading = false;
        switch (result) {
          case FetchSuccess(:final messages):
            _sessionFailed = false;
            _historyError = null;
            for (final message in messages) {
              _mergeMessage(message);
            }
          case FetchSessionExpired():
            _sessionFailed = true;
            _historyError = 'Сессия чата истекла. Подключитесь заново.';
          case FetchFailure(:final error):
            _sessionFailed = false;
            _historyError = 'Не удалось загрузить сообщения: $error';
        }
      });
      if (result is FetchSuccess) _scrollDown();
    } catch (_) {
      if (!current()) return;
      setState(() {
        _loading = false;
        _sessionFailed = true;
        _historyError = 'Не удалось подключиться к чату. Проверьте соединение.';
      });
    } finally {
      _connecting = false;
      if (_reconnectQueued && mounted) {
        _reconnectQueued = false;
        unawaited(_tryConnect());
      }
      if (_historyRefreshQueued && mounted) {
        _historyRefreshQueued = false;
        unawaited(_refreshHistory());
      }
    }
  }

  void _onMessageReceived(ChatMessage message) {
    if (!mounted) return;
    if (!_chatService.hasSession) return;
    final followLatest = _nearBottom;
    setState(() => _mergeMessage(message));
    if (followLatest) _scrollDown();
  }

  void _onStreamError(Object error) {
    if (!mounted) return;
    setState(() {
      if (error == 'SESSION_EXPIRED') {
        _sessionFailed = true;
        _historyError = 'Сессия чата истекла. Подключитесь заново.';
      } else {
        _historyError = 'Не удалось обновить сообщения: $error';
      }
    });
  }

  void _mergeMessage(ChatMessage message) {
    final index = message.id == null
        ? -1
        : _messages.indexWhere((existing) => existing.id == message.id);
    if (index == -1) {
      _messages.add(message);
    } else {
      _messages[index] = message;
    }
    if (!message.isFromOperator) {
      final orderKey = RegExp(r'Контекст обращения: заказ #([^\s]+)')
          .firstMatch(message.content)
          ?.group(1);
      if (orderKey != null) _sentOrderContextKeys.add(orderKey);
    }
  }

  bool get _nearBottom =>
      !_scrollController.hasClients ||
      _scrollController.position.extentAfter < 100;

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  String get _topic {
    final explicit = widget.initialTopic?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return switch (widget.entryPoint) {
      'payment_failure' => 'Ошибка оплаты',
      'order_detail' => 'Вопрос по заказу',
      _ => 'Поддержка',
    };
  }

  String get _statusText {
    if (_loading) return 'Загрузка сообщений…';
    if (_sessionFailed) return 'Нет подключения к чату';
    if (_historyError != null) return 'Не удалось обновить чат';
    return 'Чат поддержки';
  }

  Future<void> _sendMessage({bool attachOrder = false}) async {
    if (_sending || _loading || _sessionFailed || !_chatService.hasSession) {
      return;
    }
    final order = _selectedOrder;
    final orderKey = _orderKey(order);
    if (attachOrder && (order == null || orderKey == null)) return;
    final draft = _messageController.text;
    final generation = _pageGeneration;
    final content =
        attachOrder ? _buildOrderContextMessage(order!) : draft.trim();
    if (content.isEmpty) return;
    setState(() {
      _sending = true;
      _sendingContext = attachOrder;
      if (attachOrder) {
        _contextError = null;
      } else {
        _sendError = null;
      }
    });
    final result = await _chatService.sendMessage(content);
    if (!mounted || generation != _pageGeneration) return;
    setState(() {
      _sending = false;
      _sendingContext = false;
      switch (result) {
        case SendSuccess(:final message):
          _mergeMessage(message);
          if (attachOrder) {
            _sentOrderContextKeys.add(orderKey!);
            _contextError = null;
          } else {
            if (_messageController.text == draft) _messageController.clear();
            _sendError = null;
          }
        case SendSessionExpired():
          _sessionFailed = true;
          _historyError = 'Сессия чата истекла. Подключитесь заново.';
          if (attachOrder) {
            _contextError = 'Заказ не прикреплён.';
          } else {
            _sendError = 'Сообщение не отправлено. Текст сохранён.';
          }
        case SendFailure(:final error):
          if (attachOrder) {
            _contextError = 'Не удалось прикрепить заказ: $error';
          } else {
            _sendError = 'Сообщение не отправлено: $error';
          }
      }
    });
    if (result is SendSuccess) {
      _scrollDown();
      if (!_profileSyncStarted) {
        _profileSyncStarted = true;
        unawaited(_syncUserProfile());
      }
    }
  }

  Future<void> _syncUserProfile() async {
    // Profile mutation belongs to an explicitly sent enquiry, never opening a page.
    try {
      final info = await ApiService.getFullInfo();
      if (!mounted) return;
      final externalId = await ApiService.getCurrentUserExternalId();
      if (!mounted) return;
      if (externalId != _chatService.identity) return;
      final user = order_ui.asOrderMap(info?['user']);
      final name =
          (info?['name'] ?? user?['name'] ?? user?['login'])?.toString().trim();
      final phone = (info?['phone_number'] ??
              info?['phone'] ??
              user?['phone_number'] ??
              user?['phone'] ??
              _selectedOrder?['phone_number'] ??
              _selectedOrder?['phone'])
          ?.toString()
          .trim();
      final profileName = [
        if (name != null && name.isNotEmpty) name,
        if (externalId != null && externalId.isNotEmpty) 'id:$externalId',
      ].join(' ');
      if (profileName.isEmpty && (phone == null || phone.isEmpty)) return;
      await _chatService.updateProfile(
        name: profileName.isEmpty ? null : profileName,
        phone: phone,
      );
    } catch (_) {
      // A failed optional profile sync must not turn an accepted message into a failure.
    }
  }

  String _buildOrderContextMessage(Map<String, dynamic> order) {
    final key = _orderKey(order)!;
    final business = order_ui.asOrderMap(order['business']);
    final address = order_ui.asOrderMap(order['delivery_address']);
    final total = order_ui.resolveOrderTotalAmount(order);
    final paymentError =
        key == _orderKey(widget.order) ? widget.paymentError?.trim() : null;
    return [
      'Контекст обращения: заказ #$key',
      'Источник: $_topic',
      'Статус: ${order_ui.resolveOrderStatusText(order)}',
      'Тип: ${order_ui.resolveDeliveryTypeText(order)}',
      if (business?['name']?.toString().trim().isNotEmpty ?? false)
        'Магазин: ${business!['name']}',
      if (total != null) 'Сумма: ${formatTenge(total)}',
      if (address?['address']?.toString().trim().isNotEmpty ?? false)
        'Адрес: ${address!['address']}',
      if (paymentError != null && paymentError.isNotEmpty)
        'Ошибка оплаты: $paymentError',
    ].join('\n');
  }

  Future<void> _showOrderPicker() async {
    _messageFocus.unfocus();
    final order = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SupportOrderPicker(selectedOrder: _selectedOrder),
    );
    if (!mounted || order == null) return;
    setState(() {
      _selectedOrder = order;
      _contextError = null;
    });
  }

  FaqSection? get _faqSection => switch (widget.entryPoint) {
        'payment_failure' => FaqSection.payment,
        'order_detail' => FaqSection.orderProblems,
        _ => null,
      };

  void _openFaq() => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FaqPage(initialSection: _faqSection),
      ));

  @override
  Widget build(BuildContext context) {
    _measureComposerAfterLayout();
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppTopBar(
                    title: 'Поддержка',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _conversation()),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _composer(),
                      ),
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

  void _measureComposerAfterLayout() {
    if (_composerMeasureQueued) return;
    _composerMeasureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _composerMeasureQueued = false;
      if (!mounted) return;
      final height = _composerKey.currentContext?.size?.height;
      if (height != null && (height - _composerExtent).abs() > 0.5) {
        setState(() => _composerExtent = height);
      }
    });
  }

  Widget _conversation() {
    final rows = <Widget>[
      _faqCard(),
      const SizedBox(height: 32),
      _supportIdentity(),
      const SizedBox(height: 24),
      if (_selectedOrder != null ||
          widget.initialTopic != null ||
          widget.entryPoint == 'payment_failure') ...[
        _orderContext(),
        const SizedBox(height: 16),
      ],
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (_historyError != null) ...[
        _notice(
          key: const ValueKey('support-history-error'),
          text: _historyError!,
          action: _sessionFailed ? 'Подключиться заново' : 'Повторить загрузку',
          onRetry: _loading ? null : _tryConnect,
        ),
        const SizedBox(height: 16),
      ],
      if (!_loading && _historyError == null && _messages.isEmpty)
        _emptyConversation(),
    ];
    return CustomScrollView(
      key: const ValueKey('support-conversation'),
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          sliver: SliverList.list(children: rows),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, _composerExtent + 12),
          sliver: SliverList.builder(
            itemCount: _messages.length,
            itemBuilder: (context, index) => _messageBubble(
              _messages[index],
              separate: index > 0 &&
                  _messages[index - 1].isFromOperator !=
                      _messages[index].isFromOperator,
              tail: index == _messages.length - 1 ||
                  _messages[index + 1].isFromOperator !=
                      _messages[index].isFromOperator,
            ),
          ),
        ),
      ],
    );
  }

  Widget _faqCard() {
    final palette = context.palette;
    return Container(
      key: const ValueKey('support-faq-card'),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.20),
        borderRadius: AppRadii.lgAll,
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: palette.textPrimary.withValues(alpha: 0.18))
            : null,
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  offset: const Offset(0, 3),
                  blurRadius: 5,
                ),
              ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: palette.accentFaint,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.question_mark_rounded,
                color: palette.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Сначала можно проверить FAQ',
                    style: AppTypography.bodyBold.copyWith(
                      color: palette.textPrimary,
                    )),
                const SizedBox(height: 8),
                Text(
                  switch (widget.entryPoint) {
                    'payment_failure' =>
                      'Ответы по картам, списаниям и ошибкам оплаты.',
                    'order_detail' =>
                      'Ответы по задержкам, отменам и возвратам заказов.',
                    _ =>
                      'Там уже есть ответы по входу, оплате, доставке, бонусам и возвратам',
                  },
                  style: AppTypography.label.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                TextButton.icon(
                  onPressed: _openFaq,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Открыть FAQ'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    alignment: Alignment.centerLeft,
                    textStyle: AppTypography.body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _supportIdentity() {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: palette.accent.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.38,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: palette.accent.withValues(alpha: 0.50)),
          ),
          child: AppIcon(AppIcons.support, size: 30, color: palette.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_config?.name ?? 'Поддержка',
                  style:
                      AppTypography.title.copyWith(color: palette.textPrimary)),
              const SizedBox(height: 4),
              Text(_statusText,
                  style: AppTypography.bodySmall.copyWith(
                    color: palette.textSecondary,
                  )),
            ],
          ),
        ),
        IconButton(
          onPressed: _sending ? null : _showOrderPicker,
          tooltip: 'Выбрать заказ для обращения',
          icon: const Icon(Icons.attach_file_rounded, size: 22),
          color: palette.textSecondary,
        ),
      ],
    );
  }

  Widget _orderContext() {
    final palette = context.palette;
    final key = _orderKey(_selectedOrder);
    final sent = key != null && _sentOrderContextKeys.contains(key);
    final total = _selectedOrder == null
        ? null
        : order_ui.resolveOrderTotalAmount(_selectedOrder!);
    return Container(
      key: const ValueKey('support-order-context'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: palette.surface, borderRadius: AppRadii.lgAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_topic, style: AppTypography.bodyBold),
          if (key != null) ...[
            const SizedBox(height: 4),
            Text(
                'Заказ №$key${total == null ? '' : ' · ${formatTenge(total)}'}',
                style: AppTypography.bodySmall),
          ],
          if (key == _orderKey(widget.order) &&
              (widget.paymentError?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 4),
            Text(widget.paymentError!,
                style: AppTypography.bodySmall.copyWith(
                  color: palette.error,
                )),
          ],
          if (_contextError != null) ...[
            const SizedBox(height: 8),
            Text(_contextError!,
                style: AppTypography.bodySmall.copyWith(
                  color: palette.error,
                )),
          ],
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: _sending ? null : _showOrderPicker,
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: Text(key == null ? 'Выбрать заказ' : 'Сменить заказ'),
              ),
              if (key != null)
                TextButton.icon(
                  onPressed: sent || _loading || _sessionFailed || _sending
                      ? null
                      : () => _sendMessage(attachOrder: true),
                  icon: Icon(
                      sent ? Icons.check_rounded : Icons.attach_file_rounded,
                      size: 18),
                  label: Text(sent
                      ? 'Заказ прикреплён'
                      : _sendingContext
                          ? 'Прикрепляем…'
                          : _contextError == null
                              ? 'Прикрепить заказ'
                              : 'Повторить прикрепление'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyConversation() {
    final welcome = _config?.welcomeMessage?.trim();
    return Padding(
      key: const ValueKey('support-empty-conversation'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Начните обращение', style: AppTypography.title),
          const SizedBox(height: 8),
          Text(
            welcome != null && welcome.isNotEmpty
                ? welcome
                : 'Опишите ваш вопрос в сообщении. Ответ поддержки появится здесь.',
            style: AppTypography.body
                .copyWith(color: context.palette.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _notice(
      {Key? key,
      required String text,
      required String action,
      required VoidCallback? onRetry}) {
    final palette = context.palette;
    return Container(
      key: key,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: palette.error.withValues(alpha: 0.10),
        borderRadius: AppRadii.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text,
              style: AppTypography.bodySmall.copyWith(color: palette.error)),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(action),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(
    ChatMessage message, {
    required bool separate,
    required bool tail,
  }) {
    final palette = context.palette;
    final user = !message.isFromOperator;
    final color = user ? palette.accent : palette.surface;
    return Padding(
      padding: EdgeInsets.only(top: separate ? 24 : 0, bottom: tail ? 10 : 4),
      child: LayoutBuilder(builder: (context, constraints) {
        return Align(
          alignment: user ? Alignment.centerRight : Alignment.centerLeft,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (tail)
                Positioned(
                  bottom: -7,
                  left: user ? null : 0,
                  right: user ? 0 : null,
                  child: CustomPaint(
                    size: const Size(20, 12),
                    painter: _BubbleTail(color, user),
                  ),
                ),
              Container(
                key: message.id == null
                    ? null
                    : ValueKey('support-message-${message.id}'),
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppRadii.lgAll,
                ),
                child: Text(
                  message.content,
                  style: AppTypography.bodyLight.copyWith(
                    color: user ? palette.textOnAccent : palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _composer() {
    final palette = context.palette;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Padding(
      key: _composerKey,
      padding: EdgeInsets.fromLTRB(16, 12, 16, keyboardVisible ? 12 : 25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_sendError != null) ...[
            _notice(
              key: const ValueKey('support-send-error'),
              text: _sendError!,
              action: 'Повторить отправку',
              onRetry: _loading || _sending || _sessionFailed
                  ? null
                  : () => _sendMessage(),
            ),
            const SizedBox(height: 8),
          ],
          AppGlassPanel(
            key: const ValueKey('support-composer'),
            radius: AppRadii.pill,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('support-message-input'),
                    controller: _messageController,
                    focusNode: _messageFocus,
                    readOnly: _sending && !_sendingContext,
                    minLines: 1,
                    maxLines: MediaQuery.sizeOf(context).height -
                                MediaQuery.viewInsetsOf(context).bottom <
                            500
                        ? 2
                        : 4,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: AppTypography.titleRegular
                        .copyWith(color: palette.textPrimary),
                    onChanged: (_) => _measureComposerAfterLayout(),
                    decoration: InputDecoration(
                      hintText: 'Сообщение',
                      hintStyle:
                          AppTypography.base(size: 16, weight: 300).copyWith(
                        color: palette.textSecondary,
                      ),
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _messageController,
                  builder: (_, value, __) => IconButton.filled(
                    key: const ValueKey('support-send'),
                    onPressed: _loading ||
                            _sessionFailed ||
                            _sending ||
                            value.text.trim().isEmpty
                        ? null
                        : () => _sendMessage(),
                    tooltip: 'Отправить сообщение',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      maximumSize: const Size(44, 44),
                      backgroundColor: palette.accent,
                      foregroundColor: palette.textOnAccent,
                      disabledBackgroundColor: palette.accentSoft,
                      disabledForegroundColor: palette.textOnAccent,
                    ),
                    icon: _sending && !_sendingContext
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: palette.textOnAccent))
                        : const Icon(Icons.send_outlined, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _BubbleTail extends CustomPainter {
  const _BubbleTail(this.color, this.user);

  final Color color;
  final bool user;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (user) {
      path
        ..moveTo(0, 0)
        ..quadraticBezierTo(size.width * 0.55, size.height, size.width, size.height)
        ..quadraticBezierTo(size.width * 0.55, size.height * 0.4, size.width, 0);
    } else {
      path
        ..moveTo(0, 0)
        ..quadraticBezierTo(size.width * 0.45, size.height * 0.4, 0, size.height)
        ..quadraticBezierTo(size.width * 0.45, size.height, size.width, 0);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BubbleTail oldDelegate) =>
      color != oldDelegate.color || user != oldDelegate.user;
}
String? _orderKey(Map<String, dynamic>? order) {
  final key = (order?['order_id'] ?? order?['order_uuid'] ?? order?['id'])
      ?.toString()
      .trim();
  return key == null || key.isEmpty || key.toLowerCase() == 'null' ? null : key;
}


class _SupportOrderPicker extends StatefulWidget {
  const _SupportOrderPicker({this.selectedOrder});
  final Map<String, dynamic>? selectedOrder;

  @override
  State<_SupportOrderPicker> createState() => _SupportOrderPickerState();
}

class _SupportOrderPickerState extends State<_SupportOrderPicker> {
  bool _loading = true;
  bool _guest = false;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final token = await ApiService.getAuthToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _guest = true;
        _orders = [if (widget.selectedOrder != null) widget.selectedOrder!];
      });
      return;
    }
    final results = await Future.wait([
      ApiService.getMyActiveOrders(),
      ApiService.getMyOrdersHistory(page: 1, pageSize: 10),
    ]);
    if (!mounted) return;
    final seen = <String>{};
    final orders = <Map<String, dynamic>>[];
    void add(Map<String, dynamic> order) {
      final key = _orderKey(order);
      if (key != null && seen.add(key)) orders.add(order);
    }

    if (widget.selectedOrder != null) add(widget.selectedOrder!);
    for (final response in results) {
      for (final order in _extractOrders(response)) {
        add(order);
      }
    }
    setState(() {
      _orders = orders;
      _loading = false;
      if (results.any((result) => result == null)) {
        _error = 'Не удалось загрузить все заказы.';
      }
    });
  }

  List<Map<String, dynamic>> _extractOrders(Map<String, dynamic>? response) {
    final data = response?['data'];
    final dynamic list;
    if (data is List) {
      list = data;
    } else if (data is Map) {
      list = data['active_orders'] ??
          data['orders'] ??
          data['history_orders'] ??
          data['order_history'] ??
          data['completed_orders'];
    } else {
      return [];
    }
    return list is List
        ? list
            .map(order_ui.asOrderMap)
            .whereType<Map<String, dynamic>>()
            .toList()
        : [];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(children: [
                Expanded(
                    child: Text('Заказ для обращения',
                        style: AppTypography.title)),
                IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Закрыть',
                    icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (_loading)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator())),
                  if (_guest)
                    const Text(
                        'Войдите в аккаунт, чтобы выбрать заказ из истории.'),
                  if (_error != null) ...[
                    Text(_error!,
                        style:
                            AppTypography.body.copyWith(color: palette.error)),
                    TextButton.icon(
                        onPressed: _loading ? null : _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Повторить загрузку заказов')),
                  ],
                  if (!_loading && !_guest && _error == null && _orders.isEmpty)
                    const Text('Заказов пока нет'),
                  for (final order in _orders)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                          _orderKey(order) == _orderKey(widget.selectedOrder)
                              ? Icons.check_circle_outline_rounded
                              : Icons.receipt_long_rounded,
                          color: palette.accent),
                      title: Text('Заказ №${_orderKey(order)}'),
                      subtitle: Text([
                        order_ui
                            .asOrderMap(order['business'])?['name']
                            ?.toString(),
                        order_ui.resolveOrderStatusText(order),
                        if (order_ui.resolveOrderTotalAmount(order)
                            case final total?)
                          formatTenge(total),
                      ].whereType<String>().join(' · ')),
                      onTap: () => Navigator.of(context).pop(order),
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
