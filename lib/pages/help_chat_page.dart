import 'dart:async';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/services/chat_api_service.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/api.dart';
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
  bool _loading = true;
  bool _sending = false;
  bool _sessionFailed = false;
  String? _errorText;
  WidgetConfig? _config;
  StreamSubscription<ChatMessage>? _msgSub;
  StreamSubscription<ChatConnectionState>? _connSub;
  ChatConnectionState _connectionState = ChatConnectionState.disconnected;

  @override
  void initState() {
    super.initState();
    _initChat();
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

      if (messages.isEmpty) {
        _messages.add(ChatMessage(
          content: config?.welcomeMessage ??
              'Здравствуйте! Опишите, что случилось, мы поможем.',
          isFromOperator: true,
        ));

        final orderId = _orderId;
        if (orderId != null) {
          _messages.add(ChatMessage(
            content: 'Вижу заказ #$orderId. Уже прикрепили его к обращению.',
            isFromOperator: true,
          ));
        }

        final paymentError = widget.paymentError;
        if (paymentError != null && paymentError.trim().isNotEmpty) {
          _messages.add(ChatMessage(
            content: 'Не проходит оплата: $paymentError',
            isFromOperator: false,
          ));
          _messages.add(ChatMessage(
            content: 'Проверим оплату и подскажем, что можно сделать дальше.',
            isFromOperator: true,
          ));
        }
      } else {
        _messages.addAll(messages);
      }
    });
    _scrollDown();
  }

  void _onMessageReceived(ChatMessage msg) {
    if (!mounted) return;
    // Дедупликация по ID: polling/socket могут прислать уже известное сообщение
    if (msg.id != null && _messages.any((m) => m.id == msg.id)) return;
    setState(() => _messages.add(msg));
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
      phone ??= widget.order?['phone_number']?.toString() ??
          widget.order?['phone']?.toString();

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
    final order = widget.order;
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
    if (_connectionState == ChatConnectionState.connected)
      return 'Оператор на связи';
    return 'Ожидание подключения...';
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
          // Заменяем локальное сообщение серверным (поиск по отсутствию id)
          final idx = _messages.indexWhere(
            (m) => m.id == null && m.content == text,
          );
          if (idx != -1) {
            _messages[idx] = serverMsg;
          } else {
            _messages.add(serverMsg);
          }
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
          child: _contextHeader(),
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.s),
      decoration: AppDecorations.card(radius: 16.s, color: AppColors.cardDark),
      child: Row(
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
              ],
            ),
          ),
        ],
      ),
    );
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
