import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../shared/app_theme.dart';
import '../utils/api.dart';
import '../utils/responsive.dart';
import 'order_detail_page.dart';

const Map<String, String> _orderStatusLabels = <String, String>{
  '0': 'Новый заказ',
  '1': 'Принят магазином',
  '11': 'Просмотрен',
  '12': 'Собирается',
  '2': 'Готов к выдаче',
  '21': 'Передан курьеру',
  '3': 'Доставляется',
  '31': 'Курьер рядом',
  '4': 'Доставлен',
  '5': 'Отменен',
  '50': 'Отменен пользователем',
  '51': 'Отменен магазином',
  '52': 'Отменен: нет в наличии',
  '6': 'Ошибка платежа',
  '60': 'Ожидает оплаты',
  '61': 'Оплата в обработке',
  '66': 'Не оплачен',
  '7': 'Возврат начат',
  '71': 'Возврат завершен',
};

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
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _activeOrders = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _historyOrders = <Map<String, dynamic>>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreHistory = true;
  int _historyPage = 1;
  final int _pageSize = 10;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadOrders();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
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
          : ApiService.getMyOrdersHistoryList(page: 1, pageSize: _pageSize);

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
      final pageOrders = await ApiService.getMyOrdersHistoryList(page: nextPage, pageSize: _pageSize);
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

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMoreHistory) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _loadMoreHistory();
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

  List<_HistoryListEntry> _historyEntries() {
    final entries = <_HistoryListEntry>[];
    DateTime? previousDate;

    for (final order in _historyOrders) {
      final orderDate = _orderTimestamp(order);
      if (previousDate == null || !_isSameDate(previousDate, orderDate)) {
        entries.add(_HistoryListEntry.divider(_formatHistoryDivider(orderDate)));
        previousDate = orderDate;
      }
      entries.add(_HistoryListEntry.order(order));
    }

    return entries;
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month && left.day == right.day;
  }

  String _formatHistoryDivider(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final normalized = DateTime(date.year, date.month, date.day);

    if (normalized == today) return 'Сегодня';
    if (normalized == yesterday) return 'Вчера';
    return DateFormat('d MMMM y', 'ru').format(date);
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
          Icon(Icons.receipt_long_outlined, color: AppColors.textMute, size: 48.s),
          SizedBox(height: 14.s),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12.s),
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
          Icon(Icons.shopping_bag_outlined, color: AppColors.textMute, size: 48),
          SizedBox(height: 14),
          Text(
            'Заказов пока нет',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          SizedBox(height: 7),
          Text(
            'Когда появятся активные или завершённые заказы, они будут отображаться здесь.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMute),
          ),
        ],
      );
    }

    final historyEntries = _historyEntries();

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(14.s, 7.s, 14.s, 22.s),
      children: [
        if (_activeOrders.isNotEmpty) ...[
          _sectionTitle('Активные заказы', '${_activeOrders.length}'),
          SizedBox(height: 9.s),
          ..._activeOrders.map((order) => Padding(
                padding: EdgeInsets.only(bottom: 9.s),
                child: OrderPreviewCard(order: order),
              )),
          SizedBox(height: 12.s),
        ],
        _sectionTitle('История заказов', '${_historyOrders.length}'),
        SizedBox(height: 9.s),
        if (_historyOrders.isEmpty)
          Container(
            padding: EdgeInsets.all(16.s),
            decoration: AppDecorations.card(radius: 16.s),
            child: const Text(
              'История пока пуста или ещё не доступна от сервера.',
              style: TextStyle(color: AppColors.textMute, fontWeight: FontWeight.w700),
            ),
          )
        else
          ...historyEntries.map((entry) {
            if (entry.label != null) {
              return Padding(
                padding: EdgeInsets.fromLTRB(2, 10.s, 2, 9.s),
                child: Text(
                  entry.label!,
                  style: TextStyle(
                    color: AppColors.textMute,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.sp,
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(bottom: 9.s),
              child: OrderPreviewCard(order: entry.order!),
            );
          }),
        if (_isLoadingMore) ...[
          const SizedBox(height: 8),
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation(AppColors.orange),
              ),
            ),
          ),
        ] else if (_hasMoreHistory && _historyOrders.isNotEmpty) ...[
          SizedBox(height: 10.s),
          Center(
            child: ElevatedButton.icon(
              onPressed: _loadMoreHistory,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Загрузить ещё'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.card,
                foregroundColor: AppColors.text,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
          ),
        ] else if (!_hasMoreHistory && _historyOrders.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Все заказы загружены',
              style: TextStyle(color: AppColors.textMute, fontWeight: FontWeight.w700),
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
          style: TextStyle(color: AppColors.text, fontSize: 16.sp, fontWeight: FontWeight.w900),
        ),
        SizedBox(width: 7.s),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 9.s, vertical: 4.s),
          decoration: AppDecorations.pill(color: AppColors.blue.withValues(alpha: 0.9)),
          child: Text(
            count,
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 11.sp),
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

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, entryValue) => MapEntry(key.toString(), entryValue));
    }
    return null;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value.map(_asMap).whereType<Map<String, dynamic>>().toList();
  }

  String _resolveStatusText(Map<String, dynamic>? status) {
    if (status == null) return 'Статус уточняется';

    final explicitText = status['status_description']?.toString() ?? status['status_name']?.toString();
    if (explicitText != null && explicitText.trim().isNotEmpty) {
      return explicitText;
    }

    final code = status['status']?.toString();
    if (code == null || code.isEmpty) return 'Статус уточняется';
    return _orderStatusLabels[code] ?? 'Статус $code';
  }

  @override
  Widget build(BuildContext context) {
    final business = _asMap(order['business']);
    final currentStatus = _asMap(order['current_status']);
    final itemsSummary = _resolveItemsSummary(order);
    final costSummary = _resolveCostSummary(order);
    final address = _asMap(order['delivery_address']);

    final title = '#${order['order_id'] ?? '—'}';
    final businessName = business?['name']?.toString() ?? 'Магазин не указан';
    final statusText = _resolveStatusText(currentStatus);
    final statusColor = _parseStatusColor(currentStatus?['status_color']?.toString());
    final dateText = _formatDate(order['log_timestamp']?.toString() ?? order['created_at']?.toString());
    final itemsCount = (itemsSummary?['items_count'] as num?)?.toInt();
    final totalAmount = (itemsSummary?['total_amount'] as num?)?.toInt();
    final deliveryPrice = costSummary?['delivery_price'] as num?;

    return InkWell(
      borderRadius: BorderRadius.circular(16.s),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderDetailPage(order: order),
          ),
        );
      },
      child: Container(
        decoration: AppDecorations.card(radius: 16.s),
        padding: EdgeInsets.all(12.s),
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
                        style: TextStyle(color: AppColors.text, fontSize: 15.sp, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 4.s),
                      Text(
                        businessName,
                        style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 9.s),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.s, vertical: 5.s),
                  decoration: AppDecorations.pill(color: statusColor.withValues(alpha: 0.18)),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11.sp),
                  ),
                ),
              ],
            ),
            SizedBox(height: 9.s),
            Wrap(
              spacing: 7.s,
              runSpacing: 7.s,
              children: [
                _metaChip(Icons.schedule, dateText),
                _metaChip(Icons.local_shipping_outlined, order['delivery_type']?.toString() ?? 'Не указан'),
                if (itemsCount != null) _metaChip(Icons.shopping_bag_outlined, '$itemsCount поз.'),
                if (totalAmount != null) _metaChip(Icons.layers_outlined, '$totalAmount шт.'),
                if (deliveryPrice != null) _metaChip(Icons.payments_outlined, 'Доставка ${_formatMoney(deliveryPrice)}'),
              ],
            ),
            if (address != null && (address['address']?.toString().trim().isNotEmpty ?? false)) ...[
              SizedBox(height: 9.s),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined, color: AppColors.textMute, size: 14.s),
                  SizedBox(width: 5.s),
                  Expanded(
                    child: Text(
                      address['address'].toString(),
                      style: TextStyle(color: AppColors.textMute, fontSize: 12.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 10.s),
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
      padding: EdgeInsets.symmetric(horizontal: 9.s, vertical: 5.s),
      decoration: AppDecorations.pill(color: AppColors.cardDark.withValues(alpha: 0.95)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textMute, size: 12.s),
          SizedBox(width: 5.s),
          Text(
            text,
            style: TextStyle(color: AppColors.text, fontSize: 11.sp, fontWeight: FontWeight.w700),
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
    final mappedSummary = _asMap(summary);
    if (mappedSummary != null) return mappedSummary;

    final items = _asMapList(order['items']);
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
    final mappedSummary = _asMap(summary);
    if (mappedSummary != null) return mappedSummary;

    final deliveryPrice = order['delivery_price'] as num?;
    final bonusUsed = order['bonus_used'] as num?;
    if (deliveryPrice == null && bonusUsed == null) return null;

    return {
      'delivery_price': deliveryPrice,
      'bonus_used': bonusUsed,
    };
  }
}

class _HistoryListEntry {
  final String? label;
  final Map<String, dynamic>? order;

  const _HistoryListEntry._({this.label, this.order});

  factory _HistoryListEntry.divider(String label) => _HistoryListEntry._(label: label);

  factory _HistoryListEntry.order(Map<String, dynamic> order) => _HistoryListEntry._(order: order);
}
