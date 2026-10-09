import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/money.dart';
import '../../../design/theme.dart';
import '../../../ui/app_states.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_top_bar.dart';
import '../../../utils/api.dart';
import '../../../utils/bonus_rules.dart';
import '../../../utils/cart_provider.dart';
import '../../../utils/order_ui_helpers.dart';
import '../../../pages/order_detail_page.dart';
import '../../bonuses/bonus_account.dart';

/// Displays server order history without treating estimates as earned points.
class OrdersPage extends StatefulWidget {
  const OrdersPage({this.businessId, this.onCart, this.onOpenOrder, super.key});

  final int? businessId;
  final VoidCallback? onCart;
  final FutureOr<void> Function(Map<String, dynamic>)? onOpenOrder;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with WidgetsBindingObserver {
  List<Map<String, dynamic>>? _orders;
  BonusAccount? _bonuses;
  bool _loading = false;
  bool _failed = false;
  bool _bonusFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    await Future.wait([_loadOrders(), _loadBonuses()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadBonuses() async {
    setState(() => _bonusFailed = false);
    try {
      final bonuses =
          BonusAccount.fromResponse(await ApiService.getUserBonuses());
      if (mounted) setState(() => _bonuses = bonuses);
    } catch (_) {
      if (mounted) setState(() => _bonusFailed = true);
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _failed = false);
    try {
      final response = await ApiService.getMyOrdersHistory(
        businessId: widget.businessId,
      );
      if (response == null) {
        throw const FormatException('Order history unavailable');
      }
      final data = response['data'];
      List<dynamic>? entries;
      if (data is List) {
        entries = data;
      } else if (data is Map) {
        for (final key in const [
          'orders',
          'history_orders',
          'order_history',
          'completed_orders'
        ]) {
          if (data[key] is List) {
            entries = data[key] as List;
            break;
          }
        }
        if (entries == null) {
          for (final value in data.values) {
            if (value is List && value.every((item) => item is Map)) {
              entries = value;
              break;
            }
          }
        }
      }
      if (entries == null || entries.any((item) => item is! Map)) {
        throw const FormatException('Order history response has no order list');
      }
      final orders = entries.map((item) => asOrderMap(item)!).toList();
      if (!mounted) return;
      setState(() => _orders = orders);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _openOrder(Map<String, dynamic> order) async {
    final open = widget.onOpenOrder;
    if (open != null) {
      await open(order);
      if (mounted) await _load();
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => OrderDetailPage(order: order),
    ));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final count = cart.displayItemCount;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: AppTopBar(
                    title: 'Мои заказы',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _body(),
                  ),
                ),
              ],
            ),
            if (widget.onCart != null) Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
              child: Center(
                child: AppCartButton(
                  itemCount: count,
                  total: count == 0 ? null : cart.getTotalPrice().round(),
                  onTap: widget.onCart,
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

  Widget _body() {
    final orders = _orders;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (_loading)
          const SliverToBoxAdapter(child: LinearProgressIndicator()),
        if (_failed)
          SliverToBoxAdapter(
            child: AppErrorState(
              message: orders == null
                  ? 'Не удалось загрузить заказы'
                  : 'Не удалось обновить заказы. Показаны ранее полученные данные.',
              onRetry: _load,
              topOffset: 24,
            ),
          ),
        if (_bonusFailed && orders != null && orders.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Не удалось обновить бонусные операции'),
              ),
            ),
          ),
        if (orders != null && orders.isEmpty)
          const SliverToBoxAdapter(
            child: AppEmptyState(
              title: 'Заказов пока нет',
              subtitle:
                  'Когда появятся активные или завершённые заказы, они будут отображаться здесь',
              topOffset: 218,
            ),
          ),
        if (orders != null)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final order = orders[index];
                  final orderId = '${order['order_id'] ?? ''}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _OrderCard(
                      order: order,
                      operations: _bonuses?.entriesForOrder(orderId) ?? const [],
                      onTap: () => _openOrder(order),
                    ),
                  );
                },
                childCount: orders.length,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppCartButton.clearanceFor(context) +
                MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}

