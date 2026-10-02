import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/money.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../services/repeat_order_service.dart';
import '../ui/app_states.dart';
import '../ui/app_top_bar.dart';
import '../utils/api.dart';
import '../utils/business_provider.dart';
import '../utils/cart_provider.dart';
import '../utils/order_ui_helpers.dart' as order_ui;
import '../utils/order_payment_guard.dart';
import 'checkout_page.dart';
import '../features/faq/models/faq.dart';
import '../features/faq/faq_navigation.dart';
import 'help_chat_page.dart';
import 'payment_method_page.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.order, this.onSupport});

  final Map<String, dynamic> order;
  final ValueChanged<Map<String, dynamic>>? onSupport;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  _OrderDetails? _details;
  bool _loading = false;
  bool _repeating = false;
  bool _openingPayment = false;
  String? _notice;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void didUpdateWidget(covariant OrderDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order != widget.order) {
      _details = null;
      _loadOrder();
    }
  }

  Future<void> _loadOrder() async {
    final generation = ++_loadGeneration;
    final base = widget.order;
    final orderId = int.tryParse(base['order_id']?.toString() ?? '');
    setState(() {
      _loading = true;
      _notice = null;
    });

    Map<String, dynamic>? loaded;
    if (orderId != null) {
      try {
        loaded = await ApiService.getOrderDetails(orderId);
      } catch (_) {
        // The frozen API normally returns null on failure; injected transports can throw.
      }
    }
    final known = _details?.order ?? base;
    final merged = _mergeOrder(known, loaded);
    final paymentId = paymentOrderId(merged);
    if (paymentId != null) {
      merged[OrderPaymentGuard.localStateKey] =
          (await OrderPaymentGuard.read(paymentId)).name;
    }
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _details = _OrderDetails(merged);
      _loading = false;
      if (orderId == null) {
        _notice = 'Подробности недоступны: номер заказа не передан.';
      } else if (loaded == null || loaded.isEmpty) {
        _notice =
            'Не удалось обновить заказ. Показаны ранее полученные данные.';
      }
    });
  }

  Future<void> _repeatOrder() async {
    if (_repeating ||
        _openingPayment ||
        _loading ||
        _details == null ||
        _paymentUnresolved(_details!.order)) {
      return;
    }
    setState(() => _repeating = true);
    try {
      final source = _details!.order;
      if (!await _confirmReplaceCart(source) || !mounted) return;
      final result = await RepeatOrderService.repeatOrderIntoCart(
        sourceOrder: source,
        cartProvider: context.read<CartProvider>(),
        businessProvider: context.read<BusinessProvider>(),
      );
      if (!mounted) return;
      if (result.hasSkippedItems) {
        await _showMessage(
          'Часть позиций пропущена',
          'Не удалось восстановить: ${result.skippedItems.join(', ')}. '
              'Проверьте состав и актуальные цены перед оформлением.',
        );
      }
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CheckoutPage(
          initialDeliveryType: result.deliveryType,
          initialAddress: result.restoredAddress,
        ),
      ));
    } on RepeatOrderException catch (error) {
      if (mounted) {
        await _showMessage('Не удалось повторить заказ', error.message);
      }
    } catch (_) {
      if (mounted) {
        await _showMessage(
          'Не удалось повторить заказ',
          'Попробуйте ещё раз чуть позже.',
        );
      }
    } finally {
      if (mounted) setState(() => _repeating = false);
    }
  }

  Future<bool> _confirmReplaceCart(Map<String, dynamic> order) async {
    if (!context.read<CartProvider>().hasActiveItems) return true;
    final current = context.read<BusinessProvider>().selectedBusiness;
    final target = RepeatOrderService.resolveBusiness(order);
    final currentId =
        current?['id'] ?? current?['business_id'] ?? current?['businessId'];
    final targetId =
        target?['id'] ?? target?['business_id'] ?? target?['businessId'];
    final changesStore =
        targetId != null && currentId?.toString() != targetId.toString();
    final storeName = _text(target?['name']) ?? 'магазин этого заказа';
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Заменить корзину?'),
            content: Text(changesStore
                ? 'Товары в текущей корзине будут заменены, а магазин сменится на $storeName.'
                : 'Товары в текущей корзине будут заменены товарами из этого заказа.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Заменить'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openPayment() async {
    final details = _details;
    if (details == null ||
        _loading ||
        _repeating ||
        _openingPayment ||
        !order_ui.canPayOrder(details.order)) {
      return;
    }
    setState(() => _openingPayment = true);
    try {
      final amount =
          order_ui.resolveOrderTotalAmount(details.order)?.toDouble();
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PaymentMethodPage(
          orderData: {
            ...details.order,
            if (amount != null) 'payable_amount': amount,
          },
          displayAmount: amount,
        ),
      ));
      if (mounted) await _loadOrder();
    } catch (_) {
      if (mounted) {
        await _showMessage(
            'Не удалось открыть оплату', 'Попробуйте ещё раз чуть позже.');
      }
    } finally {
      if (mounted) setState(() => _openingPayment = false);
    }
  }

  Future<void> _showMessage(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  void _openSupport(_OrderDetails details) {
    if (widget.onSupport != null) {
      widget.onSupport!(details.order);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => HelpChatPage(
        order: details.order,
        entryPoint: 'order_detail',
        initialTopic:
            details.paymentIssue ? 'Ошибка оплаты' : 'Заказ №${details.id}',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final id = details?.id ?? _text(widget.order['order_id']) ?? '—';
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: AppTopBar(
                    title: 'Заказ №$id',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Expanded(
                  child: details == null
                      ? const AppLoading()
                      : _orderBody(details),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: details == null || details.order.isEmpty
          ? null
          : _actionPanel(details),
    );
  }

  Widget _orderBody(_OrderDetails details) {
    if (details.order.isEmpty) {
      return AppErrorState(
        message: 'Не удалось загрузить заказ',
        onRetry: _loading ? null : _loadOrder,
      );
    }
    return CustomScrollView(
      slivers: [
        if (_loading)
          const SliverToBoxAdapter(child: LinearProgressIndicator()),
        if (_notice != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _noticeCard(),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: _identityFields(details),
          ),
        ),
        if (details.items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _muted('Состав заказа не передан'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _OrderItemRow(item: details.items[index]),
                ),
                childCount: details.items.length,
              ),
            ),
          ),
        if (details.isPreview)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _muted(
                  'Полный состав не передан. Показаны доступные товары.'),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _costSection(details),
                const SizedBox(height: 24),
                _informationSection(details),
                const SizedBox(height: 24),
                _sectionTitle('История статусов'),
                if (details.history.isEmpty)
                  _muted('История статусов не передана'),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _historyRow(details.history[index]),
              childCount: details.history.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: _supportSection(details),
          ),
        ),
      ],
    );
  }

  Widget _noticeCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: AppRadii.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_notice!,
              style: AppTypography.body
                  .copyWith(color: context.palette.textPrimary)),
          if (int.tryParse(widget.order['order_id']?.toString() ?? '') != null)
            TextButton.icon(
              onPressed: _loading ? null : _loadOrder,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Обновить заказ'),
            ),
        ],
      ),
    );
  }

  Widget _identityFields(_OrderDetails details) {
    final status = Text(
      order_ui.resolveOrderStatusText(details.order),
      style: AppTypography.bodySmall.copyWith(
        color: order_ui.isOrderCanceled(details.order)
            ? context.palette.error
            : details.statusCode == '4'
                ? context.palette.success
                : context.palette.textSecondary,
      ),
    );
    final phone =
        _OrderField(label: 'Телефон', value: details.phone ?? 'Не передан');
    final address = details.address;
    final extras = [
      if (_text(address?['entrance']) case final value?) 'Подъезд $value',
      if (_text(address?['floor']) case final value?) 'Этаж $value',
      if (_text(address?['apartment']) case final value?) 'Кв. $value',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(16) > 21) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [status, const SizedBox(height: 8), phone],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: phone),
              const SizedBox(width: 12),
              Flexible(flex: 2, child: status),
            ],
          );
        }),
        const SizedBox(height: 16),
        _OrderField(
            label: 'Способ оплаты',
            value: details.paymentMethod ?? 'Не передан'),
        const SizedBox(height: 16),
        _OrderField(
          label: details.pickup ? 'Самовывоз' : 'Адрес доставки',
          value: details.pickup
              ? _text(details.business?['address']) ??
                  'Адрес магазина не передан'
              : _text(address?['address']) ?? 'Адрес не передан',
        ),
        if (extras.isNotEmpty) ...[
          const SizedBox(height: 4),
          _muted(extras.join(' · ')),
        ],
        if (_text(address?['comment'] ?? address?['other'])
            case final comment?) ...[
          const SizedBox(height: 8),
          _muted(comment),
        ],
      ],
    );
  }

  Widget _costSection(_OrderDetails details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Стоимость заказа'),
        if (details.itemsTotal != null)
          _CostRow(label: 'Товары', amount: details.itemsTotal!),
        if (details.deliveryFee != null)
          _CostRow(label: 'Доставка', amount: details.deliveryFee!),
        if (details.serviceFee != null)
          _CostRow(label: 'Сервисный сбор', amount: details.serviceFee!),
        if (details.discount != null)
          _CostRow(
              label: 'Скидка', amount: -details.discount!, deduction: true),
        if (details.bonusUsed != null)
          _CostRow(
              label: 'Оплачено бонусами',
              amount: -details.bonusUsed!,
              deduction: true),
        const Divider(height: 16),
        if (details.total != null)
          _CostRow(label: 'Итого', amount: details.total!, total: true)
        else
          _muted('Итоговая сумма не передана'),
      ],
    );
  }

  Widget _informationSection(_OrderDetails details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Информация о заказе'),
        _OrderField(
            label: 'Получение',
            value: order_ui.resolveDeliveryTypeText(details.order)),
        if (details.business != null) ...[
          const SizedBox(height: 12),
          _OrderField(
              label: 'Магазин',
              value:
                  _text(details.business?['name']) ?? 'Название не передано'),
          if (!details.pickup) ...[
            if (_text(details.business?['address']) case final address?)
              _muted(address),
          ],
          if (_text(details.business?['phone']) case final phone?)
            _muted(phone),
        ],
        if (details.createdAt != null) ...[
          const SizedBox(height: 12),
          _OrderField(
              label: 'Создан', value: _formatTimestamp(details.createdAt!)),
        ],
        if (_text(details.order['delivery_time']) case final time?) ...[
          const SizedBox(height: 12),
          _OrderField(label: 'Время доставки', value: time),
        ],
        if (_text(order_ui.asOrderMap(details.order['user'])?['name'])
            case final name?) ...[
          const SizedBox(height: 12),
          _OrderField(label: 'Получатель', value: name),
        ],
        TextButton.icon(
          onPressed: _loading ? null : _loadOrder,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(_loading ? 'Обновляем заказ…' : 'Обновить заказ'),
        ),
      ],
    );
  }

  Widget _historyRow(Map<String, dynamic> status) {
    final label = order_ui.resolveStatusLabel(status);
    final description = _text(status['description']);
    final timestamp = _text(status['timestamp']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 8, color: context.palette.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.bodyBold
                        .copyWith(color: context.palette.textPrimary)),
                if (description != null &&
                    description.toLowerCase() != label.toLowerCase() &&
                    !description.toLowerCase().contains('unknown') &&
                    description.toLowerCase() != 'неизвестный статус')
                  _muted(description),
                _muted(timestamp == null
                    ? 'Время не передано'
                    : _formatTimestamp(timestamp)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _supportSection(_OrderDetails details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(details.paymentIssue
            ? 'Проблема с оплатой?'
            : 'Нужна помощь с заказом?'),
        _muted('Обратитесь в поддержку или найдите ответ в частых вопросах.'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _openSupport(details),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
          label:
              const Text('Открыть чат поддержки', textAlign: TextAlign.center),
        ),
        TextButton(
          onPressed: () => openFaqPage(
            context,
            initialSection: details.paymentIssue
                ? FaqSection.payment
                : FaqSection.orderProblems,
          ),
          child: const Text('Ответы по заказу', textAlign: TextAlign.center),
        ),
      ],
    );
  }

  bool _paymentUnresolved(Map<String, dynamic> order) {
    final local = order[OrderPaymentGuard.localStateKey];
    if (local == OrderPaymentState.completed.name) return false;
    return local == OrderPaymentState.unconfirmed.name ||
        local == OrderPaymentState.storageUnavailable.name ||
        orderPaymentOutcome(order) == OrderPaymentOutcome.pending;
  }

  Widget _actionPanel(_OrderDetails details) {
    final pending = _loading || _repeating || _openingPayment;
    late final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!details.pickup) ...[
          _muted('Доставка'),
          Text(
            details.deliveryFee == null
                ? 'Не указана'
                : formatTenge(details.deliveryFee!.round()),
            style: AppTypography.titleRegular
                .copyWith(color: context.palette.textPrimary),
          ),
          const SizedBox(height: 8),
        ],
        _muted('Итого'),
        Text(
          details.total == null
              ? 'Не передано'
              : formatTenge(details.total!.round()),
          style: AppTypography.displayBold
              .copyWith(color: context.palette.textPrimary),
        ),
      ],
    );
    late final repeat = FilledButton.icon(
      key: const ValueKey('order-detail-repeat-button'),
      onPressed: pending ? null : _repeatOrder,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 70),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      icon: _repeating
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: context.palette.textOnAccent),
            )
          : const Icon(Icons.repeat_rounded, size: 26),
      label: Text(_repeating ? 'Собираем корзину…' : 'Повторить заказ',
          textAlign: TextAlign.center),
    );
    return Container(
      decoration: BoxDecoration(
        color: context.palette.background,
        border: Border(top: BorderSide(color: context.palette.divider)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_paymentUnresolved(details.order)) ...[
                    _muted('Не удалось подтвердить состояние оплаты. '
                        'Обновите заказ прежде чем оплачивать или повторять его.'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('order-detail-check-payment'),
                      onPressed: pending ? null : _loadOrder,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Проверить состояние оплаты'),
                    ),
                  ] else ...[
                    if (order_ui.canPayOrder(details.order)) ...[
                      FilledButton.icon(
                        key: const ValueKey('order-detail-pay-button'),
                        onPressed: pending ? null : _openPayment,
                        icon: const Icon(Icons.lock_outline_rounded, size: 20),
                        label: Text(
                            _openingPayment
                                ? 'Открываем оплату…'
                                : 'Оплатить заказ',
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 12),
                    ],
                    LayoutBuilder(builder: (context, constraints) {
                      if (constraints.maxWidth < 310 ||
                          MediaQuery.textScalerOf(context).scale(16) > 21) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            summary,
                            const SizedBox(height: 12),
                            repeat
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: summary),
                          const SizedBox(width: 16),
                          SizedBox(width: 177, child: repeat),
                        ],
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: AppTypography.title
                .copyWith(color: context.palette.textPrimary)),
      );

  Widget _muted(String text) => Text(
        text,
        style: AppTypography.bodySmall
            .copyWith(color: context.palette.textSecondary),
      );
}

class _OrderField extends StatelessWidget {
  const _OrderField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.label
                  .copyWith(color: context.palette.textSecondary)),
          Text(value,
              style: AppTypography.title
                  .copyWith(color: context.palette.textPrimary)),
        ],
      );
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final image = _text(item['img'] ?? item['item_img']);
    final quantity = _number(item['amount']);
    final total = _lineTotal(item);
    final name =
        _text(item['name'] ?? item['item_name']) ?? 'Название не передано';
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: context.palette.surface, borderRadius: AppRadii.lgAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: AppRadii.smAll,
            child: SizedBox(
              width: 52,
              height: 52,
              child: image == null
                  ? _imageFallback(context)
                  : Image.network(
                      image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _imageFallback(context),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTypography.titleMedium
                        .copyWith(color: context.palette.textPrimary)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Цена',
                              style: AppTypography.label.copyWith(
                                  color: context.palette.textSecondary)),
                          Text(
                              total == null
                                  ? 'Не передана'
                                  : formatTenge(total.round()),
                              style: AppTypography.title.copyWith(
                                  color: context.palette.textPrimary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Кол-во',
                            style: AppTypography.label.copyWith(
                                color: context.palette.textSecondary)),
                        Text(quantity == null ? '—' : _quantityText(quantity),
                            style: AppTypography.titleMedium
                                .copyWith(color: context.palette.textPrimary)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _imageFallback(BuildContext context) => ColoredBox(
        color: context.palette.surfaceMuted,
        child: Icon(Icons.inventory_2_outlined,
            color: context.palette.textSecondary, size: 24),
      );
}

class _CostRow extends StatelessWidget {
  const _CostRow(
      {required this.label,
      required this.amount,
      this.deduction = false,
      this.total = false});

  final String label;
  final num amount;
  final bool deduction;
  final bool total;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: Text(label,
                    style: total ? AppTypography.title : AppTypography.body)),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                formatTenge(amount.round()),
                textAlign: TextAlign.right,
                style:
                    (total ? AppTypography.title : AppTypography.body).copyWith(
                  color: deduction
                      ? context.palette.gold
                      : context.palette.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
}

class _OrderDetails {
  _OrderDetails(this.order) {
    final summary = order_ui.asOrderMap(order['items_summary']);
    var fullItems = order['items'];
    if (fullItems is! List || fullItems.isEmpty) fullItems = summary?['items'];
    final preview = summary?['items_preview'];
    isPreview = (fullItems is! List || fullItems.isEmpty) &&
        preview is List &&
        preview.isNotEmpty;
    items = _maps(isPreview ? preview : fullItems);
    final cost = {
      ...?order_ui.asOrderMap(order['cost']),
      ...?order_ui.asOrderMap(order['cost_summary']),
    };
    var subtotal = _number(cost['items_total']);
    if (subtotal == null && !isPreview && items.isNotEmpty) {
      num sum = 0;
      var complete = true;
      for (final item in items) {
        final amount = _lineTotal(item);
        if (amount == null) {
          complete = false;
          break;
        }
        sum += amount;
      }
      if (complete) subtotal = sum;
    }
    itemsTotal = subtotal;
    deliveryFee = _number(cost['delivery_fee'] ??
        cost['delivery_price'] ??
        order['delivery_price']);
    serviceFee = _positive(cost['service_fee']);
    discount = _positive(cost['discount']);
    bonusUsed =
        _positive(cost['bonus_used'] ?? order['bonus_used'] ?? order['bonus']);
    total = order_ui.resolveOrderTotalAmount(order) ?? _number(order['total']);
    history = _statusHistory(order);
  }

  final Map<String, dynamic> order;
  late final List<Map<String, dynamic>> items;
  late final bool isPreview;
  late final List<Map<String, dynamic>> history;
  late final num? itemsTotal;
  late final num? deliveryFee;
  late final num? serviceFee;
  late final num? discount;
  late final num? bonusUsed;
  late final num? total;

  String get id =>
      _text(order['order_id'] ?? order['order_uuid'] ?? order['id']) ?? '—';
  Map<String, dynamic>? get address =>
      order_ui.asOrderMap(order['delivery_address']);
  Map<String, dynamic>? get business => order_ui.asOrderMap(order['business']);
  String? get phone => _text(order_ui.asOrderMap(order['user'])?['phone']);
  String? get paymentMethod => _text(order['payment_method']);
  String? get createdAt => _text(order['created_at'] ?? order['log_timestamp']);
  bool get pickup => order_ui.isPickupOrder(order);
  String? get statusCode =>
      _text((order_ui.asOrderMap(order['current_status']) ??
          order_ui.asOrderMap(order['status']))?['status']);
  bool get paymentIssue =>
      const {'6', '60', '61', '66'}.contains(statusCode) ||
      order_ui.canPayOrder(order);
}

String? _text(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
}

num? _number(dynamic value) {
  final number = value is num ? value : num.tryParse(value?.toString() ?? '');
  return number != null && number.isFinite ? number : null;
}

num? _positive(dynamic value) {
  final number = _number(value);
  return number != null && number > 0 ? number : null;
}

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.map(order_ui.asOrderMap).whereType<Map<String, dynamic>>().toList()
    : const [];

num? _lineTotal(Map<String, dynamic> item) {
  final explicit = _number(item['total_cost'] ?? item['total'] ?? item['sum']);
  if (explicit != null) return explicit;
  final quantity = _number(item['amount']);
  final price = _number(item['price']);
  return quantity != null && price != null ? quantity * price : null;
}

String _quantityText(num quantity) =>
    quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toString();

String _formatTimestamp(String raw) {
  final timestamp = DateTime.tryParse(raw);
  return timestamp == null
      ? raw
      : DateFormat('dd.MM.yyyy, HH:mm').format(timestamp.toLocal());
}

Map<String, dynamic> _mergeOrder(
    Map<String, dynamic> base, Map<String, dynamic>? loaded) {
  if (loaded == null) return base;
  final merged = <String, dynamic>{...base};
  for (final entry in loaded.entries) {
    final oldMap = order_ui.asOrderMap(merged[entry.key]);
    final newMap = order_ui.asOrderMap(entry.value);
    merged[entry.key] =
        oldMap != null && newMap != null ? {...oldMap, ...newMap} : entry.value;
  }
  return merged;
}

List<Map<String, dynamic>> _statusHistory(Map<String, dynamic> order) {
  final entries =
      <({Map<String, dynamic> status, DateTime? time, int index})>[];
  final seen = <String>{};
  for (final source in [order['order_statuses'], order['status_history']]) {
    if (source is! List) continue;
    for (final value in source) {
      final status = order_ui.asOrderMap(value);
      if (status == null) continue;
      final code = status['status'] ?? status['status_id'] ?? status['code'];
      final timestamp = _text(status['timestamp'] ??
          status['log_timestamp'] ??
          status['created_at']);
      final normalized = <String, dynamic>{
        ...status,
        'status': code,
        'timestamp': timestamp
      };
      final label = order_ui.resolveStatusLabel(normalized);
      final key = '$code|$label|$timestamp|${status['description']}';
      if (!seen.add(key)) continue;
      entries.add((
        status: normalized,
        time: DateTime.tryParse(timestamp ?? ''),
        index: entries.length,
      ));
    }
  }
  entries.sort((left, right) {
    final leftTime = left.time;
    final rightTime = right.time;
    if (leftTime != null && rightTime != null) {
      final comparison = rightTime.compareTo(leftTime);
      if (comparison != 0) return comparison;
    } else if (leftTime != null) {
      return -1;
    } else if (rightTime != null) {
      return 1;
    }
    return left.index.compareTo(right.index);
  });
  return entries.map((entry) => entry.status).toList();
}
