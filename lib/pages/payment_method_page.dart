import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/core/money.dart';
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
import 'package:naliv_delivery/utils/order_ui_helpers.dart';
import 'package:naliv_delivery/utils/web_window.dart';
import 'package:url_launcher/url_launcher.dart';

import 'card_flow.dart';
import 'card_widgets.dart';

class PaymentMethodPage extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final double? displayAmount;

  /// Set when the server charged a different total than the cart calculated.
  final String? amountNotice;
  final Future<bool> Function(Uri)? openCardForm;
  final Future<void> Function(String orderId)? onPaymentCompleted;

  const PaymentMethodPage({
    super.key,
    required this.orderData,
    this.displayAmount,
    this.amountNotice,
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
  String? _kaspiPaymentLink;
  Map<String, dynamic>? _refreshedOrder;
  bool _completionPresented = false;
  bool get _orderClosed =>
      isOrderClosed(_refreshedOrder ?? widget.orderData);

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
      _flow.refresh();
    }
  }

  Future<void> _readPaymentGuard({bool initial = false}) async {
    if (!mounted || _isPaying || (_readingPaymentGuard && !initial)) return;
    setState(() => _readingPaymentGuard = true);
    final id = _orderId();
    var state = id == null
        ? OrderPaymentState.storageUnavailable
        : await OrderPaymentGuard.read(id);
    var serverCompleted = false;
    var statusUnavailable = false;
    try {
      if (initial && id != null) {
        final knownOutcome = orderPaymentOutcome(widget.orderData);
        if (knownOutcome == OrderPaymentOutcome.completed ||
            knownOutcome == OrderPaymentOutcome.pending) {
          final knownOrder = Map<String, dynamic>.from(widget.orderData);
          await OrderPaymentGuard.reconcileOrder(knownOrder,
              readRevision: OrderPaymentGuard.beginOrderRead());
          state = await OrderPaymentGuard.read(id);
        }
      }
      if (id != null && state == OrderPaymentState.unconfirmed &&
          !_orderClosed) {
        _kaspiPaymentLink ??= await OrderPaymentGuard.readKaspiLink(id);
        if (_kaspiPaymentLink != null) {
          _selectedPaymentMethod = _PaymentMethodType.kaspi;
          _selectedCardId = null;
        }
        if (!initial || _kaspiPaymentLink != null) {
          if (_kaspiPaymentLink != null) {
            final outcome = await _refreshKaspiStatus(id);
            serverCompleted = outcome == OrderPaymentOutcome.completed;
            statusUnavailable = outcome == OrderPaymentOutcome.unknown;
          } else {
            final numericId = int.tryParse(id);
            Map<String, dynamic>? order;
            if (numericId != null) {
              order = await ApiService.getOrderDetails(numericId)
                  .timeout(const Duration(seconds: 12));
            } else {
              final orders = await ApiService.getMyOrdersHistoryList()
                  .timeout(const Duration(seconds: 12));
              for (final candidate in orders) {
                if (paymentOrderId(candidate) == id) {
                  order = candidate;
                  break;
                }
              }
            }
            statusUnavailable = order == null;
            if (order != null && mounted) {
              _refreshedOrder = order;
              serverCompleted =
                  orderPaymentOutcome(order) == OrderPaymentOutcome.completed;
            }
          }
          state = await OrderPaymentGuard.read(id);
        }
      }
      if (!mounted) return;
      _applyPaymentState(state);
      if (statusUnavailable) {
        _setCardFeedback(
          'Сервер пока не подтвердил статус оплаты. Новый платёж заблокирован; попробуйте проверить статус снова.',
          _CardFeedbackTone.error,
        );
      }
      if (!initial && serverCompleted && !_orderClosed && id != null &&
          state == OrderPaymentState.completed) {
        await _finishSuccessfulPayment(id);
      }
    } catch (_) {
      if (!mounted) return;
      _applyPaymentState(state);
      _setCardFeedback(
        'Не удалось проверить оплату на сервере. Повторное списание заблокировано; попробуйте обновить статус.',
        _CardFeedbackTone.error,
      );
    } finally {
      if (mounted) setState(() => _readingPaymentGuard = false);
    }
  }

  void _applyPaymentState(OrderPaymentState state) {
    if (!mounted) return;
    setState(() {
      final wasLocked = _paymentState != OrderPaymentState.ready;
      _paymentState = state;
      if (state != OrderPaymentState.unconfirmed) _kaspiPaymentLink = null;
      if (_orderClosed) {
        _cardFeedback = const _CardFeedback(
          message: 'Заказ закрыт. Повторная оплата недоступна.',
          tone: _CardFeedbackTone.info,
        );
      } else if (state == OrderPaymentState.unconfirmed) {
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
        _flow.cards.any((card) =>
            card.canCharge && card.chargeId == _selectedCardId)) {
      return;
    }
    for (final card in _flow.cards) {
      if (card.canCharge) {
        _selectedPaymentMethod = _PaymentMethodType.card;
        _selectedCardId = card.chargeId;
        return;
      }
    }
    _selectedPaymentMethod = _PaymentMethodType.kaspi;
    _selectedCardId = null;
  }

  Future<void> _pay({_PaymentMethodType? paymentMethod}) async {
    if (_isPaying ||
        _orderClosed ||
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
            !_flow.cards.any((card) =>
                card.canCharge && card.chargeId == _selectedCardId))) {
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
          orElse: () => OrderPaymentState.unconfirmed,
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
      final result = await ApiService.createKaspiQrPayment(orderId, method: 'link')
          .timeout(const Duration(seconds: 12));
      final paymentData = ApiService.mapFromDynamic(result['data']);
      final createOutcome = result.containsKey('requestSent')
          ? orderPaymentResultOutcome(result)
          : orderPaymentOutcome(paymentData);

      if (result['requestSent'] == false) {
        await _settleKaspiPayment(orderId, OrderPaymentOutcome.refused);
      }
      if (createOutcome == OrderPaymentOutcome.refused) {
        await _settleKaspiPayment(orderId, createOutcome);
      }
      if (result['success'] != true ||
          createOutcome == OrderPaymentOutcome.refused) {
        if (mounted) {
          closeProgressDialog();
          await _showPaymentFailureNotice(_paymentErrorMessage(result['error']),
              kaspi: true);
        }
        return false;
      }

      if (createOutcome == OrderPaymentOutcome.completed) {
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

      _kaspiPaymentLink = paymentLink;
      final retained =
          await OrderPaymentGuard.retainKaspiLink(orderId, paymentLink);
      if (!mounted) return false;
      if (!retained) {
        _setCardFeedback(
          'Ссылка получена, но не сохранена на устройстве. Её можно открыть повторно сейчас; после перезапуска проверьте заказ перед оплатой.',
          _CardFeedbackTone.error,
        );
      }

      var opened = false;
      try {
        opened =
            await _openKaspiPaymentLink(paymentLink, webKaspiWindowHandle);
      } catch (_) {}
      if (!opened) {
        if (mounted) {
          closeProgressDialog();
          await _showPaymentFailureNotice(
              'Не удалось открыть ссылку оплаты Kaspi.kz. Нажмите «Открыть оплату», чтобы открыть ту же ссылку без нового списания.',
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

      final outcome = _kaspiReadOutcome(statusResult);
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

  OrderPaymentOutcome _kaspiReadOutcome(Map<String, dynamic> result) {
    if (result['success'] != true || result['outcomeUnknown'] == true ||
        result['requestSent'] == false) {
      return OrderPaymentOutcome.unknown;
    }
    return orderPaymentOutcome(ApiService.mapFromDynamic(result['data']));
  }

  Future<OrderPaymentOutcome> _refreshKaspiStatus(String orderId) async {
    final revision = OrderPaymentGuard.beginOrderRead();
    final result = await ApiService.getKaspiQrPaymentStatus(orderId)
        .timeout(const Duration(seconds: 12));
    final outcome = _kaspiReadOutcome(result);
    if (outcome == OrderPaymentOutcome.unknown) return outcome;
    final order = <String, dynamic>{
      ...ApiService.mapFromDynamic(result['data']),
      'order_id': orderId,
    };
    await OrderPaymentGuard.reconcileOrder(order, readRevision: revision);
    return outcome;
  }

  Future<void> _reopenKaspiPayment() async {
    final id = _orderId();
    final link = _kaspiPaymentLink;
    if (_isPaying || _readingPaymentGuard || _orderClosed ||
        _paymentState != OrderPaymentState.unconfirmed ||
        id == null || link == null) {
      return;
    }
    final window = _reserveWebKaspiPaymentWindow();
    if (kIsWeb && window == null) return;
    setState(() => _isPaying = true);
    var opened = false;
    try {
      final state = await OrderPaymentGuard.read(id);
      _applyPaymentState(state);
      if (state != OrderPaymentState.unconfirmed || !mounted) return;
      opened = await _openKaspiPaymentLink(link, window);
      _setCardFeedback(
        opened
            ? 'Та же ссылка Kaspi.kz открыта. Новый запрос оплаты не отправлен; результат подтверждает сервер.'
            : 'Не удалось открыть оплату. Ссылка сохранена; попробуйте открыть её снова или проверьте статус.',
        opened ? _CardFeedbackTone.info : _CardFeedbackTone.error,
      );
    } catch (_) {
      _setCardFeedback(
        'Не удалось открыть оплату. Ссылка сохранена, повторного списания не было.',
        _CardFeedbackTone.error,
      );
    } finally {
      if (!opened) closeReservedWebWindow(window);
      if (mounted) setState(() => _isPaying = false);
    }
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

      try {
        latestResult = await ApiService.getKaspiQrPaymentStatus(orderId)
            .timeout(const Duration(seconds: 12));
      } on TimeoutException {
        continue;
      }
      if (latestResult['success'] != true) {
        continue;
      }

      final outcome = _kaspiReadOutcome(latestResult);
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
    if (uri == null || !uri.hasScheme || uri.scheme == 'javascript' ||
        uri.scheme == 'data' || uri.scheme == 'file' ||
        uri.userInfo.isNotEmpty) {
      return false;
    }

    if (kIsWeb) {
      return navigateReservedWebWindow(
        webWindowHandle,
        uri.toString(),
        windowName: _webKaspiPaymentWindowName,
      );
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }


  void _showPaymentProgressDialog(_PaymentMethodType paymentMethod) {
    final isKaspi = paymentMethod == _PaymentMethodType.kaspi;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog.fullscreen(
          child: _PaymentNoticePage(
            title: 'Проводим оплату…',
            message: isKaspi
                ? 'Создаём ссылку Kaspi.kz и проверяем оплату на сервере'
                : null,
            kaspi: isKaspi,
            loading: true,
          ),
        ),
      ),
    );
  }

  Future<void> _finishSuccessfulPayment(String orderId) async {
    if (!mounted || _completionPresented) return;
    _completionPresented = true;

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

  String _getOrderAmount() {
    final amount = resolveServerChargedAmount(_refreshedOrder ?? widget.orderData)
        ?? widget.displayAmount;
    return amount == null ? 'Сумма не указана' : formatTenge(amount);
  }

  Future<void> _showNotice(String title, String message,
      {bool kaspi = false}) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: _PaymentNoticePage(
          title: title,
          message: message,
          kaspi: kaspi,
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  Future<void> _showPaymentFailureNotice(String message,
      {bool kaspi = false}) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: _PaymentNoticePage(
          title: 'Ошибка оплаты',
          message: message,
          kaspi: kaspi,
          failed: true,
          onClose: () => Navigator.of(dialogContext).pop(),
          onSupport: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => HelpChatPage(
                order: widget.orderData,
                entryPoint: 'payment_failure',
                initialTopic: 'Ошибка оплаты',
                paymentError: message,
              ),
            ));
          },
        ),
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
    final selectionBusy = _isPaying || _orderClosed ||
        _readingPaymentGuard || _paymentState != OrderPaymentState.ready ||
        _flow.preparing || _flow.awaiting;
    final cannotPay = selectionBusy || _flow.loading ||
        _selectedPaymentMethod == null ||
        (_selectedPaymentMethod == _PaymentMethodType.card &&
            (_selectedCardId == null || _flow.error != null ||
                !_flow.cards.any((card) =>
                    card.canCharge && card.chargeId == _selectedCardId)));
    return Scaffold(
      backgroundColor: palette.background,
      extendBody: true,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.paddingOf(context).bottom + 24),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 608),
            child: AppGlassPanel(
              radius: 32,
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: _paymentFooter(cannotPay),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppTopBar(
                    title: 'Способ оплаты',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Expanded(
                  child: Builder(builder: (context) => RefreshIndicator(
                    onRefresh: () async {
                      await _flow.refresh();
                      await _readPaymentGuard();
                    },
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
                                Text(_getOrderAmount(),
                                    key: const ValueKey('payment-payable-amount'),
                                    style: AppTypography.displayBold),
                                if (widget.amountNotice case final notice?) ...[
                                  const SizedBox(height: 12),
                                  Semantics(
                                    liveRegion: true,
                                    child: AppSurface(
                                      key: const ValueKey('payment-amount-notice'),
                                      padding: const EdgeInsets.all(12),
                                      fill: palette.error.withValues(alpha: .12),
                                      child: Text(notice,
                                          style: AppTypography.bodySmall),
                                    ),
                                  ),
                                ],
                                if (_cardFeedback case final feedback?) ...[
                                  const SizedBox(height: 24),
                                  Semantics(
                                    liveRegion: true,
                                    child: AppSurface(
                                      padding: const EdgeInsets.all(16),
                                      fill: (feedback.tone == _CardFeedbackTone.error
                                          ? palette.error : palette.accent)
                                          .withValues(alpha: .12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (_selectedPaymentMethod ==
                                              _PaymentMethodType.kaspi) ...[
                                            const KaspiLogo(),
                                            const SizedBox(height: 12),
                                          ],
                                          Text(feedback.message,
                                              style: AppTypography.body),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                if (_paymentState != OrderPaymentState.ready ||
                                    _orderClosed) ...[
                                  const SizedBox(height: 12),
                                  if (_paymentState !=
                                      OrderPaymentState.storageUnavailable ||
                                      _orderClosed)
                                    OutlinedButton(
                                      key: const ValueKey('payment-pending-orders'),
                                      onPressed: _readingPaymentGuard || _isPaying
                                          ? null : _openOrders,
                                      child: const Text('Проверить мои заказы'),
                                    ),
                                  OutlinedButton(
                                    key: const ValueKey('payment-state-refresh'),
                                    onPressed: _readingPaymentGuard || _isPaying
                                        ? null : _readPaymentGuard,
                                    child: Text(_readingPaymentGuard
                                        ? 'Проверяем состояние…'
                                        : 'Проверить состояние оплаты'),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                if (_flow.message != null) ...[
                                  CardFlowFeedback(flow: _flow),
                                  const SizedBox(height: 12),
                                ],
                                _kaspiRow(selectionBusy),
                                const SizedBox(height: 24),
                                Text('Сохранённые карты',
                                    style: AppTypography.title),
                                const SizedBox(height: 16),
                                const CardFaqPanel(),
                                const SizedBox(height: 24),
                                if (_flow.loading)
                                  const SizedBox(height: 80, child: AppLoading()),
                                if (_flow.error != null ||
                                    _flow.partialWarning != null)
                                  CardReadFeedback(
                                    flow: _flow,
                                    allowSignIn:
                                        !_isPaying && !_paymentUnconfirmed,
                                  )
                                else if (!_flow.loading && _flow.cards.isEmpty)
                                  const AppEmptyState(
                                    title: 'Добавленных карт нет',
                                    subtitle:
                                        'Можно оплатить через Kaspi.kz или добавить карту в форме банка',
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (_flow.cards.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList.builder(
                              itemCount: _flow.cards.length,
                              itemBuilder: (_, index) {
                                final card = _flow.cards[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: SavedCardRow(
                                    key: ValueKey('payment-card-${card.rowKey}'),
                                    card: card,
                                    selected: card.canCharge &&
                                        _selectedPaymentMethod == _PaymentMethodType.card &&
                                        _selectedCardId == card.chargeId,
                                    onSelected: selectionBusy || _flow.loading ||
                                            _flow.error != null || !card.canCharge
                                        ? null
                                        : () => setState(() {
                                            _selectedPaymentMethod = _PaymentMethodType.card;
                                            _selectedCardId = card.chargeId;
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
                                  onPressed: !_isPaying && !_orderClosed &&
                                          _flow.canAdd
                                      ? _flow.addCard : null,
                                  icon: const Icon(Icons.add),
                                  label: Text(_flow.preparing
                                      ? 'Открываем банк…'
                                      : _flow.addState == CardAddState.launchFailed
                                          ? 'Открыть форму снова'
                                          : 'Добавить новую карту'),
                                ),
                                if (!_flow.awaiting)
                                  TextButton(
                                    key: const ValueKey('refresh-card-list'),
                                    onPressed: _flow.loading || _flow.preparing ||
                                            _isPaying
                                        ? null : _flow.refresh,
                                    child: const Text('Обновить список'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                              height: MediaQuery.paddingOf(context).bottom + 16),
                        ),
                      ],
                    ),
                  )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentFooter(bool cannotPay) {
    if (_kaspiPaymentLink != null && _paymentUnconfirmed && !_orderClosed) {
      return FilledButton(
        key: const ValueKey('reopen-kaspi-payment'),
        onPressed: _isPaying || _readingPaymentGuard ? null : _reopenKaspiPayment,
        child: const Text('Открыть оплату'),
      );
    }
    if (_selectedPaymentMethod != _PaymentMethodType.kaspi) {
      return FilledButton(
        key: const ValueKey('pay-order-button'),
        onPressed: cannotPay ? null : _pay,
        child: Text(_isPaying ? 'Проводим оплату…' : 'Оплатить'),
      );
    }
    if (_paymentState != OrderPaymentState.ready ||
        _readingPaymentGuard || _orderClosed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          _orderClosed ? 'Заказ закрыт'
              : _paymentState == OrderPaymentState.completed
                  ? 'Заказ уже оплачен'
                  : _paymentState == OrderPaymentState.storageUnavailable
                      ? 'Проверьте состояние оплаты'
                      : 'Ожидаем подтверждение оплаты',
          key: const ValueKey('kaspi-payment-state'),
          textAlign: TextAlign.center,
          style: AppTypography.body,
        ),
      );
    }
    return KaspiPayButton(
      buttonKey: const ValueKey('pay-order-button'),
      onPressed: cannotPay ? null : _pay,
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

class _PaymentNoticePage extends StatelessWidget {
  const _PaymentNoticePage({
    required this.title,
    this.message,
    this.kaspi = false,
    this.loading = false,
    this.failed = false,
    this.onClose,
    this.onSupport,
  });

  final String title;
  final String? message;
  final bool kaspi;
  final bool loading;
  final bool failed;
  final VoidCallback? onClose;
  final VoidCallback? onSupport;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      extendBody: true,
      bottomNavigationBar: onClose == null
          ? null
          : SafeArea(
              top: false,
              minimum: EdgeInsets.fromLTRB(
                  16, 12, 16, MediaQuery.paddingOf(context).bottom + 24),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 608),
                  child: AppGlassPanel(
                    radius: 32,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: onClose,
                          child: Text(failed
                              ? 'Изменить способ оплаты' : 'Понятно'),
                        ),
                        if (failed)
                          TextButton(
                            onPressed: onClose,
                            child: const Text('Понятно'),
                          ),
                        if (onSupport != null)
                          TextButton(
                            onPressed: onSupport,
                            child: const Text('Написать в поддержку'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                if (onClose != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppTopBar(title: '', onBack: onClose),
                  ),
                Expanded(
                  child: Builder(builder: (context) => CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16,
                              MediaQuery.paddingOf(context).bottom + 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (kaspi) ...[
                                const KaspiLogo(),
                                const SizedBox(height: 32),
                              ],
                              if (loading)
                                SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 8,
                                    strokeCap: StrokeCap.round,
                                    color: palette.accent,
                                    backgroundColor: palette.textSecondary,
                                  ),
                                )
                              else
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: failed ? palette.error :
                                        palette.accentFaint,
                                  ),
                                  child: Icon(
                                    failed ? Icons.close : Icons.schedule,
                                    size: 48,
                                    color: failed ? Colors.white :
                                        palette.accent,
                                  ),
                                ),
                              const SizedBox(height: 28),
                              Text(title,
                                  style: AppTypography.headline,
                                  textAlign: TextAlign.center),
                              if (message != null) ...[
                                const SizedBox(height: 16),
                                Text(message!,
                                    style: AppTypography.body.copyWith(
                                        color: palette.textSecondary),
                                    textAlign: TextAlign.center),
                              ],
                              if (failed) ...[
                                const SizedBox(height: 28),
                                const CardFaqPanel(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
