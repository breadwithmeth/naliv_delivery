import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:naliv_delivery/core/money.dart';
import 'package:naliv_delivery/core/json_payload.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/design/tokens.dart';
import 'package:naliv_delivery/design/typography.dart';
import 'package:naliv_delivery/features/checkout/ui/payment_success_page.dart';
import 'package:naliv_delivery/features/orders/ui/orders_page.dart';
import 'package:naliv_delivery/features/faq/faq_navigation.dart';
import 'package:naliv_delivery/features/faq/models/faq.dart';
import 'package:naliv_delivery/pages/help_chat_page.dart';
import 'package:naliv_delivery/ui/app_states.dart';
import 'package:naliv_delivery/ui/app_icon.dart';
import 'package:naliv_delivery/ui/app_icon_button.dart';
import 'package:naliv_delivery/ui/frosted_dock.dart';
import 'package:naliv_delivery/ui/frosted_surface.dart';
import 'package:naliv_delivery/ui/app_top_bar.dart';
import 'package:naliv_delivery/ui/payment_method_tile.dart';
import 'package:naliv_delivery/ui/surfaces.dart';
import 'package:naliv_delivery/ui/kaspi_payment.dart';
import 'package:naliv_delivery/services/auth_service.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/order_payment_guard.dart';
import 'package:naliv_delivery/utils/order_ui_helpers.dart';
import 'package:naliv_delivery/utils/web_window.dart';
import 'package:url_launcher/url_launcher.dart';

