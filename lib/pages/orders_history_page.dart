import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/repeat_order_service.dart';
import '../shared/app_theme.dart';
import '../utils/api.dart';
import '../utils/business_provider.dart';
import '../utils/cart_provider.dart';
import '../utils/order_ui_helpers.dart' as order_ui;
import '../utils/responsive.dart';
import 'checkout_page.dart';
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
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _activeOrders = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _historyOrders = <Map<String, dynamic>>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreHistory = true;
  int _historyPage = 1;
  final int _pageSize = 10;
  String? _repeatingOrderId;
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
          ? Future<List<Map<String, dynamic>>>.value(
              widget.initialActiveOrders!)
          : ApiService.getMyActiveOrdersList();
      final historyFuture = widget.initialHistoryOrders != null
          ? Future<List<Map<String, dynamic>>>.value(
              widget.initialHistoryOrders!)
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
      final pageOrders = await ApiService.getMyOrdersHistoryList(
          page: nextPage, pageSize: _pageSize);
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
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMoreHistory)
      return;
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

  Future<void> _repeatOrder(Map<String, dynamic> order) async {
    final orderKey = _orderIdentity(order);
    if (_repeatingOrderId != null) return;

    final shouldContinue = await _confirmReplaceCart(order);
    if (shouldContinue != true || !mounted) return;

    setState(() {
      _repeatingOrderId = orderKey;
    });

    try {
      final cartProvider = context.read<CartProvider>();
      final businessProvider = context.read<BusinessProvider>();
      final result = await RepeatOrderService.repeatOrderIntoCart(
        sourceOrder: order,
        cartProvider: cartProvider,
        businessProvider: businessProvider,
      );
      if (!mounted) return;

      if (result.hasSkippedItems) {
        await AppDialogs.showMessage(
          context,
          title: 'Часть позиций пропущена',
          message: 'Не все позиции из прошлого заказа удалось восстановить. Проверьте состав перед подтверждением.',
        );
      }
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheckoutPage(
            initialDeliveryType: result.deliveryType,
            initialAddress: result.restoredAddress,
          ),
        ),
      );
    } on RepeatOrderException catch (e) {
      if (!mounted) return;
      await AppDialogs.showMessage(
        context,
        title: 'Не удалось повторить заказ',
        message: e.message,
      );
    } catch (_) {
      if (!mounted) return;
      await AppDialogs.showMessage(
        context,
        title: 'Не удалось повторить заказ',
        message: 'Попробуйте ещё раз чуть позже.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _repeatingOrderId = null;
        });
      }
    }
  }

  Future<bool?> _confirmReplaceCart(Map<String, dynamic> order) {
    final cartProvider = context.read<CartProvider>();
    if (!cartProvider.hasActiveItems) {
      return Future<bool?>.value(true);
    }

    final currentBusiness = context.read<BusinessProvider>().selectedBusiness;
    final targetBusiness = RepeatOrderService.extractBusiness(order);
    final currentBusinessId = currentBusiness?['id'] ?? currentBusiness?['business_id'] ?? currentBusiness?['businessId'];
    final targetBusinessId = targetBusiness?['id'] ?? targetBusiness?['business_id'] ?? targetBusiness?['businessId'];
    final targetBusinessName = targetBusiness?['name']?.toString() ?? 'другой магазин';
    final isDifferentBusiness = targetBusinessId != null && currentBusinessId != targetBusinessId;

    return AppDialogs.show<bool>(
      context,
      title: 'Заменить корзину?',
      content: Text(
        isDifferentBusiness
            ? 'Текущая корзина будет очищена, а магазин сменится на $targetBusinessName.'
            : 'Текущая корзина будет очищена и заменена товарами из этого заказа.',
        style: const TextStyle(color: AppColors.textMute),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена', style: TextStyle(color: AppColors.text)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Продолжить', style: TextStyle(color: AppColors.orange)),
        ),
      ],
    );
  }

  DateTime _orderTimestamp(Map<String, dynamic> order) {
    final raw =
        order['log_timestamp']?.toString() ?? order['created_at']?.toString();
    if (raw == null || raw.isEmpty)
      return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(raw)?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<_HistoryListEntry> _historyEntries() {
    final entries = <_HistoryListEntry>[];
    DateTime? previousDate;

    for (final order in _historyOrders) {
      final orderDate = _orderTimestamp(order);
      if (previousDate == null || !_isSameDate(previousDate, orderDate)) {
        entries
            .add(_HistoryListEntry.divider(_formatHistoryDivider(orderDate)));
        previousDate = orderDate;
      }
      entries.add(_HistoryListEntry.order(order));
    }

    return entries;
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
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
        title: const Text('Мои заказы',
            style: TextStyle(fontWeight: FontWeight.w800)),
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
          Icon(Icons.receipt_long_outlined,
              color: AppColors.textMute, size: 48.s),
          SizedBox(height: 14.s),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.text, fontWeight: FontWeight.w700),
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
          Icon(Icons.shopping_bag_outlined,
              color: AppColors.textMute, size: 48),
          SizedBox(height: 14),
          Text(
            'Заказов пока нет',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
                fontSize: 16),
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
                child: OrderPreviewCard(
                  order: order,
                  onRepeat: () => _repeatOrder(order),
                  isRepeating: _repeatingOrderId == _orderIdentity(order),
                ),
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
              style: TextStyle(
                  color: AppColors.textMute, fontWeight: FontWeight.w700),
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
              child: OrderPreviewCard(
                order: entry.order!,
                onRepeat: () => _repeatOrder(entry.order!),
                isRepeating: _repeatingOrderId == _orderIdentity(entry.order!),
              ),
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
              style: TextStyle(
                  color: AppColors.textMute, fontWeight: FontWeight.w700),
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
          style: TextStyle(
              color: AppColors.text,
              fontSize: 16.sp,
              fontWeight: FontWeight.w900),
        ),
        SizedBox(width: 7.s),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 9.s, vertical: 4.s),
          decoration:
              AppDecorations.pill(color: AppColors.blue.withValues(alpha: 0.9)),
          child: Text(
            count,
            style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
                fontSize: 11.sp),
          ),
        ),
      ],
    );
  }
}

class OrderPreviewCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onRepeat;
  final bool isRepeating;

  const OrderPreviewCard({
    super.key,
    required this.order,
    this.onRepeat,
    this.isRepeating = false,
  });

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

  num? _asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value
          .map((key, entryValue) => MapEntry(key.toString(), entryValue));
    }
    return null;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value.map(_asMap).whereType<Map<String, dynamic>>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final business = _asMap(order['business']);
    final currentStatus = _asMap(order['current_status']);
    final itemsSummary = _resolveItemsSummary(order);
    final costSummary = _resolveCostSummary(order);
    final address = _asMap(order['delivery_address']);
    final isCanceled = order_ui.isOrderCanceled(order);

    final title = '#${order['order_id'] ?? '—'}';
    final businessName = business?['name']?.toString() ?? 'Магазин не указан';
    final statusText =
        order_ui.resolveOrderStatusText(order, status: currentStatus);
    final statusColor = isCanceled
        ? AppColors.red
        : _parseStatusColor(currentStatus?['status_color']?.toString());
    final dateText = _formatDate(
        order['log_timestamp']?.toString() ?? order['created_at']?.toString());
    final itemsCount = (itemsSummary?['items_count'] as num?)?.toInt();
    final totalAmount = (itemsSummary?['total_amount'] as num?)?.toInt();
    final deliveryPrice = _asNum(costSummary?['delivery_price']);
    final totalSum = _resolveOrderTotal(costSummary, itemsSummary);
    final deliveryTypeText = order_ui.resolveDeliveryTypeText(order);
    final businessAddress = business?['address']?.toString().trim();
    final deliveryAddress = address?['address']?.toString().trim();
    final itemsText = [
      if (itemsCount != null) '$itemsCount поз.',
      if (totalAmount != null) '$totalAmount шт.',
    ].join(' • ');

    return InkWell(
      borderRadius: BorderRadius.circular(18.s),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderDetailPage(order: order),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18.s),
          border: Border.all(
            color: (isCanceled ? AppColors.red : AppColors.orange)
                .withValues(alpha: isCanceled ? 0.26 : 0.14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.26),
              blurRadius: 18,
              offset: Offset(0, 10.s),
            ),
          ],
        ),
        padding: EdgeInsets.all(13.s),
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
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 5.s),
                      Text(
                        businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800),
                      ),
                      if (businessAddress != null &&
                          businessAddress.isNotEmpty) ...[
                        SizedBox(height: 4.s),
                        _inlineInfo(Icons.storefront_outlined, businessAddress),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 10.s),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _statusBadge(statusText, statusColor,
                        isCanceled: isCanceled),
                    if (totalSum != null) ...[
                      SizedBox(height: 8.s),
                      Text(
                        _formatMoney(totalSum),
                        style: TextStyle(
                            color: AppColors.orange,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w900),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.s),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),
            SizedBox(height: 11.s),
            Row(
              children: [
                Expanded(
                    child:
                        _summaryTile(Icons.schedule_rounded, 'Дата', dateText)),
                SizedBox(width: 9.s),
                Expanded(
                    child: _summaryTile(Icons.local_shipping_outlined, 'Тип',
                        deliveryTypeText)),
              ],
            ),
            if (itemsText.isNotEmpty || deliveryPrice != null) ...[
              SizedBox(height: 8.s),
              Row(
                children: [
                  if (itemsText.isNotEmpty)
                    Expanded(
                        child: _summaryTile(
                            Icons.shopping_bag_outlined, 'Товары', itemsText)),
                  if (itemsText.isNotEmpty && deliveryPrice != null)
                    SizedBox(width: 9.s),
                  if (deliveryPrice != null)
                    Expanded(
                      child: _summaryTile(Icons.payments_outlined, 'Доставка',
                          _formatMoney(deliveryPrice)),
                    ),
                ],
              ),
            ],
            if (address != null &&
                !order_ui.isPickupAddress(address) &&
                (deliveryAddress?.isNotEmpty ?? false)) ...[
              SizedBox(height: 10.s),
              _inlineInfo(Icons.location_on_outlined, deliveryAddress!,
                  label: 'Куда'),
            ],
            SizedBox(height: 12.s),
            Row(
              children: [
                if (onRepeat != null)
                  OutlinedButton.icon(
                    onPressed: isRepeating ? null : onRepeat,
                    icon: isRepeating
                        ? SizedBox(
                            width: 14.s,
                            height: 14.s,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(AppColors.orange),
                            ),
                          )
                        : Icon(Icons.replay_rounded, size: 16.s),
                    label: Text(isRepeating ? 'Собираем...' : 'Повторить заказ'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.orange,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 10.s),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.s)),
                    ),
                  ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Открыть детали',
                      style: TextStyle(color: AppColors.orange.withValues(alpha: 0.95), fontWeight: FontWeight.w900),
                    ),
                    SizedBox(width: 5.s),
                    Icon(Icons.chevron_right_rounded, color: AppColors.orange, size: 18.s),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String text, Color color, {required bool isCanceled}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 124.s),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 6.s),
        decoration: AppDecorations.pill(
            color: color.withValues(alpha: isCanceled ? 0.24 : 0.2)),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: isCanceled ? const Color(0xFFFF7B6E) : color,
              fontWeight: FontWeight.w900,
              fontSize: 11.sp),
        ),
      ),
    );
  }

  Widget _summaryTile(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28.s,
          height: 28.s,
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(9.s),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Icon(icon, color: AppColors.textMute, size: 14.s),
        ),
        SizedBox(width: 7.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.textMute,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2.s),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inlineInfo(IconData icon, String text, {String? label}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textMute, size: 14.s),
        SizedBox(width: 5.s),
        if (label != null) ...[
          Text(
            '$label: ',
            style: TextStyle(
                color: AppColors.textMute,
                fontSize: 12.sp,
                fontWeight: FontWeight.w800),
          ),
        ],
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: AppColors.textMute,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                height: 1.25),
          ),
        ),
      ],
    );
  }

  num? _resolveOrderTotal(
      Map<String, dynamic>? costSummary, Map<String, dynamic>? itemsSummary) {
    final explicitTotal = _asNum(costSummary?['total_sum']) ??
        _asNum(costSummary?['total']) ??
        _asNum(costSummary?['order_total']);
    if (explicitTotal != null) return explicitTotal;

    final itemsTotal = _asNum(costSummary?['items_total']);
    if (itemsTotal != null) {
      return itemsTotal +
          (_asNum(costSummary?['delivery_price']) ?? 0) -
          (_asNum(costSummary?['bonus_used']) ?? 0);
    }

    final items =
        _asMapList(itemsSummary?['items_preview'] ?? itemsSummary?['items']);
    if (items.isEmpty) return null;

    return items.fold<num>(0, (sum, item) {
      final amount = _asNum(item['amount']) ?? 0;
      final price = _asNum(item['price']) ??
          _asNum(item['total_cost']) ??
          _asNum(item['total']) ??
          _asNum(item['sum']) ??
          0;
      return sum +
          (amount > 0 && item['price'] != null ? amount * price : price);
    });
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

    final totalAmount = items.fold<int>(
        0, (sum, item) => sum + ((item['amount'] as num?)?.toInt() ?? 0));
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

    final deliveryPrice = _asNum(order['delivery_price']);
    final bonusUsed = _asNum(order['bonus_used']);
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

  factory _HistoryListEntry.divider(String label) =>
      _HistoryListEntry._(label: label);

  factory _HistoryListEntry.order(Map<String, dynamic> order) =>
      _HistoryListEntry._(order: order);
}
