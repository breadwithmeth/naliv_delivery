import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/design/typography.dart';
import 'package:naliv_delivery/features/checkout/ui/payment_success_page.dart';
import 'package:naliv_delivery/features/orders/ui/orders_page.dart';
import 'package:naliv_delivery/pages/help_chat_page.dart';
import 'package:naliv_delivery/ui/app_states.dart';
import 'package:naliv_delivery/ui/app_top_bar.dart';
import 'package:naliv_delivery/ui/surfaces.dart';
import 'package:naliv_delivery/ui/kaspi_payment.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/order_payment_guard.dart';
import 'package:naliv_delivery/utils/web_window.dart';
import 'package:url_launcher/url_launcher.dart';

import 'card_flow.dart';
import 'card_widgets.dart';

class PaymentMethodPage extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final double? displayAmount;
  final Future<bool> Function(Uri)? openCardForm;
  final Future<void> Function(String orderId)? onPaymentCompleted;

  const PaymentMethodPage({
    super.key,
    required this.orderData,
    this.displayAmount,
    this.openCardForm,
    this.onPaymentCompleted,
  });

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage>
    with WidgetsBindingObserver {
  static const String _webKaspiPaymentWindowName = 'gradusy24_kaspi_payment';

  late final CardFlow _flow;
  _PaymentMethodType? _selectedPaymentMethod;
  String? _selectedCardId;
  bool _isPaying = false;
  OrderPaymentState _paymentState = OrderPaymentState.storageUnavailable;
  bool _readingPaymentGuard = true;
  bool get _paymentUnconfirmed =>
      _paymentState == OrderPaymentState.unconfirmed;
  _CardFeedback? _cardFeedback;

  @override
  void initState() {
    super.initState();
    _flow = CardFlow(
      readCards: () => ApiService.getUserCards(source: 'halyk'),
      openForm: (uri, window) => openHostedCardForm(context, uri, window,
          openCardForm: widget.openCardForm),
      requiresWindow: kIsWeb && widget.openCardForm == null,
      reserveWindow: kIsWeb && widget.openCardForm == null
          ? () => reserveWebNamedWindow(cardFormWindowName)
          : null,
      closeWindow: closeReservedWebWindow,
    )..addListener(_cardsChanged);
    WidgetsBinding.instance.addObserver(this);
    _flow.refresh();
    _readPaymentGuard(initial: true);
  }

  void _cardsChanged() {
    if (!mounted) return;
    setState(() {
      if (!_flow.loading && _flow.error == null) _syncSelectedPaymentMethod();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flow.removeListener(_cardsChanged);
    _flow.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _readPaymentGuard();
      if (_flow.awaiting) _flow.refresh();
    }
  }

  Future<void> _readPaymentGuard({bool initial = false}) async {
    if (!mounted || _isPaying) return;
    setState(() => _readingPaymentGuard = true);
    final id = _orderId();
    var state = id == null
        ? OrderPaymentState.storageUnavailable
        : await OrderPaymentGuard.read(id);
    if (initial && id != null) {
      final knownOutcome = orderPaymentOutcome(widget.orderData);
      if (knownOutcome == OrderPaymentOutcome.completed ||
          knownOutcome == OrderPaymentOutcome.pending) {
        final knownOrder = Map<String, dynamic>.from(widget.orderData);
        await OrderPaymentGuard.reconcileOrder(knownOrder,
            readRevision: OrderPaymentGuard.beginOrderRead());
        state = OrderPaymentState.values.firstWhere(
          (value) => value.name == knownOrder[OrderPaymentGuard.localStateKey],
          orElse: () => OrderPaymentState.storageUnavailable,
        );
      }
    }
    if (!mounted) return;
    _applyPaymentState(state);
    setState(() => _readingPaymentGuard = false);
  }

  void _applyPaymentState(OrderPaymentState state) {
    if (!mounted) return;
    setState(() {
      final wasLocked = _paymentState != OrderPaymentState.ready;
      _paymentState = state;
      if (state == OrderPaymentState.unconfirmed) {
        _cardFeedback = const _CardFeedback(
          message:
              'Оплата ещё не подтверждена. Проверьте заказ перед повторной оплатой.',
          tone: _CardFeedbackTone.info,
        );
      } else if (state == OrderPaymentState.completed) {
        _cardFeedback = const _CardFeedback(
          message: 'Заказ уже оплачен. Повторная оплата недоступна.',
          tone: _CardFeedbackTone.info,
        );
      } else if (state == OrderPaymentState.storageUnavailable) {
        _cardFeedback = const _CardFeedback(
          message:
              'Не удалось прочитать или сохранить состояние оплаты. Новый запрос оплаты не отправлен.',
          tone: _CardFeedbackTone.error,
        );
      } else if (wasLocked) {
        _cardFeedback = null;
      }
    });
  }

  Future<void> _openOrders() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const OrdersPage(),
    ));
    if (mounted) await _readPaymentGuard();
  }

  void _syncSelectedPaymentMethod() {
    if (_selectedPaymentMethod == _PaymentMethodType.kaspi) return;
    if (_selectedPaymentMethod == _PaymentMethodType.card &&
        _flow.cards.any((card) => card.id == _selectedCardId)) {
      return;
    }
    if (_flow.cards.isNotEmpty) {
      _selectedPaymentMethod = _PaymentMethodType.card;
      _selectedCardId = _flow.cards.first.id;
    } else {
      _selectedPaymentMethod = _PaymentMethodType.kaspi;
      _selectedCardId = null;
    }
  }

  Future<void> _pay({_PaymentMethodType? paymentMethod}) async {
    if (_isPaying ||
        _readingPaymentGuard ||
        _paymentState != OrderPaymentState.ready ||
        _flow.loading ||
        _flow.preparing ||
        _flow.awaiting) {
      return;
    }
    final selectedMethod = paymentMethod ?? _selectedPaymentMethod;
    if (selectedMethod == null) {
      if (mounted) {
        await _showNotice(
            'Способ оплаты не выбран', 'Пожалуйста, выберите способ оплаты.');
      }
      return;
    }

    if (selectedMethod == _PaymentMethodType.card &&
        (_flow.error != null ||
            !_flow.cards.any((card) => card.id == _selectedCardId))) {
      await _showNotice(
          'Карты не загружены', 'Обновите список карт перед оплатой.');
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
        await _showNotice('Заказ не найден', 'ID заказа не найден.',
            kaspi: selectedMethod == _PaymentMethodType.kaspi);
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

        final paymentData = ApiService.mapFromDynamic(result['data']);
        final stateName = result['paymentGuardState'];
        final state = OrderPaymentState.values.firstWhere(
          (state) => state.name == stateName,
          orElse: () => OrderPaymentState.ready,
        );
        _applyPaymentState(state);
        if (result['localFailure'] == true) {
          _setCardFeedback(
              _paymentErrorMessage(result['error']), _CardFeedbackTone.error);
        } else if (orderPaymentResultOutcome(result) ==
            OrderPaymentOutcome.completed) {
          await _finishSuccessfulPayment(orderId);
        } else if (result['guardPersistenceFailed'] == true) {
          _setCardFeedback(
            'Оплата отклонена, но не удалось сохранить этот результат. Повторная оплата пока заблокирована; проверьте заказ.',
            _CardFeedbackTone.error,
          );
        } else if (state == OrderPaymentState.ready && mounted) {
          await _showPaymentFailureNotice(
              _paymentErrorMessage(result['error'] ?? paymentData['error']));
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
        await _showPaymentFailureNotice('Произошла ошибка: $e',
            kaspi: selectedMethod == _PaymentMethodType.kaspi);
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
    final reservation = await OrderPaymentGuard.reserve(orderId);
    if (reservation != OrderPaymentState.ready) {
      _applyPaymentState(reservation);
      return false;
    }
    _applyPaymentState(OrderPaymentState.unconfirmed);
    try {
      final result =
          await ApiService.createKaspiQrPayment(orderId, method: 'link');
      final paymentData = ApiService.mapFromDynamic(result['data']);

      if (result['success'] != true) {
        if (orderPaymentOutcome(paymentData) == OrderPaymentOutcome.refused) {
          await _settleKaspiPayment(orderId, OrderPaymentOutcome.refused);
        }
        if (mounted) {
          closeProgressDialog();
          await _showPaymentFailureNotice(_paymentErrorMessage(result['error']),
              kaspi: true);
        }
        return false;
      }

      if (orderPaymentOutcome(paymentData) == OrderPaymentOutcome.completed) {
        await _settleKaspiPayment(orderId, OrderPaymentOutcome.completed);
        closeProgressDialog();
        await _finishSuccessfulPayment(orderId);
        return false;
      }

      final paymentLink = _nonEmptyString(paymentData['paymentLink']);
      if (paymentLink == null) {
        if (mounted) {
          closeProgressDialog();
          await _showPaymentFailureNotice(
              'Kaspi.kz не вернул ссылку для оплаты.',
              kaspi: true);
        }
        return false;
      }

      final opened =
          await _openKaspiPaymentLink(paymentLink, webKaspiWindowHandle);
      if (!opened) {
        if (mounted) {
          closeProgressDialog();
          await _showPaymentFailureNotice(
              'Не удалось открыть ссылку оплаты Kaspi.kz.',
              kaspi: true);
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
          kaspi: true,
        );
        return true;
      }

      final statusData = ApiService.mapFromDynamic(statusResult['data']);
      final outcome = orderPaymentOutcome(statusData);
      if (outcome == OrderPaymentOutcome.completed) {
        await _settleKaspiPayment(orderId, outcome);
        closeProgressDialog();
        await _finishSuccessfulPayment(orderId);
        return true;
      }

      if (outcome == OrderPaymentOutcome.refused) {
        await _settleKaspiPayment(orderId, outcome);
        closeProgressDialog();
        await _showPaymentFailureNotice(
          statusResult['message']?.toString() ??
              'Оплата Kaspi.kz не была завершена.',
          kaspi: true,
        );
        return true;
      }

      closeProgressDialog();
      await _showNotice(
        'Ожидаем оплату',
        'Ссылка Kaspi.kz открыта. Если вы уже оплатили заказ, статус обновится после подтверждения.',
        kaspi: true,
      );
      return true;
    } finally {
      OrderPaymentGuard.release(orderId);
    }
  }

  Future<void> _settleKaspiPayment(
      String orderId, OrderPaymentOutcome outcome) async {
    _applyPaymentState(await OrderPaymentGuard.settle(orderId, outcome));
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
      final outcome = orderPaymentOutcome(statusData);
      if (outcome == OrderPaymentOutcome.completed ||
          outcome == OrderPaymentOutcome.refused) {
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

  Widget _paymentNoticeTitle(String title, {required bool kaspi}) {
    if (!kaspi) return Text(title);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KaspiLogo(),
        const SizedBox(height: 8),
        Text(title),
      ],
    );
  }

  void _showPaymentProgressDialog(_PaymentMethodType paymentMethod) {
    final isKaspi = paymentMethod == _PaymentMethodType.kaspi;
    final title = isKaspi ? 'Оплата с Kaspi.kz' : 'Оплата';
    final message =
        isKaspi ? 'Создаем ссылку и проверяем оплату...' : 'Проводим оплату...';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        scrollable: isKaspi,
        insetPadding: isKaspi
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
            : null,
        title: _paymentNoticeTitle(title, kaspi: isKaspi),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finishSuccessfulPayment(String orderId) async {
    if (!mounted) return;

    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => PaymentSuccessPage(
        orderId: orderId,
        businessId:
            int.tryParse(widget.orderData['business_id']?.toString() ?? ''),
        onOrders: widget.onPaymentCompleted == null
            ? null
            : () => widget.onPaymentCompleted!(orderId),
      ),
    ));
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

  Future<void> _showNotice(String title, String message,
      {bool kaspi = false}) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: kaspi,
        insetPadding: kaspi
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
            : null,
        title: _paymentNoticeTitle(title, kaspi: kaspi),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentFailureNotice(String message,
      {bool kaspi = false}) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: kaspi,
        insetPadding: kaspi
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
            : null,
        title: _paymentNoticeTitle('Ошибка оплаты', kaspi: kaspi),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Понятно'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => HelpChatPage(
                  order: widget.orderData,
                  entryPoint: 'payment_failure',
                  initialTopic: 'Ошибка оплаты',
                  paymentError: message,
                ),
              ));
            },
            icon: kaspi
                ? null
                : const Icon(Icons.support_agent_rounded, size: 18),
            label: const Text('Написать в поддержку'),
          ),
        ],
      ),
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
    final palette = context.palette;
    final selectionBusy = _isPaying ||
        _readingPaymentGuard ||
        _paymentState != OrderPaymentState.ready ||
        _flow.preparing ||
        _flow.awaiting;
    final cannotPay = selectionBusy ||
        _flow.loading ||
        _selectedPaymentMethod == null ||
        (_selectedPaymentMethod == _PaymentMethodType.card &&
            (_selectedCardId == null || _flow.error != null));
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppTopBar(
                      title: 'Способ оплаты',
                      onBack: () => Navigator.of(context).maybePop()),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _flow.refresh,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Сумма к оплате',
                                    style: AppTypography.body.copyWith(
                                        color: palette.textSecondary)),
                                const SizedBox(height: 8),
                                Text('${_getOrderAmount()} ₸',
                                    style: AppTypography.displayBold),
                                const SizedBox(height: 24),
                                if (_cardFeedback != null) ...[
                                  AppSurface(
                                    padding: const EdgeInsets.all(12),
                                    fill: (_cardFeedback!.tone ==
                                                _CardFeedbackTone.error
                                            ? palette.error
                                            : palette.accent)
                                        .withValues(alpha: .12),
                                    child: _selectedPaymentMethod ==
                                            _PaymentMethodType.kaspi
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const KaspiLogo(),
                                              const SizedBox(height: 8),
                                              Text(_cardFeedback!.message,
                                                  style: AppTypography.body),
                                            ],
                                          )
                                        : Text(_cardFeedback!.message,
                                            style: AppTypography.body),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (_paymentState != OrderPaymentState.ready &&
                                    _paymentState !=
                                        OrderPaymentState
                                            .storageUnavailable) ...[
                                  OutlinedButton(
                                    key: const ValueKey(
                                        'payment-pending-orders'),
                                    onPressed: _readingPaymentGuard || _isPaying
                                        ? null
                                        : _openOrders,
                                    child: const Text('Проверить мои заказы'),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (_paymentState !=
                                    OrderPaymentState.ready) ...[
                                  OutlinedButton(
                                    key:
                                        const ValueKey('payment-state-refresh'),
                                    onPressed: _readingPaymentGuard || _isPaying
                                        ? null
                                        : _readPaymentGuard,
                                    child: Text(_readingPaymentGuard
                                        ? 'Проверяем состояние…'
                                        : 'Проверить состояние оплаты'),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (_flow.message != null) ...[
                                  CardFlowFeedback(flow: _flow),
                                  const SizedBox(height: 12),
                                ],
                                _kaspiRow(selectionBusy),
                                const SizedBox(height: 24),
                                Text('Сохранённые карты',
                                    style: AppTypography.title),
                                const SizedBox(height: 12),
                                if (_flow.loading)
                                  const SizedBox(
                                      height: 120, child: AppLoading())
                                else if (_flow.error != null ||
                                    _flow.partialWarning != null)
                                  CardReadFeedback(
                                    flow: _flow,
                                    allowSignIn:
                                        !_isPaying && !_paymentUnconfirmed,
                                  )
                                else if (_flow.cards.isEmpty)
                                  const AppEmptyState(
                                    title: 'Добавленных карт нет',
                                    subtitle:
                                        'Можно оплатить через Kaspi.kz или добавить карту в форме банка',
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (!_flow.loading && _flow.error == null)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList.builder(
                              itemCount: _flow.cards.length,
                              itemBuilder: (_, index) {
                                final card = _flow.cards[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: SavedCardRow(
                                    key: ValueKey('payment-card-${card.id}'),
                                    card: card,
                                    selected: _selectedPaymentMethod ==
                                            _PaymentMethodType.card &&
                                        _selectedCardId == card.id,
                                    onSelected: selectionBusy
                                        ? null
                                        : () => setState(() {
                                              _selectedPaymentMethod =
                                                  _PaymentMethodType.card;
                                              _selectedCardId = card.id;
                                            }),
                                  ),
                                );
                              },
                            ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                OutlinedButton.icon(
                                  key: const ValueKey('add-card-button'),
                                  onPressed: !_isPaying && _flow.canAdd
                                      ? _flow.addCard
                                      : null,
                                  icon: const Icon(Icons.add),
                                  label: Text(_flow.preparing
                                      ? 'Открываем банк…'
                                      : _flow.addState ==
                                              CardAddState.launchFailed
                                          ? 'Открыть форму снова'
                                          : 'Добавить новую карту'),
                                ),
                                if (!_flow.awaiting)
                                  TextButton(
                                    key: const ValueKey('refresh-card-list'),
                                    onPressed: _flow.loading || selectionBusy
                                        ? null
                                        : _flow.refresh,
                                    child: const Text('Обновить список'),
                                  ),
                                const SizedBox(height: 24),
                                const CardFaqPanel(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: _selectedPaymentMethod == _PaymentMethodType.kaspi
                        ? _paymentState != OrderPaymentState.ready ||
                                _readingPaymentGuard
                            ? Text(
                                _paymentState == OrderPaymentState.completed
                                    ? 'Заказ уже оплачен'
                                    : _paymentState ==
                                            OrderPaymentState.storageUnavailable
                                        ? 'Проверьте состояние оплаты'
                                        : 'Ожидаем подтверждение оплаты',
                                key: const ValueKey('kaspi-payment-state'),
                                textAlign: TextAlign.center,
                                style: AppTypography.body,
                              )
                            : KaspiPayButton(
                                buttonKey: const ValueKey('pay-order-button'),
                                onPressed: cannotPay ? null : _pay,
                              )
                        : FilledButton(
                            key: const ValueKey('pay-order-button'),
                            onPressed: cannotPay ? null : _pay,
                            child: Text(
                                _isPaying ? 'Проводим оплату…' : 'Оплатить'),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kaspiRow(bool busy) {
    final palette = context.palette;
    final selected = _selectedPaymentMethod == _PaymentMethodType.kaspi;
    return Semantics(
      button: true,
      selected: selected,
      enabled: !busy,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: const ValueKey('payment-kaspi'),
          borderRadius: BorderRadius.circular(12),
          onTap: busy
              ? null
              : () => setState(() {
                    _selectedPaymentMethod = _PaymentMethodType.kaspi;
                    _selectedCardId = null;
                  }),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: selected ? Border.all(color: palette.accent) : null,
            ),
            child: Row(
              children: [
                const KaspiLogo(compact: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Kaspi.kz', style: AppTypography.title),
                          const KaspiGoldBadge(),
                        ],
                      ),
                      Text('Оплата по ссылке в приложении банка',
                          style: AppTypography.body
                              .copyWith(color: palette.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? palette.accent : palette.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _PaymentMethodType { card, kaspi }

enum _CardFeedbackTone { error, info }

class _CardFeedback {
  final String message;
  final _CardFeedbackTone tone;

  const _CardFeedback({required this.message, required this.tone});
}
