import 'dart:async';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/faq_page.dart';
import 'package:naliv_delivery/services/chat_api_service.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/order_ui_helpers.dart' as order_ui;
import 'package:naliv_delivery/utils/responsive.dart';

class HelpChatPage extends StatefulWidget {
  final Map<String, dynamic>? order;
  final String entryPoint;
  final String? initialTopic;
  final String? paymentError;

  const HelpChatPage({
    super.key,
    this.order,
    required this.entryPoint,
    this.initialTopic,
    this.paymentError,
  });

  @override
  State<HelpChatPage> createState() => _HelpChatPageState();
}

class _HelpChatPageState extends State<HelpChatPage> {
  final ChatApiService _chatService = ChatApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  final Set<String> _sentOrderContextKeys = <String>{};
  Map<String, dynamic>? _selectedOrder;
  List<Map<String, dynamic>> _selectableOrders = const [];
  bool _loading = true;
  bool _sending = false;
  bool _sendingOrderContext = false;
  bool _ordersLoading = false;
  bool _sessionFailed = false;
  String? _errorText;
  WidgetConfig? _config;
  StreamSubscription<ChatMessage>? _msgSub;
  StreamSubscription<ChatConnectionState>? _connSub;
  ChatConnectionState _connectionState = ChatConnectionState.disconnected;

  @override
  void initState() {
    super.initState();
    _selectedOrder = widget.order;
    _initChat();
    unawaited(_loadSelectableOrders());
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _connSub?.cancel();
    _chatService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    await _tryConnect();
  }