import 'card_flow.dart';
import 'payment_notice_page.dart';
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
  bool get _orderClosed => isOrderClosed(_refreshedOrder ?? widget.orderData);
  int _ownerRevision = AuthService.credentialRevision;
  final String? _ownerAccount = AuthService.currentIdentity;
  bool _invalidated = false;
  Route<void>? _progressRoute;
  PaymentFollowUp? _deferredFollowUp;
  double _dockHeight = 0;
  bool get _ownerCurrent =>
      mounted &&
      !_invalidated &&
      _ownerRevision == AuthService.credentialRevision &&
      !AuthService.isEndingSession;

  void _credentialsChanged() {
    if (!mounted) return;
    if (_invalidated &&
        _ownerAccount != null &&
        AuthService.currentIdentity == _ownerAccount &&
        !_flow.reauthenticationRequired &&
        !AuthService.isEndingSession) {
      setState(() {
        _ownerRevision = AuthService.credentialRevision;
        _invalidated = false;
      });
      _readPaymentGuard(initial: true);
      return;
    }
    if (_ownerRevision == AuthService.credentialRevision) return;
    _closePaymentProgress();
    setState(() {
      _invalidated = true;
      _selectedCardId = null;
      _selectedPaymentMethod = null;
      _kaspiPaymentLink = null;
      _refreshedOrder = null;
      _cardFeedback = null;
      _readingPaymentGuard = false;
    });
  }

  void _closePaymentProgress() {
    final route = _progressRoute;
    _progressRoute = null;
    if (route?.isActive == true) route!.navigator?.removeRoute(route);
  }

  @override
  void initState() {
    super.initState();
    _flow = CardFlow(
      readCards: CardFlow.readAuthenticatedCards,
      openForm: (uri, window) => openHostedCardForm(context, uri, window,
          openCardForm: widget.openCardForm),
      requiresWindow: kIsWeb && widget.openCardForm == null,
      reserveWindow: kIsWeb && widget.openCardForm == null
          ? () => reserveWebNamedWindow(cardFormWindowName)
          : null,
      closeWindow: closeReservedWebWindow,
    )..addListener(_cardsChanged);
    WidgetsBinding.instance.addObserver(this);
    AuthService.sessionRevision.addListener(_credentialsChanged);
    _flow.refresh();
    _readPaymentGuard(initial: true);
  }

  void _cardsChanged() {
    if (!mounted) return;
    if (_invalidated && !_flow.reauthenticationRequired) {
      _credentialsChanged();
    }
    setState(() {
      if (!_flow.loading && _flow.error == null) _syncSelectedPaymentMethod();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthService.sessionRevision.removeListener(_credentialsChanged);
    _flow.removeListener(_cardsChanged);
    _flow.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ownerCurrent) {
      _readPaymentGuard();
      _flow.refresh();
    }
  }

  Future<void> _readPaymentGuard({bool initial = false}) async {
    if (!_ownerCurrent || _isPaying || (_readingPaymentGuard && !initial)) {
      return;
    }
    setState(() => _readingPaymentGuard = true);
    final session = await AuthService.captureSession();
    if (session == null || !session.isCurrent || !_ownerCurrent) return;
    final id = _orderId();
    var state = id == null
        ? OrderPaymentState.storageUnavailable
        : await OrderPaymentGuard.read(id, accountId: _ownerAccount);
    var serverCompleted = false;
    var statusUnavailable = false;
    var kaspiCancelled = false;
    try {
      if (initial && id != null) {
        final knownOutcome = orderPaymentOutcome(widget.orderData);
        if (knownOutcome == OrderPaymentOutcome.completed ||
            knownOutcome == OrderPaymentOutcome.pending) {
          final knownOrder = Map<String, dynamic>.from(widget.orderData);
          await OrderPaymentGuard.reconcileOrder(knownOrder,
              readRevision: OrderPaymentGuard.beginOrderRead(),
              accountId: _ownerAccount);
          state = await OrderPaymentGuard.read(id, accountId: _ownerAccount);
        }
      }
      if (id != null &&
          state == OrderPaymentState.unconfirmed &&
          !_orderClosed) {
        final retainedLink =
            await OrderPaymentGuard.readKaspiLink(id, accountId: _ownerAccount);
        if (!_ownerCurrent || !session.isCurrent) return;
        _kaspiPaymentLink ??= retainedLink;
        if (_kaspiPaymentLink != null) {
          _selectedPaymentMethod = _PaymentMethodType.kaspi;
          _selectedCardId = null;
        }
        if (!initial || _kaspiPaymentLink != null) {
          if (_kaspiPaymentLink != null) {
            final outcome = await _refreshKaspiStatus(id, session);
            serverCompleted = outcome == OrderPaymentOutcome.completed;
            statusUnavailable = outcome == OrderPaymentOutcome.unknown;
            kaspiCancelled = !initial && outcome == OrderPaymentOutcome.refused;
          } else {
            final numericId = int.tryParse(id);
            Map<String, dynamic>? order;
            if (numericId != null) {
              order = await ApiService.getOrderDetails(numericId,
                      credentialToken: session.token)
                  .timeout(const Duration(seconds: 12));
            } else {
              final orders = await ApiService.getMyOrdersHistoryList(
                      credentialToken: session.token)
                  .timeout(const Duration(seconds: 12));
              for (final candidate in orders) {
                if (paymentOrderId(candidate) == id) {
                  order = candidate;
                  break;
                }
              }
            }
            statusUnavailable = order == null;
            if (order != null && _ownerCurrent && session.isCurrent) {
              _refreshedOrder = order;
              serverCompleted =
                  orderPaymentOutcome(order) == OrderPaymentOutcome.completed;
            }
          }
          state = await OrderPaymentGuard.read(id, accountId: _ownerAccount);
        }
      }
      if (!_ownerCurrent || !session.isCurrent) return;
      _applyPaymentState(state);
      if (statusUnavailable) {
        _setCardFeedback(
          'Сервер пока не подтвердил статус оплаты. Новый платёж заблокирован; попробуйте проверить статус снова.',
          _CardFeedbackTone.error,
        );
      }
      if (!initial &&
          serverCompleted &&
          !_orderClosed &&
          id != null &&
          state == OrderPaymentState.completed) {
        await _finishSuccessfulPayment(id);
      }
    } catch (_) {
      if (!_ownerCurrent || !session.isCurrent) return;
      _applyPaymentState(state);
      _setCardFeedback(
        'Не удалось проверить оплату на сервере. Повторное списание заблокировано; попробуйте обновить статус.',
        _CardFeedbackTone.error,
      );
    } finally {
      if (mounted) setState(() => _readingPaymentGuard = false);
    }
    if (kaspiCancelled &&
        _ownerCurrent &&
        _paymentState == OrderPaymentState.ready) {
      final followUp = await _showKaspiFailure(
        title: 'Отмена покупки',
        message: 'Вы не подтвердили покупку',
      );
      if (followUp != null) {
        await _runFollowUp(followUp, method: _PaymentMethodType.kaspi);
      }
    }
  }

  void _applyPaymentState(OrderPaymentState state) {
    if (!_ownerCurrent) return;
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
        _flow.cards.any(
            (card) => card.canCharge && card.chargeId == _selectedCardId)) {
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
    if (!_ownerCurrent ||
        _flow.reauthenticationRequired ||
        _isPaying ||
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
    final session = await AuthService.captureSession();
    if (session == null || !session.isCurrent || !_ownerCurrent) {
      if (mounted) setState(() => _isPaying = false);
      closeReservedWebWindow(kaspiWindowHandle);
      return;
    }

    var progressDialogShown = false;
    void closeProgressDialog() {
      if (!progressDialogShown || !mounted) return;
      _closePaymentProgress();
      progressDialogShown = false;
    }

    if (mounted) {
      _showPaymentProgressDialog(selectedMethod);
      progressDialogShown = true;
    }

    var kaspiPaymentOpened = false;
    try {
      if (selectedMethod == _PaymentMethodType.card) {
        final result = await ApiService.payOrder(orderId, _selectedCardId!,
            credentialToken: session.token);

        closeProgressDialog();
        if (!_ownerCurrent || !session.isCurrent) return;

        final paymentData = payloadMap(result['data']);
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
          _deferredFollowUp = await _showPaymentFailureNotice(
              _paymentErrorMessage(result['error'] ?? paymentData['error']));
        }

        return;
      }

      kaspiPaymentOpened = await _payWithKaspi(
        orderId,
        kaspiWindowHandle,
        closeProgressDialog,
        session,
      );
      closeProgressDialog();
    } catch (e) {
      closeProgressDialog();
      if (_ownerCurrent && session.isCurrent) {
        _deferredFollowUp = await _showPaymentFailureNotice(
            'Не удалось завершить оплату из-за ошибки. Проверьте соединение.',
            kaspi: selectedMethod == _PaymentMethodType.kaspi,
            supportError: 'Произошла ошибка: $e');
      }
    } finally {
      closeProgressDialog();
      if (mounted) {
        setState(() {
          _isPaying = false;
        });
      }
      if (_ownerCurrent && !session.isCurrent) {
        unawaited(_readPaymentGuard());
      }
      if (selectedMethod == _PaymentMethodType.kaspi && !kaspiPaymentOpened) {
        closeReservedWebWindow(kaspiWindowHandle);
      }
      final followUp = _deferredFollowUp;
      _deferredFollowUp = null;
      if (followUp != null && _ownerCurrent) {
        await _runFollowUp(followUp, method: selectedMethod);
      }
    }
  }

  Future<bool> _payWithKaspi(
    String orderId,
    Object? webKaspiWindowHandle,
    VoidCallback closeProgressDialog,
    AuthSession session,
  ) async {
    final reservation =
        await OrderPaymentGuard.reserve(orderId, accountId: _ownerAccount);
    if (reservation != OrderPaymentState.ready) {
      _applyPaymentState(reservation);
      return false;
    }
    _applyPaymentState(OrderPaymentState.unconfirmed);
    try {
      if (!_ownerCurrent || !session.isCurrent) {
        await OrderPaymentGuard.settle(orderId, OrderPaymentOutcome.refused,
            accountId: _ownerAccount);
        return false;
      }
      final result = await ApiService.createKaspiQrPayment(orderId,
          method: 'link', credentialToken: session.token);
      final paymentData = payloadMap(result['data']);
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
        if (_ownerCurrent && session.isCurrent) {
          closeProgressDialog();
          _deferredFollowUp = await _showKaspiFailure(
            title: 'Не удалось начать оплату',
            message: _paymentErrorMessage(result['error']),
          );
        }
        return false;
      }

      if (createOutcome == OrderPaymentOutcome.completed) {
        await _settleKaspiPayment(orderId, OrderPaymentOutcome.completed);
        if (!_ownerCurrent || !session.isCurrent) return false;
        closeProgressDialog();
        await _finishSuccessfulPayment(orderId);
        return false;
      }

      final paymentLink = _nonEmptyString(paymentData['paymentLink']);

      if (paymentLink == null) {
        if (_ownerCurrent && session.isCurrent) {
          closeProgressDialog();
          _deferredFollowUp = await _showKaspiFailure(
            title: 'Не удалось начать оплату',
            message: 'Kaspi.kz не вернул ссылку для оплаты.',
          );
        }
        return false;
      }

      if (_ownerCurrent && session.isCurrent) _kaspiPaymentLink = paymentLink;
      final retained = await OrderPaymentGuard.retainKaspiLink(
          orderId, paymentLink,
          accountId: _ownerAccount);
      if (!_ownerCurrent || !session.isCurrent) return false;
      if (!retained) {
        _setCardFeedback(
          'Ссылка получена, но не сохранена на устройстве. Её можно открыть повторно сейчас; после перезапуска проверьте заказ перед оплатой.',
          _CardFeedbackTone.error,
        );
      }

      var opened = false;
      try {
        opened = await _openKaspiPaymentLink(paymentLink, webKaspiWindowHandle);
      } catch (_) {}
      if (!opened) {
        if (mounted) {
          closeProgressDialog();
          _deferredFollowUp = await _showKaspiFailure(
            title: 'Не удалось открыть Kaspi.kz',
            message:
                'Ссылка для оплаты сохранена: её можно открыть снова без нового списания.',
          );
        }
        return false;
      }

      _setCardFeedback(
        'Ссылка Kaspi.kz открыта. Ожидаем подтверждение оплаты.',
        _CardFeedbackTone.info,
      );

      final statusResult =
          await _pollKaspiPaymentStatus(orderId, paymentData, session);
      if (!_ownerCurrent || !session.isCurrent) return true;

      if (statusResult == null || statusResult['success'] != true) {
        closeProgressDialog();
        _deferredFollowUp = await _showKaspiFailure(
          title: 'Статус оплаты не получен',
          message:
              'Не удалось проверить оплату в Kaspi.kz. Если вы уже оплатили заказ, она обновится после подтверждения.',
          failed: false,
          preferCheck: true,
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
        _deferredFollowUp = await _showKaspiFailure(
          title: 'Отмена покупки',
          message: 'Вы не подтвердили покупку',
        );
        return true;
      }

      closeProgressDialog();
      _deferredFollowUp = await _showKaspiFailure(
        title: 'Подтвердите оплату',
        message:
            'Откройте приложение Kaspi.kz и подтвердите покупку. Если вы уже оплатили заказ, статус обновится после подтверждения.',
        failed: false,
        preferCheck: true,
      );
      return true;
    } finally {
      OrderPaymentGuard.release(orderId);
    }
  }

  Future<void> _settleKaspiPayment(
      String orderId, OrderPaymentOutcome outcome) async {
    _applyPaymentState(await OrderPaymentGuard.settle(orderId, outcome,
        accountId: _ownerAccount));
  }

  OrderPaymentOutcome _kaspiReadOutcome(Map<String, dynamic> result) {
    if (result['success'] != true ||
        result['outcomeUnknown'] == true ||
        result['requestSent'] == false) {
      return OrderPaymentOutcome.unknown;
    }
    return orderPaymentOutcome(payloadMap(result['data']));
  }

  Future<OrderPaymentOutcome> _refreshKaspiStatus(
      String orderId, AuthSession session) async {
    final revision = OrderPaymentGuard.beginOrderRead();
    final result = await ApiService.getKaspiQrPaymentStatus(orderId,
            credentialToken: session.token)
        .timeout(const Duration(seconds: 12));
    if (!_ownerCurrent || !session.isCurrent) {
      return OrderPaymentOutcome.unknown;
    }
    final outcome = _kaspiReadOutcome(result);
    if (outcome == OrderPaymentOutcome.unknown) return outcome;
    final order = <String, dynamic>{
      ...payloadMap(result['data']),
      'order_id': orderId,
    };
    await OrderPaymentGuard.reconcileOrder(order,
        readRevision: revision, accountId: _ownerAccount, verifiedRead: true);
    return outcome;
  }

  Future<void> _reopenKaspiPayment() async {
    final id = _orderId();
    final link = _kaspiPaymentLink;
    if (!_ownerCurrent ||
        _flow.reauthenticationRequired ||
        _isPaying ||
        _readingPaymentGuard ||
        _orderClosed ||
        _paymentState != OrderPaymentState.unconfirmed ||
        id == null ||
        link == null) {
      return;
    }
    final window = _reserveWebKaspiPaymentWindow();
    if (kIsWeb && window == null) return;
    setState(() => _isPaying = true);
    var opened = false;
    try {
      final state = await OrderPaymentGuard.read(id, accountId: _ownerAccount);
      _applyPaymentState(state);
      if (state != OrderPaymentState.unconfirmed || !_ownerCurrent) return;
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
    AuthSession session,
  ) async {
    final behaviorOptions = payloadMap(paymentData['behaviorOptions']);
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
      if (!_ownerCurrent || !session.isCurrent) return latestResult;

      try {
        latestResult = await ApiService.getKaspiQrPaymentStatus(orderId,
                credentialToken: session.token)
            .timeout(const Duration(seconds: 12));
      } on TimeoutException {
        continue;
      }
      if (!_ownerCurrent || !session.isCurrent) return null;
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
    if (uri == null ||
        !uri.hasScheme ||
        uri.scheme == 'javascript' ||
        uri.scheme == 'data' ||
        uri.scheme == 'file' ||
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
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog.fullscreen(
          child: PaymentNoticePage(
            title: isKaspi ? 'Готовимся к приему оплаты' : 'Проводим оплату…',
            message: null,
            kaspi: isKaspi,
            loading: true,
          ),
        ),
      ),
    );
    _progressRoute = route;
    unawaited(Navigator.of(context, rootNavigator: true).push(route));
  }

  Future<void> _finishSuccessfulPayment(String orderId) async {
    if (!_ownerCurrent || _completionPresented) return;
    _completionPresented = true;

    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => PaymentSuccessPage(
        orderId: orderId,
        businessId:
            int.tryParse(widget.orderData['business_id']?.toString() ?? ''),
        onOrders: widget.onPaymentCompleted == null
            ? null
            : () => widget.onPaymentCompleted!(orderId),
        kaspi: _selectedPaymentMethod == _PaymentMethodType.kaspi ||
            _kaspiPaymentLink != null,
        amount: _chargedAmount(),
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

  String _getOrderAmount() => _chargedAmount() ?? 'Сумма не указана';

  String? _chargedAmount() {
    final amount =
        resolveServerChargedAmount(_refreshedOrder ?? widget.orderData) ??
            widget.displayAmount;
    return amount == null ? null : formatTenge(amount);
  }

  /// Shows [PaymentNoticePage] over the page and returns the follow-up the user chose, or
  /// null when the notice was only dismissed. Support opens the chat right here: it needs
  /// no payment state.
  Future<PaymentFollowUp?> _presentNotice({
    required String title,
    String? message,
    String? note,
    bool kaspi = false,
    bool failed = false,
    bool cardFaq = false,
    bool help = false,
    PaymentNoticeChoice? primary,
    PaymentNoticeChoice? secondary,
    String? supportError,
  }) async {
    if (!_ownerCurrent) return null;
    final result = await showDialog<PaymentFollowUp>(
      context: context,
      useSafeArea: false,
      builder: (dialogContext) => Dialog.fullscreen(
        child: PaymentNoticePage(
          title: title,
          message: message,
          note: note,
          kaspi: kaspi,
          failed: failed,
          cardFaq: cardFaq,
          help: help,
          primary: primary,
          secondary: secondary,
          onResult: (followUp) => Navigator.of(dialogContext).pop(followUp),
        ),
      ),
    );
    if (result != PaymentFollowUp.support) return result;
    if (mounted) {
      unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => HelpChatPage(
          order: widget.orderData,
          entryPoint: 'payment_failure',
          initialTopic: 'Ошибка оплаты',
          paymentError: supportError ?? message,
        ),
      )));
    }
    return null;
  }

  Future<void> _showNotice(String title, String message,
      {bool kaspi = false}) async {
    await _presentNotice(title: title, message: message, kaspi: kaspi);
  }

  static const _retry = PaymentNoticeChoice('Попробовать снова',
      followUp: PaymentFollowUp.retry, key: ValueKey('payment-notice-retry'));
  static const _check = PaymentNoticeChoice('Проверить оплату',
      followUp: PaymentFollowUp.check, key: ValueKey('payment-notice-check'));
  static const _reopen = PaymentNoticeChoice('Открыть оплату',
      followUp: PaymentFollowUp.reopen, key: ValueKey('payment-notice-reopen'));

  /// Why a retry is not offered while the order's payment state is uncertain.
  String? get _lockedNote => _paymentState == OrderPaymentState.unconfirmed
      ? 'Платёж мог быть создан, поэтому новый запрос заблокирован: повторного списания не будет.'
      : null;

  /// The actions of a failed or unfinished payment, chosen from what the payment guard
  /// knows. Only a settled refusal ([OrderPaymentState.ready]) can be retried; while the
  /// outcome is uncertain the user may re-open the same Kaspi link or ask the server, and
  /// never start a second charge. [preferCheck] puts «Проверить оплату» first, for a
  /// payment that is still waiting for the user.
  (PaymentNoticeChoice, PaymentNoticeChoice?) _noticeChoices(
      {required bool kaspi, bool preferCheck = false}) {
    switch (_paymentState) {
      case OrderPaymentState.ready:
        return kaspi
            ? (
                _retry,
                const PaymentNoticeChoice('Выбрать другой способ',
                    key: ValueKey('payment-notice-change')),
              )
            : (
                const PaymentNoticeChoice('Изменить способ оплаты',
                    key: ValueKey('payment-notice-change')),
                _retry,
              );
      case OrderPaymentState.unconfirmed:
        if (kaspi && _kaspiPaymentLink != null) {
          return preferCheck ? (_check, _reopen) : (_reopen, _check);
        }
        return (_check, null);
      case OrderPaymentState.completed:
      case OrderPaymentState.storageUnavailable:
        return (const PaymentNoticeChoice('Понятно'), null);
    }
  }

  /// A failed Kaspi.kz payment in Kaspi's error template (grey cross, title, one reason).
  Future<PaymentFollowUp?> _showKaspiFailure({
    required String title,
    required String message,
    bool failed = true,
    bool preferCheck = false,
    String? supportError,
  }) {
    final (primary, secondary) =
        _noticeChoices(kaspi: true, preferCheck: preferCheck);
    return _presentNotice(
      title: title,
      message: message,
      note: _lockedNote,
      kaspi: true,
      failed: failed,
      help: true,
      primary: primary,
      secondary: secondary,
      supportError: supportError,
    );
  }

  Future<PaymentFollowUp?> _showPaymentFailureNotice(String message,
      {bool kaspi = false, String? title, String? supportError}) {
    if (kaspi) {
      return _showKaspiFailure(
        title: title ?? 'Не удалось выполнить оплату',
        message: message,
        supportError: supportError,
      );
    }
    final (primary, secondary) = _noticeChoices(kaspi: false);
    return _presentNotice(
      title: title ?? 'Ошибка оплаты',
      message: message,
      note: _lockedNote,
      failed: true,
      cardFaq: true,
      help: true,
      primary: primary,
      secondary: secondary,
      supportError: supportError,
    );
  }

  /// Runs what the user chose on a notice, after the payment that raised it has finished.
  Future<void> _runFollowUp(PaymentFollowUp followUp,
      {_PaymentMethodType? method}) async {
    if (!_ownerCurrent) return;
    switch (followUp) {
      case PaymentFollowUp.retry:
        await _pay(paymentMethod: method);
      case PaymentFollowUp.reopen:
        await _reopenKaspiPayment();
      case PaymentFollowUp.check:
        await _readPaymentGuard();
      case PaymentFollowUp.support:
        break;
    }
  }

  void _setCardFeedback(String message, _CardFeedbackTone tone) {
    if (!_ownerCurrent) return;
    setState(() {
      _cardFeedback = _CardFeedback(message: message, tone: tone);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ownerCurrent) {
      return Scaffold(
        appBar: AppBar(title: const Text('Оплата заказа')),
        body: _flow.reauthenticationRequired
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CardReadFeedback(flow: _flow),
                ),
              )
            : const AppErrorState(
                message: 'Аккаунт изменился. Данные предыдущего заказа скрыты. '
                    'Найдите свой заказ в истории; повторная оплата не отправлена.',
                onRetry: null,
              ),
      );
    }
    final palette = context.palette;
    final selectionBusy = _isPaying ||
        _flow.reauthenticationRequired ||
        _orderClosed ||
        _readingPaymentGuard ||
        _paymentState != OrderPaymentState.ready ||
        _flow.preparing ||
        _flow.awaiting;
    final cannotPay = selectionBusy ||
        _flow.loading ||
        _selectedPaymentMethod == null ||
        (_selectedPaymentMethod == _PaymentMethodType.card &&
            (_selectedCardId == null ||
                _flow.error != null ||
                !_flow.cards.any((card) =>
                    card.canCharge && card.chargeId == _selectedCardId)));
    // The list ends above the bar's measured height, not a guessed inset.
    final bottomClearance =
        _dockHeight + MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl;
    // While a charge is in flight, leaving would hide its outcome.
    return PopScope(
      canPop: !_isPaying,
      child: Scaffold(
        backgroundColor: palette.background,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: FrostedDock(
              onDockHeightChanged: (height) {
                if ((height - _dockHeight).abs() > 0.5) {
                  setState(() => _dockHeight = height);
                }
              },
              content: FrostedHeaderLayout(
                estimatedHeaderHeight: 87,
                header: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xxxl, 0, AppSpacing.xxxl, AppSpacing.md),
                  child: AppTopBar(
                    title: 'Способ оплаты',
                    onBack: () => Navigator.of(context).maybePop(),
                    backEnabled: !_isPaying,
                    trailing: AppIconButton(
                      key: const ValueKey('payment-faq'),
                      asset: AppIcons.faq,
                      tooltip: 'Вопросы об оплате',
                      onTap: () => openFaqPage(context,
                          initialSection: FaqSection.payment),
                    ),
                  ),
                ),
                body: (context, topInset) => RefreshIndicator(
                  edgeOffset: topInset,
                  onRefresh: () async {
                    await _flow.refresh();
                    await _readPaymentGuard();
                  },
                  child: _methodList(
                    topInset: topInset,
                    bottomClearance: bottomClearance,
                    selectionBusy: selectionBusy,
                  ),
                ),
              ),
              dock: Padding(
                // The dock supplies the 16 px sides and the safe-area inset below; the
                // action keeps 8 px of its own around it (Kaspi's free zone).
                padding: const EdgeInsets.fromLTRB(
                    0, AppSpacing.md, 0, AppSpacing.xs),
                child: _paymentAction(cannotPay),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The scrolling body: amount and notices, then one list of methods (Kaspi.kz first,
  /// then the saved cards), then adding a card and help. Cards scroll under the frosted
  /// header and bar; the last row stops [bottomClearance] above the bottom edge.
  Widget _methodList({
    required double topInset,
    required double bottomClearance,
    required bool selectionBusy,
  }) {
    final palette = context.palette;
    const gap = SizedBox(height: AppSpacing.xl);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(AppSpacing.xxxl,
              topInset + AppSpacing.xxxl, AppSpacing.xxxl, bottomClearance),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(child: _summary(palette)),
              const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.huge)),
              if (_flow.message != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    child: CardFlowFeedback(flow: _flow),
                  ),
                ),
              SliverToBoxAdapter(child: _kaspiTile(selectionBusy)),
              if (_flow.loading)
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80, child: AppLoading()),
                )
              else if (_flow.error != null || _flow.partialWarning != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xl),
                    child: CardReadFeedback(
                      flow: _flow,
                      allowSignIn: !_isPaying && !_paymentUnconfirmed,
                    ),
                  ),
                )
              else if (_flow.cards.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: AppSpacing.huge),
                    child: AppEmptyState(
                      title: 'Добавленных карт нет',
                      subtitle:
                          'Можно оплатить через Kaspi.kz или добавить карту в форме банка',
                    ),
                  ),
                ),
              if (_flow.cards.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  sliver: SliverList.separated(
                    itemCount: _flow.cards.length,
                    separatorBuilder: (_, __) => gap,
                    itemBuilder: (_, index) {
                      final card = _flow.cards[index];
                      return SavedCardRow(
                        key: ValueKey('payment-card-${card.rowKey}'),
                        card: card,
                        selected: card.canCharge &&
                            _selectedPaymentMethod == _PaymentMethodType.card &&
                            _selectedCardId == card.chargeId,
                        showSelection: card.canCharge,
                        onSelected: selectionBusy ||
                                _flow.loading ||
                                _flow.error != null ||
                                !card.canCharge
                            ? null
                            : () => setState(() {
                                  _selectedPaymentMethod =
                                      _PaymentMethodType.card;
                                  _selectedCardId = card.chargeId;
                                }),
                      );
                    },
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('add-card-button'),
                        onPressed: !_isPaying && !_orderClosed && _flow.canAdd
                            ? _flow.addCard
                            : null,
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
                          onPressed:
                              _flow.loading || _flow.preparing || _isPaying
                                  ? null
                                  : _flow.refresh,
                          child: const Text('Обновить список'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Amount due, the server's amount notice, the latest payment feedback and the actions
  /// that resolve a locked payment state.
  Widget _summary(AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Сумма к оплате',
            style: AppTypography.body.copyWith(color: palette.textSecondary)),
        const SizedBox(height: AppSpacing.md),
        Text(_getOrderAmount(),
            key: const ValueKey('payment-payable-amount'),
            style: AppTypography.displayBold),
        if (widget.amountNotice case final notice?) ...[
          const SizedBox(height: AppSpacing.xl),
          Semantics(
            liveRegion: true,
            child: AppSurface(
              key: const ValueKey('payment-amount-notice'),
              padding: const EdgeInsets.all(AppSpacing.xl),
              fill: palette.error.withValues(alpha: .12),
              child: Text(notice, style: AppTypography.bodySmall),
            ),
          ),
        ],
        if (_cardFeedback case final feedback?) ...[
          const SizedBox(height: AppSpacing.huge),
          Semantics(
            liveRegion: true,
            child: AppSurface(
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              fill: (feedback.tone == _CardFeedbackTone.error
                      ? palette.error
                      : palette.accent)
                  .withValues(alpha: .12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedPaymentMethod == _PaymentMethodType.kaspi) ...[
                    const KaspiLogo(),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  Text(feedback.message, style: AppTypography.body),
                ],
              ),
            ),
          ),
        ],
        if (_paymentState != OrderPaymentState.ready || _orderClosed) ...[
          const SizedBox(height: AppSpacing.xl),
          if (_paymentState != OrderPaymentState.storageUnavailable ||
              _orderClosed)
            OutlinedButton(
              key: const ValueKey('payment-pending-orders'),
              onPressed: _readingPaymentGuard || _isPaying ? null : _openOrders,
              child: const Text('Проверить мои заказы'),
            ),
          OutlinedButton(
            key: const ValueKey('payment-state-refresh'),
            onPressed:
                _readingPaymentGuard || _isPaying ? null : _readPaymentGuard,
            child: Text(_readingPaymentGuard
                ? 'Проверяем состояние…'
                : 'Проверить состояние оплаты'),
          ),
        ],
      ],
    );
  }

  /// The bar's one action. It is the page's strongest control: a full-width primary (the
  /// official red Kaspi button while Kaspi.kz is chosen) that always sits clear of the list.
  Widget _paymentAction(bool cannotPay) {
    if (_kaspiPaymentLink != null && _paymentUnconfirmed && !_orderClosed) {
      return _dockButton(
        key: const ValueKey('reopen-kaspi-payment'),
        onPressed:
            _isPaying || _readingPaymentGuard ? null : _reopenKaspiPayment,
        label: 'Открыть оплату',
      );
    }
    if (_selectedPaymentMethod != _PaymentMethodType.kaspi) {
      final amount = _chargedAmount();
      return _dockButton(
        key: const ValueKey('pay-order-button'),
        onPressed: cannotPay ? null : _pay,
        label: _isPaying
            ? 'Проводим оплату…'
            : amount == null
                ? 'Оплатить'
                : 'Оплатить $amount',
      );
    }
    if (_paymentState != OrderPaymentState.ready ||
        _readingPaymentGuard ||
        _orderClosed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Text(
          _orderClosed
              ? 'Заказ закрыт'
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

  Widget _dockButton({
    required Key key,
    required VoidCallback? onPressed,
    required String label,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: FilledButton(
          key: key,
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      );

  /// Kaspi.kz in the same row anatomy as a saved card. The rules ask for the full logo
  /// wherever it fits at 112 dp or more, Gold right after it, and the alignment of the
  /// other methods: the logo starts where a card's glyph starts. A row keeps at least 220
  /// dp for them even at 320 dp wide, so the compact mark is never needed; the Wrap only
  /// moves Gold under the logo if a very narrow window ever forces it.
  Widget _kaspiTile(bool busy) => PaymentMethodTile(
        inkKey: const ValueKey('payment-kaspi'),
        selected: _selectedPaymentMethod == _PaymentMethodType.kaspi,
        onTap: busy
            ? null
            : () => setState(() {
                  _selectedPaymentMethod = _PaymentMethodType.kaspi;
                  _selectedCardId = null;
                }),
        title: const Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            KaspiLogo(clearSpace: false),
            KaspiGoldBadge(clearSpace: false),
          ],
        ),
        subtitle: 'Оплата в приложении Kaspi.kz',
      );
}

enum _PaymentMethodType { card, kaspi }

enum _CardFeedbackTone { error, info }

class _CardFeedback {
  final String message;
  final _CardFeedbackTone tone;

  const _CardFeedback({required this.message, required this.tone});
}
