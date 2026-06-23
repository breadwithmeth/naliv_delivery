import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/pages/add_card_webview_page.dart';
import 'package:naliv_delivery/pages/help_chat_page.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/app_navigator.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:naliv_delivery/utils/responsive.dart';
import 'package:naliv_delivery/utils/web_window.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentMethodPage extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final double? displayAmount;

  const PaymentMethodPage(
      {super.key, required this.orderData, this.displayAmount});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage>
    with WidgetsBindingObserver {
  static const String _webAddCardWindowName = 'gradusy24_add_card';
  static const String _webKaspiPaymentWindowName = 'gradusy24_kaspi_payment';
  static const String _kaspiCompactAsset = 'assets/Compact.png';
  static const String _kaspiGoldTrailAsset = 'assets/Gold_trail.png';

  List<Map<String, dynamic>>? _cards;
  bool _isLoading = true;
  _PaymentMethodType? _selectedPaymentMethod;
  String? _selectedCardId;
  bool _awaitingCardAdd = false;
  bool _isPaying = false;
  bool _isPreparingAddCardLink = false;
  int _cardCountBeforeAdd = 0;
  String? _preparedAddCardLink;
  _CardFeedback? _cardFeedback;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCards();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingCardAdd) {
      // Вернулись из внешнего браузера — обновляем карты один раз
      _awaitingCardAdd = false;
      _loadCards(showRefreshFeedback: true, previousCount: _cardCountBeforeAdd);
    }
  }

  Future<void> _loadCards(
      {bool showRefreshFeedback = false, int? previousCount}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final cards = await ApiService.getUserCards(source: 'halyk');
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _isLoading = false;
        _syncSelectedPaymentMethod(_cards ?? const <Map<String, dynamic>>[]);
      });
      if (showRefreshFeedback) {
        final previous = previousCount ?? 0;
        final current = _cards?.length ?? 0;
        if (current > previous) {
          _setCardFeedback('Новая карта добавлена. Выберите её для оплаты.',
              _CardFeedbackTone.success);
        } else {
          _setCardFeedback(
            'Список карт обновлен. Если новая карта еще не появилась, завершите привязку в форме банка и обновите список еще раз.',
            _CardFeedbackTone.info,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      await _showNotice('Карты не загружены', 'Ошибка загрузки карт: $e');
    }
  }

  void _syncSelectedPaymentMethod(List<Map<String, dynamic>> cards) {
    final hasCards = cards.isNotEmpty;
    final hasSelectedCard = _selectedCardId != null &&
        cards.any((card) => _cardIdOf(card) == _selectedCardId);

    if (_selectedPaymentMethod == _PaymentMethodType.kaspi) {
      return;
    }

    if (_selectedPaymentMethod == _PaymentMethodType.card && hasSelectedCard) {
      return;
    }

    if (hasCards) {
      _selectedPaymentMethod = _PaymentMethodType.card;
      _selectedCardId = _cardIdOf(cards.first);
      return;
    }

    _selectedPaymentMethod = _PaymentMethodType.kaspi;
    _selectedCardId = null;
  }

  String? _cardIdOf(Map<String, dynamic> card) {
    final id = card['halyk_id'] ?? card['card_id'] ?? card['id'];
    final normalized = id?.toString().trim();
    if (normalized == null ||
        normalized.isEmpty ||
        normalized.toLowerCase() == 'null') {
      return null;
    }
    return normalized;
  }

  Future<void> _prepareAddCardLink() async {
    if (_isPreparingAddCardLink) return;

    if (!mounted) return;
    setState(() {
      _isPreparingAddCardLink = true;
    });

    final result = await ApiService.generateAddCardLinkResult();

    if (!mounted) return;
    setState(() {
      _isPreparingAddCardLink = false;
    });

    if (!result.success || result.link == null) {
      _setCardFeedback(result.message, _CardFeedbackTone.error);
      return;
    }

    final link = result.link!;
    final uri = Uri.tryParse(link);
    if (uri == null) {
      _setCardFeedback(
          'Получена некорректная ссылка для добавления карты. Попробуйте еще раз.',
          _CardFeedbackTone.error);
      return;
    }

    if (!mounted) return;
    setState(() {
      _preparedAddCardLink = uri.toString();
    });
    _setCardFeedback(
      'Ссылка получена. Нажмите «Привязать карту», чтобы открыть форму банка.',
      _CardFeedbackTone.success,
    );
  }

  Future<void> _openPreparedAddCardLink() async {
    final link = _preparedAddCardLink;
    if (link == null || link.isEmpty) {
      _setCardFeedback(
        'Сначала получите ссылку для привязки карты.',
        _CardFeedbackTone.info,
      );
      return;
    }

    final uri = Uri.tryParse(link);
    if (uri == null) {
      _setCardFeedback(
        'Ссылка для привязки карты устарела или некорректна. Получите новую ссылку.',
        _CardFeedbackTone.error,
      );
      if (!mounted) return;
      setState(() {
        _preparedAddCardLink = null;
      });
      return;
    }

    _cardCountBeforeAdd = _cards?.length ?? 0;

    final webWindowHandle = _reserveWebAddCardWindow();

    if (_supportsEmbeddedCardFlow) {
      if (!mounted) return;
      _setCardFeedback('Открываем защищенную форму банка для привязки карты.',
          _CardFeedbackTone.info);
      final shouldRefresh = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => AddCardWebViewPage(initialUrl: link),
        ),
      );
      if (!mounted) return;
      if (shouldRefresh == true) {
        await _loadCards(
            showRefreshFeedback: true, previousCount: _cardCountBeforeAdd);
      }
      return;
    }

    if (kIsWeb) {
      final opened = navigateReservedWebWindow(
        webWindowHandle,
        uri.toString(),
        windowName: _webAddCardWindowName,
      );
      if (opened) {
        _awaitingCardAdd = true;
        _setCardFeedback(
          'Открываем форму банка в новой вкладке. После завершения привязки вернитесь и обновите список карт.',
          _CardFeedbackTone.info,
        );
        return;
      }

      if (!mounted) return;
      _setCardFeedback('Не удалось открыть форму банка для привязки карты.',
          _CardFeedbackTone.error);
      return;
    }

    if (await canLaunchUrl(uri)) {
      _awaitingCardAdd = true;
      _setCardFeedback(
          'Открываем форму банка. После возвращения список карт обновится автоматически.',
          _CardFeedbackTone.info);
      final mode = defaultTargetPlatform == TargetPlatform.iOS
          ? LaunchMode.inAppWebView
          : LaunchMode.externalApplication;
      await launchUrl(uri, mode: mode);
      return;
    }

    if (!mounted) return;
    _setCardFeedback('Не удалось открыть форму банка для привязки карты.',
        _CardFeedbackTone.error);
  }

  Object? _reserveWebAddCardWindow() {
    if (!kIsWeb) return null;

    final windowHandle = reserveWebNamedWindow(_webAddCardWindowName);

    if (windowHandle == null && mounted) {
      _setCardFeedback(
        'Браузер заблокировал открытие вкладки для формы банка. Разрешите всплывающие окна и попробуйте снова.',
        _CardFeedbackTone.error,
      );
      return null;
    }

    return windowHandle;
  }

  bool get _supportsEmbeddedCardFlow {
    if (kIsWeb) return false;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  Future<void> _pay({_PaymentMethodType? paymentMethod}) async {
    if (_isPaying || _isLoading) return;
    final selectedMethod = paymentMethod ?? _selectedPaymentMethod;
    if (selectedMethod == null) {
      if (mounted) {
        await _showNotice(
            'Способ оплаты не выбран', 'Пожалуйста, выберите способ оплаты.');
      }
      return;
    }

    if (selectedMethod == _PaymentMethodType.card && _selectedCardId == null) {
      if (mounted) {
        await _showNotice(
            'Карта не выбрана', 'Пожалуйста, выберите карту для оплаты.');
      }
      return;
    }

    final orderId = _orderId();
    if (orderId == null) {
      if (mounted) {
        await _showNotice('Заказ не найден', 'ID заказа не найден.');
      }
      return;
    }

    Object? kaspiWindowHandle;
    if (selectedMethod == _PaymentMethodType.kaspi) {
      kaspiWindowHandle = _reserveWebKaspiPaymentWindow();
      if (kIsWeb && kaspiWindowHandle == null) {
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isPaying = true;
      });
    }

    var progressDialogShown = false;
    void closeProgressDialog() {
      if (!progressDialogShown || !mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      progressDialogShown = false;
    }

    if (mounted) {
      _showPaymentProgressDialog(selectedMethod);
      progressDialogShown = true;
    }

    var kaspiPaymentOpened = false;
    try {
      if (selectedMethod == _PaymentMethodType.card) {
        final result = await ApiService.payOrder(orderId, _selectedCardId!);

        closeProgressDialog();

        if (result['success'] == true) {
          final paymentData = ApiService.mapFromDynamic(result['data']);
          await _finishSuccessfulPayment(
            orderId,
            paymentData['payment_status']?.toString(),
          );
        } else if (mounted) {
          await _showPaymentFailureNotice(
              _paymentErrorMessage(result['error']));
        }

        return;
      }

      kaspiPaymentOpened = await _payWithKaspi(
        orderId,
        kaspiWindowHandle,
        closeProgressDialog,
      );
      closeProgressDialog();
    } catch (e) {
      closeProgressDialog();
      if (mounted) {
        await _showPaymentFailureNotice('Произошла ошибка: $e');
      }
    } finally {
      closeProgressDialog();
      if (mounted) {
        setState(() {
          _isPaying = false;
        });
      }
      if (selectedMethod == _PaymentMethodType.kaspi && !kaspiPaymentOpened) {
        closeReservedWebWindow(kaspiWindowHandle);
      }
    }
  }

  Future<bool> _payWithKaspi(
    String orderId,
    Object? webKaspiWindowHandle,
    VoidCallback closeProgressDialog,
  ) async {
    final result =
        await ApiService.createKaspiQrPayment(orderId, method: 'link');

    if (result['success'] != true) {
      if (mounted) {
        closeProgressDialog();
        await _showPaymentFailureNotice(_paymentErrorMessage(result['error']));
      }
      return false;
    }

    final paymentData = ApiService.mapFromDynamic(result['data']);
    final initialStatus = paymentData['payment_status']?.toString();
    if (_isKaspiStatusCompleted(paymentData)) {
      closeProgressDialog();
      await _finishSuccessfulPayment(orderId, initialStatus);
      return false;
    }

    final paymentLink = _nonEmptyString(paymentData['paymentLink']);
    if (paymentLink == null) {
      if (mounted) {
        closeProgressDialog();
        await _showPaymentFailureNotice(
            'Kaspi.kz не вернул ссылку для оплаты.');
      }
      return false;
    }

    final opened =
        await _openKaspiPaymentLink(paymentLink, webKaspiWindowHandle);
    if (!opened) {
      if (mounted) {
        closeProgressDialog();
        await _showPaymentFailureNotice(
            'Не удалось открыть ссылку оплаты Kaspi.kz.');
      }
      return false;
    }

    _setCardFeedback(
      'Ссылка Kaspi.kz открыта. Ожидаем подтверждение оплаты.',
      _CardFeedbackTone.info,
    );

    final statusResult = await _pollKaspiPaymentStatus(orderId, paymentData);
    if (!mounted) return true;

    if (statusResult == null || statusResult['success'] != true) {
      closeProgressDialog();
      await _showNotice(
        'Статус не получен',
        'Ссылка Kaspi.kz открыта, но статус оплаты пока не удалось проверить. Если вы оплатили заказ, он обновится после подтверждения.',
      );
      return true;
    }

    final statusData = ApiService.mapFromDynamic(statusResult['data']);
    final paymentStatus = statusData['payment_status']?.toString();

    if (_isKaspiStatusCompleted(statusData)) {
      closeProgressDialog();
      await _finishSuccessfulPayment(orderId, paymentStatus);
      return true;
    }

    if (_isKaspiStatusFailed(statusData)) {
      closeProgressDialog();
      await _showPaymentFailureNotice(
        statusResult['message']?.toString() ??
            'Оплата Kaspi.kz не была завершена.',
      );
      return true;
    }

    closeProgressDialog();
    await _showNotice(
      'Ожидаем оплату',
      'Ссылка Kaspi.kz открыта. Если вы уже оплатили заказ, статус обновится после подтверждения.',
    );
    return true;
  }

  Future<Map<String, dynamic>?> _pollKaspiPaymentStatus(
    String orderId,
    Map<String, dynamic> paymentData,
  ) async {
    final behaviorOptions =
        ApiService.mapFromDynamic(paymentData['behaviorOptions']);
    final intervalSeconds = _positiveInt(
      behaviorOptions['StatusPollingInterval'],
      fallback: 5,
    ).clamp(2, 30).toInt();
    final timeoutSeconds = _positiveInt(
      behaviorOptions['PaymentConfirmationTimeout'],
      fallback: 65,
    ).clamp(intervalSeconds, 180).toInt();
    final startedAt = DateTime.now();

    Map<String, dynamic>? latestResult;
    while (DateTime.now().difference(startedAt).inSeconds < timeoutSeconds) {
      await Future.delayed(Duration(seconds: intervalSeconds));
      if (!mounted) return latestResult;

      latestResult = await ApiService.getKaspiQrPaymentStatus(orderId);
      if (latestResult['success'] != true) {
        continue;
      }

      final statusData = ApiService.mapFromDynamic(latestResult['data']);
      if (_isKaspiStatusCompleted(statusData) ||
          _isKaspiStatusFailed(statusData)) {
        return latestResult;
      }
    }

    return latestResult;
  }

  Object? _reserveWebKaspiPaymentWindow() {
    if (!kIsWeb) return null;

    final windowHandle = reserveWebNamedWindow(_webKaspiPaymentWindowName);
    if (windowHandle == null && mounted) {
      _setCardFeedback(
        'Браузер заблокировал открытие вкладки Kaspi.kz. Разрешите всплывающие окна и попробуйте снова.',
        _CardFeedbackTone.error,
      );
      return null;
    }

    return windowHandle;
  }

  Future<bool> _openKaspiPaymentLink(
    String link,
    Object? webWindowHandle,
  ) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return false;

    if (kIsWeb) {
      return navigateReservedWebWindow(
        webWindowHandle,
        uri.toString(),
        windowName: _webKaspiPaymentWindowName,
      );
    }

    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    return false;
  }

  void _showPaymentProgressDialog(_PaymentMethodType paymentMethod) {
    final isKaspi = paymentMethod == _PaymentMethodType.kaspi;
    final title = isKaspi ? 'Kaspi.kz' : 'Оплата';
    final message =
        isKaspi ? 'Создаем ссылку и проверяем оплату...' : 'Проводим оплату...';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppDialogs.dialog(
        title: title,
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.orange)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finishSuccessfulPayment(
    String orderId,
    String? paymentStatus,
  ) async {
    if (!mounted) return;

    Provider.of<CartProvider>(context, listen: false).clearCart();
    await _showNotice(
      'Оплата прошла',
      'Заказ #$orderId успешно оплачен. Статус: ${paymentStatus ?? 'completed'}.',
    );
    if (mounted) {
      await AppNavigator.goToHomeTab(0);
    }
  }

  String? _orderId() {
    final raw = widget.orderData['order_id'] ??
        widget.orderData['order_uuid'] ??
        widget.orderData['id'];
    final normalized = raw?.toString().trim();
    if (normalized == null ||
        normalized.isEmpty ||
        normalized.toLowerCase() == 'null') {
      return null;
    }
    return normalized;
  }

  String _paymentErrorMessage(dynamic error) {
    if (error is Map) {
      return error['message']?.toString() ?? error.toString();
    }
    return error?.toString() ?? 'Ошибка оплаты';
  }

  String? _nonEmptyString(dynamic value) {
    final normalized = value?.toString().trim();
    if (normalized == null ||
        normalized.isEmpty ||
        normalized.toLowerCase() == 'null') {
      return null;
    }
    return normalized;
  }

  int _positiveInt(dynamic value, {required int fallback}) {
    if (value is num && value > 0) {
      return value.toInt();
    }

    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : fallback;
  }

  bool _isKaspiStatusCompleted(Map<String, dynamic> data) {
    const completedStatuses = <String>{
      'completed',
      'paid',
      'processed',
      'success',
      'succeeded',
    };
    return completedStatuses
            .contains(_normalizedStatus(data['payment_status'])) ||
        completedStatuses.contains(_normalizedStatus(data['kaspi_status']));
  }

  bool _isKaspiStatusFailed(Map<String, dynamic> data) {
    const failedStatuses = <String>{
      'failed',
      'rejected',
      'canceled',
      'cancelled',
      'expired',
      'error',
      'declined',
    };
    return failedStatuses.contains(_normalizedStatus(data['payment_status'])) ||
        failedStatuses.contains(_normalizedStatus(data['kaspi_status']));
  }

  String _normalizedStatus(dynamic value) {
    return value?.toString().trim().toLowerCase().replaceAll('-', '_') ?? '';
  }

  /// Получить сумму заказа из различных возможных полей
  String _getOrderAmount() {
    final orderData = widget.orderData;

    // Проверяем различные возможные поля для суммы
    final amount = orderData['payable_amount'] ??
        orderData['final_amount'] ??
        orderData['total_amount'] ??
        orderData['total_sum'] ??
        orderData['amount'] ??
        orderData['cost_summary']?['total_sum'] ??
        orderData['cost_summary']?['total'] ??
        orderData['data']?['total_sum'] ??
        orderData['data']?['total_amount'] ??
        orderData['data']?['amount'];

    if (amount != null) {
      return amount.toString();
    }

    if (widget.displayAmount != null) {
      return widget.displayAmount!.toStringAsFixed(0);
    }

    return 'Не указана';
  }

  Future<void> _showNotice(String title, String message) {
    return AppDialogs.showMessage(
      context,
      title: title,
      message: message,
    );
  }

  Future<void> _showPaymentFailureNotice(String message) {
    return AppDialogs.show<void>(
      context,
      title: 'Ошибка оплаты',
      content: Text('Ошибка оплаты: $message'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.textMute),
          child: const Text('Понятно'),
        ),
        TextButton.icon(
          onPressed: () {
            final navigator = Navigator.of(context);
            Navigator.of(context, rootNavigator: true).pop();
            navigator.push(
              MaterialPageRoute(
                builder: (_) => HelpChatPage(
                  order: widget.orderData,
                  entryPoint: 'payment_failure',
                  initialTopic: 'Ошибка оплаты',
                  paymentError: message,
                ),
              ),
            );
          },
          icon: const Icon(Icons.support_agent_rounded, size: 18),
          label: const Text('Написать в поддержку'),
          style: TextButton.styleFrom(foregroundColor: AppColors.orange),
        ),
      ],
    );
  }

  void _setCardFeedback(String message, _CardFeedbackTone tone) {
    if (!mounted) return;
    setState(() {
      _cardFeedback = _CardFeedback(message: message, tone: tone);
    });
  }

  @override
  Widget build(BuildContext context) {
    final amount = _getOrderAmount();

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Способ оплаты',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: _isLoading ? null : _loadCards,
          ),
        ],
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(14.s, 0, 14.s, 18.s),
              child: Column(
                children: [
                  _amountHeader(amount),
                  if (_cardFeedback != null) ...[
                    SizedBox(height: 12.s),
                    _cardFeedbackBanner(_cardFeedback!),
                  ],
                  SizedBox(height: 14.s),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.orange))
                        : _cardsSection(),
                  ),
                  if (_selectedPaymentMethod != null) ...[
                    SizedBox(height: 14.s),
                    _payButton(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountHeader(String amount) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.s),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12.s),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Сумма к оплате:',
              style: TextStyle(
                  color: AppColors.textMute,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 5.s),
          RichText(
            text: TextSpan(
              text: amount,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900),
              children: [
                TextSpan(
                    text: ' ₸',
                    style: TextStyle(
                        color: AppColors.orange,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardsSection() {
    if (_cards == null || _cards!.isEmpty) {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          _kaspiTile(),
          SizedBox(height: 10.s),
          _emptyCardsNotice(),
          SizedBox(height: 10.s),
          _addCardButton(),
        ],
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _kaspiTile();
        }
        if (index == _cards!.length + 1) {
          return _addCardButton();
        }
        final card = _cards![index - 1];
        return _cardTile(card);
      },
      separatorBuilder: (_, __) => SizedBox(height: 10.s),
      itemCount: _cards!.length + 2,
    );
  }

  Widget _kaspiTile() {
    final isSelected = _selectedPaymentMethod == _PaymentMethodType.kaspi;

    return Column(
      children: [
        SizedBox(height: 6.s),
        InkWell(
          onTap: () {
            setState(() {
              _selectedPaymentMethod = _PaymentMethodType.kaspi;
              _selectedCardId = null;
            });
          },
          borderRadius: BorderRadius.circular(12.s),
          child: _kaspiTileContent(
            isSelected: isSelected,
            isLoading: isSelected && _isPaying,
          ),
        ),
      ],
    );
  }

  Widget _kaspiTileContent({
    required bool isSelected,
    bool isLoading = false,
  }) {
    return Container(
      width: double.infinity,
      height: 60.s,
      padding: EdgeInsets.symmetric(horizontal: 15.s, vertical: 1.s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.s),
        border: Border.all(
          color: isSelected
              ? AppColors.orange.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.005),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.s),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      _kaspiCompactAsset,
                      height: 30.s,
                      fit: BoxFit.contain,
                      semanticLabel: 'Kaspi.kz',
                    ),
                  ),
                ),
                SizedBox(width: 10.s),
                Image.asset(
                  _kaspiGoldTrailAsset,
                  width: 60.s,
                  height: 54.s,
                  fit: BoxFit.contain,
                  semanticLabel: 'Kaspi Gold',
                ),
              ],
            ),
            if (isLoading)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.16),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCardsNotice() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.s),
      decoration: AppDecorations.card(
          radius: 12.s, color: AppColors.cardDark.withValues(alpha: 0.94)),
      child: Row(
        children: [
          Icon(Icons.credit_card_off_outlined,
              color: AppColors.textMute.withValues(alpha: 0.85), size: 22.s),
          SizedBox(width: 10.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Карт пока нет',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 3.s),
                Text('Можно оплатить через Kaspi.kz или привязать карту',
                    style: TextStyle(
                        color: AppColors.textMute,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardTile(Map<String, dynamic> card) {
    final id = _cardIdOf(card);
    final mask = card['card_mask']?.toString() ?? 'Неизвестная карта';
    final holder = card['payer_name']?.toString();
    final bool isSelected = _selectedPaymentMethod == _PaymentMethodType.card &&
        _selectedCardId == id;

    return InkWell(
      onTap: id == null
          ? null
          : () {
              setState(() {
                _selectedPaymentMethod = _PaymentMethodType.card;
                _selectedCardId = id;
              });
            },
      borderRadius: BorderRadius.circular(12.s),
      child: Container(
        padding: EdgeInsets.all(12.s),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.blue.withValues(alpha: 0.96)
              : AppColors.cardDark.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(12.s),
          border: Border.all(
              color: isSelected
                  ? AppColors.orange.withValues(alpha: 0.68)
                  : Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 10,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            _selectionIndicator(isSelected),
            SizedBox(width: 12.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mask,
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 3.s),
                  Text(
                      holder?.isNotEmpty == true ? holder! : 'Банковская карта',
                      style: TextStyle(
                          color: AppColors.textMute,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionIndicator(bool isSelected) {
    return Container(
      width: 24.s,
      height: 24.s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: isSelected
                ? AppColors.orange
                : Colors.white.withValues(alpha: 0.4),
            width: 2),
        color: isSelected ? AppColors.orange : Colors.transparent,
      ),
      child: isSelected
          ? Icon(Icons.check, size: 14.s, color: Colors.black)
          : null,
    );
  }

  Widget _addCardButton({bool expanded = true}) {
    final hasPreparedLink = _preparedAddCardLink != null;
    final bool isBusy = _isPreparingAddCardLink;
    final button = OutlinedButton.icon(
      icon: isBusy
          ? SizedBox(
              width: 16.s,
              height: 16.s,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
              ),
            )
          : Icon(
              hasPreparedLink ? Icons.link_outlined : Icons.add_card_outlined,
              color: AppColors.orange,
            ),
      label: Text(
        isBusy
            ? 'Получаем ссылку...'
            : (hasPreparedLink ? 'Привязать карту' : 'Добавить карту'),
        style: const TextStyle(
          color: AppColors.orange,
          fontWeight: FontWeight.w800,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.orange, width: 1.2),
        padding: EdgeInsets.symmetric(vertical: 12.s, horizontal: 12.s),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.s)),
        backgroundColor: Colors.white.withValues(alpha: 0.02),
      ),
      onPressed: isBusy
          ? null
          : (hasPreparedLink ? _openPreparedAddCardLink : _prepareAddCardLink),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  Widget _cardFeedbackBanner(_CardFeedback feedback) {
    final Color accent;
    final IconData icon;
    switch (feedback.tone) {
      case _CardFeedbackTone.success:
        accent = const Color(0xFF2A8C3E);
        icon = Icons.check_circle_rounded;
      case _CardFeedbackTone.error:
        accent = AppColors.red;
        icon = Icons.error_outline_rounded;
      case _CardFeedbackTone.info:
        accent = AppColors.orange;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.s),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12.s),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 18.s),
          SizedBox(width: 10.s),
          Expanded(
            child: Text(
              feedback.message,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _payButton() {
    final selectedMethod = _selectedPaymentMethod;
    final bool disabled = _isLoading ||
        _isPaying ||
        selectedMethod == null ||
        (selectedMethod == _PaymentMethodType.card && _selectedCardId == null);
    return GestureDetector(
      onTap: disabled ? null : _pay,
      child: Opacity(
        opacity: disabled ? 0.6 : 1,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 14.s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.s),
            gradient: const LinearGradient(
                colors: [Color(0xFF8B1F1E), AppColors.red]),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 12,
                  offset: const Offset(0, 7)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isPaying) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                ),
                SizedBox(width: 10.s),
              ] else
                Icon(Icons.lock_outline, color: Colors.white, size: 16.s),
              Text('Оплатить',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PaymentMethodType { card, kaspi }

enum _CardFeedbackTone { success, error, info }

class _CardFeedback {
  final String message;
  final _CardFeedbackTone tone;

  const _CardFeedback({required this.message, required this.tone});
}
