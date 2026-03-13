import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../shared/app_theme.dart';
import '../utils/api.dart';
import 'order_detail_page.dart';

class OrdersHistoryPage extends StatefulWidget {
  final List<Map<String, dynamic>>? initialActiveOrders;
  final List<Map<String, dynamic>>? initialHistoryOrders;

  const OrdersHistoryPage({
    super.key,
    this.initialActiveOrders,
    this.initialHistoryOrders,
  });

  @override
  State<OrdersHistoryPage> createState() => _OrdersHistoryPageState();
}

class _OrdersHistoryPageState extends State<OrdersHistoryPage> {
  List<Map<String, dynamic>> _activeOrders = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _historyOrders = <Map<String, dynamic>>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreHistory = true;
  int _historyPage = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _historyPage = 1;
      _hasMoreHistory = true;
    });

    try {
      final activeFuture = widget.initialActiveOrders != null
          ? Future<List<Map<String, dynamic>>>.value(widget.initialActiveOrders!)
          : ApiService.getMyActiveOrdersList();
      final historyFuture = widget.initialHistoryOrders != null
          ? Future<List<Map<String, dynamic>>>.value(widget.initialHistoryOrders!)
          : ApiService.getMyOrdersHistoryList(page: 1);

      final results = await Future.wait<List<Map<String, dynamic>>>([
        activeFuture,
        historyFuture,
      ]);

      if (!mounted) return;

      final activeOrders = _dedupeOrders(results[0]);
      final historyOrders = _dedupeOrders(results[1], exclude: activeOrders);

      setState(() {
        _activeOrders = activeOrders;
        _historyOrders = historyOrders;
        _hasMoreHistory = historyOrders.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить заказы: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadingMore || !_hasMoreHistory) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _historyPage + 1;
      final pageOrders = await ApiService.getMyOrdersHistoryList(page: nextPage);
      if (!mounted) return;

      if (pageOrders.isEmpty) {
        setState(() {
          _hasMoreHistory = false;
          _isLoadingMore = false;
        });
        return;
      }

      final merged = _dedupeOrders(
        [..._historyOrders, ...pageOrders],
        exclude: _activeOrders,
      );

      setState(() {
        _historyPage = nextPage;
        _historyOrders = merged;
        _hasMoreHistory = pageOrders.isNotEmpty;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  List<Map<String, dynamic>> _dedupeOrders(
    List<Map<String, dynamic>> source, {
    List<Map<String, dynamic>> exclude = const <Map<String, dynamic>>[],
  }) {
    final seen = <String>{
      ...exclude.map(_orderIdentity).where((value) => value.isNotEmpty),
    };
    final result = <Map<String, dynamic>>[];

    for (final order in source) {
      final id = _orderIdentity(order);
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      result.add(order);
    }

    result.sort((a, b) => _orderTimestamp(b).compareTo(_orderTimestamp(a)));
    return result;
  }

  String _orderIdentity(Map<String, dynamic> order) {
    return order['order_uuid']?.toString() ?? order['order_id']?.toString() ?? '';
  }

  DateTime _orderTimestamp(Map<String, dynamic> order) {
    final raw = order['log_timestamp']?.toString() ?? order['created_at']?.toString();
    if (raw == null || raw.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(raw)?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Мои заказы', style: TextStyle(fontWeight: FontWeight.w800)),
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: RefreshIndicator(
              color: AppColors.orange,
              onRefresh: _loadOrders,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.orange),
        ),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.receipt_long_outlined, color: AppColors.textMute, size: 54),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Center(
            child: ElevatedButton(
              onPressed: _loadOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.black,
              ),
              child: const Text('Повторить'),
            ),
          ),
        ],
      );
    }

    if (_activeOrders.isEmpty && _historyOrders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Icon(Icons.shopping_bag_outlined, color: AppColors.textMute, size: 54),
          SizedBox(height: 16),
          Text(
            'Заказов пока нет',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Когда появятся активные или завершённые заказы, они будут отображаться здесь.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMute),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (_activeOrders.isNotEmpty) ...[
          _sectionTitle('Активные заказы', '${_activeOrders.length}'),
          const SizedBox(height: 10),
          ..._activeOrders.map((order) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OrderPreviewCard(order: order),
              )),
          const SizedBox(height: 14),
        ],
        _sectionTitle('История заказов', '${_historyOrders.length}'),
        const SizedBox(height: 10),
        if (_historyOrders.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppDecorations.card(radius: 18),
            child: const Text(
              'История пока пуста или ещё не доступна от сервера.',
              style: TextStyle(color: AppColors.textMute, fontWeight: FontWeight.w700),
            ),
          )
        else
          ..._historyOrders.map((order) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OrderPreviewCard(order: order),
              )),
        if (_historyOrders.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton(
              onPressed: _isLoadingMore || !_hasMoreHistory ? null : _loadMoreHistory,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.orange,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: _isLoadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.orange),
                      ),
                    )
                  : Text(_hasMoreHistory ? 'Показать ещё' : 'Больше заказов нет'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title, String count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: AppDecorations.pill(color: AppColors.blue.withValues(alpha: 0.9)),
          child: Text(
            count,
            style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class OrderPreviewCard extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderPreviewCard({super.key, required this.order});

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  String _formatDate(String? raw) {
    final date = _parseDate(raw);
    if (date == null) return 'Дата неизвестна';
    return DateFormat('dd.MM.yyyy, HH:mm').format(date);
  }

  String _formatMoney(num? value) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(0)} ₸';
  }

  @override
  Widget build(BuildContext context) {
    final business = order['business'] as Map<String, dynamic>?;
    final currentStatus = order['current_status'] as Map<String, dynamic>?;
    final itemsSummary = _resolveItemsSummary(order);
    final costSummary = _resolveCostSummary(order);
    final address = order['delivery_address'] as Map<String, dynamic>?;

    final title = '#${order['order_id'] ?? '—'}';
    final businessName = business?['name']?.toString() ?? 'Магазин не указан';
    final statusText = currentStatus?['status_description']?.toString() ?? 'Статус уточняется';
    final statusColor = _parseStatusColor(currentStatus?['status_color']?.toString());
    final dateText = _formatDate(order['log_timestamp']?.toString() ?? order['created_at']?.toString());
    final itemsCount = (itemsSummary?['items_count'] as num?)?.toInt();
    final totalAmount = (itemsSummary?['total_amount'] as num?)?.toInt();
    final deliveryPrice = costSummary?['delivery_price'] as num?;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderDetailPage(order: order),
          ),
        );
      },
      child: Container(
        decoration: AppDecorations.card(radius: 18),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        businessName,
                        style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: AppDecorations.pill(color: statusColor.withValues(alpha: 0.18)),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metaChip(Icons.schedule, dateText),
                _metaChip(Icons.local_shipping_outlined, order['delivery_type']?.toString() ?? 'Не указан'),
                if (itemsCount != null) _metaChip(Icons.shopping_bag_outlined, '$itemsCount поз.'),
                if (totalAmount != null) _metaChip(Icons.layers_outlined, '$totalAmount шт.'),
                if (deliveryPrice != null) _metaChip(Icons.payments_outlined, 'Доставка ${_formatMoney(deliveryPrice)}'),
              ],
            ),
            if (address != null && (address['address']?.toString().trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, color: AppColors.textMute, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address['address'].toString(),
                      style: const TextStyle(color: AppColors.textMute, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Открыть детали',
                style: TextStyle(color: AppColors.orange.withValues(alpha: 0.95), fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: AppDecorations.pill(color: AppColors.cardDark.withValues(alpha: 0.95)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textMute, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Color _parseStatusColor(String? raw) {
    if (raw == null || raw.isEmpty) return AppColors.orange;
    final normalized = raw.replaceFirst('#', '');
    if (normalized.length != 6) return AppColors.orange;
    final value = int.tryParse('FF$normalized', radix: 16);
    return value == null ? AppColors.orange : Color(value);
  }

  Map<String, dynamic>? _resolveItemsSummary(Map<String, dynamic> order) {
    final summary = order['items_summary'];
    if (summary is Map<String, dynamic>) return summary;

    final items = (order['items'] as List<dynamic>? ?? []).whereType<Map>().map((item) => item.cast<String, dynamic>()).toList();
    if (items.isEmpty) return null;

    final totalAmount = items.fold<int>(0, (sum, item) => sum + ((item['amount'] as num?)?.toInt() ?? 0));
    return {
      'items_count': items.length,
      'total_amount': totalAmount,
      'items_preview': items,
    };
  }

  Map<String, dynamic>? _resolveCostSummary(Map<String, dynamic> order) {
    final summary = order['cost_summary'];
    if (summary is Map<String, dynamic>) return summary;

    final deliveryPrice = order['delivery_price'] as num?;
    final bonusUsed = order['bonus_used'] as num?;
    if (deliveryPrice == null && bonusUsed == null) return null;

    return {
      'delivery_price': deliveryPrice,
      'bonus_used': bonusUsed,
    };
  }
}