/// One history card: 343 × 114, r10.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.operations,
    this.onTap,
  });

  final Map<String, dynamic> order;
  final Iterable<BonusLedgerEntry> operations;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canceled = isOrderCanceled(order);
    final statusText = resolveOrderStatusText(order);
    final total = resolveOrderTotalAmount(order);
    final estimate = _pendingBonusEstimate(order);
    final timestamp = _timestamp(order);
    final scaled = MediaQuery.textScalerOf(context).scale(16) > 20;
    final date = Text(
      _humanDate(timestamp),
      maxLines: scaled ? null : 1,
      overflow: scaled ? null : TextOverflow.ellipsis,
      style: AppTypography.title.copyWith(color: palette.textPrimary),
    );
    final status = Text(
      statusText,
      style: AppTypography.base(size: 12, weight: 400).copyWith(
        color: canceled
            ? palette.error
            : asOrderMap(order['current_status'])?['status']?.toString() == '4'
                ? palette.success
                : palette.textSecondary,
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.lgAll,
      child: Container(
        constraints: const BoxConstraints(minHeight: 114),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (scaled)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [date, const SizedBox(height: 4), status],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: date), Flexible(child: status)],
              ),
            Text(
              '№${order['order_id'] ?? '—'}',
              style: AppTypography.base(size: 12, weight: 400)
                  .copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: AppSpacing.huge,
              runSpacing: 12,
              children: [
                _Summary(
                  label: 'Сумма',
                  value: total == null ? '—' : formatTenge(total),
                  valueColor: palette.textPrimary,
                ),
                if (operations.isNotEmpty)
                  _Summary(
                    label: 'Бонусные операции',
                    value: operations
                        .map((entry) => signedBonusLabel(entry.amount))
                        .join(' · '),
                    valueColor: palette.gold,
                  )
                else if (estimate != null)
                  _Summary(
                    label: 'Оценка · ещё не начислено',
                    value: '≈${signedBonusLabel(estimate)}',
                    valueColor: palette.gold,
                  )
                else
                  _Summary(
                    label: 'Бонусы',
                    value: 'Подтверждённые операции не переданы',
                    valueColor: palette.textSecondary,
                  ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _humanDate(DateTime? date) {
    if (date == null) return 'Дата неизвестна';
    return '${DateFormat('d MMMM', 'ru').format(date)} в '
        '${DateFormat('HH:mm').format(date)}';
  }

  DateTime? _timestamp(Map<String, dynamic> order) {
    final raw =
        order['log_timestamp']?.toString() ?? order['created_at']?.toString();
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  int? _pendingBonusEstimate(Map<String, dynamic> order) {
    if (isOrderClosed(order)) return null;
    final status = asOrderMap(order['current_status']) ??
        asOrderMap(order['status']);
    if (!const {'1', '11', '12', '2', '21', '3', '31'}
        .contains(status?['status']?.toString())) {
      return null;
    }
    final items = order['items'];
    if (items is! List || items.isEmpty) return null;
    var eligible = 0.0;
    for (final entry in items) {
      final map = asOrderMap(entry);
      if (map == null) return null;
      final snapshot = asOrderMap(map['item_data']);
      if (BonusRules.isBonusExcludedText(
        name: (map['name'] ?? map['item_name'] ?? snapshot?['name'])?.toString() ??
            '',
        description:
            (map['description'] ?? snapshot?['description'])?.toString(),
        code: (map['code'] ?? snapshot?['code'])?.toString(),
        categoryName: asOrderMap(map['category'] ?? snapshot?['category'])?['name']
            ?.toString(),
      )) {
        continue;
      }
      final raw = map['total_cost'];
      final total = raw is num ? raw : num.tryParse('$raw');
      if (total == null || !total.isFinite || total < 0) return null;
      eligible += total.toDouble();
    }
    final points = BonusRules.calculateEarnedBonuses(eligible);
    return points > 0 ? points : null;
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.base(size: 12, weight: 400)
              .copyWith(color: palette.textSecondary, height: 1.3),
        ),
        Text(
          value,
          style: AppTypography.base(size: 12, weight: 400)
              .copyWith(color: valueColor, height: 1.3),
        ),
      ],
    );
  }
}
