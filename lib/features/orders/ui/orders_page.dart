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

/// Order history — the design's `История заказов` frames.
///
/// Geometry: the standard top bar, then 343 × 114 cards from y = 143 at a 118 px pitch. Each card
/// carries the date 16/700, «№N» 12/400 muted beneath it, a two-part summary («Сумма» over the
/// amount, «Начислено» over the bonus in gold) and the status 12/400 in the top-right corner.
/// The empty state is centred text at y = 369.
///
/// Status text comes from the app's frozen `orderStatusLabels`; its wording differs from the
/// design's mock in places («Собирается» rather than «Собираем (15-30 мин)»), and the app's copy
/// is the real one, so it wins — recorded in `docs/redesign/STATUS.md`.
class OrdersPage extends StatefulWidget {
  const OrdersPage({this.businessId, this.onCart, this.onOpenOrder, super.key});

  final int? businessId;
  final VoidCallback? onCart;
  final ValueChanged<Map<String, dynamic>>? onOpenOrder;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Map<String, dynamic>>? _orders;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _orders = null;
    });
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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final count = cart.displayItemCount;
    return Scaffold(
      body: SafeArea(
        bottom: false,
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
                Expanded(child: _body()),
              ],
            ),
            Positioned(
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
    );
  }

  Widget _body() {
    if (_failed) {
      return AppErrorState(
        message: 'Не удалось загрузить заказы',
        onRetry: _load,
      );
    }
    final orders = _orders;
    if (orders == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (orders.isEmpty) {
      return const AppEmptyState(
        title: 'Заказов пока нет',
        subtitle:
            'Когда появятся активные или завершённые заказы, они будут отображаться здесь',
        topOffset: 218,
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        0,
        AppSpacing.xxxl,
        AppCartButton.clearanceFor(context) + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) => _OrderCard(
        order: orders[index],
        onTap: widget.onOpenOrder == null
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrderDetailPage(order: orders[index]),
                  ),
                )
            : () => widget.onOpenOrder!(orders[index]),
      ),
    );
  }
}

/// One history card: 343 × 114, r10.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, this.onTap});

  final Map<String, dynamic> order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canceled = isOrderCanceled(order);
    final statusText = resolveOrderStatusText(order);
    final total = resolveOrderTotalAmount(order);
    final bonus = _bonusPoints(order);
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
        color: canceled ? palette.error : palette.textSecondary,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: scaled ? null : 114,
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
            if (scaled) const SizedBox(height: 12) else const Spacer(),
            Wrap(
              spacing: AppSpacing.huge,
              runSpacing: 12,
              children: [
                _Summary(
                  label: 'Сумма',
                  value: total == null ? '—' : formatTenge(total.round()),
                  valueColor: palette.textPrimary,
                ),
                if (bonus != null)
                  _Summary(
                    label: 'Начислено',
                    value: '+$bonus бонусов',
                    valueColor: palette.gold,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The design's humanised date («10 июля в 23:00») rather than the legacy `dd.MM.yyyy, HH:mm`.
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

  /// «Начислено» — the order payload carries **no** earned-bonus field (`cost_summary` has
  /// `bonus_used`, not `bonus_points`), so it is computed from the order's items with the same
  /// frozen rule the cart uses: 3 % of eligible lines, tobacco excluded. Returns null when the
  /// order earns nothing, which hides the line exactly as the design omits it elsewhere.
  int? _bonusPoints(Map<String, dynamic> order) {
    final items = order['items'];
    if (items is! List) return null;
    var eligible = 0.0;
    for (final entry in items) {
      final map = asOrderMap(entry);
      if (map == null) continue;
      if (BonusRules.isBonusExcludedText(
        name: map['name']?.toString() ?? '',
        description: map['description']?.toString(),
        code: map['code']?.toString(),
      )) {
        continue;
      }
      final total = map['total_cost'];
      if (total is num) eligible += total.toDouble();
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
