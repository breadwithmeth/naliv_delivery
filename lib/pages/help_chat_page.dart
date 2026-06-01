import 'package:flutter/material.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final List<_ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messages = _initialMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<_ChatMessage> _initialMessages() {
    final messages = <_ChatMessage>[
      const _ChatMessage(
        text: 'Здравствуйте! Опишите, что случилось, мы поможем.',
        isUser: false,
      ),
    ];

    final orderId = _orderId;
    if (orderId != null) {
      messages.add(_ChatMessage(
        text: 'Вижу заказ #$orderId. Уже прикрепили его к обращению.',
        isUser: false,
      ));
    }

    final paymentError = widget.paymentError;
    if (paymentError != null && paymentError.trim().isNotEmpty) {
      messages.add(_ChatMessage(
        text: 'Не проходит оплата: $paymentError',
        isUser: true,
      ));
      messages.add(const _ChatMessage(
        text: 'Проверим оплату и подскажем, что можно сделать дальше.',
        isUser: false,
      ));
    }

    return messages;
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
        return 'Поддержка';
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _messages.add(const _ChatMessage(
        text: 'Спасибо, сообщение добавлено в демо-чат. Скоро подключим настоящую поддержку.',
        isUser: false,
      ));
      _messageController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
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
        title: const Text('Поддержка', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(14.s, 0, 14.s, 10.s),
                  child: _contextHeader(),
                ),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _contextHeader() {
    final orderId = _orderId;

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
            decoration: AppDecorations.pill(color: AppColors.orange.withValues(alpha: 0.16)),
            child: Icon(Icons.support_agent_rounded, color: AppColors.orange, size: 20.s),
          ),
          SizedBox(width: 10.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _topic,
                  style: TextStyle(color: AppColors.text, fontSize: 15.sp, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 5.s),
                Text(
                  orderId == null ? 'Демо-чат без подключения к оператору' : 'Демо-чат по заказу #$orderId',
                  style: TextStyle(color: AppColors.textMute, fontSize: 12.sp, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(_ChatMessage message) {
    final alignment = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final background = message.isUser ? AppColors.orange : AppColors.card;
    final textColor = message.isUser ? Colors.black : AppColors.text;
    final radius = BorderRadius.only(
      topLeft: Radius.circular(16.s),
      topRight: Radius.circular(16.s),
      bottomLeft: Radius.circular(message.isUser ? 16.s : 4.s),
      bottomRight: Radius.circular(message.isUser ? 4.s : 16.s),
    );

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: EdgeInsets.only(bottom: 9.s),
        padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 10.s),
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: Border.all(color: Colors.white.withValues(alpha: message.isUser ? 0 : 0.06)),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: textColor, fontSize: 13.sp, fontWeight: FontWeight.w700, height: 1.32),
        ),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(14.s, 10.s, 14.s, 12.s),
        decoration: BoxDecoration(
          color: AppColors.bgDeep.withValues(alpha: 0.96),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Сообщение...',
                  hintStyle: TextStyle(color: AppColors.textMute.withValues(alpha: 0.85)),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 12.s),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20.s),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20.s),
                    borderSide: const BorderSide(color: AppColors.orange, width: 1.2),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.s),
            IconButton.filled(
              onPressed: _sendMessage,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}