  Future<void> _tryConnect() async {
    setState(() {
      _loading = true;
      _sessionFailed = false;
      _errorText = null;
    });

    try {
      // Конфиг не обязателен — используем локальные фолбэки при ошибке
      final config = await _chatService.fetchConfig();
      await _chatService.init();

      final sessionOk = await _chatService.ensureSession();

      if (!mounted) return;

      if (!sessionOk) {
        setState(() {
          _loading = false;
          _sessionFailed = true;
          _config = config;
        });
        return;
      }

      // Передаём данные пользователя в профиль сессии
      unawaited(_syncUserProfile());

      // Подписываемся на входящие сообщения (polling + socket)
      _msgSub?.cancel();
      _connSub?.cancel();
      _msgSub = _chatService.messages.listen(
        _onMessageReceived,
        onError: _onStreamError,
      );
      _connSub = _chatService.connectionState.listen((state) {
        if (mounted) setState(() => _connectionState = state);
      });

      // Загружаем историю
      final historyResult = await _chatService.fetchHistory();

      if (!mounted) return;

      switch (historyResult) {
        case FetchSuccess(:final messages):
          _applyHistory(config, messages);
        case FetchSessionExpired():
          setState(() {
            _loading = false;
            _sessionFailed = true;
            _config = config;
            _errorText = 'Сессия истекла. Нажмите «Повторить».';
          });
        case FetchFailure(:final error):
          setState(() {
            _loading = false;
            _sessionFailed = true;
            _config = config;
            _errorText = error;
          });
      }

      _scrollDown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sessionFailed = true;
        _errorText = 'Не удалось подключиться к чату. Проверьте соединение.';
      });
    }
  }

  void _applyHistory(WidgetConfig? config, List<ChatMessage> messages) {
    setState(() {
      _config = config;
      _loading = false;
      _sessionFailed = false;
      _messages.clear();

      if (messages.isEmpty) {
        _messages.add(ChatMessage(
          content: config?.welcomeMessage ??
              'Здравствуйте! Опишите, что случилось, мы поможем.',
          isFromOperator: true,
        ));

        final orderId = _orderId;
        if (orderId != null) {
          _messages.add(ChatMessage(
            content: 'Вижу заказ #$orderId. Прикреплю его к обращению.',
            isFromOperator: true,
          ));
        }

        final paymentError = widget.paymentError;
        if (paymentError != null && paymentError.trim().isNotEmpty) {
          _messages.add(const ChatMessage(
            content: 'Проверим оплату и подскажем, что можно сделать дальше.',
            isFromOperator: true,
          ));
        }
      } else {
        _messages.addAll(messages);
        for (final message in messages) {
          final orderKey = _orderKeyFromContextMessage(message.content);
          if (orderKey != null) _sentOrderContextKeys.add(orderKey);
        }
      }
    });
    unawaited(_sendOrderContextIfNeeded());
    _scrollDown();
  }

  void _onMessageReceived(ChatMessage msg) {
    if (!mounted) return;
    setState(() {
      _mergeMessage(msg);
    });
    _scrollDown();
  }

  void _onStreamError(Object error) {
    if (error == 'SESSION_EXPIRED') {
      debugPrint('[ChatPage] Сессия истекла в polling, нужен перезапуск');
      if (mounted) {
        setState(() {
          _sessionFailed = true;
          _errorText = 'Сессия истекла. Нажмите «Повторить».';
        });
      }
    }
  }

  /// Отправляет имя, ID и телефон пользователя в профиль чат-сессии.
  Future<void> _syncUserProfile() async {
    try {
      final userInfo = await ApiService.getFullInfo();
      final userId = await ApiService.getCurrentUserExternalId();
      debugPrint(
          '[ChatPage] userId=$userId getFullInfo=${userInfo != null ? "ok" : "null"}');

      String? userName;
      String? phone;

      if (userInfo != null) {
        final user = userInfo['user'] as Map<String, dynamic>?;
        userName =
            (userInfo['name'] ?? user?['name'] ?? user?['login'])?.toString();
        phone = (userInfo['phone_number'] ??
                userInfo['phone'] ??
                user?['phone_number'] ??
                user?['phone'])
            ?.toString();
      }

      // Даже без авторизации пробуем взять phone из заказа
      phone ??= _selectedOrder?['phone_number']?.toString() ??
          _selectedOrder?['phone']?.toString();

      debugPrint(
          '[ChatPage] Профиль: name=$userName userId=$userId phone=$phone');

      if (userName == null && phone == null && userId == null) {
        debugPrint('[ChatPage] Нет данных для профиля, пропускаем');
        return;
      }

      final nameForProfile = [
        if (userName != null && userName.isNotEmpty) userName,
        if (userId != null && userId.isNotEmpty) 'id:$userId',
      ].join(' ');

      final ok = await _chatService.updateProfile(
        name: nameForProfile.isNotEmpty ? nameForProfile : null,
        phone: phone,
      );
      debugPrint('[ChatPage] updateProfile: ${ok ? "ok" : "fail"}');
    } catch (e) {
      debugPrint('[ChatPage] Ошибка _syncUserProfile: $e');
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String? get _orderId {
    final order = _selectedOrder;
    if (order == null) return null;
    final raw = order['order_id'] ?? order['order_uuid'] ?? order['id'];
    final value = raw?.toString();
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  String get _topic {
    final explicitTopic = widget.initialTopic;
    if (explicitTopic != null && explicitTopic.trim().isNotEmpty) {
      return explicitTopic;
    }
    switch (widget.entryPoint) {
      case 'payment_failure':
        return 'Ошибка оплаты';
      case 'order_detail':
        return 'Вопрос по заказу';
      default:
        return _config?.name ?? 'Поддержка';
    }
  }

  String get _subtitle {
    if (_sessionFailed) return 'Чат временно недоступен';
    final orderId = _orderId;
    if (orderId != null) return 'Чат по заказу #$orderId';
    if (_connectionState == ChatConnectionState.connected) {
      return 'Оператор на связи';
    }
    return 'Ожидание подключения...';
  }

  Future<void> _loadSelectableOrders() async {
    if (_ordersLoading) return;
    setState(() => _ordersLoading = true);

    try {
      final activeOrders = await ApiService.getMyActiveOrdersList();
      final recentOrders = await ApiService.getMyOrdersHistoryList(
        page: 1,
        pageSize: 10,
      );
      if (!mounted) return;

      final orders = <Map<String, dynamic>>[];
      final seen = <String>{};
      void addOrder(Map<String, dynamic>? order) {
        if (order == null) return;
        final key = _orderKey(order);
        if (key == null || !seen.add(key)) return;
        orders.add(order);
      }

      addOrder(_selectedOrder);
      for (final order in activeOrders) {
        addOrder(order);
      }
      for (final order in recentOrders) {
        addOrder(order);
      }

      setState(() {
        _selectableOrders = orders;
        _ordersLoading = false;
      });
    } catch (e) {
      debugPrint('[ChatPage] Ошибка загрузки заказов для поддержки: $e');
      if (mounted) setState(() => _ordersLoading = false);
    }
  }

  String? _orderKey(Map<String, dynamic>? order) {
    if (order == null) return null;
    final raw = order['order_id'] ?? order['order_uuid'] ?? order['id'];
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return null;
    }
    return value;
  }

  Future<void> _sendOrderContextIfNeeded() async {
    final order = _selectedOrder;
    final orderKey = _orderKey(order);
    if (order == null || orderKey == null || _sendingOrderContext) return;
    if (_sentOrderContextKeys.contains(orderKey)) return;
    if (!_chatService.hasSession || _sessionFailed) return;

    _sendingOrderContext = true;
    final content = _buildOrderContextMessage(order);
    final localMsg = ChatMessage.local(content);
    if (mounted) {
      setState(() {
        _sentOrderContextKeys.add(orderKey);
        _messages.add(localMsg);
      });
      _scrollDown();
    }

    final result = await _chatService.sendMessage(content);
    if (!mounted) return;

    setState(() {
      _sendingOrderContext = false;
      switch (result) {
        case SendSuccess(message: final serverMsg):
          _mergeMessage(serverMsg, fallbackLocalContent: content);
          _errorText = null;
        case SendSessionExpired():
          _sentOrderContextKeys.remove(orderKey);
          _sessionFailed = true;
          _errorText = 'Сессия истекла. Нажмите «Повторить».';
        case SendFailure():
          _sentOrderContextKeys.remove(orderKey);
          final idx = _messages.indexWhere(
            (m) => m.id == null && m.content == content,
          );
          if (idx != -1) _messages.removeAt(idx);
          _errorText = 'Не удалось прикрепить заказ к чату.';
      }
    });

    if (_orderId != orderKey) {
      unawaited(_sendOrderContextIfNeeded());
    }
  }

  String _buildOrderContextMessage(Map<String, dynamic> order) {
    final orderKey = _orderKey(order) ?? '-';
    final business = order_ui.asOrderMap(order['business']);
    final address = order_ui.asOrderMap(order['delivery_address']);
    final total = order_ui.resolveOrderTotalAmount(order);
    final paymentError = widget.entryPoint == 'payment_failure' &&
            orderKey == _orderKey(widget.order)
        ? widget.paymentError?.trim()
        : null;
    final lines = <String>[
      'Контекст обращения: заказ #$orderKey',
      'Источник: $_topic',
      'Статус: ${order_ui.resolveOrderStatusText(order)}',
      'Тип: ${order_ui.resolveDeliveryTypeText(order)}',
      if (business?['name']?.toString().trim().isNotEmpty ?? false)
        'Магазин: ${business!['name']}',
      if (total != null) 'Сумма: ${_formatMoney(total)}',
      if (address?['address']?.toString().trim().isNotEmpty ?? false)
        'Адрес: ${address!['address']}',
      if (paymentError != null && paymentError.isNotEmpty)
        'Ошибка оплаты: $paymentError',
    ];
    return lines.join('\n');
  }

  String? _orderKeyFromContextMessage(String content) {
    final match = RegExp(r'Контекст обращения: заказ #([^\s]+)')
        .firstMatch(content);
    return match?.group(1);
  }

  void _mergeMessage(ChatMessage message, {String? fallbackLocalContent}) {
    if (message.id != null) {
      final existingIndex = _messages.indexWhere((m) => m.id == message.id);
      if (existingIndex != -1) {
        _messages[existingIndex] = message;
        return;
      }
    }

    final localIndex = _messages.indexWhere((m) {
      if (m.id != null || m.isFromOperator != message.isFromOperator) {
        return false;
      }
      return m.content == message.content ||
          (fallbackLocalContent != null && m.content == fallbackLocalContent);
    });

    if (localIndex != -1) {
      _messages[localIndex] = message;
      return;
    }

    _messages.add(message);
  }

  Future<void> _showOrderPicker() async {
    if (_ordersLoading) return;
    if (_selectableOrders.isEmpty) {
      await _loadSelectableOrders();
      if (!mounted || _selectableOrders.isEmpty) return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.s)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.s, 14.s, 16.s, 18.s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Заказ для обращения',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textMute,
                    ),
                  ],
                ),
                SizedBox(height: 8.s),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _selectableOrders.length,
                    separatorBuilder: (_, __) => Divider(
                      color: Colors.white.withValues(alpha: 0.06),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final order = _selectableOrders[index];
                      return _orderPickerTile(order);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    final selectedKey = _orderKey(selected);
    if (selectedKey == null || selectedKey == _orderId) return;
    setState(() => _selectedOrder = selected);
    unawaited(_sendOrderContextIfNeeded());
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    // Оптимистично добавляем локальное сообщение
    final localMsg = ChatMessage.local(text);
    setState(() {
      _sending = true;
      _messages.add(localMsg);
      _messageController.clear();
    });
    _scrollDown();

    final result = await _chatService.sendMessage(text);

    if (!mounted) return;

    switch (result) {
      case SendSuccess(message: final serverMsg):
        setState(() {
          _sending = false;
          _errorText = null;
          _mergeMessage(serverMsg, fallbackLocalContent: text);
        });
      case SendSessionExpired():
        setState(() {
          _sending = false;
          _sessionFailed = true;
          _errorText = 'Сессия истекла. Нажмите «Повторить».';
        });
      case SendFailure(:final error):
        setState(() {
          _sending = false;
          _errorText = 'Сообщение не доставлено: $error';
        });
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _errorText = null);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        title: Row(
          children: [
            const Text('Поддержка',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            _connectionDot(),
          ],
        ),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: _loading ? _buildLoading() : _buildChat(),
          ),
        ],
      ),
    );
  }

  Widget _connectionDot() {
    final color = _connectionState == ChatConnectionState.connected
        ? const Color(0xFF4ADE80)
        : AppColors.textMute;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.orange),
    );
  }

  Widget _buildChat() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(14.s, 0, 14.s, 10.s),
          child: Column(
            children: [
              _contextHeader(),
              SizedBox(height: 10.s),
              FaqShortcutCard(
                title: 'Сначала можно проверить FAQ',
                subtitle: _faqSubtitle(),
                initialSection: _faqSectionForContext(),
                icon: Icons.help_center_rounded,
                actionLabel: 'Открыть ответы',
              ),
            ],
          ),
        ),
        if (_sessionFailed) _sessionErrorView(),
        if (_errorText != null && !_sessionFailed) _errorBanner(),
        if (!_sessionFailed)
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(14.s, 4.s, 14.s, 14.s),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _messageBubble(_messages[index]),
            ),
          ),
        _composer(),
      ],
    );
  }

  Widget _sessionErrorView() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24.s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 56.s, color: AppColors.textMute.withValues(alpha: 0.5)),
              SizedBox(height: 16.s),
              Text(
                _errorText ?? 'Чат временно недоступен',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMute,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8.s),
              Text(
                'Проверьте настройки подключения\nили попробуйте позже',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMute.withValues(alpha: 0.6),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 20.s),
              FilledButton.icon(
                onPressed: _tryConnect,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Повторить'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.s, 0, 14.s, 8.s),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 8.s),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10.s),
        ),
        child: Text(
          _errorText!,
          style: TextStyle(
            color: AppColors.red,
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _contextHeader() {
    final order = _selectedOrder;
    final orderId = _orderId;
    final business = order_ui.asOrderMap(order?['business']);
    final businessName = business?['name']?.toString().trim();
    final total = order == null ? null : order_ui.resolveOrderTotalAmount(order);
    final orderMeta = [
      if (businessName != null && businessName.isNotEmpty) businessName,
      if (order != null) order_ui.resolveOrderStatusText(order),
      if (total != null) _formatMoney(total),
    ].join(' • ');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.s),
      decoration: AppDecorations.card(radius: 16.s, color: AppColors.cardDark),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36.s,
                height: 36.s,
                decoration: AppDecorations.pill(
                    color: AppColors.orange.withValues(alpha: 0.16)),
                child: Icon(Icons.support_agent_rounded,
                    color: AppColors.orange, size: 20.s),
              ),
              SizedBox(width: 10.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _topic,
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 5.s),
                    Text(
                      _subtitle,
                      style: TextStyle(
                          color: AppColors.textMute,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700),
                    ),
                    if (orderMeta.isNotEmpty) ...[
                      SizedBox(height: 5.s),
                      Text(
                        orderMeta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMute.withValues(alpha: 0.78),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.s),
              TextButton.icon(
                onPressed: _ordersLoading ? null : _showOrderPicker,
                icon: Icon(
                  orderId == null
                      ? Icons.add_link_rounded
                      : Icons.swap_horiz_rounded,
                  size: 17.s,
                ),
                label: Text(orderId == null ? 'Выбрать' : 'Сменить'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.s, vertical: 6.s),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderPickerTile(Map<String, dynamic> order) {
    final orderId = _orderKey(order) ?? '-';
    final isSelected = orderId == _orderId;
    final business = order_ui.asOrderMap(order['business']);
    final businessName = business?['name']?.toString().trim();
    final total = order_ui.resolveOrderTotalAmount(order);
    final subtitle = [
      if (businessName != null && businessName.isNotEmpty) businessName,
      order_ui.resolveOrderStatusText(order),
      order_ui.resolveDeliveryTypeText(order),
    ].join(' • ');

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 2.s, vertical: 4.s),
      leading: Container(
        width: 36.s,
        height: 36.s,
        decoration: AppDecorations.pill(
          color: (isSelected ? AppColors.orange : AppColors.textMute)
              .withValues(alpha: isSelected ? 0.18 : 0.10),
        ),
        child: Icon(
          isSelected ? Icons.check_rounded : Icons.receipt_long_rounded,
          color: isSelected ? AppColors.orange : AppColors.textMute,
          size: 19.s,
        ),
      ),
      title: Text(
        'Заказ #$orderId',
        style: TextStyle(
          color: AppColors.text,
          fontSize: 14.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textMute,
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          height: 1.28,
        ),
      ),
      trailing: total == null
          ? null
          : Text(
              _formatMoney(total),
              style: TextStyle(
                color: AppColors.orange,
                fontSize: 13.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
      onTap: () => Navigator.of(context).pop(order),
    );
  }

  String _formatMoney(num value) {
    final isWhole = value == value.roundToDouble();
    final amount = isWhole ? value.toInt().toString() : value.toStringAsFixed(2);
    return '$amount ₸';
  }

  FaqSection? _faqSectionForContext() {
    switch (widget.entryPoint) {
      case 'payment_failure':
        return FaqSection.payment;
      case 'order_detail':
        return FaqSection.orderProblems;
      default:
        return null;
    }
  }

  String _faqSubtitle() {
    switch (widget.entryPoint) {
      case 'payment_failure':
        return 'В разделе оплаты собраны подсказки по удаленным счетам, картам и ошибкам при списании.';
      case 'order_detail':
        return 'В FAQ есть ответы по задержкам, отменам, возвратам и проблемам с доставленным заказом.';
      default:
        return 'Там уже есть ответы по входу, оплате, доставке, бонусам и возвратам.';
    }
  }

  Widget _messageBubble(ChatMessage message) {
    final isUser = !message.isFromOperator;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final background = isUser ? AppColors.orange : AppColors.card;
    final textColor = isUser ? Colors.black : AppColors.text;
    final radius = BorderRadius.only(
      topLeft: Radius.circular(16.s),
      topRight: Radius.circular(16.s),
      bottomLeft: Radius.circular(isUser ? 16.s : 4.s),
      bottomRight: Radius.circular(isUser ? 4.s : 16.s),
    );

    return Align(
      alignment: alignment,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: EdgeInsets.only(bottom: 9.s),
        padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 10.s),
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: Border.all(
              color: Colors.white.withValues(alpha: isUser ? 0 : 0.06)),
        ),
        child: Text(
          message.content,
          style: TextStyle(
              color: textColor,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              height: 1.32),
        ),
      ),
    );
  }

  Widget _composer() {
    final disabled = _sessionFailed;
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(14.s, 10.s, 14.s, 12.s),
        decoration: BoxDecoration(
          color: AppColors.bgDeep.withValues(alpha: 0.96),
          border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !disabled,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(
                    color: AppColors.text, fontWeight: FontWeight.w700),
                textInputAction: TextInputAction.send,
                onSubmitted: disabled ? null : (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: disabled ? 'Чат недоступен' : 'Сообщение...',
                  hintStyle: TextStyle(
                      color: disabled
                          ? AppColors.textMute.withValues(alpha: 0.4)
                          : AppColors.textMute.withValues(alpha: 0.85)),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14.s, vertical: 12.s),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20.s),
                    borderSide: BorderSide(
                        color: Colors.white
                            .withValues(alpha: disabled ? 0.03 : 0.06)),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20.s),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.03)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20.s),
                    borderSide:
                        const BorderSide(color: AppColors.orange, width: 1.2),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.s),
            _sending
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  )
                : IconButton.filled(
                    onPressed: disabled ? null : _sendMessage,
                    style: IconButton.styleFrom(
                      backgroundColor:
                          disabled ? AppColors.card : AppColors.orange,
                      foregroundColor:
                          disabled ? AppColors.textMute : Colors.black,
                    ),
                    icon: const Icon(Icons.send_rounded),
                  ),
          ],
        ),
      ),
    );
  }
}
